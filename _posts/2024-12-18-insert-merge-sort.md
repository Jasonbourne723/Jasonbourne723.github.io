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

## 3.快速排序

快速排序是一种高效的排序算法，它采用了分治法的策略。它的基本思想是：选择一个基准元素，通常是数组的第一个或最后一个元素，然后将数组分为两部分，使得左边的所有元素都不大于基准元素，右边的所有元素都不小于基准元素。接着，对这两部分继续进行快速排序，直到整个序列有序。

快速排序的平均时间复杂度为 O(nlogn)，在最好的情况下也是 O(nlogn)，但在最坏的情况下会退化为 O(n^2)。尽管如此，由于它的平均性能非常好，它通常比其他 O(nlogn) 算法更快，因此在实际应用中非常受欢迎。

```go
func QuickSort(array []int) []int {
	if len(array) < 2 {
		return array
	}
	left, right := 0, len(array)-1
	pivot := rand.Int() % len(array)
	array[pivot], array[right] = array[right], array[pivot]
	for i := range array {
		if array[i] < array[right] {
			array[i], array[left] = array[left], array[i]
			left++
		}
	}
	array[left], array[right] = array[right], array[left]
	QuickSort(array[:left])
	QuickSort(array[left+1:])
	return array
}
```

## 4.基数排序

数组中都是正整数，并且其中最大的元素是一个相对较小的数，可以采用基数排序。

```go
func BaseSort(array []int) []int {

	temp := [5]int{}

	for _, item := range array {
		temp[item]++
	}

	i := 0
	for j := 0; j < 5; j++ {
		for temp[j] > 0 {
			array[i] = j
			i++
			temp[j]--
		}
	}
	return array
}
```