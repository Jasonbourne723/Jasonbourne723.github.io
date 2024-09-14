---
title: Git移除已被跟踪的文件
date: 2024-09-14 10:00:00 +0800
categories: [7.系统运维]
tags: []
---

要从 `GitHub` 仓库中移除已经上传的 `bin` 和 `obj` 目录，同时防止它们再次被上传，你可以按照以下步骤操作：

## 1. 添加 .gitignore 文件

首先，在项目的根目录下创建一个 `.gitignore` 文件，添加以下内容以忽略 `bin` 和 `obj` 文件夹：

```
# Ignore bin and obj directories
bin/
obj/
```

这将告诉 `Git`，忽略 `bin` 和 `obj` 目录中的文件。

## 2. 移除已被跟踪的 bin 和 obj 文件

即使你添加了 `.gitignore` 文件，`Git` 仍然会跟踪已经提交的文件。因此，你需要从 ` Git` 的历史记录中删除这些文件。执行以下命令：

```
git rm -r --cached bin obj
```

解释：

- `rm -r --cached` ：这会从 `Git` 的索引中移除 `bin` 和 `obj` 目录的文件，但不会从本地文件系统中删除它们。
- `bin obj` ：这是要移除的目录。

## 3. 提交更改

移除缓存后，提交这些更改：

```
git commit -m "Remove bin and obj directories from version control"
```

## 4. 推送到远程仓库

最后，将这些更改推送到远程仓库：

```
git push origin <branch-name>
```
其中 `<branch-name>` 是你当前使用的分支名称，通常是 `main` 或 `master`。

## 5. 验证

推送完成后，你可以到 `GitHub` 仓库查看，`bin` 和 `obj` 文件夹应该已经被移除。

这样，`bin` 和 `obj` 目录的文件就不会再被上传到 `Git` 仓库中。