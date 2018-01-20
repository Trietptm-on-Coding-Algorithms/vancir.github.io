---
title: yoda's protector脱壳思路
tags: [unpack]
layout: post
categories: crack
---

> 本文已发表在看雪论坛, 详情可见: [https://bbs.pediy.com/thread-223371.htm](https://bbs.pediy.com/thread-223371.htm)

yoda's protector主要有两个需要注意的反调试保护：阻塞设备输入和枚举进程pid并终止调试器

文中分析的程序你可以点击此处下载: [yoda_unpack.zip](http://od7mpc53s.bkt.clouddn.com/yoda_unpack.zip)

## 阻塞设备输入

yoda 使用`user32.dll`中的`BlockInput`来屏蔽所有的输入设备的消息，比如鼠标键盘。当设备被屏蔽时你无法进行任何操作，只有阻塞设备的线程或进程可以使用相同的API填入不同的参数来解锁它

yoda protector会在使用api阻塞设备后转向脱壳/解密的进程并执行一些反调试的技巧，在脱壳结束并且所有检查通过时，yoda才会解锁设备。

一个非常简单的方法可以解除阻塞，那就是patch掉`BlockInput`，让它什么都不做就返回。

当我们用od载入unpackme，我们可以看到内存中只载入了两个dll

![1.png](https://bbs.pediy.com/upload/attach/201712/722644_49fvu0ztysyfpol.jpg)

为了patch掉`BlockInput`，我们需要让user32.dll载入内存，在od选项中我们设置断在新的dll上

![2.png](https://bbs.pediy.com/upload/attach/201712/722644_do1yallmldttgfj.jpg)

然后我们继续F9，让user32.dll导入到内存

![3.png](https://bbs.pediy.com/upload/attach/201712/722644_sgaw7xerhm5h9ls.jpg)

随后我们就可以取消掉之前断在新dll的选项，然后跳到`BlockInput`的入口代码处

![4.png](https://bbs.pediy.com/upload/attach/201712/722644_2uc6govoj4w6et5.jpg)

![5.png](https://bbs.pediy.com/upload/attach/201712/722644_t8tfazaj0srm3p1.jpg)

`BlockInput`的api就是上图的灰色代码，`retn 4`就是结尾，我们只需要将所有这些代码填充为nop就行

![6.png](https://bbs.pediy.com/upload/attach/201712/722644_fvx6n0o1m9526hj.jpg)

这样，api就不会进行任何操作，我们的输入设备也不会被阻塞

## 枚举进程并终止调试器

yoda使用`CreateToolhelp32Snapshot`来获取所有正在运行的进程，然后yoda会搜索启动unpackme的进程是否和unpackme自己的进程PID是否相同，如果不同，那么yoda就会终止掉该进程(如od)。如果我们像先前一样patch掉`CreateToolhelp32Snapshot`，程序则会产生句柄非法(Invalid_Handle)异常。这里有另外一种方式来绕过保护。yoda使用`GetCurrentProcessId`来获取PID，因此我们可以控制返回的PID的值来迷惑保护代码。

比如我们启动unpackme的进程是Ollydbg.exe，我们就要让`GetCurrentProcessId`返回Ollydbg.exe的PID，这样检查就不会出现问题（而不是unpackme的PID）。

首先我们必须知道ollydbg.exe的PID，这点我们可以启动LordPE来轻松获得

![7.png](https://bbs.pediy.com/upload/attach/201712/722644_41esohgprhqad8p.jpg)

这里ollydbg.exe的PID是`0x4B4`，而unpackme的PID是`0x1CC`，我们要做的就是使得`GetCurrentProcessId`的返回结果是`0x4B4`

像之前一样，来到api的入口代码处

![8.png](https://bbs.pediy.com/upload/attach/201712/722644_ryflqoyrweunnft.jpg)

函数通过eax返回值，我们只需要修改eax即可

![9.png](https://bbs.pediy.com/upload/attach/201712/722644_y2qyqoqyajeca6i.jpg)

这样也就完成了。

在patch完后，还需要使用插件来隐藏Ollydbg（用HideOD等插件，避免`IsDebuggerPresent`的检查），之后的关键就是找OEP了。

## OEP查找

oep的查找我们可以使用最后一次异常法来跟踪，按下shift+F9的最后一次异常，在堆栈窗口中出现的SE Handler，本例中是`00413F50`，我们跟踪进去，在`00413F50`设下断点，然后按下Shift+F9到达断点处。我们要记得开启HideDebugger或类似插件的反`IsDebuggerPresent`的选项，否则在使用最后一次异常法时会退出OD和unpackme并且无法再点击任务栏和图标。

![10.png](https://bbs.pediy.com/upload/attach/201712/722644_57pyeg79zpd92q9.jpg)

然后在`00413F79`处的`00404000`就是我们的OEP了，dump出来修复IAT即可

![11.png](https://bbs.pediy.com/upload/attach/201712/722644_zyljdhg2gk9cypc.jpg)