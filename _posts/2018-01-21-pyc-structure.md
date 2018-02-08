---
title: pyc文件结构
tags: [RE]
layout: post
categories: 
- python
- translations
---

> 原文链接: [The structure of .pyc files](https://nedbatchelder.com/blog/200804/the_structure_of_pyc_files.html)

简单来说, 一个pyc文件包含以下三块
* 一个4字节的魔数(magic number)
* 一个4直接的修改时间戳(modification timestamp)
* 一个编排过的代码对象

对于各个版本的python解释器, magic number都各不相同, 对于python 2.5则是`b3f20d0a`

修改时间戳则是源文件生成.pyc文件的Unix修改时间戳, 当源文件改变的时候, 该值也会变化

整个文件剩下的部分则是在编译源文件产生的代码对象编排后的输出. marshal跟python的pickle类似, 它对python对象进行序列化操作. 不过marshal和pickle的目标不同. pickle目的在于产生一个持久的独立于版本的序列化, 而marshal则是为了短暂地序列化对象, 因此它的表示会随着python版本二改变.

而且, pickle被设计用于适用用户定义的类型, 而marshal这时用于处理python内部类型的复杂结构

marshal的特性给出了pyc文件的重要特征: 它对平台独立, 但依赖于python版本. 一个2.4版本的pyc文件不能在2.5版本下执行, 但是它可以很好地移植到不同操作系统里.

接下来的部分也简单: 对于两个长整数和一个marshalled的代码对象, 复杂点在于代码对象的结构. 它们包含有编译器禅师的各种信息, 其中内容最丰富的这是字节码本身.

所幸有了marshal和dis模块, 编写程序导出这些信息并不会很难. 

``` python
import dis, marshal, struct, sys, time, types

def show_file(fname):
    f = open(fname, "rb")
    magic = f.read(4)
    moddate = f.read(4)
    modtime = time.asctime(time.localtime(struct.unpack('L', moddate)[0]))
    print "magic %s" % (magic.encode('hex'))
    print "moddate %s (%s)" % (moddate.encode('hex'), modtime)
    code = marshal.load(f)
    show_code(code)
     
def show_code(code, indent=''):
    print "%scode" % indent
    indent += '   '
    print "%sargcount %d" % (indent, code.co_argcount)
    print "%snlocals %d" % (indent, code.co_nlocals)
    print "%sstacksize %d" % (indent, code.co_stacksize)
    print "%sflags %04x" % (indent, code.co_flags)
    show_hex("code", code.co_code, indent=indent)
    dis.disassemble(code)
    print "%sconsts" % indent
    for const in code.co_consts:
        if type(const) == types.CodeType:
            show_code(const, indent+'   ')
        else:
            print "   %s%r" % (indent, const)
    print "%snames %r" % (indent, code.co_names)
    print "%svarnames %r" % (indent, code.co_varnames)
    print "%sfreevars %r" % (indent, code.co_freevars)
    print "%scellvars %r" % (indent, code.co_cellvars)
    print "%sfilename %r" % (indent, code.co_filename)
    print "%sname %r" % (indent, code.co_name)
    print "%sfirstlineno %d" % (indent, code.co_firstlineno)
    show_hex("lnotab", code.co_lnotab, indent=indent)
     
def show_hex(label, h, indent):
    h = h.encode('hex')
    if len(h) < 60:
        print "%s%s %s" % (indent, label, h)
    else:
        print "%s%s" % (indent, label)
        for i in range(0, len(h), 60):
            print "%s   %s" % (indent, h[i:i+60])

show_file(sys.argv[1])
```

我们使用这段代码, 来处理一个极简单的python文件生成的pyc文件:

``` python
a, b = 1, 0
if a or b:
    print "Hello", a
```

产生的结果如下: 

```
magic b3f20d0a
moddate 8a9efc47 (Wed Apr 09 06:46:34 2008)
code
   argcount 0
   nlocals 0
   stacksize 2
   flags 0040
   code
      6404005c02005a00005a0100650000700700016501006f0d000164020047
      65000047486e01000164030053
  1           0 LOAD_CONST               4 ((1, 0))
              3 UNPACK_SEQUENCE          2
              6 STORE_NAME               0 (a)
              9 STORE_NAME               1 (b)

  2          12 LOAD_NAME                0 (a)
             15 JUMP_IF_TRUE             7 (to 25)
             18 POP_TOP
             19 LOAD_NAME                1 (b)
             22 JUMP_IF_FALSE           13 (to 38)
        >>   25 POP_TOP

  3          26 LOAD_CONST               2 ('Hello')
             29 PRINT_ITEM
             30 LOAD_NAME                0 (a)
             33 PRINT_ITEM
             34 PRINT_NEWLINE
             35 JUMP_FORWARD             1 (to 39)
        >>   38 POP_TOP
        >>   39 LOAD_CONST               3 (None)
             42 RETURN_VALUE
   consts
      1
      0
      'Hello'
      None
      (1, 0)
   names ('a', 'b')
   varnames ()
   freevars ()
   cellvars ()
   filename 'C:\\ned\\sample.py'
   name '<module>'
   firstlineno 1
   lnotab 0c010e01
```

有很多内容我们都不明白, 但是字节码却很好地被反汇编并呈现了出来. python虚拟机是一个面向栈的解释器, 因此有许多操作都是load和pop, 并且当然也有很多jump和条件判断. 字节码的解释器则是在[`ceval.c`](https://github.com/python/cpython/blob/master/Python/ceval.c)中实现, 对于字节码的具体改变则会依赖于python的主版本. 比如`PRINT_ITEM `和`PRINT_NEWLINE`在python 3中则被去掉了. 

在反汇编的输出中, 最左的数字(1,2,3)是源文件中的行号, 而接下来的数字(0,3,6,9)这是指令中的字节偏移. 指令的操作数这是直接用数字呈现, 而在括号内的这是符号性的解释. `>>`所表示的行实际上是代码中某处跳转指令的目标地址. 

我们这个样例非常简单, 它只是一个模块中单一的代码对象中的指令流程. 在现实中有着类和函数定义的模块会十分复杂. 那些类和函数本身就是const列表中的代码对象, 在模块中进行了足够深的嵌套. 

一旦你开始在这个级别挖掘, 会发现有各种各样适用于代码对象的工具. 在标准库中有内置的[compile](http://docs.python.org/lib/built-in-funcs.html#l2h-18)函数, 以及[compiler](http://docs.python.org/lib/module-compiler.html), [codeop](http://docs.python.org/lib/module-codeop.html)和[opcode](http://docs.python.org/lib/bytecodes.html)模块. 在真实场景中会有很多第三方包比如[codewalk](http://www.aminus.org/rbre/python/index.html), [byteplay](http://wiki.python.org/moin/ByteplayDoc)和[bytecodehacks](http://bytecodehacks.sourceforge.net/bch-docs/bch/index.html)等. [PEP 339](https://www.python.org/dev/peps/pep-0339/)给出了有关编译和操作码的更多详细信息. 最后