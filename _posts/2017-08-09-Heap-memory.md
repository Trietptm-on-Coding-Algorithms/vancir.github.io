---
title: Heap Exploitation系列翻译-01 Heap Memory
tags: [CTF, pwn, heap]
layout: post
categories: translations
---


## Heap memory

> 本文是对Dhaval Kapil的[Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)系列教程的译文

## What is Heap?

堆是操作系统分配给每个程序的一块内存区域，与栈不同，堆内存可以进行动态分配，也就是说程序可以在任何时候申请或释放堆段的内存。而且，这块内存是全局共享的，比你不仅可以在申请调用内存的函数中访问或修改它，在程序中的任何地方都可以。程序使用指针来指向动态申请的内存来实现这一效果，虽然相比使用局部变量会在性能上会稍有下降。

## Using dynamic memory

`stdlib.h` 提供了许多可供访问、修改和管理动态内存的标准库函数，常用的函数包括
 **malloc** and **free**:

```c
// Dynamically allocate 10 bytes
char *buffer = (char *)malloc(10);

strcpy(buffer, "hello");
printf("%s\n", buffer); // prints "hello"

// Frees/unallocates the dynamic memory allocated earlier
free(buffer);
```

文档中 'malloc' 和 'free' 有如下说明：

* **malloc**:

  ```c
  /*
    malloc(size_t n)
    Returns a pointer to a newly allocated chunk of at least n
    bytes, or null if no space is available. Additionally, on
    failure, errno is set to ENOMEM on ANSI C systems.

    If n is zero, malloc returns a minimum-sized chunk. (The
    minimum size is 16 bytes on most 32bit systems, and 24 or 32
    bytes on 64bit systems.)  On most systems, size_t is an unsigned
    type, so calls with negative arguments are interpreted as
    requests for huge amounts of space, which will often fail. The
    maximum supported value of n differs across systems, but is in
    all cases less than the maximum representable value of a
    size_t.
  */
  ```

* **free**:

  ```c
  /*
    free(void* p)
    Releases the chunk of memory pointed to by p, that had been
    previously allocated using malloc or a related routine such as
    realloc. It has no effect if p is null. It can have arbitrary
    (i.e., bad!) effects if p has already been freed.

    Unless disabled (using mallopt), freeing very large spaces will
    when possible, automatically trigger operations that give
    back unused memory to the system, thus reducing program
    footprint.
  */
  ```

重要的是标准库提供有这些内存分配函数，这些函数为开发者和操作系统能有效管理堆内存提供了中间层。开发者有必要在使用完分配的内存后立即‘free’释放它。从实质来看，这些函数都使用了两种系统调用[sbrk](http://man7.org/linux/man-pages/man2/sbrk.2.html)和[mmap](http://man7.org/linux/man-pages/man2/mmap.2.html)来申请或释放操作系统的堆内存。[这篇文章](https://sploitfun.wordpress.com/2015/02/11/syscalls-used-by-malloc/)则详细地介绍这些系统调用。
