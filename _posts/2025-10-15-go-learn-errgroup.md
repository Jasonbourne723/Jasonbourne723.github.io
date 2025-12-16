---
layout: post
title: Go 语言学习：errgroup
date: 2025-10-15 01:12:00 +0800
categories: [Go]
tags: [golang, errgroup, 并发, 错误处理]
---

## 什么是 errgroup

`errgroup` 是 Go 官方扩展库 `golang.org/x/sync/errgroup` 提供的一个并发原语，用于简化一组 goroutine 的错误处理和同步。它在 `sync.WaitGroup` 的基础上增加了错误传播和上下文取消的能力。

## 核心特性

1. **并发执行多个任务**：可以启动多个 goroutine 并发执行
2. **错误收集**：任何一个 goroutine 返回错误，都会被捕获
3. **快速失败**：第一个错误发生时，可以通过 context 取消其他 goroutine
4. **等待所有任务完成**：自动等待所有 goroutine 执行完毕

## 基本使用

### 安装

```bash
go get golang.org/x/sync/errgroup
```

### 简单示例

```go
package main

import (
    "context"
    "fmt"
    "golang.org/x/sync/errgroup"
    "time"
)

func main() {
    g := new(errgroup.Group)
    
    // 启动多个并发任务
    for i := 0; i < 5; i++ {
        i := i // 避免闭包问题
        g.Go(func() error {
            time.Sleep(time.Second)
            fmt.Printf("任务 %d 完成\n", i)
            return nil
        })
    }
    
    // 等待所有任务完成
    if err := g.Wait(); err != nil {
        fmt.Printf("发生错误: %v\n", err)
    }
}
```

## 带 Context 的使用

使用 `WithContext` 可以实现错误时自动取消其他任务：

```go
package main

import (
    "context"
    "errors"
    "fmt"
    "golang.org/x/sync/errgroup"
    "time"
)

func main() {
    g, ctx := errgroup.WithContext(context.Background())
    
    // 任务1：会失败
    g.Go(func() error {
        time.Sleep(2 * time.Second)
        return errors.New("任务1失败")
    })
    
    // 任务2：会被取消
    g.Go(func() error {
        select {
        case <-time.After(5 * time.Second):
            fmt.Println("任务2完成")
            return nil
        case <-ctx.Done():
            fmt.Println("任务2被取消")
            return ctx.Err()
        }
    })
    
    // 任务3：会被取消
    g.Go(func() error {
        select {
        case <-time.After(5 * time.Second):
            fmt.Println("任务3完成")
            return nil
        case <-ctx.Done():
            fmt.Println("任务3被取消")
            return ctx.Err()
        }
    })
    
    // Wait 返回第一个非 nil 的错误
    if err := g.Wait(); err != nil {
        fmt.Printf("错误: %v\n", err)
    }
}
```

## 限制并发数量

`errgroup` 本身不支持限制并发数，但可以通过 channel 实现：

```go
package main

import (
    "context"
    "fmt"
    "golang.org/x/sync/errgroup"
    "time"
)

func main() {
    g, ctx := errgroup.WithContext(context.Background())
    
    // 使用 channel 限制并发数为 3
    maxConcurrent := 3
    semaphore := make(chan struct{}, maxConcurrent)
    
    tasks := 10
    for i := 0; i < tasks; i++ {
        i := i
        g.Go(func() error {
            // 获取信号量
            select {
            case semaphore <- struct{}{}:
            case <-ctx.Done():
                return ctx.Err()
            }
            defer func() { <-semaphore }() // 释放信号量
            
            // 执行任务
            time.Sleep(time.Second)
            fmt.Printf("任务 %d 完成\n", i)
            return nil
        })
    }
    
    if err := g.Wait(); err != nil {
        fmt.Printf("错误: %v\n", err)
    }
}
```

## 使用 SetLimit (Go 1.20+)

Go 1.20 版本后，`errgroup` 新增了 `SetLimit` 方法来限制并发：

```go
package main

import (
    "fmt"
    "golang.org/x/sync/errgroup"
    "time"
)

func main() {
    g := new(errgroup.Group)
    g.SetLimit(3) // 限制最多 3 个并发
    
    for i := 0; i < 10; i++ {
        i := i
        g.Go(func() error {
            fmt.Printf("任务 %d 开始\n", i)
            time.Sleep(time.Second)
            fmt.Printf("任务 %d 完成\n", i)
            return nil
        })
    }
    
    if err := g.Wait(); err != nil {
        fmt.Printf("错误: %v\n", err)
    }
}
```

## 实际应用场景

### 1. 并发 HTTP 请求

```go
func fetchURLs(urls []string) error {
    g := new(errgroup.Group)
    
    for _, url := range urls {
        url := url
        g.Go(func() error {
            resp, err := http.Get(url)
            if err != nil {
                return err
            }
            defer resp.Body.Close()
            
            // 处理响应
            fmt.Printf("获取 %s: %s\n", url, resp.Status)
            return nil
        })
    }
    
    return g.Wait()
}
```

### 2. 并发数据库查询

```go
func queryMultipleTables(ctx context.Context, db *sql.DB) ([]User, []Order, error) {
    var users []User
    var orders []Order
    
    g, ctx := errgroup.WithContext(ctx)
    
    // 查询用户表
    g.Go(func() error {
        rows, err := db.QueryContext(ctx, "SELECT * FROM users")
        if err != nil {
            return err
        }
        defer rows.Close()
        
        // 扫描结果到 users
        return nil
    })
    
    // 查询订单表
    g.Go(func() error {
        rows, err := db.QueryContext(ctx, "SELECT * FROM orders")
        if err != nil {
            return err
        }
        defer rows.Close()
        
        // 扫描结果到 orders
        return nil
    })
    
    if err := g.Wait(); err != nil {
        return nil, nil, err
    }
    
    return users, orders, nil
}
```

### 3. 并发文件处理

```go
func processFiles(files []string) error {
    g := new(errgroup.Group)
    g.SetLimit(5) // 限制同时处理 5 个文件
    
    for _, file := range files {
        file := file
        g.Go(func() error {
            data, err := os.ReadFile(file)
            if err != nil {
                return fmt.Errorf("读取文件 %s 失败: %w", file, err)
            }
            
            // 处理文件内容
            fmt.Printf("处理文件 %s, 大小: %d\n", file, len(data))
            return nil
        })
    }
    
    return g.Wait()
}
```

## errgroup vs sync.WaitGroup

| 特性 | errgroup | sync.WaitGroup |
|------|----------|----------------|
| 错误处理 | ✅ 支持 | ❌ 不支持 |
| Context 集成 | ✅ 支持 | ❌ 不支持 |
| 自动取消 | ✅ 支持 | ❌ 不支持 |
| 并发限制 | ✅ SetLimit | ❌ 需手动实现 |
| 使用复杂度 | 简单 | 需要手动管理 |

## 相关错误处理库

### 1. pkg/errors

提供错误包装和堆栈跟踪：

```go
import "github.com/pkg/errors"

func doSomething() error {
    err := someOperation()
    if err != nil {
        return errors.Wrap(err, "操作失败")
    }
    return nil
}
```

### 2. Go 1.13+ 标准库错误处理

```go
import (
    "errors"
    "fmt"
)

var ErrNotFound = errors.New("未找到")

func process() error {
    return fmt.Errorf("处理失败: %w", ErrNotFound)
}

func main() {
    err := process()
    if errors.Is(err, ErrNotFound) {
        fmt.Println("处理未找到错误")
    }
}
```

### 3. hashicorp/go-multierror

收集多个错误：

```go
import "github.com/hashicorp/go-multierror"

func validateData(data []string) error {
    var result error
    
    for _, item := range data {
        if err := validate(item); err != nil {
            result = multierror.Append(result, err)
        }
    }
    
    return result
}
```

## 最佳实践

1. **使用 WithContext**：需要取消功能时使用 `errgroup.WithContext`
2. **避免闭包陷阱**：循环中启动 goroutine 时，注意变量捕获
3. **限制并发数**：处理大量任务时使用 `SetLimit` 避免资源耗尽
4. **错误包装**：返回错误时添加上下文信息
5. **超时控制**：结合 `context.WithTimeout` 实现超时控制
6. **资源清理**：确保在 goroutine 中正确清理资源

## 注意事项

1. `Wait()` 只返回第一个非 nil 错误
2. 所有 goroutine 都会执行完毕，即使有错误发生
3. 使用 Context 可以实现快速失败，但需要 goroutine 主动检查
4. `SetLimit` 会阻塞 `Go()` 调用，直到有空闲槽位

## 总结

`errgroup` 是 Go 并发编程中非常实用的工具，它简化了并发任务的错误处理和同步。通过合理使用 `errgroup`，可以写出更简洁、更健壮的并发代码。

主要优势：
- 简化并发错误处理
- 自动同步等待
- 支持快速失败
- 代码更清晰易读

适用场景：
- 并发 API 调用
- 并发数据库查询
- 并发文件处理
- 任何需要并发执行且关心错误的场景

## 参考资料

- [errgroup 官方文档](https://pkg.go.dev/golang.org/x/sync/errgroup)
- [Go 并发模式](https://go.dev/blog/pipelines)
- [Go 错误处理最佳实践](https://go.dev/blog/error-handling-and-go)
