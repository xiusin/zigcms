# ZigCMS DDD 架构迁移策略

**版本**: 1.0.0  
**最后更新**: 2025-01-17  
**作者**: ZigCMS Team

本文档描述如何将 ZigCMS 逐步迁移到领域驱动设计（DDD）架构。

## 📋 迁移概述

### 迁移目标

1. **引入 DDD 核心模式**：值对象、实体、聚合根、领域事件
2. **实现 CQRS**：分离读写操作，提高系统可维护性
3. **事件驱动架构**：通过领域事件实现松耦合

### 迁移原则

- **渐进式迁移**：逐步引入新模式，不破坏现有功能
- **向后兼容**：保持现有 API 稳定
- **可逆性**：每步迁移都可以独立回滚

## 🏗️ 新增模块结构

### shared_kernel - 核心共享模块

```
shared_kernel/
├── mod.zig                 # 模块入口
├── patterns/              # DDD 模式定义
│   ├── value_object.zig   # 值对象基类
│   ├── entity.zig         # 实体基类
│   ├── aggregate_root.zig # 聚合根模式
│   ├── domain_event.zig   # 领域事件基类
│   ├── repository.zig     # 仓储接口
│   ├── command.zig        # 命令模式 (CQRS)
│   ├── query.zig          # 查询模式 (CQRS)
│   └── projection.zig     # 投影模式
└── infrastructure/        # 基础设施实现
    ├── domain_event_bus.zig    # 领域事件总线
    └── user_event_handlers.zig # 用户事件处理器
```

### domain - 领域层扩展

```
domain/
├── entities/
│   ├── value_objects/     # 值对象
│   │   ├── email.zig      # Email 值对象
│   │   └── username.zig   # Username 值对象
│   └── user.model.zig     # User 聚合根
├── events/                # 领域事件
│   └── user_events.zig    # 用户领域事件
├── repositories/          # 仓储接口
└── services/              # 领域服务
```

## 📦 迁移步骤

### Phase 1: 基础设施（已完成） ✓

#### 1.1 添加 DDD 模式基类

**文件**: `shared_kernel/patterns/*.zig`

```zig
// 使用示例
const ValueObject = @import("shared_kernel/patterns/value_object.zig").ValueObject;

// 创建值对象
pub const Email = struct {
    value: []const u8,
    
    pub fn create(email: []const u8) !Email {
        if (email.len == 0) return error.EmailRequired;
        // ...
    }
};
```

#### 1.2 添加聚合根模式

**文件**: `shared_kernel/patterns/aggregate_root.zig`

```zig
// 使用示例
const AggregateRoot = @import("shared_kernel/patterns/aggregate_root.zig").AggregateRoot;

pub const UserAgg = AggregateRoot(UserData, UserEvent);
```

### Phase 2: 领域层迁移（已完成） ✓

#### 2.1 迁移 User 实体

**原代码**:
```zig
// domain/entities/user.model.zig (旧)
pub const User = struct {
    id: ?i32,
    username: []const u8,
    email: []const u8,
    // ...
};
```

**新代码**:
```zig
// domain/entities/user.model.zig (新)
pub const UserData = struct {
    id: ?i32 = null,
    username: []const u8 = "",
    email: []const u8 = "",
    // ...
};

pub const UserAgg = AggregateRoot(UserData, UserEvent);

pub const User = struct {
    impl: *UserAgg,
    // 包装器方法...
};
```

#### 2.2 添加领域事件

**文件**: `domain/events/user_events.zig`

```zig
const DomainEvent = @import("../../shared_kernel/patterns/domain_event.zig").DomainEvent;

pub const UserCreated = DomainEvent(struct {
    user_id: i32,
    username: []const u8,
    email: []const u8,
    created_at: i64,
});
```

### Phase 3: CQRS 实现（已完成） ✓

#### 3.1 添加命令模式

**文件**: `shared_kernel/patterns/command.zig`

```zig
pub const Command = struct {
    id: []const u8,
    payload: []const u8,
    timestamp: i64,
};

pub const CommandBus = struct {
    allocator: std.mem.Allocator,
    handlers: std.StringHashMap(CommandHandler),
    // ...
};
```

#### 3.2 添加查询模式

**文件**: `shared_kernel/patterns/query.zig`

```zig
pub const Query = struct {
    type_name: []const u8,
    filters: std.ArrayList(Filter),
    sorts: std.ArrayList(Sort),
    pagination: QueryPagination,
    // ...
};

pub const QueryBus = struct {
    handlers: std.StringHashMap(QueryHandler),
    // ...
};
```

#### 3.3 添加投影模式

**文件**: `shared_kernel/patterns/projection.zig`

```zig
pub const UserProjection = struct {
    allocator: std.mem.Allocator,
    state: UserReadModel,
    status: ProjectionStatus,
    version: u32,
    // ...
};
```

### Phase 4: 事件驱动架构（已完成） ✓

#### 4.1 领域事件总线

**文件**: `shared_kernel/infrastructure/domain_event_bus.zig`

```zig
pub const DomainEventBus = struct {
    allocator: std.mem.Allocator,
    handlers: std.StringHashMap(DomainEventHandler),
    // ...
};
```

#### 4.2 事件处理器

**文件**: `shared_kernel/infrastructure/user_event_handlers.zig`

```zig
pub const UserCreatedHandler = struct {
    allocator: std.mem.Allocator,
    on_user_created: *const fn (UserEvents.UserCreated) void,
    // ...
};
```

## 🔄 迁移计划

### 优先级排序

| 优先级 | 领域模型 | 状态 | 说明 |
|--------|----------|------|------|
| P0 | User | ✓ 已完成 | 核心用户模型 |
| P1 | Article | 待迁移 | 文章模型 |
| P1 | Category | 待迁移 | 分类模型 |
| P2 | Comment | 待迁移 | 评论模型 |
| P2 | Tag | 待迁移 | 标签模型 |

### 迁移检查清单

对于每个领域模型，需要完成：

- [ ] 定义值对象（Email, Username 等）
- [ ] 定义领域事件（Created, Updated, Deleted 等）
- [ ] 实现聚合根
- [ ] 实现事件处理器
- [ ] 添加命令和查询
- [ ] 实现投影
- [ ] 编写单元测试
- [ ] 更新 API 文档

## 📝 使用指南

### 创建新聚合根

```zig
// 1. 定义数据模型
pub const ArticleData = struct {
    id: ?i32 = null,
    title: []const u8 = "",
    content: []const u8 = "",
    author_id: i32 = 0,
    // ...
};

// 2. 定义领域事件
pub const ArticleCreated = DomainEvent(struct {
    article_id: i32,
    title: []const u8,
    // ...
});

// 3. 创建聚合根
pub const ArticleAgg = AggregateRoot(ArticleData, ArticleCreated);

// 4. 定义业务方法
pub const Article = struct {
    impl: *ArticleAgg,
    
    pub fn publish(self: *Self, allocator: std.mem.Allocator) !void {
        // 业务逻辑...
        const event = try ArticleCreated.create(.{
            .article_id = self.impl.data.id orelse 0,
            .title = self.impl.data.title,
        }, allocator, "article.created");
        self.impl.publish(event);
    }
};
```

### 发布和订阅领域事件

```zig
// 1. 创建事件总线
var event_bus = DomainEventBus.init(allocator);
defer event_bus.deinit();

// 2. 注册事件处理器
try event_bus.subscribe("user.created", UserCreatedHandler);

// 3. 发布事件
const event = try UserCreated.create(.{ ... }, allocator, "user.created");
try event_bus.publish(event);
```

### 使用 CQRS

```zig
// 1. 创建命令总线
var command_bus = CommandBus.init(allocator);
defer command_bus.deinit();

// 2. 注册命令处理器
try command_bus.register("CreateUserCommand", create_user_handler);

// 3. 发送命令
const result = command_bus.send(cmd_data, "CreateUserCommand");

// 4. 创建查询总线
var query_bus = QueryBus.init(allocator);
defer query_bus.deinit();

// 5. 注册查询处理器
try query_bus.register("ListUsersQuery", list_users_handler);

// 6. 执行查询
var query = Query.init(allocator, "ListUsersQuery");
query.setPagination(1, 20);
const result = query_bus.fetch(&query);
```

## ⚠️ 注意事项

### 1. 内存管理

- 聚合根创建后需要手动调用 `deinit()` 释放
- 领域事件中的字符串需要使用 allocator 分配
- 事件处理器回调需要正确管理生命周期

### 2. 向后兼容

- 保持现有 API 端点不变
- 仓储接口需要支持旧版和新版两种用法
- 逐步迁移，不强制一次性更新所有代码

### 3. 性能考虑

- 事件发布是同步的，注意不要在事件处理中执行耗时操作
- 投影更新应该是幂等的
- 大量事件时考虑使用异步处理

## 📚 相关文档

- [ARCHITECTURE.md](../ARCHITECTURE.md) - 架构设计文档
- [NEW_ARCHITECTURE.md](../NEW_ARCHITECTURE.md) - 新架构设计
- [CODE_STYLE.md](../CODE_STYLE.md) - 代码规范
- [MEMORY_SAFETY.md](../MEMORY_SAFETY.md) - 内存安全指南
