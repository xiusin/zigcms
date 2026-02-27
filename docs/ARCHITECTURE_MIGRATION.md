# ZigCMS 架构迁移指南

## 概述

本文档描述了 ZigCMS 从旧架构迁移到新架构的过程和指南。

## 架构演进

### 旧架构（问题）

```
zigcms/
├── shared/              # 共享层1
│   ├── di/              # DI容器实现1
│   ├── primitives/      # 包含另一个DI容器实现
│   ├── config/          # 配置（8个文件）
│   ├── errors/          # 错误处理1
│   └── utils/           # 工具函数
├── shared_kernel/       # 共享层2（重复）
│   ├── patterns/        # DDD模式
│   └── infrastructure/  # 基础设施
├── application/
│   └── services/        # 26个子模块（混杂基础设施）
│       ├── cache/       # 缓存实现1
│       ├── redis/       # Redis客户端
│       ├── sql/         # ORM实现1
│       ├── orm/         # ORM实现2
│       ├── http/        # HTTP客户端
│       ├── logger/      # 日志实现
│       └── errors/      # 错误处理2
├── infrastructure/
│   ├── cache/           # 缓存实现2（重复）
│   └── http/            # HTTP接口（重复）
└── domain/
    └── repositories/    # 仓储接口（与shared_kernel重复）
```

**问题**:
- 8处严重重复实现
- 依赖方向混乱
- 层级边界模糊
- `application/services` 过于庞大

### 新架构（目标）

```
zigcms/
├── src/
│   └── core/                    # 统一核心层
│       ├── di/                  # 唯一DI容器
│       ├── errors/              # 统一错误处理
│       ├── logging/             # 统一日志系统
│       ├── config/              # 配置管理
│       ├── types/               # 通用类型
│       ├── utils/               # 工具函数
│       ├── patterns/            # DDD模式
│       └── context/             # 应用上下文
├── domain/                      # 领域层（纯业务）
├── application/                 # 应用层（精简）
│   ├── services/                # 业务服务
│   ├── usecases/                # 用例
│   └── plugins/                 # 插件系统
├── infrastructure/              # 基础设施层（扩充）
│   ├── database/
│   │   ├── orm/                 # 合并后的ORM
│   │   └── repositories/        # 仓储实现
│   ├── cache/                   # 合并后的缓存
│   ├── redis/                   # Redis客户端
│   └── http/                    # HTTP客户端
└── api/                         # API层
```

---

## 迁移步骤

### 第一阶段：创建核心层 ✅

已完成：
- 创建 `src/core/` 目录结构
- 合并 DI 容器实现
- 合并错误处理
- 合并日志系统
- 合并 DDD 模式

### 第二阶段：更新导入路径

**旧代码**:
```zig
const shared = @import("shared/mod.zig");
const shared_kernel = @import("shared_kernel/mod.zig");
const di = @import("shared/di/mod.zig");
```

**新代码**:
```zig
const core = @import("src/core/mod.zig");
const di = core.di;
const errors = core.errors;
const logging = core.logging;
```

### 第三阶段：移动基础设施服务

将以下模块从 `application/services/` 移至 `infrastructure/`:
- `redis/` → `infrastructure/redis/`
- `sql/` + `orm/` → `infrastructure/database/orm/`
- `http/` → `infrastructure/http/`
- `cache/` → `infrastructure/cache/`

### 第四阶段：清理废弃代码

删除以下重复文件：
- `shared/primitives/container.zig`（使用 `core/di/container.zig`）
- `shared/primitives/logger.zig`（使用 `core/logging/mod.zig`）
- `shared/utils/redis.zig`（使用 `infrastructure/redis/`）
- `shared_kernel/patterns/repository.zig`（使用 `core/patterns/repository.zig`）

---

## 模块对照表

| 旧路径 | 新路径 | 状态 |
|-------|-------|------|
| `shared/di/` | `src/core/di/` | ✅ 已迁移 |
| `shared/primitives/container.zig` | `src/core/di/container.zig` | ✅ 已合并 |
| `shared/primitives/logger.zig` | `src/core/logging/mod.zig` | ✅ 已合并 |
| `shared/errors/` | `src/core/errors/` | ✅ 已迁移 |
| `application/services/errors/` | `src/core/errors/` | ✅ 已合并 |
| `shared_kernel/patterns/` | `src/core/patterns/` | ✅ 已迁移 |
| `domain/repositories/mod.zig` | `src/core/patterns/repository.zig` | ✅ 已合并 |
| `shared/config/` | `src/core/config/` | ✅ 已迁移 |
| `shared/types/` | `src/core/types/` | ✅ 已迁移 |
| `shared/utils/` | `src/core/utils/` | ✅ 已迁移 |
| `shared/context/` | `src/core/context/` | ✅ 已迁移 |
| `application/services/logger/` | `src/core/logging/` | 🔄 待完全迁移 |
| `application/services/cache/` | `infrastructure/cache/` | 🔄 待迁移 |
| `application/services/redis/` | `infrastructure/redis/` | 🔄 待迁移 |
| `application/services/sql/` | `infrastructure/database/orm/` | 🔄 待迁移 |
| `application/services/http/` | `infrastructure/http/` | 🔄 待迁移 |

---

## API 兼容性

### DI 容器

```zig
// 旧 API
const di = @import("shared/di/mod.zig");
try di.initGlobalDISystem(allocator);
const container = di.getGlobalContainer();

// 新 API（完全兼容）
const core = @import("src/core/mod.zig");
try core.di.initGlobalDISystem(allocator);
const container = core.di.getGlobalContainer();
```

### 错误处理

```zig
// 旧 API
const errors = @import("shared/errors/mod.zig");
const status = errors.errorToHttpStatus(error.NotFound);

// 新 API（完全兼容）
const core = @import("src/core/mod.zig");
const status = core.errors.errorToHttpStatus(error.NotFound);
```

### 日志

```zig
// 旧 API
const logger = @import("shared/primitives/logger.zig");
logger.info("消息", .{});

// 新 API
const core = @import("src/core/mod.zig");
core.logging.info("消息", .{});
```

---

## 依赖规则

```
正确的依赖方向（由内向外）:

core ← domain ← application ← infrastructure ← api
  │                              ↑
  └──────────────────────────────┘
         (core 可被所有层使用)
```

**规则**:
1. `core` 不依赖任何业务层
2. `domain` 只依赖 `core`
3. `application` 依赖 `domain` 和 `core`
4. `infrastructure` 依赖 `domain`、`application` 和 `core`
5. `api` 依赖所有层

---

## 测试验证

运行以下命令验证迁移：

```bash
# 编译验证
zig build

# 运行测试
zig build test

# 运行内存泄漏测试
zig build test-memory
```
