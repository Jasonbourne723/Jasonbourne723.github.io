---
title: 回溯算法
date: 2025-09-02 10:12:00 +0800
categories: [数据结构与算法]
toc: true
tags: [数据结构与算法]
---

## 回溯算法

核心思想：回溯法是一种通过探索所有可能的候选解来找出所有解的算法。如果候选解被确认不是一个解（或者至少不是最后一个解），回溯算法会通过撤销（回溯） 上一步或几步的操作，丢弃该候选解，并尝试其他可能的候选解。

它是一种深度优先搜索策略的运用。

## 为什么需要回溯算法？

很多问题无法用简单的循环嵌套来解决，特别是当问题的规模（大小）是动态的或需要穷举所有排列/组合时。

### 典型问题：

- 组合问题：N个数里面按一定规则找出k个数的集合（不强调顺序）

    - [1,2,3,4] 中找出所有大小为2的组合：[1,2], [1,3], [1,4], [2,3], [2,4], [3,4]

- 切割问题：一个字符串按一定规则有几种切割方式

    - 分割回文串："aab" -> ["a","a","b"], ["aa","b"]

- 子集问题：一个N个数的集合里有多少符合条件的子集

    - [1,2,3] 的所有子集：[], [1], [2], [3], [1,2], [1,3], [2,3], [1,2,3]

- 排列问题：N个数按一定规则全排列，有几种排列方式（强调顺序）

    - [1,2,3] 的全排列：[1,2,3], [1,3,2], [2,1,3], [2,3,1], [3,1,2], [3,2,1]

- 棋盘问题：N皇后，解数独等

这些问题如果用手动写循环，层数不确定，代码会非常复杂甚至无法编写。回溯算法通过递归天然地解决了循环层数的问题。

##  理解回溯法的核心：递归与回溯

回溯法通常用递归来实现，递归的层数构成了问题的“深度”，而每一层的尝试构成了“广度”。回溯法的过程可以抽象地理解为一棵N叉树的遍历（决策树）。

- 树的宽度：表示问题的大小，即每个节点有多少种选择。
- 树的深度：表示递归的深度，即问题的条件（如组合大小k）。

模板三部曲：

- 做出选择：在当前步骤，尝试一个可用的选项。
- 递归深入：基于当前选择，继续向下一步探索。
- 撤销选择：当递归返回（无论成功与否），撤销步骤1的选择，回到之前的状态，以便进行下一个选项的尝试。

这一步“撤销选择”就是“回溯”的灵魂所在。

## 经典题型

### 39. 组合总和

题目：[组合总和](https://leetcode.cn/problems/combination-sum/description/?envType=problem-list-v2&envId=backtracking)

#### 解

```go
func combinationSum(candidates []int, target int) [][]int {
    if len(candidates) == 0 {
        return [][]int{}
    }
    var r [][]int
    var sum int
    var p []int

    var backtrack func(int )
    backtrack = func(index int ) {
        if sum == target {
            t := make([]int,len(p))
            copy(t,p)
            r = append(r,t)
            return
        }
        if sum > target {
            return
        }
        for i:=index;i<len(candidates);i++ {
            p = append(p,candidates[i])
            sum+=candidates[i]
            backtrack(i)
            sum -= candidates[i]
            p = p[:len(p)-1]
        }
    }
    backtrack(0)
    return r
}
```

### 子集

题目：[子集](https://leetcode.cn/problems/subsets/description/?envType=problem-list-v2&envId=backtracking)

#### 解

```go
func subsets(nums []int) [][]int {
	result := [][]int{}
	var path []int
	
	var backtrack func(start int)
	backtrack = func(start int) {
		
		temp:=make([]int,len(path))
        copy(temp,path)
		result = append(result,temp)
		
		for i:=start;i<len(nums);i++ {
			path = append(path,nums[i])
			backtrack(i+1)
			path = path[:len(path)-1]
		}
	}
	backtrack(0)
	return result
}
```

### 切割

题目：[分割回文串](https://leetcode.cn/problems/palindrome-partitioning/?envType=problem-list-v2&envId=backtracking)

```go
func partition(s string) [][]string {
	r := [][]string{}
	var p []string

	var backtrack func(int)

	backtrack = func(index int) {
		if index == len(s) {
			t := make([]string, len(p))
			copy(t, p)
			r = append(r, t)
			return
		}

		for i := index; i < len(s); i++ {
			if isPalindrome(s[index : i+1]) {
				p = append(p, s[index:i+1])
				backtrack(i + 1)
				p = p[:len(p)-1]
			}
		}
	}
	backtrack(0)
	return r
}

func isPalindrome(s string) bool {
	if len(s) == 0 {
		return false
	}
	for i := 0; i < len(s)/2; i++ {
		if s[i] != s[len(s)-i-1] {
			return false
		}
	}
	return true
}
```

### 排列

题目：[全排列Ⅱ](https://leetcode.cn/problems/permutations-ii/description/?envType=problem-list-v2&envId=backtracking)

```go
func permuteUnique(nums []int) [][]int {
    result := [][]int{}
    p := []int{}
    used := make( []int,len(nums))
    
    sort.Ints(nums)

    var backtrack func()
    backtrack = func() {
        if len(p) == len(nums) {
            temp := make([]int, len(p))
            copy(temp, p)
            result = append(result, temp)
        }
        for i := 0; i < len(nums); i++ {
            if used[i] == 1 {
                continue
            } 
            if i > 0 && nums[i] == nums[i-1] && used[i-1] == 0 {
                continue
            }
            used[i] = 1
            p = append(p,nums[i])
            backtrack()
            p = p[:len(p)-1]
            used[i] = 0
        }
    }
    backtrack()
    return result
}
```

### 棋盘

题目：[N皇后](https://leetcode.cn/problems/n-queens/description/?envType=problem-list-v2&envId=backtracking)

```go
func solveNQueens(n int) [][]string {
	var r [][]string
	path := make([][]byte, n)
	x := make([]byte, n)
	y := make([]byte, n)
	ex := make([][2]int, n)
	var q int
	for i := 0; i < n; i++ {
		bs := make([]byte, n)
		for j := 0; j < n; j++ {
			bs[j] = '.'
		}
		path[i] = bs
	}
	var backtrack func(int)

	backtrack = func(i int) {
		if q == n {
			t := make([]string, n)
			for index, item := range path {
				t[index] = string(item)
			}
			r = append(r, t)
			return
		}

	loop:
		for j := 0; j < n; j++ {
			if i >= n {
				break
			}
			if x[i] == '1' {
				break
			}
			if y[j] == '1' {
				continue
			}

			if q != 0 {
				for k := 0; k < q; k++ {
					a := ex[k][0] - i
					b := ex[k][1] - j

					if a == b || a+b == 0 {
						continue loop
					}
				}
			}

			x[i] = '1'
			y[j] = '1'
			path[i][j] = 'Q'
			ex[q] = [2]int{i, j}
			q++
			backtrack(i + 1)
			path[i][j] = '.'
			x[i] = '0'
			y[j] = '0'
			q--
		}
	}

	for i := 0; i < n; i++ {
		backtrack(i)
	}
	return r}

```