---
title: 几个简单的双指针算法题
date: 2025-08-10 10:12:00 +0800
categories: [数据结构与算法]
toc: true
tags: [数据结构与算法]
---

## 27. 移除元素

给你一个数组 nums 和一个值 val，你需要 原地 移除所有数值等于 val 的元素。元素的顺序可能发生改变。然后返回 nums 中与 val 不同的元素的数量。

假设 nums 中不等于 val 的元素数量为 k，要通过此题，您需要执行以下操作：

- 更改 nums 数组，使 nums 的前 k 个元素包含不等于 val 的元素。nums 的其余元素和 nums 的大小并不重要。
- 返回 k。

### 示例 1：

- 输入：nums = [3,2,2,3], val = 3
- 输出：2, nums = [2,2,_,_]
- 解释：你的函数函数应该返回 k = 2, 并且 nums 中的前两个元素均为 2。
你在返回的 k 个元素之外留下了什么并不重要（因此它们并不计入评测）。

### 解

因为题目没有要求数组元素保持原相对顺序，所以可以反向遍历数组，同时再维护一个标记有效元素坐标的指针 end，初始为 数组长度-1，当出现不等于 val 的元素时，与end指向的的元素调换位置，同时将end向前移动。
最终end会移动到自身+前面元素都是不等于val元素的位置，那么end+1就是不等于val元素的数量了。

```go
func removeElement(nums []int, val int) int {
    end := len(nums) -1 
    for i:=end;i>=0;i--{
        if nums[i] == val {
            nums[i],nums[end] = nums[end],nums[i]
            end -= 1
        }
    }
    return end+1
}
```
## 26. 删除有序数组中的重复项

给你一个 非严格递增排列 的数组 nums ，请你 原地 删除重复出现的元素，使每个元素 只出现一次 ，返回删除后数组的新长度。元素的 相对顺序 应该保持 一致 。然后返回 nums 中唯一元素的个数。

考虑 nums 的唯一元素的数量为 k ，你需要做以下事情确保你的题解可以被通过：

- 更改数组 nums ，使 nums 的前 k 个元素包含唯一元素，并按照它们最初在 nums 中出现的顺序排列。nums 的其余元素与 nums 的大小不重要。
- 返回 k 。
- 1 <= nums.length <= 3 * 104

### 示例 1：

- 输入：nums = [1,1,2]
- 输出：2, nums = [1,2,_]
- 解释：函数应该返回新的长度 2 ，并且原数组 nums 的前两个元素被修改为 1, 2 。不需要考虑数组中超出新长度后面的元素

### 解

维护一个无重复元素下标的指针c，默认为1.
从下标1开始正向遍历数组，如果元素与c-1指向元素不同，则让该元素与c指向的元素调换位置，同时c向后移动一位。

```go
func removeDuplicates(nums []int) int {

   c := 1
   for  i := 1;i<len(nums);i++ {
        if nums[i] != nums[c-1] {
            nums[c] = nums[i]
            c += 1
        }
   }
   return c
   
}
```

## 283. 移动零

给定一个数组 nums，编写一个函数将所有 0 移动到数组的末尾，同时保持非零元素的相对顺序。

请注意 ，必须在不复制数组的情况下原地对数组进行操作。

- 1 <= nums.length <= 104

### 示例 1:

- 输入: nums = [0,1,0,3,12]
- 输出: [1,3,12,0,0]

### 解

```go
func moveZeroes(nums []int)  {
    
    z_index := -1
    
    for i := 0 ; i < len(nums);i++ {
        if nums[i] != 0 {
            if z_index != -1 {
                nums[i],nums[z_index] = nums[z_index],nums[i]
                z_index += 1
            }
        } else{
                if z_index == -1 {
                    z_index = i
                }
            }      
    }

}
```
