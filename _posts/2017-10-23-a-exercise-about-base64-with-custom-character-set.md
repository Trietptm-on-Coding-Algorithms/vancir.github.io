---
title: Base64自定义字符集的一道逆向
tags: [CTF]
layout: post
categories: writeups
---
这次分析的是`WhiteHat Grand Prix Qualification Round 2015`的一道100分的逆向题`Dong Van`. 这道题的关键在于使用了`自定义编码`的`Base64`来处理字符串.

文件下载地址: [re100_35d14595b17756b79556f6eca775c31a](http://od7mpc53s.bkt.clouddn.com/re100_35d14595b17756b79556f6eca775c31a)


## 分析

下载下来是7z压缩文件, 用7z解压. 使用file命令查看文件属性, 是一个x64的ELF可执行文件
```bash
➜  dong-van chmod +x Re100
➜  dong-van file Re100
Re100: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 2.6.24, BuildID[sha1]=6c7c0504ab2f342427f59846298e97f9e4fbb98f, not stripped
```

使用`IDA Pro(64 bits)`打开文件, `shift+f12`查找文件中出现的字符串, 我们发现了一些比较关键的信息

``` bash
.rodata:00000000004036F8	00000041	C	ELF8n0BKxOCbj/WU9mwle4cG6hytqD+P3kZ7AzYsag2NufopRSIVQHMXJri51Tdv
.rodata:0000000000403741	00000014	C	Input your secret: 
.rodata:0000000000403755	00000019	C	ms4otszPhcr7tMmzGMkHyFn=
.rodata:000000000040376E	0000001E	C	Good boy! Submit your flag :)
.rodata:000000000040378C	0000000B	C	Too bad :(
```

那么我们就可以猜测程序的执行逻辑是这样的

```bash
输入secret -> 处理secret -> 将处理过的secret与正确但已被处理过的secret进行比较 -> 根据比较结果输出提示信息.
```
而且显然`ms4otszPhcr7tMmzGMkHyFn=`是一个base64字符串. 

```bash
➜  ~ echo -n ms4otszPhcr7tMmzGMkHyFn= | base64 --decode 
��(��υ���ɳ��Y%                                    
```
明显解密失败. 但是这是一个base64串基本是可以确认的. 所以这个base64的处理过程有变化.也有可能是先将字符串进行AES加密或其他的加密方式, 然后再进行base64编码.

我们通过交叉引用继续找到主程序继续分析

``` c 
int __cdecl main(int argc, const char **argv, const char **envp)
{
  char v3; // bl
  char v5; // [rsp+0h] [rbp-40h]
  char v6; // [rsp+10h] [rbp-30h]
  char v7; // [rsp+20h] [rbp-20h]

  std::string::string((std::string *)&v5);
  std::operator<<<std::char_traits<char>>(&std::cout, "Input your secret: ");
  std::operator>><char,std::char_traits<char>,std::allocator<char>>(&std::cin, &v5);
  std::string::string((std::string *)&v6, (const std::string *)&v5);
  change(&v7, &v6);
  v3 = std::operator==<char,std::char_traits<char>,std::allocator<char>>(&v7, "ms4otszPhcr7tMmzGMkHyFn=");
  std::string::~string((std::string *)&v7);
  std::string::~string((std::string *)&v6);
  if ( v3 )
    std::operator<<<std::char_traits<char>>(&std::cout, "Good boy! Submit your flag :)");
  else
    std::operator<<<std::char_traits<char>>(&std::cout, "Too bad :(");
  std::string::~string((std::string *)&v5);
  return 0;
}
```

从反编译代码可以看出, `ms4otszPhcr7tMmzGMkHyFn=`是正确但是被处理过的secret, 处理字符串的逻辑主要在于`change(&v7, &v6);`这一处. 而且我们点进去观察这个函数, 我们会发现

```
std::string::string(&v19, "ELF8n0BKxOCbj/WU9mwle4cG6hytqD+P3kZ7AzYsag2NufopRSIVQHMXJri51Tdv", &v38);
```

而`ELF8n0BKxOCbj/WU9mwle4cG6hytqD+P3kZ7AzYsag2NufopRSIVQHMXJri51Tdv`刚好有64位. 因此可以推测出这是一个自定义编码的base64处理. 

因此我们设定自定义编码进行解码, 得到secret.

```
➜ echo ms4otszPhcr7tMmzGMkHyFn= | tr 'ELF8n0BKxOCbj/WU9mwle4cG6hytqD+P3kZ7AzYsag2NufopRSIVQHMXJri51Tdv' 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' | base64 --decode
Funny_encode_huh!
```