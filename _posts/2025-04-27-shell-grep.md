---
title: Linux命令：grep
date: 2025-04-27 10:12:00 +0800
categories: [系统运维]
tags: [shell]
hidden: true
---


Linux grep (global regular expression) 命令用于查找文件里符合条件的字符串或正则表达式。
`grep` 指令用于查找内容包含指定的范本样式的文件，如果发现某文件的内容符合所指定的范本样式，预设 `grep` 指令会把含有范本样式的那一列显示出来。若不指定任何文件名称，或是所给予的文件名为 `-`，则 `grep` 指令会从标准输入设备读取数据。

## 语法

```shell
grep [options] pattern [files]
- pattern - 表示要查找的字符串或正则表达式。
- files - 表示要查找的文件名，可以同时查找多个文件，如果省略 files 参数，则默认从标准输入中读取数据。
```

### 常用选项

- -i：忽略大小写进行匹配。
- -v：反向查找，只打印不匹配的行。
- -n：显示匹配行的行号。
- -r：递归查找子目录中的文件。
- -l：只打印匹配的文件名。
- -c：只打印匹配的行数。
  在单个文件中查询指定字符串

## 常用用法

1. 在单个文件中查询指定字符串
```shell
grep "literal_string" filename
```
2. 在多个文件中查找指定字符串，FILE_PATTERN 表示文件通配符表示。比如当前目录下的所有文件 ./*
```shell
grep "string" FILE_PATTERN
```
3. 查找的过程中忽略大小写
```shell
grep -i "string" FILE
```
4. 使用正则表达式来查找字符串。
```shell
grep "REGEX" filename
```
  - ? 0到1次
  - `*` 0到多次
  -  `+` 1到多次
  -    {n} 之匹配n次
  -    {n,} 最少n次
  -    {,m} 最多m次
  -    {n,m} 匹配最少n次，最多m次
5. 匹配完整的单词，而不是子串。
```shell
grep -iw "is" demo_file # 只会完整的匹配is这个单词
```
6. 现在匹配字符串前面/后面/前后两边的字符串。(After/Before/Around)。
```shell
grep -A 3 -i "example" demo_text # After 连着打印“example” 单词后的2行，共3行
grep -B 3 -i "example" demo_text # Before 连着打印“example” 单词前的2行，共3行
grep -C 3 -i "example" demo_text # Both 连着打印“example” 单词前后的2行，共5行
```
7. 使用 GREP_OPTIONS 高亮grep的显示结果
```shell
export GREP_OPTIONS='--color=auto' GREP_COLOR='100;8'
# 或者别名一下
alias grep='grep --color=auto'
```
8. 使用 -r 参数来实现递归的搜索目录
```shell
grep -r "ramesh" *
```
9. 取反搜索结果
```shell
grep -v "go" demo_text  # 显示哪些不包含 go 子串的行
```
10. 取反（多个）指定模式的匹配结果
```shell
grep -v -e "pattern1" -e "pattern2" filename # 显示不符合pattern1和pattern2的结果的数据
```
11. 计算出命中匹配的总行数
```shell
grep -c "pattern" filename # 6
```
12. 用 -l 只显示匹配命中的文件名称，而不显示具体匹配的内容。
13. 只显示匹配中的字符串，而不是一行。
```shell
$ grep -o "is.*line" demo_file  # 只显示 is 和 line 之间的字符串
```
14. 显示匹配的字符串位置。该位置是相对于整个文件的字节位置，不是行数
```shell
grep -o -b "pattern" file
```
15. 使用 -n 显示匹配的字符串在文件中的行数。
```shell
grep -n "go" demo_text
```
