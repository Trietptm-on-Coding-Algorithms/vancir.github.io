---
title: RE(正则表达式)库
tags: [tools]
layout: post
categories: python
---

# 正则表达式的常用操作符

| 操作符 | 说明 |示例 | 
|-------|-----|----|
|.|表示任何单个字符| |
|[]|字符集, 对单个字符给出取值范围|[abc]表示a,b,c, [a-z]表示a到z单个字符|
|[^ ]|非字符集, 对单个字符给出排除范围|[^abc]表示非a或b或c的单个字符|
|\*|前一个字符0次或无限次扩展|abc\*表示ab, abc, abcc等|
|+|前一个字符1次或无限次扩展|abc+表示abc, abcc, abccc等|
|?|前一个字符0次或1次扩展|abc?表示ab, abc|
|\||左右表达式任意一个|abc\|def表示abc或def|
|{m}|扩展前一个字符m次|ab{2}c表示abbc|
|{m,n}|扩展前一个字符m到n次(含n)|ab{1,2}c表示abc, abbc|
|^|匹配字符串开头|^abc表示abc且在一个字符串的开头|
|$|匹配字符串结尾|abc$表示abc且在一个字符串的结尾|
|()|分组标记, 内部只能用\|操作符|(abc)表示abc|
|\d|数字, 等价于[0-9]| |
|\w|单词字符, 等价于[A-Za-z0-9_]| |

# RE库的主要函数

|函数|说明|
|---|---|
|re.search(pattern, string, flags=0)|在一个字符串中搜索匹配正则表达式的第一个位置, 返回match对象|
|re.match(pattern, string, flags=0)|从一个字符串的开始位置起匹配正则表达式, 返回match对象|
|re.findall(pattern, string, flags=0)|搜索字符串, 以列表类型返回全部能匹配的子串|
|re.split(pattern, string, maxsplit=0, flags=0)|将一个字符串按照正则表达式匹配结果进行分割, 返回列表类型|
|re.finditer(pattern, string, flags=0)|搜索字符串, 返回一个匹配结果的迭代类型, 每个迭代元素是match对象|
|re.sub(pattern, repl, string, count=0, flags=0)|在一个字符串中替换所有匹配正则表达式的子串, 返回替换后的字符串|

# flags: 正则表达式使用时的控制标记

|标记|说明|
|---|---|
|re.I     re.IGNORECASE|忽略正则表达式的大小写, [A-Z]能够匹配小写字符|
|re.M   re.MULTILINE|正则表达式中的^操作符能够将给定字符串的每行当做匹配开始|
|re.S    re.DOTALL|正则表达式中.操作符能够匹配所有字符, 默认匹配除换行外的所有字符|

# 一种等价的调用方式

``` python
rst = re.search(r'[1-9]\d{5}', 'BIT 100081')

pat = re.compiler(r'[1-9]\d{5}')
rst = pat.search('BIT 100081')
```

# Match对象的方法

|方法|说明|
|---|---|
|.string|待匹配的文本|
|.re|匹配时使用的pattern对象(正则表达式)|
|.pos|正则表达式搜索文本的开始位置|
|.endpos|正则表达式搜索文本的结束位置|
|.group(0)|获得匹配后的字符串|
|.start()|匹配字符串在原始字符串的开始位置|
|.end()|匹配字符串在原始字符串的结束位置|
|.span()|返回(.start(), .end())|