---
title: 缓存和数据库一致性
date: 2024-03-21 01:12:00 +0800
pin: false 
categories: [Redis]
tags: [Redis]
---


业务处于起步阶段时，流量非常小，无论是读请求还是写请求，直接操作数据库即可，但是随着业务量的增长，项目请求量越来越大，这时如果每次都从数据库中读数据，那肯定会有性能问题。
这个阶段通常的做法是，引入缓存来提高读性能。

我们常用的缓存方案一般是这样的：

- 写请求依旧只写数据库
- 读请求先读缓存，如果缓存不存在，则从数据库读取，并重建缓存
- 同时，写入缓存中的数据，都设置失效时间

引入缓存后，需要考虑缓存和数据库一致性问题，可选的方案有：

- 更新数据库 + 更新缓存
- 更新数据库 + 删除缓存

更新数据库 + 更新缓存方案，在并发场景下无法保证缓存和数据一致性，且存在缓存资源浪费和机器性能浪费的情况发生。

在更新数据库 + 删除缓存的方案中，先删除缓存，再更新数据库在并发场景下依旧有数据不一致问题，解决方案是延迟双删，但这个延迟时间很难评估，所以推荐用先更新数据库，再删除缓存的方案

在先更新数据库，再删除缓存方案下，为了保证两步都成功执行，需配合消息队列或订阅变更日志的方案来做，本质是通过重试的方式保证数据一致性

在先更新数据库，再删除缓存方案下，读写分离 + 主从库延迟也会导致缓存和数据库不一致，缓解此问题的方案是延迟双删，凭借经验发送延迟消息到队列中，延迟删除缓存，同时也要控制主从库延迟，尽可能降低不一致发生的概率

解决数据库和缓存一致性问题的关键思想：

1. 性能和一致性不能同时满足，为了性能考虑，通常会采用「最终一致性」的方案

2. 掌握缓存和数据库一致性问题，核心问题有 3 点：缓存利用率、并发、缓存 + 数据库一起成功问题

3. 失败场景下要保证一致性，常见手段就是「重试」，同步重试会影响吞吐量，所以通常会采用异步重试的方案

4. 订阅变更日志的思想，本质是把权威数据源（例如 MySQL）当做 leader 副本，让其它异质系统（例如 Redis / Elasticsearch）成为它的 follower 副本，通过同步变更日志的方式，保证 leader 和 follower 之间保持一致