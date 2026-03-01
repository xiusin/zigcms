# ORM 关系预加载设计方案

## 目标

通过模型的 `relation` 关系自动处理 N+1 查询，类似 Laravel 的 `with()` 预加载。

## 设计原则

1. **零侵入**：不影响现有数据写入逻辑
2. **最小化**：只在查询时生效，写入时完全透明
3. **类型安全**：编译时检查关系定义
4. **内存安全**：自动管理关联数据生命周期

## 使用示例

### 1. 定义关系

```zig
// src/domain/entities/role.model.zig
pub const Role = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    
    // 定义关系（可选）
    pub const relations = .{
        .menus = .{
            .type = .many_to_many,
            .model = Menu,
            .through = "role_menu",
            .foreign_key = "role_id",
            .related_key = "menu_id",
        },
        .permissions = .{
            .type = .many_to_many,
            .model = Permission,
            .through = "role_permission",
            .foreign_key = "role_id",
            .related_key = "permission_id",
        },
    };
};
```

### 2. 使用预加载（自动解决 N+1）

```zig
// ❌ 之前：N+1 查询（41 次）
var q = OrmRole.Query();
defer q.deinit();
const roles = try q.get();
defer OrmRole.freeModels(roles);

for (roles) |role| {
    // 每个角色都会触发一次查询
    var menu_q = OrmRoleMenu.Query();
    defer menu_q.deinit();
    _ = menu_q.where("role_id", "=", role.id);
    const menus = try menu_q.get();
    defer OrmRoleMenu.freeModels(menus);
}

// ✅ 现在：预加载（3 次查询）
var q = OrmRole.Query();
defer q.deinit();

_ = q.with(&.{"menus"});  // 预加载菜单关系

const roles = try q.get();
defer OrmRole.freeModels(roles);

// 关联数据已预加载，无额外查询
for (roles) |role| {
    // 直接访问，无需额外查询
    const menus = role.menus;  // 已预加载
}
```

### 3. 多关系预加载

```zig
var q = OrmRole.Query();
defer q.deinit();

// 同时预加载多个关系
_ = q.with(&.{ "menus", "permissions" });

const roles = try q.get();
defer OrmRole.freeModels(roles);
```

### 4. 嵌套预加载

```zig
var q = OrmRole.Query();
defer q.deinit();

// 预加载嵌套关系
_ = q.with(&.{"menus.permissions"});  // 菜单的权限

const roles = try q.get();
defer OrmRole.freeModels(roles);
```

## 实现方案

### 方案 1：编译时关系（推荐）

**优点**：
- 编译时类型检查
- 零运行时开销
- 类型安全

**实现**：

```zig
// QueryBuilder 添加 with() 方法
pub fn with(self: *Self, relations: []const []const u8) *Self {
    for (relations) |rel| {
        self.eager_loader.add(rel) catch return self;
    }
    return self;
}

// get() 方法自动预加载
pub fn get(self: *Self) ![]Model {
    const models = try self.executeQuery();
    
    // 如果有预加载关系，自动加载
    if (self.eager_loader.relations.count() > 0) {
        try self.eager_loader.load(self.db, models);
    }
    
    return models;
}
```

### 方案 2：运行时关系（备选）

**优点**：
- 更灵活
- 可动态配置

**缺点**：
- 运行时开销
- 类型不安全

## 关系类型支持

### 1. 多对多（Many-to-Many）

```zig
.menus = .{
    .type = .many_to_many,
    .model = Menu,
    .through = "role_menu",      // 中间表
    .foreign_key = "role_id",    // 外键
    .related_key = "menu_id",    // 关联键
}
```

**SQL 执行流程**：
```sql
-- 1. 查询角色（1 次）
SELECT * FROM roles WHERE status = 1;

-- 2. 批量查询中间表（1 次）
SELECT * FROM role_menu WHERE role_id IN (1, 2, 3);

-- 3. 批量查询菜单（1 次）
SELECT * FROM menus WHERE id IN (10, 11, 12, 13);
```

### 2. 一对多（Has-Many）

```zig
.posts = .{
    .type = .has_many,
    .model = Post,
    .foreign_key = "user_id",
}
```

**SQL 执行流程**：
```sql
-- 1. 查询用户（1 次）
SELECT * FROM users WHERE status = 1;

-- 2. 批量查询文章（1 次）
SELECT * FROM posts WHERE user_id IN (1, 2, 3);
```

### 3. 一对一（Has-One）

```zig
.profile = .{
    .type = .has_one,
    .model = Profile,
    .foreign_key = "user_id",
}
```

### 4. 属于（Belongs-To）

```zig
.user = .{
    .type = .belongs_to,
    .model = User,
    .foreign_key = "user_id",
}
```

## 内存管理

### 关联数据存储

```zig
pub const Role = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    
    // 关联数据（可选）
    menus: ?[]Menu = null,
    permissions: ?[]Permission = null,
    
    pub const relations = .{
        .menus = .{ ... },
        .permissions = .{ ... },
    };
};
```

### 自动释放

```zig
// freeModels 自动释放关联数据
pub fn freeModels(models: []Model) void {
    for (models) |model| {
        // 释放关联数据
        if (model.menus) |menus| {
            OrmMenu.freeModels(menus);
        }
        if (model.permissions) |perms| {
            OrmPermission.freeModels(perms);
        }
        
        // 释放字符串字段
        // ...
    }
    
    allocator.free(models);
}
```

## 性能对比

### N+1 查询（之前）

```
查询 10 个角色 = 1 次
每个角色查询菜单 = 10 次
每个菜单查询权限 = 30 次
总计：41 次查询
```

### 预加载（现在）

```
查询角色 = 1 次
批量查询角色-菜单关系 = 1 次
批量查询菜单 = 1 次
总计：3 次查询

性能提升：93%
```

## 实现步骤

### 阶段 1：基础框架（已完成）

- [x] 创建 `relations.zig` 模块
- [x] 定义关系类型枚举
- [x] 创建 `EagerLoader` 结构

### 阶段 2：多对多支持（优先）

- [ ] 实现 `loadManyToMany()`
- [ ] 批量查询中间表
- [ ] 批量查询关联模型
- [ ] 组装数据到模型

### 阶段 3：其他关系类型

- [ ] 实现 `loadHasMany()`
- [ ] 实现 `loadHasOne()`
- [ ] 实现 `loadBelongsTo()`

### 阶段 4：集成到 QueryBuilder

- [ ] 添加 `with()` 方法
- [ ] 修改 `get()` 自动预加载
- [ ] 修改 `freeModels()` 释放关联数据

### 阶段 5：测试和文档

- [ ] 单元测试
- [ ] 集成测试
- [ ] 性能测试
- [ ] 使用文档

## 注意事项

### 1. 不影响写入

关系定义**只在查询时生效**，写入时完全透明：

```zig
// 写入不受影响
const role = try OrmRole.Create(.{
    .name = "管理员",
});

// 关联数据写入仍然手动控制
try OrmRoleMenu.Create(.{
    .role_id = role.id,
    .menu_id = menu_id,
});
```

### 2. 可选使用

关系预加载是**可选功能**：

```zig
// 不使用预加载（保持原有行为）
var q = OrmRole.Query();
const roles = try q.get();

// 使用预加载（自动解决 N+1）
var q = OrmRole.Query();
_ = q.with(&.{"menus"});
const roles = try q.get();
```

### 3. 内存安全

关联数据由 `freeModels()` 自动释放，无需手动管理：

```zig
const roles = try q.get();
defer OrmRole.freeModels(roles);  // 自动释放关联数据
```

## 总结

**优点**：
- ✅ 自动解决 N+1 查询（93% 性能提升）
- ✅ 零侵入（不影响写入逻辑）
- ✅ 类型安全（编译时检查）
- ✅ 内存安全（自动管理生命周期）
- ✅ 可选使用（向后兼容）

**实现成本**：
- 最小化实现（约 200 行代码）
- 不修改现有写入逻辑
- 只在查询时生效

**建议**：
- 优先实现多对多（最常用）
- 逐步支持其他关系类型
- 保持 API 简洁
