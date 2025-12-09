# ZigCMS - 优化后的项目结构

## 概述
ZigCMS 项目已经重构为整洁架构（Clean Architecture）模式，提高代码组织性和可维护性。项目采用现代化的 Zig 项目结构，使用 `mod.zig` 约定实现模块化。

## 新的目录结构
```
zigcms/
├── api/                    # API 层 - 处理 HTTP 请求和响应
│   ├── Api.zig            # API 层入口
│   ├── App.zig            # 应用框架（更新版）
│   ├── controllers/       # HTTP 控制器
│   │   └── mod.zig        # 控制器模块入口（原 controllers.zig）
│   ├── dto/               # 数据传输对象
│   │   └── mod.zig        # DTO 模块入口（原 dtos.zig）
│   └── middleware/        # HTTP 中间件
│       └── mod.zig        # 中间件模块入口（原 middlewares.zig）
├── application/           # 应用层 - 协调业务流程
│   ├── mod.zig            # 应用层入口（原 Application.zig）
│   ├── services/          # 应用服务
│   └── usecases/          # 业务用例
├── domain/                # 领域层 - 核心业务逻辑
│   ├── mod.zig            # 领域层入口（原 Domain.zig）
│   ├── entities/          # 业务实体
│   └── repositories/      # 仓库接口
├── infrastructure/        # 基础设施层 - 外部服务集成
│   ├── mod.zig            # 基础设施层入口（原 Infrastructure.zig）
│   ├── database/          # 数据库实现
│   ├── cache/             # 缓存实现
│   ├── http/              # HTTP 客户端实现
│   └── messaging/         # 消息系统实现
├── shared/                # 共享层 - 通用组件
│   ├── mod.zig            # 共享层入口（原 Shared.zig）
│   ├── utils/             # 通用工具
│   ├── primitives/        # 基础原语
│   └── types/             # 通用类型
├── main.zig              # 主程序入口（已更新）
├── root.zig              # 项目根模块（已更新）
├── build.zig             # 构建配置（已更新）
└── ...
```

## 架构说明

### 1. API 层 (api/)
- **职责**: 处理 HTTP 请求和响应，验证请求参数，返回响应
- **包含**: 控制器、DTO、中间件
- **依赖**: 仅依赖 Application 层
- **模块化**: 使用 `mod.zig` 模块入口，支持 `@import("api/controllers")` 简洁导入

### 2. 应用层 (application/)
- **职责**: 协调业务流程，处理用例逻辑，事务管理
- **包含**: 应用服务、业务用例
- **依赖**: 仅依赖 Domain 层
- **模块化**: 使用 `mod.zig` 模块入口，支持 `@import("application")` 简洁导入

### 3. 领域层 (domain/)
- **职责**: 包含核心业务逻辑和规则，业务实体和值对象
- **包含**: 实体、值对象、领域服务、仓库接口
- **依赖**: 无外部依赖（最内层）
- **模块化**: 使用 `mod.zig` 模块入口，支持 `@import("domain")` 简洁导入

### 4. 基础设施层 (infrastructure/)
- **职责**: 实现外部服务接口（数据库、缓存、HTTP 客户端等）
- **包含**: 数据库实现、缓存实现、HTTP 客户端实现
- **依赖**: 仅依赖 Domain 层
- **模块化**: 使用 `mod.zig` 模块入口，支持 `@import("infrastructure")` 简洁导入

### 5. 共享层 (shared/)
- **职责**: 提供跨层共享的工具和原语
- **包含**: 通用工具、基础原语、通用类型
- **依赖**: 无外部依赖
- **模块化**: 使用 `mod.zig` 模块入口，支持 `@import("shared")` 简洁导入

## 模块化改进

### 1. 使用 `mod.zig` 约定
所有主要模块（如 `api/controllers`, `api/dto`, `api/middleware`, `application`, `domain`, `infrastructure`, `shared`）都使用 `mod.zig` 作为模块入口文件。

### 2. 简洁的导入方式
支持以下导入方式：
- `@import("api/controllers")` - 在同一目录层级
- `@import("api/controllers/mod.zig")` - 在不同层级或根目录
- `@import("domain")` - 领域层入口
- `@import("application")` - 应用层入口

### 3. 分组和命名空间组织
- **控制器分组**: `controllers.auth.Login`, `controllers.admin.Menu`, `controllers.common.Crud`
- **DTO 分组**: `dtos.user.Login`, `dtos.menu.Save`, `dtos.common.Page`
- **中间件分组**: `middleware.authMiddleware`, `middleware.logMiddleware`

## 主要改进

1. **职责分离**: 每层都有明确的职责，代码更加模块化
2. **依赖规则**: 严格遵循依赖规则，外层依赖内层，内层不依赖外层
3. **可测试性**: 各层可以独立测试，提高代码质量
4. **可维护性**: 代码组织更清晰，便于长期维护
5. **可扩展性**: 新功能可以更容易地添加到合适的位置
6. **模块化**: 遵循 Zig `mod.zig` 约定，支持简洁的导入方式
7. **命名空间组织**: 按功能分组组织代码，提高可读性

## 构建和运行

构建项目:
```bash
zig build
```

运行开发服务器:
```bash
zig build run
```

## 文件路径更新

- 原 `src/controllers/` → `api/controllers/`
- 原 `src/dto/` → `api/dto/`
- 原 `src/middlewares/` → `api/middleware/`
- 原 `src/models/` → `domain/entities/`
- 原 `src/services/` → `application/services/`
- 原 `src/modules/` → `shared/utils/`
- 原 `src/global/` → `shared/primitives/`

所有导入路径已在主要文件中更新以匹配新的结构。

## 模块入口文件更新

- `api/controllers/controllers.zig` → `api/controllers/mod.zig`
- `api/dto/dtos.zig` → `api/dto/mod.zig`
- `api/middleware/middlewares.zig` → `api/middleware/mod.zig`
- `domain/Domain.zig` → `domain/mod.zig`
- `application/Application.zig` → `application/mod.zig`
- `infrastructure/Infrastructure.zig` → `infrastructure/mod.zig`
- `shared/Shared.zig` → `shared/mod.zig`

这些改进使项目结构更加现代化、模块化和易于维护。