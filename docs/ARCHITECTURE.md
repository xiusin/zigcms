# ZigCMS 技术架构文档

> 本文档为 AI 助手参考资料，详细描述 ZigCMS 项目的技术架构、代码结构和设计模式。

---

## 1. 项目概述

**ZigCMS** 是一个使用 **Zig 语言** 开发的轻量级内容管理系统（CMS）。项目采用前后端一体化架构，后端基于 Zap HTTP 框架，前端使用 LayUI 框架。

### 核心特性
- **高性能 HTTP 服务**：基于 Zap 框架，支持多线程/多工作者模式
- **PostgreSQL 数据库**：使用连接池管理
- **JWT 认证**：基于 Token 的身份验证
- **泛型 CRUD**：通过编译期泛型自动生成增删改查接口
- **静态资源服务**：内置静态文件服务器

---

## 2. 技术栈

### 后端
| 组件 | 说明 |
|------|------|
| **Zig** | 主开发语言，版本要求 ≥ 0.13.0 |
| **Zap** | HTTP 服务框架，高性能异步处理 |
| **pg.zig** | PostgreSQL 客户端库 |
| **jwt** | JSON Web Token 实现 |
| **json (getty-zig)** | JSON 序列化/反序列化 |
| **smtp_client** | 邮件发送客户端 |
| **zig-curl** | HTTP 客户端 |
| **zig-regex** | 正则表达式库 |

### 前端
| 组件 | 说明 |
|------|------|
| **LayUI** | UI 组件框架 |
| **LayuiMini** | 后台管理模板 |
| **Font Awesome** | 图标库 |
| **jQuery** | DOM 操作库 |

### 数据库
- **PostgreSQL**：主数据库
- **Schema**: `zigcms`

---

## 3. 项目目录结构

```
zigcms/
├── build.zig              # Zig 构建配置
├── build.zig.zon          # 依赖声明文件
├── .env                   # 环境变量配置
├── src/                   # 后端源代码
│   ├── main.zig           # 程序入口
│   ├── root.zig           # 库入口
│   ├── controllers/       # 控制器层
│   ├── models/            # 数据模型层
│   ├── modules/           # 工具模块
│   ├── middlewares/       # 中间件
│   ├── dto/               # 数据传输对象
│   └── global/            # 全局配置和状态
└── resources/             # 前端静态资源
    ├── index.html         # 主页面
    ├── page/              # 页面模板
    ├── api/               # Mock 数据
    ├── js/                # JavaScript
    ├── css/               # 样式文件
    └── lib/               # 第三方库
```

---

## 4. 核心架构设计

### 4.1 分层架构

```
┌─────────────────────────────────────────┐
│              HTTP Layer (Zap)           │
├─────────────────────────────────────────┤
│              Controllers                │
│   (Login, Menu, Public, Setting, Generic)│
├─────────────────────────────────────────┤
│              Models (ORM)               │
│   (Article, Category, Upload, Role...)  │
├─────────────────────────────────────────┤
│              Global State               │
│   (DB Pool, Config, Allocator)          │
├─────────────────────────────────────────┤
│              PostgreSQL                 │
└─────────────────────────────────────────┘
```

### 4.2 请求处理流程

```
HTTP Request
    ↓
Zap Router → 路由匹配
    ↓
Controller → 业务逻辑
    ↓
Model → 数据操作
    ↓
PostgreSQL → 数据库
    ↓
JSON Response → 返回结果
```

---

## 5. 源代码模块详解

### 5.1 入口文件 (`src/main.zig`)

**主要职责**：
- 初始化内存分配器（GeneralPurposeAllocator）
- 初始化全局配置
- 注册路由
- 启动 HTTP 服务器

**关键代码模式**：
```zig
// 泛型 CRUD 路由注册
const cruds = .{
    .category = models.Category,
    .upload = models.Upload,
    .article = models.Article,
    .role = models.Role,
};

inline for (std.meta.fields(@TypeOf(cruds))) |field| {
    // 为每个模型自动生成 get/list/delete/save/modify/select 接口
}
```

**服务配置**：
- 端口：3000
- 静态资源目录：`resources`
- 最大连接数：10000
- 线程数：4
- 工作者数：4

### 5.2 控制器层 (`src/controllers/`)

| 文件 | 说明 |
|------|------|
| `controllers.zig` | 控制器导出模块 |
| `base.fn.zig` | 基础函数（响应封装、SQL 构建） |
| `generic.controller.zig` | 泛型 CRUD 控制器 |
| `login.controller.zig` | 登录/注册 |
| `menu.controller.zig` | 菜单管理 |
| `public.controller.zig` | 文件上传/目录管理 |
| `setting.controller.zig` | 系统设置 |

#### 5.2.1 泛型控制器 (`generic.controller.zig`)

核心设计：使用 Zig 的 comptime 泛型，为任意模型自动生成 CRUD 操作。

**方法签名**：
```zig
pub fn Generic(comptime T: type) type {
    return struct {
        pub fn list(self: *Self, req: zap.Request) void { ... }
        pub fn get(self: *Self, req: zap.Request) void { ... }
        pub fn delete(self: *Self, req: zap.Request) void { ... }
        pub fn save(self: *Self, req: zap.Request) void { ... }
        pub fn modify(self: *Self, req: zap.Request) void { ... }
        pub fn select(self: *Self, req: zap.Request) void { ... }
    };
}
```

**API 端点模式**：
- `GET /{model}/list` - 分页列表
- `GET /{model}/get?id=X` - 获取单条
- `POST /{model}/save` - 新增/更新
- `POST /{model}/delete` - 删除
- `POST /{model}/modify` - 单字段修改
- `GET /{model}/select` - 下拉选项

#### 5.2.2 基础函数 (`base.fn.zig`)

**响应格式**：
```zig
// 成功响应
{ "code": 0, "msg": "操作成功", "data": {...} }

// 失败响应
{ "code": 500, "msg": "错误信息" }

// 分页响应 (LayUI Table 格式)
{ "code": 0, "count": 100, "msg": "获取列表成功", "data": [...], "extra": {} }
```

**SQL 构建工具**：
- `build_insert_sql(T)` - 根据结构体自动生成 INSERT 语句
- `build_update_sql(T)` - 根据结构体自动生成 UPDATE 语句
- `get_table_name(T)` - 从类型名推导表名（如 `Article` → `zigcms.article`）

### 5.3 模型层 (`src/models/`)

**模型结构规范**：
```zig
pub const Article = struct {
    id: ?i32 = null,           // 主键，可选
    title: []const u8 = "",    // 字符串字段
    status: i32 = 0,           // 整型字段
    create_time: ?i64 = null,  // 时间戳
    update_time: ?i64 = null,  // 时间戳
    is_delete: i32 = 0,        // 软删除标记
};
```

**现有模型**：
| 模型 | 对应表 | 说明 |
|------|--------|------|
| `Admin` | `zigcms.admin` | 管理员 |
| `Article` | `zigcms.article` | 文章 |
| `Category` | `zigcms.category` | 分类 |
| `Upload` | `zigcms.upload` | 上传文件 |
| `Role` | `zigcms.role` | 角色 |
| `Setting` | `zigcms.setting` | 系统设置 |
| `Menu` | `zigcms.menu` | 菜单 |
| `Banner` | `zigcms.banner` | 轮播图 |
| `Task` | `zigcms.task` | 任务 |

### 5.4 全局模块 (`src/global/`)

#### `global.zig`

**职责**：
- 管理全局内存分配器
- 管理 PostgreSQL 连接池
- 管理系统配置缓存

**关键函数**：
```zig
pub fn init(allocator: Allocator) void       // 初始化全局状态
pub fn deinit() void                          // 清理资源
pub fn get_allocator() Allocator              // 获取分配器
pub fn get_pg_pool() *pg.Pool                 // 获取数据库连接池
pub fn get_setting(key, default) []const u8   // 获取配置项
pub fn sql_exec(sql, values) !i64             // 执行 SQL
```

**编译期工具函数**：
```zig
// 将结构体转换为元组（用于 SQL 参数绑定）
pub inline fn struct_2_tuple(T: type) type
```

### 5.5 工具模块 (`src/modules/`)

| 模块 | 说明 |
|------|------|
| `strings.zig` | 字符串处理（split, trim, md5, contains 等） |
| `color.zig` | 终端颜色输出 |
| `redis.zig` | Redis 客户端 |
| `regex.zig` | 正则表达式封装 |
| `github.zig` | GitHub API 集成 |
| `tos.zig` | 对象存储 |

#### `strings.zig` 常用函数
```zig
split(allocator, str, delimiter)    // 字符串分割
eql(str1, str2)                     // 相等判断
contains(haystack, needle)          // 包含判断
starts_with / ends_with             // 前缀/后缀判断
md5(allocator, str)                 // MD5 哈希
trim / ltrim / rtrim                // 去除空白
to_int / to_float                   // 类型转换
sprinf(format, args)                // 格式化字符串
```

### 5.6 中间件 (`src/middlewares/`)

**认证中间件** (`auth.middleware.zig`)：
- 提供请求链式处理
- 实现 JWT Token 验证（目前已注释）
- 可扩展的上下文传递

### 5.7 DTO 层 (`src/dto/`)

**用户相关 DTO**：
```zig
pub const Login = struct { username: []const u8, password: []const u8 };
pub const Register = struct { username: []const u8, password: []const u8 };
```

**分页 DTO**：
```zig
pub const Page = struct {
    page: u32 = 1,
    limit: u32 = 10,
    field: []const u8 = "",
    sort: []const u8 = "",
};
```

---

## 6. API 接口设计

### 6.1 认证接口

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/login` | 用户登录，返回 JWT Token |
| POST | `/register` | 用户注册 |

**登录响应**：
```json
{
  "code": 0,
  "msg": "操作成功",
  "data": {
    "token": "eyJhbGc...",
    "user": { "id": 1, "username": "admin" }
  }
}
```

### 6.2 文件管理接口

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/public/upload` | 文件上传 |
| POST | `/public/folder` | 创建目录 |
| GET/POST | `/public/files` | 获取文件列表 |

**上传响应**：
```json
{
  "code": 0,
  "data": {
    "path": "resources/uploads/abc/def/hash.jpg",
    "url": "/uploads/abc/def/hash.jpg",
    "filename": "original.jpg",
    "cache": false
  }
}
```

### 6.3 泛型 CRUD 接口

以 `article` 为例：

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/article/list?page=1&limit=10&sort[id]=desc` | 分页列表 |
| GET | `/article/get?id=1` | 获取详情 |
| POST | `/article/save` | 新增/更新 |
| POST | `/article/delete` | 删除（支持批量） |
| POST | `/article/modify` | 单字段修改 |
| GET | `/article/select` | 下拉选项 |

---

## 7. 数据库设计

### 7.1 连接配置

```zig
// 从环境变量读取
host: "124.222.103.232"
port: 5432
username: "postgres"
database: "postgres"
pool_size: 10
```

### 7.2 表命名约定

- Schema: `zigcms`
- 表名: 模型名小写（如 `zigcms.article`）
- 主键: `id` (自增)
- 时间戳: `create_time`, `update_time` (微秒级)
- 软删除: `is_delete` (0=正常, 1=删除)

---

## 8. 前端架构

### 8.1 页面结构

```
resources/
├── index.html          # 主框架页面
├── page/
│   ├── login.html      # 登录页
│   ├── article/        # 文章管理页
│   ├── category/       # 分类管理页
│   ├── upload/         # 上传管理页
│   ├── role/           # 角色管理页
│   ├── menu/           # 菜单管理页
│   └── setting.html    # 系统设置页
├── api/
│   └── init.json       # 菜单配置
└── js/
    ├── lay-config.js   # LayUI 配置
    └── public.js       # 公共函数
```

### 8.2 LayUI 配置

- Tab 多页签模式
- 左侧无限级菜单
- 支持主题切换
- 响应式布局

---

## 9. 构建与运行

### 9.1 开发环境

```bash
# 运行开发服务器
zig build run

# 构建发行版
zig build -Doptimize=ReleaseSafe run
```

### 9.2 依赖安装

依赖通过 `build.zig.zon` 自动管理，首次构建时自动下载。

### 9.3 环境变量

必需的环境变量（`.env` 文件）：
```
DB_PASSWORD=<数据库密码>
```

---

## 10. 扩展指南

### 10.1 新增模型

1. 在 `src/models/` 创建 `xxx.model.zig`
2. 在 `src/models/models.zig` 导出
3. 在 `main.zig` 的 `cruds` 中注册

```zig
// 1. 定义模型
pub const Product = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    price: i32 = 0,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
};

// 2. 注册到 cruds
const cruds = .{
    .product = models.Product,
    // ...
};
```

### 10.2 新增控制器

1. 在 `src/controllers/` 创建 `xxx.controller.zig`
2. 在 `src/controllers/controllers.zig` 导出
3. 在 `main.zig` 注册路由

### 10.3 新增中间件

参考 `auth.middleware.zig` 实现 `Handler` 接口。

---

## 11. 注意事项

1. **内存管理**：所有分配的内存需要正确释放，使用 `defer` 确保清理
2. **编译期泛型**：大量使用 `inline for` 和 `comptime`，修改时注意编译期/运行期边界
3. **SQL 注入**：动态 SQL 需使用参数化查询
4. **JWT 认证**：当前 `check_auth` 已注释，生产环境需启用

---

## 12. 文件变更记录

> 每次对项目进行修改时，请更新 `docs/{DATE}/ai_modify.md`。

---

*文档生成时间: 2024-12-04*
*版本: 1.0*
