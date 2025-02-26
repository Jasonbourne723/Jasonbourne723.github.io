---
title: 数据结构与算法：不相交集合（Disjoint set）
date: 2024-01-14 10:12:00 +0800
categories: [数据结构与算法]
tags: [数据结构与算法]
---

## 并查集

并查集（Disjoint-set）是一种数据结构，用于处理一些不交集的合并及查询问题。并查集支持如下操作：

- 查询：查询某个元素属于哪个集合，通常是返回集合内的一个“代表元素”。这个操作是为了判断两个元素是否在同一个集合之中。
- 合并：将两个集合合并为一个。
- 添加：添加一个新集合，其中有一个新元素。添加操作不如查询和合并操作重要，常常被忽略。

由于支持查询和合并这两种操作，并查集在英文中也被称为联合-查找数据结构（Union-find data structure）或者合并-查找集合（Merge-find set）。

并查集可以用来指代任何支持上述操作的数据结构，但是一般来说，并查集特指其中最常见的一种实现：不交集森林（Disjoint-set forest）。经过优化的不交集森林有线性的空间复杂度O(n)，以及接近常数的单次操作平均时间复杂度，是效率最高的常见数据结构之一。

并查集是用于计算最小生成树的克鲁斯克尔算法中的关键。由于最小生成树在网络路由等场景下十分重要，并查集也得到了广泛的引用。此外，并查集在符号计算，寄存器分配等方面也有应用。


## 不交集森林

### 表示

不交集森林把每一个集合以一棵树表示，每一个节点即是一个元素。节点保存着到它的父节点的引用，树的根节点则保存一个空引用或者到自身的引用或者其他无效值，以表示自身为根节点。这个数据结构最早由 Bernard A. Galler 和 Michael J. Fischer 于 1964 年提出，但是经过了数年才完成了精确的分析。

### 添加

添加操作MakeSet(x)添加一个元素x，这个元素单独属于一个仅有它自己的集合。在不交集森林中，添加操作仅需将元素标记为根节点。用伪代码表示如下：

```
 function MakeSet(x)
     x.parent := x
 end function
```

在经过优化的不交集森林中，添加操作还会初始化一些有关节点的信息，例如集合的大小或者秩。

### 查询

在不交集森林中，每个集合的代表即是集合的根节点。查询操作Find(x)从x开始，根据节点到父节点的引用向根行进，直到找到根节点。用伪代码表示如下：
```
function Find(x)
     if x.parent = x then
         return x
     else
         return Find(x.parent)
     end if
 end function
```

### 路径压缩优化

在集合很大或者树很不平衡时，上述代码的效率很差，最坏情况下（树退化成一条链时），单次查询的时间复杂度高达O(n)。一个常见的优化是路径压缩：在查询时，把被查询的节点到根节点的路径上的所有节点的父节点设置为根结点，从而减小树的高度。也就是说，在向上查询的同时，把在路径上的每个节点都直接连接到根上，以后查询时就能直接查询到根节点。用伪代码表示如下：

```
function Find(x)
     if x.parent = x then
         return x
     else
         x.parent := Find(x.parent)
         return x.parent
     end if
 end function
```

### 合并

合并操作Union(x, y)把元素x所在的集合与元素y所在的集合合并为一个。合并操作首先找出节点x与节点y对应的两个根节点，如果两个根节点其实是同一个，则说明元素x与元素y已经位于同一个集合中，否则，则使其中一个根节点成为另一个的父节点。

```
 function Union(x, y)
     xRoot := Find(x)
     yRoot := Find(y)
     
     if xRoot ≠ yRoot then
         xRoot.parent := yRoot
     end if
 end function
```

### 按秩合并优化

上述代码的问题在于，可能会使得树不平衡，增大树的深度，从而增加查询的耗时。一个控制树的深度的办法是，在合并时，比较两棵树的大小，较大的一棵树的根节点成为合并后的树的根节点，较小的一棵树的根节点则成为前者的子节点。

判断树的大小有两种常用的方法，一个是以树中元素的数量作为树的大小，这被称为按大小合并。用伪代码表示如下：

```
 function MakeSet(x)
     x.parent := x
     x.size := 1
 end function
 
 function Union(x, y)
     xRoot := Find(x)
     yRoot := Find(y)
     
     if xRoot ≠ yRoot then
         if xRoot.size < yRoot.size then
             large := yRoot
             small := xRoot
         else
             large := xRoot
             small := yRoot
         end if
         
         small.parent := large
         large.size := large.size + small.size
     end if
 end function
```

需要注意的是，上面的代码中，只有根节点的size有意义，非根节点的size是没有意义的。

另一种做法则是使用秩来比较树的大小。秩的定义如下：

- 只有根节点的树（即只有一个元素的集合），秩为0；
- 当两棵秩不同的树合并后，新的树的秩为原来两棵树的秩的较大者；
- 当两棵秩相同的树合并后，新的树的秩为原来的树的秩加一。

容易发现，在没有路径压缩优化时，树的秩等于树的深度。在有路径压缩优化时，树的秩仍然能反映出树的深度和大小。在合并时根据两棵树的秩的大小，决定新的根节点，这被称作按秩合并。用伪代码表示如下：
```
 function MakeSet(x)
     x.parent := x
     x.rank := 0
 end function
 
 function Union(x, y)
     xRoot := Find(x)
     yRoot := Find(y)
     
     if xRoot ≠ yRoot then
         if xRoot.rank < yRoot.rank then
             large := yRoot
             small := xRoot
         else
             large := xRoot
             small := yRoot
         end if
         
         small.parent := large
         if large.rank = small.rank then
             large.rank := large.rank + 1
         end if
     end if
 end function
```
同样，上面的代码中，只有根节点的rank有意义，非根节点的rank是没有意义的。

### 时间及空间复杂度

#### 空间复杂度

容易看出，不交集森林的空间复杂度是O(n)。

#### 时间复杂度

对于同时使用路径压缩和按秩合并优化的不交集森林，每个查询和合并操作的平均时间复杂度仅为O(α(n))，α(n)是反阿克曼函数。由于阿克曼函数A增加极度迅速，所以α(n)增长极度缓慢，对于任何在实践中有意义的元素数目α(n)均小于5，因此，也可以粗略地认为，并查集的操作有常数的时间复杂度。

实际上，这是渐近最优算法：Fredman 和 Saks 在 1989 年证明了任何并查集都需要 Ω(α(n))的均摊时间来完成每次操作。

## 应用场景

- 动态连通性问题：判断两个元素是否属于同一连通分量，常用于网络连接、社交网络中的群组判定等。

- 最小生成树：并查集是 Kruskal 算法 的核心，用于判断边是否会形成环。

- 图的连通分量：判断图中有多少个连通分量。

- 网络分组问题：在计算机网络中，用于动态管理网络中节点的分组。