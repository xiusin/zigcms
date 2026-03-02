# MCP 代码生成工具使用指南

## 概述

MCP 代码生成工具可以通过 AI 编辑器（Claude Code、Cursor、Windsurf）自动生成 ZigCMS 的 CRUD 模块代码。

## 工具列表

### 1. crud_generator - CRUD 生成器

自动生成完整的 CRUD 模块，包括：
- 模型定义（Model）
- 控制器（Controller）
- 路由注册代码

#### 输入参数

```json
{
  "name": "Article",
  "fields": [
    {
      "name": "id",
      "type": "int",
      "required": true
    },
    {
      "name": "title",
      "type": "string",
      "required": true
    },
    {
      "name": "content",
      "type": "string",
      "required": true
    },
    {
      "name": "author_id",
      "type": "int",
      "required": true
    },
    {
      "name": "published_at",
      "type": "timestamp",
      "required": false
    },
    {
      "name": "is_published",
      "type": "bool",
      "required": true
    }
  ]
}
```

#### 支持的字段类型

| 类型 | Zig 类型 | 说明 |
|------|----------|------|
| `string` | `[]const u8` | 字符串 |
| `int` | `i32` | 整数 |
| `bool` | `bool` | 布尔值 |
| `float` | `f64` | 浮点数 |
| `timestamp` | `i64` | 时间戳 |

#### 输出结果

```json
{
  "model": "// 模型代码...",
  "controller": "// 控制器代码...",
  "routes": "// 路由注册代码...",
  "model_path": "src/domain/entities/Article.model.zig",
  "controller_path": "src/api/controllers/Article.controller.zig"
}
```

## 使用流程

### 1. 配置 AI 编辑器

#### Claude Code 配置

在项目根目录创建 `.claude/mcp.json`：

```json
{
  "mcpServers": {
    "ZigCMS Helper": {
      "type": "sse",
      "url": "http://127.0.0.1:8889/mcp/sse"
    }
  }
}
```

#### Cursor 配置

在 Cursor 设置中添加 MCP 服务器：

```json
{
  "mcp": {
    "servers": {
      "ZigCMS Helper": {
        "type": "sse",
        "url": "http://127.0.0.1:8889/mcp/sse"
      }
    }
  }
}
```

#### Windsurf 配置

在 Windsurf 设置中添加：

```json
{
  "mcp": {
    "servers": [
      {
        "name": "ZigCMS Helper",
        "type": "sse",
        "url": "http://127.0.0.1:8889/mcp/sse"
      }
    ]
  }
}
```

### 2. 启动 ZigCMS 服务器

```bash
cd /path/to/zigcms
./zig-out/bin/zigcms
```

确保看到以下日志：

```
✅ MCP 服务已启用: 127.0.0.1:8889/mcp/sse
```

### 3. 在 AI 编辑器中使用

#### 示例对话

**你**：请帮我生成一个文章（Article）模块，包含以下字段：
- id (整数，必填)
- title (字符串，必填)
- content (字符串，必填)
- author_id (整数，必填)
- published_at (时间戳，可选)
- is_published (布尔值，必填)

**AI**：好的，我将使用 crud_generator 工具为你生成代码...

*AI 会自动调用 MCP 工具并返回生成的代码*

### 4. 应用生成的代码

#### 4.1 创建模型文件

将生成的模型代码保存到：
```
src/domain/entities/Article.model.zig
```

#### 4.2 创建控制器文件

将生成的控制器代码保存到：
```
src/api/controllers/Article.controller.zig
```

#### 4.3 注册路由

在 `src/api/bootstrap.zig` 中添加生成的路由注册代码。

#### 4.4 编译测试

```bash
zig build
```

## 生成的代码示例

### 模型代码

```zig
//! Article 模型
//! 自动生成 - 请勿手动修改

const std = @import("std");

pub const Article = struct {
    id: i32,
    title: []const u8,
    content: []const u8,
    author_id: i32,
    published_at: ?i64 = null,
    is_published: bool,
};
```

### 控制器代码

```zig
//! Article 控制器
//! 自动生成 - 请勿手动修改

const std = @import("std");
const zap = @import("zap");
const Article = @import("../../domain/entities/Article.model.zig").Article;

pub const ArticleController = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ArticleController {
        return .{ .allocator = allocator };
    }

    pub fn list(self: *@This(), req: zap.Request) !void {
        _ = self;
        _ = req;
        // TODO: 实现列表查询
    }

    pub fn get(self: *@This(), req: zap.Request) !void {
        _ = self;
        _ = req;
        // TODO: 实现详情查询
    }

    pub fn create(self: *@This(), req: zap.Request) !void {
        _ = self;
        _ = req;
        // TODO: 实现创建
    }

    pub fn update(self: *@This(), req: zap.Request) !void {
        _ = self;
        _ = req;
        // TODO: 实现更新
    }

    pub fn delete(self: *@This(), req: zap.Request) !void {
        _ = self;
        _ = req;
        // TODO: 实现删除
    }
};
```

### 路由注册代码

```zig
// 在 bootstrap.zig 中添加以下代码：

// 1. 导入控制器
const ArticleController = @import("controllers/Article.controller.zig").ArticleController;

// 2. 注册到 DI 容器
if (!self.container.isRegistered(ArticleController)) {
    try self.container.registerSingleton(ArticleController, ArticleController, struct {
        fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*Controller {
            _ = di;
            const ctrl = try allocator.create(Controller);
            ctrl.* = Controller.init(allocator);
            return ctrl;
        }
    }.factory, null);
}

// 3. 注册路由
const Article_ctrl = try self.container.resolve(ArticleController);
try self.app.route("/api/Article", Article_ctrl, &ArticleController.list);
try self.app.route("/api/Article/:id", Article_ctrl, &ArticleController.get);
try self.app.route("/api/Article/create", Article_ctrl, &ArticleController.create);
try self.app.route("/api/Article/update/:id", Article_ctrl, &ArticleController.update);
try self.app.route("/api/Article/delete/:id", Article_ctrl, &ArticleController.delete);
```

## 后续步骤

生成的代码是基础框架，你需要：

1. **实现业务逻辑**：在控制器的 TODO 部分实现具体的 CRUD 逻辑
2. **添加 ORM 集成**：使用 ZigCMS 的 ORM 进行数据库操作
3. **添加验证**：添加输入验证和错误处理
4. **添加权限控制**：根据需要添加权限检查
5. **编写测试**：为生成的代码编写单元测试

## 最佳实践

1. **遵循 ZigCMS 规范**：生成的代码遵循 ZigCMS 的整洁架构和 DDD 原则
2. **使用 Arena 分配器**：在临时操作中使用 Arena 分配器
3. **错误处理**：使用 Zig 的显式错误处理
4. **内存安全**：确保所有分配的内存都被正确释放
5. **参数化查询**：使用 ORM/QueryBuilder 防止 SQL 注入

## 故障排除

### MCP 服务未启动

**症状**：AI 编辑器无法连接到 MCP 服务器

**解决方案**：
1. 检查 ZigCMS 是否正在运行
2. 检查端口 8889 是否被占用
3. 查看服务器日志确认 MCP 已启用

### 生成的代码编译失败

**症状**：生成的代码无法编译

**解决方案**：
1. 检查字段类型是否正确
2. 确保模型名称符合 Zig 命名规范
3. 检查导入路径是否正确

### 路由注册失败

**症状**：路由注册时出错

**解决方案**：
1. 确保控制器已正确导入
2. 检查 DI 容器注册代码
3. 确保路由路径不冲突

## 参考资料

- [MCP 设计方案](mcp_design_plan.md)
- [MCP 实现计划](mcp_implementation_plan.md)
- [ZigCMS 开发规范](../AGENTS.md)
- [ORM 使用指南](../knowlages/orm_memory_lifecycle.md)
