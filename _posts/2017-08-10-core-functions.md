---
title: Heap Exploitation系列翻译-05 Core functions
time: 2017-08-10
tags: [CTF, pwn, heap]
layout: post
categories: posts
---

# Core functions

> 本文是对Dhaval Kapil的[Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)系列教程的译文

## void * _int_malloc (mstate av, size_t bytes)

1. Updates `bytes` to take care of alignments, etc.
2. 检查`av`是否为NULL
3. 缺少可用arena的情况(`av = NULL`),会使用mmap方式调用`sysmalloc`来获得堆块，如果成功，则调用`alloc_perturb`返回堆块指针
4. * 如果堆块大小在fastbins范围内
     1. 根据申请的堆块大小在fastbins数组里获取一个指向合适bin的索引
     2. 移除那个bin中的第一个堆块并用`victim`指针指向它
     3. 如果`victim = NULL`，则退出继续到下一个情形(smallbin)
     4. 如果`victim != NULL`，则检查堆块大小，则检查堆块大小以确保它确实是属于要求的那个bin的，如果不符合，则抛出error("malloc(): memory corruption (fast)")
     5. 继续调用`alloc_perturb`并返回指针

   * 如果堆块大小在smallbin的范围内
     1. 根据申请的堆块大小，在smallbins数组中获取一个指向合适bin的索引
     2. 如果该bin中没有堆块，那么就退出继续到下一情形。这是通过比较指针`bin`和`bin->bk`来检查的
     3. 创建`victim`指针使等于`bin->bk`(bin中的最后一个堆块).如果它为NULL(在`初始化`过程中会发生这种情况), 就调用`malloc_consolidate`并跳过bins是否相同的检查
     4. 否则,当`victim != NULL`, 检查`victim->bk->fd`跟`victim`是否相等,如果不等,则抛出error("malloc(): smallbin double linked list corrupted")
     5. 为`victim`设置下一个堆块(内存意义上的,并非指双向链表中)的PREV\_INUSE位为1
     6. 从bin中移除该堆块
     7. 根据`av`为该堆块设置相应的arena位
     8. 调用`alloc_perturb`并返回堆块指针

   * 如果大小不在smallbin范围内
     1. 根据申请的堆块大小,在largebin数组中获取一个指向合适bin的索引
     2. 看`av`是否有fastchunks. 这是通过`av->flags`中的`FASTCHUNKS_BIT`位来进行检查的, 如果确实有fastchunks,那么就调用`av`中的`malloc_consolidate`

5. 如果到目前为止依旧没有任何指针返回, 那么只会是以下几种情形之一:
  1. 大小在fastbin范围内,但是没有fastchunk是可用的
  2. 大小在smallbin范围内,但是没有smallchunk是可用的(在初始化过程中调用`malloc_consolidate`)
  3. 大小在largebin范围内

6. 接下来, 检查unsorted chunks, 遍历bin中的各个堆块
  1. `victim`指针指向当前处理的堆块
  2. 检查`victim`的堆块大小是否在最小范围(`2*SIZE_SZ`)和最大范围(`av->system_mem`)之间, 不在范围内的话则抛出error("malloc(): memory corruption")
  3. 如果(申请堆块的大小在smallbin范围)并且(`victim`是last remainder chunl)并且同时(它是unsorted bin中唯一的堆块)同时(该堆块的大小>=所需求的大小)
    将该堆块分成两部分
     * 第一个堆块大小为所申请的大小并将其返回
     * 剩下的那块会成为新的last remainder chunk, 并插回到unsorted bin中:
       1. 为该堆块设置好对应的`chunl_size`和`chunk_prev_size`
       2. 在调用`alloc_perturb`后返回第一个堆块
  4. 如果上述情形都不满足, 进行如下控制. 在unsorted bin中移除`victim`, 如果`victim`的大小刚好满足所申请的堆块大小, 那么就在调用`alloc_perturb`后返回该堆块的指针
  5. 如果`victim`的大小在smallbin范围内, 那么就将该堆块添加到对应的smallbin的`首部`
  6. 不在smallbin范围内的话, 就将其插入到合适的largebin中并维持原有的排序顺序
    * 首先检查最后一个堆块(也是最小的). 如果`victim`小过这最后一个堆块, 那么就将其插入到最后
    * 不然, 循环遍历寻找一个大小恰好大于等于`victim`大小的堆块, 并将`victim`插入到这个堆块后面. 如果恰好相等, 则将其插入到第二个的位置上
  7. 重复这整个步骤最多`MAX_ITERS`(10000)次直到所有的堆块都插入到unsorted bin中合适的位置

7. 在检查完unsorted chunks, 检查需求的堆块大小是否不在smallbin范围内, 如果不在的话, 那么就将检查largebins
  1. 根据申请的大小, 从largebin数组中获取一个合适的bin的索引
  2. 如果最大的堆块大小(bin中的第一个堆块)大于我们所申请的大小
    1. 从链表尾部开始迭代, 直到找到一个大于等于申请大小的最小堆块`victim`
    2. 调用`unlink`移除bin中的`victim`堆块
    3. 为`victim`堆块计算`remainder_size`(`remainder_size`大小为`victim`的堆块大小减去所申请的堆块大小)
    4.如果`remainder_size >= MINSIZE`(包括头部在内的最小堆块大小), 那么就切分该该堆块成两部分. 否则, 返回整个`victim`. 将remainder chunk插入到unsorted bin中(插到尾部). 在unsorted bin中会检查`unsorted_chunks(av)->fd->bk`是否等于`unsorted_chunks(av)`. 不等的话抛出error("malloc(): corrupted unsorted chunks")
    5. 在调用`alloc_perturb`后返回`victim`堆块

8. 到目前为止, 我们以及检查了unsorted bin以及各个fastbin, smallbin以及largebin. 要注意的是我们会根据所申请的堆块大小来检查每个bin(fast或small), 重复以下步骤直到所有的bin都被检查完.
  1. bin数组的索引通过自增来检查下一个bin
  2. 使用`av->binmap`来跳过那些空的bin
  3. `victim`指向当前bin的尾部
  4. 使用binmap确保跳过的bin(在上述第二个步骤中)确实是空的. 然而这还不能确保所有的空白bin会被跳过, 还需要检查victim是否为空. 如果为空, 那么再次跳过该bin并重复以上步骤(或继续本次循环)直到到达一个非空的bin
  5. 切分堆块(`victim`指向非空bin中的最后一个堆块)成两部分, 将remainder chunk插入到unsorted bin中(插入到尾部). 在unsorted bin中胡检查`unsorted_chunks(av)->fd->bk`是否等于`unsorted_chunks(av)`, 如果不等,则抛出一个error("malloc(): corrupted unsorted chunks 2")
  6. 在调用`alloc_perturb`后返回`victim`堆块

9. 如果还是没能找到非空bin, 那么会使用top chunk来满足需求
  1. `victim`指向`av->top`
  2. 如果`size of top chunk >= requested size + MINSIZE`, 那么就将其分成两部分, 在这里, 剩下的remainder chun会变成新的`top chunk`, 另外一个chunk则会在调用`alloc_perturb`后返回给用户
  3. 观察`av`是否有fastchunks, 这是通过`av->flags`中的`FASTCHUNKS_BIT`来检查的. 如果有fastchunks, 就对`av`调用`malloc_consolidate`并返回到步骤6(我们检查unsorted bin的地方)
  4. 如果`av`没有fastchunks, 那么就调用`sysmalloc`并返回调用`alloc_perturb`获得的指针

## __libc_malloc (size_t bytes)

1. 调用`arena_get`来获得一个`mstate`指针
2. 使用指向arena的指针及arena的大小作参调用`_init_malloc`
3. 解锁arena
4. 在返回堆块指针之前, 以下所列之一应该为真
   * 返回指针是NULL
   * chunk是通过mmap映射得到的
   * arena的chunk会和1中找到的那个相同

## _int_free (mstate av, mchunkptr p, int have_lock)

1. 检查`p`在内存上是否在`p+chunksize(p)`之前(避免被覆写), 不然会抛出error("free(): invalid pointer")
2. 检查堆块的大小至少为`MINSIZE`或者是`MALLOC_ALIGNMENT`的倍数, 若不满足则抛出error("free(): invalid size")
3. 如果堆块大小在fastbin范围内:
   1. 检查下一个堆块的大小是否在最小值和最大值之间(`av->system_mem`), 不然抛出error(free(): invalid next size (fast)")
   2. 对chunk调用`free_perturb`
   3. 为`av`设置`FASTCHUNKS_BIT`位为1
   4. 根据堆块大小获取fastbin数组中的索引
   5. 检查确保bin的顶部不是我们将要添加的那个堆块, 否则抛出error("double free or corruption (fasttop)")
   6. 检查确保在顶部的fastbin堆块的大小跟我们所要添加的堆块大小相同, 否则抛出error("invalid fastbin entry (free)")
   7. 将该堆块插入到fastbin链表顶部并返回
4. 如果堆块不是通过mmap映射得到的
   1. 检查堆块是否是top chunk, 如果是则抛出error("double free or corruption (top)")
   2. 检查next chunk是否是在arena的范围内, 如果不在的话, 抛出error("double free or corruption (out)")
   3. 检查next chunk(内存意义上的)的`PREV_INUSE`位是否设置为1, 如果没有, 则抛出error("double free or corruption (!prev)")
   4. 检查next chunk的大小是否在最小值和最大值之间(`av->system_mem`), 如果不在, 则抛出error("free(): invalid next size (normal)")
   5. 对该堆块调用`free_perturb`
   6. 如果前一个堆块(内存意义上的)处于空闲状态, 则对这个前一个堆块调用`unlink`
   7.如果next chunk(内存意义上的)不是top chunk
      1. 如果next chunk处于空闲状态, 则对这个next chunk调用`unlink`
      2. 合并前后堆块(内存意义上的), 如果都是空闲状态, 则将其加入到unsorted bin的首部. 在插入之前, 会检查`unsorted_chunks(av)->fd->bk`是否等于`unsorted_chunks(av)`, 如果不等,则抛出error("free(): corrupted unsorted chunks")
   8. 如果next chunk(内存意义上的)是一个top chunk, 那么将该堆块适当地合并到top chunk去
5. 如果堆块是通过mmap映射得到, 则调用`munmap_chunk`

## __libc_free (void *mem)

1. 如果`mem`为NULL则返回
2. 如果相应的堆块通过mmap映射, 则会在需要调整动态brk/mmap阈的时候调用`munmap_chunk`
3. 为相应堆块获取arena指针
4. 调用 `_int_free`.
