---
title: Heap Exploitation系列翻译-09 Double Free
tags: [CTF, pwn, heap]
layout: post
categories: translations
---


> 本文是对Dhaval Kapil的[Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)系列教程的译文

释放内存资源超过一次可以导致内存泄露. 分配器的数据结构会被损坏并且可以被攻击者利用漏洞. 在下面的示例程序中, 一块fastbin堆块被释放了两次. 现在, 为了避免glibc的`double free`及内存腐败安全检查, 我们在两次释放之间会释放另外一个堆块. 这也就暗示着两次不同的`malloc`可以返回同一块相同的堆块. 并且返回的指针指向同一个内存地址. 如果其中一个被攻击者控制, 那么他/她便可以为其他指针修改内存进而造成各种攻击(包括代码执行)

考虑以下示例代码:

```c
a = malloc(10);     // 0xa04010
b = malloc(10);     // 0xa04030
c = malloc(10);     // 0xa04050

free(a);
free(b);  // To bypass "double free or corruption (fasttop)" check
free(a);  // Double Free !!

d = malloc(10);     // 0xa04010
e = malloc(10);     // 0xa04030
f = malloc(10);     // 0xa04010   - Same as 'd' !
```

fastbin的状态变化如下:

1. 'a' freed.
  > head -> a -> tail
2. 'b' freed.
  > head -> b -> a -> tail
3. 'a' freed again.
  > head -> a -> b -> a -> tail
4. 'malloc' request for 'd'.
  > head -> b -> a -> tail      [ 'a' is returned ]
5. 'malloc' request for 'e'.
  > head -> a -> tail           [ 'b' is returned ]
6. 'malloc' request for 'f'.
  > head -> tail                [ 'a' is returned ]

现在, 'd'和'f'指针都指向同一个内存地址. 其中一个的任意改变都会影响到另外一个.

要注意, 这个例子对那些大小在smallbin范围内的堆块不适用. 在第一次释放时, 'a'的next chunk将会把'prev_inuse'标志设为0, 在第二次释放时, 会因为改标志为0而抛出error(double free or corruption (!prev)")
