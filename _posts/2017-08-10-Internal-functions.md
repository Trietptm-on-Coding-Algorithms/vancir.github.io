---
title: Heap Exploitation系列翻译-05 Internal functions
time: 2017-08-10
tags: [CTF, pwn, heap]
layout: post
categories: posts
---

# Internal functions

> 本文是对Dhaval Kapil的[Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)系列教程的译文

这里将列出内部使用的一些常见函数，值得注意的是有些函数实际上直接使用`#define`进行定义，因此调用参数发生的变化实际上在调用结束后依然存在，并假定未设置MALLOC\_DEBUG

## arena_get (ar_ptr, size)

获得一块arena并锁定相应的互斥体。`ar_ptr`指向获得的相应arena，size`表示需要获得的内存大小。

## sysmalloc [TODO]

``` c
/*
   sysmalloc handles malloc cases requiring more memory from the system.
   On entry, it is assumed that av->top does not have enough
   space to service request for nb bytes, thus requiring that av->top
   be extended or replaced.
*/
```

## void alloc_perturb (char *p, size_t n)

如果`perturb_byte`(malloc使用`M_PERTURB`后的可变参数)非零(默认为0)，就会将`p`指向`n`字节设置为等于`perturb_byte` ^ 0xff

## void free_perturb (char *p, size_t n)

如果`perturb_byte`(malloc使用`M_PERTURB`后的可变参数)非零(默认为0)，就会将`p`指向`n`字节设置为等于`perturb_byte`

## void malloc_init_state (mstate av)

```c
/*
   Initialize a malloc_state struct.

   This is called only from within malloc_consolidate, which needs
   be called in the same contexts anyway.  It is never called directly
   outside of malloc_consolidate because some optimizing compilers try
   to inline it at all call points, which turns out not to be an
   optimization at all. (Inlining it in malloc_consolidate is fine though.)
 */
```

1. 对于非fastbins，会为每一个bin创建空的循环链表
2. 为`av`设置`FASTCHUNKS_BIT`标志位
3. 初始化`av->top`指向第一个unsorted chunk

## unlink(AV, P, BK, FD)

This is a defined macro which removes a chunk from a bin.

以下是从一个bin中移除chunk的简要定义

1. 检查chunk的size是否等于next chunk的prev_size，如果不等，则抛出error(corrupted size vs. prev\_size)
2. 检查`P->fd->bk == P ?` 以及 `P->bk->fd == P ?`，若不然，抛出error(corrupted double-linked list)
3. 调整了相邻堆块的前向指针(fd)和后向指针(bk)以便清除
  1. 设置`P->fd->bk` = `P->bk`
  2. 设置`P->bk->fd` = `P->fd`

## void malloc_consolidate(mstate av)

以下针对free()的特定版本

1. 检查`global_max_fast`是否为0(未初始化`av`时)，如果为0，则以`av`为参数调用`malloc_init_state`并返回。
2. 如果`global_max_fast`非零，则为`av`清除`FASTCHUNKS_BIT`标志
3. 从头至尾遍历fastbin数组：
  1. 如果非空，则锁定当前fastbin堆块并继续
  2. 如果前一个堆块(内存意义上的)处于空闲状态，则对前一个堆块进行`unlink`操作
  3. 如果后一个堆块(内存意义上的)不是top chunk：
    1. 如果后一个堆块处于空闲状态，则对后一个堆块进行`unlink`操作
    2. 如果前后两个堆块(内存意义上的)都处于空闲状态，那么前后两个堆块合并，并将合并后的堆块添加到unsorted bin的链表首部
  4. 如果下一个堆块(内存意义上的)是top chunk，则将堆块和top chunk合并

_注意_： 对于堆块是否处于空闲是根据`PREV_IN_USE`标志判断，因此，fastbin堆块并不会被认为是空闲状态。
