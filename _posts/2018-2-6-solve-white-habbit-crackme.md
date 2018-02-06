---
title:  the White Rabbit CrackMe 解答
tags: [RE]
layout: post
categories: 
- crack
- translations
---

Crackme文件可以从此处下载: [White Rabbit crackme!](https://hshrzd.wordpress.com/2018/02/03/white-rabbit-crackme/) 

因为crackme里稍微使用了混淆和一些像恶意程序的把戏, 所以可能会被一些杀毒软件标记为恶意程序, 所以也建议在虚拟机下运行.

这个crackme运行的截图如下:

![1.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/1.png)

OK, 首先要做的第一件事就是将其载入到IDA中(我这里使用的是刚刚发布的[IDA 7的免费版本](https://www.hex-rays.com/products/ida/support/download_freeware.shtml)). 通过搜索字符串`Password#1`来看它的交叉引用以及前后都发生了些什么.

![2.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/2.png)

就这了! 我们可以看到它被`sub_4034D0`所引用. 现在我们将跟随到引用处, 来看看接下来发生什么

![3.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/3.png)

在`sub_403D90`中有一些初始化操作, 随后在`sub_404150`的结果与可疑值`0x57585384`的比较后又一个分支跳转. 子分支中的`sub_403990`输出了一些提示语以及后续一些有关接受用户输入的内容.

我们首先来看初始化部分(`sub_403D90`):

![4.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/4.png)

函数取了两个参数, 内容看上去也非常清楚: 通过给出的标识符查找资源文件, 加载资源文件, 确定它的文件大小, 然后申请内存空间并将资源文件的数据复制进去. 该函数返回那个新申请的内存空间的指针, 并将资源文件的大小存储在第一个参数中.

现在我们唯一需要注意的就是图中的`sub_406A70`, 它取了3个参数(target pointer, source pointer 以及 data size)并且看起来非常像是`memcpy`(或`memmove`, 是哪个不重要, 因为内存区域没有重叠). 但是函数内的代码却包含有大量的分支, 难以分析. 所以我们不能确定它有没有在复制的过程中以某种方式修改了数据(比如, 解密数据). 最简便的检查方式就是在调试器里动态分析, 比较函数返回时, `soure`和`target`内存是否有区别.

我使用`[x64Dbg](https://x64dbg.com/)`来分析. 在启动调试器后我们打开crackme, 调试器会自动运行程序并暂停在入口点位置.

![5.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/5.png)

现在我们需要在我们感兴趣的函数返回处设下一个断点. 指令地址是`0x00403DF9`(给定`.text`段的基址是`0x00401000`). 你可以根据内存布局来了解真正`.text`段载入的基址(我这里是`0x00281000`). 因此我的实际断点地址应该是`0x00283DF9`.

现在我们用`bp 0x00283DF9`命令设下断点, 继续执行触发断点. 然后我们右键点击右侧面板`ebx`和`edi`寄存器的值, 选择在数据窗口跟随. 现在我们就可以确认`sub_406A70`仅仅复制了内存`as is`, 我们可以放心地将该函数重命名为更易理解的`memcpy`. 同样我们也把`sub_403D90`重命名为`loadResource`

现在我们来分析`sub_404150`

![6.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/6.png)

映入眼帘的是一个常量`0x82F63B78`. 通过google搜索知道说这是一个用于CRC32计算的多项式值. 代码里看也有从输入缓冲区里对每个字节的值异或累加, 随后再移位/异或8次. 因此它确实是一个`crc32c`计算函数. 

在重命名和初期的分析后, 我们再来看看改动后的代码

![7.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/7.png)

注意: 也许你会对lea/cmovnb指令有些许困惑. 不过很好解释: `lpPasswordText`的值实际上是如下的结构体:

``` c
struct {
    union {
        char static[16];
        char *dynamic;
    }
    size_t length;
    size_t size;
}
```

这可能就是栈上`std::string`的形式. 当字符串仅有`static`数组那么长时, 不会申请额外的内存空间(并且`static`缓冲区的地址用`lea`加载). 相反如果超出了缓冲区, `cmovnb`会获取`dynamic`域所分配的内存的指针. 最后, `eax`会获得指向真正字符串数据的指针, 不论其位置具体在哪.

因此, `sub_401000`读取键盘输入到`std::string`, `std::string`随后传递给`crc32c`函数. 现在我们知道说我们的password应该含有CRC32的`0x57585384`, 我们可以根据这个条件判断我们是否获取到了正确的password.

现在我们来假定password跟给出的CRC32值相匹配, 来继续往下分析:

![8.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/8.png)

有趣的第一点就是`sub_403C90`, 因为它同时取了`password`和`资源数据`作为参数.

![9.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/9.png)

很显然这里是一个异或加密的操作. 它首先确定`password`的长度, 随后用相应的`password`字符对输入缓冲区的每一个字节进行异或.

随后生成一个临时文件名, 将解密的资源数据内容写入到该文件(在函数`sub_403090`里). 待一切完成, 却也再没有给出任何关于`password`的线索了. 我们来看一下`sub_403D20`, 该函数接收新创建的文件名并执行了一些操作. 

![10.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/10.png)

OK, 现在事情已经越发清晰. crackme尝试设置新生成的文件作为桌面壁纸, 因此很显然这个文件应该是一个图片.

现在我们要提取crackme里的资源文件, 看看我们能否有所收获. 你可以使用任意的资源编辑软件, 例如: [Resource Hacker](https://medium.com/@alexskalozub/solving-the-white-rabbit-crackme-d6b627c02ad4)

![11.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/11.png)

我们可以看到它的大小是`6,220,854`字节, 对于一个图像来说已经很大了, 据此我们猜测, 这是一个无压缩的BMP图像文件.

BMP格式已经是众所周知, 并且有文档说明. 文件起始于一个`"BM"`签名, 随后是`4字节`的文件大小(小端序), 接着是两个`4字节`的保留字(全0), 一个`4字节`存储着位图数据的起始位置, 再紧接着是`40字节`的位图信息头(起始的是该信息头所占用的字节数). 再下面就是各种关于BMP信息了, 我们现在也不知道.

由于我们得知了真正的文件大小值, 所以我们可以较准确地推测出文件的前18个字节.

``` 
资源文件里的字节:
24 22 5A 80 31 77 5F 64 61 5F 44 61 62 62 41 74 7A 66
期待的结果:
42 4D 36 EC 5E 00 00 00 00 00 36 00 00 00 28 00 00 00
```

现在我们逐个将实际资源文件里的字节和说期望的字节进行异或, 这样我们就可以恢复出部分key的内容. 如果幸运的话, 我们可以获得一个完整的key

``` 
66 6F 6C 6C 6F 77 5F 64 61 5F 72 61 62 62 69 74 7A 66
```

异或得到的结果是`"follow_da_rabbitzf"`. 最后的这一个`"f"`也许是重复的下一个key的起始字母, 也许就是这个key的一部分. 最简单的检查方法就是将其输入到crackme里看看结果如何.

![12.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/12.png)

Yeah. 我们的结果是正确的. 我们再继续.

现在我们有一个超酷的桌面壁纸, 然后还有另外一个`password`需要破解出来. 我们再次搜索`"Password#2"`字符串并跟随到交叉引用处:

![13.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/13.png)

这看起来跟之前非常相似, 因此我们自己向下来到解密开始的部分:

![14.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/14.png)

有趣的部分在`sub_403E10`, 这里在写入数据到文件之前进行了解密:

![15.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/15.png)

这里根据`password`导出一个`AES128`的密钥(使用`SHA256`作为密钥导出算法)并用于解密资源数据.

没有必要去破解AES加密(恐怕就连NSA也无法破解), 我们只知道`password`的crc32值. 很显然不足以通过暴力破解的手段来获取它(我尝试过!). 但等等, 我们有一个壁纸啊! 或许在壁纸里会有某些隐藏的信息!

用图像编辑器打开并使用"颜色选择"工具:

![16.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/16.png)

这应该就是我们一直在寻找的key! 接下来继续:

![17.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/17.png)

但是事情还没结束. 现在我们在临时目录下有一个解密过的可执行文件, 但我们还是没有拿到flag. 我们还需要用IDA继续分析.

因为第二个可执行文件按并没有产生任何字符串信息, 也就难以下手. 我们就来看看导入表情况:

![18.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/18.png)

这里有一系列的按顺序导入的`ws2_32.dll`的函数, 这给我们两个线索:

* 程序有在进行网络socket操作
* 程序有隐藏些什么!

因此我们的第一步就是去到这些函数被调用的地方, 并将这些函数重命名为可读性更高更有意义的名称. 序号与之对应的函数名称可以很容易地通过google搜索找到.

现在我们知道了所有的网络操作都在`sub_404480`里, 因此接下来仔细看看这个函数. 该函数开始是一个标准流程(`WSAStartup/socket/bind/listen`), 所以没太多亮点, 有趣的部分在下图:

![19.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/19.png)

因此它等待接受一个连接, 从连接中读取4字节, 基于静态缓冲区`buf`和接收的数据在`sub_404640`中执行一些操作. 如果操作成功转型(函数返回非零值), 它就会将`buf`的内容发回给客户端随后关闭连接. 否则它会关闭连接监听新的连接. 所有的操作都是同步的, 所以在`sub_404640`成功执行前不会退出函数.

来看看`sub_404640`的内容:

![20.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/20.png)

看起来非常像是一个小的状态机, 成功转移到下一状态时返回1, 有如下几个转移:

* 从 初始状态(0) 到 'Y' 状态 (如果接收到9)
* 从 'Y' 状态 到 'E' 状态 (如果接收到3)
* 从 'E' 状态 到 'S' 状态 (如果接收到5)
* 接收到其他的任何值, 都会将状态机重置为 初始状态(0)

因此, 我们可能需要按顺序发起3个连接, 连到`"server"`, 更新状态机到下一状态.

但是我们仍有两个问题需要解决:

1. 我们不知道需要连接到哪一个端口(函数需要取端口号作参数)
2. 在每次成功转移状态后, 监听的套接字都会关闭

因此我们需要找到所有的函数被调用的地方, 然后跟踪看它启动了哪一个端口.

如同我们所预料的那样, 函数被调用了3次(因为有3次合法的状态转移), 并且幸运的是, 它都是在同一个步骤里被调用的:

![21.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/21.png)

在这里

![22.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/22.png)

所以, server一开始开启了端口`1337`, 随后是`1338`, 最后是`1339`. 因此我们首先需要连接到`1337`端口并发送`9`, 然后连接到`1338`端口, 发送`3`. 最后连接到`1339`端口, 发送`5`. 我们可以使用内置的`telnet`工具来完成这一操作.

完成上述操作后会打开一个简短视频的YouTube页面:

![23.png](http://od7mpc53s.bkt.clouddn.com/white-rabbit/23.png)

我们成功地拿到了flag. 收工回家!
