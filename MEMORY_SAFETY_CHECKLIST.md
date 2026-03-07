# 质量中心内存安全检查清单

## 使用说明
在开发新功能或修改现有代码时，使用此清单确保内存安全。

## 1. ORM 查询结果管理 ✅

### 检查项
- [ ] 所有 `.get()` 调用都有 `defer freeModels`
- [ ] 或使用 `getWithArena` 自动管理
- [ ] QueryBuilder 使用 `defer q.deinit()`

### 正确示例
```zig
// 方式 1：手动释放
var q = OrmModel.Query();
defer q.deinit();

const rows = try q.get();
defer OrmModel.freeModels(rows);

// 方式 2：Arena 自动管理
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

var result = try q.getWithArena(arena.allocator());
```

### 错误示例 ❌
```zig
// ❌ 忘记释放
const rows = try q.get();
// 使用 rows...
// 内存泄漏！

// ❌ 忘记 defer
const rows = try q.get();
OrmModel.freeModels(rows);  // 如果后续代码出错，不会执行
```

## 2. 字符串深拷贝管理 ✅

### 检查项
- [ ] 所有字符串字段使用 `allocator.dupe`
- [ ] 实现了释放方法（如 `freeEntity`）
- [ ] 使用 `defer` 确保释放

### 正确示例
```zig
// 深拷贝
fn toEntity(self: *Self, orm: OrmModel) !Entity {
    return Entity{
        .name = try self.allocator.dupe(u8, orm.name),
        .description = try self.allocator.dupe(u8, orm.description),
    };
}

// 释放
pub fn freeEntity(self: *Self, entity: Entity) void {
    self.allocator.free(entity.name);
    self.allocator.free(entity.description);
}

// 使用
const entity = try repo.toEntity(orm);
defer repo.freeEntity(entity);
```

### 错误示例 ❌
```zig
// ❌ 浅拷贝（悬垂指针）
return Entity{
    .name = orm.name,  // 指向 ORM 内存
};

// ❌ 忘记释放
const entity = try repo.toEntity(orm);
// 使用 entity...
// 内存泄漏！
```

## 3. Arena Allocator 管理 ✅

### 检查项
- [ ] 所有 Arena 初始化都有 `defer deinit`
- [ ] 使用 `errdefer` 处理错误路径
- [ ] Arena 作用域清晰

### 正确示例
```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
errdefer arena.deinit();  // 错误路径也释放

const arena_allocator = arena.allocator();

// 使用 arena_allocator 分配内存
const data = try arena_allocator.alloc(u8, 1024);
// 无需手动释放
```

### 错误示例 ❌
```zig
// ❌ 忘记 deinit
var arena = std.heap.ArenaAllocator.init(allocator);
// 使用 arena...
// 内存泄漏！

// ❌ 忘记 errdefer
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
// 如果后续代码出错，可能不会执行 deinit
```

## 4. 错误处理内存安全 ✅

### 检查项
- [ ] 使用 `errdefer` 确保错误路径释放
- [ ] 分配后立即添加 `errdefer`
- [ ] 成功路径使用 `defer`

### 正确示例
```zig
var data = try allocator.alloc(T, size);
errdefer allocator.free(data);  // 错误路径释放

// 可能失败的操作
try doSomething(data);

// 成功路径释放
defer allocator.free(data);
```

### 错误示例 ❌
```zig
// ❌ 缺少 errdefer
var data = try allocator.alloc(T, size);
try doSomething(data);  // 如果失败，data 泄漏
defer allocator.free(data);
```

## 5. 数组和切片管理 ✅

### 检查项
- [ ] 数组分配使用 `errdefer` 保护
- [ ] 元素分配失败时清理已分配元素
- [ ] 使用 Arena 简化管理

### 正确示例
```zig
// 方式 1：手动管理
var items = try allocator.alloc(Item, count);
errdefer allocator.free(items);

for (items, 0..) |*item, i| {
    errdefer {
        // 清理已分配的元素
        for (items[0..i]) |prev| {
            freeItem(prev);
        }
    }
    item.* = try createItem();
}

defer {
    for (items) |item| {
        freeItem(item);
    }
    allocator.free(items);
}

// 方式 2：Arena 管理（推荐）
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

var items = try arena.allocator().alloc(Item, count);
// 无需手动释放
```

## 6. 结构体内存管理 ✅

### 检查项
- [ ] 实现 `deinit` 方法
- [ ] 释放所有拥有的资源
- [ ] 使用 `defer` 调用 `deinit`

### 正确示例
```zig
pub const MyStruct = struct {
    allocator: Allocator,
    name: []const u8,
    data: []u8,
    
    pub fn init(allocator: Allocator, name: []const u8) !*MyStruct {
        const self = try allocator.create(MyStruct);
        errdefer allocator.destroy(self);
        
        self.* = .{
            .allocator = allocator,
            .name = try allocator.dupe(u8, name),
            .data = try allocator.alloc(u8, 1024),
        };
        
        return self;
    }
    
    pub fn deinit(self: *MyStruct) void {
        self.allocator.free(self.name);
        self.allocator.free(self.data);
        self.allocator.destroy(self);
    }
};

// 使用
const obj = try MyStruct.init(allocator, "test");
defer obj.deinit();
```

## 7. 常见陷阱 ⚠️

### 陷阱 1：浅拷贝字符串
```zig
// ❌ 错误
const user = User{
    .name = orm_user.name,  // 浅拷贝
};
defer OrmUser.freeModels(orm_users);
// user.name 现在是悬垂指针！

// ✅ 正确
const user = User{
    .name = try allocator.dupe(u8, orm_user.name),
};
defer allocator.free(user.name);
defer OrmUser.freeModels(orm_users);
```

### 陷阱 2：忘记 QueryBuilder deinit
```zig
// ❌ 错误
var q = OrmModel.Query();
const rows = try q.get();
// 忘记 q.deinit()

// ✅ 正确
var q = OrmModel.Query();
defer q.deinit();
const rows = try q.get();
```

### 陷阱 3：错误路径内存泄漏
```zig
// ❌ 错误
const data1 = try allocator.alloc(u8, 100);
const data2 = try allocator.alloc(u8, 200);  // 如果失败，data1 泄漏
defer allocator.free(data1);
defer allocator.free(data2);

// ✅ 正确
const data1 = try allocator.alloc(u8, 100);
errdefer allocator.free(data1);

const data2 = try allocator.alloc(u8, 200);
errdefer allocator.free(data2);

defer allocator.free(data1);
defer allocator.free(data2);
```

## 8. 验证工具使用

### 开发时验证
```zig
var gpa = std.heap.GeneralPurposeAllocator(.{
    .safety = true,
    .verbose_log = true,
}){};
defer {
    const leaked = gpa.deinit();
    if (leaked == .leak) {
        std.debug.print("内存泄漏！\n", .{});
    }
}
```

### 审计脚本
```bash
# 运行内存安全审计
bash audit-memory-safety.sh
```

### 验证工具
```bash
# 编译并运行验证工具
zig build-exe verify-memory-safety.zig -O ReleaseSafe
./verify-memory-safety
```

## 9. 代码审查清单

在代码审查时，检查以下项：

- [ ] 所有 ORM 查询都正确释放
- [ ] 所有字符串深拷贝都正确释放
- [ ] 所有 Arena 都正确释放
- [ ] 使用了 errdefer 处理错误路径
- [ ] 实现了 deinit 方法
- [ ] 使用了 defer 模式
- [ ] 无明显内存泄漏风险

## 10. 最佳实践总结

### 优先级 1：使用 Arena（推荐）
```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
// 使用 arena.allocator() 分配所有临时内存
```

### 优先级 2：使用 defer
```zig
const data = try allocator.alloc(T, size);
defer allocator.free(data);
```

### 优先级 3：使用 errdefer
```zig
const data = try allocator.alloc(T, size);
errdefer allocator.free(data);
```

### 优先级 4：实现 deinit
```zig
pub fn deinit(self: *Self) void {
    // 释放所有拥有的资源
}
```

---

**记住**：内存安全是 Zig 的核心优势，遵循这些最佳实践可以避免 99% 的内存问题！
