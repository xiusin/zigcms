# ZigCMS 命令行工具文档

## 概述

ZigCMS 提供了一套完整的命令行工具，用于代码生成、数据库迁移和插件开发。所有工具都位于 `cmd/` 目录下，通过 `zig build` 命令调用。

## 目录结构

```
cmd/
├── codegen/            # 代码生成器
│   └── main.zig
├── migrate/            # 数据库迁移
│   └── main.zig
└── plugingen/          # 插件生成器
    └── main.zig
```

## 工具列表

### 1. codegen - 代码生成器

**功能**：自动生成模型、DTO、控制器、路由等代码

**使用方式**：
```bash
zig build codegen -- [选项]
```

**选项**：
```
--name <名称>        模型名称（必需）
--all               生成所有文件（模型+DTO+控制器+路由）
--model             仅生成模型
--dto               仅生成 DTO
--controller        仅生成控制器
--route             仅生成路由
--table <表名>      指定数据库表名（默认：模型名小写）
--help              显示帮助信息
```

**示例**：

```bash
# 生成完整的 Article 模块（模型+DTO+控制器+路由）
zig build codegen -- --name=Article --all

# 仅生成 Article 模型
zig build codegen -- --name=Article --model

# 生成 Article 模型和 DTO
zig build codegen -- --name=Article --model --dto

# 指定自定义表名
zig build codegen -- --name=Article --table=cms_articles --all
```

**生成的文件**：

```
src/
├── domain/entities/
│   └── article.model.zig          # 实体模型
├── api/dto/
│   ├── article_create.dto.zig     # 创建 DTO
│   ├── article_update.dto.zig     # 更新 DTO
│   └── article_list.dto.zig       # 列表 DTO
├── api/controllers/
│   └── article.controller.zig     # 控制器
└── api/routes/
    └── article.route.zig          # 路由注册
```

**生成的代码示例**：

```zig
// src/domain/entities/article.model.zig
pub const Article = struct {
    id: ?i32 = null,
    title: []const u8 = "",
    content: []const u8 = "",
    author_id: ?i32 = null,
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

// src/api/controllers/article.controller.zig
pub fn list(req: zap.Request) !void {
    var q = OrmArticle.Query();
    defer q.deinit();
    
    const articles = try q.get();
    defer OrmArticle.freeModels(articles);
    
    try base.send_success(req, articles);
}

pub fn create(req: zap.Request) !void {
    const body = try req.parseBody(CreateArticleDto);
    
    const article = try OrmArticle.Create(body);
    try base.send_success(req, article);
}
```

### 2. migrate - 数据库迁移

**功能**：管理数据库结构变更（创建表、修改字段、添加索引等）

**使用方式**：
```bash
zig build migrate -- [命令] [选项]
```

**命令**：
```
up                  执行所有未运行的迁移
down                回滚最后一次迁移
create <名称>       创建新的迁移文件
status              查看迁移状态
reset               回滚所有迁移
refresh             回滚所有迁移并重新执行
```

**选项**：
```
--steps <数量>      指定执行/回滚的迁移数量
--help              显示帮助信息
```

**示例**：

```bash
# 创建新的迁移文件
zig build migrate -- create add_user_table

# 执行所有未运行的迁移
zig build migrate -- up

# 回滚最后一次迁移
zig build migrate -- down

# 回滚最后 3 次迁移
zig build migrate -- down --steps=3

# 查看迁移状态
zig build migrate -- status

# 重置数据库（回滚所有迁移）
zig build migrate -- reset

# 刷新数据库（回滚并重新执行所有迁移）
zig build migrate -- refresh
```

**迁移文件结构**：

```
migrations/
├── 20260301_120000_create_users_table.zig
├── 20260301_130000_add_email_to_users.zig
└── 20260301_140000_create_articles_table.zig
```

**迁移文件示例**：

```zig
// migrations/20260301_120000_create_users_table.zig
const std = @import("std");
const sql = @import("../src/application/services/sql/mod.zig");

pub fn up(db: *sql.Database) !void {
    const create_table =
        \\CREATE TABLE users (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  username TEXT NOT NULL UNIQUE,
        \\  email TEXT NOT NULL UNIQUE,
        \\  password TEXT NOT NULL,
        \\  status INTEGER DEFAULT 1,
        \\  created_at INTEGER,
        \\  updated_at INTEGER
        \\)
    ;
    
    try db.exec(create_table);
    
    // 创建索引
    try db.exec("CREATE INDEX idx_users_username ON users(username)");
    try db.exec("CREATE INDEX idx_users_email ON users(email)");
}

pub fn down(db: *sql.Database) !void {
    try db.exec("DROP TABLE IF EXISTS users");
}
```

**迁移最佳实践**：

1. **命名规范**：
   ```
   YYYYMMDD_HHMMSS_描述.zig
   20260301_120000_create_users_table.zig
   20260301_130000_add_email_to_users.zig
   ```

2. **原子性**：每个迁移只做一件事
   ```zig
   // ✅ 推荐：单一职责
   // 20260301_120000_create_users_table.zig
   // 20260301_130000_add_email_to_users.zig
   
   // ❌ 避免：多个不相关的操作
   // 20260301_120000_create_tables_and_add_fields.zig
   ```

3. **可回滚**：所有 `up()` 都要有对应的 `down()`
   ```zig
   pub fn up(db: *sql.Database) !void {
       try db.exec("ALTER TABLE users ADD COLUMN email TEXT");
   }
   
   pub fn down(db: *sql.Database) !void {
       try db.exec("ALTER TABLE users DROP COLUMN email");
   }
   ```

4. **数据迁移**：先修改结构，再迁移数据
   ```zig
   pub fn up(db: *sql.Database) !void {
       // 1. 添加新字段
       try db.exec("ALTER TABLE users ADD COLUMN full_name TEXT");
       
       // 2. 迁移数据
       try db.exec("UPDATE users SET full_name = username WHERE full_name IS NULL");
       
       // 3. 设置约束
       try db.exec("ALTER TABLE users ALTER COLUMN full_name SET NOT NULL");
   }
   ```

### 3. plugingen - 插件生成器

**功能**：生成插件模板，快速开发 ZigCMS 插件

**使用方式**：
```bash
zig build plugingen -- [选项]
```

**选项**：
```
--name <名称>        插件名称（必需）
--author <作者>      插件作者（默认：ZigCMS）
--version <版本>     插件版本（默认：0.1.0）
--description <描述> 插件描述
--help              显示帮助信息
```

**示例**：

```bash
# 生成基础插件
zig build plugingen -- --name=MyPlugin

# 生成完整信息的插件
zig build plugingen -- \
  --name=MyPlugin \
  --author="张三" \
  --version="1.0.0" \
  --description="我的第一个插件"
```

**生成的文件**：

```
plugins/
└── my_plugin/
    ├── plugin.zig              # 插件入口
    ├── manifest.json           # 插件清单
    ├── README.md               # 插件文档
    ├── src/
    │   ├── handlers/           # 请求处理器
    │   ├── services/           # 业务服务
    │   └── models/             # 数据模型
    └── tests/
        └── plugin_test.zig     # 插件测试
```

**插件清单示例**：

```json
{
  "name": "MyPlugin",
  "version": "1.0.0",
  "author": "张三",
  "description": "我的第一个插件",
  "dependencies": [],
  "hooks": [
    "before_request",
    "after_request",
    "before_response"
  ],
  "routes": [
    {
      "path": "/api/myplugin/hello",
      "method": "GET",
      "handler": "handlers.hello"
    }
  ]
}
```

**插件入口示例**：

```zig
// plugins/my_plugin/plugin.zig
const std = @import("std");
const plugin_api = @import("../../src/plugins/plugin_api.zig");

pub const Plugin = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) !*Plugin {
        const plugin = try allocator.create(Plugin);
        plugin.* = .{ .allocator = allocator };
        return plugin;
    }
    
    pub fn deinit(self: *Plugin) void {
        self.allocator.destroy(self);
    }
    
    pub fn onLoad(self: *Plugin) !void {
        std.debug.print("插件加载: MyPlugin\n", .{});
    }
    
    pub fn onUnload(self: *Plugin) !void {
        std.debug.print("插件卸载: MyPlugin\n", .{});
    }
    
    pub fn beforeRequest(self: *Plugin, req: *plugin_api.Request) !void {
        // 请求前钩子
    }
    
    pub fn afterRequest(self: *Plugin, req: *plugin_api.Request, res: *plugin_api.Response) !void {
        // 请求后钩子
    }
};
```

## 构建配置

所有命令行工具都在 `build.zig` 中配置：

```zig
// build.zig
pub fn build(b: *std.Build) void {
    // ... 主程序构建 ...
    
    // 代码生成器
    const codegen = b.addExecutable(.{
        .name = "codegen",
        .root_source_file = b.path("cmd/codegen/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(codegen);
    
    const codegen_cmd = b.addRunArtifact(codegen);
    if (b.args) |args| {
        codegen_cmd.addArgs(args);
    }
    const codegen_step = b.step("codegen", "运行代码生成器");
    codegen_step.dependOn(&codegen_cmd.step);
    
    // 数据库迁移
    const migrate = b.addExecutable(.{
        .name = "migrate",
        .root_source_file = b.path("cmd/migrate/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(migrate);
    
    const migrate_cmd = b.addRunArtifact(migrate);
    if (b.args) |args| {
        migrate_cmd.addArgs(args);
    }
    const migrate_step = b.step("migrate", "运行数据库迁移");
    migrate_step.dependOn(&migrate_cmd.step);
    
    // 插件生成器
    const plugingen = b.addExecutable(.{
        .name = "plugingen",
        .root_source_file = b.path("cmd/plugingen/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(plugingen);
    
    const plugingen_cmd = b.addRunArtifact(plugingen);
    if (b.args) |args| {
        plugingen_cmd.addArgs(args);
    }
    const plugingen_step = b.step("plugingen", "运行插件生成器");
    plugingen_step.dependOn(&plugingen_cmd.step);
}
```

## 开发新工具

### 1. 创建工具目录

```bash
mkdir -p cmd/mytool
touch cmd/mytool/main.zig
```

### 2. 编写工具代码

```zig
// cmd/mytool/main.zig
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        std.debug.print("用法: zig build mytool -- <参数>\n", .{});
        return;
    }
    
    // 工具逻辑...
}
```

### 3. 添加到 build.zig

```zig
// build.zig
const mytool = b.addExecutable(.{
    .name = "mytool",
    .root_source_file = b.path("cmd/mytool/main.zig"),
    .target = target,
    .optimize = optimize,
});
b.installArtifact(mytool);

const mytool_cmd = b.addRunArtifact(mytool);
if (b.args) |args| {
    mytool_cmd.addArgs(args);
}
const mytool_step = b.step("mytool", "运行我的工具");
mytool_step.dependOn(&mytool_cmd.step);
```

### 4. 使用工具

```bash
zig build mytool -- <参数>
```

## 工具开发最佳实践

### 1. 参数解析

```zig
// ✅ 推荐：使用结构化参数解析
const Args = struct {
    name: ?[]const u8 = null,
    help: bool = false,
    
    pub fn parse(allocator: std.mem.Allocator) !Args {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);
        
        var result = Args{};
        
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            
            if (std.mem.eql(u8, arg, "--help")) {
                result.help = true;
            } else if (std.mem.startsWith(u8, arg, "--name=")) {
                result.name = arg[7..];
            }
        }
        
        return result;
    }
};

pub fn main() !void {
    const args = try Args.parse(allocator);
    
    if (args.help) {
        printHelp();
        return;
    }
    
    const name = args.name orelse {
        std.debug.print("错误：缺少 --name 参数\n", .{});
        return error.MissingArgument;
    };
    
    // 使用 name...
}
```

### 2. 错误处理

```zig
// ✅ 推荐：友好的错误信息
pub fn main() !void {
    run() catch |err| {
        switch (err) {
            error.MissingArgument => {
                std.debug.print("错误：缺少必需参数\n", .{});
                std.debug.print("使用 --help 查看帮助\n", .{});
            },
            error.FileNotFound => {
                std.debug.print("错误：文件不存在\n", .{});
            },
            else => {
                std.debug.print("错误：{}\n", .{err});
            },
        }
        std.process.exit(1);
    };
}
```

### 3. 进度显示

```zig
// ✅ 推荐：显示进度信息
pub fn generateFiles(names: []const []const u8) !void {
    std.debug.print("开始生成文件...\n", .{});
    
    for (names, 0..) |name, i| {
        std.debug.print("[{d}/{d}] 生成 {s}...", .{ i + 1, names.len, name });
        
        try generateFile(name);
        
        std.debug.print(" ✓\n", .{});
    }
    
    std.debug.print("完成！共生成 {d} 个文件\n", .{names.len});
}
```

### 4. 文件操作

```zig
// ✅ 推荐：安全的文件操作
pub fn writeFile(path: []const u8, content: []const u8) !void {
    // 检查文件是否存在
    if (std.fs.cwd().access(path, .{})) {
        std.debug.print("警告：文件已存在，是否覆盖？(y/n): ", .{});
        
        const stdin = std.io.getStdIn().reader();
        var buf: [10]u8 = undefined;
        const input = try stdin.readUntilDelimiterOrEof(&buf, '\n') orelse return error.InvalidInput;
        
        if (!std.mem.eql(u8, input, "y")) {
            std.debug.print("已取消\n", .{});
            return;
        }
    } else |_| {}
    
    // 创建目录
    const dir = std.fs.path.dirname(path) orelse ".";
    try std.fs.cwd().makePath(dir);
    
    // 写入文件
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    
    try file.writeAll(content);
    
    std.debug.print("已创建：{s}\n", .{path});
}
```

## 总结

### 工具特点

1. **独立性**：每个工具独立编译，互不影响
2. **统一入口**：通过 `zig build <tool>` 调用
3. **参数传递**：使用 `--` 分隔 zig build 参数和工具参数
4. **错误处理**：友好的错误信息和帮助文档

### 开发流程

1. 创建工具目录（`cmd/<tool>/`）
2. 编写工具代码（`main.zig`）
3. 添加到 `build.zig`
4. 测试工具功能
5. 编写文档

### 使用规范

```bash
# 查看帮助
zig build <tool> -- --help

# 执行工具
zig build <tool> -- [选项]

# 示例
zig build codegen -- --name=Article --all
zig build migrate -- up
zig build plugingen -- --name=MyPlugin
```

**ZigCMS 命令行工具体系完善，开发效率高！**
