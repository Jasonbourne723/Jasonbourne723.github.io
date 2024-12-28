---
title: 数据结构与算法：排序算法
date: 2024-12-28 10:12:00 +0800
categories: [数据结构与算法]
tags: [数据结构与算法]
---

## 1. 插入排序

每次循环迭代都保证一个已排序前缀

时间复杂度
- 最优:O(n),
- 最差:O(n^2)
- 平均:O(n^2)

```go
func InsertSort(array []int) []int {

	for i := 0; i < len(array); i++ {
		j := i
		for j > 0 && array[j] < array[j-1] {
			array[j], array[j-1] = array[j-1], array[j]
			j--
		}
	}
	return array
}
```

## 2. 归并排序

基于分治法的原理，将一个大问题分解成小问题解决，然后将小问题的解决结果合并起来。在归并排序中，一个数组被递归地分割成两半，直到每个小部分只有一个元素，然后这些元素被合并成一个有序的数组。

- 时间复杂度：O(nlgn)
- 空间复杂度：O(n)

```go
func MergeSort(array []int) []int {
	if len(array) < 2 {
		return array
	}
	mid := len(array) / 2
	return merge(MergeSort(array[:mid]), MergeSort(array[mid:]))
}

func merge(left, right []int) []int {

	n := len(left)
	m := len(right)
	i, j := 0, 0
	result := make([]int, 0, n+m)

	for i < n || j < m {
		if i == n || (j < m && left[i] > right[j]) {
			result = append(result, right[j])
			j++
		} else {
			result = append(result, left[i])
			i++
		}
	}
	return result
}
```