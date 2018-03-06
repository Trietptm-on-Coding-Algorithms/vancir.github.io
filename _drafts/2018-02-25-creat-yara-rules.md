---
title:  编写YARA规则检测恶意软件
tags: [RE, malware]
layout: post
categories: 
- tutorials
- translations
---

## 大纲

我将介绍以下内容:

1. 标识符
2. Yara关键字
3. 字符串
    1. 十六进制值
    2. 文本字符串
    3. String Modifiers
    4. 正则表达式
    5. 字符串集合
    6. Anonymous strings
4. 条件语句
    1. 布尔表达式
    2. Counting string instances
    3. String offsets or virtual addresses
    4. 匹配长度
    5. 文件大小
    6. 可执行程序入口点
    7. Accessing data at a given position
    8. Applying one condition across many strings
    9. Iterating over string occurrences
5. Referencing other rules
6. Yara Essentials
    1. Global Rules
    2. Private Rules
    3. Rule tags
    4. Metadata
    5. Using Modules
    6. Undefined values
    7. External/Argument Values
    8. Including Files

让我们现在开始吧.

### 编写Yara规则

Yara与C语言语法十分相像, 以下是一个没有任何操作的样例:

``` yara
rule HelloRule 
{
condition:
false
}
```

### Yara规则名

规则名是跟在`rule`后的名称,  该名称命名有如下规则:

*  是由英文字母或数字组成的字符串
*  可以使用下划线字符
*  第一个字符不能是数字
*  对大小写敏感
*  不能超出128个字符长度




