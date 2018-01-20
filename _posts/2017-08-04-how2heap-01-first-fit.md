---
title: how2heap-01 first fit实践笔记
tags: [CTF, pwn, heap]
layout: post
categories: tutorials
---

> 本文是对shellphish的[how2heap](https://github.com/shellphish/how2heap)系列堆漏洞课程的实践笔记

## 示例源码

``` c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main()
{
	printf("This file doesn't demonstrate an attack, but shows the nature of glibc's allocator.\n");
	printf("glibc uses a first-fit algorithm to select a free chunk.\n");
	printf("If a chunk is free and large enough, malloc will select this chunk.\n");
	printf("This can be exploited in a use-after-free situation.\n");

	printf("Allocating 2 buffers. They can be large, don't have to be fastbin.\n");
	char* a = malloc(512);
	char* b = malloc(256);
	char* c;

	printf("1st malloc(512): %p\n", a);
	printf("2nd malloc(256): %p\n", b);
	printf("we could continue mallocing here...\n");
	printf("now let's put a string at a that we can read later \"this is A!\"\n");
	strcpy(a, "this is A!");
	printf("first allocation %p points to %s\n", a, a);

	printf("Freeing the first one...\n");
	free(a);

	printf("We don't need to free anything again. As long as we allocate less than 512, it will end up at %p\n", a);

	printf("So, let's allocate 500 bytes\n");
	c = malloc(500);
	printf("3rd malloc(500): %p\n", c);
	printf("And put a different string here, \"this is C!\"\n");
	strcpy(c, "this is C!");
	printf("3rd allocation %p points to %s\n", c, c);
	printf("first allocation %p points to %s\n", a, a);
	printf("If we reuse the first allocation, it now holds the data from the third allocation.");
}
```

## 漏洞分析

程序首先为`a`和`b`分别申请了`512bytes`和`256bytes`的空间，随后将字符串`"this is A!"`对空间`a`进行标记后将`a`释放，释放完`a`后又继续为`c`申请了`500bytes`的空间并将`"this is C!"`对`c`进行标记，最后将`a`和`c`的空间以及存储的字符串都打印出来。

接下来我们运行程序，看看结果如何，首先我们打印出`a`和`b`的地址

``` c
1st malloc(512): 0x602000
2nd malloc(256): 0x602210
```

这里我们会问，为什么我明明申请的`chunk`大小为`0x200`和`0x100`，可是从两个`chunk`之间的地址来看，第二个`chunk`的地址不应该是`0x602200`吗？多出来的`0x10`是什么呢？

其实这需要了解关于chunk的数据结构，我们在申请空间的时候，操作系统会给我们分配一个chunk，并返回给我们chunk的数据区的地址用作指针，但其实在chunk的数据区前，还有大小为`0x10`的chunk头信息，用于堆内存管理，因此我们会发现两者之间不单纯只是数据区而已～

我们这里也可以尝试用`libheap`来打印看看我们的堆空间

``` bash
gdb-peda$ heapls
           ADDR             SIZE            STATUS
sbrk_base  0x602000
chunk      0x602000         0x210           (inuse)
chunk      0x602210         0x110           (inuse)
chunk      0x602320         0x20ce0         (top)
sbrk_end   0x602000
```

接下来我们继续执行，直到`free(a)`

我们这时来看看堆的情况

``` bash
gdb-peda$ heapls
           ADDR             SIZE            STATUS
sbrk_base  0x602000
chunk      0x602000         0x210           (F) FD 0x7ffff7dd37b8 BK 0x7ffff7dd37b8 (LC)
chunk      0x602210         0x110           (inuse)
chunk      0x602320         0x20ce0         (top)
sbrk_end   0x602000
```

可以看见，第一个chunk的状态从inuse转变为freed，并且`libheap`帮我们打印出了`FD`和`BK`的值，这对我们分析很有帮助

接下来我们使用`freebins`来看看我们的chunk目前被收进了哪个bin中

``` bash
gdb-peda$ freebins

unsorted bin @ 0x7ffff7dd37c8
	free chunk @ 0x602000 - size 0x210
```

对于unsorted bin而言，无论多大的chunk都是可以被收进其中的，但是在过段时间后，glibc便会将其收录到其他的bin中，也可以说是一个暂住区

接下来继续执行，会对c申请一块空间，我们继续查看堆内存信息

``` bash
gdb-peda$ heapls
           ADDR             SIZE            STATUS
sbrk_base  0x602000
chunk      0x602000         0x210           (inuse)
chunk      0x602210         0x110           (inuse)
chunk      0x602320         0x20ce0         (top)
sbrk_end   0x602000
gdb-peda$ freebins


```

我们的第一个chunk的状态又变为了inuse状态，这说明了我们这个原先属于a并且被释放的chunk又被分配给了c，而`freebins`中也变得空空如也。那么继续执行，看最后`a`和`c`的地址如何

``` bash
3rd allocation 0x602010 points to this is C!
first allocation 0x602010 points to this is C!
```

结果表明，`a`和`c`同时指向了同一块区域。那么我们可以得到结论

> 当释放一块内存后再申请一块大小相近(略小于)的空间，那么glibc倾向于将先前被释放的空间分配回来

最后，我们用`villoc`来更形象地看下这整个过程的内存情况吧

![first_fit](http://od7mpc53s.bkt.clouddn.com/how2heap-first_fit.png)
