---
title: how2heap-02 fastbin-dup实践笔记
tags: [CTF, pwn, heap]
layout: post
categories: tutorials
---

> 本文是对shellphish的[how2heap](https://github.com/shellphish/how2heap)系列堆漏洞课程的实践笔记

## 示例源码

``` c
#include <stdio.h>
#include <stdlib.h>

int main()
{
	printf("This file demonstrates a simple double-free attack with fastbins.\n");

	printf("Allocating 3 buffers.\n");
	int *a = malloc(8);
	int *b = malloc(8);
	int *c = malloc(8);
  /* [1] */
	printf("1st malloc(8): %p\n", a);
	printf("2nd malloc(8): %p\n", b);
	printf("3rd malloc(8): %p\n", c);

	printf("Freeing the first one...\n");
	free(a);
  /* [2] */
	printf("If we free %p again, things will crash because %p is at the top of the free list.\n", a, a);
	// free(a);

	printf("So, instead, we'll free %p.\n", b);
	free(b);
  /* [3] */
	printf("Now, we can free %p again, since it's not the head of the free list.\n", a);
	free(a);
  /* [4] */
	printf("Now the free list has [ %p, %p, %p ]. If we malloc 3 times, we'll get %p twice!\n", a, b, a, a);
	printf("1st malloc(8): %p\n", malloc(8));
	printf("2nd malloc(8): %p\n", malloc(8));
	printf("3rd malloc(8): %p\n", malloc(8));
  /* [5] */
}
```

## 漏洞分析

程序首先向操作系统申请了3块大小为`8bytes`的内存，而后依次释放 `a` `b` `a`，再重新申请了3块大小依旧为`8bytes`的内存。我们通过巧妙地欺骗glibc的`free`操作从而可以泄露出一块已经被分配的内存指针

我们接下来用gdb来进行调试来看看具体的内存情况，首先我们执行到上面源码的`[1]`处，程序申请了3块内存，这时来看看堆的情况

``` bash
gdb-peda$ heapls
           ADDR             SIZE            STATUS
sbrk_base  0x602000
chunk      0x602000         0x20            (inuse)
chunk      0x602020         0x20            (inuse)
chunk      0x602040         0x20            (inuse)
chunk      0x602060         0x20fa0         (top)
sbrk_end   0x602000
```

可以看见，操作系统给我们分配了3个chunk，继续向下到`[2]`处，这时将chunk `a`释放

``` bash
gdb-peda$ heapls
           ADDR             SIZE            STATUS
sbrk_base  0x602000
chunk      0x602000         0x20            (inuse)
chunk      0x602020         0x20            (inuse)
chunk      0x602040         0x20            (inuse)
chunk      0x602060         0x20fa0         (top)
sbrk_end   0x602000
```

这时敲入`heapls`命令查看堆情况，但是却发现第一个chunk的状态依旧是`inuse`？为什么明明被释放了，状态却依旧没变呢？因为这是因为chunk的大小为`8bytes`，chunk `a`虽然被释放，但是被链入了`fastbins`里，而`fastbins`为了快速释放分配，并不会修改每个`chunk`的`PREV_INUSE (P)`，简称`P位`，因此我们看到的就是chunk `a`依旧是`inuse`的状态

我们可以敲入`freebins`和`fastbins`进行验证

``` bash
gdb-peda$ freebins
fast bin 0 @ 0x602000
	free chunk @ 0x602000 - size 0x20
gdb-peda$ fastbins
fastbins
[ fb 0 ] 0x7ffff7dd3768  -> [ 0x602000 ] (32)
[ fb 1 ] 0x7ffff7dd3770  -> [ 0x0 ]
[ fb 2 ] 0x7ffff7dd3778  -> [ 0x0 ]
[ fb 3 ] 0x7ffff7dd3780  -> [ 0x0 ]
[ fb 4 ] 0x7ffff7dd3788  -> [ 0x0 ]
[ fb 5 ] 0x7ffff7dd3790  -> [ 0x0 ]
[ fb 6 ] 0x7ffff7dd3798  -> [ 0x0 ]
[ fb 7 ] 0x7ffff7dd37a0  -> [ 0x0 ]
[ fb 8 ] 0x7ffff7dd37a8  -> [ 0x0 ]
[ fb 9 ] 0x7ffff7dd37b0  -> [ 0x0 ]
```

那么我们继续运行，到`[3]`的位置，这是将chunk `b`释放掉了，继续查看堆情况

``` bash
gdb-peda$ heapls
           ADDR             SIZE            STATUS
sbrk_base  0x602000
chunk      0x602000         0x20            (inuse)
chunk      0x602020         0x20            (inuse)
chunk      0x602040         0x20            (inuse)
chunk      0x602060         0x20fa0         (top)
sbrk_end   0x602000
gdb-peda$ fastbins
fastbins
[ fb 0 ] 0x7ffff7dd3768  -> [ 0x602020 ] (32)
                            [ 0x602000 ] (32)
[ fb 1 ] 0x7ffff7dd3770  -> [ 0x0 ]
[ fb 2 ] 0x7ffff7dd3778  -> [ 0x0 ]
[ fb 3 ] 0x7ffff7dd3780  -> [ 0x0 ]
[ fb 4 ] 0x7ffff7dd3788  -> [ 0x0 ]
[ fb 5 ] 0x7ffff7dd3790  -> [ 0x0 ]
[ fb 6 ] 0x7ffff7dd3798  -> [ 0x0 ]
[ fb 7 ] 0x7ffff7dd37a0  -> [ 0x0 ]
[ fb 8 ] 0x7ffff7dd37a8  -> [ 0x0 ]
[ fb 9 ] 0x7ffff7dd37b0  -> [ 0x0 ]
gdb-peda$ freebins
fast bin 0 @ 0x602020
	free chunk @ 0x602020 - size 0x20
	free chunk @ 0x602000 - size 0x20
```

我们可以发现，`free(b)`之后，chunk `b`被链入了`fastbins`中，但是chunk `b`被链进了`a`的前面，我们继续向下，到`[4]`处，再次将`a`释放，这时我们再选择打印`freebins`和`fastbins`会发现，一直在输出chunk `a`和chunk `b`，意思就是在`freebins`和`fastbins`中，chunk `a`和chunk `b`形成了一个循环

这是因为再次`free(a)`后，glibc重新将chunk `a`链入`fastbins`中并且位于chunk `b`之上，也就意味着形成了`[0x602000] -> [0x602020] -> [0x602000]`这样的循环

这时我们向下执行到`[5]`处，这时我们申请了3块内存

``` bash
1st malloc(8): 0x602010
2nd malloc(8): 0x602030
3rd malloc(8): 0x602010
```

我们看到，`fastbins`中最先将新加入的chunk `a`分配给用户，也即是`[0x602000] -> [0x602020] -> [0x602000]`的第一个`[0x602000]`
之后再申请相同空间，分配掉了加入的chunk `b`给用户，也就是`[0x602000] -> [0x602020] -> [0x602000]`中的第二个`[0x602020]`
最后第三次申请，分配回我们最先free掉的chunk `a`，也就是`[0x602000] -> [0x602020] -> [0x602000]`中第三个`[0x602000]`

那么我们可以得到结论

> 对于fastbins，我们通过double free泄露出一个堆块的指针

![fastbin-dup](http://od7mpc53s.bkt.clouddn.com/how2heap-fastbin_dup.png)
