---
title: 限流
date: 2023-12-16 09:12:00 +0800
categories: [1.架构设计]
tags: []
---

## 定义

限流是指在单位时间内限制接口的请求数量。其主要作用有两个：

1. **保护服务的处理能力**：避免因流量洪峰导致系统超载或崩溃。
2. **防范恶意调用**：防止人为或恶意的频繁请求耗尽系统资源。


## 限流位置

### 1. 客户端

在客户端或前端直接限制用户的请求频率。例如，用户提交表单时设置按钮的防重复点击，或通过前端代码限制调用频次。这样可以有效降低无意义的请求传递到后端。

### 2. 服务端

服务端限流是在后端对请求流量进行控制，通常分为以下两种方式：

#### (1) 网关层

通过 API 网关对流量进行统一管理和控制，集中式处理限流规则。网关的优势在于它可以集中管理所有微服务的流量，降低对服务本身的侵入性。

#### (2) 服务自集成

将限流逻辑集成到服务本身，每个服务根据自身的特性独立实现限流规则。这种方式灵活，但增加了服务的复杂性。


## 限流对象

### 1. 用户

针对单个用户的请求数量进行限制，防止其频繁调用接口。例如，某个用户每分钟最多只能发送 10 个请求。

### 2. IP 地址

限制来自单个 IP 地址的请求数量，防止某些 IP 通过批量调用接口引发资源占用。例如，限制每个 IP 每秒最多发起 100 个请求。

### 3. 全局流量

针对所有请求的总量进行限制，以保护系统整体的稳定性。比如，限制系统每秒处理的总请求数为 10,000 个。


## 限流算法的实现

### 1. 固定窗口算法

将时间划分为固定的窗口（如 1 秒或 1 分钟），在每个时间窗口内记录请求的数量。一旦达到限流阈值，后续请求会被直接拒绝。此算法实现简单，但在窗口切换时可能出现短时间内的流量激增问题。

```go
package main

import (
	"sync"
	"time"
)

type FixedWindowLimiter struct {
	mu         sync.Mutex
	limit      int
	interval   time.Duration
	requests   int
	windowStart time.Time
}

func NewFixedWindowLimiter(limit int, interval time.Duration) *FixedWindowLimiter {
	return &FixedWindowLimiter{
		limit:      limit,
		interval:   interval,
		windowStart: time.Now(),
	}
}

func (fw *FixedWindowLimiter) Allow() bool {
	fw.mu.Lock()
	defer fw.mu.Unlock()

	now := time.Now()
	if now.Sub(fw.windowStart) >= fw.interval {
		// Reset the window
		fw.requests = 0
		fw.windowStart = now
	}

	if fw.requests < fw.limit {
		fw.requests++
		return true
	}
	return false
}
```

### 2. 滑动窗口算法

滑动窗口通过更精细的时间粒度来记录请求数量。它按照滑动的方式统计最近时间段内的请求总数，可以更平滑地控制流量并避免固定窗口算法中的流量激增。

```go
package main

import (
	"sync"
	"time"
)

type SlidingWindowLimiter struct {
	mu        sync.Mutex
	limit     int           // 请求限制
	interval  time.Duration // 时间窗口大小
	buckets   map[int64]int // 时间桶，key 为时间段，value 为请求数
}

func NewSlidingWindowLimiter(limit int, interval time.Duration) *SlidingWindowLimiter {
	return &SlidingWindowLimiter{
		limit:    limit,
		interval: interval,
		buckets:  make(map[int64]int),
	}
}

func (sw *SlidingWindowLimiter) cleanUp(now int64) {
	// 删除超过窗口的旧桶
	for timestamp := range sw.buckets {
		if timestamp < now-int64(sw.interval.Seconds()) {
			delete(sw.buckets, timestamp)
		}
	}
}

func (sw *SlidingWindowLimiter) Allow() bool {
	sw.mu.Lock()
	defer sw.mu.Unlock()

	now := time.Now().Unix() // 当前秒时间戳
	sw.cleanUp(now)          // 清理过期的时间桶

	// 统计窗口内的请求总数
	var count int
	for _, reqCount := range sw.buckets {
		count += reqCount
	}

	if count < sw.limit {
		// 当前请求被允许，计入当前时间段
		sw.buckets[now]++
		return true
	}
	return false
}


```

### 3. 漏桶算法

漏桶算法将请求放入一个固定大小的漏桶中，以恒定速率处理请求。当请求到达速率大于漏桶的漏水速率时，多余的请求会被丢弃。这种算法能够平滑流量，但不允许突发流量。

```go
package main

import (
	"sync"
	"time"
)

type LeakyBucketLimiter struct {
	mu         sync.Mutex
	limit      int
	interval   time.Duration
	lastLeak   time.Time
	currentWater int
}

func NewLeakyBucketLimiter(limit int, interval time.Duration) *LeakyBucketLimiter {
	return &LeakyBucketLimiter{
		limit:    limit,
		interval: interval,
		lastLeak: time.Now(),
	}
}

func (lb *LeakyBucketLimiter) Allow() bool {
	lb.mu.Lock()
	defer lb.mu.Unlock()

	now := time.Now()
	// Leak water
	leakAmount := int(now.Sub(lb.lastLeak) / lb.interval)
	if leakAmount > 0 {
		lb.currentWater -= leakAmount
		if lb.currentWater < 0 {
			lb.currentWater = 0
		}
		lb.lastLeak = now
	}

	if lb.currentWater < lb.limit {
		lb.currentWater++
		return true
	}
	return false
}
```

### 4. 令牌桶算法

令牌桶算法按照一定的速率生成令牌，请求必须获得令牌才能被处理。令牌桶允许短时间的突发流量，只要桶内有足够的令牌。

```go
package main

import (
	"sync"
	"time"
)

type TokenBucketLimiter struct {
	mu           sync.Mutex
	capacity     int
	tokenRate    int
	currentTokens int
	lastRefill   time.Time
}

func NewTokenBucketLimiter(capacity int, tokenRate int) *TokenBucketLimiter {
	return &TokenBucketLimiter{
		capacity:     capacity,
		tokenRate:    tokenRate,
		currentTokens: capacity,
		lastRefill:   time.Now(),
	}
}

func (tb *TokenBucketLimiter) Allow() bool {
	tb.mu.Lock()
	defer tb.mu.Unlock()

	now := time.Now()
	elapsed := now.Sub(tb.lastRefill).Seconds()

	// Add new tokens
	newTokens := int(elapsed * float64(tb.tokenRate))
	tb.currentTokens += newTokens
	if tb.currentTokens > tb.capacity {
		tb.currentTokens = tb.capacity
	}
	tb.lastRefill = now

	if tb.currentTokens > 0 {
		tb.currentTokens--
		return true
	}
	return false
}
```

## 总结

限流是保障系统稳定性和资源公平使用的重要手段。通过选择合适的限流位置（客户端或服务端）、对象（用户、IP 或全局流量）以及算法（固定窗口、滑动窗口、漏桶、令牌桶），可以在不同场景下满足系统的需求。同时，在限流的实现过程中，还需结合业务特性，综合考虑流量模式、性能开销和用户体验。


