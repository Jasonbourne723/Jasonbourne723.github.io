---
title: Nginx负载均衡配置
date: 2024-2-27 10:12:00 +0800
categories: [架构]
tags: [Nginx]
---

> 对于一个大型网站来说，随着网站访问量的快速增长，单台服务器已经无法承担大量用户的并发访问，必须以增加服务器的方式，提高计算机系统的处理能力，计算速度，进而满足当前业务量的需求。那么如何实现服务器之间的协同功能呢？Nginx提供的反向代理和负载均衡功能是一个很好的解决方案。

## 反向代理

在Nginx服务器中，反向代理的配置非常简单，最主要的指令就是“proxy_pass”，用于设置后端服务器的地址。

```
server {
        listen       80;
       server_name  localhost;
       location / { 
       proxy_pass http://localhost:9000;
    }
}
```

如上配置 所有 `http://localhost:80`的请求都会被转发到`http://localhost:9000`。

## 负载均衡

负载均衡就是将负载分摊到多个操作单元上执行，从而提高服务的可用性和响应速度，带给用户更好的体验。

Nginx默认支持轮询、权重、ip Hash等多种负载均衡策略。

- 轮询：默认设置方式，每个请求按时间顺序逐一分配到不同的后端服务器进行处理，可以自动剔除宕机服务器。
- 权重方式：利用weight指定轮询的权重比率，用于后端服务器性能不均的情况。
- ip_hash方式：每个请求按照IP的hash结果分配，这样可以让每个访客每次请求都访问同一个后端服务器，可以解决session共享的问题。
- 第三方模块：fair或url_hash等策略，nginx本身不包含该实现，需要下载对应的软件包。

### 轮询配置

```
server {
        listen       80;
       server_name  localhost;
       location / { 
       proxy_pass http://web_server;
    }
}
#配置负载均衡服务器组 轮询方式
upstream web_server
{
      server  192.168.78.128;
      server   192.168.78.129;
}
```

### 权重方式配置

```
upstream web_server1
{
      server  192.168.78.128 weight=1;
      server   192.168.78.129 weight=3;
}

upstream web_server2
{
      server  192.168.78.128 weight=1 max_fails=1 fail_timeout=2;
      server   192.168.78.129 weight=3;
      server 192.168.78.130   backup;
}
```

按上图web_server1配置后，3/4的流量会转发到192.168.78.129的服务器上，1/4的流量会转发到192.168.78.128的服务器上,web_server2的配置表示 nginx在2s内发现后端服务异常达到max_fails次，就将该服务器标记为不可用。backup标记为预留的备份机器，当上面上个服务都宕机时，会将流量转发到备份机器。

### IP Hash方式

```
upstream web_server1
{
      ip_hash;
      server  192.168.78.128;
      server   192.168.78.129;
      server   192.168.78.130 down;
}
```

down参数可以将服务器标记为下线状态，在路由分配时，会忽略该服务器。