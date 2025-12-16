---
title: OpenTelemetry从零到实践
date: 2025-10-16 22:00:00 +0800
categories: [微服务]
tags: [OpenTelemetry, 可观测性, tracing, metrics, logging]
---

## 前言：为什么要关心可观测性？

最早做业务开发的时候，我对“监控”的理解非常朴素：

- 请求量、QPS 看一眼
- CPU、内存、磁盘差不多就行
- 报错了看一下日志，`grep` 一把

随着系统复杂度增加（微服务、消息队列、分布式事务、异步任务……），这些手段越来越不够用：

- **排查一次线上慢请求**，要在多个服务的日志里来回翻
- **调用链断层**，很难知道一次请求到底经过了哪些服务
- **指标、日志、链路是分离的**，无法快速关联到同一条请求

这时候就会接触到“可观测性（Observability）”以及 OpenTelemetry 这个统一标准。本文是我学习 OpenTelemetry 后的一次系统梳理，希望能把零散的概念串成一条线：

- **先讲可观测性的“三板斧”：Metrics、Logs、Traces**
- 再看 **OpenTelemetry 的整体架构和核心概念**
- 然后通过一个简单示例感受 **SDK + Collector + 后端** 的数据流
- 最后总结一些 **实践建议和踩坑经验**


## 一、可观测性的“三板斧”：Metrics、Logs、Traces

在 OpenTelemetry 的语境下，可观测性通常由三类数据组成：

### 1. Metrics（指标）

指标是 **聚合后的数字**，反映系统整体健康状态：

- **QPS**、错误率
- **延迟分位数**（p95、p99）
- **资源使用率**（CPU、内存、连接数）

它的特点：

- 数据量可控（已经聚合过，比如每 10 秒一个点）
- 拿来画图、配置告警非常适合
- 但 **很难追踪单次请求具体发生了什么**

### 2. Logs（日志）

日志是开发者最熟悉的，可认为是 **离散的文本事件**：

- 错误栈、业务关键节点打印
- 结构化日志（JSON）可以更方便地检索

问题在于：

- 服务一多，很难在海量日志中拼凑出一条完整调用路径
- 同一条请求在不同服务的日志之间，很难做“关联”

### 3. Traces（分布式追踪 / 调用链）

Trace 是 OpenTelemetry 最重要的一类数据：

- 一次 **端到端请求**，是一条完整的 Trace
- Trace 由多个 **Span（跨度）** 组成，每个 Span 表示一次操作
  - 比如：
    - Web 网关处理 HTTP 请求
    - 服务 A 调用服务 B
    - 服务 B 操作数据库

有了 Trace，我们可以：

- 清晰看到一次请求 **经过了哪些服务、每一步耗时多少**
- 快速定位 **慢在哪、错在哪**

在现代可观测性方案里，**Metrics + Logs + Traces 是互补关系**：

- Metrics 告诉你“哪里有问题”（报警）
- Traces 帮你跟到具体某次请求“发生了什么”
- Logs 提供最细粒度的信息（异常堆栈、业务数据）

OpenTelemetry 要做的，就是为这三类数据提供 **统一的标准和采集方案**。


## 二、OpenTelemetry：目标与整体架构

### 1. OpenTelemetry 想解决什么问题？

在 OTel 之前，监控生态非常割裂：

- Tracing 有 Zipkin、Jaeger、SkyWalking，各自协议不兼容
- Metrics 有 Prometheus、StatsD、各种 SDK
- Logs 则更加碎片化

问题在于：

- **每接入一个新后端，就要换一套 SDK 或者埋点**
- 语言不统一、协议不统一，迁移成本极高

OpenTelemetry 的核心目标可以概括为：

- **提供一套统一的 API / SDK 标准**，屏蔽底层实现差异
- 定义 **统一的传输协议（OTLP）** 和数据模型
- 通过 **Collector 作为中枢**，把数据转发到不同后端

简单理解：

> OpenTelemetry 不是一个“监控后端系统”，而是一个 **标准 + SDK + Collector**，帮你把可观测性数据采集好，然后送给你喜欢的后端。

### 2. OTel 的主要组成部分

从整体上看，OpenTelemetry 主要有以下几个关键组件：

- **API**：
  - 定义了 Tracer、Meter 等接口
  - 让你的代码只依赖统一 API，而不关心具体实现

- **SDK**：
  - API 的具体实现
  - 提供采样器、导出器（Exporter）、SpanProcessor 等

- **Exporter**：
  - 决定数据往哪儿发
  - 比如导出到：OTLP、Jaeger、Zipkin、Prometheus 等

- **Collector**：
  - 独立进程/服务
  - 负责接收来自各语言 SDK 的数据（通常用 OTLP 协议）
  - 可以做数据加工、采样、聚合，再转发到各种后端

- **后端（Backend）**：
  - 例如：Jaeger、Tempo、Zipkin（链路），Prometheus（指标）、Loki/Elastic（日志），商用 APM 等

一个典型的链路是：

> 业务代码 → OTel SDK（埋点 + 自动注入）→ OTLP → Collector → 后端（APM / 时序数据库 / 日志系统）


## 三、核心概念梳理

### 1. Trace、Span、SpanContext

- **Trace**：
  - 一次端到端请求，包含多个 Span
  - 有一个全局唯一的 `TraceId`

- **Span**：
  - 一次具体操作的时间片段
  - 有 `SpanId`、起止时间、属性（Attributes）、事件（Events）等
  - 通过 `ParentSpanId` 形成调用层级

- **SpanContext**：
  - 携带 TraceId、SpanId 等上下文信息
  - 会通过 HTTP Header、RPC Metadata 等方式在服务间传递

### 2. Resource（资源）

Resource 用于描述 **产生数据的实体是谁**，比如：

- 服务名（`service.name`）
- 部署环境（dev / staging / prod）
- 版本号（`service.version`）

在后端界面里，经常会按 `service.name` 维度来筛选和聚合，所以 **规范的 Resource 配置非常重要**。

### 3. Instrumentation Library / Scope

表示“是谁”打的点：

- 比如：`io.opentelemetry.contrib.http` 这样的 HTTP 客户端库
- 便于在后端区分：哪些 span 是应用自定义埋点，哪些由第三方库自动注入

### 4. Sampler（采样器）

Tracing 与 Metrics 不同，如果每个请求都打满调用链，在高 QPS 服务下数据量会非常恐怖。

采样器的作用是控制 **哪些 Trace 被记录**，常见策略：

- AlwaysOn / AlwaysOff
- 头部采样（基于上游决定）
- 比例采样（例如 1%）
- 基于规则/属性采样（例如对错误请求全采样）

合理配置采样策略是 **既控制成本又保证排障能力** 的关键。

### 5. Exporter（导出器）

Exporter 决定数据发到哪里：

- OTLP（推荐，统一协议）
- Jaeger、Zipkin（用于链路追踪）
- Prometheus（指标）

在生产环境中，常见的模式是：

- 应用只配置 **OTLP Exporter 指向 Collector**
- Collector 根据配置再导出到多个后端（例如同时发给 Prometheus、Tempo、Loki）


## 四、典型数据流：应用 → Collector → 后端

我们用文字描述一个典型的 OpenTelemetry 数据流：

1. **应用层（App）**
   - 在代码中引入 OTel SDK
   - 初始化 TracerProvider / MeterProvider
   - 为 HTTP 服务、gRPC、数据库驱动等接入自动化埋点

2. **传输层（OTLP）**
   - 应用通过 OTLP/gRPC 或 OTLP/HTTP 将数据发给 Collector
   - 一般配置成异步批量导出

3. **Collector**
   - 接收不同协议（OTLP、Jaeger、Zipkin 等）
   - 通过 pipeline 做处理：
     - receivers → processors → exporters
   - 把处理后的数据发送到不同后端

4. **后端**
   - 链路后端（例如 Jaeger/Tempo）：负责存储和查询 Trace
   - 指标后端（例如 Prometheus / Mimir）：用于绘制图表、告警
   - 日志后端（例如 Loki / Elastic）：存储日志，并可根据 TraceId 做关联查询

这种解耦的好处是：

- 应用只需要关注 OTel SDK + OTLP
- Collector 成为“路由中心”，可以随时变更/扩展后端，而无需修改业务代码


## 五、一个简单示例（以 Go HTTP 服务为例）

下面是一个非常简化的 Go 示例，用来感受一下 OTel 的使用方式（仅展示核心思路，具体版本和 API 以官方文档为准）。

### 1. 初始化 TracerProvider

```go
import (
    "context"
    "log"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
    "google.golang.org/grpc"
)

func initTracerProvider(ctx context.Context) (*sdktrace.TracerProvider, error) {
    // 1. 创建 OTLP gRPC 导出器，指向 Collector
    conn, err := grpc.DialContext(ctx, "otel-collector:4317",
        grpc.WithInsecure(),
        grpc.WithBlock(),
    )
    if err != nil {
        return nil, err
    }

    exporter, err := otlptracegrpc.New(ctx, otlptracegrpc.WithGRPCConn(conn))
    if err != nil {
        return nil, err
    }

    // 2. 定义 Resource（服务名、环境等）
    res, err := resource.New(ctx,
        resource.WithAttributes(
            semconv.ServiceNameKey.String("demo-api"),
            semconv.DeploymentEnvironmentKey.String("dev"),
        ),
    )
    if err != nil {
        return nil, err
    }

    // 3. 创建 TracerProvider
    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
    )

    // 4. 设置为全局
    otel.SetTracerProvider(tp)

    return tp, nil
}
```

### 2. 在 HTTP Handler 中打点

```go
import (
    "net/http"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
)

func helloHandler(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    tracer := otel.Tracer("demo-api/handler")

    // 创建一个新的 Span
    ctx, span := tracer.Start(ctx, "helloHandler")
    defer span.End()

    // 添加一些业务属性
    span.SetAttributes(
        attribute.String("http.route", "/hello"),
        attribute.String("user.id", "123"),
    )

    w.Write([]byte("hello, otel"))
}
```

### 3. Collector 简单配置示例

下面是一个极简的 Collector 配置示例，展示典型的 `receivers → processors → exporters` 管道：

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:

exporters:
  otlp:
    endpoint: "tempo:4317"  # 发送到链路后端
    tls:
      insecure: true

  prometheus:
    endpoint: "0.0.0.0:8889" # 暴露指标给 Prometheus 抓取

processors:
  batch: {}

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp]

    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
```

实际生产环境配置会复杂很多，但基本结构都是这几个元素：

- **receivers**：接收上游数据（OTLP、Jaeger、Zipkin 等）
- **processors**：批量、过滤、采样、重写标签等
- **exporters**：输出到后端（OTLP、Prometheus、Loki 等）
- **pipelines**：把三者串起来，对 traces / metrics / logs 分别配置


## 六、落地实践中的一些经验和建议

### 1. 从 Trace 开始，再扩展到 Metrics / Logs

对于大多数团队，**分布式调用链是最直观的收益点**：

- 先让关键服务链路打通（例如 HTTP 网关 → 核心服务 → DB）
- 确认 TraceId 在各服务之间成功传递
- 再逐步扩展到 Metrics 和 Logs 的关联

这样做可以避免一开始就铺太大战线，导致推进困难。

### 2. 统一命名规范

可观测性数据的“可查性”高度依赖命名：

- `service.name`：约定命名风格，例如 `project-module-env`
- Span 名称：建议使用 **动词 + 资源** 的方式，例如 `GET /api/v1/orders`，`SELECT user` 等
- Attributes：关键业务字段（订单号、用户 ID）要结构化出来，而不是只写在日志文本里

统一的命名规范可以极大提升检索效率和跨团队协作体验。

### 3. 采样策略一定要提前设计

Tracing 的成本不容忽视：

- QPS 很高的服务，如果全量采集，存储和网络压力都非常大
- 一刀切的随机采样，可能恰好丢掉了关键错误请求

通用建议：

- 默认使用 **概率采样**（例如 1%）
- 对错误请求、慢请求、特定业务（如支付）可以提高采样率或全采样
- 在 Collector 层配合做下游采样和过滤，减少后端压力

### 4. 上下文传递要连贯（Trace 不要“断链”）

最常见的坑之一就是 Trace 断链：

- 上游没把 TraceId 注入 HTTP 头部 / RPC metadata
- 下游没从请求中把上下文提取出来
- 不同语言/框架使用了不同的上下文注入/提取方式

建议：

- **尽量使用官方或成熟社区提供的自动化 Instrumentation**（例如 HTTP Client/Server、gRPC、数据库驱动）
- 保证所有服务都使用相同的 **上下文传播规范（如 W3C TraceContext）**

### 5. 联合使用 Metrics + Traces + Logs

真正给排障提效的是三者的关联：

- 告警往往是 Metrics 触发的（例如错误率升高、延迟升高）
- 然后跳转到对应时间段、对应服务的 Traces
- 再从特定 Span 中关联到 Logs（根据 TraceId / SpanId 查询）

因此在日志中：

- 建议把 `trace_id`、`span_id` 等字段打出来
- 方便从链路视图“一键跳转”到完整日志


## 七、一些常见踩坑记录

结合实际体验，总结几个容易踩的坑：

- **Collector 性能和可靠性被忽略**：
  - Collector 本身也是生产级组件，需要做高可用和资源规划
  - 否则 Collector 挂了，整个链路数据就中断

- **协议混用导致上下文丢失**：
  - 部分服务使用自定义 Header 或旧协议，没按 W3C TraceContext 来
  - 导致跨语言、跨框架时 Trace 无法串起来

- **Exporter 配置过多直接在应用中写死**：
  - 一开始图省事，在应用里同时配置了多种 Exporter（Jaeger、Zipkin、OTLP……）
  - 后面想替换后端就很痛苦
  - 更好的方式是：应用只发 OTLP 到 Collector，后端变化都在 Collector 配置层处理

- **版本兼容问题**：
  - OTel 生态发展很快，SDK、Collector、后端的版本配合很关键
  - 升级前要看好 **Breaking Changes**，尽量对齐一套兼容矩阵


## 结语：把可观测性当成“工程能力”来建设

OpenTelemetry 提供的是一套 **开放、统一、可扩展的“可观测性基础设施”**：

- 它不是某个具体厂商的产品，而是一个社区标准
- 它的价值不只在于“能打链路”，更重要的是 **统一数据模型和采集方式**

从工程实践的角度，我的体会是：

- 不要把可观测性当作“运维的事”，而应该融入开发流程
- 在设计接口、定义服务边界、拆解模块时，就要考虑监控和追踪
- 通过 OpenTelemetry，把 Metrics / Logs / Traces 串在一起，构建真正可观测的系统

如果你刚开始接触 OTel，可以按以下顺序推进：

1. 选定一条关键业务链路，从 Trace 入手打通调用链
2. 引入 Collector，把数据统一转发到现有后端
3. 逐步完善 Resource、命名规范和采样策略
4. 最后再考虑与日志、指标深度联动

这样，既能快速看到收益，又能控制复杂度和改造成本。
