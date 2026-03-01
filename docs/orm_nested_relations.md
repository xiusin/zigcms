# ORM 嵌套预加载使用指南

## 功能说明

嵌套预加载允许你一次性加载多层关系，例如：
- `menus.permissions` - 加载菜单及其权限
- `users.posts.comments` - 加载用户、文章及评论

## 使用示例

### 1. 定义多层关系

```zig
// 角色模型
pub const Role = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    menus: ?[]Menu = null,
    
    pub const relations = .{
        .menus = .{
            .type = .many_to_many,
            .model = Menu,
            .through = "role_menu",
            .foreign_key = "role_id",
            .related_key = "menu_id",
        },
    };
};

// 菜单模型
pub const Menu = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    permissions: ?[]Permission = null,
    
    pub const relations = .{
        .permissions = .{
            .type = .many_to_many,
            .model = Permission,
            .through = "menu_permission",
            .foreign_key = "menu_id",
            .related_key = "permission_id",
        },
    };
};

// 权限模型
pub const Permission = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    code: []const u8 = "",
};
```

### 2. 使用嵌套预加载

```zig
// 一次性加载角色、菜单、权限（3 层）
var q = OrmRole.Query();
_ = q.with(&.{"menus.permissions"});  // 嵌套预加载
const roles = try q.get();
defer OrmRole.freeModels(roles);

// 访问嵌套数据
for (roles) |role| {
    std.debug.print("角色: {s}\n", .{role.name});
    
    if (role.menus) |menus| {
        for (menus) |menu| {
            std.debug.print("  菜单: {s}\n", .{menu.name});
            
            if (menu.permissions) |perms| {
                for (perms) |perm| {
                    std.debug.print("    权限: {s}\n", .{perm.name});
                }
            }
        }
    }
}
```

### 3. 多个嵌套关系

```zig
// 同时预加载多个嵌套关系
var q = OrmRole.Query();
_ = q.with(&.{
    "menus.permissions",  // 菜单的权限
    "users.posts",        // 用户的文章
});
const roles = try q.get();
defer OrmRole.freeModels(roles);
```

## 性能对比

### 场景：10 个角色，每个角色 3 个菜单，每个菜单 5 个权限

**不使用预加载（N+1+M 问题）**：
```zig
// 1 次查询角色
var role_q = OrmRole.Query();
const roles = try role_q.get();

// 10 次查询菜单（每个角色一次）
for (roles) |role| {
    var menu_q = OrmRoleMenu.Query();
    _ = menu_q.where("role_id", "=", role.id);
    const menus = try menu_q.get();
    
    // 30 次查询权限（每个菜单一次）
    for (menus) |menu| {
        var perm_q = OrmMenuPermission.Query();
        _ = perm_q.where("menu_id", "=", menu.id);
        const perms = try perm_q.get();
    }
}
// 总计：1 + 10 + 30 + 30 + 150 = 221 次查询
```

**使用嵌套预加载**：
```zig
var q = OrmRole.Query();
_ = q.with(&.{"menus.permissions"});
const roles = try q.get();
// 总计：1 + 1 + 1 + 1 + 1 = 5 次查询
```

**性能提升：97.7%**（221 次 → 5 次）

## 实现原理

### 1. 解析嵌套关系

```
"menus.permissions" 
    ↓
["menus", "permissions"]
```

### 2. 分层加载

```
1. 加载 roles（1 次查询）
2. 加载 roles.menus（2 次查询：中间表 + 菜单表）
3. 加载 menus.permissions（2 次查询：中间表 + 权限表）
```

### 3. 递归组装

```
roles
  └── menus[]
        └── permissions[]
```

## 注意事项

### 1. 关系定义必须完整

每一层的模型都必须定义 `relations`：

```zig
// ✅ 正确
pub const Role = struct {
    menus: ?[]Menu = null,
    pub const relations = .{ .menus = ... };
};

pub const Menu = struct {
    permissions: ?[]Permission = null,
    pub const relations = .{ .permissions = ... };
};

// ❌ 错误：Menu 没有定义 relations
pub const Menu = struct {
    permissions: ?[]Permission = null,
    // 缺少 relations 定义
};
```

### 2. 字段必须是 optional

```zig
// ✅ 正确
menus: ?[]Menu = null,

// ❌ 错误
menus: []Menu,
```

### 3. 内存管理

嵌套数据由 `freeModels()` 自动释放：

```zig
const roles = try q.get();
defer OrmRole.freeModels(roles);  // 自动释放所有嵌套数据
```

### 4. 深度限制

建议嵌套深度不超过 3 层：
- ✅ `menus.permissions` - 2 层
- ✅ `users.posts.comments` - 3 层
- ⚠️ `a.b.c.d.e` - 5 层（不推荐）

## 最佳实践

### 1. 按需加载

```zig
// ✅ 推荐：只加载需要的层级
_ = q.with(&.{"menus.permissions"});

// ❌ 避免：加载不需要的层级
_ = q.with(&.{"menus.permissions.roles.users"});
```

### 2. 结合条件查询

```zig
var q = OrmRole.Query();
_ = q.where("status", "=", 1)
     .with(&.{"menus.permissions"})
     .limit(10);
```

### 3. 使用 Arena 简化内存管理

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

var q = OrmRole.Query();
_ = q.with(&.{"menus.permissions"});
var result = try q.getWithArena(arena.allocator());
// 无需手动释放
```

## 故障排查

### 问题 1：嵌套数据为空

**原因**：子模型没有定义 `relations`

**解决**：
```zig
// 确保每一层都定义了 relations
pub const Menu = struct {
    permissions: ?[]Permission = null,
    pub const relations = .{
        .permissions = .{ ... },
    };
};
```

### 问题 2：编译错误

**原因**：字段类型不是 optional

**解决**：
```zig
// ✅ 正确
menus: ?[]Menu = null,

// ❌ 错误
menus: []Menu,
```

### 问题 3：内存泄漏

**原因**：忘记调用 `freeModels()`

**解决**：
```zig
const roles = try q.get();
defer OrmRole.freeModels(roles);  // 必须调用
```

## 总结

嵌套预加载功能：
- ✅ 自动解决多层 N+1 查询
- ✅ 性能提升 97%+
- ✅ 一行代码使用
- ✅ 类型安全
- ✅ 内存安全

**让你的多层关系查询飞起来！🚀**
