---
title: Flareon challenge 4 第3题
tags: [RE,flareon]
layout: post
categories: 
- crack
- translations
---

> 本文已发表在看雪论坛, 详情可见: [https://bbs.pediy.com/thread-223494.htm](https://bbs.pediy.com/thread-223494.htm)

文章作者: hasherezade(@hasherezade)

原文链接: [Import all the things! Solving FlareOn4 Challenge 3 with libPeConv](https://hshrzd.wordpress.com/2017/11/24/import-all-the-things-solving-flareon-challenge-3-with-libpeconv/)

翻译前言: 虽然依旧是Flareon4第3题的分析,但是一道题的解决方法多种多样,这次给大家分享如何使用libPeConv来解决问题,又可以get到新姿势啦

libPeConv: 是作者hasherezade开发的用于加载和转换PE文件的库,github仓库地址是:[libpeconv](https://github.com/hasherezade/libpeconv)

文中分析的程序你可以点击此处下载: [greek_to_me.zip](http://od7mpc53s.bkt.clouddn.com/greek_to_me.zip), 解压密码: www.pediy.com


## 总览
题目greek_to_me.exe是一个32位PE文件, 程序已经剔除了重定位信息. 我们以下就简称该程序为crackme
![fig1](https://hshrzd.files.wordpress.com/2017/11/exe_info.png?w=640)

我们运行crackme, 只有一个空白的控制台程序, 并且没有从标准输入中读取任何数据, 所以我们可以推断程序是使用了一些其他方式来读取用户的password

我们使用IDA静态分析, crackme结构非常简洁并没有混淆过. 我们可以在代码开头看见程序创建了一个socket并等待着输入
socket监听着本地2222端口

![fig2](https://hshrzd.files.wordpress.com/2017/11/make_socket.png)

在建立连接后, crackme从用户输入中取前4字节读入到缓冲区中:

![fig3](https://hshrzd.files.wordpress.com/2017/11/recv_4.png)

读入4字节后, crackme开始处理输入并用来解码已加密的缓冲区数据

![fig4](https://hshrzd.files.wordpress.com/2017/11/read_buf.png)

如果校验值是合法的, 也就是说加密数据被正确解密了, 那么crackme就会进一步执行下去.

我们可以看到, 输入中的数据只有1字节用于解码缓冲区数据, 所以我们可以轻易地穷举获得结果. 解码部分的代码也相当简单:
``` c
const size_t encrypted_len = 0x79;
for (int i = 0; i < encrypted_len; i++) {
    BYTE val = encrypted_code[i];
    encrypted_code[i] = (unknown_byte ^ val) + 0x22;
}
```
程序唯一的难点在于校验值 - 这个函数并没有那么好复现. 然而如果我们想要暴力穷举, 我们却又需要在穷举后计算校验值.

在我之前的解答中, 我复现了校验函数并表现良好, 但这并没有那么好玩. 我看过了一些其他的解决方式如[使用Unicorn引擎模拟执行校验函数](https://www.fireeye.com/content/dam/fireeye-www/global/en/blog/threat-research/Flare-On%202017/Challenge%20%233%20solution.pdf)
, 或[使用angr框架](https://blog.xorhex.com/flare-on-2017-challenge-3/), 或[通过socket使用暴力穷举程序来获得原始程序](http://blog.attify.com/2017/10/10/flare-4-writeup-p1/)等等. 但是我们可以解决得更快速吗?我们来接着看...
## 使用LibPeConv
使用PeConv我们可以将原始格式的任何PE文件转换成虚拟内存格式并返回. 它也提供有一个可定制的PE加载器 - 用于加载任意PE文件到当前进程(就算它不是dll文件也没有重定位表, 这我会在之后的部分进行解释). 载入的PE文件随后可以在当前进程内运行. 我们也可以选择文件中的任意函数来使用 - 而我们只需要知道函数的RVA和API.

在这次, 我将会使用libpeconv来加载crackme并导入校验值的计算函数. 不用复制加密缓冲区数据到我们的代码中, 我们可以直接从载入的PE文件中读取它. 

## 收集需要的信息
让我们再一次在IDA中查看crackme. 我们需要找到恰当的偏移量并明白我们需要导入的API函数.

首先我们计算校验值的函数起始于RVA 0x11E6处:

![fig5](https://hshrzd.files.wordpress.com/2017/11/checksum_func.png)

函数读取2个参数: 指向缓冲区的指针和缓冲区大小
函数返回一个WORD类型数据.

![fig6](https://hshrzd.files.wordpress.com/2017/11/return_word.png)

总结一下, 我们可以定义一个如下的函数原型:
``` c
WORD calc_checksum(BYTE *decoded_buffer, size_t buf_size)
```
还有一点需要注意, 就是这个函数是可独用的并且没有调用任何的导入库函数 - 这让我们导入这个校验值函数更加轻松(我们不必加载任何导入库模块或进行重定位).

另一个我们需要的信息就是加密的缓冲区. 缓冲区起始于RVA 0x107C并且长度为0x79(121)字节

![fig7](https://hshrzd.files.wordpress.com/2017/11/enc_code.png)

信息搜集完毕!我们开始写代码.
## 使用libPeConv解决crackme
当前版本的`libpeconv`允许两种方式来载入PE文件. 使用到的函数有`load_pe_module`和`load_pe_executable`. 第2个函数`load_pe_executable`是一个完整的加载器, 它加载指定PE文件到当前进程的可读可写可执行(RWX)内存中, 并自动应用重定位信息和载入其他依赖. 第1个函数`load_pe_module`则不能载入依赖并且我们需要提供更多的控制: 我们可能会加载PE文件到一个不可执行的内存中而是否进行重定位也是可选的. 更多详细信息(或者该API的重要更新)请看: [https://github.com/hasherezade/libpeconv/blob/master/libpeconv/include/peconv/pe_loader.h](https://github.com/hasherezade/libpeconv/blob/master/libpeconv/include/peconv/pe_loader.h)

正如我们所见, 我们想要导入的函数是独用的, 因此如果我们载入crackme的PE文件时没有加载导入表和重定位信息也不会造成什么危害(我们将在文章的下一部分看如何载入一个完整的PE文件). 我将使用到`load_pe_module`函数
``` c
BYTE* loaded_pe = (BYTE*)load_pe_module(
    path,
    v_size, // OUT: size of the loaded module
    true,   // executable
    false   // without relocations
);
```
现在, 我们来导入函数, 首先我们来定义一个指针
```c
WORD (*calc_checksum) (BYTE *buffer, size_t buf_size) = NULL;
```
计算在载入模块中该函数的绝对偏移
``` c
ULONGLONG offset = DWORD(0x11e6) + (ULONGLONG) loaded_pe;
```
然后填充指针
``` c
calc_checksum = ( WORD (*) (BYTE *, size_t ) ) offset;
```
现在我们就可以在我们的应用程序里该函数
但在那之前, 我们可以开始暴力穷举, 我们也同样也需要填充缓冲区指针.
``` c
g_Buffer = (uint8_t*) (0x107C + (ULONGLONG) loaded_pe);
```
以下链接是我准备的完整穷举程序: [https://gist.github.com/hasherezade/44b440675ccc065f111dd6a90ed34399#file-brutforcer_1-cpp](https://gist.github.com/hasherezade/44b440675ccc065f111dd6a90ed34399#file-brutforcer_1-cpp)
并且结果表现良好. 我们得到的结果跟crackme需要的一样.

![fig8](https://hshrzd.files.wordpress.com/2017/11/brutforce_1.png)

但目前为止, 我们找到的值也只是解答过程的一部分, 并不是我们需要找到的flag. 我们从先前静态分析时可以知道, 如果给出正确值, 那么代码块就能解密并执行. 如果我们能看到解密后代码块到底是怎样的, 那岂不是很酷?

而且这也非常容易实现. 我们的PE文件载入进了当前进程可读可写可执行内存中 - 因此我们可以轻易地将解密后的数据替换回加密块代码, 我们只需要一个简单的`memcpy`就能完成这个工作
``` c
memcpy(g_Buffer, g_Buffer2, g_BufferLen);
```
随后, `libPeConv`可以帮助我们将PE文件转换回原始格式以便用IDA打开. 我们可以用`libPeConv`的`pe_virtual_to_raw`来完成.

``` c
size_t out_size = 0;
BYTE* unmapped_module = pe_virtual_to_raw(
    loaded_pe, //pointer to the module
    v_size, //virtual size
    module_base, //in this case we need here
                 //the original module base, because
                 //the loaded PE was not relocated
    out_size //OUT: raw size of the unmapped PE
);
```
并且以下是完整的解答: [brutforcer_2.cpp](https://gist.github.com/hasherezade/36a4a531840cfe1fd5997bc7c5f6be4d#file-brutforcer_2-cpp)
``` c
#include <stdio.h>

#include "peconv.h"

BYTE *g_Buffer = NULL;
const size_t g_BufferLen = 0x79;

BYTE g_Buffer2[g_BufferLen] = { 0 };

WORD (*calc_checksum) (BYTE *decoded_buffer, size_t buf_size) = NULL;

bool test_val(BYTE xor_val)
{
    for (size_t i = 0; i < g_BufferLen; i++) {
        BYTE val = g_Buffer[i];
        g_Buffer2[i] = (xor_val ^ val) + 0x22;
    }
    WORD checksum = calc_checksum(g_Buffer2, g_BufferLen);
    if (checksum == 0xfb5e) {
        return true;
    }
    return false;
}

BYTE brutforce()
{
    BYTE xor_val = 0;
    do {
      xor_val++;
    } while (!test_val(xor_val));
    return xor_val;
}
//---

bool dump_to_file(char *out_path, BYTE* buffer, size_t buf_size)
{
    FILE *f1 = fopen(out_path, "wb");
    if (!f1) {
        return false;
    }
    fwrite(buffer, 1, buf_size, f1);
    fclose(f1);
    return true;
}

int main(int argc, char *argv[])
{
#ifdef _WIN64
    printf("Compile the loader as 32bit!\n");
    system("pause");
    return 0;
#endif
    char default_path[] = "greek_to_me.exe";
    char *path = default_path;
    if (argc > 2) {
        path = argv[1];
    }
    size_t v_size = 0;

    BYTE* loaded_pe = peconv::load_pe_module(path, 
                                     v_size, 
                                     true, // load as executable?
                                     false // apply relocations ?
                                    );
    if (!loaded_pe) {
        printf("Loading module failed!\n");
        system("pause");
        return 0;
    }

    g_Buffer = (BYTE*) (0x107C + (ULONGLONG) loaded_pe);

    ULONGLONG func_offset = 0x11e6 + (ULONGLONG) loaded_pe;
    calc_checksum =  ( WORD (*) (BYTE *, size_t ) ) func_offset;

    BYTE found = brutforce();
    printf("Found: %x\n", found);

    memcpy(g_Buffer, g_Buffer2, g_BufferLen);

    size_t out_size = 0;
    
    /*in this case we need to use the original module base, because 
    * the loaded PE was not relocated */
    ULONGLONG module_base = peconv::get_image_base(loaded_pe); 
    
    BYTE* unmapped_module = peconv::pe_virtual_to_raw(loaded_pe, 
                                              v_size, 
                                              module_base, //the original module base
                                              out_size // OUT: size of the unmapped (raw) PE
                                             );
    if (unmapped_module) {
        char out_path[] = "modified_pe.exe";
        if (dump_to_file(out_path, unmapped_module, out_size)) {
            printf("Module dumped to: %s\n", out_path);
        }
        peconv::free_pe_buffer(unmapped_module, v_size);
    }
    peconv::free_pe_buffer(loaded_pe, v_size);
    
    system("pause");
    return 0;
}
```
与初始的文件相比, 我们可以看到dump出来的可执行文件的缓冲区已经覆写过了.

![fig9](https://hshrzd.files.wordpress.com/2017/11/filled_buf.png?w=640)

所以我们在IDA里看下修改的可执行文件

![fig10](https://hshrzd.files.wordpress.com/2017/11/flag_revealed.png)

搞定!在`0x000F107C`处显示出我们的flag: `et_tu_brute_force@flare-on.com`

## 福利 - 载入和运行剔除了重定位信息的PE文件
OK, 你可能会说, 这很简单呀, 导入的函数是独立的, 所以我们可以从原来文件中抽出来, 并不需要使用任何加载器. 但是如果函数调用了一些其他的模块内的其他函数或是导入函数呢? 我们之前的方法还能生效吗? 不止如此, 剔除掉重定位信息的PE文件又能行吗?

为了回答这些问题, 我准备了其他的测试用例. 与之前载一个函数相反, 我将会在穷举程序中载入并执行完整的crackme文件. 

首先我们将会修改一些东西. 这次不使用`load_pe_module`, 我使用`load_pe_executable`来加载完整的可执行文件和依赖.
``` c
BYTE* loaded_pe = (BYTE*)load_pe_executable(path, v_size);
```

这个函数将自动地识别出这个PE文件没有重定位信息, 并且载入到初始模块基址. 注意, 分配的指定基址处的内存可能不总会生效, 因此有时需要运行多次使得程序正确地执行. 你也必须确定加载器的模块基址跟payload需要的模块基址不相冲突(如果加载器的基址是随机的话就很好).

一旦PE文件加载完毕, 我们就需要获取它的入口地址, 并且随后我们就可以像其他函数一样调用它:

``` c
// Deploy the payload:
// read the Entry Point from the headers:
ULONGLONG ep_va = get_entry_point_rva(loaded_pe)
    + (ULONGLONG) loaded_pe;
 
//make pointer to the entry function:
int (*loaded_pe_entry)(void) = (int (*)(void)) ep_va;
 
//call the loaded PE's ep:
int ret = loaded_pe_entry();
```

但还要注意这与payload的具体实现细节有关, 一旦你转向执行入口点代码, 它可能在完成工作后直接退出而不会返回到你的代码中. 

我打算修改穷举程序的代码, 使得在找到正确值之后crackme会继续运行. 以下是代码的完整版本: [brutforcer_3.cpp](https://gist.github.com/hasherezade/9d5186b27c730d01849ac1787b3d699b#file-brutforcer_3-cpp)
``` c
#include <stdio.h>

#include "peconv.h"

BYTE *g_Buffer = NULL;
const size_t g_BufferLen = 0x79;

BYTE g_Buffer2[g_BufferLen] = { 0 };

WORD (*calc_checksum) (BYTE *decoded_buffer, size_t buf_size) = NULL;

bool test_val(BYTE xor_val)
{
    for (size_t i = 0; i < g_BufferLen; i++) {
        BYTE val = g_Buffer[i];
        g_Buffer2[i] = (xor_val ^ val) + 0x22;
    }
    WORD checksum = calc_checksum(g_Buffer2, g_BufferLen);
    if (checksum == 0xfb5e) {
        return true;
    }
    return false;
}

BYTE brutforce()
{
    BYTE xor_val = 0;
    do {
      xor_val++;
    } while (!test_val(xor_val));
    return xor_val;
}
//---

int main(int argc, char *argv[])
{
#ifdef _WIN64
    printf("Compile the loader as 32bit!\n");
    system("pause");
    return 0;
#endif
    char default_path[] = "greek_to_me.exe";
    char *path = default_path;
    if (argc > 2) {
        path = argv[1];
    }
    size_t v_size = 0;

    BYTE* loaded_pe = peconv::load_pe_executable(path, v_size);
    if (!loaded_pe) {
        printf("Loading module failed!\n");
        system("pause");
        return 0;
    }

    g_Buffer = (BYTE*) (0x107C + (ULONGLONG) loaded_pe);

    ULONGLONG func_offset = 0x11e6 + (ULONGLONG) loaded_pe;
    calc_checksum =  ( WORD (*) (BYTE *, size_t ) ) func_offset;

    BYTE found = brutforce();
    printf("Found: %x\n", found);

    // Deploy the payload!
    // read the Entry Point from the headers:
    ULONGLONG ep_va = peconv::get_entry_point_rva(loaded_pe) + (ULONGLONG) loaded_pe;

    //make pointer to the entry function:
    int (*loaded_pe_entry)(void) = (int (*)(void)) ep_va;

    //call the loaded PE's ep:
    printf("Calling the Entry Point of the loaded module:\n");
    int res = loaded_pe_entry();
    printf("Finished: %d\n", res);
    system("pause");
    return 0;
}
```
为了确保一切运行正常(尽管运行payload确实建立了socket并给出跟之前载入独立函数时相同的回应), 我写了一个简短的python脚本来交流和显示回应结果: [test.py](https://gist.github.com/hasherezade/328210a57464360e23e125929b62b301#file-test-py)

``` python
import socket
import sys
import argparse

def main():
    parser = argparse.ArgumentParser(description="Send to the Crackme")
    parser.add_argument('--key', dest="key", default="0xa2", help="The value to be sent")
    args = parser.parse_args()
    my_key = int(args.key, 16) % 255
    print '[+] Checking the key: ' + hex(my_key)
    key =  chr(my_key) + '012'
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect(('127.0.0.1', 2222))
        s.send(key)
        result = s.recv(512)
        if result is not None:
            print "[+] Response: " + result
        s.close()
    except socket.error:
        print "Could not connect to the socket. Is the crackme running?"
    
if __name__ == "__main__":
    sys.exit(main())
```

现在, 你可以在YouTube观看整个过程的操作: [https://www.youtube.com/watch?v=x3T3qFEDkF0](https://www.youtube.com/watch?v=x3T3qFEDkF0)

以上就是我今天所准备的内容, 我希望大家都能有所收获! 该库现在正处于快速开发阶段, 所以许多东西会进行重构并优化, 敬请期待. 

## 附录
其他解决该问题的方法如下:
* [emulating the checksum function by the Unicorn engine](https://www.fireeye.com/content/dam/fireeye-www/global/en/blog/threat-research/Flare-On%202017/Challenge%20%233%20solution.pdf)
* [using angr framework](https://blog.xorhex.com/flare-on-2017-challenge-3/)
* [using WinAppDbg](https://parsiya.net/blog/2017-11-15-winappdbg---part-4---bruteforcing-flareon-2017---challenge-3/)
* [a brutforcer that talks to the original program via socket](http://blog.attify.com/2017/10/10/flare-4-writeup-p1/)

