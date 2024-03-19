---
title: Redis慢查询日志
date: 2023-02-22 01:12:00 +0800
pin: false 
categories: [数据库,Redis]
tags: [Redis]
---

> Redis的慢查询日志功能用于记录执行时间超过给点时长的命令请求，用户可以通过日志来监视和优化查询速度。

## 慢查询日志配置

我们可以通过配置文件或者命令方式配置 slowlog-log-slower-than（执行时间超过多少微妙的命令会被记录） 和 slowlog-max-len （最多保存多少条日志记录）

- 配置文件

```
slowlog-log-slower-than 10000

slowlog-max-len 128
```

- 命令方式

```
config set slowlog-log-slower-than 10000
config set slowlog-max-len 128
```

## 慢查询日志查询

可以通过 slowlog get 命令查询慢查询日志

```
slowlog get 5
```