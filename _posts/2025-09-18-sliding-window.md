---
title: 数据结构与算法：滑动窗口
date: 2025-09-18 10:01:00 +0800
categories: [数据结构与算法]
tags: [数据结构与算法]
---

## 定长窗口

### 1456. 定长子串中元音的最大数目

给你字符串 s 和整数 k 。

请返回字符串 s 中长度为 k 的单个子字符串中可能包含的最大元音字母数。

英文中的 元音字母 为（a, e, i, o, u）。

#### 示例 1：

- 输入：s = "abciiidef", k = 3
- 输出：3
- 解释：子字符串 "iii" 包含 3 个元音字母。

#### 题解 

```go
func maxVowels(s string, k int) int {
    var t int
    var ans int
	// 初始化第一个窗口
    for i:=0;i<k;i++ {
        t += isVowel(s[i])
    }
    ans = t

    for i:=k;i<len(s);i++ {
		// 窗口左右左边同时向右移动1位
        t += isVowel(s[i])
        t -= isVowel(s[i-k])
        ans = max(ans,t)
    }

    return ans
}

func isVowel(x byte) int {
    if x == 'a' || x == 'e' || x== 'i' || x == 'o' || x== 'u' {
        return 1
    }
    return 0
}
```

## 不定长窗口

### 水果成蓝

你正在探访一家农场，农场从左到右种植了一排果树。这些树用一个整数数组 fruits 表示，其中 fruits[i] 是第 i 棵树上的水果 种类 。

你想要尽可能多地收集水果。然而，农场的主人设定了一些严格的规矩，你必须按照要求采摘水果：

你只有 两个 篮子，并且每个篮子只能装 单一类型 的水果。每个篮子能够装的水果总量没有限制。
你可以选择任意一棵树开始采摘，你必须从 每棵 树（包括开始采摘的树）上 恰好摘一个水果 。采摘的水果应当符合篮子中的水果类型。每采摘一次，你将会向右移动到下一棵树，并继续采摘。
一旦你走到某棵树前，但水果不符合篮子的水果类型，那么就必须停止采摘。
给你一个整数数组 fruits ，返回你可以收集的水果的 最大 数目。

#### 示例 1：

- 输入：fruits = [1,2,1]
- 输出：3
- 解释：可以采摘全部 3 棵树。

#### 题解

```go
func totalFruit(fruits []int) int {
    var ans int
    var l int
    m := map[int]int{}
    for r,item := range fruits {
        m[item]++
        for len(m) > 2 {
			// 不符合条件时，窗口左指针向右移动
            m[fruits[l]]--
            if m[fruits[l]] == 0 {
                delete(m,fruits[l])
            }
            l++
        }
        ans = max(ans,r-l+1)
    }
    return ans
}
```
