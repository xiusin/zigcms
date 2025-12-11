# ZigCMS 内存安全与资源管理指南

## 概述

本文档描述 ZigCMS 项目的内存管理策略、资源清理规范和最佳实践。

## 核心原则

### 1. 所有权明确
- **谁分配，谁释放**：资源的分配者负责释放
- **使用 errdefer**：在可能失败的初始化中使用 `errdefer` 确保部分初始化的资源被清理
- **defer 顺序**：资源释放顺序与分配顺序相反

### 2. 生命周期管理

```zig
// ✅ 正确示例
pub fn init(allocator: Allocator) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);  // 如果后续失败，清理已分配的内存
    
    self.* = .{
        .allocator = allocator,
        .data = try allocator.alloc(u8, 1024),
    };
    errdefer allocator.free(self.data);  // 如果后续失败，清理 data
    
    return self;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.data);  // 先释放内部资源
    self.allocator.destroy(self);     // 最后释放自身
}
```

### 3. 全局资源管理

全局资源必须：
1. 在程序启动时初始化
2. 在程序退出时清理
3. 使用互斥锁保护并发访问
4. 提供线程安全的访问接口

## 项目中的资源管理

### 1. 全局单例资源 (global.zig)

```zig
// 全局资源清理顺序（与初始化相反）
pub fn deinit() void {
    // 1. 插件系统（依赖服务管理器）
    if (_plugin_system) |ps| {
        ps.shutdown() catch {};
        _allocator.?.destroy(ps);
    }
    
    // 2. 服务管理器（依赖数据库）
    if (_service_manager) |sm| {
        sm.deinit();
        _allocator.?.destroy(sm);
    }
    
    // 3. 数据库连接
    if (_db) |db| {
        db.deinit();
        _allocator.?.destroy(db);
    }
    
    // 4. 日志器
    logger.deinitDefault();
    
    // 5. 配置
    config.deinit();
}
```

### 2. HTTP 控制器 (App.zig)

```zig
pub const App = struct {
    controllers: std.ArrayList(*anyopaque),  // 追踪所有控制器
    
    pub fn crud(self: *Self, comptime name: []const u8, comptime T: type) !void {
        const ctrl_ptr = try self.allocator.create(Controller);
        errdefer self.allocator.destroy(ctrl_ptr);
        
        // 追踪控制器以便清理
        try self.controllers.append(@ptrCast(ctrl_ptr));
    }
    
    pub fn deinit(self: *Self) void {
        // 清理所有控制器
        for (self.controllers.items) |ctrl| {
            self.allocator.destroy(ctrl);
        }
        self.controllers.deinit();
    }
};
```

### 3. 数据库连接池 (orm.zig)

连接池管理：
- 最小连接数：预创建
- 最大连接数：动态扩展
- 空闲超时：自动回收
- 连接验证：定期 ping

```zig
pub fn deinit(self: *ConnectionPool) void {
    self.closed = true;
    
    // 等待 keepalive 线程退出
    if (self.keepalive_thread) |thread| {
        thread.join();
    }
    
    // 关闭所有连接
    for (self.all_connections.items) |pooled| {
        pooled.conn.deinit();
        self.allocator.destroy(pooled);
    }
    
    self.all_connections.deinit(self.allocator);
    self.idle_connections.deinit(self.allocator);
}
```

## 常见内存泄漏场景

### 1. 忘记释放动态分配的内存

```zig
// ❌ 错误
pub fn process() !void {
    const data = try allocator.alloc(u8, 1024);
    // 忘记 defer allocator.free(data);
    if (someCondition) return error.Failed;  // 泄漏！
}

// ✅ 正确
pub fn process() !void {
    const data = try allocator.alloc(u8, 1024);
    defer allocator.free(data);  // 确保释放
    if (someCondition) return error.Failed;
}
```

### 2. 部分初始化失败

```zig
// ❌ 错误
pub fn init() !*Self {
    const self = try allocator.create(Self);
    self.field1 = try allocField1();  // 如果这里失败，self 泄漏
    self.field2 = try allocField2();
    return self;
}

// ✅ 正确
pub fn init() !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    
    self.field1 = try allocField1();
    errdefer freeField1(self.field1);
    
    self.field2 = try allocField2();
    return self;
}
```

### 3. 循环引用

```zig
// ❌ 避免循环引用
pub const Parent = struct {
    child: *Child,  // Parent 持有 Child
};

pub const Child = struct {
    parent: *Parent,  // Child 持有 Parent - 循环！
};

// ✅ 使用弱引用或单向引用
pub const Child = struct {
    parent: ?*Parent,  // 可选，由 Parent 管理生命周期
};
```

## 测试内存泄漏

### 使用 GeneralPurposeAllocator

```zig
test "no memory leaks" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try std.testing.expect(leaked == .ok);
    }
    
    const allocator = gpa.allocator();
    
    // 测试代码
    var obj = try MyStruct.init(allocator);
    defer obj.deinit();
}
```

### 使用 testing.allocator

```zig
test "with testing allocator" {
    const allocator = std.testing.allocator;
    
    var obj = try MyStruct.init(allocator);
    defer obj.deinit();
    
    // testing.allocator 会自动检测泄漏
}
```

## 最佳实践清单

- [ ] 每个 `create` 都有对应的 `destroy`
- [ ] 每个 `alloc` 都有对应的 `free`
- [ ] 使用 `defer` 确保资源释放
- [ ] 使用 `errdefer` 处理部分初始化
- [ ] 全局资源在 `deinit()` 中清理
- [ ] 测试中使用 `testing.allocator` 检测泄漏
- [ ] 文档化资源所有权
- [ ] 避免循环引用
- [ ] 使用 RAII 模式（Resource Acquisition Is Initialization）

## 代码审查要点

在代码审查时，重点检查：

1. **分配点**：每个 `allocator.create/alloc` 是否有对应的释放？
2. **错误路径**：错误返回时是否清理了已分配的资源？
3. **生命周期**：资源的生命周期是否明确？
4. **并发安全**：共享资源是否有适当的同步？
5. **测试覆盖**：是否有内存泄漏测试？

## 工具和命令

```bash
# 编译时启用内存安全检查
zig build -Doptimize=Debug

# 运行测试并检查内存泄漏
zig build test

# 使用 Valgrind (Linux)
valgrind --leak-check=full ./zig-out/bin/zigcms

# 使用 AddressSanitizer
zig build -Doptimize=Debug -Dsanitize-thread=true
```

## 参考资源

- [Zig Language Reference - Memory](https://ziglang.org/documentation/master/#Memory)
- [Zig Standard Library - Allocators](https://ziglang.org/documentation/master/std/#std.mem.Allocator)
- [Zig Style Guide](https://ziglang.org/documentation/master/#Style-Guide)
