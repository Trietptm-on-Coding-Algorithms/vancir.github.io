---
title: Heap Exploitation系列翻译-04 Bins and Chunks
tags: [CTF, pwn, heap]
layout: post
categories: translations
---

# Bins and Chunks

> 本文是对Dhaval Kapil的[Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)系列教程的译文

bin是一个由空闲(未分配)堆块组成的(双向或单向)链表。Bins根据所包含的区块大小进行区分：

1. Fast bin
2. Unsorted bin
3. Small bin
4. Large bin

Fast bins 使用一个包含各堆块指针的数组进行链接。

```c
typedef struct malloc_chunk *mfastbinptr;

mfastbinptr fastbinsY[]; // Array of pointers to chunks
```

Unsorted, small 和 large bins 同样使用一个简单数组进行链接

```c
typedef struct malloc_chunk* mchunkptr;

mchunkptr bins[]; // Array of pointers to chunks
```

在一开始的初始化过程中， small bins 和 large bins 都是空的

每一个bin在数组中都有两个值进行表示，一个是指向链表头(HEAD)的指针，另一个指向链表尾(TAIL)。而对于 fastbins (单向链表)，第二个指向链表尾(TAIL)的指针为空

## Fast bins


fastbins 划分为10个，其中每一个bins都是一个单向链表，并在链表首部进行插入和删除操作(先进后出)

每一个bins都包含着许多大小相同的堆块，这10个bins各自的堆块大小为：16, 24, 32, 40, 48, 56, 64, 72, 80 以及 88。这里所提及的大小是包括堆块的元数据的。存储堆块时可以节省4字节的空间(在指针长度为4字节的平台上)。因为对于已分配的堆块，`prev_size`和`size`作为元数据，而下一个相邻的堆块的`prev_size`则会用于存储用户数据。

相邻的两个空闲的 fast chunk 不会被合并

## Unsorted bin

仅有1个unsorted bin，small bin和large bin被释放后会加入到unsorted bin中。unsorted bin最初的意图是作为一个缓存层来加速堆块的分配和释放。

## Small bins

一共有62个small bins，small bins在分配上比large bins更快但慢于fastbins。每一个bins都是一个双向链表，在链表首部(HEAD)进行插入操作，在链表尾部(TAIL)进行删除操作(后进后出)

与fastbins类似，每一个bin都有着许多大小相同的堆块，这62个堆块的大小分别为：16, 24, ... , 504字节

当堆块被释放，small chunks会在链入unsorted bins前进行合并

## Large bins

一共有63个large bins，每一个bin都是一个双向链表，每一个large bin都有着不同的大小，以递减的顺序排列(比如，最大的堆块位于链表首部(HEAD),而最小的堆块在链表尾部(TAIL))。插入和删除操作都可以在链表的任意一个位置进行。

前32个bins包括的堆块都以64字节大小间隔

1st bin: 512 - 568 bytes
2nd bin: 576 - 632 bytes
.
.

总结一下就是如下这样

```
No. of Bins       Spacing between bins

64 bins of size       8  [ Small bins]
32 bins of size      64  [ Large bins]
16 bins of size     512  [ Large bins]
8 bins of size     4096  [ ..        ]
4 bins of size    32768
2 bins of size   262144
1 bin  of size what's left
```

和small chunks类似，当被释放时，large chunks会在链入unsorted bins之前进行合并

除上述介绍之外，还有两种特殊的堆块不属于任何一种bins中

## Top chunk

Top chunk是位于arena最顶端的堆块，用于malloc申请内存的最后途径，如果malloc需要更大的内存而 top chunk无法满足的话，那么top chunk就会通过使用 `sbrk`系统调用而变大来满足需求。Top chunk的`PREV_INUSE`标志总是被设置为1.

## Last remainder chunk

这是指那些分割后剩余的堆块。有时一个确定大小的堆块不可得时，会通过分割一个更大的堆块成两块来解决这个问题，其中一个返回给用户，而另一块就会成为last remainder chunk
