---
title: 知识图谱
date: 2024-08-27 10:12:00 +0800
categories: [架构设计]
tags: []
hidden: true
---

![](/assets/img/knowledge-graph/1.png)

```
@startmindmap

<style>
mindmapDiagram {
    :depth(1) {
      BackGroundColor pink
    }
    :depth(2) {
      BackGroundColor lightBlue
    }
    :depth(3) {
      BackGroundColor orange
    }
    :depth(4) {
      BackGroundColor lightGreen
    }
}
</style>

+ 知识图谱
++ 数据库
+++ MySQL
++++ 事务
+++++ 原子性
+++++ 隔离性
++++++ 读未提交
++++++ 读提交
++++++ 可重复读
++++++ 串行化
+++++ 持久性
+++++ 一致性
++++ 索引
+++++ 聚簇索引
+++++ 最左前缀原则
+++++ 索引覆盖
+++++ 索引下推
+++++ 前缀索引
+++++ hash索引
++++ MVCC
++++ 锁
+++++ 表锁
+++++ 行锁
+++++ 间隙锁
++++ 持久化
+++++ WAL redolog
+++++ Binlog
++++ 读写分离

+++ Redis
++++ 持久化策略
++++ 缓存淘汰策略
++++ 底层数据结构
++++ 多路复用模型
++++ 数据库-缓存一致性
++++ 主从复制
++++ 哨兵模型
++++ 集群模型

+++ MongoDB
++++ 聚合
++++ 索引
++++ 时序特性
++++ 事务
++++ 复制/分片

+++ Tdengine
+++ ElasticSearch
++++ 倒排索引
++++ 分词
+++ clickhouse

++ 消息队列
+++ RabbitMQ
+++ Kafka

++ 微服务架构
+++ DDD
+++ 网关
++++ Ocelot
++++ KONG
+++ 注册中心
++++ Consul
++++ Zookeeper
+++ 系统容错
++++ Polly
+++ 配置中心
++++ Apollo
+++++ 环境隔离
+++++ 版本跟踪
+++++ 金丝雀发布
+++++ 回滚
+++++ 权限控制
+++ 链路追踪
++++ Skywalking
++++ Zipkin
+++ 服务通讯
++++ Restful API
++++ gRPC
++++ 消息队列
+++ 日志收集
++++ ELK
++++ ExceptionLess
++++ Promtail+Loki+Grafana

++ 分布式
+++ 复制
++++ 主从复制
++++ 多主复制
++++ 无主复制
+++ 分片
++++ 按数据范围
++++ hash
++++ 一致性hash
+++ 分布式时钟
+++ 分布式锁
++++ MySQL
++++ Redis
++++ Zookeeper
+++ 分布式事务
++++ 两阶段提交
++++ 三阶段提交
++++ TCC
++++ 本地事件表
+++ 版本矢量
+++ 一致性原理
++++ CAP
++++ BASE
++++ Paxos
++++ Raft
++++ Zookeeper


-- C#
--- .Net6
---- Ioc
---- MiddleWare
---- SignalR
---- Swagger
---- gRPC
---- Authorization
--- ORM
---- EFCore
---- Dapper
--- MediatR
--- AutoMapper
--- Mapster
--- Polly
--- Ocelot
--- RulesEngine
--- SuperSocket
--- IdGenerator
--- Quartz
--- Furion
--- ABP

-- Go
--- gORM
--- gin

-- 网络协议
--- TCP/IP
--- UDP
--- ICMP
--- HTTP
--- HTTPS
--- DNS
--- Modbus
--- MQTT

-- 操作系统
--- 进程/线程
--- 内存管理器
--- 文件系统

-- 数据结构与算法

-- Linux
--- 权限管理
--- 文件系统管理
--- 软件安装 yum/npm
--- 网络管理 iptables 
--- 文本处理（linux三剑客）
--- 文本编辑 vim
--- 系统服务管理

-- DevOps
--- Git
--- GitHub
--- Gitlab
--- Jenkins
--- Docker
--- Docker Compose
--- Docker Machine
--- Docker Swarm
--- Kubernetes

-- Google三驾马车
--- MapReduce
--- Bigtable
--- GFS

-- 软技能
--- 技术文档
--- 技术演讲
--- 项目管理


@endmindmap
```