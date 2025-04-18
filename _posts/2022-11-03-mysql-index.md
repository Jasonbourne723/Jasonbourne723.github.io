---
title: MySQL 索引
date: 2022-11-03 10:12:00 +0800
categories: [数据库]
tags: [MySQL]
---

## 索引简介

索引是数据库中一种排序的数据结构，用于提升数据查询效率

## 索引的分类

### 聚簇索引与非聚簇索引

数据行与索引结构组织在一起的索引为聚簇索引，反之则为非聚簇索引。

### 按底层结构实现划分

- 有序数组：可以通过二分法快速（O(logn)）定位数据,但是当数组插入新数据时，需要移动插入位置后面的数据。适合在静态数据中使用。
- 哈希表：哈希表非常适合存储key-value型数据，查询复杂度为O(1),但是不适合范围查询。
- B+树：对查询、更新操作都有很好的支持。innodb引擎底层就是使用B+树实现。

### 按类型划分

- 主键索引：innodb会为主键创建索引，主键既是聚簇索引，也是唯一索引。
- 唯一索引：可以保证唯一索引列的值都是唯一的，没有重复的。
- 普通索引：非唯一索引的索引为普通索引。
- 联合索引：对多个列创建的索引为联合索引。

## Innodb索引特性

### 最左前缀匹配原则

最左前缀原则就是只要查询的是联合索引的最左 N 个字段，就可以利用该联合索引来加速查询。不按照最左匹配来为什么失效，其原因就在于联合索引的 B+ 树中的键值是排好序的。不过，这里指的排好序，其实是相对的，举个例子，有 (a, b, c) 联合索引，a 首先是排序好的，而 b 列是在 a 列排序的基础上做的排序，同样的 c 是在 a,b 有序的基础上做的排序。所以说，如果有 where a = xxx order by b = xxx 这种请求的话，是可以直接在这颗联合索引树上查出来的，不用对 b 列进行额外的排序；而如果是 where a = xxx order by c = xxx 这种请求的话，还需要额外对 c 列进行一次排序才行。另外，如果有对 a,b,c 的联合条件查询的话，并且 a 是模糊匹配或者说是范围查询的话，其实并不能完全踩中联合索引（a,b,c），a 列右边的所有列都无法使用索引进行快速定位了。所以这个时候就需要进行回表判断。也就是说数据库会首先根据索引来查找记录，然后再根据 where 条件来过滤记录。不过在 MySQL 5.6 中支持了索引下推功能，数据库在取出索引的同时，会根据 where 条件直接过滤掉不满足条件的记录，减少回表次数

### 索引覆盖

当一条查询语句命中索引，并且要查询的字段全部包含在索引列中，那么MySQL就不用再需要回表查询，提升了查询效率。

### 字符串字段加索引的几种方式

1. 直接创建完整索引，这样可能比较占用空间；
2. 创建前缀索引，节省空间，但会增加查询扫描次数，并且不能使用覆盖索引；
3. 倒序存储，再创建前缀索引，用于绕过字符串本身前缀的区分度不够的问题；
4. 创建 hash 字段索引，查询性能稳定，有额外的存储和计算消耗，跟第三种方式一样，都不支持范围扫描。

## 滥用索引的危害

1. 多余的索引会占用大量的磁盘空间。
2. 索引过多会影响数据插入、修改的效率。
3. 索引维护有序性的同时，容易造成页分裂、页合并过程，不仅影响性能，同时也会影响页的利用率。


索引可能因为删除，或者页分裂等原因，导致数据页有空洞，重建索引的过程会创建一个新的索引，把数据按顺序插入，这样页面的利用率最高，也就是索引更紧凑、更省空间。 

重建索引语句:

``` 
alter table T engine=InnoDB
```