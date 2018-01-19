---
title: Heap Exploitation系列翻译-07 Security Checks
tags: [CTF, pwn, heap]
layout: post
categories: translations
---

# Security Checks

> 本文是对Dhaval Kapil的[Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)系列教程的译文

下表总结了glibc实现中为了检查并组织堆相关攻击的安全检查.

| Function | Security Check | Error |
| --- | --- | --- |
| unlink | chunk size是否等于next chunk(内存意义上的)的prev_size | corrupted size vs. prev\_size |
| unlink | 检查是否`P->fd->bk == P` 以及 `P->bk->fd == P \*` | corrupted double-linked list |
| \_int\_malloc | 当移除fastbin的第一个堆块(以满足malloc要求)时, 检查chunk size是否在fast chunk的大小范围内 | malloc(): memory corruption (fast) |
| \_int\_malloc | 当移除smallbin的最后一个堆块(`victim`)时(以满足malloc要求), 检查`victim->bk->fd`是否等于`victim`|
| \_int\_malloc | 当迭代unsorted bin时, 会检查当前chunk的大小是否在最小值(`2*SIZE_SZ`)和最大值(`av->system_mem`)范围内| malloc(): memory corruption |
| \_int\_malloc | 当将last remainder chunk插入到unsorted bin中(在切分一块large chunk之后), 会检查是否`unsorted_chunks(av)->fd->bk == unsorted_chunks(av)` | malloc(): corrupted unsorted chunks |
| \_int\_malloc | 当将last remainder chunk插入到unsorted bin中(在切分一块fast chunk或small chunk之后), 检查是否`unsorted_chunks(av)->fd->bk == unsorted_chunks(av)` | malloc(): corrupted unsorted chunks 2 |
| \_int\_free | 检查`p \*\*`在内存中是否在`p+chunksize(p)`之前(以避免被覆写) | free(): invalid pointer |
| \_int\_free | 检查chunk大小是否至少为`MINISIZE`或是`MALLOC_ALIGNMENT`的倍数 | free(): invalid size |
| \_int\_free | 对于一个大小在fastbin范围内的chunk, 检查next chunk的大小是否在最小值和最大值(`av->system_mem`)之间 | free(): invalid next size (fast) |
| \_int\_free | 当插入fast chunk到fastbin(在`首部`)时, 检查fastbin中的首部chunk与即将插入的chunk不同 | double free or corruption (fasttop) |
| \_int\_free | 当插入fast chunk 到fastbin(首部)时, 检查已经在首部的chunk是否跟即将被插入的chunk相同 | invalid fastbin entry (free) |
| \_int\_free | 如果chunk不在fastbin的大小范围内, 也不是通过mmap映射得到的chunk, 检查该chunk是否为top chunk | double free or corruption (top) |
| \_int\_free | 检查next chunk是否在arena范围内 | double free or corruption (out) |
| \_int\_free | 检查next chunk的`PREV_INUSE`位是否为1 | double free or corruption (!prev) |
| \_int\_free | 检查next chunk的大小是否在最小值和最大值之间(`av->system_mem`) | free(): invalid next size (normal) |
| \_int\_free | 当插入合并后的chunk到unsorted bin时, 检查是否`unsorted_chunks(av)->fd->bk == unsorted_chunks(av)` | free(): corrupted unsorted chunks |

_\*: 'P' refers to the chunk being unlinked_

_\*\*: 'p' refers to the chunk being freed_
