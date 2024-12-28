---
title: MySQL 一条update语句的执行过程
date: 2023-03-05 10:12:00 +0800
categories: [数据库]
tags: [MySQL]
---

![](/assets/img/mysql-arch/002.png)

与查询流程不一样的是，更新流程还设计两个重要模块：redo log 和 binlog。

以下面的一条sql为例 （ID为主键）

1. update T set b=b+1 where ID = 2
2. 客户端通过连接器与 mysql 建立连接　
3. 删除要update表的缓存
4. 分析器解析 sql 并判断是否含有语句错误
5. 优化器确定查询索引
6. 执行器调用 Innodb 存储引擎接口获取 ID=2 的数据行。
7. Innodb 存储引擎扫描主键索引查找到 ID=2 的行返回给server层。执行器将 B+1 调用存储引擎接口写入该行数据。
8. Innodb存储引擎将数据保存在内存中(WAL)。Innodb 存储引擎写 redo 日志，prepare 状态，通知 Server 层。
9. server 层 提交 Binlog 后通知 Innodb 存储引擎。
10. Innodb 存储引擎将 redo 日志 commit。

至此一条update语句就执行完成了。

### redolog

Innodb存储引擎特有的机制，可以用来应对异常恢复，Crash-safe，redo可以保证mysql异常重启时，将未提交的事务回滚，已提交的事务安全落库。

### binLog 

binlog 记录的是逻辑日志，是mysql的归档日志，支持所有引擎使用。与redo不同的是，binlog是不限制大小，文件追加写。

### 二阶段提交 

redo（perpare）--->binlog-->redo(commit) 保证了mysql在异常重启的时候，数据的一致性，在任意环节出错，都可以保证redo日志和binlog的一致性。

### WAL

第8个步骤，innodb没有直接将数据落盘，而是存在内存中，并记录日志，这里用到的技术就是WAL(Write-Ahead Logging)。数据在持久化硬盘前，如果mysql异常重启，innodb可以根据redo日志将未持久化的数据恢复。redo日志是有大小限制的，循环写，当redo快要写满时，将redo日志头部的记录清理，擦除记录前要把内存记录更新到数据文件。

