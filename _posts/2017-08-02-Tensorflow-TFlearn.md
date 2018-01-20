---
layout: post
title: Tensorflow与TFlearn安装与使用
categories: installation
tags: [tools]
---

## Tensorflow

这里的安装环境是Ubuntu 14.04 64bits，需要安装python，pip，numpy以及tensorflow。这里需要更新pip版本，否则会出现UnicodeDecodeError的错误信息而无法正确安装。

这里安装的tensorflow是仅支持CPU的版本。

```bash
#安装python以及pip
sudo aptitude install python-dev python-pip
#需要更新pip，否则会出现UnicodeDecodeError的错误信息而无法正确安装
sudo pip install --upgrade pip
#安装numpy以及CPU支持的tensorflow
sudo pip install numpy
sudo pip install https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-0.5.0-cp27-none-linux_x86_64.whl
```

这里我们打开python终端运行Tensorflow，尝试运行以下代码测试安装成功

```python
import tensorflow as tf
hello = tf.constant('Hello, TensorFlow!')
sess = tf.Session()
print sess.run(hello) #Hello, TensorFlow!
a = tf.constant(10)
b = tf.constant(32)
print sess.run(a+b) #42
```

##  TFlearn

在尝试安装TFlearn时遇到了不少问题，不光是在ubuntu14.04 64bits，而且在帮同学在win8，win10下安装（win下还需要安装如curses，scipy这些模块）也会遇到一些蜜汁bug，不过也还好，能在issues和stackoverflow上得到不少解答，也不枉自己的一番辛苦。

```bash
#推荐安装bleeding edge version
pip install git+https://github.com/tflearn/tflearn.git
```

官方推荐安装bleeding edge version不是没有道理的，如果安装最新版本，会出现一些蜜汁bug。不过也许还好，因为我在解决了一个urllib3模块的问题后直接装的bleeding edge version，并没有尝试最新版本。

在使用pip时，urllib3模块会提示InsecurePlatformWarning和SNIMissingWarning，大致原因就是urllib3无法正常访问https站点。

```bash
/usr/local/lib/python2.7/dist-packages/pip/_vendor/requests/packages/urllib3/util/ssl_.py:318: SNIMissingWarning: An HTTPS request has been made, but the SNI (Subject Name Indication) extension to TLS is not available on this platform. This may cause the server to present an incorrect TLS certificate, which can cause validation failures. You can upgrade to a newer version of Python to solve this. For more information, see https://urllib3.readthedocs.io/en/latest/security.html#snimissingwarning.
  SNIMissingWarning
/usr/local/lib/python2.7/dist-packages/pip/_vendor/requests/packages/urllib3/util/ssl_.py:122: InsecurePlatformWarning: A true SSLContext object is not available. This prevents urllib3 from configuring SSL appropriately and may cause certain SSL connections to fail. You can upgrade to a newer version of Python to solve this. For more information, see https://urllib3.readthedocs.io/en/latest/security.html#insecureplatformwarning.
  InsecurePlatformWarning
```

google以及github的issues上搜索得到的解答无非就是以下几种解决方案

* 更新python版本到2.7.9以上
* pip安装requests[security]或者pyOpenSSL ndg-httpsclient pyasn1（都是安装的同一些东西）
因为更新ubuntu预装的python版本，有可能导致一些系统软件的错误，我使用了方法2，但是问题依旧没有解决。

万幸的是，在stackoverflow上终于找到了解答，详见MoreReading的链接3。

```bash
sudo aptitude install python-dev libffi-dev libssl-dev packages
```
当然，stackoverflow上的解答还提供了第4种解决方案，就是关闭urllib3的相关警告。当然我之前曾有尝试，但是记得是提示说模块错误，所以也是蜜汁bug，如果你在安装了python-dev libffi-dev libssl-dev packages之后问题仍不能解决，那就只好尝试第4种方法了。不过如果还是不行的话，那也就是无力回天了（来自我长达3小时解决此问题的经验）。

```python
import requests.packages.urllib3
requests.packages.urllib3.disable_warnings()
```

解决urllib3的bug，安装tflearn成功后，可以尝试运行tflearn的一个入门案例，是关于泰坦尼克号存活率的小程序，详见More Reading的链接4

```python
from __future__ import print_function

import numpy as np
import tflearn

# Download the Titanic dataset
from tflearn.datasets import titanic
titanic.download_dataset('titanic_dataset.csv')

# Load CSV file, indicate that the first column represents labels
from tflearn.data_utils import load_csv
data, labels = load_csv('titanic_dataset.csv', target_column=0,
                        categorical_labels=True, n_classes=2)


# Preprocessing function
def preprocess(passengers, columns_to_delete):
    # Sort by descending id and delete columns
    for column_to_delete in sorted(columns_to_delete, reverse=True):
        [passenger.pop(column_to_delete) for passenger in passengers]
    for i in range(len(passengers)):
        # Converting 'sex' field to float (id is 1 after removing labels column)
        passengers[i][1] = 1. if data[i][1] == 'female' else 0.
    return np.array(passengers, dtype=np.float32)

# Ignore 'name' and 'ticket' columns (id 1 & 6 of data array)
to_ignore=[1, 6]

# Preprocess data
data = preprocess(data, to_ignore)

# Build neural network
net = tflearn.input_data(shape=[None, 6])
net = tflearn.fully_connected(net, 32)
net = tflearn.fully_connected(net, 32)
net = tflearn.fully_connected(net, 2, activation='softmax')
net = tflearn.regression(net)

# Define model
model = tflearn.DNN(net)
# Start training (apply gradient descent algorithm)
model.fit(data, labels, n_epoch=10, batch_size=16, show_metric=True)

# Let's create some data for DiCaprio and Winslet
dicaprio = [3, 'Jack Dawson', 'male', 19, 0, 0, 'N/A', 5.0000]
winslet = [1, 'Rose DeWitt Bukater', 'female', 17, 1, 2, 'N/A', 100.0000]
# Preprocess data
dicaprio, winslet = preprocess([dicaprio, winslet], to_ignore)
# Predict surviving chances (class 1 results)
pred = model.predict([dicaprio, winslet])
print("DiCaprio Surviving Rate:", pred[0][1])
print("Winslet Surviving Rate:", pred[1][1])
```

如果运行成功，会输出存活率

```python
DiCaprio Surviving Rate: 0.113464005291
Winslet Surviving Rate: 0.617543399334
```

## More Reading
* [Tensorflow 中文社区](http://www.tensorfly.cn/)
* [Github - TFlearn](https://github.com/tflearn/tflearn)
* [SSL InsecurePlatform error when using Requests package](http://stackoverflow.com/questions/29099404/ssl-insecureplatform-error-when-using-requests-package)
* [TFlearn_Quickstart_CN](https://github.com/lxzheng/machine_learning/wiki/TFlearn_Quickstart_CN)
