---
title: zbot变种木马wsnpoem脱壳笔记 part 2
tags: [unpack, malware]
layout: post
categories: crack
---

> 本文已发表在看雪论坛, 详情可见: [https://bbs.pediy.com/thread-223401.htm](https://bbs.pediy.com/thread-223401.htm)

承接之前写的[zbot变种木马wsnpoem脱壳笔记 part 1](http://vancir.com/2017/12/19/wsnpoem-unack-one)，我们这次用另外一种方式来脱壳。并且本文还将分析另外两个恶意样本。

文中分析的程序你可以点击此处下载: [wsnpoem恶意样本par2.zip](http://od7mpc53s.bkt.clouddn.com/wsnpoem%E6%81%B6%E6%84%8F%E6%A0%B7%E6%9C%ACpart2.zip), 解压密码: www.pediy.com

OD重载`wsnpoem-with-rootkit.exe`，依然是之前的顺序，在`leave`处设下硬件断点后运行，让第1阶段的解密完成。然后删除设下的硬件断点，向下翻看。

不过这次我们就不会在`00409EDA`处的`jmp eax`下断了，我们再向下翻到`00409F26`处的`mov eax, 004051B7`，这句汇编代码下面是`call eax`，也就是说程序将要执行OEP处的代码。

![1.png](https://bbs.pediy.com/upload/attach/201712/722644_293sajegk0nty8q.jpg)

我们在`004051B7`设下硬件执行断点，然后执行断下，程序停在了OEP处，我们删除硬件断点

![2.png](https://bbs.pediy.com/upload/attach/201712/722644_5yn8m5tplxxrslg.jpg)

那么我们接下来的步骤就跟之前一样，运行步过`004051D2`处的`call 0040aad4`导入函数表，然后将EIP重设为`004051B7`。

之前用Ollydump+ImportREC我们手动cut chunks来修复导入表，这样不仅枯燥费力，而且还有可能误删正确的chunks导致修复失败，这次我们使用额外一个工具 - `Universial Import Fixer 1.0[Final]`，也就是`UIF`。这个工具可以为我们自动修复导入表，我们只需要将wsnpoem的进程id输入进去就可以。

在重设完EIP后，我们打开UIF，然后再通过在cmd里用`tasklist`命令查询到wsnpoem的pid，我的是`1816`，将其转为16进制，也就是`0x718`，填入到UIF的`Process ID`中，取消掉默认勾选的`Fix NtDll to Kernel32`，然后点击`Start UIF`就会帮你自动修复导入表并显示修复后的信息。这些信息我们等下用ImportREC是需要使用的，也就是下图的`IAT RVA`和`IAT Size`

![3.png](https://bbs.pediy.com/upload/attach/201712/722644_btjtwvp8rp1y074.jpg)

既然修复好了导入表，那么我们就可以用Ollydump将程序转储出来，记得在dump时要取消勾选`rebuild imports`，转储文件保存为dump.exe

![4.png](https://bbs.pediy.com/upload/attach/201712/722644_ondh0kf79s01zyz.jpg)

打开ImortREC，然后选择wsnpoem进程，输入OEP，并按照UIF修复给出的`IAT RVA`和`IAT Size`填入到ImportREC中

你可以看到导入表直接就是可用的，我们不需要手动修复导入表。我们就可以直接转储到文件就行了。IDA打开当然也是脱壳完成并且各导入函数清晰的。

当然，还是很麻烦，那有什么更好的方法吗.当然有，这里提供了一份ollydby的脚本，我们载入程序后运行脚本，就可以帮我们自动完成脱壳和修复导入表的步骤。

我们重新载入程序，然后点击插件中的ODbgScript->Run Script ... 然后选择`WSNPOEM-generic-unpacker.osc`

![5.png](https://bbs.pediy.com/upload/attach/201712/722644_576893isl4bzdqu.jpg)

一路向下点击过去，你也可以按下`Alt+L`来查看脚本脱壳过程的log

![7.png](https://bbs.pediy.com/upload/attach/201712/722644_b4iib9nf9huxiks.jpg)

脚本运行完成，显示ImportREC需要的信息

![8.png](https://bbs.pediy.com/upload/attach/201712/722644_ncagp9fmcryzpkj.jpg)

我们照之前的步骤将其填入到ImportREC, 转储到文件即可。

![9.png](https://bbs.pediy.com/upload/attach/201712/722644_enq628tp3i6twmz.jpg)

