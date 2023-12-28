---
title: mysql 主从模式搭建
date: 2023-12-28 09:12:00 +0800
categories: [架构]
tags: [mysql,数据库]
---

> 当单体数据库的读写能力成为系统瓶颈时，搭建数据库的主-从模式是一个很好的选择，通过实现读写分离，可以大幅度提升数据库的读写能力。

## 环境准备

使用docker安装两个mysql容器，分别映射到宿主机的3306、3307端口。
参考如下安装命令：
```
docker run -d --restart=always --name mysql --privileged=true -v /data/mysql/data:/var/lib/mysql -v /data/mysql/conf:/etc/mysql/conf.d -v /data/mysql/log:/var/log/mysql -p 3303:3306  -e TZ=Asia/Shanghai -e MYSQL_ROOT_PASSWORD=123456  mysql:latest
```

## 配置主库

- 修改主库配置文件my.cnf,增加如下内容后，重启主库。

```
# 服务的唯一编号
server-id = 1

# 开启mysql binlog功能
log-bin = mysql-bin

# binlog记录内容的方式，记录被操作的每一行
binlog_format = ROW

# 减少记录日志的内容，只记录受影响的列
binlog_row_image = minimal

# 指定需要复制的数据库名为test
binlog-do-db = test
```
- 创建给从库同步数据的账号

```
# 创建账号
create user 'jason'@'%' identified by '123456';
# 授权
grant all privileges on *.* to 'jason'@'%' WITH GRANT option;
# 重新加载配置
FLUSH PRIVILEGES;
```

- 通过 `show master status` 查看主库状态，重点关注 File 和 Position 两列
```
+------------------+----------+--------------+------------------+-------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+------------------+----------+--------------+------------------+-------------------+
| mysql-bin.000005 |      737 | test         |                  |                   |
+------------------+----------+--------------+------------------+-------------------+
```

## 配置从库

- 修改从库my.cnf文件，在[mysqld]加入下面的内容,然后重启从库
```
# 服务的唯一编号
server-id = 2

# 开启mysql binlog功能
log-bin = mysql-bin

# binlog记录内容的方式，记录被操作的每一行
binlog_format = ROW

# 减少记录日志的内容，只记录受影响的列
binlog_row_image = minimal

# 指定需要复制的数据库名为test
replicate-do-db = test

```
- 执行如下同步命令

```
stop slave;

change master to master_host='192.168.164.101',master_user='jason',master_password='123456',master_log_file='mysql-bin.000005',master_log_pos=737,get_master_public_key=1;

start slave;
```

- 通过 `show slave status` 查看从库状态，如下两列均为yes时，表示主-从模式的mysql已经搭建成功。

```
+------------------+-----------------+
| Slave_IO_Running |Slave_SQL_Running|
+------------------+-----------------+
|      yes         |      yes        | 
+------------------+-----------------+
```


