---
title: 服务注册与发现
date: 2023-05-09 00:34:00 +0800
categories: [架构,微服务]
tags: [微服务,Consul,.Net]
---

> 在微服务架构中，由于系统的拆分，通常会有很多的服务，而每个服务又可能因为横向扩展而部署在多台服务器上，当服务A需要调用服务B的接口时，服务A该如何知道服务B的主机地址就成了一个问题，如果将B服务地址写死在配置文件中，那么当服务B扩展、下线或主机迁移时，服务A都需要改动配置文件以保证接口的正常调用，如果只有服务A需要调用服务B还好，手动修改也不是十分麻烦，但是在复杂的微服务架构中，一个服务往往会被多个服务调用，如果全部以手动的形式修改，那么无论在便捷性、安全性还有准确性方面都是不友好的。而服务注册发现系统就是为了帮助我们解决微服务中服务寻址的问题。

## 注册中心原理

在微服务架构下，主要有三种角色：服务提供者（RPC Server）、服务消费者（RPC Client）和服务注册中心（Registry）。

1. RPC Server 提供服务，在启动时，根据服务发布文件 server.xml 中的配置的信息，向 Registry 注册自身服务，并向 Registry 定期发送心跳汇报存活状态。
2. RPC Client 调用服务，在启动时，根据服务引用文件 client.xml 中配置的信息，向 Registry 订阅服务，把 Registry 返回的服务节点列表缓存在本地内存中，并与 RPC Sever 建立连接。
3. 当 RPC Server 节点发生变更时，Registry 会同步变更，RPC Client 感知后会刷新本地内存中缓存的服务节点列表。
4. RPC Client 从本地缓存的服务节点列表中，基于负载均衡算法选择一台 RPC Sever 发起调用。

## 注册中心实现方式

1. 注册中心 API：根据注册中心原理的描述，注册中心必须提供以下最基本的 api，服务注册接口，服务反注册接口，心跳汇报接口，服务订阅接口，服务变更查询接口。
2. 集群部署：注册中心作为服务提供者和服务消费者之间沟通的桥梁，它的重要性不言而喻。所以注册中心一般都是采用集群部署来保证高可用性，并通过分布式一致性协议来确保集群中不同节点之间的数据保持一致。
3. 服务健康状态检测：注册中心除了要支持最基本的服务注册和服务订阅功能以外，还必须具备对服务提供者节点的健康状态检测功能，这样才能保证注册中心里保存的服务节点都是可用的。
4. 服务状态变更通知：一旦注册中心探测到有服务提供者节点新加入或者被剔除，就必须立刻通知所有订阅该服务的服务消费者，刷新本地缓存的服务节点信息，确保服务调用不会请求不可用的服务提供者节点。

## 开源注册中心 Consul

不启用acl时，可直接执行下面的命令，创建一个只有一个节点的consul集群使用Docker部署单节点Consul

``` shell
sudo docker run -id -expose=[8300,8301,8302,8500,8600] --restart always -p 18300:8300 -p 18301:8301 -p 18302:8302 -p 18500:8500 -p 18600:8600 --name server1 -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true}' consul agent -server -bootstrap-expect=1 -node=server1 -bind=0.0.0.0 -client=0.0.0.0 -ui -datacenter dc1
```
启用acl是，只需要修改上面-e参数，如下面的命令，其中token_value可自行设置
```shell
sudo docker run -id -expose=[8300,8301,8302,8500,8600] --restart always -p 18300:8300 -p 18301:8301 -p 18302:8302 -p 18500:8500 -p 18600:8600 --name server1 -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true,"acl": {"enabled": true,"default_policy": "deny","down_policy": "extend-cache","tokens": {"master": "token_value"}}}' consul agent -server -bootstrap-expect=1 -node=server1 -bind=0.0.0.0 -client=0.0.0.0 -ui -datacenter dc1
```
配置参考
```
-expose：暴露出出来的端口，即consul启动所需的端口：8300,8301,8302,8500,8600
--restart：always表示容器挂了就自动重启
-p：建立宿主机与容器的端口映射
--name：容器名称
-e：环境变量，这里用于对consul进行配置
consul：这是consul镜像名，不是consul命令
agent：容器中执行的命令，各参数含义：
-server：表示节点是server类型
-bootstrap-expect：表示集群中有几个server节点后开始选举leader，既然是单节点集群，那自然就是1了
-node：节点名称
-bind：集群内部通信地址，默认是0.0.0.0
-client：客户端地址，默认是127.0.0.1
-ui：启用consul的web页面管理
-datacenter：数据中心
```
### 集成gliderlabs/registrator实现服务自动注册

Registrator监控新建的Docker容器，并且检查判定这些容器提供的服务。从我们的目的出发，任何监听在某个端口的程序都是服务。Registrator发现在容器内发现的任务服务，都将被添加到一个服务注册端，比如Consul或etcd。

[Registrator中文文档](https://www.cnblogs.com/flyingaway/p/10405294.html)

```
//容器ip+端口
docker run -d \
--name=registrator \
--net=host \
--volume=/var/run/docker.sock:/tmp/docker.sock \
gliderlabs/registrator:latest \
-internal \
consul://localhost:18500
```

```
//主机ip+端口
docker run -d \
--name=registrator \
--net=host \
--volume=/var/run/docker.sock:/tmp/docker.sock \
gliderlabs/registrator:latest \
-ip 192.168.0.8 \
consul://192.168.0.8:18500
```

### .net6实现简单的服务发现
　　
首先抽象一个服务发现的接口

```
public interface IServiceDiscoveryProvider
{
    ServiceEndPoint GetServiceEndPoint(string serviceName);
}

public class ServiceEndPoint
{
    public ServiceEndPoint(string host, int port, string name)
    {
        Host = host;
        Port = port;
        Name = name;
    }

    public string Host { get; set; }

    public int Port { get; set; }

    public string Name { get; set; }
}
```
Consul服务发现实现类

```
public class ConsulServiceDiscoveryProvider : IServiceDiscoveryProvider
{
      private readonly ConsulConfigOptions _consulConfigOptions;
 
     public ConsulServiceDiscoveryProvider(ConsulConfigOptions consulConfigOptions)
     {
          _consulConfigOptions = consulConfigOptions;
     }
 
     public ServiceEndPoint GetServiceEndPoint(string serviceName)
     {
         using (var consulClient = new ConsulClient(a => a.Address = GetConsulAddress()))
         {
             var services = consulClient.Catalog.Service(serviceName).Result.Response;
             if (services == null || !services.Any()) throw new Exception("The service endpoint was not found"); 
             Random r = new Random();
             int index = r.Next(services.Count());
             var service = services[index];
             return new ServiceEndPoint(service.ServiceAddress, service.ServicePort, serviceName);
         }
     }

   private Uri GetConsulAddress()
   {
        return new Uri($"http://{_consulConfigOptions.Host}:{_consulConfigOptions.Port}");
    }
}
```
consul配置选项类
```
public class ConsulConfigOptions
{
     public string Host { get; set; }
 
     public int Port { get; set; }
}
```