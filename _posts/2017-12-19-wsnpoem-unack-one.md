---
title: zbot变种木马wsnpoem脱壳笔记 part 1
tags: [unpack, malware]
layout: post
categories: crack
---

> 本文已发表在看雪论坛, 详情可见: [https://bbs.pediy.com/thread-223393.htm](https://bbs.pediy.com/thread-223393.htm)

wsnpoem恶意程序是zbot木马家族的变种，经过加壳保护，我们接下来就来脱壳。

文中分析的程序你可以点击此处下载: [wsnpoem恶意样本par1.zip](http://od7mpc53s.bkt.clouddn.com/wsnpoem%E6%81%B6%E6%84%8F%E6%A0%B7%E6%9C%ACpar1.zip), 解压密码: www.pediy.com

OD载入`wsnpoem-with-rootkit.exe`

![1.png](https://bbs.pediy.com/upload/attach/201712/722644_qbbr1m7nonwqzv1.jpg)

这是wsnpoem解密的第一阶段，我们直接在`00409D41`的LEAVE处右键设下硬件执行断点，然后运行

![2.png](https://bbs.pediy.com/upload/attach/201712/722644_p04n73dz7ctkg1b.jpg)

然后我们选择菜单Debug->Hardware Breakpoint移除刚才设下的断点，向下翻到`00409EDA`处

![3.png](https://bbs.pediy.com/upload/attach/201712/722644_41o8mbtetorowfl.jpg)

我们在这行设下软件断点(F2)然后运行，停在断点处，我们取消掉这行的断点，按下Enter进入到跳转的分支去，向下翻到`00412449`处

![4.png](https://bbs.pediy.com/upload/attach/201712/722644_bhls9fg1tpzgp22.jpg)

在翻过了第2层解密后，`00412449`处所指向的`004051B7`便是我们的OEP，同样设下一个软件断点(F2)，然后运行，停在断点处，我们取消掉这行的断点，然后步入OEP

![5.png](https://bbs.pediy.com/upload/attach/201712/722644_gtg6fhxlz88dbb4.jpg)

然后向下一点，看到`0040523A`处，在数据窗口中转向0040FD34

![6.png](https://bbs.pediy.com/upload/attach/201712/722644_0ibdn05vvld4ps1.jpg)

可以看见，这里的这个call所调用的函数地址处是全零，这会造成程序的崩溃，因此我们可以推测在call以上的代码中有填充这个空间

我们现在边步过，边观察数据窗口中的`0040FD34`，看什么时候向该处填充了数据，可以很容易发现，在步过`004051D2`处的Call `0040AAD4`后，数据窗口中填充了许多的数据

![7.png](https://bbs.pediy.com/upload/attach/201712/722644_jts16y5tgegemhb.jpg)

那这样看来，`004051D2`处的`Call 0040AAD4`就是将所有的函数都导入到内存空间中，而我们的`0040FD34`则是导入表的一部分，因此我们可以右键重新将EIP设到OEP处。

向上翻看导入表空间，貌似可能的函数地址块，也就是我们的导入表头，是从`0040FB3C`开始

![8.png](https://bbs.pediy.com/upload/attach/201712/722644_bf1yd3nx4kx1rmy.jpg)

我们也可以在ascii块中右键选择Long->Address，这样数据窗口会以地址格式进行显示，方便我们查看导入表

![9.png](https://bbs.pediy.com/upload/attach/201712/722644_2qcxbblavdak0c1.jpg)

同样，我们向下翻看，查找导入表的结尾是在0040FEB8

![10.png](https://bbs.pediy.com/upload/attach/201712/722644_0coxb1a2x934ntg.jpg)

这样，找到了OEP，也有导入表信息，那么我们就可以用Ollydump+ImportREC来进行脱壳，如下，点击dump保存为dump.exe

![11.png](https://bbs.pediy.com/upload/attach/201712/722644_wkfsszb8fbtprvk.jpg)

打开ImportREC，选择正在运行的`wsnpoem-with-rootkit.exe`，然后在OEP、RVA和SIZE处填写好我们获得的信息，然后点击Get Imports

![12.png](https://bbs.pediy.com/upload/attach/201712/722644_h21scg5a8id4d36.jpg)

但显然，我们的导入表函数虽然有找到，但都是无效的。所以我们需要手动修复导入表函数，因为可能在导入表内混有一些垃圾地址，所以我们需要手动进行移除，比如第一个chunk中

![13.png](https://bbs.pediy.com/upload/attach/201712/722644_kbo2am16hx86q0i.jpg)

点击对应的shell32.dll右键显示反汇编，可以看到如下代码，显然不是一个正常的函数的代码，因此可以确定是垃圾地址。我们右键cut chunks

然后有的块显示反汇编提示read error，那么其实也是垃圾地址。依照类似的方法将所有的垃圾地址清除干净后，你就可以转储到文件，然后用IDA打开，你会发现壳已经脱干净并且导入函数也很清晰


