---
title: 鉴权中心的设计与实现
date: 2025-11-10 10:12:00 +0800
categories: [架构设计]
tags: [权限系统, RBAC, ABAC, SSO, OAuth2]
---

最近在做公司的统一鉴权中心，踩了不少坑，也有一些思考。这篇文章记录一下整个设计过程，希望对有类似需求的朋友有所帮助。

## 为什么需要统一鉴权中心

公司业务发展到一定阶段，系统越来越多，每个系统都有自己的用户体系和权限管理。用户要记住多套账号密码，开发团队要重复实现权限逻辑，运维要维护多套用户数据。这种情况下，统一鉴权中心就成了刚需。

我们的目标很明确：一套账号体系，一次登录，访问所有系统。权限管理集中化，安全策略统一管控。听起来简单，实际做起来要考虑的东西很多。

## 多租户隔离是基础

企业级系统绕不开多租户。我们的鉴权中心不仅要服务自己公司，还要支持给客户部署独立实例，或者 SaaS 模式下的多租户隔离。

租户表的设计很简单，但影响深远。几乎所有核心表都要加上 tenant_id，从数据层面保证隔离。这个决策要在项目初期就定下来，后期改造成本太高。

```sql
Table tenant {
  id bigint [pk]
  name varchar(100)
  code varchar(50)
  status tinyint
  is_deleted tinyint [default: 0]
}
```

## 用户体系要足够灵活

用户不是孤立的个体，在企业环境中，用户属于组织、担任岗位、加入用户组、被赋予角色。这些关系交织在一起，构成了权限判断的基础。

我们设计了用户、组织、岗位、用户组、角色这几个核心实体。用户可以属于多个组织，但有一个主组织；可以担任多个岗位，但有一个主岗位。这种设计既保证了灵活性，又避免了权限判断时的歧义。

组织结构用了经典的树形设计，parent_id 指向父节点。但光有 parent_id 还不够，我们加了 path 和 level 字段。path 存储完整路径（如 /1/5/12），查询某个部门的所有子部门时，一条 SQL 就能搞定，不用递归查询。level 字段方便做层级限制和权限继承。

```sql
Table organization {
  id bigint [pk]
  tenant_id bigint
  name varchar(50)
  parent_id bigint
  path varchar(500)  -- 关键字段
  level int
  org_type tinyint  -- 公司、部门、小组
  status tinyint
}
```

岗位也是类似的设计，但岗位要关联到具体的组织。比如"财务经理"这个岗位，在不同的分公司是不同的岗位实例。

## RBAC + ABAC 混合权限模型

权限模型是整个系统的核心。单纯的 RBAC（基于角色）不够灵活，纯 ABAC（基于属性）又太复杂。我们选择了混合模式。

角色是权限的容器，这是 RBAC 的思路。但角色不直接关联资源，而是关联策略（Policy）。策略才是真正定义权限规则的地方，这是 ABAC 的思路。

一个策略包含多条声明（Statement），每条声明定义：对哪个资源，可以做什么操作，是允许还是拒绝。这个设计借鉴了 AWS IAM 的思路，实践证明很好用。

```sql
Table policy {
  id bigint [pk]
  name varchar(50)
  effect tinyint  -- 允许/拒绝
  priority int    -- 优先级
  valid_from datetime
  valid_to datetime
}

Table policy_statement {
  id bigint [pk]
  policy_id bigint
  resource_id bigint
  actions text  -- JSON: ['read', 'write']
  effect tinyint
}
```

更强大的是条件（Condition）。一条声明可以附加多个条件，只有满足所有条件时才生效。比如"只允许工作时间访问"、"只允许特定 IP 访问"、"只允许访问自己部门的数据"。这些动态条件让权限控制变得非常灵活。

```sql
Table policy_condition {
  id bigint [pk]
  policy_statement_id bigint
  expression text -- 条件表达式
}
```

策略通过 policy_binding 表绑定到用户、角色、用户组、组织、岗位。这个设计让权限分配变得很灵活，可以直接给用户授权，也可以通过角色授权，还可以给整个部门授权并支持继承。

## 应用接入和权限空间

鉴权中心要服务多个应用，每个应用有自己的资源和权限。我们引入了"权限空间"的概念，每个应用对应一个或多个权限空间。

应用注册时分配 app_key 和 app_secret，用于身份认证。app_secret 支持多版本，可以在不停服的情况下轮换密钥。这个设计在实际运维中很有用，定期轮换密钥是安全规范的要求。

```sql
Table application {
  id bigint [pk]
  name varchar(100)
  app_key varchar(50)
  callback varchar(255)
  ip_whitelist text
  rate_limit int
}

Table app_secret {
  id bigint [pk]
  application_id bigint
  secret varchar(255)
  version int
  status tinyint  -- 当前使用/备用/已废弃
  expire_time datetime
}
```

资源也是树形结构，菜单、页面、按钮、API、数据都是资源。每个资源可以定义多个操作（Action），比如用户管理资源有 read、write、delete 等操作。

## SSO 单点登录的实现

单点登录是统一鉴权中心的核心功能。用户在一个系统登录后，访问其他系统时不需要再次输入密码。

我们采用了经典的 CAS 协议思路。用户登录成功后，鉴权中心创建全局 session，并设置跨域 cookie。当用户访问其他应用时，应用重定向到鉴权中心，鉴权中心检测到已登录，生成一次性 ticket 返回给应用。应用拿着 ticket 去鉴权中心验证，验证通过后获得用户信息，创建本地 session。

ticket 是一次性的，验证后立即失效，防止重放攻击。ticket 还绑定了 service_url，只能用于指定的应用，防止被盗用。

```sql
Table sso_ticket {
  id bigint [pk]
  user_id bigint
  ticket varchar(100)
  service_url varchar(255)
  expire_time datetime
  status tinyint  -- 未使用/已使用
}
```

这个表看起来存的是临时数据，但在企业环境中很有必要。一是安全审计需要，二是分布式环境下需要共享 ticket 状态，三是排查问题时可以追溯授权链路。

## OAuth2 支持

除了 SSO，我们还实现了标准的 OAuth2 协议，支持第三方应用接入。授权码模式、客户端模式都支持。

OAuth2 的授权码和访问令牌也建了表。虽然是临时数据，但考虑到审计和安全要求，还是选择了持久化存储。实际使用中，我们在 Redis 做了一层缓存，数据库作为备份和审计日志。

```sql
Table oauth_authorization_code {
  id bigint [pk]
  application_id bigint
  user_id bigint
  code varchar(100)
  scope varchar(200)
  expire_time datetime
}

Table oauth_access_token {
  id bigint [pk]
  application_id bigint
  user_id bigint
  access_token varchar(500)
  refresh_token varchar(500)
  expire_time datetime
}
```

## 密码策略和安全管控

企业对密码安全有严格要求。我们设计了密码策略表，支持配置密码长度、复杂度、过期时间、历史密码限制等。

```sql
Table password_policy {
  id bigint [pk]
  tenant_id bigint
  min_length int
  require_uppercase tinyint
  require_number tinyint
  expire_days int
  history_count int  -- 不能重复最近 N 次密码
  max_retry_count int
  lock_duration int
}
```

登录日志表记录所有登录行为，成功的、失败的都记录。这不仅是安全审计的要求，也是排查问题的重要依据。用户反馈登录不了，查一下日志就知道是密码错误还是账号被锁定。

## 性能优化的考虑

权限判断是高频操作，每个请求都要做。如果每次都查数据库，性能肯定扛不住。

我们的方案是用户登录时计算一次完整权限，序列化成 JSON 存到 Redis，设置 30 分钟过期。后续请求直接从 Redis 读取，速度很快。

权限变更时，删除对应的缓存 key，或者递增版本号。用户下次请求时发现缓存失效或版本不匹配，重新计算权限。

```sql
key: permission:user:1001:tenant:1
value: {
  "resources": {
    "user_management": ["read", "write"],
    "financial_report": ["read"]
  },
  "menus": [1, 2, 5, 8]
}
TTL: 1800
```

数据模型里有个 permission_cache 表，最初是想做二级缓存的。后来发现 Redis 已经够用了，这个表可以去掉。不过如果对权限一致性要求特别高，或者 Redis 重启后希望快速恢复，保留这个表也有意义。

## 一些实践经验

设计过程中踩了一些坑，分享几点经验：

**关于软删除：** 所有核心表都加了 is_deleted 字段。用户、角色、组织这些数据不能真删除，删除后历史数据就对不上了。软删除是必须的。

**关于状态字段：** status 字段也是标配。用户可能被禁用、角色可能被停用、应用可能下线。这些状态变化不应该删除数据，而是改状态。

**关于外键：** 数据模型里定义了外键关系，但实际建表时我们没有加外键约束。一是性能考虑，二是灵活性考虑。外键约束在某些场景下会成为瓶颈，比如批量删除、数据迁移。通过应用层保证数据一致性，是更常见的做法。

**关于索引：** tenant_id、user_id、status 这些高频查询字段都要加索引。组织的 path 字段也要加索引，支持前缀匹配查询。索引设计直接影响查询性能，这个要在设计阶段就考虑清楚。


## 写在最后

这套模型在我们公司已经跑了大半年，支撑了十几个业务系统。期间也在不断优化，比如加了用户组、优化了策略模型、增加了条件判断。

权限系统没有银弹，要根据实际业务场景设计。我们的模型偏重灵活性和扩展性，适合业务复杂、权限规则多变的场景。如果是简单的后台系统，可能 RBAC 就够了，不需要这么复杂。

代码和文档都在公司内部 GitLab，暂时不方便开源。如果有朋友在做类似的系统，欢迎交流。

---

## 附：完整数据模型（DBML 格式）

![鉴权中心 ER 图](/assets/img/auth/2.png)

```sql
// 租户表
Table tenant {
  id bigint [pk]
  name varchar(100)
  code varchar(50)
  status tinyint [note: '1:启用 0:禁用']
  is_deleted tinyint [default: 0]
}

// 用户表
Table user {
  id bigint [pk]
  tenant_id bigint
  account varchar(50)
  nickname varchar(50)
  password varchar(255)
  email varchar(100)
  phone varchar(20)
  status tinyint [note: '1:正常 0:禁用 2:锁定']
  last_login_time datetime
  login_count int
  is_deleted tinyint [default: 0]
}

// 用户组表
Table user_group {
  id bigint [pk]
  tenant_id bigint
  name varchar(50)
  code varchar(50)
  description varchar(200)
  status tinyint
  is_deleted tinyint [default: 0]
}

// 用户组成员表
Table user_group_member {
  id bigint [pk]
  user_group_id bigint [ref: > user_group.id]
  user_id bigint [ref: > user.id]
}

// 组织表
Table organization {
  id bigint [pk]
  tenant_id bigint
  name varchar(50)
  code varchar(50)
  parent_id bigint [ref: > organization.id]
  path varchar(500) [note: '组织路径，如 /1/2/3']
  level int [note: '组织层级']
  org_type tinyint [note: '1:公司 2:部门 3:小组']
  status tinyint
  is_deleted tinyint [default: 0]
}

// 用户组织关系表
Table user_organization {
  id bigint [pk]
  user_id bigint [ref: > user.id]
  organization_id bigint [ref: > organization.id]
  is_primary tinyint [note: '是否主组织']
}

// 岗位表
Table post {
  id bigint [pk]
  tenant_id bigint
  code varchar(20)
  name varchar(50)
  parent_id bigint [ref: > post.id]
  organization_id bigint [ref: > organization.id]
  level int
  status tinyint
  is_deleted tinyint [default: 0]
}

// 用户岗位关系表
Table user_post {
  id bigint [pk]
  user_id bigint [ref: > user.id]
  post_id bigint [ref: > post.id]
  is_primary tinyint [note: '是否主岗位']
}

// 角色表
Table role {
  id bigint [pk]
  tenant_id bigint
  permission_space_id bigint [ref: > permission_space.id]
  name varchar(50)
  code varchar(50)
  description varchar(200)
  status tinyint
  is_system tinyint [note: '系统内置角色不可删除']
  is_deleted tinyint [default: 0]
}

// 用户角色关系表
Table user_role {
  id bigint [pk]
  user_id bigint [ref: > user.id]
  role_id bigint [ref: > role.id]
  valid_from datetime [note: '生效时间']
  valid_to datetime [note: '失效时间']
}

// 应用表
Table application {
  id bigint [pk]
  name varchar(100)
  code varchar(50)
  description varchar(200)
  app_key varchar(50)
  callback varchar(255)
  status tinyint
  ip_whitelist text [note: 'IP白名单，JSON格式']
  rate_limit int [note: '访问频率限制']
  is_deleted tinyint [default: 0]
}

// 应用密钥表
Table app_secret {
  id bigint [pk]
  application_id bigint [ref: > application.id]
  secret varchar(255)
  version int [note: '密钥版本']
  status tinyint [note: '1:当前使用 2:备用 0:已废弃']
  expire_time datetime
}

// 权限空间表
Table permission_space {
  id bigint [pk]
  application_id bigint [ref: > application.id]
  name varchar(50)
  code varchar(50)
  description varchar(200)
  status tinyint
  is_deleted tinyint [default: 0]
}

// 资源表
Table resource {
  id bigint [pk]
  permission_space_id bigint [ref: > permission_space.id]
  name varchar(50)
  code varchar(50)
  parent_id bigint [ref: > resource.id]
  path varchar(500) [note: '资源路径']
  level int
  resource_type tinyint [note: '1:菜单 2:页面 3:按钮 4:API 5:数据']
  description varchar(200)
  is_deleted tinyint [default: 0]
}

// 资源操作表
Table resource_action {
  id bigint [pk]
  resource_id bigint [ref: > resource.id]
  name varchar(50)
  code varchar(50) [note: '如: read, write, delete, execute']
  description varchar(200)
}

// 策略表
Table policy {
  id bigint [pk]
  tenant_id bigint
  permission_space_id bigint [ref: > permission_space.id]
  name varchar(50)
  code varchar(50)
  description varchar(200)
  effect tinyint [note: '1:允许 0:拒绝']
  priority int [note: '优先级，数字越大优先级越高']
  status tinyint
  valid_from datetime
  valid_to datetime
  is_deleted tinyint [default: 0]
}

// 策略声明表
Table policy_statement {
  id bigint [pk]
  policy_id bigint [ref: > policy.id]
  resource_id bigint [ref: > resource.id]
  actions text [note: "资源操作列表，JSON格式 ['read','write']"]
  effect tinyint [note: '1:允许 0:拒绝']
}

// 策略条件表
Table policy_condition {
  id bigint [pk]
  policy_statement_id bigint [ref: > policy_statement.id]
  expression text -- 条件表达式
}

// 策略绑定表
Table policy_binding {
  id bigint [pk]
  policy_id bigint [ref: > policy.id]
  target_type tinyint [note: '1:用户 2:角色 3:用户组 4:组织 5:岗位']
  target_id bigint [note: '目标ID']
  inherit tinyint [note: '是否继承给子级']
  valid_from datetime
  valid_to datetime
}

// 会话表
Table session {
  id bigint [pk]
  user_id bigint [ref: > user.id]
  tenant_id bigint
  session_id varchar(100)
  access_token varchar(500)
  refresh_token varchar(500)
  expire_time datetime
  ip_address varchar(50)
  user_agent varchar(500)
  status tinyint
}

// OAuth授权码表
Table oauth_authorization_code {
  id bigint [pk]
  application_id bigint [ref: > application.id]
  user_id bigint [ref: > user.id]
  code varchar(100)
  redirect_uri varchar(255)
  scope varchar(200)
  expire_time datetime
  status tinyint
}

// OAuth访问令牌表
Table oauth_access_token {
  id bigint [pk]
  application_id bigint [ref: > application.id]
  user_id bigint [ref: > user.id]
  access_token varchar(500)
  refresh_token varchar(500)
  token_type varchar(20)
  scope varchar(200)
  expire_time datetime
  status tinyint
}

// SSO票据表
Table sso_ticket {
  id bigint [pk]
  user_id bigint [ref: > user.id]
  tenant_id bigint
  ticket varchar(100)
  service_url varchar(255)
  expire_time datetime
  status tinyint
}

// 密码策略表
Table password_policy {
  id bigint [pk]
  tenant_id bigint
  min_length int
  require_uppercase tinyint
  require_lowercase tinyint
  require_number tinyint
  require_special_char tinyint
  expire_days int [note: '密码过期天数']
  history_count int [note: '不能重复最近N次密码']
  max_retry_count int [note: '最大重试次数']
  lock_duration int [note: '锁定时长（分钟）']
}

// 登录日志表
Table login_log {
  id bigint [pk]
  user_id bigint [ref: > user.id]
  tenant_id bigint
  login_time datetime
  ip_address varchar(50)
  user_agent varchar(500)
  login_type tinyint [note: '1:账号密码 2:手机验证码 3:SSO 4:OAuth']
  status tinyint [note: '1:成功 0:失败']
  fail_reason varchar(200)
}

// 权限缓存表
Table permission_cache {
  id bigint [pk]
  cache_key varchar(200)
  user_id bigint [ref: > user.id]
  tenant_id bigint
  permission_data text [note: '权限数据，JSON格式']
  expire_time datetime
  version int
}
```
