# ZigCMS 技术架构与功能文档

## 目录

1. [项目概述](#1-项目概述)
2. [技术栈](#2-技术栈)
3. [架构设计](#3-架构设计)
4. [核心模块详解](#4-核心模块详解)
5. [功能特性](#5-功能特性)
6. [配置管理](#6-配置管理)
7. [依赖注入系统](#7-依赖注入系统)
8. [ORM 与数据库](#8-orm-与数据库)
9. [API 层](#9-api-层)
10. [命令行工具](#10-命令行工具)
11. [插件系统](#11-插件系统)
12. [测试策略](#12-测试策略)
13. [性能优化](#13-性能优化)
14. [安全机制](#14-安全机制)
15. [开发指南](#15-开发指南)
16. [部署运维](#16-部署运维)

---

## 1. 项目概述

### 1.1 简介

ZigCMS 是一个基于 Zig 语言开发的现代化 CMS（内容管理系统），具备高性能、内存安全和易扩展的特性。项目采用整洁架构（Clean Architecture）并深度集成了依赖注入（DI）机制。

**核心特性：**
- 🏗️ **整洁架构**：严格的分层设计，确保业务逻辑高度独立
- 💉 **自动依赖注入**：基于 Arena 托管的全局 DI 容器，实现服务的自动化装配与零泄漏清理
- 🗄️ **Laravel 风格 ORM**：增强型 QueryBuilder，支持链式调用及模型关联
- 🛠️ **工程化工具链**：模块化的 CLI 工具集，支持代码生成、数据库迁移及插件管理
- 💾 **统一缓存契约**：标准化的 `CacheInterface`，支持内存与 Redis 驱动的无缝切换

### 1.2 项目定位

ZigCMS 定位为：
- **企业级 CMS 系统**：适用于中小型企业的内容管理需求
- **高性能 Web 框架**：可作为 RESTful API 服务框架使用
- **领域驱动设计典范**：展示如何用 Zig 语言实现 DDD 架构

### 1.3 版本信息

- **当前版本**：2.0.0
- **Zig 语言版本**：0.15.0+
- **许可证**：MIT

---

## 2. 技术栈

### 2.1 核心语言

| 技术 | 用途 | 优势 |
|------|------|------|
| Zig 0.15.0+ | 系统开发语言 | 内存安全、零成本抽象、编译时计算 |
| std 标准库 | 基础库 | 完善的数据结构、内存管理、并发支持 |

### 2.2 外部依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| zap | latest | HTTP 服务器框架 |
| sqlite | latest | SQLite 数据库驱动 |
| pg | latest | PostgreSQL 数据库驱动 |
| regex | latest | 正则表达式 |
| smtp_client | latest | SMTP 邮件客户端 |
| curl | latest | HTTP 客户端 |

### 2.3 数据库支持

- **SQLite**：内置支持，开发环境首选
- **MySQL/MariaDB**：生产环境使用
- **PostgreSQL**：企业级应用

### 2.4 构建工具

- **Zig Build System**：原生构建系统
- **Makefile**：开发命令快捷方式

---

## 3. 架构设计

### 3.1 整洁架构概述

ZigCMS 采用 Robert C. Martin 提出的整洁架构（Clean Architecture）模式，将系统分为五个清晰的层次，每层都有明确的职责和依赖规则。

```
┌─────────────────────────────────────────────────────────────────┐
│                        API 层 (api/)                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Controllers  │  │     DTO      │  │  Middleware  │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│  职责: HTTP 请求处理、参数验证、响应格式化                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓ 依赖
┌─────────────────────────────────────────────────────────────────┐
│                     应用层 (application/)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   UseCases   │  │   Services   │  │   Handlers   │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│  职责: 业务流程编排、用例实现、事务管理                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓ 依赖
┌─────────────────────────────────────────────────────────────────┐
│                      领域层 (domain/)                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Entities   │  │   Services   │  │ Repositories │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│  职责: 核心业务逻辑、业务规则、领域模型                        │
└─────────────────────────────────────────────────────────────────┘
                              ↑ 实现
┌─────────────────────────────────────────────────────────────────┐
│                  基础设施层 (infrastructure/)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Database   │  │     Cache    │  │  HttpClient  │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│  职责: 外部服务实现、数据持久化、第三方集成                    │
└─────────────────────────────────────────────────────────────────┘
                              
┌─────────────────────────────────────────────────────────────────┐
│                      共享层 (shared/)                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │    Utils     │  │  Primitives  │  │    Types     │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│  职责: 通用工具、基础原语、共享类型（被所有层使用）            │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 依赖规则

| 方向 | 允许的依赖 | 禁止的依赖 |
|------|-----------|-----------|
| API → 应用 | ✅ | ❌ |
| API → 基础设施 | ❌ | ❌ |
| 应用 → 领域 | ✅ | ❌ |
| 应用 → 基础设施 | ✅（通过接口） | ❌ |
| 领域 | ❌ | ❌（核心层） |
| 基础设施 → 领域 | ✅（实现接口） | ❌ |
| 共享 | ❌ | ❌（被所有层使用） |

### 3.3 各层职责详解

#### 3.3.1 共享层 (shared/)

**职责**：提供跨层共享的通用组件

**包含组件**：
- `utils/` - 工具函数（字符串、时间、加密等）
- `primitives/` - 基础原语（全局变量、容器、注册表）
- `types/` - 通用类型定义
- `errors/` - 统一错误处理
- `config/` - 配置加载器
- `di/` - 依赖注入容器
- `context/` - 应用上下文

**设计原则**：
- 不依赖任何业务层
- 被所有层使用
- 保持轻量级

#### 3.3.2 领域层 (domain/)

**职责**：包含核心业务逻辑和规则，是系统的核心

**包含组件**：
- `entities/` - 业务实体（Admin, Article, Category, Member 等）
- `services/` - 领域服务（业务规则验证）
- `repositories/` - 仓库接口（数据访问契约）

**实体列表**：
| 实体 | 说明 | 主要字段 |
|------|------|---------|
| Admin | 管理员 | username, password, role_id |
| Article | 文章 | title, content, category_id, status |
| Category | 分类 | name, parent_id, sort_order |
| Member | 会员 | username, email, group_id, points |
| Role | 角色 | name, permissions |
| Upload | 上传文件 | filename, path, size, type |
| Dict | 字典 | type, code, value |
| CmsModel | CMS 模型 | name, table_name |
| CmsField | CMS 字段 | model_id, name, type |
| Document | 文档 | title, content, model_id |
| MaterialCategory | 素材分类 | name, parent_id |
| Material | 素材 | title, file_path, category_id |
| FriendLink | 友链 | name, url, logo |
| Banner | 轮播图 | title, image_url, link |
| Department | 部门 | name, parent_id, code |
| Employee | 员工 | name, department_id, position_id |
| Position | 职位 | name, level, department_id |
| Task | 任务 | title, status, assignee_id |
| Setting | 系统设置 | key, value |

**设计原则**：
- 不依赖任何其他层
- 封装核心业务规则
- 使用值对象（Value Objects）确保数据有效性

#### 3.3.3 应用层 (application/)

**职责**：编排业务流程，协调领域服务和基础设施服务

**包含组件**：
- `services/` - 应用服务
  - `orm/` - ORM 实现
  - `sql/` - SQL 驱动
  - `logger/` - 日志服务
  - `cache/` - 缓存服务
  - `user_service.zig` - 用户服务
  - `member_service.zig` - 会员服务
  - `auth_service.zig` - 认证服务
- `mod.zig` - 应用层入口

**设计原则**：
- 协调业务流程，不包含核心业务规则
- 使用依赖注入获取服务
- 管理事务边界

#### 3.3.4 API 层 (api/)

**职责**：处理 HTTP 请求和响应，作为系统的入口点

**包含组件**：
- `controllers/` - HTTP 控制器
  - `auth/` - 认证控制器（Login）
  - `admin/` - 管理控制器（Menu, Setting）
  - `common/` - 通用控制器（Public）
  - CRUD 控制器（自动生成）
- `dto/` - 数据传输对象
- `middleware/` - 中间件
- `App.zig` - 应用框架核心
- `Application.zig` - 应用入口
- `bootstrap.zig` - 启动编排

**路由统计**：
- CRUD 模块：13 个（每个模块 6 条路由）
- 自定义路由：12 条
- 总计：约 90 条路由

**设计原则**：
- 薄控制器，厚服务
- 只处理 HTTP 相关逻辑
- 验证输入，格式化输出

#### 3.3.5 基础设施层 (infrastructure/)

**职责**：实现外部服务接口，提供技术能力

**包含组件**：
- `database/` - 数据库实现
- `cache/` - 缓存实现
- `http/` - HTTP 客户端
- `messaging/` - 消息系统
- `mod.zig` - 基础设施层入口

**设计原则**：
- 实现领域层定义的接口
- 不依赖 API 层和应用层
- 技术选型可替换

---

## 4. 核心模块详解

### 4.1 程序入口 (main.zig)

```zig
//! ZigCMS 主程序入口
//!
//! 职责：
//! - 初始化内存分配器
//! - 创建并启动应用实例
//!
//! 遵循整洁架构原则，main.zig 只负责高层初始化，
//! 具体的配置加载、系统初始化、路由注册等逻辑委托给 Application 模块处理。

const std = @import("std");
const Application = @import("api/Application.zig").Application;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            std.debug.print("⚠️ 检测到内存泄漏\n", .{});
        } else {
            std.debug.print("✅ 服务器正常退出，无内存泄漏\n", .{});
        }
    }
    const allocator = gpa.allocator();

    var app = try Application.create(allocator);
    defer app.destroy();

    try app.run();
}
```

**职责**：
1. 初始化 GPA（通用目的分配器）
2. 创建 Application 实例
3. 运行应用
4. 清理资源

### 4.2 应用入口 (Application.zig)

```zig
pub const Application = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    config: SystemConfig,
    app: App,
    bootstrap: Bootstrap,
    global_logger: *logger.Logger,
    system_initialized: bool,
    app_context: *AppContext,
    
    pub fn create(allocator: std.mem.Allocator) !*Self {
        // 1. 加载配置
        const config = try zigcms.loadSystemConfig(allocator);
        
        // 2. 初始化系统
        try zigcms.initSystem(allocator, config);
        
        // 3. 初始化日志
        try logger.initDefault(allocator, .{ .level = .debug, .format = .colored });
        const global_logger = logger.getDefault() orelse return error.LoggerInitFailed;
        
        // 4. 创建 App
        var app = try App.init(allocator);
        errdefer app.deinit();
        
        // 5. 创建应用上下文
        const container = zigcms.shared.di.getGlobalContainer() orelse return error.DIContainerNotInitialized;
        const db = zigcms.shared.global.get_db();
        const app_context = try AppContext.init(allocator, &config, db, container);
        errdefer app_context.deinit();
        
        // 6. 创建 Bootstrap
        const bootstrap = try Bootstrap.init(allocator, &app, global_logger, container, app_context);
        
        // 7. 注册路由
        try bootstrap.registerRoutes();
        
        return app_ptr;
    }
    
    pub fn run(self: *Self) !void {
        self.bootstrap.printStartupSummary();
        try self.app.listen();
    }
};
```

### 4.3 启动编排 (Bootstrap.zig)

**职责**：
- 按正确顺序初始化各层
- 注册路由
- 配置服务
- 提供启动摘要信息

```zig
pub const Bootstrap = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    app: *App,
    global_logger: *logger.Logger,
    container: *DIContainer,
    app_context: *AppContext,
    route_count: usize,
    crud_count: usize,

    pub fn registerRoutes(self: *Self) !void {
        // 1. 注册 CRUD 模块
        try self.registerCrudModules();

        // 2. 注册自定义控制器路由
        try self.registerCustomRoutes();
    }
    
    fn registerCrudModules(self: *Self) !void {
        try self.app.crud("category", models.Category);
        try self.app.crud("upload", models.Upload);
        try self.app.crud("article", models.Article);
        try self.app.crud("role", models.Role);
        try self.app.crud("dict", models.Dict);
        // ... 更多模块
    }
    
    fn registerCustomRoutes(self: *Self) !void {
        try self.registerAuthRoutes();
        try self.registerPublicRoutes();
        try self.registerAdminRoutes();
    }
};
```

### 4.4 根模块 (root.zig)

**职责**：作为库使用时的入口点，导出所有公共 API

```zig
//! ZigCMS 根模块 - 库入口点
//!
//! 本模块是 ZigCMS 作为库使用时的入口点，导出所有公共 API。

pub const api = @import("api/Api.zig");
pub const application = @import("application/mod.zig");
pub const domain = @import("domain/mod.zig");
pub const infrastructure = @import("infrastructure/mod.zig");
pub const shared = @import("shared/mod.zig");
pub const sql = @import("application/services/sql/mod.zig");
pub const redis = @import("application/services/redis/mod.zig");
pub const cache_drivers = @import("application/services/cache_drivers.zig");
```

---

## 5. 功能特性

### 5.1 用户认证

**功能模块**：`controllers.auth.Login`

| 功能 | 路由 | 方法 | 说明 |
|------|------|------|------|
| 登录 | /login | POST | 用户登录，获取 Token |
| 注册 | /register | POST | 新用户注册 |

**认证流程**：
```
HTTP Request → AuthMiddleware → JWT 验证 → 设置用户上下文 → Controller
```

### 5.2 CRUD 操作

系统自动为每个数据模型生成 6 个标准 CRUD 路由：

| 路由 | 方法 | 说明 |
|------|------|------|
| /:model/list | GET | 获取列表（支持分页、排序、筛选） |
| /:model/get/:id | GET | 获取单条记录 |
| /:model/save | POST | 创建新记录 |
| /:model/modify | POST | 更新记录 |
| /:model/delete | POST | 删除记录 |
| /:model/select | GET | 获取选择列表 |

**支持的模型**：
- 基础模块：Category, Upload, Article, Role, Dict
- CMS 模块：CmsModel, CmsField, Document, MaterialCategory, Material
- 会员模块：MemberGroup, Member
- 友链模块：FriendLink

### 5.3 文件上传

**功能模块**：`controllers.common.Public`

| 功能 | 路由 | 方法 | 说明 |
|------|------|------|------|
| 上传文件 | /public/upload | POST | 文件上传 |
| 创建文件夹 | /public/folder | POST | 创建文件夹 |
| 文件列表 | /public/files | GET | 获取文件列表 |

### 5.4 系统设置

**功能模块**：`controllers.admin.Setting`

| 功能 | 路由 | 方法 | 说明 |
|------|------|------|------|
| 获取设置 | /setting/get | GET | 获取系统设置 |
| 保存设置 | /setting/save | POST | 保存系统设置 |
| 发送测试邮件 | /setting/send_email | POST | 发送测试邮件 |
| 获取上传配置 | /setting/upload_config/get | GET | 获取上传配置 |
| 保存上传配置 | /setting/upload_config/save | POST | 保存上传配置 |
| 测试上传配置 | /setting/upload_config/test | POST | 测试上传配置 |

### 5.5 菜单管理

**功能模块**：`controllers.admin.Menu`

| 功能 | 路由 | 方法 | 说明 |
|------|------|------|------|
| 菜单列表 | /menu/list | GET | 获取菜单树形结构 |

---

## 6. 配置管理

### 6.1 配置文件结构

```
configs/
├── api.toml      # API 服务器配置
├── app.toml      # 应用配置
├── domain.toml   # 领域层配置
├── infra.toml    # 基础设施配置
└── README.md     # 配置说明
```

### 6.2 配置项说明

#### 6.2.1 API 配置 (api.toml)

```toml
[api]
host = "0.0.0.0"           # 监听地址
port = 3000                # 监听端口
max_clients = 10000        # 最大连接数
timeout = 30               # 请求超时（秒）
public_folder = "public"   # 静态资源目录
```

#### 6.2.2 应用配置 (app.toml)

```toml
[app]
enable_cache = true        # 启用缓存
cache_ttl_seconds = 3600   # 缓存 TTL（秒）
max_concurrent_tasks = 100 # 最大并发任务数
enable_plugins = true      # 启用插件系统
plugin_directory = "plugins" # 插件目录
```

#### 6.2.3 领域配置 (domain.toml)

```toml
[domain]
validate_models = true     # 验证模型
enforce_business_rules = true # 强制业务规则
```

#### 6.2.4 基础设施配置 (infra.toml)

```toml
[infra]
# 数据库配置
db_host = "localhost"
db_port = 5432
db_name = "zigcms"
db_user = "postgres"
db_password = "password"
db_pool_size = 10          # 连接池大小

# 缓存配置
cache_enabled = true
cache_host = "localhost"
cache_port = 6379
cache_ttl = 3600           # 缓存 TTL（秒）
cache_password = null      # Redis 密码（可选）

# HTTP 配置
http_timeout_ms = 30000    # HTTP 超时（毫秒）
```

### 6.3 配置加载流程

```
configs/*.toml → ConfigLoader → SystemConfig → 内存
                      ↓
              环境变量覆盖
```

### 6.4 配置使用示例

```zig
const SystemConfig = @import("shared/config/system_config.zig").SystemConfig;

pub fn example() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 从配置文件加载
    const config = try zigcms.loadSystemConfig(allocator);

    // 使用配置
    std.debug.print("Server: {s}:{d}\n", .{ config.api.host, config.api.port });
    std.debug.print("Database: {s}@{s}:{d}/{s}\n", .{
        config.infra.db_user,
        config.infra.db_host,
        config.infra.db_port,
        config.infra.db_name,
    });
}
```

---

## 7. 依赖注入系统

### 7.1 概述

ZigCMS 使用自定义的依赖注入（DI）容器来管理服务生命周期，支持：
- 单例模式（Singleton）：全局唯一实例
- 瞬态模式（Transient）：每次请求创建新实例
- 实例注册：直接注册已有实例

### 7.2 容器结构

```zig
pub const DIContainer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    descriptors: std.StringHashMap(ServiceDescriptor),
    singletons: std.StringHashMap(*anyopaque),
    initialized: bool = false,

    pub fn init(allocator: std.mem.Allocator) Self { ... }
    
    pub fn registerSingleton(...) !void { ... }
    pub fn registerTransient(...) !void { ... }
    pub fn registerInstance(...) !void { ... }
    pub fn resolve(...) !*ServiceType { ... }
    pub fn isRegistered(...) bool { ... }
    pub fn deinit(self: *Self) void { ... }
};
```

### 7.3 服务注册

#### 7.3.1 注册单例

```zig
try container.registerSingleton(UserService, UserService, struct {
    fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*UserService {
        const user_repo = try di.resolve(UserRepository);
        const user_service = try allocator.create(UserService);
        user_service.* = UserService.init(allocator, user_repo.*);
        return user_service;
    }
}.factory, null);
```

#### 7.3.2 注册瞬态

```zig
try container.registerTransient(
    ControllerType,
    ControllerType,
    struct {
        fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*ControllerType {
            const service = try di.resolve(ServiceType);
            const ctrl = try allocator.create(ControllerType);
            ctrl.* = ControllerType.init(allocator, service);
            return ctrl;
        }
    }.factory,
);
```

#### 7.3.3 注册实例

```zig
try container.registerInstance(ServiceType, &service_instance, null);
```

### 7.4 服务解析

```zig
const user_service = try container.resolve(UserService);
```

### 7.5 服务生命周期

```
┌──────────────────────────────────────────────────────────────┐
│                    服务生命周期                              │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Singleton:                                                  │
│  ┌─────────┐                                                 │
│  │  创建   │ ──→ 缓存实例 ──→  返回同一实例                   │
│  └─────────┘                                                 │
│                                                              │
│  Transient:                                                 │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐                │
│  │  创建   │ ──→ │  使用   │ ──→ │  销毁   │                │
│  └─────────┘     └─────────┘     └─────────┘                │
│                                                              │
│  每次请求创建新实例                                           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 7.6 内存管理

DI 容器使用 Arena Allocator 统一管理单例生命周期：

```zig
pub fn deinit(self: *Self) void {
    // 清理所有 singleton 实例
    var desc_it = self.descriptors.iterator();
    while (desc_it.next()) |entry| {
        const descriptor = entry.value_ptr.*;
        if (descriptor.lifetime == .Singleton) {
            if (descriptor.deinit_fn) |deinit_fn| {
                deinit_fn(instance, self.allocator);
            }
        }
    }
    
    self.singletons.deinit();
    self.descriptors.deinit();
}
```

---

## 8. ORM 与数据库

### 8.1 ORM 概述

ZigCMS 提供类似 Laravel Eloquent 的 ORM 系统，支持：
- 链式查询构建器
- 模型定义
- CRUD 操作
- 多数据库支持

### 8.2 模型定义

```zig
const orm = @import("services").sql.orm;

// 定义模型
const User = orm.define(struct {
    pub const table_name = "users";
    pub const primary_key = "id";

    id: u64,
    name: []const u8,
    email: []const u8,
    age: ?u32 = null,
    created_at: ?[]const u8 = null,
});
```

### 8.3 查询构建器

#### 8.3.1 基本查询

```zig
// 获取所有记录
const users = try User.query(&db).get();

// 带条件查询
const adult_users = try User.query(&db)
    .where("age", ">", 18)
    .orderBy("created_at", .desc)
    .limit(10)
    .get();

// 获取单条记录
const user = try User.find(&db, 1);

// 带条件获取单条
const user = try User.query(&db)
    .where("email", "=", "test@example.com")
    .first();
```

#### 8.3.2 条件构建器

```zig
// 简单条件
.where("status", "=", "active")

// 比较操作符
.where("age", ">", 18)
.where("score", "<=", 100)
.where("name", "like", "%test%")

// IN 查询
.whereIn("id", &.{ 1, 2, 3 })

// BETWEEN
.whereBetween("created_at", "2024-01-01", "2024-12-31")

// NULL 检查
.whereNull("deleted_at")
.whereNotNull("updated_at")
```

#### 8.3.3 排序与分页

```zig
// 排序
.orderBy("created_at", .asc)   // 升序
.orderBy("id", .desc)          // 降序

// 分页
.offset(20)
.limit(10)
```

#### 8.3.4 聚合查询

```zig
// 计数
const count = try User.query(&db).count();

// 求和
const total = try User.query(&db).sum("score");

// 平均值
const avg = try User.query(&db).avg("score");

// 最大/最小
const max = try User.query(&db).max("score");
const min = try User.query(&db).min("score");
```

### 8.4 CRUD 操作

#### 8.4.1 创建

```zig
// 单条创建
const user = try User.create(&db, .{
    .name = "张三",
    .email = "zhangsan@example.com",
    .age = 25,
});

// 批量创建
try User.insertMany(&db, &.{
    .{ .name = "李四", .email = "lisi@example.com" },
    .{ .name = "王五", .email = "wangwu@example.com" },
});
```

#### 8.4.2 读取

```zig
// 按 ID 查找
const user = User.find(&db, 1);

// 查找或失败
const user = try User.findOrFail(&db, 1);

// 获取第一个
const user = try User.first(&db);

// 获取最后一个
const user = try User.last(&db);
```

#### 8.4.3 更新

```zig
// 按 ID 更新
try User.update(&db, 1, .{
    .name = "新名字",
    .age = 30,
});

// 条件更新
try User.query(&db)
    .where("status", "=", "inactive")
    .update(.{ .status = "active" });
```

#### 8.4.4 删除

```zig
// 按 ID 删除
try User.destroy(&db, 1);

// 条件删除
try User.query(&db)
    .where("status", "=", "deleted")
    .delete();
```

### 8.5 查询结果

使用 `QueryResult` 自动管理内存：

```zig
var result = try QueryResult(User).fromAll(db, allocator);
defer result.deinit();

for (result.items()) |user| {
    std.debug.print("User: {s}\n", .{user.name});
}
```

### 8.6 SQL 注入防护

```zig
/// 转义 SQL 字符串中的危险字符以防止 SQL 注入
/// 转义: 单引号('), 反斜杠(\), NULL字节(\0), 换行(\n), 回车(\r), 双引号(")
pub fn escapeSqlString(allocator: Allocator, str: []const u8) ![]u8 { ... }
```

### 8.7 JSON 字段支持

#### 8.7.1 JsonField 类型

支持将复杂结构体存储为 JSON 字符串：

```zig
const sql = @import("services").sql;

// 定义嵌套结构体
const Metadata = struct {
    avatar: []const u8,
    bio: ?[]const u8,
    socials: []SocialLink,
};

const SocialLink = struct {
    platform: []const u8,
    url: []const u8,
};

// 模型中使用 JsonField
const User = struct {
    id: u64,
    name: []const u8,
    metadata: sql.JsonField(Metadata),  // JSON 字段
};
```

#### 8.7.2 JsonArray 类型

支持 JSON 数组字段：

```zig
const Tags = struct {
    tags: [][]const u8,
};

const Article = struct {
    id: u64,
    title: []const u8,
    tags: sql.JsonArray([]const u8),  // JSON 字符串数组
};
```

#### 8.7.3 自动序列化/反序列化

```zig
// 从数据库加载（自动反序列化）
const user = try User.find(1);
if (user.metadata.get()) |meta| {
    std.debug.print("Avatar: {s}\n", .{meta.avatar});
    std.debug.print("Bio: {s}\n", .{meta.bio orelse "N/A"});
}

// 保存到数据库（自动序列化）
const new_metadata = Metadata{
    .avatar = "https://example.com/avatar.png",
    .bio = "Hello world",
    .socials = &.{
        .{ .platform = "github", .url = "https://github.com/user" },
    },
};

// 设置值（标记为 dirty）
user.metadata.set(new_metadata);
```

#### 8.7.4 JSON 查询

支持 PostgreSQL JSONB 和 MySQL JSON 查询：

```zig
// JSON 值等于
try User.query()
    .whereJsonEquals("metadata", "avatar", "https://example.com/avatar.png")
    .get();

// JSON 数组包含
try User.query()
    .whereJsonContains("tags", "vip")
    .get();

// JSON 数组长度
try Article.query()
    .whereJsonArrayLength("tags", ">", 3)
    .get();

// JSON 键存在检查
try User.query()
    .whereJsonHasKey("config", "beta_features")
    .get();

// JSON 路径提取比较
try User.query()
    .whereJsonExtractEquals("data", "{level,key}", "enabled")
    .get();
```

#### 8.7.5 JSON 查询 SQL 示例

| 方法 | PostgreSQL | MySQL |
|------|-----------|-------|
| 值比较 | `(field->>'key') = 'value'` | `JSON_UNQUOTE(field->'$.key') = 'value'` |
| 包含 | `field @> '["value"]'` | `JSON_CONTAINS(field, '"value"')` |
| 键存在 | `field ? 'key'` | `JSON_CONTAINS_PATH(field, 'one', '$.key')` |
| 路径提取 | `field#>>'{a,b}'` | `JSON_EXTRACT(field, '$.a.b')` |

### 8.8 数据库驱动

| 驱动 | 文件 | 特点 |
|------|------|------|
| SQLite | `sqlite_*.zig` | 内置支持，开发首选 |
| MySQL | `mysql_*.zig` | 生产环境使用 |
| PostgreSQL | `postgres_*.zig` | 企业级应用 |

---

## 9. API 层

### 9.1 控制器结构

```zig
pub const UserController = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    user_usecase: *UserUseCase,

    pub fn create(self: *Self, req: zap.Request) !void {
        // 1. 解析 DTO
        const dto = try req.parseBody(UserCreateDto);
        
        // 2. 调用用例
        const user = try self.user_usecase.register(dto);
        
        // 3. 返回响应
        try req.sendJson(.{ .code = 0, .data = user });
    }
};
```

### 9.2 中间件

```zig
pub const AuthMiddleware = struct {
    pub fn handle(req: *zap.Request, next: *const fn (*zap.Request) anyerror!void) !void {
        // 验证 Token
        const auth_header = req.header("Authorization") orelse return error.Unauthorized;
        
        // 解析 JWT
        const claims = try verifyToken(auth_header);
        
        // 设置用户上下文
        req.setUserContext(claims);
        
        // 调用下一个处理器
        try next(req);
    }
};
```

### 9.3 响应格式

```json
// 成功响应
{
    "code": 0,
    "message": "success",
    "data": { ... }
}

// 错误响应
{
    "code": -1,
    "message": "error message",
    "data": null
}
```

### 9.4 路由注册

```zig
try app.route("/users", user_controller, &UserController.create);
try app.route("/users/:id", user_controller, &UserController.find);
```

---

## 10. 命令行工具

### 10.1 命令列表

| 命令 | 用法 | 说明 |
|------|------|------|
| codegen | `zig build codegen -- --name=Article --all` | 代码生成 |
| migrate | `zig build migrate -- up` | 执行迁移 |
| migrate create | `zig build migrate -- create add_user_table` | 创建迁移 |
| plugin-gen | `zig build plugin-gen -- --name=MyPlugin` | 插件模板生成 |
| config-gen | `zig build config-gen` | 配置生成 |

### 10.2 代码生成器

```
zig build codegen -- --name=Article --all
```

**生成内容**：
- 模型文件
- DTO 文件
- 控制器
- 服务类
- 仓库接口
- 迁移文件

### 10.3 数据库迁移

```bash
# 创建迁移
zig build migrate -- create add_user_table

# 执行迁移
zig build migrate -- up

# 回滚迁移
zig build migrate -- down

# 查看状态
zig build migrate -- status
```

### 10.4 插件生成器

```bash
# 生成插件模板
zig build plugin-gen -- --name=MyPlugin

# 生成带功能的插件
zig build plugin-gen -- --name=MyPlugin --features=cache,hook
```

---

## 11. 插件系统

### 11.1 概述

ZigCMS 提供可扩展的插件系统，允许在不修改核心代码的情况下扩展功能。

### 11.2 插件结构

```
plugins/
├── mod.zig              # 插件模块入口
├── plugin_interface.zig # 插件接口
├── plugin_manager.zig   # 插件管理器
├── plugin_registry.zig  # 插件注册表
└── security_policy.zig  # 安全策略
```

### 11.3 插件接口

```zig
pub const Plugin = struct {
    const VTable = struct {
        name: []const u8,
        version: []const u8,
        init: fn (*anyopaque, *DIContainer) anyerror!void,
        deinit: fn (*anyopaque) void,
        onRequest: fn (*anyopaque, *Request) anyerror!?Response,
    };
    
    ptr: *anyopaque,
    vtable: *const VTable,
};
```

### 11.4 插件生命周期

```
加载插件 → 初始化 → 注册路由 → 启动服务 → 卸载插件
                     ↓
              事件钩子（请求前后）
```

---

## 12. 测试策略

### 12.1 测试类型

| 类型 | 文件 | 说明 |
|------|------|------|
| 单元测试 | `tests/*_test.zig` | 测试单个组件 |
| 集成测试 | `tests/*_test.zig` | 测试组件交互 |
| 并发测试 | `tests/concurrent_test.zig` | 测试线程安全 |
| 内存泄漏测试 | `tests/memory_leak_test.zig` | 检测内存泄漏 |

### 12.2 测试命令

```bash
# 运行所有测试
make test
zig build test

# 运行单元测试
zig build test-unit

# 运行并发测试
zig build test-concurrent

# 运行内存泄漏测试
zig build test-memory

# 运行特定测试
zig test src/module_test.zig
```

### 12.3 测试示例

```zig
test "User model creation" {
    const User = orm.define(struct {
        pub const table_name = "users";
        id: u64,
        name: []const u8,
        email: []const u8,
    });
    
    // 测试创建
    const user = try User.create(&db, .{
        .name = "测试用户",
        .email = "test@example.com",
    });
    
    try std.testing.expect(user.id > 0);
    try std.testing.expectEqualStrings("测试用户", user.name);
}
```

---

## 13. 性能优化

### 13.1 内存管理

#### 13.1.1 Arena Allocator

```zig
// 使用 Arena 一次性分配和释放
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

const result = try someOperation(arena.allocator());
// 自动清理所有分配
```

#### 13.1.2 错误处理与资源清理

```zig
pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();  // 正常路径关闭
    
    errdefer file.close();  // 错误时自动关闭
    return try file.readToEndAlloc(allocator, 1024 * 1024);
}
```

### 13.2 数据库优化

- **连接池**：复用数据库连接
- **批量操作**：减少数据库往返
- **查询缓存**：缓存频繁查询结果
- **索引优化**：合理创建数据库索引

### 13.3 缓存策略

```
查询 → 检查缓存 → 缓存命中？ → 返回
                   ↓ 未命中
              查询数据库 → 写入缓存 → 返回
```

### 13.4 并发模型

```zig
// 使用 async/await 进行并发操作
const tasks = [_]async void{
    async fetchData(1),
    async fetchData(2),
    async fetchData(3),
};

for (&tasks) |*task| {
    await task;
}
```

---

## 14. 安全机制

### 14.1 SQL 注入防护

```zig
/// 转义 SQL 字符串中的危险字符以防止 SQL 注入
pub fn escapeSqlString(allocator: Allocator, str: []const u8) ![]u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    for (str) |c| {
        switch (c) {
            '\'' => try result.appendSlice(allocator, "''"),
            '\\' => try result.appendSlice(allocator, "\\\\"),
            // ... 其他转义
            else => try result.append(allocator, c),
        }
    }

    return result.toOwnedSlice(allocator);
}
```

### 14.2 认证与授权

```zig
// JWT Token 验证
const claims = try verifyToken(auth_header);

// 权限检查
if (!user.hasPermission("article:edit")) {
    return error.Forbidden;
}
```

### 14.3 文件上传安全

```zig
// 限制文件类型
const allowed_types = &.{ ".jpg", ".png", ".gif", ".pdf" };
const ext = std.fs.path.extension(filename);

// 检查文件大小
if (file_size > max_size) {
    return error.FileTooLarge;
}
```

---

## 15. 开发指南

### 15.1 环境搭建

```bash
# 1. 安装 Zig
brew install zig

# 2. 克隆项目
git clone https://github.com/xiusin/zigcms.git
cd zigcms

# 3. 安装依赖
make setup

# 4. 构建项目
make build

# 5. 运行开发服务器
make dev
```

### 15.2 项目结构

```
zigcms/
├── api/                  # API 层
│   ├── controllers/      # 控制器
│   ├── dto/              # 数据传输对象
│   └── middleware/       # 中间件
├── application/          # 应用层
│   └── services/         # 应用服务
├── domain/               # 领域层
│   ├── entities/         # 实体
│   ├── repositories/     # 仓储接口
│   └── services/         # 领域服务
├── infrastructure/       # 基础设施层
│   ├── database/         # 数据库实现
│   └── cache/            # 缓存实现
├── shared/               # 共享层
│   ├── config/           # 配置
│   ├── di/               # 依赖注入
│   └── utils/            # 工具函数
├── commands/             # 命令行工具
├── configs/              # 配置文件
├── plugins/              # 插件系统
├── tests/                # 测试文件
├── main.zig              # 程序入口
├── root.zig              # 根模块
└── build.zig             # 构建配置
```

### 15.3 新增功能步骤

#### 15.3.1 创建模型

1. 在 `domain/entities/` 创建模型文件
2. 在 `domain/entities/mod.zig` 导出
3. 创建对应的 Repository 接口

#### 15.3.2 创建服务

1. 在 `application/services/` 创建服务
2. 实现业务逻辑
3. 注册到 DI 容器

#### 15.3.3 创建控制器

1. 在 `api/controllers/` 创建控制器
2. 实现 HTTP 处理逻辑
3. 在 `bootstrap.zig` 注册路由

### 15.4 代码规范

遵循 `docs/CODE_STYLE.md` 中的规范：
- 命名约定
- 错误处理
- 文档注释
- 测试要求

---

## 16. 部署运维

### 16.1 生产环境部署

```bash
# 1. 构建发布版本
make build

# 2. 配置生产环境变量
export ZIGCMS_ENV=production
export DATABASE_URL=postgresql://...

# 3. 运行数据库迁移
zig build migrate -- up

# 4. 启动服务
./zig-out/bin/zigcms
```

### 16.2 Docker 部署

```dockerfile
FROM zig:0.15 AS builder

WORKDIR /app
COPY . .
RUN zig build -Doptimize=ReleaseSafe

FROM alpine:latest
COPY --from=builder /app/zig-out/bin/zigcms /usr/local/bin/
EXPOSE 3000
CMD ["zigcms"]
```

### 16.3 监控与日志

```bash
# 查看日志
tail -f logs/zigcms.log

# 性能监控
# 使用 Tracy 进行性能剖析
```

### 16.4 备份与恢复

```bash
# 数据库备份
pg_dump -U postgres zigcms > backup.sql

# 数据库恢复
psql -U postgres zigcms < backup.sql
```

---

## 附录

### A. 错误码参考

| 错误码 | 说明 |
|--------|------|
| 0 | 成功 |
| -1 | 通用错误 |
| 401 | 未认证 |
| 403 | 无权限 |
| 404 | 资源不存在 |
| 422 | 参数验证失败 |
| 500 | 服务器错误 |

### B. API 响应格式

```json
{
    "code": 0,
    "message": "success",
    "data": { ... },
    "meta": {
        "page": 1,
        "per_page": 10,
        "total": 100
    }
}
```

### C. 配置项完整列表

详见 `configs/README.md`

### D. 常见问题

详见 `docs/FAQ.md`

---

## 维护者

**ZigCMS Team**

**版本**: 2.0.0  
**最后更新**: 2026-01-17
