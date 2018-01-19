---
title: 安装YouCompleteMe
tags: [tool]
layout: post
categories: installation
---

# 安装

> 首先你需要安装vim的vundle插件, 并要求vim版本高于7.3.584

1. 首先需要在`.vimrc`中添加如下代码
``` bash
Plugin 'valloric/youcompleteme'
```
然后进入vim, 在Normal模式中输入`:PluginInstall`进行下载

2. 检查仓库的完整性

``` bash
cd ~/.vim/bundle/youcompleteme
git submodule update --init --recursive
```

3. 下载安装最新版的 libclang
``` bash
sudo aptitude install llvm-3.9 clang-3.9 libclang-3.9-dev libboost-all-dev
```

4. 编译构建`ycm_core`库

``` bash
mkdir ~/.ycm_build
cd ~/.ycm_build
cmake -G "Unix Makefiles" -DUSE_SYSTEM_BOOST=ON -DEXTERNAL_LIBCLANG_PATH=/usr/lib/x86_64-linux-gnu/libclang-3.9.so . ~/.vim/bundle/youcompleteme/third_party/ycmd/cpp
```
然后开始编译`ycm_core`
``` bash
cmake --build . --target ycm_core --config Release
```

5. 配置

复制 .ycm_extra_conf.py 文件
``` bash
cp ~/.vim/bundle/youcompleteme/third_party/ycmd/examples/.ycm_extra_conf.py ~/.vim/
```
然后添加vim配置(修改.vimrc文件)
``` bash
# gedit ～/.vimrc
let g:ycm_server_python_interpreter='/usr/bin/python'
let g:ycm_global_ycm_extra_conf='~/.vim/.ycm_extra_conf.py'
```

然后就安装完成了..不过我这里还有点问题.还需要再分析解决
