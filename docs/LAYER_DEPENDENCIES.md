# 层间依赖关系文档

## 概述

ZigCMS 采用整洁架构（Clean Architecture），各层之间的依赖关系应遵循以下规则：

```
API 层 → 应用层 → 领域层 → 共享层
         ↓
    基础设施层
```

## 依赖规则

### 共享层 (shared/)
- **不应依赖**：domain, application, api, infrastructure
- **可以依赖**：标准库, 外部工具库

### 领域层 (domain/)
- **不应依赖**：application, api, infrastructure
- **可以依赖**：shared, 标准库

### 应用层 (application/)
- **不应依赖**：api
- **可以依赖**：domain, shared, infrastructure（通过接口）

### 基础设施层 (infrastructure/)
- **不应依赖**：api
- **可以依赖**：domain, application, shared

### API 层 (api/)
- **可以依赖**：application, shared
- **不应直接依赖**：domain, infrastructure

## 当前已知的依赖违规

### 1. shared/primitives/global.zig

**问题**：global.zig 位于共享层，但依赖了多个业务层：
- domain/entities/models.zig
- domain/entities/orm_models.zig
- api/controllers/base.fn.zig
- application/services/services.zig
- application/services/sql/orm.zig
- application/services/plugins/plugin_system.zig
- application/services/logger/logger.zig

**建议修复方案**：
1. 将 global.zig 移动到 application 层，因为它管理的是应用级别的服务
2. 或者重构为依赖注入模式，在启动时注入依赖

### 2. shared/utils/jwt.zig

**问题**：jwt.zig 依赖了 application/services/json/json.zig

**建议修复方案**：
1. 将 JSON 工具移动到 shared 层
2. 或者使用标准库的 JSON 功能

## 已修复的依赖违规

### 1. shared/primitives/logger.zig
- **原问题**：依赖 api/middleware/request_id.middleware.zig
- **修复方案**：使用 thread-local 变量存储 request_id，由中间件设置

### 2. shared/primitives/container.zig
- **原问题**：依赖 application/services/logger/logger.zig
- **修复方案**：使用 std.debug.print 替代

## 验证依赖关系

使用以下命令检查共享层是否有违规依赖：

```bash
grep -r '@import("\.\./' shared/
```

## 未来改进计划

1. 将 global.zig 重构为应用层的 AppContext
2. 实现完整的依赖注入系统
3. 将 JSON 工具移动到共享层
