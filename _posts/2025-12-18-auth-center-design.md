---
title: 企业级鉴权中心设计：从 RBAC 到工程落地
date: 2025-12-18 12:00:00 +0800
categories: [分布式]
tags: [RBAC, ABAC, 权限设计, 鉴权, 架构]
---

## 概述

在企业级系统演进的过程中，鉴权往往从最初的"在应用内硬编码"，逐步演进到"独立的鉴权中心服务"。这篇文章从工程实践的角度，讨论为什么需要独立鉴权中心、如何设计才能既满足业务灵活性，又不因过度设计导致系统复杂度爆炸。

本文的核心观点：
- **RBAC 是 80% 场景的最优选择**，不要被学术化的 ABAC 吸引而过度复杂化
- **权限分层是关键**：页面权限 → 接口权限 → 数据权限，每层职责清晰
- **架构设计的本质是权衡**：在一致性、性能、复杂度之间做出有意识的取舍
- **不要把所有东西都同步到鉴权中心**，应该让业务系统保留必要的上下文

---

## 第一部分：为什么需要独立鉴权中心

### 1.1 问题的演进

**第一阶段：权限硬编码（反面案例）**

在小型系统中，权限逻辑往往直接写在业务代码里：

```java
// 反面案例：权限逻辑散落在各处
if (user.getId() == 123 && "admin".equals(request.getParameter("role"))) {
    // 允许删除用户
    userService.delete(userId);
}
```

问题显而易见：
- 修改权限需要改代码、重新发版
- 无法审计谁在什么时间改了权限
- 新增业务系统时，权限逻辑要重新写一遍
- 权限变更的成本非常高

**第二阶段：权限表放在各应用库（半分散模式）**

每个业务系统自己维护一套权限表（user_role, role_permission 等），问题：
- 多个系统的权限策略不一致
- 跨系统的权限管理成本高（比如员工离职要删除多个系统的权限）
- 无法实现企业级的权限审计和统一控制

**第三阶段：独立鉴权中心（本文重点）**

将权限管理独立出来，形成一个专门的服务：

```
┌─────────────────────────────────────────┐
│          业务系统（A/B/C/...）           │
└────────────┬────────────────────────────┘
             │ 权限查询
             ↓
    ┌────────────────────┐
    │   鉴权中心服务      │
    │ - 权限数据库      │
    │ - 权限缓存        │
    │ - 权限引擎        │
    └────────────────────┘
```

### 1.2 独立鉴权中心的核心价值

| 价值维度 | 具体表现 | 工程收益 |
|--------|---------|---------|
| **权限审计** | 所有权限变更有唯一的审计日志 | 安全合规、故障排查快速 |
| **高效迭代** | 权限变更无需改代码、发版 | 从小时级降低到分钟级 |
| **跨系统一致** | 同一个用户在所有系统中的权限视图一致 | 避免数据不一致的坑 |
| **细粒度控制** | 支持页面、接口、数据三个层次的权限 | 灵活适应复杂业务 |
| **集中性能优化** | 在一个地方做缓存、预计算、高可用 | 不用每个系统都重复优化 |
| **职责清晰** | 鉴权中心专注权限，业务系统专注业务 | 降低系统复杂度 |

---

## 第二部分：鉴权中心设计原则

### 2.1 核心设计原则

**原则 1：权限分层设计**

不要试图用一个模型解决所有权限问题。应该分为三层：

- **第1层 - 页面权限（UI 权限）**：用户能看到哪些菜单、按钮
- **第2层 - 接口权限（API 权限）**：用户能调用哪些 API
- **第3层 - 数据权限（Data Scope）**：用户能访问哪些数据

这样做的好处：
- 职责清晰，易于维护
- 性能可以针对性优化（比如页面权限可以更激进地缓存）
- 降低误用的概率（比如有人容易混淆"能看到菜单"和"能访问数据"）

**原则 2：不要让鉴权中心成为数据库**

一个常见的反模式：把所有业务上下文都推送到鉴权中心。

```java
// 反面案例：鉴权中心需要知道所有业务信息
{
    "userId": "123",
    "permissions": [
        "order.view",
        "order.edit",
        "order.delete"
    ],
    "dataScopes": [
        {
            "resource": "order",
            "scope": "department_id=456"  // 跨越了太多业务上下文
        }
    ]
}
```

更好的做法是：鉴权中心只返回权限的**元数据**，具体的数据过滤由业务系统完成。

**原则 3：性能优先于理论完美性**

不要为了设计的"完美"而牺牲性能。在实际工程中：
- 80% 的权限问题用 RBAC 就足够了
- 20% 的复杂场景可以用 ABAC 或特殊处理
- 切勿为了覆盖那 20% 而让所有系统都付出性能代价

**原则 4：关键数据必须强一致，其他数据允许最终一致**

关键数据（用户禁用、角色删除）需要同步强制更新，但权限规则的变更可以通过异步事件最终一致。

---

## 第三部分：权限模型总览

### 3.1 核心概念

在深入设计之前，先明确几个核心实体：

```
用户 (User)
  ↓ 被分配到
  ├── 角色 (Role)
  │     ├─ 拥有
  │     └─→ 权限 (Permission)
  │          ├─ 页面权限
  │          ├─ 接口权限
  │          └─ 数据权限
  │
  └── 部门/组织 (Dept/Org)
        └─ 决定数据权限的范围
```

### 3.2 关键数据结构定义（SQL）

```sql
-- 1. 用户表
CREATE TABLE `user` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `username` VARCHAR(64) UNIQUE NOT NULL,
  `email` VARCHAR(128),
  `dept_id` BIGINT NOT NULL COMMENT '用户所属部门',
  `is_deleted` TINYINT DEFAULT 0 COMMENT '软删除标记，用于强一致性',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_dept_id (dept_id)
);

-- 2. 角色表
CREATE TABLE `role` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `name` VARCHAR(64) UNIQUE NOT NULL COMMENT '角色名称，如 admin, editor',
  `description` VARCHAR(255),
  `parent_id` BIGINT COMMENT '父角色，用于支持角色继承',
  `data_scope_type` VARCHAR(32) COMMENT 'ALL/DEPT/CUSTOM/PERSONAL，数据权限类型',
  `is_deleted` TINYINT DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_parent_id (parent_id)
);

-- 3. 用户-角色关联表
CREATE TABLE `user_role` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `user_id` BIGINT NOT NULL,
  `role_id` BIGINT NOT NULL,
  `assigned_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_user_role (user_id, role_id),
  INDEX idx_user_id (user_id),
  INDEX idx_role_id (role_id)
);

-- 4. 权限表（统一的权限定义）
CREATE TABLE `permission` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `code` VARCHAR(128) UNIQUE NOT NULL COMMENT '权限唯一标识，如 user:delete, order.view',
  `name` VARCHAR(64) NOT NULL COMMENT '权限名称',
  `type` VARCHAR(32) NOT NULL COMMENT 'MENU/API/DATA，权限类型',
  `resource` VARCHAR(128) COMMENT '资源标识，如 user, order',
  `action` VARCHAR(32) COMMENT '操作，如 view, edit, delete',
  `parent_id` BIGINT COMMENT '菜单权限的父菜单',
  `is_deleted` TINYINT DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_type (type),
  INDEX idx_resource_action (resource, action)
);

-- 5. 角色-权限关联表
CREATE TABLE `role_permission` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `role_id` BIGINT NOT NULL,
  `permission_id` BIGINT NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_role_perm (role_id, permission_id),
  INDEX idx_role_id (role_id),
  INDEX idx_permission_id (permission_id)
);

-- 6. 用户直接权限（支持用户粒度的权限调整，不走角色）
CREATE TABLE `user_permission` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `user_id` BIGINT NOT NULL,
  `permission_id` BIGINT NOT NULL,
  `assigned_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `is_deny` TINYINT DEFAULT 0 COMMENT '1表示显式拒绝',
  UNIQUE KEY unique_user_perm (user_id, permission_id),
  INDEX idx_user_id (user_id)
);

-- 7. 角色继承表（支持角色的多层继承）
CREATE TABLE `role_inheritance` (
  `parent_role_id` BIGINT NOT NULL COMMENT '父角色',
  `child_role_id` BIGINT NOT NULL COMMENT '子角色',
  `level` INT DEFAULT 1 COMMENT '继承层级，防止循环',
  PRIMARY KEY (parent_role_id, child_role_id),
  INDEX idx_child_role_id (child_role_id)
);
```

### 3.3 数据权限相关表

```sql
-- 8. 数据权限规则表
CREATE TABLE `data_permission_rule` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `role_id` BIGINT NOT NULL,
  `resource` VARCHAR(128) NOT NULL COMMENT '数据资源，如 order, customer',
  `scope_type` VARCHAR(32) NOT NULL COMMENT 'ALL/DEPT/CUSTOM/PERSONAL',
  `condition` VARCHAR(512) COMMENT '自定义条件，如 dept_id=? 或 owner_id=?',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_role_resource (role_id, resource)
);

-- 9. 部门表（用于数据权限的范围）
CREATE TABLE `department` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `name` VARCHAR(128) NOT NULL,
  `parent_id` BIGINT COMMENT '上级部门',
  `level` INT DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 第四部分：页面权限设计

### 4.1 页面权限的职责

页面权限（菜单权限）的核心职责：**决定用户能看到什么菜单和按钮**。

这一层通常在**客户端**或者 **API 网关**处理，目的是：
- 优化用户体验：不显示用户无权限的菜单
- 降低前端复杂度：前端不需要自己判断权限

### 4.2 设计模式

**模式 1：权限树返回**

鉴权中心返回用户能看到的完整菜单树：

```json
{
  "menus": [
    {
      "id": "1",
      "name": "系统管理",
      "path": "/admin",
      "children": [
        {
          "id": "1.1",
          "name": "用户管理",
          "path": "/admin/users",
          "actions": ["view", "add", "edit", "delete"]
        },
        {
          "id": "1.2",
          "name": "角色管理",
          "path": "/admin/roles",
          "actions": ["view", "add", "edit"]
        }
      ]
    },
    {
      "id": "2",
      "name": "订单管理",
      "path": "/order",
      "children": [
        {
          "id": "2.1",
          "name": "订单列表",
          "path": "/order/list",
          "actions": ["view", "export"]
        }
      ]
    }
  ]
}
```

客户端收到后，直接根据这个树渲染菜单。

**模式 2：权限编码检查**

客户端保存所有可能的菜单定义，鉴权中心只返回权限编码列表，客户端自己过滤：

```json
{
  "permissions": [
    "menu:admin:view",
    "menu:admin:users:view",
    "menu:admin:users:add",
    "menu:admin:users:edit",
    "menu:admin:users:delete",
    "menu:order:view",
    "menu:order:list:view",
    "menu:order:list:export",
    "button:order:create"
  ]
}
```

客户端代码（伪代码）：

```javascript
function canViewMenu(menuCode) {
  return userPermissions.includes(`menu:${menuCode}:view`);
}

function canClickButton(buttonCode) {
  return userPermissions.includes(`button:${buttonCode}`);
}
```

### 4.3 工程建议

1. **权限编码规范很重要**：统一用 `resource:action` 的格式（如 `user:delete`, `order:view`）
2. **层级权限的继承**：如果用户有 `menu:admin:view`，应该自动有 `menu:admin:users:view` 等子权限（或者在返回时展开）
3. **缓存策略**：页面权限变更不需要实时生效，可以缓存 5-10 分钟，大幅降低鉴权中心的 QPS

---

## 第五部分：接口权限设计

### 5.1 接口权限的职责

接口权限在**服务端**执行，职责是：**拒绝未授权的 API 调用**。

这是真正的安全防线，必须强制执行，不能绕过。

### 5.2 实现方式

**方式 1：API 网关集中检查**

```
请求 → API 网关 → 检查权限 → 转发到业务服务 → 返回响应
```

优点：
- 业务服务无需关心权限检查，代码简洁
- 所有权限检查在一个地方，便于监控和审计
- 可以在网关层做限流、黑名单等通用处理

缺点：
- 网关成为性能瓶颈
- 权限决策的复杂逻辑在网关层，维护困难

**方式 2：业务服务本地检查**

```java
// 在 Spring Boot 中用注解实现
@RestController
@RequestMapping("/api/users")
public class UserController {
    
    @PostMapping("/{id}/delete")
    @RequiresPermission("user:delete")  // 权限注解
    public Response deleteUser(@PathVariable Long id) {
        // 实际删除逻辑
        userService.delete(id);
        return Response.ok();
    }
}
```

优点：
- 灵活性高，可以根据业务逻辑动态判断权限
- 实现按需计费式的权限检查（有些 API 不需要检查）

缺点：
- 业务服务需要依赖鉴权中心的客户端库
- 需要在每个 API 上加权限注解，容易遗漏

**推荐：混合方式**

1. **API 网关做基础安全检查**：拒绝完全没有权限的请求
2. **业务服务做细粒度权限检查**：根据数据上下文决定是否允许

```java
// 业务服务：检查用户是否能修改这个订单
@PostMapping("/orders/{orderId}/cancel")
public Response cancelOrder(@PathVariable Long orderId) {
    // 1. 权限检查：用户是否有 order:edit 权限
    @RequiresPermission("order:edit")
    
    // 2. 数据权限检查：用户是否有权限修改这个订单
    Order order = orderService.findById(orderId);
    if (!userHasDataPermission(getCurrentUser(), order)) {
        throw new ForbiddenException("无权修改该订单");
    }
    
    // 3. 业务逻辑检查：订单状态是否可以取消
    if (order.getStatus() != OrderStatus.PENDING) {
        throw new BusinessException("订单状态不允许取消");
    }
    
    // 4. 执行取消
    orderService.cancel(orderId);
}
```

### 5.3 接口权限的定义

在权限表中，接口权限的编码应该反映 **资源** 和 **操作**：

```sql
INSERT INTO permission (code, name, type, resource, action) VALUES
('user:view', '查看用户', 'API', 'user', 'view'),
('user:create', '创建用户', 'API', 'user', 'create'),
('user:edit', '编辑用户', 'API', 'user', 'edit'),
('user:delete', '删除用户', 'API', 'user', 'delete'),
('order:view', '查看订单', 'API', 'order', 'view'),
('order:edit', '编辑订单', 'API', 'order', 'edit'),
('order:export', '导出订单', 'API', 'order', 'export');
```

### 5.4 性能优化：权限检查的缓存

接口权限检查的核心性能问题是：**每次请求都要查权限吗？**

答案是**不能每次都查数据库**。最佳实践是：

```
请求来临
  ↓
  ├─ 检查本地缓存（用户的权限缓存）
  │   ├─ 缓存命中 → 直接判断 → 响应
  │   └─ 缓存未命中
  │       ↓
  │   └─ 查 Redis（分布式缓存）
  │       ├─ Redis 命中 → 加载到本地缓存 → 判断
  │       └─ Redis 未命中
  │           ↓
  │       └─ 查权限数据库 → 更新 Redis → 更新本地缓存 → 判断
```

缓存键设计：

```
// 用户的权限缓存
auth:permissions:{userId} = [
  "user:view",
  "user:edit",
  "order:view",
  ...
]

// 缓存过期时间：10-30 分钟（根据业务对一致性的要求）
```

缓存失效机制：
- **主动失效**：权限变更时，立即删除相关缓存
- **被动失效**：缓存过期时间到达，自动重新加载
- **监听失效**：通过事件系统（如消息队列），当权限变更时，所有服务都收到通知，更新本地缓存

---

## 第六部分：数据权限设计（核心难点）

### 6.1 数据权限的本质

数据权限解决的问题：**同样的 API，不同的用户看到的数据不同**。

例如，`GET /api/orders` 接口：
- 管理员可以看到所有订单
- 销售经理只能看到自己部门的订单
- 销售员只能看到自己的订单

这不能在网关层解决，必须在数据库查询层处理。

### 6.2 RBAC 数据权限模型（推荐）

RBAC 的数据权限基于**角色**的数据范围定义。常见的 `DataScope` 类型：

| Scope 类型 | 说明 | SQL 条件示例 |
|-----------|------|-----------|
| **ALL** | 所有数据 | 无条件 |
| **DEPT** | 本部门及下属部门的数据 | `dept_id IN (select id from dept where parent_path like ?)` |
| **DEPT_ONLY** | 仅本部门数据 | `dept_id = ?` |
| **PERSONAL** | 仅个人数据 | `created_by = ? OR owner_id = ?` |
| **CUSTOM** | 自定义条件 | 由 condition 字段定义 |

**数据库设计：**

```sql
-- 角色表中已有 data_scope_type
ALTER TABLE role ADD COLUMN data_scope_type VARCHAR(32) DEFAULT 'DEPT';

-- 数据权限规则表：当 scope_type 为 CUSTOM 时，用 condition 字段
CREATE TABLE data_permission_rule (
  id BIGINT PRIMARY KEY,
  role_id BIGINT,
  resource VARCHAR(128),  -- 数据资源，如 'order', 'customer'
  scope_type VARCHAR(32),  -- ALL/DEPT/DEPT_ONLY/PERSONAL/CUSTOM
  condition VARCHAR(1024),  -- 自定义 SQL 条件，如 "dept_id = ? OR created_by = ?"
  UNIQUE KEY (role_id, resource)
);
```

### 6.3 在应用层执行数据权限过滤

**方式 1：SQL 拼接（最常见，但要小心 SQL 注入）**

```java
public List<Order> listOrders(User user) {
    String baseSql = "SELECT * FROM `order` WHERE 1=1";
    
    // 1. 获取用户的角色
    List<Role> roles = roleService.getRolesByUserId(user.getId());
    
    // 2. 根据数据权限追加 WHERE 条件
    String dataScopeCondition = buildDataScopeCondition(roles, user);
    
    String finalSql = baseSql + " AND " + dataScopeCondition;
    
    return jdbcTemplate.query(finalSql, orderRowMapper);
}

private String buildDataScopeCondition(List<Role> roles, User user) {
    // 返回 SQL 片段，如 "dept_id IN (select id from dept...)"
    // 这里需要非常小心 SQL 注入，建议用参数化查询
    
    // 获取用户所在部门及下属部门
    List<Long> deptIds = getDeptAndSubDepts(user.getDeptId());
    
    return "dept_id IN (" + deptIds.stream()
        .map(String::valueOf)
        .collect(Collectors.joining(",")) + ")";
}
```

**方式 2：ORM 框架拦截器（推荐，更安全）**

以 MyBatis-Plus 为例：

```java
@Component
public class DataPermissionInterceptor implements InnerInterceptor {
    
    @Override
    public void beforeQuery(Executor executor, MappedStatement ms, 
                           Object parameter, RowBounds rowBounds, 
                           ResultHandler resultHandler) {
        // 1. 获取当前用户
        User currentUser = SecurityContextHolder.getContext().getAuthentication()
            .getPrincipal();
        
        if (currentUser == null || currentUser.isAdmin()) {
            return;  // 管理员不需要数据权限过滤
        }
        
        // 2. 解析 SQL，获取 table name
        String sql = ms.getBoundSql(parameter).getSql();
        String tableName = extractTableName(sql);
        
        // 3. 查询数据权限规则
        DataPermissionRule rule = dataPermissionService
            .getRule(currentUser.getId(), tableName);
        
        if (rule == null) {
            return;
        }
        
        // 4. 修改 SQL，添加 WHERE 条件
        String newSql = addWhereCondition(sql, buildCondition(rule, currentUser));
        
        // 5. 更新 MappedStatement 中的 SQL
        updateSql(ms, newSql);
    }
}
```

### 6.4 避免的反模式

**反模式 1：把所有业务数据都推送到鉴权中心**

```json
// 不要这样做！
{
  "userId": "123",
  "dataScopes": [
    {
      "resource": "order",
      "departments": ["dept1", "dept2", "dept3"],
      "regions": ["region1", "region2"],
      "teams": ["team1"],
      "projects": ["project1", "project2"]
    }
  ]
}
```

为什么不好：
- 数据量膨胀，网络开销大
- 业务结构变化（新增部门类型）要改权限中心
- 无法处理动态数据（比如"用户能访问他参与的项目"）

**反模式 2：在鉴权中心维护完整的数据模型**

```java
// 不要这样做！
// 鉴权中心不应该维护这些
class OrderDataPermission {
    List<Long> allowedOrderIds;
    List<Long> allowedSupplierIds;
    List<Long> allowedWarehouseIds;
    List<String> allowedOrderStatuses;
}
```

正确做法是：鉴权中心只返回**规则**，业务系统执行规则。

### 6.5 ABAC 在数据权限中的使用场景

RBAC 的数据权限大多数情况够用，但有些场景需要 ABAC（基于属性）：

**场景 1：基于用户属性**
- 销售只能查看分配给自己的订单：`owner_id = ${user.id}`
- 财务只能查看审批人包含自己的报销单：`approver_ids LIKE ${user.id}`

**场景 2：基于资源属性**
- 用户只能查看状态为"已发布"的内容：`status = 'published'`
- 用户只能查看优先级不超过 P2 的工单：`priority <= 2`

**场景 3：基于时间属性**
- 用户只能查看 7 天内的订单：`created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)`

**实现 ABAC 时的条件表达式：**

```sql
-- 数据权限规则中的 condition 字段
-- 支持简单的 SpEL 或 JEXL 表达式

"owner_id = ${currentUser.id}"
"dept_id IN (${currentUser.deptIds})"
"status = 'published' AND priority <= 2"
"created_at > DATE_SUB(NOW(), INTERVAL ${dataRetentionDays} DAY)"
```

在运行时解析：

```java
private String resolveCondition(String template, User user) {
    // 简单的字符串替换实现
    String condition = template
        .replace("${currentUser.id}", String.valueOf(user.getId()))
        .replace("${currentUser.deptIds}", 
                 getDeptIds(user).stream()
                     .map(String::valueOf)
                     .collect(Collectors.joining(",")));
    
    return condition;
}
```

---

## 第七部分：高并发与一致性的设计取舍

### 7.1 一致性分析

权限系统中的数据可以分为两类：

| 数据类型 | 例子 | 一致性需求 | 策略 |
|---------|------|---------|------|
| **关键数据** | 用户是否被禁用、角色是否被删除 | 强一致性 | 实时查询 + 及时缓存失效 |
| **权限规则** | 用户-角色关联、角色-权限关联 | 最终一致性（数分钟） | 缓存 + 异步更新 |

### 7.2 缓存策略

**三层缓存架构：**

```
┌──────────────────────────────────────┐
│ 第 1 层：本地缓存（内存）             │
│ - Caffeine、GuavaCache               │
│ - 超短过期时间（1-5 分钟）           │
│ - 降低网络开销                       │
└──────────────────────────────────────┘
           ↓ 命中率 < 70%
┌──────────────────────────────────────┐
│ 第 2 层：分布式缓存（Redis）          │
│ - 所有服务共享                       │
│ - 中等过期时间（10-30 分钟）         │
│ - 支持集中失效控制                   │
└──────────────────────────────────────┘
           ↓ Redis 不可用或未命中
┌──────────────────────────────────────┐
│ 第 3 层：数据库（MySQL）              │
│ - 真实数据源                         │
│ - 强一致性保证                       │
│ - 需要有降级策略                     │
└──────────────────────────────────────┘
```

**缓存键设计：**

```java
// 用户权限缓存
String permissionCacheKey = "auth:perms:" + userId;  // HASH

// 用户角色缓存
String roleCacheKey = "auth:roles:" + userId;  // HASH

// 角色权限缓存（可选，看是否需要重复计算）
String rolePermCacheKey = "auth:role:perms:" + roleId;  // SET

// 部门层级缓存（用于数据权限范围）
String deptCacheKey = "auth:dept:tree:" + deptId;  // JSON
```

**缓存预热：**

系统启动时或权限变更时，主动加载热数据到缓存：

```java
@Component
public class PermissionCachePreheater {
    
    @PostConstruct
    public void preheatCache() {
        // 1. 加载所有活跃用户的权限
        List<User> activeUsers = userService.getActiveUsers();
        for (User user : activeUsers) {
            permissionCache.refresh(user.getId());
        }
        
        // 2. 加载组织结构
        departmentCache.refresh();
        
        log.info("Permission cache preheating completed");
    }
}
```

### 7.3 缓存失效策略

**策略 1：主动失效（强一致性）**

权限变更时立即删除缓存：

```java
@Service
public class RoleService {
    
    @Transactional
    public void updateRole(Long roleId, RoleUpdateRequest request) {
        // 1. 更新数据库
        roleRepository.update(roleId, request);
        
        // 2. 立即失效相关缓存
        List<User> usersWithRole = userRoleRepository
            .findUsersByRoleId(roleId);
        for (User user : usersWithRole) {
            // 清除用户的权限缓存
            cacheManager.evict("auth:perms", user.getId());
            // 清除用户的角色缓存
            cacheManager.evict("auth:roles", user.getId());
        }
        
        // 3. 发送权限变更事件（给其他服务）
        eventPublisher.publishEvent(new PermissionChangedEvent(roleId));
        
        log.info("Role updated and cache invalidated: {}", roleId);
    }
}
```

**策略 2：被动失效（最终一致性）**

设置缓存过期时间，自动重新加载：

```java
// 缓存配置
@Configuration
public class CacheConfig {
    
    @Bean
    public CacheManager cacheManager(RedisConnectionFactory factory) {
        return RedisCacheManager.builder(factory)
            .cacheDefaults(
                RedisCacheConfiguration.defaultCacheConfig()
                    .entryTtl(Duration.ofMinutes(15))  // 15 分钟过期
            )
            .build();
    }
}
```

**策略 3：监听失效（跨服务同步）**

权限中心发送消息，所有服务都收到通知，更新本地缓存：

```java
@Component
public class PermissionChangeListener {
    
    @RabbitListener(queues = "permission.changed")
    public void onPermissionChanged(PermissionChangeEvent event) {
        // 清除本地缓存
        cacheManager.evict("auth:perms", event.getUserId());
        
        log.info("Permission changed event received: {}", event);
    }
}
```

### 7.4 高可用设计

**问题：如果鉴权中心宕机怎么办？**

方案：

```
1. 多副本部署：至少 3 个实例
2. 读写分离：主库写，从库读（权限查询通常是读）
3. 本地缓存降级：缓存失效时，不要直接返回 403，而是允许请求通过
   （这样做的风险是权限被临时放宽，但至少系统可用）
4. 黑名单熔断：已知被禁用的用户，直接拒绝，不查库
```

```java
@Component
public class PermissionCheckFilter extends OncePerRequestFilter {
    
    @Override
    protected void doFilterInternal(HttpServletRequest request, 
                                   HttpServletResponse response,
                                   FilterChain filterChain) 
            throws ServletException, IOException {
        
        String userId = extractUserIdFromToken(request);
        
        try {
            // 1. 检查是否在黑名单中
            if (userBlacklistCache.contains(userId)) {
                response.sendError(HttpServletResponse.SC_FORBIDDEN);
                return;
            }
            
            // 2. 检查权限（优先本地缓存，再查 Redis，最后查库）
            boolean hasPermission = permissionService.hasPermission(userId, 
                                                      extractRequiredPermission(request));
            
            if (hasPermission) {
                filterChain.doFilter(request, response);
            } else {
                response.sendError(HttpServletResponse.SC_FORBIDDEN);
            }
        } catch (Exception e) {
            // 鉴权中心异常：允许请求通过（降级策略）
            log.error("Permission check failed", e);
            if (isInLocalCache(userId)) {
                filterChain.doFilter(request, response);
            } else {
                response.sendError(HttpServletResponse.SC_SERVICE_UNAVAILABLE);
            }
        }
    }
}
```

---

## 第八部分：多租户设计

### 8.1 为什么需要多租户

一个鉴权中心往往服务多个企业（租户）。需要做到：
- **数据隔离**：A 租户的权限不能看到 B 租户的
- **资源隔离**：每个租户有独立的配额
- **自定义扩展**：不同租户的权限规则不同

### 8.2 多租户隔离方案

**方案 1：独立数据库（最严格，但成本高）**

```
Tenant A ──→ Database A
Tenant B ──→ Database B
Tenant C ──→ Database C
```

优点：完全隔离，安全性最高

缺点：运维复杂，资源浪费

**方案 2：共享数据库 + 租户字段（推荐）**

```sql
-- 所有表都加 tenant_id 字段
ALTER TABLE `user` ADD COLUMN `tenant_id` BIGINT NOT NULL;
ALTER TABLE `role` ADD COLUMN `tenant_id` BIGINT NOT NULL;
ALTER TABLE `permission` ADD COLUMN `tenant_id` BIGINT NOT NULL;

-- 所有查询都加租户过滤条件
SELECT * FROM user WHERE tenant_id = ? AND id = ?
```

实现租户隔离的拦截器：

```java
@Component
public class TenantContextFilter extends OncePerRequestFilter {
    
    @Override
    protected void doFilterInternal(HttpServletRequest request, 
                                   HttpServletResponse response,
                                   FilterChain filterChain) 
            throws ServletException, IOException {
        
        // 从请求头或 Token 中提取租户 ID
        String tenantId = request.getHeader("X-Tenant-Id");
        
        if (StringUtils.isEmpty(tenantId)) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, 
                             "Missing tenant ID");
            return;
        }
        
        // 保存到 ThreadLocal，后续所有数据库查询都会自动添加租户过滤
        TenantContext.setCurrentTenant(tenantId);
        
        try {
            filterChain.doFilter(request, response);
        } finally {
            TenantContext.clear();
        }
    }
}
```

MyBatis 拦截器自动添加租户条件：

```java
@Component
public class TenantInterceptor implements InnerInterceptor {
    
    @Override
    public void beforeQuery(Executor executor, MappedStatement ms, 
                           Object parameter, RowBounds rowBounds, 
                           ResultHandler resultHandler) {
        String sql = ms.getBoundSql(parameter).getSql();
        
        // 如果 SQL 不包含租户条件，自动添加
        if (!sql.contains("tenant_id")) {
            String tenantId = TenantContext.getCurrentTenant();
            String newSql = sql + " AND tenant_id = " + tenantId;
            updateSql(ms, newSql);
        }
    }
}
```

### 8.3 多租户下的权限继承问题

**问题：不同租户的权限规则完全不同**

例如，Tenant A 的组织结构是"公司-部门-团队"，但 Tenant B 是"集团-子公司-部门"。

**解决方案：灵活的权限规则定义**

```sql
-- 数据权限规则支持租户粒度的自定义
CREATE TABLE data_permission_rule (
  id BIGINT PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  role_id BIGINT NOT NULL,
  resource VARCHAR(128),
  scope_type VARCHAR(32),
  condition VARCHAR(1024),  -- 租户可以自定义 condition 的内容
  created_at TIMESTAMP,
  UNIQUE KEY (tenant_id, role_id, resource)
);
```

管理界面允许每个租户配置自己的权限规则。

---

## 第九部分：权限审计与变更追踪

### 9.1 为什么需要审计

- **安全合规**：等保、SOC 2 等要求权限变更可追踪
- **故障排查**：权限异常时，能快速定位是谁在什么时间改的
- **权限回溯**：需要知道某个用户在历史某个时刻有哪些权限

### 9.2 审计日志设计

```sql
CREATE TABLE audit_log (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  tenant_id BIGINT NOT NULL,
  operator_id BIGINT COMMENT '执行操作的管理员',
  operation_type VARCHAR(32) COMMENT 'CREATE/UPDATE/DELETE',
  target_type VARCHAR(32) COMMENT '作用对象：USER/ROLE/PERMISSION',
  target_id BIGINT,
  old_value JSON COMMENT '变更前的值',
  new_value JSON COMMENT '变更后的值',
  reason VARCHAR(512) COMMENT '变更原因',
  ip_address VARCHAR(64),
  user_agent VARCHAR(512),
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_tenant_timestamp (tenant_id, timestamp),
  KEY idx_target (target_type, target_id)
);
```

### 9.3 自动审计实现

使用 Spring Data Auditing：

```java
@Data
@Entity
@EntityListeners(AuditingEntityListener.class)
public class Role {
    @Id
    private Long id;
    private String name;
    
    @CreatedBy
    private String createdBy;
    
    @CreatedDate
    private Instant createdDate;
    
    @LastModifiedBy
    private String lastModifiedBy;
    
    @LastModifiedDate
    private Instant lastModifiedDate;
}
```

或者使用 Hibernate Envers：

```java
@Entity
@Audited  // 自动审计所有变更
public class Role {
    @Id
    private Long id;
    private String name;
    // ...
}

// 查询历史版本
AuditReader reader = AuditReaderFactory.get(em);
List<Number> revisions = reader.getRevisions(Role.class, roleId);
Role roleAtRevision = reader.find(Role.class, roleId, revisions.get(0));
```

---

## 第十部分：性能优化策略

### 10.1 常见性能瓶颈

| 瓶颈 | 表现 | 原因 | 优化方案 |
|-----|------|------|---------|
| **权限查询 QPS 高** | 鉴权中心 CPU 高 | 每次请求都要多表 JOIN | 缓存 + 预计算 |
| **缓存穿透** | Redis 大量未命中 | 不存在的权限被反复查询 | 布隆过滤器 + 空值缓存 |
| **缓存雪崩** | 缓存同时失效，DB 被压爆 | 缓存过期时间设置不当 | 随机过期时间 + 缓存预热 |
| **角色-权限 JOIN** | 查询慢 | 表太大，JOIN 条件不好 | 反范式化（在 user_role 表中冗余权限列表） |
| **数据权限过滤** | 查询慢 | SQL 拼接复杂，子查询多 | 物化视图、预计算权限范围 |

### 10.2 具体优化案例

**优化 1：权限列表反范式化缓存**

不要每次都 JOIN user_role 和 role_permission 表。

```sql
-- 反范式化存储
CREATE TABLE user_permission_cache (
  user_id BIGINT PRIMARY KEY,
  permission_codes JSON COMMENT '用户的权限编码列表，JSON 数组',
  roles_hash VARCHAR(32) COMMENT '基于角色的 hash，用于判断是否需要更新',
  updated_at TIMESTAMP,
  KEY idx_updated (updated_at)
);

-- 权限变更时，异步更新这个表
INSERT INTO user_permission_cache (user_id, permission_codes, roles_hash)
SELECT u.id, 
       JSON_ARRAY_COMPACT(GROUP_CONCAT(p.code)),
       MD5(GROUP_CONCAT(r.id))
FROM user u
LEFT JOIN user_role ur ON u.id = ur.user_id
LEFT JOIN role r ON ur.role_id = r.id
LEFT JOIN role_permission rp ON r.id = rp.role_id
LEFT JOIN permission p ON rp.permission_id = p.id
WHERE u.is_deleted = 0
GROUP BY u.id
ON DUPLICATE KEY UPDATE
  permission_codes = VALUES(permission_codes),
  updated_at = NOW();
```

查询时直接读这个表：

```java
public List<String> getUserPermissions(Long userId) {
    // 先查缓存
    String cached = redisTemplate.opsForValue()
        .get("user:perms:" + userId);
    if (cached != null) {
        return parsePermissions(cached);
    }
    
    // 缓存未命中，查数据库
    UserPermissionCache cache = userPermissionCacheRepository
        .findById(userId)
        .orElse(null);
    
    if (cache != null) {
        List<String> permissions = parsePermissions(cache.getPermissionCodes());
        // 存入缓存
        redisTemplate.opsForValue()
            .set("user:perms:" + userId, cache.getPermissionCodes(), 
                 Duration.ofMinutes(20));
        return permissions;
    }
    
    return Collections.emptyList();
}
```

**优化 2：数据权限范围预计算**

不要在查询时才构建 WHERE 条件，提前计算好。

```java
@Component
public class DataPermissionPrecomputer {
    
    @Scheduled(fixedDelay = 300000)  // 每 5 分钟
    public void precomputeDataScopes() {
        List<User> users = userRepository.findAll();
        
        for (User user : users) {
            // 计算用户能访问的部门范围
            Set<Long> deptIds = computeAccessibleDepts(user);
            String deptIdsStr = deptIds.stream()
                .map(String::valueOf)
                .collect(Collectors.joining(","));
            
            // 存入 Redis
            redisTemplate.opsForValue()
                .set("user:dept_scope:" + user.getId(), deptIdsStr);
        }
    }
    
    private Set<Long> computeAccessibleDepts(User user) {
        // 递归计算用户所在部门及其下属部门
        Set<Long> result = new HashSet<>();
        Queue<Long> queue = new LinkedList<>();
        queue.offer(user.getDeptId());
        
        while (!queue.isEmpty()) {
            Long deptId = queue.poll();
            result.add(deptId);
            
            // 获取子部门
            List<Department> subDepts = departmentRepository
                .findByParentId(deptId);
            subDepts.forEach(d -> queue.offer(d.getId()));
        }
        
        return result;
    }
}
```

查询时直接使用预计算的范围：

```java
public List<Order> listOrders(User user) {
    // 从缓存获取部门范围
    String deptIdsCached = redisTemplate.opsForValue()
        .get("user:dept_scope:" + user.getId());
    
    List<Long> deptIds = Arrays.stream(deptIdsCached.split(","))
        .map(Long::parseLong)
        .collect(Collectors.toList());
    
    // 直接查询，不需要复杂的 SQL 拼接
    return orderRepository.findByDeptIdIn(deptIds);
}
```

### 10.3 监控指标

需要关注的核心指标：

```
1. 鉴权 QPS：权限查询的吞吐量
2. 鉴权延迟：p50、p95、p99（应该在 10ms 以内）
3. 缓存命中率：应该在 95% 以上
4. 权限变更延迟：权限改完到生效的时间（应该在 30s 以内）
5. 可用性：99.9% 或更高
```

---

## 第十一部分：常见反模式与避坑指南

### 11.1 反模式集合

**反模式 1：权限中心维护所有数据**

```java
// 错误
{
    "userId": 123,
    "departments": [1, 2, 3],
    "projects": [10, 20, 30],
    "teams": [100, 200],
    "positions": ["Manager", "PM"],
    "regions": ["Asia", "Europe"],
    // ... 还有 20 个字段
}
```

权限中心会变成数据库，维护代价巨大。

**正确做法**：权限中心只返回权限和角色，具体的组织结构、部门等数据由业务系统维护。

---

**反模式 2：同步等待权限检查结果**

```java
// 错误：同步 RPC 调用，阻塞当前线程
boolean hasPermission = authCenter.checkPermission(userId, permission);
if (!hasPermission) {
    throw new ForbiddenException();
}
```

高并发下会导致线程池满。

**正确做法**：本地缓存的权限应该已经包含了答案，不需要同步调用。只有缓存不命中才查询。

---

**反模式 3：权限字段命名不规范**

```sql
-- 错误：命名不一致
INSERT INTO permission (code, name) VALUES
('user_delete', '删除用户'),           -- user_delete
('order.view', '查看订单'),            -- order.view
('customer-edit', '编辑客户'),         -- customer-edit
('product:create', '创建商品');        -- product:create
```

不同的格式会导致前端判断逻辑复杂。

**正确做法**：统一用 `resource:action` 或 `resource.action` 格式。

---

**反模式 4：忽视权限的过期失效**

```java
// 错误：权限更新了，但缓存一直有效
cacheManager.put("user:perms:123", permissions);  // 没有设置过期时间
```

缓存永不过期，权限变更永远不会生效。

**正确做法**：为每个缓存键设置过期时间，并在权限变更时主动清除。

---

**反模式 5：在数据库层面做权限过滤，然后在应用层再过一遍**

```java
// 错误：重复过滤
List<Order> orders = orderRepository.findByDeptId(userDeptId);

// 然后在应用层又检查一遍
orders = orders.stream()
    .filter(order -> userHasDataPermission(user, order))
    .collect(Collectors.toList());
```

这样会导致错误的数据被加载到内存。

**正确做法**：权限过滤只在一个地方做（通常在 SQL 层）。

---

### 11.2 决策框架：什么时候用 ABAC

```
是否需要 ABAC？

├─ 权限规则：是否涉及多个属性的复杂组合？
│  ├─ 否 → 用 RBAC
│  └─ 是
│      └─ 规则是否频繁变化？
│         ├─ 是 → 用 ABAC（表达式引擎）
│         └─ 否 → 用 RBAC + 少量特殊逻辑
│
└─ 成本评估
   ├─ 开发成本：ABAC 是 RBAC 的 3-5 倍
   ├─ 运维成本：更复杂的规则管理、更多的测试
   └─ 性能成本：表达式计算、更复杂的 SQL
```

**建议**：除非你的用户已经在大量使用 ABAC 或有非常复杂的权限规则，否则从 RBAC 开始，以后再根据需要扩展。

---

## 第十二部分：集成案例

### 12.1 典型的集成流程

```
1. 用户登录
   └─→ 生成 Token，包含 userId
   
2. 用户首次访问系统
   └─→ 前端调用 `/api/auth/permissions`
   └─→ 后端查询权限（缓存或库）
   └─→ 返回权限列表 + 菜单树
   └─→ 前端渲染菜单、隐藏无权限按钮
   
3. 用户访问某个 API
   └─→ 网关拦截，检查基础权限（在缓存中）
   └─→ 转发到业务服务
   └─→ 业务服务检查数据权限（执行 SQL 过滤）
   └─→ 返回用户有权访问的数据
   
4. 权限被修改
   └─→ 管理员在权限系统中改动
   └─→ 权限中心触发权限变更事件
   └─→ 所有服务收到事件，清除相关用户的缓存
   └─→ 下次请求时重新加载权限
```

### 12.2 代码示例：一个完整的权限检查流程

```java
@Component
public class PermissionService {
    
    private static final long CACHE_TTL_MINUTES = 15;
    
    @Autowired
    private PermissionRepository permissionRepository;
    
    @Autowired
    private UserRoleRepository userRoleRepository;
    
    @Autowired
    private RedisTemplate<String, String> redisTemplate;
    
    /**
     * 获取用户的所有权限
     */
    public Set<String> getUserPermissions(Long userId) {
        // 1. 检查本地缓存（由 Spring Cache 管理）
        Set<String> cached = getFromLocalCache(userId);
        if (cached != null) {
            return cached;
        }
        
        // 2. 检查 Redis
        String redisKey = "auth:perms:" + userId;
        String cachedJson = redisTemplate.opsForValue().get(redisKey);
        if (cachedJson != null) {
            Set<String> permissions = parsePermissions(cachedJson);
            putInLocalCache(userId, permissions);  // 更新本地缓存
            return permissions;
        }
        
        // 3. 从数据库查询
        Set<String> permissions = loadFromDatabase(userId);
        
        // 4. 存入缓存
        String json = serializePermissions(permissions);
        redisTemplate.opsForValue()
            .set(redisKey, json, Duration.ofMinutes(CACHE_TTL_MINUTES));
        putInLocalCache(userId, permissions);
        
        return permissions;
    }
    
    /**
     * 检查用户是否有某个权限
     */
    public boolean hasPermission(Long userId, String permissionCode) {
        Set<String> permissions = getUserPermissions(userId);
        return permissions.contains(permissionCode);
    }
    
    /**
     * 从数据库加载权限
     */
    private Set<String> loadFromDatabase(Long userId) {
        // 1. 获取用户的直接权限
        Set<String> directPermissions = permissionRepository
            .findPermissionCodesByUserId(userId);
        
        // 2. 获取用户的角色权限
        List<Long> roleIds = userRoleRepository.findRoleIdsByUserId(userId);
        Set<String> rolePermissions = permissionRepository
            .findPermissionCodesByRoleIds(roleIds);
        
        // 3. 合并，去除显式拒绝的权限
        Set<String> result = new HashSet<>(directPermissions);
        result.addAll(rolePermissions);
        
        Set<String> deniedPermissions = permissionRepository
            .findDeniedPermissionCodesByUserId(userId);
        result.removeAll(deniedPermissions);
        
        return result;
    }
    
    /**
     * 权限变更后，清除缓存
     */
    @EventListener
    public void onPermissionChanged(PermissionChangedEvent event) {
        // 清除 Redis 缓存
        redisTemplate.delete("auth:perms:" + event.getUserId());
        
        // 清除本地缓存
        clearLocalCache(event.getUserId());
        
        log.info("Permission cache cleared for user: {}", event.getUserId());
    }
}
```

### 12.3 前端使用示例（Vue 伪代码）

```javascript
// store/auth.js
export const authStore = {
  state: {
    permissions: [],
    menus: []
  },
  
  mutations: {
    setPermissions(state, permissions) {
      state.permissions = permissions;
    },
    setMenus(state, menus) {
      state.menus = menus;
    }
  },
  
  actions: {
    async loadPermissions({ commit }, userId) {
      const response = await api.get('/api/auth/permissions');
      commit('setPermissions', response.permissions);
      commit('setMenus', response.menus);
    }
  },
  
  getters: {
    hasPermission(state) {
      return (permissionCode) => state.permissions.includes(permissionCode);
    }
  }
};

// 在组件中使用
export default {
  methods: {
    canDeleteUser() {
      return this.$store.getters.hasPermission('user:delete');
    },
    
    canCreateOrder() {
      return this.$store.getters.hasPermission('order:create');
    }
  },
  
  computed: {
    visibleMenus() {
      // 返回用户有权限的菜单
      return this.$store.state.menus.filter(menu => 
        this.$store.getters.hasPermission(`menu:${menu.id}:view`)
      );
    }
  }
};
```

---

## 第十三部分：总结与架构思考

### 13.1 核心设计决策回顾

| 决策 | 方案 | 理由 |
|-----|------|------|
| **权限分层** | 页面 → 接口 → 数据 | 职责清晰，便于优化 |
| **权限模型** | RBAC 为主，ABAC 为辅 | 80/20 原则，性能优先 |
| **一致性** | 关键数据强一致，权限最终一致 | 可用性 vs 一致性的权衡 |
| **缓存策略** | 三层缓存（本地 + Redis + DB） | 降低延迟和 QPS |
| **多租户** | 共享数据库 + 租户字段 | 成本和隔离的平衡 |
| **数据权限** | SQL 层过滤，不往鉴权中心推 | 避免业务复杂度蔓延 |

### 13.2 上线前的检查清单

- [ ] 权限编码规范已确定（resource:action 格式）
- [ ] 三层权限（页面/接口/数据）的定义已明确
- [ ] 缓存策略已实现（本地 + Redis 双层）
- [ ] 权限变更事件已接入所有消费方
- [ ] 审计日志已完整记录
- [ ] 多租户隔离已验证
- [ ] 故障场景已测试（鉴权中心宕机、缓存宕机等）
- [ ] 性能基准测试已通过（权限查询 <10ms）
- [ ] 权限降级策略已实现
- [ ] 监控告警已配置

### 13.3 常见的演进路径

**第一阶段（MVP）：2-4 周**

```
目标：功能完整的 RBAC
核心：
  - User, Role, Permission 表和关联
  - 简单的权限检查接口
  - 权限变更 API
  - Redis 缓存
不做：
  - ABAC
  - 多租户
  - 复杂的数据权限
```

**第二阶段（性能优化）：4-6 周**

```
目标：应对高并发
新增：
  - 多层缓存架构
  - 权限反范式化存储
  - 权限预计算
  - 缓存失效机制
  - 性能监控
```

**第三阶段（功能扩展）：6-10 周**

```
目标：支持复杂的权限场景
新增：
  - 数据权限（DataScope）
  - 角色继承
  - 用户直接权限
  - 权限组合
  - 简单的 ABAC（条件表达式）
```

**第四阶段（企业级特性）：10+ 周**

```
目标：支持大规模多租户、高可用
新增：
  - 完整的多租户隔离
  - 权限审计系统
  - 权限分析和推荐
  - 自定义权限模型
  - 联邦权限（跨企业权限）
```

### 13.4 最后的建议

**建议 1：不要过度设计**

许多团队一开始就设计复杂的 ABAC 模型，结果：
- 需要 6 个月才能上线
- 上线后依然有 bug
- 维护成本非常高

更好的做法：从 RBAC 开始，遇到 RBAC 无法解决的问题时再扩展。

**建议 2：权限变更的成本很高**

在设计初期就要考虑：
- 权限规则如何修改（管理界面）
- 修改后如何生效（缓存失效）
- 如何回滚（版本管理）
- 如何审计（变更日志）

**建议 3：监控和告警非常重要**

建立以下告警：
- 权限查询延迟 > 50ms
- 权限查询错误率 > 0.1%
- 缓存命中率 < 90%
- 权限变更延迟 > 60s

**建议 4：做好文档**

包括：
- 权限编码规范
- 权限检查的最佳实践
- 常见的坑和解决方案
- 接入指南（给业务团队）

---

## 附录：关键代码模板

### A.1 权限注解实现

```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface RequiresPermission {
    String value();  // 权限编码
    String message() default "Permission denied";
}

@Component
@Aspect
public class PermissionAspect {
    
    @Autowired
    private PermissionService permissionService;
    
    @Around("@annotation(requiresPermission)")
    public Object checkPermission(ProceedingJoinPoint joinPoint,
                                 RequiresPermission requiresPermission) 
            throws Throwable {
        
        Long userId = getCurrentUserId();
        String permissionCode = requiresPermission.value();
        
        if (!permissionService.hasPermission(userId, permissionCode)) {
            throw new ForbiddenException(requiresPermission.message());
        }
        
        return joinPoint.proceed();
    }
}
```

### A.2 数据权限过滤模板

```java
@Component
public class DataPermissionFilter {
    
    public String getDataPermissionCondition(Long userId, String resource) {
        // 1. 获取用户的数据权限规则
        DataPermissionRule rule = getRule(userId, resource);
        
        if (rule == null || rule.getScopeType().equals("ALL")) {
            return "1=1";  // 无限制
        }
        
        User user = userService.findById(userId);
        
        switch (rule.getScopeType()) {
            case "DEPT":
                // 本部门及下属部门
                List<Long> deptIds = getDeptAndSubDepts(user.getDeptId());
                return "dept_id IN (" + deptIds.stream()
                    .map(String::valueOf)
                    .collect(Collectors.joining(",")) + ")";
                
            case "PERSONAL":
                // 仅个人数据
                return "created_by = " + userId;
                
            case "CUSTOM":
                // 自定义条件
                return resolveCondition(rule.getCondition(), user);
                
            default:
                return "1=0";  // 拒绝所有
        }
    }
    
    private String resolveCondition(String template, User user) {
        return template
            .replace("${userId}", String.valueOf(user.getId()))
            .replace("${deptId}", String.valueOf(user.getDeptId()));
    }
}
```

### A.3 权限缓存预热

```java
@Component
public class PermissionCacheWarmer {
    
    @Autowired
    private PermissionService permissionService;
    
    @Autowired
    private RedisTemplate<String, String> redisTemplate;
    
    @PostConstruct
    public void warmUp() {
        List<User> activeUsers = userService.getActiveUsers();
        
        for (User user : activeUsers) {
            try {
                Set<String> permissions = permissionService
                    .loadFromDatabase(user.getId());
                String json = serializePermissions(permissions);
                redisTemplate.opsForValue()
                    .set("auth:perms:" + user.getId(), json,
                         Duration.ofMinutes(15));
            } catch (Exception e) {
                log.error("Failed to warm up cache for user: {}", 
                         user.getId(), e);
            }
        }
        
        log.info("Permission cache warmed up for {} users", activeUsers.size());
    }
}
```

---

## 参考资源

- RBAC 模型规范：[ANSI INCITS 359-2004](https://csrc.nist.gov/publications/detail/fips/204/final)
- AWS IAM（ABAC 实现参考）：https://docs.aws.amazon.com/iam/
- Casbin（开源权限管理库）：https://casbin.org/

---

**本文写于 2025 年 12 月，基于多年企业级系统设计经验。权限系统的设计没有完美方案，只有适合当前业务阶段的方案。希望这篇文章能帮你避免一些常见的坑。**