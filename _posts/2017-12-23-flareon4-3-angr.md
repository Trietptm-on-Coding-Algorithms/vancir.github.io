---
title: 使用Angr解决Flareon4题目3
tags: [RE,flareon]
layout: post
categories: 
- crack
- translations
---

> 本文已发表在看雪论坛, 详情可见: [https://bbs.pediy.com/thread-223512.htm](https://bbs.pediy.com/thread-223512.htm)


文章作者: XOR Hex

博客地址: [https://blog.xorhex.com/](https://blog.xorhex.com/)

原文链接: [Flare-On 2017: Challenge 3](https://blog.xorhex.com/flare-on-2017-challenge-3/)

翻译前言: 这是解决Flareon4第3题的第3种方法. 文章中使用angr编写python脚本来获得flag, 对比之前我翻译的使用Unicorn框架的文章里的代码, 对于刚接触Angr或Unicorn的朋友会有不少帮助. 

文中分析的程序你可以点击此处下载: [greek_to_me.zip](http://od7mpc53s.bkt.clouddn.com/greek_to_me.zip), 解压密码: www.pediy.com

## 准备

我们用IDA打开文件并调到入口点, 入口点简单地调用了函数`sub_401008`

![entry_point.png](https://blog.xorhex.com/content/images/2017/09/greek_to_me_entry_point.png)

我们打开这个函数看看, 向下滚动我们可以看到看起来像成功提示的文本字符串, 接下来的标准流程就是找寻成功的分支.

![success_message.png](https://blog.xorhex.com/content/images/2017/09/greek_to_me_success_no_flag.png)

从字符串往回分析, 我们发现一个在`0x40105E`处的比较, `eax`跟值`0xFB5E`进行比较.

![eax_comparison_check.png](https://blog.xorhex.com/content/images/2017/09/greek_to_me_comparison_check.png)

如果`eax`匹配成功, 那么随后程序就会继续执行*成功*分支. 所以我们该如何满足这个匹配呢?

来看看`sub_4011E6`函数内部. 我们看到一堆的`mov`,`add`,`shl`和`shr`指令, 这可能是某种形式的混淆. 让我们看看传入进函数的参数:

``` asm
.text:00401047 mov     eax, offset loc_40107C
.text:0040104C mov     [ebp+var_C], eax
.text:0040104F push    79h
.text:00401051 push    [ebp+var_C]
.text:00401054 call    sub_4011E6
```

第1个参数存储在`eax`寄存器中而第2个参数这是值`0x79`. 注意, `eax`包含的是`0x40107C`的偏移量而第2个参数`0x79`看起来很可能是一个表示长度的参数. 我们细细检查函数`sub_4011E6`就能证实这点. 也就是说程序即将修改如下所示的汇编代码片段.

![obfuscated_assembly_code.png](https://blog.xorhex.com/content/images/2017/10/greek_to_me_asm_snippet.png)

并没有变量传入解混淆代码, 所以猜测应该是需要某种形式的用户输入, 所以我们继续看.
来到下一个代码块, 我们看到相同的汇编代码区段`0x40107C`在传入函数`sub_4011E6之前`由`xor`和`add`指令进行修改.

![first_deobfuscation_routine.png](https://blog.xorhex.com/content/images/2017/09/greek_to_me_deob_round_one.png)

`xor`的值存储在`dl`, 而`dl`总是从`[ebp+buf]`赋值而来, 这看上去就可能是我们的用户输入了. 继续向上跟踪我们看到`[eax+buf]`则是作为参数传递给函数`sub_401121`

![sub_401121_call.png](https://blog.xorhex.com/content/images/2017/09/greek_to_me_follow_buf.png)

快速浏览函数`sub_401121`, 我们看到`0x4011BC`处设置了`[ebp+buf]`

![call_to_recv.png](https://blog.xorhex.com/content/images/2017/09/greek_to_me_buf_recv.png)

函数的剩余部分则仅仅只是服务器接受输入后的一些操作

总结一下收获:

* 找到了位于`0x4010FE`的成功提示字符串
* 比较检查在`0x40105E`处
	* 必须匹配`0xFB5E`才能进入成功验证分支
* 已混淆代码起始于`0x40107C`
* 已混淆代码的长度为`0x79`
* 第2阶段的解混淆函数在`0x401054`处被调用
* 第1阶段的解混淆操作从`0x401029`开始到`0x401045`
* 用户输入发生在`0x401015`处的函数调用
	* 用户输入来自网络
	* 输入缓冲区的长度是`0x4`

## 解答

在我们开始写脚本解答之前, 我们需要提取那些混淆过的字节出来.

这里我使用IDAPython脚本来提取字节

``` python
with open('greek_to_me_buffer.asm', 'wb') as f:
  f.write(idaapi.get_many_bytes(0x40107C, 0x79))
```

现在我们可以进入下一步, 写脚本!

### 用户输入

我们知道从网络接收的长度是4字节, 但是聪明的读者可能已经注意到代码中使用`dl`赋值给`buf`而非`edx`, 也就导致实际值的范围是从`0x0`到`0xff`(`dl`只有1字节大小). 我们脚本的开始部分类似如下:

``` python
for buf in xrange(0x100):
    print("Using {0}".format(buf))
```

## 暴力穷举

接下来我们需要修改提取出的比特使得通过比较检查. 我们需要通过解混淆的两部分.

## 解混淆第1步

对于第1次的解混淆(`0x401039`), 我们可以用python简单写一个"解码器".

``` python
    # Variable to store the bits written to disk using IDA
    asm = None
    # Store the output from the first de-obfuscation routine
    b2 = []
    # Read in bytes written to file from IDA
    with open('greek_to_me_buffer.asm', 'rb') as f:
        asm = f.read()

    # Re-implement loc_401039
    dl = buf
    for byte in b:
        bl = ord(byte)
        bl = bl ^ dl
        bl = bl & 0xff
        bl = bl + 0x22
        bl = bl & 0xff
        b2.append(bl)
```

要记住第1步解混淆操作应该放在for循环块中.

## 解混淆第2步

在`Angr`的帮助下, 我们可以继续按我们的方式进行第2阶段的解混淆, 虽然有点像作弊, 但谁又想用python或c重写一遍解混淆的代码呢?

在`for`循环之前一行声明一个`angr`工程实例, 这样它就不会在每次`for`循环执行时重新创建一遍.

``` python
p = angr.Project('greek_to_me.exe', load_options={'auto_load_libs': False})
```

设置Angr模拟执行`sub_4011E6`, 不过我们这次需要放到`for`循环里去.

``` python
    # Set up angr to "run" sub_4011E6 
    s = p.factory.blank_state(addr=0x4011E6)
    s.mem[s.regs.esp+4:].dword = 1    # Angr memory location to hold the xor'ed and add'ed bytes
    s.mem[s.regs.esp+8:].dword = 0x79 # Length of ASM

    # Copy bytes output from loc_401039 into address 0x1 so Angr can run it
    asm = ''.join(map(lambda x: chr(x), b2))
    s.memory.store(1, s.se.BVV(int(asm.encode('hex'), 16), 0x79 * 8 ))

    # Create a simulation manager...
    simgr = p.factory.simulation_manager(s)

    # Tell Angr where to go, though there is only one way through this function, 
    # we just need to stop after ax is set
    simgr.explore(find=0x401268)
```

虽然我意识到在这里使用Angr可能有点过犹不及, 但它是我手上最新的工具, 所以我所有的问题都以Angr的方式来解决.

## 输入合法性检查

接下来我们需要检查`ax`的输出是否匹配`0xFB5E`

``` python
    # Once ax is set, check to see if the value in ax matches the comparison value
    for found in simgr.found:
        print(hex(found.state.solver.eval(found.state.regs.ax)))
        # Comparison check
        if hex(found.state.solver.eval(found.state.regs.ax)) == '0xfb5eL':
            # Will cover what to do here in the next section
            pass
```

## 解混淆代码

现在我们已经满足了校验值匹配, 我们将解混淆的代码输出到屏幕上

``` 
�e�]��E�t�_�U��E�t�E�u�U��E�b�E�r�E�u�E�t�]߈U��E�f�E�o�E�r�E�c�]��E�@�E�f�E�l�E�a�E�r�]��E�-�E�o�E�n�E�.�E�c�E�o�E�m�E�
```

我们猜测这应该是汇编代码. 我们使用`Capstone`反编译代码.

``` python
from capstone import *
md = Cs(CS_ARCH_X86, CS_MODE_32)
for i in md.disasm(code, 0x1000):
    print("0x%x\t%s\t%s" %(i.address, i.mnemonic, i.op_str))
```

再次运行脚本, 我们可以确定这是汇编代码并且填充入缓冲区的内容里出现了ASCII字符.

``` asm
0x1000	mov	bl, 0x65	None
0x1002	mov	byte ptr [ebp - 0x2b], bl
0x1005	mov	byte ptr [ebp - 0x2a], 0x74
0x1009	mov	dl, 0x5f	None
0x100b	mov	byte ptr [ebp - 0x29], dl
0x100e	mov	byte ptr [ebp - 0x28], 0x74
0x1012	mov	byte ptr [ebp - 0x27], 0x75
0x1016	mov	byte ptr [ebp - 0x26], dl
0x1019	mov	byte ptr [ebp - 0x25], 0x62
0x101d	mov	byte ptr [ebp - 0x24], 0x72
0x1021	mov	byte ptr [ebp - 0x23], 0x75
0x1025	mov	byte ptr [ebp - 0x22], 0x74
0x1029	mov	byte ptr [ebp - 0x21], bl
0x102c	mov	byte ptr [ebp - 0x20], dl
0x102f	mov	byte ptr [ebp - 0x1f], 0x66
0x1033	mov	byte ptr [ebp - 0x1e], 0x6f
0x1037	mov	byte ptr [ebp - 0x1d], 0x72
0x103b	mov	byte ptr [ebp - 0x1c], 0x63
0x103f	mov	byte ptr [ebp - 0x1b], bl
0x1042	mov	byte ptr [ebp - 0x1a], 0x40
0x1046	mov	byte ptr [ebp - 0x19], 0x66
0x104a	mov	byte ptr [ebp - 0x18], 0x6c
0x104e	mov	byte ptr [ebp - 0x17], 0x61
0x1052	mov	byte ptr [ebp - 0x16], 0x72
0x1056	mov	byte ptr [ebp - 0x15], bl
0x1059	mov	byte ptr [ebp - 0x14], 0x2d
0x105d	mov	byte ptr [ebp - 0x13], 0x6f
0x1061	mov	byte ptr [ebp - 0x12], 0x6e
0x1065	mov	byte ptr [ebp - 0x11], 0x2e
0x1069	mov	byte ptr [ebp - 0x10], 0x63
0x106d	mov	byte ptr [ebp - 0xf], 0x6f
0x1071	mov	byte ptr [ebp - 0xe], 0x6d
0x1075	mov	byte ptr [ebp - 0xd], 0	
```
## 嵌入的ASCII字符

既然我们能够手动将上面汇编中可显字符的十六进制转换成字符, 我们为什么不用脚本来完成这一工作呢. 修改`for`循环:

``` python
bl = None
dl = None
flag = []
# Using capstone, interpret the ASM
from capstone import *
md = Cs(CS_ARCH_X86, CS_MODE_32)
for i in md.disasm(code, 0x1000):
    flag_char = None
    # The if statements do the work of interpreting the ASCII codes to their value counterpart
    if i.op_str.split(',')[0].startswith("byte ptr"):
        flag_char = chr(long(i.op_str.split(',')[1], 16))
    if i.op_str.split(',')[0].startswith('bl'):
        bl = chr(long(i.op_str.split(',')[1], 16))
    if i.op_str.split(',')[0].startswith('dl'):
        dl = chr(long(i.op_str.split(',')[1], 16))
    if i.op_str.split(',')[1].strip() == 'dl':
        flag_char = dl
    if i.op_str.split(',')[1].strip() == 'bl':
        flag_char = bl

    if (flag_char):
        flag.append(flag_char.strip())

    print("0x%x\t%s\t%s\t%s" %(i.address, i.mnemonic, i.op_str, flag_char))

print(''.join(flag))
```

最后运行脚本得到flag

```
et_tu_brute_force@flare-on.com
```

## 结论

总体上我们解决题目用的静态方法十分有趣, 同时也让我有机会首次在CTF竞赛中使用`Angr`和`Capstone`. 一开始我使用的是`Angr 6`来解决该问题, 但后来因为在CTF的中途`Angr`更新新版本, 所以写脚本的时候用的是`Angr 7`. 如果我随后使用了`Unicorn`引擎和`Angr`再次解决的话我会回来更新这篇文章.

完整的脚本代码你可以在这里找到: [greek_to_me_angr7.py](https://bitbucket.org/snippets/XOR_Hex/kByG75)