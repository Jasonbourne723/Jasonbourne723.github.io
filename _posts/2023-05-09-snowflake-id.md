---
title: 分布式Id
date: 2023-05-09 00:34:00 +0800
categories: [1.架构设计]
tags: [微服务,分布式,雪花Id]
---

## 概述

　　分布式系统中，有一些需要使用全局唯一ID的场景，这种时候为了防止ID冲突可以使用36位的UUID，但是UUID有一些缺点，首先他相对比较长，另外UUID一般是无序的。有些时候我们希望能使用一种简单一些的ID，并且希望ID能够按照时间有序生成。而twitter的snowflake解决了这种需求，最初Twitter把存储系统从MySQL迁移到Cassandra，因为Cassandra没有顺序ID生成机制，所以开发了这样一套全局唯一ID生成服务。 该项目地址为：https://github.com/twitter/snowflake是用Scala实现的。 

## 分布式Id的基本要求

- 全局唯一 ：ID 的全局唯一性肯定是首先要满足的！
- 高性能 ： 分布式 ID 的生成速度要快，对本地资源消耗要小。
- 高可用 ：生成分布式 ID 的服务要保证可用性无限接近于 100%。
- 方便易用 ：拿来即用，使用方便，快速接入！
- 安全 ：ID 中不包含敏感信息。
- 有序递增 ：如果要把 ID 存放在数据库的话，ID 的有序性可以提升数据库写入速度。并且，很多时候 ，我们还很有可能会直接通过 ID 来进行排序。
有具体的业务含义 ：生成的 ID 如果能有具体的业务含义，可以让定位问题以及开发更透明化（通过 ID 就能确定是哪个业务）。
- 独立部署 ：也就是分布式系统单独有一个发号器服务，专门用来生成分布式 ID。这样就生成 ID 的服务可以和业务相关的服务解耦。不过，这样同样带来了网络调用消耗增加的问题。总的来说，如果需要用到分布式 ID 的场景比较多的话，独立部署的发号器服务还是很有必要的。

## snowflake结构

snowflake的结构如下(每部分用-分开):

```
0 - 0000000000 0000000000 0000000000 0000000000 0 - 00000 - 00000 - 000000000000
```

第一位为未使用，接下来的41位为毫秒级时间(41位的长度可以使用69年)，然后是5位datacenterId和5位workerId(10位的长度最多支持部署1024个节点） ，最后12位是毫秒内的计数（12位的计数顺序号支持每个节点每毫秒产生4096个ID序号），一共加起来刚好64位，为一个Long型。(转换成字符串长度为18)

snowflake生成的ID整体上按照时间自增排序，并且整个分布式系统内不会产生ID碰撞（由datacenter和workerId作区分），并且效率较高。据说：snowflake每秒能够产生26万个ID。

## 雪花算法的C#代码实现

```
public class IdWorker
{
    //机器ID
    private static long workerId;
    private static long twepoch = 687888001020L; //唯一时间，这是一个避免重复的随机量，自行设定不要大于当前时间戳
    private static long sequence = 0L;
    private static int workerIdBits = 4; //机器码字节数。4个字节用来保存机器码(定义为Long类型会出现，最大偏移64位，所以左移64位没有意义)
    public static long maxWorkerId = -1L ^ -1L << workerIdBits; //最大机器ID
    private static int sequenceBits = 10; //计数器字节数，10个字节用来保存计数码
    private static int workerIdShift = sequenceBits; //机器码数据左移位数，就是后面计数器占用的位数
    private static int timestampLeftShift = sequenceBits + workerIdBits; //时间戳左移动位数就是机器码和计数器总字节数
    public static long sequenceMask = -1L ^ -1L << sequenceBits; //一微秒内可以产生计数，如果达到该值则等到下一微妙在进行生成
    private long lastTimestamp = -1L;

    /// <summary>
    /// 机器码
    /// </summary>
    /// <param name="workerId"></param>
    public IdWorker(long workerId)
    {
        if (workerId > maxWorkerId || workerId < 0)
            throw new Exception(string.Format("worker Id can't be greater than {0} or less than 0 ", workerId));
        IdWorker.workerId = workerId;
    }

    public long nextId()
    {
        lock (this)
        {
            long timestamp = timeGen();
            if (this.lastTimestamp == timestamp)
            { //同一微妙中生成ID
                IdWorker.sequence = (IdWorker.sequence + 1) & IdWorker.sequenceMask; //用&运算计算该微秒内产生的计数是否已经到达上限
                if (IdWorker.sequence == 0)
                {
                    //一微妙内产生的ID计数已达上限，等待下一微妙
                    timestamp = tillNextMillis(this.lastTimestamp);
                }
            }
            else
            { //不同微秒生成ID
                IdWorker.sequence = 0; //计数清0
            }
            if (timestamp < lastTimestamp)
            { //如果当前时间戳比上一次生成ID时时间戳还小，抛出异常，因为不能保证现在生成的ID之前没有生成过
                throw new Exception(string.Format("Clock moved backwards.  Refusing to generate id for {0} milliseconds",
                    this.lastTimestamp - timestamp));
            }
            this.lastTimestamp = timestamp; //把当前时间戳保存为最后生成ID的时间戳
            long nextId = (timestamp - twepoch << timestampLeftShift) | IdWorker.workerId << IdWorker.workerIdShift | IdWorker.sequence;
            return nextId;
        }
    }

    /// <summary>
    /// 获取下一微秒时间戳
    /// </summary>
    /// <param name="lastTimestamp"></param>
    /// <returns></returns>
    private long tillNextMillis(long lastTimestamp)
    {
        long timestamp = timeGen();
        while (timestamp <= lastTimestamp)
        {
            timestamp = timeGen();
        }
        return timestamp;
    }

    /// <summary>
    /// 生成当前时间戳
    /// </summary>
    /// <returns></returns>
    private long timeGen()
    {
        return (long)(DateTime.UtcNow - new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc)).TotalMilliseconds;
    }
}
```

调用方法

```
IdWorker idworker = new IdWorker(1);
for (int i = 0; i < 1000; i++)
{
　　Console.WriteLine(idworker.nextId());
}
```