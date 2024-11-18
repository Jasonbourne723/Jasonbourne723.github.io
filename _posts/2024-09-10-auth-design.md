---
title: 统一用户权限系统设计
date: 2024-09-10 10:12:00 +0800
categories: [1.架构设计]
tags: []
hidden: true
---

![](/assets/img/auth/1.png)

```

user
-
id bigint PK
account varchar(50)
nickname varchar(50)
password varchar(200)
email varchar(100)
createdate datetime

user_organization
-
id bigint pk
user_id bigint fk - user.id
organization_id bigint fk - organization.id

organization
-
id bigint pk
name varchar(50)
parentId bigint

post 
-
id bigint pk
code varchar(20)
name varchar(50)

post_organization
-
id bigint pk
organization_id bigint fk - organization.id
post_id bigint fk - post.id

user_post
-
id bigint pk
user_id bigint fk - user.id
post_id bigint fk - post.id

role
-
id bigint PK
permission_space_id bigint fk - permission_space.id
name varchar(50)

user_role
-
id bigint PK
user_id bigint FK - user.id
role_id bigint fk - role.id

application
-
id bigint PK
name varchar(100)
description varchar(100)
app_key varchar(50)
app_secret varchar(100)
callback varchar(255)

permission_space
-
id bigint pk
name varchar(50)
code varchar(50) fk - application.id
description varchar(200)

resource
-
id bigint pk
name varchar(50)
code varchar(50)
permission_space_id bigint fk - permission_space.id
type tinyint commnet "树形、数组、字符串"
description varchar(200)

resource_action
-
id bigint pk
resource_id bigint fk - resource.id
name varchar(50)
description varchar(50)

resource_item
-
id bigint pk
name varchar(50)
code varchar(50)
resource_id bigint fk - resource.id
descption varchar(200)

policy
-
id bigint pk
name varchar(50)
descrition varchar(200)

policy_resource
-
id bigint pk
policy_id bigint fk - policy.id
permission_space_id bigint fk - permission_space.id
resource_id bigint fk - resource.id 
type tinyint 

policy_resource_item
-
id bigint 
policy_id bigint fk - policy.id
policy_resource_id bigint fk - policy_resource.id
resouce_item_id bigint fk - resource_item.id
resource_item_actions varchar(100)

policy_resource_condition
-
id bigint 
policy_id bigint fk - policy.id
policy_resource_id bigint fk - policy_resource.id
conditions varchar(200)

policy_auth
-
id bigint pk
name varchar(50)
policy_id bigint fk - policy.id
target_type tinyint comment "用户、角色、部门"
target_id bigint  fk - role.id
```