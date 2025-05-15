---
title: 以一种访问权限不允许的方式做了一个访问套接字的尝试
date: 2025-05-15 10:12:00 +0800
categories: [系统运维]
tags: [shell]
hidden: true
---

启用应用程序报错 `以一种访问权限不允许的方式做了一个访问套接字的尝试`, 但是端口又没有被占用。


## 解决方案

Windows 某些端口范围可能会被限制（被 Hyper-V、VPN、系统服务等预留）。

检查端口状态：
```
netsh interface ipv4 show excludedportrange protocol=tcp
```
如果你发现你的端口在被系统保留的范围内（特别是 Hyper-V 会占用 49000+ 的一大段），就不能用。

### 修改动态端口范围

查看当前动态端口范围（TCP）
```
netsh int ipv4 show dynamicport tcp
```
假设你想避开 50000-51000，可以把动态端口改为 55000-65000：
```
netsh int ipv4 set dynamicport tcp start=55000 num=10000
```
然后为 IPv6 也设置一下：
```
netsh int ipv6 set dynamicport tcp start=55000 num=10000
```
重启电脑,就可以了