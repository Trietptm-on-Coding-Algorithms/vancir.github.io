---
title: 求朋友关系中的朋友圈数量 
time: 2017-08-29
tags: [algorithm, union-find]
layout: post
categories: posts
---
# 题目描述

给出10W条人和人之间的朋友关系，求出这些朋友关系中有多少个朋友圈（如A-B、B-C、D-E、E-F，这4对关系中存在两个朋友圈），并给出算法的时间复杂度。

# 解答

这道题实际上考察的是"并查集"这一数据结构. 对于这类问题, 看似并不复杂, 但数据量极大, 如果用正常的数据结构来描述的话, 往往空间上过大, 计算机无法承受, 即使在空间上勉强通过, 运行的时间复杂度也极高. 只能用并查集来描述

## 并查集的主要操作

* 初始化

把每个点所在的集合初始化为自身. 通常来说, 这个步骤在每次使用该数据结构时只需要执行一次, 无论何种方式实现, 时间复杂度均为O(n)

* 查找

查找元素所在的集合, 即根节点

* 合并

将两个元素所在的集合合并为一个集合. 通常来说, 在合并之前, 应先判断两个元素是否属于同一集合, 这可用上面的"查找"操作来实现.

因此, 对于题目中的朋友圈关系, A-B, B-C, D-E, E-F.我们的算法过程如下:

``` c
start => (A)(B)(C)(D)(E)(F)
A-B   => (A,B)(C)(D)(E)(F)
B-C   => (A,B,C)(D)(E)(F)
D-E   => (A,B,C)(D,E)(F)
E-F   => (A,B,C)(D,E,F)
```

## 算法

对于每个集合, 都使用集合中的某个元素来代表这个集合, 也就是`代表元`. 意思就是在集合(朋友圈)里建一个树, 当要确定一个元素属于哪个集合时, 只需要根据它的父节点网上遍历找到根节点(代表元). 根据它们的代表元来确定它属于哪个集合里.

并查集主要是三个操作

* 初始化

对所有的单个数据建立一个单独的集合.

``` c
//用结构体表示
#define MAX 100000
struct Node{
  int data;
  int rank;
  int parent;
}node[MAX];

//用数组表示
int set[max];//类别，或者用parent,father表示
int rank[max];//层次，初始化为0
int data[max];//数据
```

初始化操作: 
``` c
void Make_Set(int i){
  set[i]=i;
  rank[i]=0;
}
```


* 查找

``` c
int get_parent(int x){//结构体
  if(node[x].parent==x)
    return x;
  return get_parent(node[x].parent);
}

int Find_Set(int i){ //数组
  //如果集合i的父亲是自己，说明自己就是源头，返回自己的标号
  if(set[i]==i)
     return set[i];
  //否则查找集合i的父亲的源头
  return  Find_Set(set[i]);        
}
```

* 合并

``` c
void Union(int a,int b){//结构体
  a=get_parent(a);
  b=get_parent(b);
  if(node[a].rank>node[b].rank)
    node[b].parent=a;
  else{
    node[a].parent=b;
    if(node[a].rank==node[b].rank)
      node[b].rank++;
  }
}

void Union(int i,int j){//数组
  i=Find_Set(i);
  j=Find_Set(j);
  if(i==j) return ;
  if(rank[i]>rank[j]) set[j]=i;
  else{
	  if(rank[i]==rank[j]) rank[j]++;   
	  set[i]=j;
	}
}
```

## 代码

``` c
#define MAX_PEOPLE 10001
#define MAX_RELATIONSHIP 100001 

int father[MAX_PEOPLE];//存储每个元素的father
int relat[MAX_RELATIONSHIP][2];//存储朋友关系

//初始化集合
void Make_Set(int x){
	father[x] = x;
}

//查找x所在集合并压缩路径
int Find_Set(int x){

	int root;
	int i, next;
	root = x;
	while(father[root] != root)//寻找x所在集合的代表元
		root = father[root];
	
	i = x;
	while(i != root){//将r集合中的所有结点直接指向r, 路径压缩
		next = father[i];
		father[i] = root;
		i = next;
	}
	return root;

}


void Union(int x, int y){
	int x_set;
	int y_set;

	x_set = Find_Set(x);
	y_set = Find_Set(y);

	if(x_set == y_set)
		return ;
	else 
		father[y_set] = x_set;

}

int main(){

	int n;//n个朋友圈用户
	int	m;//m对朋友关系
	
	int i;
	int count=0;
	scanf("%d %d", &n, &m);

	for(i=0; i<n; i++)//初始化
		Make_Set(i);

	for(i=0; i<m; i++)//合并关系
		Union(relat[i][0], relat[i][1]);

	for(i=0; i<n; i++)//代表元即一个朋友圈
		if(father[i] == i)
			count++;
	
	printf("%d\n", count);
	return 0;
}




```
