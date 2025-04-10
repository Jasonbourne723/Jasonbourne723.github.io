---
title: Redis配置文件详解
date: 2023-02-22 01:12:00 +0800
pin: false 
categories: [Redis]
tags: [Redis]
---

```
#redis的配置

#Redis默认不是以守护进程的方式运行，可以通过该配置项修改，使用yes启用守护进程

daemonize yes

#当Redis以守护进程方式运行时，Redis默认会把pid写入redis.pid文件，可以通过pidfile指定

pidfile 'E:/xxx/redis/redis_pid/redis.pid'

#端口

port 6379

#绑定主机的ip地址

bind 127.0.0.1

#当 客户端闲置多长时间后关闭连接，如果指定为0，表示关闭该功能

timeout 300

#指定日志记录级别，Redis总共支持四个级别：debug、verbose、notice、warning，默认为verbose

loglevel notice

#日志记录方式，默认为标准输出，如果配置Redis为守护进程方式运行，而这里又配置为日志记录方式为标准输出，则日志将会发送给/dev/null

logfile stdout

#设置数据库的数量，默认数据库为0，可以使用SELECT <dbid>命令在连接上指定数据库id

databases 16

#指定在多长时间内，有多少次更新操作，就将数据同步到数据文件，可以多个条件配合

#分别表示900秒（15分钟）内有1个更改，300秒（5分钟）内有10个更改以及60秒内有10000个更改

save 900 1

save 300 10

save 60 10000

#指定存储至本地数据库时是否压缩数据，默认为yes，Redis采用LZF压缩，如果为了节省CPU时间，可以关闭该选项，但会导致数据库文件变的巨大

rdbcompression yes

#指定本地数据库文件名，默认值为dump.rdb

dbfilename dump.rdb

#指定本地数据库存放目录

dir 'D:/XXX/redis/redis_database'

#设置当本机为slav服务时，设置master服务的IP地址及端口，在Redis启动时，它会自动从master进行数据同步

#slaveof 127.0.0.1 6379

#当master服务设置了密码保护时，slav服务连接master的密码

#masterauth 123456

#设置Redis连接密码，如果配置了连接密码，客户端在连接Redis时需要通过AUTH <password>命令提供密码，默认关闭

#requirepass foobared

#设置同一时间最大客户端连接数，默认无限制，Redis可以同时打开的客户端连接数为Redis进程可以打开的最大文件描述符数，

如果设置 maxclients 0，表示不作限制。当客户端连接数到达限制时，Redis会关闭新的连接并向客户端返回max number of clients reached错误信息

maxclients 10000

#指定Redis最大内存限制，Redis在启动时会把数据加载到内存中，达到最大内存后，Redis会先尝试清除已到期或即将到期的Key，

当此方法处理 后，仍然到达最大内存设置，将无法再进行写入操作，但仍然可以进行读取操作。Redis新的vm机制，会把Key存放内存，Value会存放在swap区

maxmemory 300m

#指定是否在每次更新操作后进行日志记录，Redis在默认情况下是异步的把数据写入磁盘，如果不开启，可能会在断电时导致一段时间内的数据丢失。

因为 redis本身同步数据文件是按上面save条件来同步的，所以有的数据会在一段时间内只存在于内存中。默认为no

appendonly yes

#指定更新日志文件名，默认为appendonly.aof

appendfilename 'appendonly.aof'

#指定更新日志条件，共有3个可选值

#no：表示等操作系统进行数据缓存同步到磁盘（快） 

#always：表示每次更新操作后手动调用fsync()将数据写到磁盘（慢，安全）

#everysec：表示每秒同步一次（折衷，默认值）

appendfsync everysec
```