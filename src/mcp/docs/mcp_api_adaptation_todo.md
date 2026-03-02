# MCP 模块 Zig 0.15.2 API 适配 TODO

## 问题描述

MCP 模块使用了 Zig 0.14 的 API，需要适配到 Zig 0.15.2。

## 需要修复的 API

### 1. ArrayList 初始化

**问题**：
```zig
// ❌ Zig 0.14 (不再可用)
var list = std.ArrayList(u8).init(allocator);

// ❌ Zig 0.15.2 (API 已改变)
// std.ArrayList 不再有 .init() 方法
```

**解决方案**：
需要查找 Zig 0.15.2 的正确 ArrayList 初始化方式。

**影响文件**：
- `src/mcp/protocol/jsonrpc.zig` - serializeResponse 方法
- `src/mcp/tools/file_search.zig` - execute 方法
- `src/mcp/tools/project_structure.zig` - execute 方法
- `src/mcp/transport/sse.zig` - cleanupStaleConnections 方法

### 2. JSON 序列化

**问题**：
```zig
// ❌ Zig 0.15.2 (不可用)
const json = try std.json.stringifyAlloc(allocator, value, .{});
```

**临时方案**：
```zig
// ✅ 使用 stringify + writer
var list = std.ArrayList(u8).init(allocator);  // 需要先修复 ArrayList
defer list.deinit();
try std.json.stringify(list.writer(), value, .{});
return try list.toOwnedSlice();
```

**影响文件**：
- `src/mcp/protocol/jsonrpc.zig` - serializeResponse 方法

## 当前状态

- ✅ MCP 基础框架已实现
- ✅ 配置模块已集成到 SystemConfig
- ✅ 路由注册逻辑已添加（但已禁用）
- ⏸️ MCP 功能暂时禁用，等待 API 适配

## 下一步

1. **研究 Zig 0.15.2 API**
   - 查看 Zig 0.15.2 的 ArrayList 文档
   - 查看 Zig 0.15.2 的 JSON API 文档

2. **适配 ArrayList**
   - 修复所有 ArrayList.init() 调用
   - 测试编译

3. **适配 JSON 序列化**
   - 修复 serializeResponse 方法
   - 测试编译

4. **启用 MCP 功能**
   - 取消 registerMcpRoutes 中的注释
   - 完整测试

5. **测试 MCP 功能**
   - 测试 SSE 连接
   - 测试 JSON-RPC 消息处理
   - 测试工具调用

## 参考

- Zig 0.15.2 Release Notes: https://ziglang.org/download/0.15.2/release-notes.html
- Zig Standard Library Docs: https://ziglang.org/documentation/0.15.2/std/

## 临时解决方案

当前 MCP 功能已暂时禁用，主程序可以正常编译和运行。
在 `src/api/bootstrap.zig` 的 `registerMcpRoutes` 方法中，所有 MCP 相关代码已被注释。

启动时会显示：
```
ℹ️  MCP 服务暂时禁用（开发中）
```
