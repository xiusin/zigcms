# ORM 关系预加载使用指南

## 快速开始

### 1. 定义关系

```zig
// src/domain/entities/role.model.zig
pub const Role = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    
    // 关联数据字段（可选）
    menus: ?[]Menu = null,
    permissions: ?[]Permission = null,
    
    // 定义关系
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

### 2. 使用预加载

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
    if (role.menus) |menus| {
        for (menus) |menu| {
            std.debug.print("菜单: {s}\n", .{menu.name});
        }
    }
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

for (roles) |role| {
    // 访问菜单
    if (role.menus) |menus| {
        // ...
    }
    
    // 访问权限
    if (role.permissions) |perms| {
        // ...
    }
}
```

## 关系类型

### 1. 多对多（Many-to-Many）

**场景**：角色和菜单、用户和标签

```zig
pub const Role = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    menus: ?[]Menu = null,
    
    pub const relations = .{
        .menus = .{
            .type = .many_to_many,
            .model = Menu,
            .through = "role_menu",      // 中间表
            .foreign_key = "role_id",    // 外键
            .related_key = "menu_id",    // 关联键
        },
    };
};
```

**SQL 执行**：
```sql
-- 1. 查询角色（1 次）
SELECT * FROM roles WHERE status = 1;

-- 2. 批量查询中间表（1 次）
SELECT role_id, menu_id FROM role_menu WHERE role_id IN (1, 2, 3);

-- 3. 批量查询菜单（1 次）
SELECT * FROM menus WHERE id IN (10, 11, 12, 13);
```

### 2. 一对多（Has-Many）

**场景**：用户和文章、分类和产品

```zig
pub const User = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    posts: ?[]Post = null,
    
    pub const relations = .{
        .posts = .{
            .type = .has_many,
            .model = Post,
            .foreign_key = "user_id",
        },
    };
};
```

**SQL 执行**：
```sql
-- 1. 查询用户（1 次）
SELECT * FROM users WHERE status = 1;

-- 2. 批量查询文章（1 次）
SELECT * FROM posts WHERE user_id IN (1, 2, 3);
```

### 3. 一对一（Has-One）

**场景**：用户和个人资料

```zig
pub const User = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    profile: ?Profile = null,
    
    pub const relations = .{
        .profile = .{
            .type = .has_one,
            .model = Profile,
            .foreign_key = "user_id",
        },
    };
};
```

**SQL 执行**：
```sql
-- 1. 查询用户（1 次）
SELECT * FROM users WHERE status = 1;

-- 2. 批量查询资料（1 次）
SELECT * FROM profiles WHERE user_id IN (1, 2, 3);
```

### 4. 属于（Belongs-To）

**场景**：文章属于用户

```zig
pub const Post = struct {
    id: ?i32 = null,
    title: []const u8 = "",
    user_id: ?i32 = null,
    user: ?User = null,
    
    pub const relations = .{
        .user = .{
            .type = .belongs_to,
            .model = User,
            .foreign_key = "user_id",
        },
    };
};
```

**SQL 执行**：
```sql
-- 1. 查询文章（1 次）
SELECT * FROM posts WHERE status = 1;

-- 2. 批量查询用户（1 次）
SELECT * FROM users WHERE id IN (1, 2, 3);
```

## 实战案例

### 案例 1：角色列表with菜单

```zig
// src/api/controllers/system_role.controller.zig
pub fn list(req: zap.Request) !void {
    var q = OrmRole.Query();
    defer q.deinit();
    
    // 预加载菜单关系
    _ = q.with(&.{"menus"});
    
    const roles = try q.get();
    defer OrmRole.freeModels(roles);
    
    // 构建响应
    var result = std.ArrayList(RoleWithMenus).init(allocator);
    defer result.deinit();
    
    for (roles) |role| {
        try result.append(.{
            .id = role.id,
            .name = role.name,
            .menus = role.menus orelse &[_]Menu{},
        });
    }
    
    try base.send_success(req, result.items);
}
```

**性能对比**：
- 之前：1 + 10 + 30 = 41 次查询
- 现在：1 + 1 + 1 = 3 次查询
- 提升：93%

### 案例 2：用户列表with文章

```zig
pub fn list(req: zap.Request) !void {
    var q = OrmUser.Query();
    defer q.deinit();
    
    _ = q.where("status", "=", 1)
         .with(&.{"posts"})
         .limit(20);
    
    const users = try q.get();
    defer OrmUser.freeModels(users);
    
    for (users) |user| {
        std.debug.print("用户: {s}\n", .{user.name});
        
        if (user.posts) |posts| {
            std.debug.print("  文章数: {d}\n", .{posts.len});
            for (posts) |post| {
                std.debug.print("  - {s}\n", .{post.title});
            }
        }
    }
}
```

### 案例 3：多关系预加载

```zig
pub fn detail(req: zap.Request) !void {
    const id = try req.getParamInt("id") orelse return error.InvalidId;
    
    var q = OrmRole.Query();
    defer q.deinit();
    
    _ = q.where("id", "=", id)
         .with(&.{ "menus", "permissions", "users" });
    
    const roles = try q.get();
    defer OrmRole.freeModels(roles);
    
    if (roles.len == 0) return error.NotFound;
    
    const role = roles[0];
    
    try base.send_success(req, .{
        .id = role.id,
        .name = role.name,
        .menus = role.menus orelse &[_]Menu{},
        .permissions = role.permissions orelse &[_]Permission{},
        .users = role.users orelse &[_]User{},
    });
}
```

## 内存管理

### 自动释放

关联数据由 `freeModels()` 自动释放：

```zig
const roles = try q.get();
defer OrmRole.freeModels(roles);  // 自动释放 roles 和关联数据

// freeModels 内部实现
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
        allocator.free(model.name);
        // ...
    }
    
    allocator.free(models);
}
```

### 注意事项

1. **关联数据字段必须是 optional**：
   ```zig
   menus: ?[]Menu = null,  // ✅ 正确
   menus: []Menu,          // ❌ 错误
   ```

2. **访问前检查 null**：
   ```zig
   if (role.menus) |menus| {
       // 使用 menus
   }
   ```

3. **不要手动释放关联数据**：
   ```zig
   // ❌ 错误：会导致重复释放
   if (role.menus) |menus| {
       OrmMenu.freeModels(menus);
   }
   OrmRole.freeModels(roles);  // 会再次释放
   ```

## 性能优化

### 1. 只预加载需要的关系

```zig
// ❌ 避免：预加载所有关系
_ = q.with(&.{ "menus", "permissions", "users", "logs" });

// ✅ 推荐：只预加载需要的
_ = q.with(&.{"menus"});
```

### 2. 结合条件查询

```zig
var q = OrmRole.Query();
defer q.deinit();

_ = q.where("status", "=", 1)
     .where("type", "=", "admin")
     .with(&.{"menus"})
     .limit(10);

const roles = try q.get();
```

### 3. 使用 Arena 简化内存管理

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

var q = OrmRole.Query();
defer q.deinit();

_ = q.with(&.{"menus"});
var result = try q.getWithArena(arena.allocator());
// 无需手动释放，arena.deinit() 会清理所有
```

## 限制和注意事项

### 1. 不影响写入

关系定义**只在查询时生效**，写入时完全透明：

```zig
// ✅ 写入不受影响
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

不使用 `with()` 时保持原有行为：

```zig
// 不使用预加载（保持原有行为）
var q = OrmRole.Query();
const roles = try q.get();

// 使用预加载（自动解决 N+1）
var q = OrmRole.Query();
_ = q.with(&.{"menus"});
const roles = try q.get();
```

### 3. 嵌套预加载（暂不支持）

当前版本不支持嵌套预加载：

```zig
// ❌ 暂不支持
_ = q.with(&.{"menus.permissions"});

// ✅ 替代方案：分步查询
_ = q.with(&.{"menus"});
const roles = try q.get();

for (roles) |role| {
    if (role.menus) |menus| {
        var menu_q = OrmMenu.Query();
        defer menu_q.deinit();
        _ = menu_q.whereIn("id", menu_ids)
                 .with(&.{"permissions"});
        // ...
    }
}
```

## 总结

### 优点

- ✅ 自动解决 N+1 查询（93% 性能提升）
- ✅ 零侵入（不影响写入逻辑）
- ✅ 类型安全（编译时检查）
- ✅ 内存安全（自动管理生命周期）
- ✅ 可选使用（向后兼容）
- ✅ 简单易用（一行代码）

### 使用建议

1. **优先使用预加载**：避免 N+1 查询
2. **只加载需要的**：不要预加载所有关系
3. **结合条件查询**：减少数据量
4. **注意内存管理**：使用 defer 确保释放

### 性能对比

| 场景 | 之前 | 现在 | 提升 |
|------|------|------|------|
| 10 个角色 + 30 个菜单 | 41 次查询 | 3 次查询 | 93% |
| 100 个用户 + 500 篇文章 | 101 次查询 | 2 次查询 | 98% |
| 20 个分类 + 200 个产品 | 21 次查询 | 2 次查询 | 90% |

**ZigCMS ORM 关系预加载，让你的应用飞起来！🚀**
