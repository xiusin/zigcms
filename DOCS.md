# ZigCMS 详细中文文档

## 项目概述

ZigCMS 是一个基于 Zig 语言开发的高性能内容管理系统。该项目采用现代化架构设计，提供完整的后台管理功能和前端界面。核心特性包括：

- **高性能**: 基于 Zig 语言开发，内存安全，零抽象开销
- **全栈支持**: 内置 HTTP 服务器、ORM、缓存等服务
- **模块化架构**: 清晰的分层架构，易于扩展和维护
- **多数据库支持**: 支持 PostgreSQL、MySQL、SQLite
- **后台管理**: 完整的后台管理系统，基于 LayUI 框架
- **RESTful API**: 自动生成 CRUD 接口
- **中间件系统**: 支持认证、日志、CORS 等中间件
- **服务容器**: 依赖注入容器，统一管理服务生命周期

## 项目架构

```
zigcms/
├── src/                    # 源代码目录
│   ├── app.zig            # 应用框架核心
│   ├── main.zig           # 程序入口
│   ├── controllers/       # 控制器层
│   ├── models/            # 数据模型
│   ├── dto/               # 数据传输对象
│   ├── middlewares/       # 中间件
│   ├── modules/           # 功能模块
│   ├── services/          # 服务层
│   └── global/            # 全局配置
├── resources/             # 前端资源
│   ├── page/              # 页面模板
│   ├── css/               # 样式文件
│   ├── js/                # JavaScript 文件
│   └── lib/               # 第三方库
└── docs/                  # 文档目录
```

### 技术栈

**后端**:
- **语言**: Zig (0.15.0+)
- **HTTP 框架**: Zap
- **数据库**: PostgreSQL/MySQL/SQLite
- **ORM**: 自研 SQL ORM
- **缓存**: Redis/内存缓存
- **认证**: JWT

**前端**:
- **框架**: LayUI
- **UI 组件**: Material Design
- **图标**: Font Awesome
- **JavaScript**: jQuery 3.4.1

## 快速开始

### 环境要求

- Zig 0.15.0+
- PostgreSQL/MySQL/SQLite (可选)
- Redis (可选)

### 构建和运行

1. **克隆项目**
```bash
git clone https://e.coding.net/code-eps/products/zigcms.git
cd zigcms
```

2. **构建项目**
```bash
zig build
```

3. **运行开发服务器**
```bash
zig build run
```

4. **生产环境构建**
```bash
zig build -Doptimize=ReleaseSafe run
```

### 配置

项目支持通过环境变量进行配置，主要配置项：

```bash
# 数据库配置
DB_HOST=localhost
DB_PORT=5432
DB_NAME=zigcms
DB_USER=postgres
DB_PASSWORD=password

# Redis 配置
REDIS_HOST=localhost
REDIS_PORT=6379

# JWT 密钥
JWT_SECRET=your-secret-key
```

## 核心模块详解

### 1. 应用框架 (App)

应用框架是整个系统的核心，提供统一的应用入口和服务管理。在 `src/app.zig` 中定义了 `App` 结构体，负责路由注册、服务容器管理和生命周期管理。

主要功能：
- 服务注册与解析
- CRUD 控制器批量注册
- 中间件支持
- 内存安全的生命周期管理

使用示例：
```zig
var app = try App.init(allocator);
defer app.deinit();

// 注册 CRUD 模块
try app.crud("category", models.Category);
try app.crud("article", models.Article);

// 注册自定义路由
try app.route("/login", &login, &controllers.Login.login);

// 启动服务器
try app.listen(3000);
```

### 2. ORM 系统

ZigCMS 拥有强大的自研 ORM 系统，支持多数据库操作：

- **PostgreSQL**: 使用 `pg.zig` 驱动，内部线程安全的连接池
- **MySQL**: 内部自动使用连接池管理，支持自动获取/释放连接
- **SQLite**: 自动启用 WAL 模式，支持多读一写

定义模型示例：
```zig
const User = sql.define(struct {
    pub const table_name = "users";
    pub const primary_key = "id";
    
    id: u64,
    name: []const u8,
    email: []const u8,
    age: ?u32 = null,
    created_at: ?[]const u8 = null,
});
```

使用 ORM 操作：
```zig
// 创建
const user = try User.create(&db, .{
    .name = "张三",
    .email = "zhangsan@example.com",
    .age = 25,
});

// 查询
var users = try User.query(&db)
    .where("age", ">", 18)
    .orderBy("created_at", .desc)
    .limit(10)
    .get();
defer users.deinit();

// 更新
try User.update(&db, 1, .{ .name = "李四" });

// 删除
try User.destroy(&db, 1);
```

### 3. 控制器系统

系统支持自动生成 CRUD 控制器，大大减少重复代码：

```zig
// 自动生成以下路由：
// /category/list    - 列表
// /category/get     - 获取单个
// /category/save    - 保存
// /category/delete  - 删除
// /category/modify  - 修改
// /category/select  - 选择列表
try app.crud("category", models.Category);
```

自定义控制器示例 (`src/controllers/login.zig`)：
```zig
pub const Login = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) Login {
        return .{ .allocator = allocator };
    }
    
    pub fn login(ctrl: *Login, req: zap.Request) !void {
        // 登录逻辑
    }
    
    pub fn register(ctrl: *Login, req: zap.Request) !void {
        // 注册逻辑
    }
};
```

### 4. 中间件系统

支持认证、日志、CORS 等中间件功能：

```zig
// 使用认证中间件
pub const list = MW.requireAuth(listImpl);

// 组合多个中间件
pub const create = MW.compose(createImpl, &.{
    MW.authMiddleware,
    MW.logMiddleware,
    MW.corsMiddleware,
});
```

### 5. 服务容器

依赖注入容器，统一管理服务的生命周期：

```zig
// 获取服务
const services = app.services_ref();
const cache = services.getCache();
const config = services.getConfig();

// 自动管理生命周期
try cache.set("key", "value");
```

## 开发指南

### 添加新的 CRUD 模块

1. **创建模型** (`src/models/new_model.zig`):
```zig
pub const NewModel = struct {
    id: u64,
    name: []const u8,
    // 其他字段...
};
```

2. **注册到应用** (`src/main.zig`):
```zig
try app.crud("new_model", models.NewModel);
```

3. **前端页面** (`resources/page/new_model/`):
- `list.html` - 列表页面
- `save.html` - 编辑页面

### 添加自定义控制器

1. **创建控制器** (`src/controllers/new.controller.zig`):
```zig
pub const NewController = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) NewController {
        return .{ .allocator = allocator };
    }
    
    pub fn newAction(ctrl: *NewController, req: zap.Request) !void {
        // 处理逻辑
    }
};
```

2. **注册路由** (`src/main.zig`):
```zig
var new_ctrl = controllers.New.init(allocator);
try app.route("/new/action", &new_ctrl, &controllers.New.newAction);
```

### 数据库操作

#### 原生 SQL
```zig
// 查询
const result = try db.rawQuery("SELECT * FROM users WHERE age > ?", .{18});
defer result.deinit();

// 执行
try db.rawExec("INSERT INTO users (name) VALUES (?)", .{"张三"});
```

#### 事务
```zig
// 自动管理事务
try db.transaction(struct {
    fn run(db_ref: *sql.Database) !void {
        try db_ref.rawExec("INSERT INTO users ...");
        try db_ref.rawExec("INSERT INTO logs ...");
        // 自动提交，出错自动回滚
    }
}.run, .{});
```

## 依赖管理

项目使用 Zig 的内置包管理器，主要依赖在 `build.zig.zon` 中定义：

```zig
// build.zig.zon
.dependencies = .{
    .zap = .{ .url = "https://github.com/zigzap/zap/archive/master.tar.gz" },
    .pg = .{ .url = "git+https://github.com/karlseguin/pg.zig" },
    .sqlite = .{ .url = "https://github.com/vrischmann/zig-sqlite/archive/master.tar.gz" },
    .regex = .{ .url = "https://github.com/tiehuis/zig-regex/archive/master.tar.gz" },
    // 其他依赖...
}
```

## 测试

### 运行测试
```bash
# 运行所有测试
zig build test

# 运行特定测试
zig build test --test-filter "sql"
```

### 数据库测试

#### SQLite 测试
```bash
cd src/services/sql
zig build-exe sqlite_complete_test.zig -lc -lsqlite3
./sqlite_complete_test
```

#### MySQL 测试
```bash
cd src/services/sql

# macOS (Homebrew)
zig build-exe mysql_complete_test.zig -lc -lmysqlclient \
  -I /opt/homebrew/include \
  -L /opt/homebrew/lib

# Linux
zig build-exe mysql_complete_test.zig -lc -lmysqlclient
```

#### PostgreSQL 测试
```bash
# 创建测试数据库
psql -U postgres -c "CREATE DATABASE test_zigcms;"

# 运行测试
zig build
```

### 数据库测试覆盖

每种驱动都有完整测试覆盖：

- **CRUD 操作** - 创建、读取、更新、删除及结果验证
- **QueryBuilder** - SQL 构造器测试
- **事务** - 提交/回滚/自动事务
- **高级查询** - 子查询、EXISTS、NOT EXISTS
- **JOIN 查询** - INNER/LEFT/多表关联
- **边界条件** - NULL 值、特殊字符、Unicode、大数据量
- **内存安全** - GPA 检测内存泄漏
- **连接池** - MySQL 连接池特性（仅 MySQL）

## 安全特性

- **JWT 认证**: 基于 JSON Web Token 的用户认证
- **中间件保护**: 路由级别的权限控制
- **SQL 注入防护**: ORM 自动参数化查询
- **XSS 防护**: 前端输入过滤和转义
- **CSRF 防护**: 请求令牌验证

## 性能优化

- **连接池**: MySQL/PostgreSQL 连接池管理
- **缓存系统**: 多层缓存策略
- **静态资源**: CDN 和缓存优化
- **压缩传输**: Gzip 压缩支持
- **异步处理**: 非阻塞 I/O 操作

## 部署

### Docker 部署
```dockerfile
FROM alpine:latest
RUN apk add --no-cache postgresql-libs
COPY zig-out/bin/vendor /app/
WORKDIR /app
EXPOSE 3000
CMD ["./vendor"]
```

### 系统服务
创建 systemd 服务文件：

```ini
[Unit]
Description=ZigCMS
After=network.target

[Service]
Type=simple
User=zigcms
WorkingDirectory=/opt/zigcms
ExecStart=/opt/zigcms/vendor
Restart=always

[Install]
WantedBy=multi-user.target
```

## 主要源代码文件详解

### src/main.zig - 程序入口
这是应用程序的主入口点，负责初始化应用、注册路由和启动服务器。

关键功能：
- 初始化应用框架
- 注册 CRUD 模块（category、upload、article、role）
- 注册自定义控制器（登录、公共接口、菜单、设置）
- 启动 HTTP 服务器（端口 3000）

### src/app.zig - 应用框架核心
定义了 `App` 结构体和应用框架的核心功能，包括服务容器、路由管理和生命周期管理。

主要结构：
- `App`: 应用实例，包含路由器、服务容器等
- `Services`: 服务容器，管理缓存、配置等服务的生命周期

### 模型文件 (src/models/)
包含所有数据模型定义，每个模型定义了数据库表结构及字段类型。
- `admin.model.zig`: 管理员模型
- `article.model.zig`: 文章模型
- `category.model.zig`: 分类模型
- `setting.model.zig`: 设置模型
- 等等...

### 控制器文件 (src/controllers/)
包含所有控制器实现，处理 HTTP 请求和响应。
- `Login`: 登录控制器
- `Public`: 公共接口控制器
- `Menu`: 菜单控制器
- `Setting`: 设置控制器
- `Crud`: 通用 CRUD 控制器

## 环境代理配置

如果在使用 `zig fetch` 时遇到问题，需要取消代理设置：

```bash
# Git 代理
git config --global --unset http.proxy
git config --global --unset https.proxy

# 系统代理
unset http_proxy https_proxy

# HTTP 版本协议变更
git config --global http.version HTTP/1.1
```

## 相关链接

- [Zig 官网](https://ziglang.org/)
- [Zap 框架](https://github.com/zigzap/zap)
- [LayUI 框架](https://www.layui.com/)
- [项目仓库](https://e.coding.net/code-eps/products/zigcms.git)

## 许可证

本项目采用 MIT 许可证。