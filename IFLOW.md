# ZigCMS - 基于 Zig 的高性能内容管理系统

## 📋 项目概述

ZigCMS 是一个使用 Zig 语言开发的高性能内容管理系统，采用现代化的架构设计，提供完整的后台管理功能和前端界面。

### 核心特性

- **高性能**: 基于 Zig 语言开发，内存安全，零抽象开销
- **全栈支持**: 内置 HTTP 服务器、ORM、缓存等服务
- **模块化架构**: 清晰的分层架构，易于扩展和维护
- **多数据库支持**: 支持 PostgreSQL、MySQL、SQLite
- **后台管理**: 完整的后台管理系统，基于 LayUI 框架
- **RESTful API**: 自动生成 CRUD 接口
- **中间件系统**: 支持认证、日志、CORS 等中间件
- **服务容器**: 依赖注入容器，统一管理服务生命周期

## 🏗️ 项目架构

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

## 🚀 快速开始

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

## 📚 核心模块

### 1. 应用框架 (App)

应用框架提供统一的应用入口和服务管理：

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

强大的 ORM 系统，支持多数据库：

```zig
// 定义模型
const User = sql.define(struct {
    pub const table_name = "users";
    pub const primary_key = "id";
    
    id: u64,
    name: []const u8,
    email: []const u8,
});

// 使用 ORM
const user = try User.create(&db, .{
    .name = "张三",
    .email = "zhangsan@example.com",
});

var users = try User.query(&db)
    .where("age", ">", 18)
    .orderBy("created_at", .desc)
    .limit(10)
    .get();
```

### 3. 控制器系统

自动生成 CRUD 控制器：

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

### 4. 中间件系统

支持认证、日志、CORS 等中间件：

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

依赖注入容器，统一管理服务：

```zig
// 获取服务
const services = app.services_ref();
const cache = services.getCache();
const config = services.getConfig();

// 自动管理生命周期
try cache.set("key", "value");
```

## 🔧 开发指南

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

## 📦 依赖管理

项目使用 Zig 的内置包管理器，主要依赖：

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

## 🧪 测试

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

## 🔒 安全特性

- **JWT 认证**: 基于 JSON Web Token 的用户认证
- **中间件保护**: 路由级别的权限控制
- **SQL 注入防护**: ORM 自动参数化查询
- **XSS 防护**: 前端输入过滤和转义
- **CSRF 防护**: 请求令牌验证

## 📊 性能优化

- **连接池**: MySQL/PostgreSQL 连接池管理
- **缓存系统**: 多层缓存策略
- **静态资源**: CDN 和缓存优化
- **压缩传输**: Gzip 压缩支持
- **异步处理**: 非阻塞 I/O 操作

## 🌐 部署

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

## 🤝 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🔗 相关链接

- [Zig 官网](https://ziglang.org/)
- [Zap 框架](https://github.com/zigzap/zap)
- [LayUI 框架](https://www.layui.com/)
- [项目仓库](https://e.coding.net/code-eps/products/zigcms.git)

## 📝 更新日志

### v0.1.0 (当前版本)
- 初始版本发布
- 基础 CRUD 功能
- 用户认证系统
- 后台管理界面
- 多数据库支持

---

**注意**: 这是一个活跃开发中的项目，API 可能会发生变化。建议在生产环境使用前进行充分测试。