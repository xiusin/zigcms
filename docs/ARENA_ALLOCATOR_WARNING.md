# ⚠️ Arena Allocator 使用警告

## 🚨 重要警告

**Arena 会导致内存累积，直到 deinit 才释放所有内存！**

如果在长期运行的循环中使用 Arena，**会导致内存泄漏**！

## ❌ 错误示例（内存泄漏）

```zig
// ❌ 永远不要这样做！
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();  // 只有程序退出才执行
    
    // Web 服务器无限循环
    while (true) {
        // 每次请求
        var builder = QueryBuilder.init(arena.allocator(), "users");
        // 内存累积！累积！累积！
        
        // 1000 次请求后：内存 +2MB
        // 10000 次请求后：内存 +20MB
        // 100000 次请求后：内存 +200MB
        // ... 最终 OOM（内存耗尽）
    }
}
```

**后果**：应用内存持续增长，最终崩溃！

## ❌ 另一个错误示例

```zig
// ❌ 后台任务使用 Arena
pub fn backgroundTask() !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();  // 任务永不结束，永不释放
    
    while (true) {
        std.time.sleep(60 * std.time.ns_per_s);
        
        // 每分钟执行一次
        var builder = QueryBuilder.init(arena.allocator(), "tasks");
        // 每次 +2KB
        
        // 1 小时后：+120KB
        // 1 天后：+2.8MB
        // 1 周后：+20MB
        // 1 个月后：+86MB
        // ... 内存持续增长！
    }
}
```

## ✅ 正确示例

### 方案 1：使用 defer（推荐）

```zig
// ✅ 每次请求独立管理内存
pub fn handleRequest(allocator: Allocator) !void {
    var builder = QueryBuilder.init(allocator, "users");
    defer builder.deinit();  // 请求结束立即释放
    
    _ = builder.where("age", ">", 18).limit(10);
    
    // 函数结束，内存自动释放
    // 内存使用：稳定在 2KB
}

// ✅ 后台任务每次迭代独立管理
pub fn backgroundTask(allocator: Allocator) !void {
    while (true) {
        std.time.sleep(60 * std.time.ns_per_s);
        
        // 使用代码块隔离作用域
        {
            var builder = QueryBuilder.init(allocator, "tasks");
            defer builder.deinit();  // 迭代结束释放
            
            // 执行任务...
        }  // builder 在这里释放
        
        // 内存使用：稳定在 2KB（不会累积）
    }
}
```

### 方案 2：Arena 用于短期批量操作

```zig
// ✅ 单次函数调用，函数结束立即释放
pub fn generateReport(allocator: Allocator) !Report {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();  // 函数结束立即释放
    
    const a = arena.allocator();
    
    // 批量查询 5-10 次
    var q1 = QueryBuilder.init(a, "users");
    var q2 = QueryBuilder.init(a, "posts");
    var q3 = QueryBuilder.init(a, "comments");
    
    // 处理数据...
    
    return report;  // arena.deinit() 自动执行
}

// ✅ 分批处理大数据
pub fn processBigData(allocator: Allocator, items: []Item) !void {
    const batch_size = 1000;
    
    var i: usize = 0;
    while (i < items.len) {
        // 每 1000 条创建新 arena
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();  // 批次结束释放
        
        const a = arena.allocator();
        const end = @min(i + batch_size, items.len);
        
        // 处理这一批
        for (items[i..end]) |item| {
            var q = QueryBuilder.init(a, "items");
            // ...
        }
        
        i = end;
        // arena.deinit() 释放这批的内存
        // 内存不会累积到下一批
    }
}
```

## 📊 内存使用对比

### 场景：循环执行 10,000 次查询

#### ❌ 错误方式（Arena 在循环外）

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

for (0..10000) |_| {
    var q = QueryBuilder.init(arena.allocator(), "users");
    // 每次查询 +2KB
}

// 内存使用：20MB（持续累积）
// 如果是 100,000 次：200MB
// 如果是 1,000,000 次：2GB -> OOM!
```

#### ✅ 正确方式（defer）

```zig
for (0..10000) |_| {
    var q = QueryBuilder.init(allocator, "users");
    defer q.deinit();
    // 每次查询 +2KB，然后 -2KB
}

// 内存使用：2KB（稳定）
// 无论执行多少次，内存都是 2KB
```

#### ✅ 正确方式（Arena 分批）

```zig
var i: usize = 0;
while (i < 10000) {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    
    const a = arena.allocator();
    
    // 每 100 次创建新 arena
    for (0..100) |_| {
        var q = QueryBuilder.init(a, "users");
        // 100 次查询 +200KB
    }
    
    i += 100;
    // arena.deinit() 释放 200KB
}

// 内存使用：200KB（分批稳定）
// 峰值：200KB，不会累积
```

## 🎯 使用规则

### ✅ 可以使用 Arena 的场景

1. **单次函数调用**
   ```zig
   pub fn doSomething() !void {
       var arena = std.heap.ArenaAllocator.init(allocator);
       defer arena.deinit();  // 函数结束立即释放
       // ✅ 安全
   }
   ```

2. **测试代码**
   ```zig
   test "something" {
       var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
       defer arena.deinit();  // 测试结束释放
       // ✅ 安全
   }
   ```

3. **分批处理**（每批创建新 Arena）
   ```zig
   while (has_more_data) {
       var arena = std.heap.ArenaAllocator.init(allocator);
       defer arena.deinit();  // 每批结束释放
       // ✅ 安全
   }
   ```

### ❌ 不能使用 Arena 的场景

1. **无限循环**
   ```zig
   var arena = std.heap.ArenaAllocator.init(allocator);
   while (true) { ... }  // ❌ 内存泄漏
   ```

2. **长期运行的服务**
   ```zig
   var arena = std.heap.ArenaAllocator.init(allocator);
   server.start();  // ❌ 内存泄漏
   ```

3. **循环中分配**（Arena 在循环外）
   ```zig
   var arena = std.heap.ArenaAllocator.init(allocator);
   for (0..10000) { ... }  // ❌ 内存累积
   ```

4. **请求处理**（Arena 跨多个请求）
   ```zig
   var arena = std.heap.ArenaAllocator.init(allocator);
   while (true) {
       handle_request(arena.allocator());  // ❌ 内存泄漏
   }
   ```

## 💡 最佳实践

### 规则 1：默认使用 defer

```zig
// 99% 的情况使用这个
var builder = QueryBuilder.init(allocator, "users");
defer builder.deinit();
```

**简单、安全、内存稳定！**

### 规则 2：Arena 只用于短期批量操作

```zig
// 只在这种情况下使用 Arena：
// 1. 单次函数调用
// 2. 立即释放（defer 在函数末尾）
// 3. 批量操作（5-1000 次分配）

pub fn batchInsert(items: []Item) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();  // ✅ 函数结束立即释放
    
    // 批量操作...
}
```

### 规则 3：循环中永远不要在外部创建 Arena

```zig
// ❌ 错误
var arena = std.heap.ArenaAllocator.init(allocator);
for (items) |item| {
    process(arena.allocator(), item);  // 累积！
}

// ✅ 正确（方案 A）
for (items) |item| {
    var builder = QueryBuilder.init(allocator, item);
    defer builder.deinit();  // 每次独立
}

// ✅ 正确（方案 B）
for (items) |item| {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();  // 每次迭代独立
    process(arena.allocator(), item);
}
```

## 🔍 如何检测内存泄漏

### 使用 GeneralPurposeAllocator

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("⚠️ 内存泄漏检测到!\n", .{});
        }
    }
    
    const allocator = gpa.allocator();
    
    // 你的代码...
}
```

### 监控内存使用

```zig
// 在长期运行的服务中定期检查
while (true) {
    const start_mem = getCurrentMemoryUsage();
    
    // 处理请求...
    
    const end_mem = getCurrentMemoryUsage();
    if (end_mem > start_mem + threshold) {
        std.debug.print("⚠️ 内存增长: {d} bytes\n", .{end_mem - start_mem});
    }
}
```

## 📝 总结

### 关键要点

1. **Arena 会累积内存**，直到 deinit 才释放
2. **长期运行的服务永远不要使用 Arena**
3. **循环中的 Arena 必须在循环内部创建和释放**
4. **默认使用 defer 模式**，简单且安全
5. **Arena 只用于短期的批量操作**

### 记住这句话

> "如果你不确定是否该用 Arena，那就不要用。用 defer！"

### defer 是你的朋友

```zig
// 这是 Zig 的惯用法，也是最安全的方法
var builder = QueryBuilder.init(allocator, "users");
defer builder.deinit();

// 简单、安全、内存稳定
// 99% 的情况下这就够了！
```

---

**结论**：Arena 是一个强大的工具，但如果误用会导致内存泄漏。对于日常开发，**defer 模式才是最佳选择**。
