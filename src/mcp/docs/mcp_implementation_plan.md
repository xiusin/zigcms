# ZigCMS MCP 功能实现计划

**日期**: 2026-03-02  
**版本**: v1.0  
**预计周期**: 6 周

---

## 📅 实施时间表

```
Week 1-2: 基础框架
Week 3-4: 代码生成工具
Week 5-6: 高级功能
```

---

## 第一阶段：基础框架（Week 1-2）

### Week 1: MCP Server 核心

#### Day 1-2: 项目结构和配置

**任务**:
1. 创建 MCP 模块目录结构
2. 实现配置加载（`src/core/config/mcp.zig`）
3. 编写配置文件模板

**代码示例**:
```zig
// src/core/config/mcp.zig
pub const McpConfig = struct {
    name: []const u8 = "ZigCMS_MCP",
    version: []const u8 = "v1.0.0",
    enabled: bool = true,
    
    transport: TransportConfig = .{},
    security: SecurityConfig = .{},
    tools: ToolsConfig = .{},
    
    pub const TransportConfig = struct {
        type: []const u8 = "sse",
        host: []const u8 = "127.0.0.1",
        port: u16 = 8889,
        sse_path: []const u8 = "/mcp/sse",
        message_path: []const u8 = "/mcp/message",
    };
    
    pub const SecurityConfig = struct {
        allowed_paths: []const []const u8 = &.{ "src/", "docs/" },
        forbidden_paths: []const []const u8 = &.{ ".git/", ".env" },
        allowed_extensions: []const []const u8 = &.{ ".zig", ".md" },
    };
    
    pub const ToolsConfig = struct {
        enabled: []const []const u8 = &.{
            "project_structure",
            "file_search",
            "file_read",
        },
    };
};
```

**交付物**:
- ✅ `src/mcp/` 目录结构
- ✅ `src/core/config/mcp.zig`
- ✅ `config/mcp.yaml` 配置模板

---

#### Day 3-4: SSE 传输层

**任务**:
1. 实现 SSE HTTP 端点
2. 实现消息接收端点
3. 实现连接管理

**代码示例**:
```zig
// src/mcp/transport/sse.zig
const std = @import("std");
const zap = @import("zap");

pub const SseTransport = struct {
    allocator: std.mem.Allocator,
    config: McpConfig.TransportConfig,
    connections: std.AutoHashMap(u64, *Connection),
    
    pub const Connection = struct {
        id: u64,
        req: zap.Request,
        last_ping: i64,
    };
    
    pub fn init(allocator: std.mem.Allocator, config: McpConfig.TransportConfig) !*SseTransport {
        const self = try allocator.create(SseTransport);
        self.* = .{
            .allocator = allocator,
            .config = config,
            .connections = std.AutoHashMap(u64, *Connection).init(allocator),
        };
        return self;
    }
    
    pub fn deinit(self: *SseTransport) void {
        var it = self.connections.iterator();
        while (it.next()) |entry| {
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.connections.deinit();
        self.allocator.destroy(self);
    }
    
    /// SSE 端点处理
    pub fn handleSse(self: *SseTransport, req: zap.Request) !void {
        // 设置 SSE 响应头
        try req.setHeader("Content-Type", "text/event-stream");
        try req.setHeader("Cache-Control", "no-cache");
        try req.setHeader("Connection", "keep-alive");
        
        // 创建连接
        const conn_id = @intCast(u64, std.time.timestamp());
        const conn = try self.allocator.create(Connection);
        conn.* = .{
            .id = conn_id,
            .req = req,
            .last_ping = std.time.timestamp(),
        };
        
        try self.connections.put(conn_id, conn);
        
        // 发送初始化消息
        try self.sendEvent(conn_id, "connected", .{ .id = conn_id });
    }
    
    /// 消息端点处理
    pub fn handleMessage(self: *SseTransport, req: zap.Request) !void {
        const body = req.body orelse return error.EmptyBody;
        
        // 解析 JSON-RPC 请求
        const request = try std.json.parseFromSlice(
            JsonRpcRequest,
            self.allocator,
            body,
            .{}
        );
        defer request.deinit();
        
        // 处理请求
        const response = try self.handleRequest(request.value);
        
        // 发送响应
        try req.sendJson(response);
    }
    
    /// 发送 SSE 事件
    pub fn sendEvent(self: *SseTransport, conn_id: u64, event: []const u8, data: anytype) !void {
        const conn = self.connections.get(conn_id) orelse return error.ConnectionNotFound;
        
        const json_data = try std.json.stringifyAlloc(self.allocator, data, .{});
        defer self.allocator.free(json_data);
        
        const message = try std.fmt.allocPrint(
            self.allocator,
            "event: {s}\ndata: {s}\n\n",
            .{ event, json_data }
        );
        defer self.allocator.free(message);
        
        try conn.req.sendChunk(message);
    }
    
    /// 心跳检测
    pub fn heartbeat(self: *SseTransport) !void {
        const now = std.time.timestamp();
        var to_remove = std.ArrayList(u64).init(self.allocator);
        defer to_remove.deinit();
        
        var it = self.connections.iterator();
        while (it.next()) |entry| {
            const conn = entry.value_ptr.*;
            if (now - conn.last_ping > 30) {
                try to_remove.append(conn.id);
            } else {
                try self.sendEvent(conn.id, "ping", .{ .timestamp = now });
            }
        }
        
        for (to_remove.items) |conn_id| {
            if (self.connections.fetchRemove(conn_id)) |kv| {
                self.allocator.destroy(kv.value);
            }
        }
    }
};
```

**交付物**:
- ✅ `src/mcp/transport/sse.zig`
- ✅ SSE 端点可用
- ✅ 消息端点可用
- ✅ 连接管理正常

---

#### Day 5: JSON-RPC 协议层

**任务**:
1. 实现 JSON-RPC 2.0 类型定义
2. 实现请求解析
3. 实现响应构建

**代码示例**:
```zig
// src/mcp/protocol/types.zig
pub const JsonRpcRequest = struct {
    jsonrpc: []const u8 = "2.0",
    id: ?i64 = null,
    method: []const u8,
    params: ?std.json.Value = null,
};

pub const JsonRpcResponse = struct {
    jsonrpc: []const u8 = "2.0",
    id: ?i64 = null,
    result: ?std.json.Value = null,
    @"error": ?JsonRpcError = null,
};

pub const JsonRpcError = struct {
    code: i32,
    message: []const u8,
    data: ?std.json.Value = null,
};

// 错误码
pub const ErrorCode = enum(i32) {
    parse_error = -32700,
    invalid_request = -32600,
    method_not_found = -32601,
    invalid_params = -32602,
    internal_error = -32603,
};
```

**交付物**:
- ✅ `src/mcp/protocol/types.zig`
- ✅ `src/mcp/protocol/jsonrpc.zig`
- ✅ JSON-RPC 解析正常

---

### Week 2: 基础工具实现

#### Day 1-2: 项目结构工具

**任务**:
1. 实现项目结构扫描
2. 实现文件树生成
3. 实现架构分析

**代码示例**:
```zig
// src/mcp/tools/project_structure.zig
pub const ProjectStructureTool = struct {
    allocator: std.mem.Allocator,
    
    pub const ToolInfo = struct {
        name: []const u8 = "project_structure",
        description: []const u8 = "Get ZigCMS project structure and architecture",
        input_schema: std.json.Value,
    };
    
    pub fn execute(self: *ProjectStructureTool, params: std.json.Value) !std.json.Value {
        const root_path = params.object.get("path") orelse return error.MissingPath;
        
        var structure = std.ArrayList(FileNode).init(self.allocator);
        defer structure.deinit();
        
        try self.scanDirectory(root_path.string, &structure, 0);
        
        return std.json.Value{
            .object = .{
                .put("structure", structure.items),
                .put("architecture", try self.analyzeArchitecture()),
            },
        };
    }
    
    fn scanDirectory(self: *ProjectStructureTool, path: []const u8, list: *std.ArrayList(FileNode), depth: usize) !void {
        if (depth > 5) return; // 限制深度
        
        var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
        defer dir.close();
        
        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (self.shouldSkip(entry.name)) continue;
            
            const node = FileNode{
                .name = try self.allocator.dupe(u8, entry.name),
                .type = if (entry.kind == .directory) "directory" else "file",
                .depth = depth,
            };
            
            try list.append(node);
            
            if (entry.kind == .directory) {
                const sub_path = try std.fs.path.join(self.allocator, &.{ path, entry.name });
                defer self.allocator.free(sub_path);
                try self.scanDirectory(sub_path, list, depth + 1);
            }
        }
    }
    
    fn analyzeArchitecture(self: *ProjectStructureTool) !std.json.Value {
        return std.json.Value{
            .object = .{
                .put("pattern", "Clean Architecture + DDD"),
                .put("layers", &.{
                    "api (Interface Layer)",
                    "application (Application Layer)",
                    "domain (Domain Layer)",
                    "infrastructure (Infrastructure Layer)",
                    "core (Core Layer)",
                }),
            },
        };
    }
};
```

**交付物**:
- ✅ `src/mcp/tools/project_structure.zig`
- ✅ 项目结构扫描正常
- ✅ 架构分析准确

---

#### Day 3-4: 文件搜索工具

**任务**:
1. 实现文件名搜索
2. 实现内容搜索
3. 实现模糊匹配

**代码示例**:
```zig
// src/mcp/tools/file_search.zig
pub const FileSearchTool = struct {
    allocator: std.mem.Allocator,
    security: SecurityConfig,
    
    pub fn execute(self: *FileSearchTool, params: std.json.Value) !std.json.Value {
        const query = params.object.get("query") orelse return error.MissingQuery;
        const search_type = params.object.get("type") orelse "filename";
        
        var results = std.ArrayList(SearchResult).init(self.allocator);
        defer results.deinit();
        
        if (std.mem.eql(u8, search_type.string, "filename")) {
            try self.searchByFilename(query.string, &results);
        } else if (std.mem.eql(u8, search_type.string, "content")) {
            try self.searchByContent(query.string, &results);
        }
        
        return std.json.Value{
            .array = results.items,
        };
    }
    
    fn searchByFilename(self: *FileSearchTool, query: []const u8, results: *std.ArrayList(SearchResult)) !void {
        try self.walkDirectory("src/", query, results);
    }
    
    fn searchByContent(self: *FileSearchTool, query: []const u8, results: *std.ArrayList(SearchResult)) !void {
        // 实现内容搜索
        // 使用 grep 或自定义搜索算法
    }
};
```

**交付物**:
- ✅ `src/mcp/tools/file_search.zig`
- ✅ 文件搜索正常
- ✅ 内容搜索正常

---

#### Day 5: 文件读取工具

**任务**:
1. 实现文件读取
2. 实现权限检查
3. 实现内容过滤

**代码示例**:
```zig
// src/mcp/tools/file_read.zig
pub const FileReadTool = struct {
    allocator: std.mem.Allocator,
    security: SecurityConfig,
    
    pub fn execute(self: *FileReadTool, params: std.json.Value) !std.json.Value {
        const path = params.object.get("path") orelse return error.MissingPath;
        
        // 安全检查
        if (!try self.isPathAllowed(path.string)) {
            return error.PathNotAllowed;
        }
        
        // 读取文件
        const content = try std.fs.cwd().readFileAlloc(
            self.allocator,
            path.string,
            10 * 1024 * 1024, // 10MB 限制
        );
        defer self.allocator.free(content);
        
        // 过滤敏感信息
        const filtered = try self.filterSensitive(content);
        
        return std.json.Value{
            .object = .{
                .put("path", path.string),
                .put("content", filtered),
                .put("size", content.len),
            },
        };
    }
    
    fn isPathAllowed(self: *FileReadTool, path: []const u8) !bool {
        // 检查是否在允许的路径中
        for (self.security.allowed_paths) |allowed| {
            if (std.mem.startsWith(u8, path, allowed)) {
                // 检查是否在禁止的路径中
                for (self.security.forbidden_paths) |forbidden| {
                    if (std.mem.indexOf(u8, path, forbidden) != null) {
                        return false;
                    }
                }
                return true;
            }
        }
        return false;
    }
    
    fn filterSensitive(self: *FileReadTool, content: []const u8) ![]const u8 {
        // 过滤密码、密钥等敏感信息
        // 简单实现：替换常见的敏感字段
        var filtered = try self.allocator.dupe(u8, content);
        
        const patterns = [_][]const u8{
            "password",
            "secret",
            "api_key",
            "token",
        };
        
        for (patterns) |pattern| {
            // 实现替换逻辑
        }
        
        return filtered;
    }
};
```

**交付物**:
- ✅ `src/mcp/tools/file_read.zig`
- ✅ 文件读取正常
- ✅ 安全检查有效

---

## 第一阶段交付检查清单

- [ ] MCP Server 可启动
- [ ] SSE 端点可连接
- [ ] AI 编辑器可连接成功
- [ ] 项目结构工具可用
- [ ] 文件搜索工具可用
- [ ] 文件读取工具可用
- [ ] 所有代码编译通过
- [ ] 基础测试通过
- [ ] 文档完整

---

## 第二阶段：代码生成工具（Week 3-4）

### Week 3: CRUD 生成器

#### Day 1-3: 模型和 DTO 生成

**任务**:
1. 实现模型代码生成
2. 实现 DTO 代码生成
3. 实现字段类型映射

**代码模板**:
```zig
// 模型模板
pub const {ModelName} = struct {{
    id: ?i32 = null,
{fields}
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
}};

// DTO 模板
pub const Create{ModelName}Dto = struct {{
{fields}
}};
```

**交付物**:
- ✅ 模型生成器
- ✅ DTO 生成器
- ✅ 字段类型映射

---

#### Day 4-5: 控制器和路由生成

**任务**:
1. 实现控制器代码生成
2. 实现路由注册代码生成
3. 实现 CRUD 方法生成

**交付物**:
- ✅ 控制器生成器
- ✅ 路由生成器
- ✅ CRUD 方法完整

---

### Week 4: 数据库和测试

#### Day 1-2: 数据库迁移生成

**任务**:
1. 实现迁移文件生成
2. 实现 SQL 生成
3. 实现迁移执行

**交付物**:
- ✅ 迁移生成器
- ✅ SQL 生成正确

---

#### Day 3-5: 测试生成和集成

**任务**:
1. 实现单元测试生成
2. 实现集成测试生成
3. 集成所有生成器

**交付物**:
- ✅ 测试生成器
- ✅ 完整的 CRUD 生成流程

---

## 第三阶段：高级功能（Week 5-6）

### Week 5: 智能重构

#### Day 1-3: 代码分析

**任务**:
1. 实现代码解析
2. 实现模式识别
3. 实现问题检测

**交付物**:
- ✅ 代码分析工具
- ✅ 问题检测准确

---

#### Day 4-5: 重构建议

**任务**:
1. 实现重构建议生成
2. 实现自动重构

**交付物**:
- ✅ 重构建议工具
- ✅ 自动重构可用

---

### Week 6: 安全和性能

#### Day 1-3: 安全审计

**任务**:
1. 实现安全扫描
2. 实现漏洞检测
3. 实现修复建议

**交付物**:
- ✅ 安全审计工具
- ✅ 漏洞检测准确

---

#### Day 4-5: 性能优化和发布

**任务**:
1. 实现性能分析
2. 实现优化建议
3. 完成文档和发布

**交付物**:
- ✅ 性能分析工具
- ✅ 完整文档
- ✅ v1.0 发布

---

## 测试计划

### 单元测试
- [ ] 每个工具的单元测试
- [ ] 协议层测试
- [ ] 传输层测试

### 集成测试
- [ ] MCP Server 启动测试
- [ ] AI 编辑器连接测试
- [ ] 工具执行测试

### 端到端测试
- [ ] CRUD 生成完整流程
- [ ] 代码生成质量验证
- [ ] 性能测试

---

## 风险和缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| SSE 连接不稳定 | 高 | 实现重连机制 |
| 代码生成质量 | 高 | 充分测试模板 |
| 安全漏洞 | 高 | 严格权限检查 |
| 性能问题 | 中 | 优化算法 |
| 兼容性问题 | 中 | 测试多个 AI 编辑器 |

---

## 成功标准

1. ✅ MCP Server 稳定运行
2. ✅ AI 编辑器可连接
3. ✅ 代码生成质量高
4. ✅ 安全检查有效
5. ✅ 文档完整
6. ✅ 测试覆盖率 > 80%

---

**下一步**: 开始第一阶段实施
