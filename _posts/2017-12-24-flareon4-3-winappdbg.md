---
title: 使用WinAppDbg解决Flareon第3题
tags: [RE,flareon]
layout: post
categories: 
- crack
- translations
---

> 本文已发表在看雪论坛, 详情可见: [https://bbs.pediy.com/thread-223525.htm](https://bbs.pediy.com/thread-223525.htm)

文章作者: Parsia's Den

博客地址: [https://parsiya.net/](https://parsiya.net/)

原文链接: [WinAppDbg - Part 4 - Bruteforcing FlareOn 2017 - Challenge 3](https://parsiya.net/blog/2017-11-15-winappdbg---part-4---bruteforcing-flareon-2017---challenge-3/#bruteforcing-in-action)

翻译前言: 这是解决Flareon4第3题的第4种方法, 也是这个系列翻译的完结篇. 作者用的WinAppDbg跟ODScript有类似的感觉, 虽然不及之前2篇让人耳目一新, 但这是作者对于WinAppDbg写的简易教程的第4篇, 如果感兴趣可以点击原文链接从其它3篇WinAppDbg的教程开始阅读. 

ps: 程序可以从附件下载, 程序可能会报毒但是安全的, 建议在虚拟机下操作, 解压密码: www.pediy.com

如果朋友想看我之前翻译的用其他3种全新的方法解决该题的文章, 可以点击以下链接:

1. [Flareon challenge 4 第3题](http://vancir.com/2017/12/21/flareon4-3/)
2. [使用libPeConv来解决Flareon4题目3](http://vancir.com/2017/12/22/flareon4-3-libpeconv/)
3. [使用Angr解决Flareon4题目3](http://vancir.com/2017/12/23/flareon4-3-angr/)

## 侦查

首先我们要运行`strings`程序分析文件. 在Windows我喜欢从以下两种方式获取`strings`

* 从Cygwin的binutils包获取strings
* 从微软Sysinternals套件获取strings
运行`strings`我们获得下图:
* `-nobanner`: 不要显示启动时的标语和版权信息
* `-o`: 打印字符串偏移(如果想要找寻字符串地址这会很有帮助)

``` 
PS > .\SysinternalsSuite\strings.exe -o -nobanner .\3-GreektoMe\greek_to_me.exe
0077:!This program cannot be run in DOS mode.
0176:Rich
0432:.text
0472:.rdata
...
1584:Nope, that's not it.
1608:Congratulations! But wait, where's my flag?
1652:127.0.0.1
1752:WS2_32.dll
```

`ws2_32.dll`是Windows套接字库, 故程序中有着网络活动.

说个有趣的题外话, 当我在搜索这个DLL时我发现以下这个链接:

* [Is Your Windows “ws2_32.dll” File Safe?](https://nakedsecurity.sophos.com/2009/10/12/windows-ws232dll-file-safe/)

回归正题, `127.0.0.1`表明程序有网络活动, 表明它尝试连接或监听本地端口.

为了进一步探明, 我们运行`procmon`或`wireshark`

* Procmon过滤条件:
	* 进程名是`greek_to_me.exe`
	* 操作是`TCP/UDP`连接
* Wireshark:
	* 使用npcap抓取Windows回环流量
	* [https://wiki.wireshark.org/CaptureSetup/Loopback](https://wiki.wireshark.org/CaptureSetup/Loopback)

什么都没有显示. 故程序是在进行本地监听. 

运行程序并以管理员身份运行命令行, 输入`netstat -anb`.

```
 TCP    127.0.0.1:2222         0.0.0.0:0              LISTENING       5816
[greek_to_me.exe]
```

程序正在监听本地端口2222

## 简短分析

程序监听端口2222, 当接收到数据, 它使用了我们输入的第1个字节(也就只用了第1个字节). 如下所示:

``` asm
.text:00401029 loc_401029:      ; CODE XREF: sub_401008+1A
.text:00401029          mov     ecx, offset loc_40107C
.text:0040102E          add     ecx, 79h
.text:00401031          mov     eax, offset loc_40107C
.text:00401036          mov     dl, [ebp+buf]   ; first byte of input moved to dl
```

现在dl指向着我们发送给socket的第1个字节

``` asm
.text:00401039 loc_401039:      ; CODE XREF: sub_401008+3D
.text:00401039          mov     bl, [eax]   ; bl = grab a byte from blob
.text:0040103B          xor     bl, dl      ; bl = blob_byte xor our_first_byte
.text:0040103D          add     bl, 22h     ; bl += 0x22
.text:00401040          mov     [eax], bl   ; *eax = bl
.text:00401042          inc     eax         ; eax++ (next char)
.text:00401043          cmp     eax, ecx    ; ecx is the address of the second section
.text:00401045          jl      short loc_401039 ; check if we have reached the next section
```

它抓取了一些数据(准确说是`0x79`或121字节), 使用我们的第1个字节跟其异或随后加上`0x22`. 取出的数据则是位于`loc40107C`偏移处的十六进制块.

``` asm
33 E1 C4 99 11 06 81 16 F0 32 9F C4 91 17 06 81
14 F0 06 81 15 F1 C4 91 1A 06 81 1B E2 06 81 18
F2 06 81 19 F1 06 81 1E F0 C4 99 1F C4 91 1C 06
81 1D E6 06 81 62 EF 06 81 63 F2 06 81 60 E3 C4
99 61 06 81 66 BC 06 81 67 E6 06 81 64 E8 06 81
65 9D 06 81 6A F2 C4 99 6B 06 81 68 A9 06 81 69
EF 06 81 6E EE 06 81 6F AE 06 81 6C E3 06 81 6D
EF 06 81 72 E9 06 81 73 7C
```

![xor_add.png](https://parsiya.net/images/2017/winappdbg-4/01-crypto.png)

随后修改的数据块(在异或和加法操作后)传递给`sub_4011E6`并继续处理:

``` asm
.text:00401047          mov     eax, offset loc_40107C  ; eax = *modified_blob
.text:0040104C          mov     [ebp+var_C], eax        ; varC = eax
.text:0040104F          push    79h                     ; length of modified_blob
.text:00401051          push    [ebp+var_C]
.text:00401054          call    sub_4011E6              ; sub_4011E6(*modified_blob, 0x79)
.text:00401059          pop     ecx
.text:0040105A          pop     ecx
.text:0040105B          movzx   eax, ax
.text:0040105E          cmp     eax, 0FB5Eh ; compare return value with 0xFB5E

.text:00401063          jz      short loc_40107C
.text:00401065          push    0               ; flags
.text:00401067          push    14h             ; len
.text:00401069          push    offset buf      ; "Nope, that's not it."
.text:0040106E          push    [ebp+s]         ; s
.text:00401071          call    ds:send
.text:00401077          jmp     loc_401107
```

`sub_4011E6`的返回值跟`0xFB5E`进行比较, 如果不匹配, `jz`跳转将不会实现并继续执行, 程序也会传回来`Nope, that's not it.`.

![nope.png](https://parsiya.net/images/2017/winappdbg-4/02-result-comparison.png)

现在就变得越发有趣了. 如果结果匹配, 它就会跳转到我们刚刚修改过的数据块并试图将其作为代码执行. 如果程序没有崩溃且运行到结尾, 那么它就会发送回来`Congratulations!`.

换句话说, 我们输入的第1个字节就是用来将那数据块转换成正确的汇编操作码.

现在我们应该用另外一种方式来解决该题. 我想所有人都会用打开套接字, 发送256个可能字节并查看结果的方法来解决它. 这确实可以解决这个问题.

## 使用WinAppDbg暴力穷举

我使用另外一种方法解决. 复现这个方法我们需要了解一点点WinAppDbg的知识. 

## WinAppDbg设置断点

WinAppDng允许我们在任意地址设置断点:

``` python
debug.break_at(pid, address, action_callback)

def action_callback(event):
    # do something
```

当断点触发, `action_callback`函数就会被调用

更多信息请看: 

* [Documentation - Example #11: setting a breakpoint](https://winappdbg.readthedocs.io/en/latest/Debugging.html?highlight=break_at#example-11-setting-a-breakpoint)
* [breakpoint.py source code](https://github.com/MarioVilas/winappdbg/blob/master/winappdbg/breakpoint.py#L3905)

## 获取和设置内存

WinAppDbg运行我们存储/恢复内存和上下文

* 获取内存: `memory = process.take_memory_snapshot()`
	* [take_memory_snapshot 源码](https://github.com/MarioVilas/winappdbg/blob/master/winappdbg/process.py#L3261) 
* 设置内存: `process.restore_memory_snapshot(memory, bSkipMappedFiles=True)`
	* [restore_memory_snapshot 源码](https://github.com/MarioVilas/winappdbg/blob/master/winappdbg/process.py#L3301)
	* 通常来说, 请总是保持`bSkipMappedFiles`为`True`, 否则你会得到一个内存地址错误
		* [Explanation of bSkipMappedFiles in source](https://github.com/MarioVilas/winappdbg/blob/master/winappdbg/process.py#L3317)

##  获取和设置上下文

上下文包含寄存器和各种标志值, 是逐线程(而非逐进程的)

* 获取上下文: `context = thread.get_context()`
	* [get_context 源码](https://github.com/MarioVilas/winappdbg/blob/master/winappdbg/thread.py#L469)
	* 处理上下文中的寄存器:
		* `context["Edx"] = 0x1234`
* 设置上下文: `thread.set_context(context)`
	* [set_context 源码](https://github.com/MarioVilas/winappdbg/blob/master/winappdbg/thread.py#L570)

注意: 在设置完上下文后, 我们需要手动修改指令指针指向一个开始执行的具体位置. 比如说如果我们获取了上下文, 改变`Eip`指向一个地址, 实际的指令指针并不会变化. 我们在设置完上下文后, 需要使用`thread.set_pc(address)`手动将指令指针改成你需要的地址. 

在进行内存和上下文的操作时, 请确保事先暂停了程序/线程, 在操作完成后再恢复. 

## 作战计划

现在我们有了建筑模块, 我们需要制定一个作战计划. 非常简单明了.

1. 运行程序
2. 在`0x401036`和`0x40105B`设置断点
3. 打开socket并发送任何可能的字节
4. 在`0x401036`的断点
	* 如果是第1次触发断点:
		* 保存内存,上下文和`0x40107C`的数据块
	* `context["Edx"] = key` - 交换key值
	* key++
	* 绕过key的赋值指令并使用`thread.set_pc(0x401039)`手动跳转到`0x401039`	
5. 在`0x40105B`的断点:
	* 如果函数返回值是`0xFB5E`, 则打印key值
	* 否则:
		* 复原内存, 上下文和`0x40107C`处的数据块(数据块已经被修改过了, 因此这里需要复原成原来的字节)
		* 使用`thread.set_pc(0x401036)`返回到`0x401036`

![plan.png](https://parsiya.net/images/2017/winappdbg-4/03-bruteforcer-1.png)

改变`buf`中第1个字节会比`edx`中更简单些, 而且能够避免途中标签2对应的跳转. 

## 开始暴力穷举

我们使用的脚本是[`19-GreekToMe.py`](https://github.com/parsiya/Parsia-Clone/blob/master/code/winappdbg/19-GreekToMe.py), 你需要将`greek_to_me.exe`放在脚本的同一目录下, 该程序可以在附件里下载.

脚本运行非常快,因为我们的穷举空间仅仅只有1字节(0x00到0xFF)

```
$ python 19-GreekToMe.py
[21:23:48.0743] Starting simple_debugger
[21:23:48.0753] Started simple_debugger. Sleeping for 2 seconds.
[21:23:50.0756] Starting send_me.
[21:23:50.0875] Socket connected
[21:23:50.0875] Sent 0
[21:23:53.0490]
-------------------------------------------------------------------------------
Key: 0xa2
Eax: 0000FB5E
[21:23:54.0901] Reached 0x100
```

## Flag

重新在调试器中运行程序, 在"Congratulations!"处设下断点然后重新发送`0xA2`, 数据块正确解密, 我们也获得了flag

*flag: et_tu_brute_force@flare-on.com*
