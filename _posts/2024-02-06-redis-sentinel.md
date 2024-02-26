---
title: Redis哨兵
date: 2024-02-22 01:12:00 +0800
pin: false 
categories: [架构]
tags: [Redis]
---

> Sentinel（哨兵）是redis的高可用解决方案：由一个或多个Sentinel实例组成Sentinel系统可以监视任意多个主服务器，以及这些这些主服务器下属的所有从服务器，并在被监视的主服务器进入下线状态后，自动将下线主服务器下属的某个从服务器升级为新的主服务器，然后由新的主服务器代替已下线的主服务器继续处理命令请求。

### 配置

创建一个Sentinel.conf配置文件内容如下：

```
port 26379
sentinel monitor mymaster 127.0.0.1 6379 1
sentinel auth-pass mymaster 123456
sentinel down-after-milliseconds mymaster 10000
```
- port是哨兵实例的端口号。
- mymaster后面是监控的主服务器Ip，端口号，1代表只要有一个sentinel实例认为主机下线就可以开始做故障转移操作。
- auth-pass 主服务器密码  （注：主从服务器要设置相同密码 及主服务器密码 否则故障转移无法成功）。
- sentinel down-after-milliseconds  当mymaster断线10秒后，Sentinel会将mymaster判断为主观下线状态。

执行命令 `redis-server.exe sentinel.conf --sentinel` 启动哨兵实例，这样我们的单实例哨兵就配置完成了。

###  哨兵方案总结

- Sentinel只是一个运行在特殊模式下的redis服务器，它使用了和普通模式不同的命令表。

- Sentinel会读入用户指定的配置文件，为每个要被监视的主服务器创建相应的实例结构，并创建向主服务器的命令连接和订阅连接，其中命令连接用于向主服务器发送命令请求，而订阅连接用于接收指定频道的消息。

- Sentinel默认会以每十秒一次的频率，通过命令连接向被监视的主服务器发送info命令来获取主服务器的配置信息及下属所有的从服务器的地址信息，并为这些从服务器创建相应的实例结构，以及连向这些从服务器的命令连接和订阅连接。

- 在一般情况下，Sentinel会以每十秒一次的频率向被监视的主从服务器发送info命令，当主服务器处于下线状态，或者Sentinel正在对主服务器做故障转移时，Sentinel向从服务器发送info命令的频率将改为每秒一次。

- 对于监视同一个主服务和从服务器的Sentinel来说，它们会以每两秒一次的频率，通过向被监视服务器的__sentinel__:hello频道发送消息来向其他Sentinel宣告自己的存在。

- 每个Sentinel也会从__sentinel__:hello频道中接收其他Sentinel发来的消息，并根据这些信息为其它Sentinel创建相应的实体结构，以及命令连接。

- Sentinel以每秒一次的频率向实例（主服务器，从服务器，Sentinel实例）发送Ping命令，并根据实例对ping命令的回复来判断实例是否在线。当一个实例在指定的时长中连续向Sentinel发送无效回复时，Sentinel会将这个实例判断为主观下线。

- 当Sentinel将一个主服务器判断为主观下线时，它会向同样监视这个服务器的其他Sentinel进行询问，看他们是否同意这个主服务器已经进入了主观下线状态。

- 当Sentinel收集了足够多的主观下线投票后，它会将主服务器判断为客观下线，并发起一次针对主服务器的故障转移操作。


哨兵可以提高redis的可用性，但并不会提升redis的数据存储总量，当需要对redis进行扩展时，需要使用redis集群方案