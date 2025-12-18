---
title: 推送中心设计：企业级多渠道通知的基础设施
date: 2025-12-18 14:00:00 +0800
categories: [分布式]
tags: [推送, 通知, 消息队列, 稳定性, 架构设计]
---

## 概述

在企业级系统演进的过程中，推送（Push）功能往往从最初的"业务系统直连三方通道"，逐步演进到"独立的推送中心服务"。这篇文章从工程实践的角度，讨论为什么需要独立推送中心、如何设计才能既满足业务复杂需求，又能保证系统稳定性和可观测性。

本文的核心观点：
- **推送中心的本质是通道适配层与发送流程编排**，而不是消息中心
- **通道抽象是灵活扩展的基础**：支持新增渠道不改动已有逻辑
- **稳定性设计是重中之重**：重试策略、幂等、限流、降级
- **推送中心不做业务决策**：决定"谁该收到什么"是上游的责任
- **可观测性与治理是长期价值**：成本、SLA、发送成功率都要可控

---

## 第一部分：为什么要有"推送中心"？

### 1.1 问题的演进

**第一阶段：业务系统直连三方通道（反面案例）**

在小型系统中，推送逻辑往往散落在各个业务系统：

```java
// 反面案例：业务系统直接调用三方 SDK
public class OrderService {
    
    public void notifyOrderCreated(Order order) {
        // 短信
        AliyunSms sms = new AliyunSms(accessKey, secret);
        sms.send(order.getPhone(), "订单已创建");
        
        // 飞书
        LarkRobot robot = new LarkRobot(webhookUrl);
        robot.sendMessage("订单 #" + order.getId() + " 已创建");
        
        // 邮件（内部实现）
        emailService.send(order.getEmail(), "订单确认", htmlContent);
    }
}
```

问题显而易见：
- **通道 SDK 分散**：每个系统都要引入和维护多个第三方库
- **模板重复**：同样的"订单创建"模板在多个系统里写一遍
- **无法控制成本**：谁在用短信？成本多少？无法统计
- **缺乏重试机制**：发送失败就失败了，用户收不到通知
- **无监控**：发送成功率、失败原因是什么，全不知道
- **难以变更**：要改短信供应商，所有系统都要改代码
- **无幂等保证**：不知道是否重复发送了

这种模式的最大问题是：**不可控、不可观测、不可维护**。

**第二阶段：推送逻辑框架化（半分散模式）**

有些团队尝试做推送库，在多个项目中共享：

```java
// 推送库
public class PushKit {
    public void send(PushRequest request) {
        // 内部封装短信、邮件的逻辑
        // 但仍然是同步调用，强耦合
    }
}

// 在各个业务系统中使用
PushKit.send(new PushRequest()
    .setUserId(123)
    .setChannels(Arrays.asList("SMS", "EMAIL"))
    .setTemplateId("order_created")
    .setParams(params)
);
```

问题仍然存在：
- 强耦合：业务系统的推送逻辑变更，库要升级
- 跨系统数据难以统一：无法全局查看推送统计
- 无法灵活治理：限流、降级、通道切换都很困难

**第三阶段：独立推送中心（本文重点）**

将推送功能独立出来，形成一个专门的服务：

```
┌──────────────────────────────────────┐
│   业务系统（订单/支付/用户等）       │
│   - 决定谁该收到通知                 │
│   - 调用推送中心 API                 │
└─────────────┬────────────────────────┘
              │ 推送请求（异步）
              ↓
    ┌────────────────────────┐
    │     推送中心服务        │
    │                        │
    │  - 请求校验            │
    │  - 模板渲染            │
    │  - 通道适配            │
    │  - 发送执行            │
    │  - 回执处理            │
    │  - 监控统计            │
    └────────────────────────┘
              │
      ┌───────┴────────────┬──────────┐
      ↓                    ↓          ↓
   短信服务商      飞书 Bot    邮件服务
  （阿里云）    （企业微信）  （SendGrid）
```

### 1.2 独立推送中心的核心价值

| 价值维度 | 具体表现 | 工程收益 |
|--------|---------|---------|
| **通道统一** | 所有通道通过一个中心接入，统一管理 | 新增通道不改业务系统代码 |
| **模板集中** | 推送模板在一个地方维护 | 模板变更无需改代码、发版 |
| **可观测性** | 每条推送都有唯一 ID，全流程可追踪 | 快速定位发送失败原因 |
| **成本可控** | 统一计费接口，按通道统计成本 | 可评估不同渠道的投入产出 |
| **稳定性保证** | 统一的重试、限流、熔断策略 | 发送成功率有保证，SLA 可测 |
| **灵活治理** | 支持限流、降级、通道优先级调整 | 应对突发流量、三方故障 |
| **职责清晰** | 业务系统专注业务，推送中心专注发送 | 降低单个系统的复杂度 |

---

## 第二部分：推送中心 vs 消息中心：职责边界

### 2.1 概念辨析

这两个概念经常被混淆，但职责完全不同：

| 维度 | 推送中心 | 消息中心 |
|-----|-------|--------|
| **核心职责** | 将消息发送到用户（通过多种渠道） | 异步解耦业务流程，保证消息可靠传递 |
| **输入** | 内容 + 用户信息 + 通道选择 | 业务事件（如订单创建） |
| **输出** | 用户收到通知（短信/邮件/IM） | 下游系统接收事件 |
| **关键指标** | 送达率、成功率、延迟 | 消息堆积、重复消费、丢失 |
| **使用方** | 通知类业务需求 | 全部异步解耦的业务流程 |
| **可靠性要求** | 高（用户能感知） | 更高（业务依赖） |

**一个常见的错误：把推送中心做成消息中心**

```
错误架构：
业务系统 → [推送中心] → [消息队列] → [通道发送]
                  ↓
            维护消息可靠性
            维护消费状态
            处理重复消费
```

**正确架构：**

```
业务系统 → [消息队列] → [消费端处理] → [推送中心] → 三方通道
                      ↓
                  业务决策
                 （谁该收到什么）
```

### 2.2 推送中心的输入与输出

**输入：推送请求**

```json
{
  "request_id": "req_abc123",
  "user_id": "user_123",
  "channels": ["SMS", "LARK"],
  "template_id": "order_created",
  "template_params": {
    "order_id": "ORD_456",
    "amount": "¥99.99",
    "delivery_date": "2025-12-20"
  },
  "urgency": "normal",
  "retry_policy": "default"
}
```

关键点：
- **request_id**：推送中心返回，用于追踪整个流程
- **user_id**：推送给谁，不是 phone/email（推送中心负责查询）
- **channels**：业务系统指定优先级，推送中心按顺序尝试
- **template_id**：不是内容本身，让推送中心去渲染

**输出：推送结果**

```json
{
  "request_id": "req_abc123",
  "status": "PARTIALLY_SUCCESS",
  "results": [
    {
      "channel": "SMS",
      "status": "SUCCESS",
      "message_id": "sms_xyz789",
      "sent_at": "2025-12-18T14:23:45Z"
    },
    {
      "channel": "LARK",
      "status": "FAILED",
      "error_code": "INVALID_LARK_ID",
      "error_msg": "User has no valid Lark account"
    }
  ],
  "completed_at": "2025-12-18T14:23:50Z"
}
```

### 2.3 推送中心不做什么

**不做业务决策**

推送中心不需要知道"为什么要通知这个用户"，也不做权限检查：

```java
// 错误做法：推送中心在审查业务决策
if (!order.isPaymentConfirmed()) {
    // 拒绝发送
}

// 正确做法：业务系统已经做了决策，推送中心只负责发送
// 业务系统已确保：该用户该收到这个通知
```

**不做消息队列**

推送中心采用异步发送，但不负责消息的可靠性传递（由上游消息队列负责）：

```
业务系统 ---(事件)---> 消息队列 ---(可靠投递)---> 推送消费端 ---> 推送中心
          ↑                                         ↑
      业务系统确保             推送消费端确保
      消息入队                 请求到达推送中心
```

**不做模板的复杂逻辑**

模板渲染应该简单、快速：

```
正确做法：${order_id}、${amount} 这样的变量替换

错误做法：模板中包含 if/for 等复杂逻辑
         或者要调用业务系统的 API 获取上下文
```

---

## 第三部分：推送中心的核心设计目标

### 3.1 五大设计目标

**1. 高可用**

- 推送中心故障不能导致业务流程卡住（应该是异步的，业务系统无需等待）
- 三方通道故障（短信供应商宕机）不能中断整个流程
- 支持多活部署，任何一个实例宕机都能自动转移

**2. 可扩展**

- 新增通道（比如钉钉、企业微信）**不修改现有代码**
- 新增模板**不改推送中心逻辑**
- 支持自定义发送策略（比如某些用户优先走飞书而不是短信）

**3. 可观测**

- 每条推送都有唯一 ID，可追踪全流程
- 能看到：发送成功率、失败原因分布、渠道延迟、用户送达情况
- 支持按模板、按通道、按业务维度统计

**4. 可治理**

- 限流：防止突发流量压垮推送中心或三方通道
- 熔断：三方通道故障时自动降级到其他通道
- 通道优先级调整：无需重新发版，直接改配置

**5. 成本可控**

- 按通道、按费率精确计费
- 支持费率动态调整
- 成本超限告警

### 3.2 关键指标体系

```
推送中心的关键指标：

1. 吞吐量（TPS）
   - 目标：支撑业务峰值，通常在 1000-10000 TPS

2. 发送成功率
   - 定义：最终至少有一个渠道成功送达的请求占比
   - 目标：>= 99%

3. 端到端延迟（P99）
   - 从业务系统发起到推送中心反馈的时间
   - 目标：<= 200ms（异步）

4. 通道成功率（按渠道）
   - SMS：通常 95-98%（运营商限流、号码黑名单）
   - 飞书/企业微信：通常 99%+ （企业用户稳定）
   - 邮件：通常 90-95% （垃圾邮件、收件箱满）

5. 重试成功率
   - 经过重试最终成功的比例
   - 目标：>= 80%（对初次失败的请求）

6. 单位成本（Cost Per Push）
   - 按渠道统计
   - 用于评估通道优先级
```

---

## 第四部分：总体架构设计

### 4.1 逻辑分层

```
┌────────────────────────────────────────────────────────┐
│  业务系统 API 层                                        │
│  - 接收推送请求                                        │
│  - 参数校验                                            │
│  - 返回 request_id                                     │
└────────────┬─────────────────────────────────────────┘
             │ 异步（通过消息队列或本地队列）
             ↓
┌────────────────────────────────────────────────────────┐
│  推送编排层                                            │
│  - 请求去重 / 幂等性检查                               │
│  - 发送策略评估（选择通道）                            │
│  - 模板渲染                                            │
│  - 用户信息补全（phone / email / lark_id 等）         │
└────────────┬─────────────────────────────────────────┘
             │
             ↓
┌────────────────────────────────────────────────────────┐
│  通道适配层                                            │
│  - Channel 接口实现                                    │
│  - 短信 Channel                                       │
│  - 飞书 / 企业微信 Channel                             │
│  - 邮件 Channel                                       │
└────────────┬─────────────────────────────────────────┘
             │ 异步
             ↓
┌────────────────────────────────────────────────────────┐
│  执行层                                                │
│  - 调用三方 API                                        │
│  - 处理响应 / 错误                                     │
│  - 重试逻辑                                            │
└────────────┬─────────────────────────────────────────┘
             │
             ↓
┌────────────────────────────────────────────────────────┐
│  回执处理层                                            │
│  - 接收三方回执（成功 / 失败 / 送达）                  │
│  - 更新发送状态                                        │
│  - 触发下游流程（通知业务系统）                        │
└────────────┬─────────────────────────────────────────┘
             │
             ↓
┌────────────────────────────────────────────────────────┐
│  监控 & 日志层                                         │
│  - 记录每条推送的全生命周期                            │
│  - 生成指标数据                                        │
│  - 支持链路追踪                                        │
└────────────────────────────────────────────────────────┘
```

### 4.2 发送流程（时序图）

```
业务系统                推送中心              消息队列           通道
   │                      │                    │               │
   ├──推送请求──────────>│                    │               │
   │                      │                    │               │
   │<────request_id───────│                    │               │
   │                      │                    │               │
   │                      ├───入队────────────>│               │
   │                      │                    │               │
   │                      │<───从队列取────────│               │
   │                      │                    │               │
   │                      ├──请求去重/幂等────│               │
   │                      │ （查 Redis）      │               │
   │                      │                    │               │
   │                      ├───渲染模板        │               │
   │                      │ （查模板数据库）   │               │
   │                      │                    │               │
   │                      ├───查用户信息      │               │
   │                      │ （查 Redis/DB）   │               │
   │                      │                    │               │
   │                      ├───选择通道        │               │
   │                      │ （根据策略）      │               │
   │                      │                    │               │
   │                      ├──调用通道发送────────────────────>│
   │                      │                                    │
   │                      │                  (异步回调)        │
   │                      │<──通道成功响应────────────────────│
   │                      │                                    │
   │                      ├──更新发送状态     │               │
   │                      │ （写数据库）      │               │
   │                      │                    │               │
   │                      ├──生成指标        │               │
   │                      │                    │               │
   │ (可选：查询状态)     │                    │               │
   ├──查询 request_id─────>│                    │               │
   │                      │                    │               │
   │<────发送状态─────────│                    │               │
```

### 4.3 同步 vs 异步的取舍

**同步发送（不推荐）**

```
业务系统 
  │
  ├─> 调用推送中心 API
  │   │
  │   ├─> 等待推送中心响应（可能 200ms-1s）
  │   │
  │   └─> 返回给业务系统
  │
  └─> 继续业务流程
```

问题：
- 推送中心任何延迟都会阻塞业务流程
- 推送中心故障会导致业务流程卡住
- 难以扩展到大规模

**异步发送（推荐）**

```
业务系统 
  │
  ├─> 调用推送中心 API（立即返回 request_id）
  │   │
  │   └─> 返回给业务系统（< 10ms）
  │
  ├─> 继续业务流程（无需等待）
  │
  └─> 后续可查询 request_id 获取最终状态
      
推送中心（异步处理）
  │
  ├─> 从消息队列取请求
  │   │
  │   ├─> 渲染、发送
  │   │
  │   └─> 更新状态
  │
  └─> 可选：回调通知业务系统
```

这样做的好处：
- 业务流程不受推送中心影响
- 推送中心可以独立扩展
- 支持重试、降级、限流

**建议：采用异步 + 可选的回调通知**

```java
// 业务系统发起推送（异步）
PushRequest request = new PushRequest()
    .setUserId("user_123")
    .setChannels(Arrays.asList("SMS", "LARK"))
    .setTemplateId("order_created")
    .setParams(params)
    .setCallbackUrl("https://biz-system/push/callback");  // 可选

PushResponse response = pushCenterClient.sendAsync(request);
// 立即返回 request_id，无需等待

String requestId = response.getRequestId();
// 保存 request_id，可以后续查询状态

// 如果指定了 callbackUrl，推送中心会在发送完成后回调
// POST https://biz-system/push/callback
// {
//   "request_id": "req_abc123",
//   "status": "SUCCESS",
//   "results": [...]
// }
```

---

## 第五部分：通道抽象与插件化设计

### 5.1 为什么要做 Channel 抽象

假设没有抽象，直接在推送服务里写各种通道的逻辑：

```java
// 反面案例：耦合的实现
@Service
public class PushService {
    
    public void send(PushRequest request) {
        // 短信逻辑
        if (request.getChannels().contains("SMS")) {
            AliyunSms sms = new AliyunSms(config.getAccessKey(), 
                                         config.getSecret());
            sms.send(userPhone, content);
        }
        
        // 飞书逻辑
        if (request.getChannels().contains("LARK")) {
            LarkClient client = new LarkClient(config.getLarkToken());
            client.sendMessage(userId, content);
        }
        
        // 邮件逻辑
        if (request.getChannels().contains("EMAIL")) {
            EmailService emailService = new EmailService();
            emailService.send(userEmail, subject, content);
        }
        
        // ...更多通道
    }
}
```

问题：
- **新增通道需要修改 send 方法**（违反开闭原则）
- **每次修改都要重新测试所有通道**
- **通道的配置、重试策略混在一起**
- **难以独立控制某个通道的行为**

### 5.2 通道抽象

**统一的 Channel 接口：**

```java
public interface PushChannel {
    
    /**
     * 发送推送
     * @param request 推送请求
     * @return 发送结果
     */
    ChannelResult send(ChannelRequest request) throws ChannelException;
    
    /**
     * 获取通道名称
     */
    String getChannelName();
    
    /**
     * 该通道是否支持该用户
     * 例如：短信通道需要用户有有效的手机号
     */
    boolean isSupported(User user);
    
    /**
     * 获取该通道的配置
     */
    ChannelConfig getConfig();
    
    /**
     * 健康检查
     */
    boolean isHealthy();
}
```

**短信通道实现：**

```java
@Component
public class SmsChannel implements PushChannel {
    
    private final AliyunSmsClient smsClient;
    private final UserService userService;
    
    @Override
    public ChannelResult send(ChannelRequest request) throws ChannelException {
        try {
            User user = userService.getUser(request.getUserId());
            String phone = user.getPhone();
            
            if (StringUtils.isBlank(phone)) {
                return ChannelResult.unsupported("No valid phone number");
            }
            
            // 调用阿里云短信 API
            SendSmsResponse response = smsClient.sendSms(
                phone,
                request.getSignName(),
                request.getTemplateCode(),
                request.getTemplateParams()
            );
            
            return ChannelResult.success(response.getRequestId());
            
        } catch (Exception e) {
            throw new ChannelException("SMS send failed", e);
        }
    }
    
    @Override
    public String getChannelName() {
        return "SMS";
    }
    
    @Override
    public boolean isSupported(User user) {
        return user.getPhone() != null && !user.getPhone().isEmpty();
    }
    
    @Override
    public ChannelConfig getConfig() {
        return new ChannelConfig()
            .setMaxRetries(3)
            .setRetryDelayMs(5000)
            .setTimeoutMs(10000)
            .setRateLimit(1000);  // QPS limit
    }
}
```

**飞书通道实现：**

```java
@Component
public class LarkChannel implements PushChannel {
    
    private final LarkClient larkClient;
    private final UserService userService;
    
    @Override
    public ChannelResult send(ChannelRequest request) throws ChannelException {
        try {
            User user = userService.getUser(request.getUserId());
            String larkUserId = user.getLarkUserId();
            
            if (StringUtils.isBlank(larkUserId)) {
                return ChannelResult.unsupported("No valid Lark ID");
            }
            
            SendMessageResponse response = larkClient.sendMessage(
                new SendMessageRequest()
                    .setReceiverId(larkUserId)
                    .setMsgType("text")
                    .setContent(request.getContent())
            );
            
            return ChannelResult.success(response.getMessageId());
            
        } catch (Exception e) {
            throw new ChannelException("Lark send failed", e);
        }
    }
    
    @Override
    public String getChannelName() {
        return "LARK";
    }
    
    @Override
    public boolean isSupported(User user) {
        return user.getLarkUserId() != null 
            && !user.getLarkUserId().isEmpty();
    }
    
    @Override
    public ChannelConfig getConfig() {
        return new ChannelConfig()
            .setMaxRetries(2)
            .setRetryDelayMs(3000)
            .setTimeoutMs(5000)
            .setRateLimit(5000);  // Lark 允许更高 QPS
    }
}
```

**邮件通道实现：**

```java
@Component
public class EmailChannel implements PushChannel {
    
    private final EmailService emailService;
    private final UserService userService;
    
    @Override
    public ChannelResult send(ChannelRequest request) throws ChannelException {
        try {
            User user = userService.getUser(request.getUserId());
            String email = user.getEmail();
            
            if (StringUtils.isBlank(email)) {
                return ChannelResult.unsupported("No valid email");
            }
            
            String messageId = emailService.send(
                email,
                request.getSubject(),
                request.getHtmlContent(),
                request.getAttachments()
            );
            
            return ChannelResult.success(messageId);
            
        } catch (Exception e) {
            throw new ChannelException("Email send failed", e);
        }
    }
    
    @Override
    public String getChannelName() {
        return "EMAIL";
    }
    
    @Override
    public boolean isSupported(User user) {
        return user.getEmail() != null && !user.getEmail().isEmpty();
    }
    
    @Override
    public ChannelConfig getConfig() {
        return new ChannelConfig()
            .setMaxRetries(5)           // 邮件可以重试更多次
            .setRetryDelayMs(60000)     // 间隔更长
            .setTimeoutMs(30000)        // 邮件可以更慢
            .setRateLimit(500);         // QPS 较低
    }
}
```

### 5.3 推送中心的通道管理

**通道注册与管理：**

```java
@Component
public class ChannelRegistry {
    
    private final Map<String, PushChannel> channels = new ConcurrentHashMap<>();
    
    public ChannelRegistry(List<PushChannel> channelList) {
        for (PushChannel channel : channelList) {
            channels.put(channel.getChannelName(), channel);
        }
    }
    
    public PushChannel getChannel(String channelName) {
        PushChannel channel = channels.get(channelName);
        if (channel == null) {
            throw new ChannelNotFoundException("Channel not found: " + channelName);
        }
        return channel;
    }
    
    public List<PushChannel> getAll() {
        return new ArrayList<>(channels.values());
    }
    
    public boolean isChannelAvailable(String channelName) {
        PushChannel channel = channels.get(channelName);
        return channel != null && channel.isHealthy();
    }
}
```

**在推送中心中使用：**

```java
@Service
public class PushService {
    
    private final ChannelRegistry channelRegistry;
    private final ChannelSender channelSender;
    
    public void send(PushRequest request) {
        // 1. 获取请求指定的通道（按优先级）
        List<String> requestedChannels = request.getChannels();
        User user = userService.getUser(request.getUserId());
        
        // 2. 从 registry 中获取可用的通道
        List<PushChannel> availableChannels = new ArrayList<>();
        for (String channelName : requestedChannels) {
            PushChannel channel = channelRegistry.getChannel(channelName);
            
            // 检查该通道是否支持该用户
            if (channel.isSupported(user)) {
                availableChannels.add(channel);
            }
        }
        
        // 3. 异步发送到各通道
        for (PushChannel channel : availableChannels) {
            channelSender.sendAsync(channel, request, user);
        }
    }
}
```

### 5.4 新增通道的最小改动原则

要新增一个通道（比如企业微信），只需要：

1. **新建一个 Channel 实现类：**

```java
@Component
public class WechatWorkChannel implements PushChannel {
    // ... 实现 PushChannel 接口
}
```

2. **Spring 自动扫描并注册到 ChannelRegistry**

3. **可选：在配置中禁用某个通道**

```yaml
push:
  channels:
    enabled:
      - SMS
      - LARK
      - EMAIL
      - WECHAT_WORK    # 新增，无需改代码
    disabled:
      - DEPRECATED_CHANNEL
```

**完全不需要修改 PushService、通道选择逻辑等现有代码。**

---

## 第六部分：稳定性设计（重点）

### 6.1 重试策略

推送中心最关键的稳定性需求就是：**尽最大努力确保消息被送达**。

**重试的分类：**

```
立即重试（Short Retry）
  ├─ 用途：快速重试网络闪断、超时的失败
  ├─ 触发：第一次发送失败立即重试
  ├─ 次数：1-2 次
  ├─ 间隔：100ms - 1s
  └─ 例子：通道网络超时、临时服务异常

延迟重试（Delayed Retry）
  ├─ 用途：应对通道高负载、限流
  ├─ 触发：立即重试仍失败
  ├─ 次数：2-5 次
  ├─ 间隔：5s, 30s, 5min, 30min
  └─ 例子：三方 API 返回限流、超载

死信队列（Dead Letter）
  ├─ 用途：所有重试都失败，保存以供人工处理
  ├─ 条件：重试次数用尽仍失败
  ├─ 处理：发告警、记录日志、人工评估
  └─ 例子：用户 phone 无效、账户余额不足
```

**实现重试策略：**

```java
public class RetryPolicy {
    
    // 立即重试配置
    private final int immediateRetries;      // 通常 1-2
    private final long immediateRetryDelayMs; // 100-1000ms
    
    // 延迟重试配置
    private final int delayedRetries;        // 通常 3-5
    private final long[] delayedRetryDelaysMs; // 5s, 30s, 5min, 30min
    
    public RetryPolicy() {
        this.immediateRetries = 2;
        this.immediateRetryDelayMs = 200;
        this.delayedRetries = 3;
        this.delayedRetryDelaysMs = new long[]{
            5_000,      // 5 秒
            30_000,     // 30 秒
            5 * 60_000  // 5 分钟
        };
    }
    
    public boolean shouldRetry(int currentAttempt, ChannelException exception) {
        // 某些错误不需要重试（如无效的用户信息）
        if (isNonRetryableError(exception)) {
            return false;
        }
        
        if (currentAttempt <= immediateRetries) {
            // 立即重试阶段
            return true;
        } else if (currentAttempt <= immediateRetries + delayedRetries) {
            // 延迟重试阶段
            return true;
        } else {
            // 所有重试用尽
            return false;
        }
    }
    
    public long getRetryDelayMs(int currentAttempt) {
        if (currentAttempt <= immediateRetries) {
            return immediateRetryDelayMs;
        } else {
            int delayedAttempt = currentAttempt - immediateRetries - 1;
            if (delayedAttempt < delayedRetryDelaysMs.length) {
                return delayedRetryDelaysMs[delayedAttempt];
            }
        }
        return -1;  // 不需要重试
    }
    
    private boolean isNonRetryableError(ChannelException exception) {
        // 用户不存在、phone 无效等
        return exception.getErrorCode().startsWith("INVALID_");
    }
}
```

**在发送流程中应用重试：**

```java
@Component
public class ChannelSender {
    
    private final RetryPolicy retryPolicy;
    private final ScheduledExecutorService scheduler;
    
    public void sendAsync(PushChannel channel, PushRequest request, User user) {
        ChannelRequest channelRequest = new ChannelRequest()
            .setUserId(request.getUserId())
            .setContent(request.getContent())
            .setTemplateParams(request.getTemplateParams());
        
        // 从重试队列中取，或者立即发送
        doSend(channel, channelRequest, user, 1);  // 第 1 次尝试
    }
    
    private void doSend(PushChannel channel, ChannelRequest request, 
                       User user, int attempt) {
        try {
            ChannelResult result = channel.send(request);
            
            if (result.isSuccess()) {
                // 发送成功，记录日志、指标
                logSuccess(request, channel, result);
            }
            
        } catch (ChannelException e) {
            
            if (retryPolicy.shouldRetry(attempt, e)) {
                // 需要重试
                long delayMs = retryPolicy.getRetryDelayMs(attempt);
                
                scheduler.schedule(
                    () -> doSend(channel, request, user, attempt + 1),
                    delayMs,
                    TimeUnit.MILLISECONDS
                );
                
                logRetry(request, channel, e, attempt, delayMs);
                
            } else {
                // 放入死信队列，记录失败
                deadLetterQueue.push(new DeadLetter(
                    request,
                    channel.getChannelName(),
                    e,
                    attempt
                ));
                
                logFailure(request, channel, e, attempt);
            }
        }
    }
}
```

**三方回调的处理（异步更新）：**

有些通道（如短信）会在实际送达时回调推送中心，更新最终状态：

```java
@RestController
@RequestMapping("/api/push/callbacks")
public class CallbackController {
    
    @PostMapping("/sms/receipt")
    public ResponseEntity<?> smsReceipt(@RequestBody SmsReceiptRequest receipt) {
        // 三方短信网关回调，报告消息是否送达用户手机
        
        String messageId = receipt.getMessageId();
        String status = receipt.getStatus();  // success / failed / delivered
        
        // 更新推送记录
        pushRecordService.updateStatus(messageId, status);
        
        // 如果是最终失败，可能需要触发降级逻辑
        if ("failed".equals(status)) {
            pushRecordService.tryFallbackChannel(messageId);
        }
        
        return ResponseEntity.ok().build();
    }
}
```

### 6.2 幂等与重复发送防护

**问题：网络重复、消息队列重复消费等原因可能导致重复发送**

```
场景 1：网络重复
业务系统 --push_request--> 推送中心
                           (处理中，正在发送)
业务系统 --push_request--> 推送中心  (重复请求)

场景 2：消息队列重复消费
推送消费端 --取消息--> 消息队列
推送中心   --处理-->
推送中心   --ack--> (网络断开，重新消费)

场景 3：推送中心内部重试
延迟重试队列 --推送请求--> 推送中心（再次处理）
```

**幂等性设计：**

```java
@Service
public class PushService {
    
    private final RedisTemplate<String, String> redis;
    
    public void send(PushRequest request) {
        // 生成幂等 key（基于 request_id 和目标信息）
        String idempotentKey = generateIdempotentKey(request);
        
        // 检查是否已处理过
        String cached = redis.opsForValue().get(idempotentKey);
        if (cached != null) {
            // 已经处理过，返回之前的结果
            log.info("Duplicate request detected, returning cached result: {}", 
                     idempotentKey);
            return;
        }
        
        try {
            // 标记为"正在处理"
            redis.opsForValue().set(
                idempotentKey,
                "PROCESSING",
                Duration.ofMinutes(5)
            );
            
            // 执行推送
            doSend(request);
            
            // 标记为"已处理"
            redis.opsForValue().set(
                idempotentKey,
                "DONE",
                Duration.ofHours(24)  // 保留 24 小时以防重复
            );
            
        } catch (Exception e) {
            // 异常时，清除"正在处理"标记，允许重试
            redis.delete(idempotentKey);
            throw e;
        }
    }
    
    private String generateIdempotentKey(PushRequest request) {
        // 基于 request_id 和主要参数生成唯一 key
        String key = String.format(
            "push:idempotent:%s:%s:%s",
            request.getRequestId(),
            request.getUserId(),
            request.getTemplateId()
        );
        return key;
    }
}
```

**推送记录表设计（防重复）：**

```sql
CREATE TABLE `push_record` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `request_id` VARCHAR(128) UNIQUE NOT NULL,
  `user_id` BIGINT NOT NULL,
  `template_id` VARCHAR(64) NOT NULL,
  `channel` VARCHAR(32) NOT NULL,
  `status` VARCHAR(32) NOT NULL COMMENT 'PENDING/SUCCESS/FAILED',
  `message_id` VARCHAR(128) COMMENT '通道返回的消息 ID',
  `attempt_count` INT DEFAULT 1,
  `last_error` TEXT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  UNIQUE KEY unique_push (request_id, channel),
  INDEX idx_user_template (user_id, template_id),
  INDEX idx_status (status)
);
```

通过 `UNIQUE KEY unique_push (request_id, channel)` 保证即使重复发送，也只会在数据库中有一条记录。

### 6.3 限流与熔断

**限流的必要性**

```
场景 1：业务突发
  黑五、618 期间，订单激增
  推送流量可能瞬间达到平时 10 倍
  如果不限流，推送中心会被压垮

场景 2：三方通道限制
  短信通道：每个账户通常限流在 100-1000 QPS
  邮件：100-500 QPS
  如果超过限制，通道会返回限流错误

场景 3：成本控制
  不同通道的费率不同
  可能需要限制某个通道的使用量以控制成本
```

**限流实现：**

```java
@Component
public class RateLimiter {
    
    private final RedisTemplate<String, String> redis;
    
    /**
     * 令牌桶算法：支持突发流量
     */
    public boolean allowRequest(String key, int qps) {
        String bucketKey = "ratelimit:bucket:" + key;
        long now = System.currentTimeMillis();
        
        // 获取当前桶中的令牌数
        Long tokens = redis.opsForValue().increment(bucketKey);
        
        if (tokens == 1) {
            // 第一次访问，设置过期时间
            redis.expire(bucketKey, Duration.ofSeconds(1));
        }
        
        // 每秒补充 qps 个令牌
        if (tokens <= qps) {
            return true;
        } else {
            // 令牌不足，拒绝
            return false;
        }
    }
}

@Component
public class ChannelRateLimiter {
    
    private final RateLimiter rateLimiter;
    
    /**
     * 针对每个通道的限流
     */
    public boolean checkChannelRate(String channelName, ChannelConfig config) {
        String key = "channel:" + channelName;
        return rateLimiter.allowRequest(key, config.getRateLimit());
    }
    
    /**
     * 针对特定用户的限流（防止某个用户滥用）
     */
    public boolean checkUserRate(String userId, int maxPerDay) {
        String key = "user:daily:" + userId;
        return rateLimiter.allowRequest(key, maxPerDay);
    }
}
```

**在发送前检查限流：**

```java
@Service
public class PushService {
    
    private final ChannelRateLimiter rateLimiter;
    
    public void send(PushRequest request) {
        // 1. 检查用户级别的限流
        if (!rateLimiter.checkUserRate(request.getUserId(), 100)) {
            throw new RateLimitException("User rate limit exceeded");
        }
        
        // 2. 选择通道并检查通道级别的限流
        List<String> requestedChannels = request.getChannels();
        for (String channelName : requestedChannels) {
            PushChannel channel = channelRegistry.getChannel(channelName);
            ChannelConfig config = channel.getConfig();
            
            if (rateLimiter.checkChannelRate(channelName, config)) {
                // 这个通道有容量，可以发送
                doSendToChannel(channel, request);
                return;
            }
        }
        
        // 所有通道都限流了，进入等待队列
        pushQueue.enqueue(request);
    }
}
```

**熔断机制（应对三方故障）**

```java
@Component
public class CircuitBreaker {
    
    private final RedisTemplate<String, String> redis;
    
    public enum State {
        CLOSED,     // 正常，请求通过
        OPEN,       // 故障，请求直接拒绝
        HALF_OPEN   // 恢复中，允许部分请求通过以测试
    }
    
    public void recordFailure(String channelName) {
        String key = "circuit:" + channelName;
        
        // 记录失败次数
        Long failures = redis.opsForValue().increment(key + ":failures");
        
        // 如果连续失败超过阈值（如 10 次），打开熔断器
        if (failures >= 10) {
            redis.opsForValue().set(key + ":state", "OPEN", Duration.ofMinutes(5));
        }
    }
    
    public void recordSuccess(String channelName) {
        String key = "circuit:" + channelName;
        
        // 清除失败计数
        redis.delete(key + ":failures");
    }
    
    public boolean isOpen(String channelName) {
        String key = "circuit:" + channelName;
        String state = redis.opsForValue().get(key + ":state");
        return "OPEN".equals(state);
    }
}
```

**在通道发送中应用熔断：**

```java
@Service
public class ChannelSender {
    
    private final CircuitBreaker circuitBreaker;
    
    public void send(PushChannel channel, PushRequest request) {
        String channelName = channel.getChannelName();
        
        // 检查熔断器状态
        if (circuitBreaker.isOpen(channelName)) {
            log.warn("Circuit breaker is open for channel: {}, switching to fallback",
                     channelName);
            // 自动降级到其他通道
            switchToFallbackChannel(request);
            return;
        }
        
        try {
            ChannelResult result = channel.send(...);
            circuitBreaker.recordSuccess(channelName);
        } catch (Exception e) {
            circuitBreaker.recordFailure(channelName);
            
            // 如果这是第一个尝试的通道，立即降级
            switchToFallbackChannel(request);
        }
    }
    
    private void switchToFallbackChannel(PushRequest request) {
        // 尝试其他通道，按优先级
        // 例如：短信失败 -> 降级到飞书 -> 降级到邮件
    }
}
```

### 6.4 多通道降级策略

**场景：某个通道出现故障，需要自动切换到其他通道**

```
┌──────────────────────────────────────┐
│  业务系统指定的通道优先级             │
│  ["SMS", "LARK", "EMAIL"]            │
└──────────────────────────────────────┘
         ↓
  ┌──────────────────────────────────┐
  │  检查通道健康状态和限流           │
  │  1. SMS: 故障（熔断打开）        │
  │  2. LARK: 正常，发送              │
  │  3. EMAIL: 作为备选               │
  └──────────────────────────────────┘
         ↓
  ┌──────────────────────────────────┐
  │  执行发送                         │
  │  - 尝试 LARK（成功）             │
  │  - 记录：LARK 成功，SMS 跳过     │
  └──────────────────────────────────┘
```

**降级配置：**

```yaml
push:
  channel-priority:
    default: ["SMS", "LARK", "EMAIL"]  # 默认顺序
    # 特定模板的通道顺序
    order_created: ["LARK", "SMS"]
    payment_reminder: ["EMAIL", "SMS", "LARK"]
  
  fallback:
    enabled: true
    # 如果 SMS 故障，自动尝试下一个
    auto-switch: true
    # 短信故障超过阈值，自动禁用 SMS 一段时间
    disable-threshold: 20  # 连续 20 个失败
    disable-duration: 300  # 禁用 5 分钟
```

**动态调整通道优先级（无需重新发版）：**

```java
@RestController
@RequestMapping("/admin/push/channels")
public class ChannelAdminController {
    
    private final ChannelPriorityManager priorityManager;
    
    @PostMapping("/priority/update")
    public ResponseEntity<?> updatePriority(@RequestBody ChannelPriorityRequest request) {
        // 动态调整通道优先级
        // request: {
        //   "template_id": "order_created",
        //   "channels": ["LARK", "SMS", "EMAIL"]
        // }
        
        priorityManager.updatePriority(
            request.getTemplateId(),
            request.getChannels()
        );
        
        return ResponseEntity.ok("Channel priority updated");
    }
    
    @PostMapping("/disable/{channelName}")
    public ResponseEntity<?> disableChannel(@PathVariable String channelName,
                                           @RequestParam int durationMinutes) {
        // 紧急情况：禁用某个通道
        priorityManager.disableChannel(channelName, Duration.ofMinutes(durationMinutes));
        
        return ResponseEntity.ok("Channel disabled for " + durationMinutes + " minutes");
    }
}
```

---

## 第七部分：发送结果回执与状态管理

### 7.1 为什么必须接收回执

**问题：推送中心发送成功 ≠ 用户收到通知**

```
场景 1：短信送达率
发送给运营商 → 运营商发送给用户手机
推送中心只知道前半段的结果，不知道用户是否真的收到

场景 2：网络延迟
推送中心返回 200 OK → 实际发送还在进行中
用户急着去查"是否发送成功"，但结果不一致

场景 3：重复发送识别
没有完整的发送状态，难以判断是否该重试
```

### 7.2 回执的来源和处理

**来源 1：推送中心内部记录**

```
推送中心发送 -> 通道立即返回成功/失败 -> 推送中心记录
这是最快的反馈，延迟 < 100ms，但准确性取决于通道的实现
```

**来源 2：三方异步回调**

```
推送中心发送短信 -> 阿里云返回 200 OK
...后续...
用户收到短信 -> 阿里云回调推送中心的 callback 端点
-> 推送中心更新最终送达状态

这种情况可能延迟 30s-5min，但准确性最高
```

**来源 3：主动查询**

```
推送中心定期查询三方，获取消息的最终状态
用于处理回调丢失或超时的情况
```

### 7.3 回执延迟与丢失的处理

**回执延迟的特征：**

```
T0: 推送中心发送
T1: 通道返回成功（推送中心以为已完成）
T2-T100: 用户最终收到（异步回调）

业务系统在 T1 查询状态 → "已发送"
实际用户在 T50 才收到
```

**解决方案 1：分层状态定义**

```java
public enum PushStatus {
    PENDING,        // 待发送
    SENT,           // 已发送（通道已接受）
    DELIVERED,      // 已送达（用户已收到）
    FAILED,         // 失败
    UNKNOWN         // 未知（查询超时）
}
```

业务系统应该区分对待：
- 如果只需要"已通知"（送达给通道即可），查询 SENT
- 如果需要"用户已收到"（如重要通知），等待 DELIVERED

**解决方案 2：回调重试机制**

```java
@Component
public class CallbackProcessor {
    
    /**
     * 处理三方的异步回调（可能重复、乱序、延迟到达）
     */
    @RabbitListener(queues = "push.callback.queue")
    public void processCallback(CallbackMessage message) {
        String messageId = message.getMessageId();
        String status = message.getStatus();
        
        try {
            // 1. 幂等性检查（防止重复处理）
            if (callbackProcessed(messageId)) {
                log.info("Duplicate callback, ignoring: {}", messageId);
                return;
            }
            
            // 2. 更新推送状态
            pushRecordService.updateStatus(messageId, status);
            
            // 3. 标记回调已处理
            markCallbackProcessed(messageId);
            
            // 4. 可选：通知业务系统（webhook）
            notifyBusinessSystem(messageId, status);
            
        } catch (Exception e) {
            // 处理失败，放入重试队列
            retryCallback(message);
        }
    }
    
    /**
     * 幂等性检查：使用 Redis 记录已处理的回调
     */
    private boolean callbackProcessed(String messageId) {
        String key = "callback:processed:" + messageId;
        return redisTemplate.hasKey(key);
    }
    
    private void markCallbackProcessed(String messageId) {
        String key = "callback:processed:" + messageId;
        redisTemplate.opsForValue().set(key, "1", Duration.ofDays(7));
    }
}
```

**解决方案 3：查询超时处理**

如果回调一直没有到达，推送中心定期查询三方的最终状态：

```java
@Component
@EnableScheduling
public class StatusPollingService {
    
    /**
     * 每分钟检查一次待处理的推送
     * 对于发送已超过 5 分钟但未得到回调的推送，主动查询
     */
    @Scheduled(fixedDelay = 60_000)
    public void pollPendingStatus() {
        List<PushRecord> pendingRecords = pushRecordService.getPendingRecords(
            Duration.ofMinutes(5)
        );
        
        for (PushRecord record : pendingRecords) {
            try {
                // 从三方查询该消息的最终状态
                PushChannel channel = channelRegistry.getChannel(record.getChannel());
                FinalStatus status = channel.queryStatus(record.getMessageId());
                
                // 更新本地状态
                pushRecordService.updateStatus(
                    record.getMessageId(),
                    status.getStatus(),
                    status.getDeliveredAt()
                );
                
            } catch (Exception e) {
                log.error("Failed to query status for message: {}", 
                         record.getMessageId(), e);
            }
        }
    }
}
```

### 7.4 推送中心向上游反馈发送状态

**方式 1：同步返回（不推荐）**

```java
// 业务系统等待推送完成（可能很慢）
PushResponse response = pushCenter.send(request);
// 返回最终状态
if (response.isSuccess()) {
    // 继续业务流程
}
```

问题：阻塞业务流程，推送中心故障影响业务

**方式 2：异步回调（推荐）**

```java
// 业务系统指定回调 URL
PushRequest request = new PushRequest()
    .setUserId("user_123")
    .setTemplateId("order_created")
    .setCallbackUrl("https://biz-system/api/push/result")  // 回调地址
    .setCallbackRetryPolicy(new RetryPolicy()
        .setMaxRetries(3)
        .setRetryDelays(new long[]{5_000, 30_000, 300_000})
    );

pushCenter.sendAsync(request);
// 立即返回 request_id，推送在后台进行

// 推送完成后，推送中心会调用回调 URL
// POST https://biz-system/api/push/result
// {
//   "request_id": "req_abc123",
//   "status": "SUCCESS",
//   "results": [{...}]
// }
```

业务系统处理回调：

```java
@RestController
@RequestMapping("/api/push")
public class PushCallbackController {
    
    @PostMapping("/result")
    public ResponseEntity<?> handlePushResult(@RequestBody PushResultCallback callback) {
        String requestId = callback.getRequestId();
        String status = callback.getStatus();
        
        // 1. 根据 request_id 查询对应的业务操作
        BusinessOperation operation = operationService.findByRequestId(requestId);
        
        if (operation == null) {
            // 对应的操作已删除或过期，无需处理
            return ResponseEntity.ok().build();
        }
        
        // 2. 根据推送结果更新业务状态
        if ("SUCCESS".equals(status)) {
            // 标记通知已发送
            operation.setNotificationSent(true);
        } else {
            // 发送失败，记录告警
            alertService.alert("Push failed for operation: " + requestId);
        }
        
        // 3. 持久化
        operationService.save(operation);
        
        return ResponseEntity.ok().build();
    }
}
```

**方式 3：主动查询（可选补充）**

某些情况下业务系统需要主动查询发送状态：

```java
// 业务系统主动查询
PushStatus status = pushCenter.queryStatus(requestId);

if (status == PushStatus.DELIVERED) {
    // 确认已送达
} else if (status == PushStatus.FAILED) {
    // 失败，可能需要重新发送
} else if (status == PushStatus.UNKNOWN) {
    // 状态未知，稍后重试查询
}
```

---

## 第八部分：监控、日志与可观测性

### 8.1 核心指标体系

**基础指标**

```
1. 吞吐量（Throughput）
   ├─ 定义：每秒处理的推送请求数（TPS）
   ├─ 维度：按通道、按模板、按业务
   ├─ 告警：TPS 超过预期峰值的 120% 时告警
   └─ 例：SMS TPS 达到 1200（预期 1000）

2. 发送成功率（Success Rate）
   ├─ 定义：至少有一个通道成功送达的请求占比
   ├─ 计算：(成功数) / (总数) * 100%
   ├─ 维度：全局、按通道、按模板、按业务、按时间
   ├─ 告警：< 95% 立即告警
   └─ 例：短信成功率 97%，飞书成功率 99.5%

3. 端到端延迟（End-to-End Latency）
   ├─ 定义：从推送请求到推送中心返回结果的时间
   ├─ 分位数：P50、P90、P99
   ├─ 目标：P99 < 200ms（异步）
   └─ 例：P99 延迟 180ms

4. 通道级别的成功率
   ├─ SMS: 95-98%（受运营商影响）
   ├─ 飞书/企业微信: 99%+ （企业用户稳定）
   ├─ 邮件: 90-95% （垃圾邮件过滤、收件箱满）
   └─ 独立监控和告警

5. 重试成功率
   ├─ 定义：初次失败但经过重试最终成功的占比
   ├─ 计算：(重试成功数) / (初次失败数) * 100%
   ├─ 目标：>= 80%
   └─ 用于评估重试策略的有效性

6. 死信队列堆积
   ├─ 定义：所有重试都失败的请求数
   ├─ 监控：每 5 分钟检查一次
   ├─ 告警：> 1000 条
   └─ 表示发生了严重问题
```

**成本指标**

```
1. 单位成本（Cost Per Push）
   ├─ SMS：¥0.05/条
   ├─ 企业微信：免费
   ├─ 飞书：免费
   ├─ 邮件：¥0.02/条（仅计费方案）
   └─ 计算总成本用于评估投入产出

2. 成本超支告警
   ├─ 日成本超过预算的 110% → 告警
   ├─ 某个通道日成本超过配额 → 自动降级
   └─ 例：短信日预算 ¥5000，超过 ¥5500 时告警
```

### 8.2 数据库监控表设计

```sql
-- 推送记录表（核心）
CREATE TABLE `push_record` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `request_id` VARCHAR(128) UNIQUE NOT NULL COMMENT '推送请求 ID',
  `user_id` BIGINT NOT NULL,
  `business_type` VARCHAR(64) NOT NULL COMMENT '业务类型，如 order, payment',
  `template_id` VARCHAR(64) NOT NULL,
  `channel` VARCHAR(32) NOT NULL,
  `status` VARCHAR(32) NOT NULL COMMENT 'PENDING/SENT/DELIVERED/FAILED',
  `message_id` VARCHAR(128) COMMENT '通道返回的消息 ID',
  `error_code` VARCHAR(32),
  `error_msg` VARCHAR(512),
  `attempt_count` INT DEFAULT 1,
  `sent_at` TIMESTAMP,
  `delivered_at` TIMESTAMP,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  INDEX idx_request_id (request_id),
  INDEX idx_user_id_created (user_id, created_at),
  INDEX idx_channel_status (channel, status),
  INDEX idx_template_id (template_id),
  INDEX idx_business_type (business_type),
  INDEX idx_created_at (created_at)
);

-- 推送统计表（每分钟汇总，用于快速查询）
CREATE TABLE `push_statistics_minute` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `minute_time` TIMESTAMP NOT NULL COMMENT '统计的分钟',
  `channel` VARCHAR(32) NOT NULL,
  `template_id` VARCHAR(64),
  `business_type` VARCHAR(64),
  `total_count` INT DEFAULT 0,
  `success_count` INT DEFAULT 0,
  `failed_count` INT DEFAULT 0,
  `avg_latency_ms` INT DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE KEY unique_stat (minute_time, channel, template_id, business_type),
  INDEX idx_minute_time (minute_time),
  INDEX idx_channel (channel)
);

-- 成本统计表
CREATE TABLE `push_cost_daily` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `date` DATE NOT NULL,
  `channel` VARCHAR(32) NOT NULL,
  `request_count` INT DEFAULT 0,
  `unit_price` DECIMAL(10, 4) DEFAULT 0,
  `total_cost` DECIMAL(15, 2) DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE KEY unique_cost (date, channel),
  INDEX idx_date (date)
);
```

### 8.3 指标采集与可视化

**实时指标采集**

```java
@Component
 public class MetricsCollector {
    
    private final MeterRegistry meterRegistry;
    
    // 记录推送请求
    public void recordPushRequest(String channel, String templateId, 
                                  String businessType, boolean success, 
                                  long latencyMs) {
        meterRegistry.counter(
            "push.request",
            "channel", channel,
            "template", templateId,
            "business", businessType,
            "status", success ? "success" : "failed"
        ).increment();
        
        meterRegistry.timer(
            "push.latency",
            "channel", channel
        ).record(latencyMs, TimeUnit.MILLISECONDS);
    }
    
    // 记录重试
    public void recordRetry(String channel, int attemptNumber) {
        meterRegistry.counter(
            "push.retry",
            "channel", channel,
            "attempt", String.valueOf(attemptNumber)
        ).increment();
    }
    
    // 记录熔断
    public void recordCircuitBreakerOpen(String channel) {
        meterRegistry.gauge(
            "push.circuit.breaker.open",
            new AtomicInteger(1),
            AtomicInteger::get
        );
    }
}
```

**监控仪表板关键图表**

```
1. 实时吞吐量（TPS）
   ├─ X 轴：时间
   ├─ Y 轴：TPS
   ├─ 分组：按通道
   └─ 用途：快速发现流量异常

2. 成功率趋势
   ├─ 按通道分别显示
   ├─ 标记告警阈值（95%）
   ├─ 显示 7 天趋势
   └─ 用途：评估通道稳定性

3. 延迟分位数
   ├─ 显示 P50、P90、P99
   ├─ 分组：按通道
   ├─ 1 小时内更新
   └─ 用途：评估用户体验

4. 通道对比
   ├─ 柱状图对比成功率
   ├─ 成本 vs 成功率
   ├─ 延迟对比
   └─ 用途：优化通道选择

5. 成本趋势
   ├─ 按通道分组
   ├─ 显示日成本
   ├─ 标记预算线
   └─ 用途：成本控制
```

### 8.4 告警设计

**告警规则**

```yaml
alerts:
  # 成功率告警
  - name: PushSuccessRateDown
    condition: push_success_rate < 0.95
    duration: 5m
    severity: critical
    message: "推送成功率下降至 {{ .Value }}%，请立即检查"
    
  # 延迟告警
  - name: PushLatencyHigh
    condition: push_latency_p99 > 500
    duration: 10m
    severity: warning
    message: "推送 P99 延迟超过 500ms"
    
  # 死信队列堆积
  - name: DeadLetterQueueFull
    condition: dead_letter_queue_count > 1000
    duration: 5m
    severity: critical
    message: "死信队列堆积 {{ .Value }} 条，需要人工处理"
    
  # 通道故障
  - name: ChannelDown
    condition: push_channel_success_rate < 0.80
    duration: 2m
    severity: critical
    message: "通道 {{ .labels.channel }} 故障，成功率仅 {{ .Value }}%"
    
  # 成本超支
  - name: DailyCostExceeded
    condition: push_daily_cost > budget_limit * 1.1
    duration: 1m
    severity: warning
    message: "今日成本 {{ .Value }} 元，超出预算 {{ .Threshold }} 元"
    
  # 熔断打开
  - name: CircuitBreakerOpen
    condition: push_circuit_breaker_open == 1
    duration: 1m
    severity: warning
    message: "通道 {{ .labels.channel }} 熔断器打开，已启用降级策略"
```

**告警接收与升级**

```
第 1 级告警（Warning）
  └─> Slack/钉钉群通知 + 邮件
  
第 2 级告警（Critical）
  └─> 钉钉@所有人 + 短信通知 + 电话
       一次
  
第 3 级告警（持续 30 分钟）
  └─> 升级为 PagerDuty
  └─> 电话轮询值班人员
```

### 8.5 链路追踪（Tracing）

每条推送请求应该有完整的链路追踪：

```
Request ID: req_abc123

Timeline:
2025-12-18 14:23:45.123
  ├─ [API] 业务系统发起推送请求
  │  └─ user_id: user_123
  │  └─ template_id: order_created
  │  └─ channels: [SMS, LARK]
  │
  ├─ [QUEUE] 请求入队
  │  └─ queue_wait_time: 12ms
  │
  ├─ [DEDUP] 去重检查
  │  └─ idempotent_key: push:idempotent:req_abc123:user_123:order_created
  │  └─ result: 首次请求，通过
  │
  ├─ [RENDER] 模板渲染
  │  └─ template_params: {order_id: ORD_456, amount: ¥99.99}
  │  └─ rendered_content: "您的订单 ORD_456（¥99.99）已创建"
  │  └─ render_time: 5ms
  │
  ├─ [USERINFO] 查询用户信息
  │  └─ phone: 186****8888
  │  └─ lark_id: ou_xxxxx
  │  └─ cache_hit: true
  │  └─ query_time: 1ms
  │
  ├─ [CHANNEL_SMS] 发送短信
  │  ├─ status: SUCCESS
  │  ├─ message_id: sms_xyz789
  │  ├─ send_time: 45ms
  │  └─ provider: AliyunSms
  │
  ├─ [CHANNEL_LARK] 发送飞书
  │  ├─ status: FAILED
  │  ├─ error_code: INVALID_LARK_ID
  │  ├─ error_msg: "User has no valid Lark account"
  │  ├─ send_time: 32ms
  │  └─ provider: LarkBot
  │
  ├─ [CALLBACK] 发送回调
  │  └─ callback_url: https://biz-system/api/push/result
  │  └─ callback_time: 28ms
  │  └─ callback_status: SUCCESS
  │
  └─ [COMPLETE] 推送完成
     └─ final_status: PARTIAL_SUCCESS
     └─ total_time: 127ms
     └─ success_channels: [SMS]
     └─ failed_channels: [LARK]
```

实现：

```java
@Component
public class TraceCollector {
    
    private final TraceService traceService;
    
    public void recordTraceEvent(String requestId, String event, 
                               Map<String, Object> details) {
        TraceRecord record = new TraceRecord()
            .setRequestId(requestId)
            .setEventName(event)
            .setTimestamp(System.currentTimeMillis())
            .setDetails(details);
        
        traceService.save(record);
    }
}
```

---

## 第九部分：常见错误设计与反模式

### 9.1 推送中心承担业务逻辑

**反面案例**

```java
// 错误：推送中心在决定"谁该收到什么"
@Service
public class PushService {
    
    public void sendOrderNotification(Order order) {
        // 推送中心不应该知道业务规则
        if (order.getTotalAmount() > 1000) {
            // 大额订单才发送？这是业务规则，不是推送中心的职责
            push(order.getUserId(), "order_created");
        }
        
        if (user.getVipLevel() > 0) {
            // VIP 客户发短信，普通客户发邮件？
            // 这些决策应该在业务系统做
            sendSms(user, message);
        }
    }
}
```

**影响**
- 推送中心变成了一个业务引擎，职责不清
- 业务规则变更需要改推送中心，违反单一职责
- 难以复用（其他业务有不同的规则）
- 推送中心的复杂度爆炸

**正确做法**

```java
// 业务系统决定
@Service
public class OrderService {
    
    public void createOrder(CreateOrderRequest request) {
        Order order = createOrderInDB(request);
        
        // 业务系统决定"谁该收到什么"
        List<String> channels = determineChannels(order);
        
        // 调用推送中心，让它负责发送
        pushCenter.send(new PushRequest()
            .setUserId(order.getUserId())
            .setTemplateId("order_created")
            .setChannels(channels)
            .setParams(buildParams(order))
        );
    }
    
    private List<String> determineChannels(Order order) {
        // 业务规则在这里
        if (order.getTotalAmount() > 1000) {
            return Arrays.asList("SMS", "LARK", "EMAIL");  // 重要订单用多通道
        } else {
            return Arrays.asList("SMS");  // 普通订单只用短信
        }
    }
}
```

### 9.2 业务系统绕过推送中心直连通道

**反面案例**

```java
// 某个业务在用推送中心，某个业务直接连阿里云
// 导致通道分散、成本无法统计、模板重复

// 业务 A：使用推送中心
pushCenter.send(request);

// 业务 B：绕过推送中心，直接调用短信 SDK
AliyunSms sms = new AliyunSms(accessKey, secret);
sms.send(phone, "您的订单已创建");  // 重复的模板内容
```

**影响**
- 无法统计全公司的推送成本
- 无法统一管理模板、限流、重试
- 新增通道要改多个地方
- 难以追踪推送发送情况

**解决方案**

1. **技术强制**：通过权限管理禁止业务系统依赖第三方 SDK
   ```java
   // 在依赖管理中，禁止非推送中心的应用引入三方 SMS SDK
   // 通过代码审查确保遵守
   ```

2. **流程强制**：所有推送需求必须经过推送中心
   ```
   PR 审查清单：
   ☐ 是否直接引入了三方 SDK？（应该移到推送中心）
   ☐ 是否定义了重复的模板？（应该在推送中心定义）
   ☐ 是否调用了推送中心 API？（应该调用）
   ```

### 9.3 模板与通道强耦合

**反面案例**

```java
// 错误：模板中硬编码通道逻辑
template: "order_created" {
    sms_content: "您的订单已创建",
    lark_content: "您的订单 {{ order_id }} 已创建，金额 {{ amount }}",
    email_subject: "订单确认 - {{ order_id }}",
    email_html: "<p>尊敬的用户，订单已确认...</p>"
}

// 后果：
// - 添加新通道需要修改模板
// - 不同通道的模板内容手工维护，容易不一致
// - 模板变更时要同时改多个通道的内容
```

**正确做法**

```yaml
# 推送中心的模板定义（内容与通道分离）
template:
  id: "order_created"
  category: "order"  # 分类便于管理
  description: "订单创建通知"
  
  # 通用参数定义
  params:
    - name: "order_id"
      type: "string"
      required: true
    - name: "amount"
      type: "decimal"
      required: true
    - name: "delivery_date"
      type: "date"
      required: false
  
  # 按通道定义内容（相互独立）
  channels:
    SMS:
      content: "您的订单{{ order_id }}已创建，金额{{ amount }}，预计{{ delivery_date }}送达"
      priority: 1
    
    LARK:
      title: "订单已创建"
      content: "订单 {{ order_id }} 已创建，金额 {{ amount }}"
      priority: 2
    
    EMAIL:
      subject: "订单确认 - {{ order_id }}"
      html_template: "order_created.html"  # 引用外部 HTML 模板
      priority: 3
```

### 9.4 同步阻塞式发送

**反面案例**

```java
// 错误：同步调用，业务流程被阻塞
public void createOrder(Order order) {
    // 1. 创建订单
    orderService.create(order);
    
    // 2. 同步调用推送，等待响应（可能 1-2 秒）
    PushResponse response = pushCenter.send(request);
    
    if (!response.isSuccess()) {
        // 3. 如果推送失败，订单也失败？太严苛了
        throw new Exception("Push failed");
    }
    
    // 4. 继续业务流程
}
```

**影响**
- 推送中心的延迟直接影响订单创建的性能
- 推送中心故障会导致业务卡住
- 无法应对推送中心的突发故障

**正确做法**

```java
@Service
public class OrderService {
    
    public void createOrder(CreateOrderRequest request) {
        // 1. 创建订单（核心业务）
        Order order = orderRepository.create(request);
        
        // 2. 异步发送推送通知（非核心业务）
        // 立即返回，不阻塞业务流程
        pushQueue.enqueue(new PushRequest()
            .setRequestId(generateRequestId())
            .setUserId(order.getUserId())
            .setTemplateId("order_created")
            .setParams(buildParams(order))
        );
        
        // 3. 立即返回给用户
        return OrderResponse.ok(order);
    }
}
```

### 9.5 忽视重复发送问题

**反面案例**

```java
// 错误：完全没有幂等性保证
// 消息队列重复消费、网络重试等都可能导致重复发送
public void send(PushRequest request) {
    PushChannel channel = channelRegistry.getChannel(request.getChannels()[0]);
    ChannelResult result = channel.send(request);
    
    // 直接保存，没有去重检查
    pushRecordRepository.save(new PushRecord(request, result));
}
```

**影响**
- 用户可能收到重复的推送
- 成本统计不准确（同一条消息计费多次）
- 用户体验差

**正确做法**

参考第六部分的幂等性设计。

### 9.6 低估通道的故障频率

**反面案例**

```java
// 错误：假设三方通道永远正常
// 实际上短信通道经常限流、邮件经常进垃圾箱

public void send(PushRequest request) {
    // 只有一个重试，不够
    int maxRetries = 1;
    
    // 没有降级策略
    // 短信失败就失败了，不尝试其他通道
}
```

**影响**
- 发送成功率达不到预期
- 某个通道故障整个系统受影响

**正确做法**

参考第六部分的重试、熔断、降级策略。

---

## 第十部分：总结

### 10.1 推送中心的设计检查清单

一个「合格的推送中心」应该满足以下标准：

**架构与设计**
- ☐ 通道抽象：新增通道不需要修改核心代码
- ☐ 职责清晰：业务系统决策谁该收到什么，推送中心只负责发送
- ☐ 异步处理：业务流程不被推送中心阻塞
- ☐ 模板独立：模板定义与通道解耦，支持多通道变体

**稳定性**
- ☐ 重试机制：立即重试 + 延迟重试 + 死信队列
- ☐ 幂等性：支持请求重放不会导致重复发送
- ☐ 限流控制：按通道、按用户、按业务维度的限流
- ☐ 熔断降级：单个通道故障不影响其他通道
- ☐ 多通道容灾：支持通道自动切换

**可观测性**
- ☐ 唯一追踪 ID：每条推送都有 request_id，可追踪全生命周期
- ☐ 完整日志：记录发送的每个阶段
- ☐ 关键指标：成功率、延迟、成本、重试成功率等
- ☐ 链路追踪：支持从发送到结果的完整链路查看
- ☐ 告警机制：异常情况及时发现和通知

**可治理性**
- ☐ 配置驱动：通道优先级、限流阈值等可动态配置
- ☐ 成本透明：能按通道、按业务统计成本
- ☐ 黑白名单：支持对用户、号码的黑白名单
- ☐ 灰度发布：支持新模板、新通道的灰度测试

**性能**
- ☐ P99 延迟 < 200ms（异步场景）
- ☐ 吞吐量支撑业务峰值
- ☐ 三层缓存（本地 + Redis + 数据库）
- ☐ 连接复用与批量发送

**运维**
- ☐ 健康检查：定期检查各通道的可用性
- ☐ 自动降级：无需人工干预的故障隔离
- ☐ 回滚能力：可快速回滚配置和代码变更
- ☐ 文档完整：API 文档、告警说明、故障处理流程

### 10.2 设计演进路线

**第一阶段：MVP（最小可行产品）**

需要的功能：
- 基础的 Channel 抽象（3-4 个通道）
- 同步发送（快速验证）
- 基础错误重试（1-2 次）
- 数据库存储发送记录
- 简单的 API 接口

时间投入：2-4 周

**第二阶段：稳定性与可观测性**

添加功能：
- 异步队列处理
- 完整的重试策略（立即 + 延迟）
- 限流、熔断、降级
- 核心指标监控
- 链路追踪

时间投入：4-8 周

**第三阶段：治理与成本优化**
- 详细的成本统计
- 灰度发布框架
- 黑白名单管理
- 配置化治理
- 完整的告警体系

时间投入：4-6 周

**第四阶段：企业级特性**
- 多租户支持
- A/B 测试框架
- 高级分析与报表
- 通道扩展市场（SaaS 化）

时间投入：持续

### 10.3 与竞品的差异

为什么要自建推送中心而不是用现成的 SaaS？

| 维度 | 自建 | SaaS 产品 |
|-----|------|----------|
| **成本** | 初期高，长期低 | 按用量计费，规模越大越贵 |
| **控制力** | 完全控制，可定制 | 受限于产品功能 |
| **数据安全** | 内部控制 | 三方存储，数据风险 |
| **集成** | 灵活集成业务系统 | API 固定，难以定制 |
| **学习成本** | 高 | 低 |
| **运维负担** | 高 | 几乎无 |

选择建议：
- **初创企业（<50 人）**：用 SaaS，节省人力
- **成长期企业（50-500 人）**：评估成本与定制需求，可考虑自建
- **大型企业（>500 人）**：必须自建，成本与控制力优势明显

### 10.4 常见的后悔设计

根据业界实践，有些设计初期看似合理，后期会反悔：

**1. 同步发送模式**

初期为了简单直接用同步，后来发现：
- 推送中心故障影响业务
- 无法应对突发流量
- 难以支持重试

⚠️ 建议：从一开始就用异步

**2. 所有规则都存 MySQL**

初期把所有限流规则、黑名单都存数据库，后来发现：
- 查询延迟高
- 数据库成为瓶颈
- 配置变更需要上线

⚠️ 建议：用 Redis 存热数据，MySQL 存历史

**3. 推送中心处理模板渲染**

初期让推送中心渲染模板，后来发现：
- 模板是业务的，应该由业务系统渲染
- 推送中心只需要发送已渲染的内容

⚠️ 建议：业务系统渲染模板，推送中心只发送

**4. 没有幂等性检查**

初期没做幂等，后来大量用户反映收到重复推送：
- 影响用户体验
- 成本翻倍
- 赔偿责任

⚠️ 建议：从一开始就实现幂等

### 10.5 最后的话

推送中心看似简单（调三方 API），但要做到企业级的可靠性和可观测性，需要：

1. **清晰的架构** - 职责边界分明
2. **扎实的重试策略** - 尽最大努力保证送达
3. **完善的监控** - 问题及时发现
4. **灵活的治理** - 应对突发与变化
5. **充分的文档** - 团队知识积累

从 MVP 到企业级，通常需要 3-6 个月的迭代。这个过程中会遇到很多教训，但正是这些教训让推送中心变得稳定、可靠、易维护。

一个好的推送中心不是一蹴而就的，而是在业务场景的不断打磨中逐步完善的。

---

## 参考资源

- 《企业级 Java 应用》- 推送系统设计章节
- 《深入理解大型互联网应用架构》- 可靠性设计
- 《微服务架构设计模式》- 服务通信与容错
- 各大厂的推送系统开源实现和博客分享