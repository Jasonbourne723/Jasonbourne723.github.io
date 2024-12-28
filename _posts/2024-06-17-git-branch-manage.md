---
title: git分支管理策略
date: 2024-06-17 10:12:00 +0800
categories: [计系统运维算机基础]
tags: []
---

![](/assets/img/gitbranch/1.png)

- main: 具有无限生存期的主要分支，用于存放稳定的、可发布的代码。
- dev: 作为主开发分支，所有的功能分支都会从这里拉取，并在开发完成后合并回这个分支。
- feature: 每开始一个新功能都要从dev分支拉取一个新的功能分支。命名为 feature-*。完成后合并回 dev 分支。功能分支通常仅存在于开发人员存储库中，而不存在于origin 中。功能完成后，可以直接删除。
- release: 当 dev 分支上的代码接近发布时，会创建一个 release-* 分支用于最后的测试和修复。完成后合并到 main 和 dev。
- hotfix: 用于修复 main 分支上的紧急问题，命名为 hotfix-*。修复完成后合并到 main 和 dev。

## 开发流程

### 创建功能分支

开始新功能开发时，从dev创建新的功能分支。
```
$ git checkout -b myfeature dev
```

### 合并完成的功能

功能完成后，合并回dev分支。

```
$ git checkout dev
$ git merge --no-ff myfeature

$ git branch -d myfeature

$ git push origin dev
```

### 创建发布分支

当前版本的功能全部开发完成后，需要基于dev创建release分支，并在release分支上做最后的bug修复。此时dev分支可以开始下一个版本功能的开发。
```
$ git checkout -b release-1.2 dev
$ git commit -a -m "Bumped version number to 1.2"
```

### 完成发布分支

当release测试通过后，可以向main分支合并，并将main分支打上版本标签。用于软件版本追踪管理。

```
$ git checkout master

$ git merge --no-ff release-1.2

$ git tag -a 1.2
```

为了保留在release分支中所做的更改，我们还需要将更改合并回dev分支。

```
$ git checkout dev

$ git merge --no-ff release-1.2
```

最后删除release分支
```
$ git branch -d release-1.2
```

### 热修复分支

当软件在生产环境中出现了严重错误，需要紧急修复，可以直接从main分支创建hotfix分支。
```
$ git checkout -b hotfix-1.2.21060601 master

$ git commit -a -m "Bumped version number to 1.2.21060601"
```

错误修复完成后，合并回main分支以及dev分支。
```
$ git checkout master

$ git merge --no-ff hotfix-1.2.21060601 

$ git tag -a 1.2.21060601 

$ git checkout dev

$ git merge --no-ff hotfix-1.2.21060601 
```
最后，删除临时分支：
```
$ git branch -d hotfix-1.2.21060601 
```

##代码合并规范

规范化的 commit 信息有助于提高代码的可维护性和可读性，方便团队成员之间的协作，因此，我们需要制定统一标准，促使团队形成一致的代码提交风格，更好的提高工作效率。

### commit 格式

```
<type>[ticketId]: <subject> 
```

### type （必须）

- feat：新功能（feature）。
- fix/to：修复bug，可以是QA发现的BUG，也可以是研发自己发现的BUG。
  - fix：产生diff并自动修复此问题。适合于一次提交直接修复问题
  - to：只产生diff不自动修复此问题。适合于多次提交。最终修复问题提交时使用fix
- docs：文档（documentation）。
- style：格式（不影响代码运行的变动）。
- refactor：重构（即不是新增功能，也不是修改bug的代码变动）。
- perf：优化相关，比如提升性能、体验。
- test：增加测试。
- chore：构建过程或辅助工具的变动。
- revert：回滚到上一个版本。
- merge：代码合并。
- sync：同步主线或分支的Bug。

### tickitId（可选）

如果开发的内容录入了JIRA，需要填写ticketId，便于后续追踪。

### subject（必须）

subject是commit目的的简短描述，不超过50个字符，建议使用中文，结尾不加句号或其他标点符号。

### 示例

根据以上规范git commit message将是如下的格式：
```
fix[PD3-1669]: 用户查询缺少username属性 
feat[PD3-1670]: 用户查询接口开发
```