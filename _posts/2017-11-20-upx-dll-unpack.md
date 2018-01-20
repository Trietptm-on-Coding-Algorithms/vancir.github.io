---
title: UPX 3.07 (Unpacking + DLL + Overlay) 脱壳笔记
tags: [unpack]
layout: post
categories: crack
---
Upx作为入门级的简单压缩壳，脱壳方法其实很简单。这里主要介绍的是使用`ImportREC手动脱壳`以及`Dll脱壳`。

## ImportREC手动脱壳

我们常用的ImportREC脱壳是使用的软件自带的`IAT auto search`，但是如果我们要手动查找IAT的地址并dump出来，又该怎么操作呢？

首先使用ESP定律，可以很快地跳转到`OEP: 00401110`。

![1.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-1.png)

我们右键点击，选择`查找->所有模块间的调用`

![2.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-2.png)

显示出调用的函数列表，我们双击其中的某个函数(注意这里要双击的应该是程序的函数而不是系统函数)

![3.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-3.png)

我们来到了函数调用处

![4.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-4.png)

右键点击`跟随`，进入函数

![5.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-5.png)

然后再右键点击`数据窗口中跟随->内存地址`

![6.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-6.png)

这里因为显示是十六进制值，不方便查看，我们可以在数据窗口点击右键选择`长型->地址`，就可以显示函数名

![7.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-7.png)

注意我们要向上翻到IAT表的起始位置，可以看到最开始的函数地址是`004050D8`的`kernel.AddAtomA`, 我们向下找到最后一个函数，也就是`user32.MessageBoxA`函数，计算一下整个IAT表的大小。在OD的最下方有显示`块大小：0x7C`，所以我们整个IAT块大小就是`0x7C`

![8.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-8.png)

打开`ImportREC`，选择我们正在调试的这个程序，然后分别输入`OEP：1110, RVA:50D8, SIZE:7C`，然后点击`获取输入表`

![9.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-9.png)

这里在输入表窗口中右键选择`高级命令->选择代码块`。

![10.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-10.png)

然后会弹出窗口，选择完整转储，保存为`dump.exe`文件

![11.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-11.png)

dump完成后，选择`转储到文件`，这里选择修复我们刚刚dump出的dump.exe，得到一个dump_.exe。这时整个脱壳就完成了

## DLL脱壳

为什么要谈到上面的ImportREC手动脱壳呢？因为Dll脱壳需要这一步骤。Dll脱壳的最关键的步骤在于`LordPE修改其Dll的标志`，用`LordPE`打开`UnpackMe.dll`，然后在特征值那里点击`...`，然后取消勾选`DLL`标志，保存后，那么系统就会将该文件视作一个可执行文件。

![12.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-12.png)

我们将`UnpackMe.dll`后缀名改成`UnpackMe.exe`，然后用OD载入。

![13.png](http://od7mpc53s.bkt.clouddn.com/upx-dll-unpack-13.png)

一般在入口点，程序都会保存一些信息，这里就很简单，只作了一个cmp。要注意的一点是，这里的jnz跳转直接就跳到了Unpack的末尾，因此我们需要修改寄存器的`z`标志来使得跳转失效。同时在unpack的末尾设下一个断点以避免脱壳完直接运行。

Dll脱壳的基本步骤跟exe文件脱壳一样，只是要注意，在脱壳完dump后，要记得用LordPE把`DLL`标志恢复过来。