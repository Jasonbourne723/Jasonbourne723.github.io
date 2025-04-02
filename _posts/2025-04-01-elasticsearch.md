---
title: Elasticsearch 入门指南
date: 2025-04-01 09:12:00 +0800
categories: [数据库]
tags: [Elasticsearch]
---

# Elasticsearch 入门指南

## 什么是 Elasticsearch？

Elasticsearch（简称 ES）是一个基于 `Apache Lucene` 的开源、分布式搜索和分析引擎。它支持全文搜索、结构化搜索、实时分析，并且可以处理海量数据。

### Elasticsearch 的特点

- **分布式架构**：支持多节点、自动分片（sharding）和副本（replica）。
- **全文搜索**：基于倒排索引（inverted index），提供高效的搜索能力。
- **RESTful API**：使用 HTTP + JSON 进行数据交互，易于集成。
- **近实时性（NRT）**：数据写入后几乎可以立即被搜索。
- **高扩展性**：可以通过添加节点进行水平扩展。


## 安装 Elasticsearch

### 下载与安装

[Elasticsearch 官方下载地址](https://www.elastic.co/downloads/elasticsearch)

####  解压并启动（Linux/macOS）

```sh
 tar -xzf elasticsearch-8.x.x-linux-x86_64.tar.gz
 cd elasticsearch-8.x.x
 ./bin/elasticsearch
```

#### 启动（Windows）

```sh
 bin\elasticsearch.bat
```

#### 验证安装

打开浏览器访问：
```sh
 http://localhost:9200
```
如果安装成功，会返回类似如下信息：
```json
{
  "name": "node-1",
  "cluster_name": "elasticsearch",
  "version": {
    "number": "8.x.x",
    "build_flavor": "default"
  }
}
```


## 基本概念

- 索引（Index）：索引类似于关系型数据库中的“表”，存储的是特定类型的文档集合。
- 文档（Document）：文档是存储在 Elasticsearch 中的基本数据单元，相当于数据库中的一行数据。
- 字段（Field）：文档中的最小数据单元，相当于数据库表的列。
- 映射（Mapping）：映射定义了索引中字段的类型及其索引方式。
- 倒排索引（Inverted Index）：Elasticsearch 采用倒排索引来提高搜索效率，它会记录每个**词**在哪些文档中出现，从而加快查询速度。

---

## Elasticsearch 基本操作

### 创建索引

```sh
PUT http://localhost:9200/products
```

### 插入文档

```sh
POST http://localhost:9200/products/_doc/1
Content-Type: application/json

{
  "name": "iPhone 15",
  "price": 7999,
  "brand": "Apple"
}
```

### 获取文档

```sh
GET http://localhost:9200/products/_doc/1
```

### 更新文档

```sh
POST http://localhost:9200/products/_update/1
Content-Type: application/json

{
  "doc": {
    "price": 7899
  }
}
```

###  删除文档

```sh
DELETE http://localhost:9200/products/_doc/1
```

### 搜索数据（全文搜索）**

```sh
GET http://localhost:9200/products/_search
Content-Type: application/json

{
  "query": {
    "match": {
      "name": "iPhone"
    }
  }
}
```

---

## 结构化查询 vs. 全文搜索

| **查询方式** | **适用场景** | **示例** |
|-------------|------------|---------|
| **`match`** | 全文搜索，分词匹配 | `match": { "name": "iPhone" }` |
| **`term`**  | 精确匹配，不分词 | `term": { "brand": "Apple" }` |
| **`range`** | 数值范围查询 | `range": { "price": { "gte": 5000, "lte": 10000 } }` |

---

##  应用场景

### 日志分析

Elasticsearch 常用于日志分析，结合 **Logstash + Kibana（ELK）** 可视化日志数据。

###  全文搜索

适用于电商搜索（如淘宝、京东）、社交媒体搜索（如微博、知乎）。

###  业务数据分析

可以用 Elasticsearch 进行数据分析，如趋势分析、用户行为分析等。


## 7. 总结
Elasticsearch 是一个强大的分布式搜索引擎，适用于全文搜索、日志分析和数据分析。其基于 **倒排索引**，提供了高效的查询能力，同时支持 RESTful API，易于集成。

你可以进一步学习 **聚合查询（Aggregation）**、**多索引查询** 和 **分片策略**，以优化性能。

