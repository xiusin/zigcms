# ZigCMS 业务层代码风格规范

## 目录结构

```
zigcms/
├── domain/entities/          # 领域实体 (RAII 内存管理)
│   ├── {entity}.model.zig    
├── api/controllers/          # 协议控制器 (通过 DI 注入服务)
├── application/services/     # 业务服务层 (实现业务逻辑)
├── infrastructure/           # 外部实现 (数据库、缓存驱动)
├── commands/                 # CLI 工具集 (codegen, migrate)
└── shared/di/                # 依赖注入核心
```

## 命名规范

### 变量与参数
- **普通变量**: `snake_case`
- ** shadowing 防护**: 禁止定义名为 `value` 的参数，统一使用 `val`（避免与 ORM 内置方法冲突）。
- **未使用参数**: 必须显式丢弃，如 `_ = self;`。

## 初始化 (DI 模式)

控制器和服务必须使用构造函数注入，不再允许手动初始化全局变量：

```zig
// ✅ 推荐 (DI 模式)
pub fn init(allocator: Allocator, auth_service: *AuthService) Self {
    return .{ 
        .allocator = allocator, 
        .auth_service = auth_service 
    };
}
```

### 标准字段
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `?i32` | 主键，可空 |
| `name` | `[]const u8` | 名称 |
| `code` | `[]const u8` | 编码（可选） |
| `status` | `i32` | 状态：0禁用 1启用 |
| `sort` | `i32` | 排序权重 |
| `remark` | `[]const u8` | 备注 |
| `create_time` | `?i64` | 创建时间戳 |
| `update_time` | `?i64` | 更新时间戳 |
| `is_delete` | `i32` | 软删除：0正常 1已删除 |

## Controller 规范

```zig
//! {实体名}管理控制器
//!
//! 提供{实体名}的 CRUD 操作

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const models = @import("../../domain/entities/models.zig");
const sql = @import("../../application/services/sql/orm.zig");
const global = @import("../../shared/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const strings = @import("../../shared/utils/strings.zig");
const mw = @import("../middleware/mod.zig");

const Self = @This();
const MW = mw.Controller(Self);

allocator: Allocator,

/// ORM 模型定义
const Orm{Entity} = sql.defineWithConfig(models.{Entity}, .{
    .table_name = "zigcms.{entity}",
    .primary_key = "id",
});

/// 初始化控制器
pub fn init(allocator: Allocator) Self {
    if (!Orm{Entity}.hasDb()) {
        Orm{Entity}.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

// ============================================================================
// 公开 API（带认证中间件）
// ============================================================================

/// 分页列表
pub const list = MW.requireAuth(listImpl);

/// 获取单条记录
pub const get = MW.requireAuth(getImpl);

/// 保存（新增/更新）
pub const save = MW.requireAuth(saveImpl);

/// 删除
pub const delete = MW.requireAuth(deleteImpl);

/// 下拉选择列表
pub const select = MW.requireAuth(selectImpl);

// ============================================================================
// 实现方法
// ============================================================================

fn listImpl(self: *Self, req: zap.Request) !void { ... }
fn getImpl(self: *Self, req: zap.Request) !void { ... }
fn saveImpl(self: *Self, req: zap.Request) !void { ... }
fn deleteImpl(self: *Self, req: zap.Request) !void { ... }
fn selectImpl(self: *Self, req: zap.Request) !void { ... }
```

### 标准 API 方法
| 方法 | 路径 | 说明 |
|------|------|------|
| `list` | `/{entity}/list` | 分页列表 |
| `get` | `/{entity}/get?id=` | 获取单条 |
| `save` | `/{entity}/save` | 新增/更新 |
| `delete` | `/{entity}/delete?id=` | 删除 |
| `select` | `/{entity}/select` | 下拉选择 |

## DTO 规范

### CreateDto（创建请求）
```zig
//! {实体名}创建数据传输对象
//!
//! 用于创建{实体名}实体的数据结构

const std = @import("std");

/// {实体名}创建 DTO
pub const {Entity}CreateDto = struct {
    /// 名称（必填）
    name: []const u8,
    /// 编码
    code: []const u8 = "",
    /// 状态
    status: i32 = 1,
    /// 排序
    sort: i32 = 0,
    /// 备注
    remark: []const u8 = "",
};
```

### UpdateDto（更新请求）
```zig
//! {实体名}更新数据传输对象

const std = @import("std");

/// {实体名}更新 DTO
pub const {Entity}UpdateDto = struct {
    /// ID（必填）
    id: i32,
    /// 名称
    name: ?[]const u8 = null,
    /// 编码
    code: ?[]const u8 = null,
    /// 状态
    status: ?i32 = null,
    /// 排序
    sort: ?i32 = null,
    /// 备注
    remark: ?[]const u8 = null,
};
```

### ResponseDto（响应数据）
```zig
//! {实体名}响应数据传输对象

const std = @import("std");

/// {实体名}响应 DTO
pub const {Entity}ResponseDto = struct {
    /// ID
    id: ?i32 = null,
    /// 名称
    name: []const u8 = "",
    /// 编码
    code: []const u8 = "",
    /// 状态
    status: i32 = 1,
    /// 排序
    sort: i32 = 0,
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
};
```

## ORM 链式调用规范

利用重构后的 QueryBuilder 编写更具表现力的代码：

```zig
// 查询单条
const admin = try Admin.Where("username", "=", val).firstOrFail();

// 批量更新
try Article.Where("status", "=", 0).update(.{ .status = 1 });

// 原子增减
try Product.WhereEq("id", id).increment("stock", 1);

// 动态查询
var query = User.Query();
_ = query.When(hasRole, struct {
    fn apply(q: *UserQuery) *UserQuery {
        return q.whereEq("role", role);
    }
}.apply);
```

### 内存管理 (ORM)
- **单条记录**: 必须调用 `freeModel(allocator, &model)`。
- **列表记录**: 必须调用 `freeModels(allocator, slice)`。
- **List 包装器**: 推荐使用 `collect()` 方法并配合 `defer list.deinit()`。

## 注释规范

- 文件头使用 `//!` 文档注释
- 结构体和函数使用 `///` 文档注释
- 字段使用 `///` 单行注释
- 代码块使用 `// ===...===` 分隔符

## 代码风格

1. **缩进**: 4 空格
2. **行宽**: 最大 100 字符
3. **空行**: 函数间空一行，逻辑块间空一行
4. **导入顺序**: std → 第三方 → 项目内部
