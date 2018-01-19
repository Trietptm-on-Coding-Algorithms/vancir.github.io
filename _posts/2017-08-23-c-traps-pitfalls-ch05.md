---
title: C陷阱与缺陷 - ch05
tags: [c/c++]
layout: post
categories: c/c++
---

# 第5章 库函数

## 5.1 返回整数的getchar函数

``` c
#include <stdio.h>
int main(int argc, char const *argv[]) {
  char c;
  while ((c = getchar()) != EOF) {
    putchar(c);
  }
  return 0;
}
```
这个程序乍一看似乎是把标准输入复制到标准输出, 实则不然. 原因在与程序中的变量c被声明为char类型, 而不是int类型. 这意味着无法容下所有可能的字符, 特别是, 可能无法容下EOF.
* 一种可能是, 某些合法的输入字符在被"截断"后使得c的取值与EOF相同
* 另一种可能是, c根本不可能取到EOF这个值

## 5.2 更新顺序文件

下面的程序片段似乎更新了一个顺序文件中选定的记录

```c
FILE *fp;
struct record rec;
...
while (fread((char*)&rec, sizeof(rec), 1, fp) == 1) {
  /* 对rec执行某些操作 */
  if (/* rec必须被重新写入 */) {
    fseek(fp, -(long)sizeof(rec), 1);
    fwrite((char*)&rec, sizeof(rec), 1, fp);
  }
}
```

这段代码看上去毫无问题, 但是代码仍然可能运行失败, 而且出错的方式非常难于察觉

问题处在: 如果一个记录需要重新被写入文件, 也就是说, fwrite函数得到执行, 对这个文件执行的下一个操作将是循环开始的fread函数. 因为在fwrite函数调用与fread函数调用之间缺少了一个fseek函数调用, 所以无法进行上述操作. 解决的办法如下:

``` c
while (fread((char*)&rec, sizeof(rec), 1, fp) == 1) {
  /* 对rec执行某些操作 */
  if (/* rec必须被重新写入 */) {
    fseek(fp, -(long)sizeof(rec), 1);
    fwrite((char*)&rec, sizeof(rec), 1, fp);
    fseek(fp, 0L, 1);
  }
}
```

## 5.3 缓冲输出与内存分配

下面程序的作用是把标准输入的内容赋值到标准输出中, 演示了setbuf库函数最显而易见的用法:
``` c
#include <stdio.h>
main(){
  int c;
  char buf[BUFSIZ];
  setbuf(stdout, buf);

  while ((c = getchar()) != EOF) {
    putchar(c);
  }
}
```
遗憾的是, 这个程序是错误的. 仅仅因为一个细微的原因.
我们不妨思考一下buf缓冲区最后一次被清空是在什么时候? 答案是在main函数结束之后, 作为程序交回控制给操作系统之前C运行时库所必须进行的清理工作的一部分. 但是, 在此之前buf字符数组已经被释放!

要避免这种类型的错误有两种办法
* 第一种办法是让缓冲数组成为静态数组, 既可以直接显式声明buf为静态`static char buf[BUFSIZ]`, 也可以把buf声明完全移到main函数之外
* 第二种办法是动态分配缓冲区, 在程序中并不主动释放分配的缓冲区
```c
char *malloc();
setbuf(stdout, malloc(BUFSIZ));
```

## 5.4 使用errno检测错误

很多库函数, 特别是那些与操作系统相关的, 当执行失败时会通过一个名称为errno的外部变量, 通知程序该函数调用失败.

``` c
/* 调用库函数 */
if(errno)
  /* 处理错误 */
```
这里的代码是错误的, 出错原因在于, 在库函数调用没有失败的情况下, 并没有强制要求库函数一定设置errno为0, 这样errno的值就可能是前一个执行失败的库函数设置的值.

因此在调用库函数时, 我们应该首先检测作为错误指示的安徽之, 确定程序执行已经失败, 然后再检查errno, 来搞清楚出错原因:

``` c
/* 调用库函数 */
if(返回的错误值)
  检查errno
```

## 5.5 库函数signal
