# MCP 端口配置说明

## 重要说明

**MCP 服务使用主 HTTP 服务器的端口，而不是 `config/mcp.yaml` 中配置的端口。**

## 端口配置

### 主 HTTP 服务器端口

**配置文件**：`config/api.yaml`

```yaml
host: "127.0.0.1"
port: 3000  # 主 HTTP 服务器端口
```

### MCP 端口配置（已废弃）

**配置文件**：`config/mcp.yaml`

```yaml
transport:
  host: "127.0.0.1"
  port: 8889  # ⚠️ 此端口配置已废弃，MCP 使用主 HTTP 服务器端口
```

## 实际端点地址

假设主 HTTP 服务器运行在 `http://127.0.0.1:3000`：

- **SSE 端点**：`http://127.0.0.1:3000/mcp/sse`
- **消息端点**：`http://127.0.0.1:3000/mcp/message`

## 为什么这样设计？

### 1. 简化部署

- 只需要一个 HTTP 服务器
- 不需要额外的端口配置
- 减少防火墙配置

### 2. 统一管理

- 所有路由在同一个服务器上
- 统一的中间件和认证
- 统一的日志和监控

### 3. 避免端口冲突

- 不需要管理多个端口
- 减少端口占用
- 简化网络配置

## 配置示例

### 1. 查看主服务器端口

```bash
cat config/api.yaml | grep port
```

**输出**：
```yaml
port: 3000
```

### 2. 启动服务器

```bash
zig build run
```

**启动日志**：
```
╔══════════════════════════════════════════════════════════════╗
║                    ZigCMS 启动摘要                           ║
╠══════════════════════════════════════════════════════════════╣
║ 📡 服务器配置:                                               ║
║    地址: http://127.0.0.1:3000                               ║
╠══════════════════════════════════════════════════════════════╣
║ 🤖 MCP 服务:                                                 ║
║    状态: ✅ 已启用                                            ║
║    SSE 端点: http://127.0.0.1:3000/mcp/sse                   ║
║    消息端点: http://127.0.0.1:3000/mcp/message               ║
╚══════════════════════════════════════════════════════════════╝
```

### 3. 测试 MCP 端点

```bash
# 测试 SSE 端点
curl http://127.0.0.1:3000/mcp/sse

# 测试消息端点
curl -X POST http://127.0.0.1:3000/mcp/message \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

## 客户端配置

### Claude Desktop 配置

**文件**：`~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "zigcms": {
      "command": "curl",
      "args": [
        "-N",
        "-H", "Accept: text/event-stream",
        "http://127.0.0.1:3000/mcp/sse"
      ]
    }
  }
}
```

**注意**：使用主服务器端口 `3000`，而不是 MCP 配置的端口 `8889`。

### Cline 配置

**文件**：`.vscode/settings.json` 或 `~/.config/Code/User/settings.json`

```json
{
  "cline.mcpServers": {
    "zigcms": {
      "url": "http://127.0.0.1:3000/mcp/sse"
    }
  }
}
```

## 常见错误

### 错误 1：连接被拒绝

**错误信息**：
```
failed to connect to SSE stream: Get "http://127.0.0.1:8889/sse": 
dial tcp 127.0.0.1:8889: connect: connection refused
```

**原因**：使用了 MCP 配置的端口 `8889`，而不是主服务器端口 `3000`。

**解决方案**：
```json
// ❌ 错误
"url": "http://127.0.0.1:8889/mcp/sse"

// ✅ 正确
"url": "http://127.0.0.1:3000/mcp/sse"
```

### 错误 2：404 Not Found

**错误信息**：
```
404 Not Found
```

**原因**：路径错误或 MCP 服务未启用。

**解决方案**：

1. 检查 MCP 是否启用：
```yaml
# config/mcp.yaml
enabled: true
```

2. 检查路径是否正确：
```bash
# ✅ 正确
curl http://127.0.0.1:3000/mcp/sse

# ❌ 错误（缺少 /mcp 前缀）
curl http://127.0.0.1:3000/sse
```

### 错误 3：端口已被占用

**错误信息**：
```
Address already in use
```

**原因**：主服务器端口 `3000` 已被占用。

**解决方案**：

1. 查找占用端口的进程：
```bash
lsof -i :3000
```

2. 修改主服务器端口：
```yaml
# config/api.yaml
port: 3001  # 使用其他端口
```

3. 重启服务器：
```bash
zig build run
```

4. 更新客户端配置：
```json
{
  "url": "http://127.0.0.1:3001/mcp/sse"
}
```

## 端口规划建议

### 开发环境

- **主服务器**：`3000`
- **MCP 端点**：`http://127.0.0.1:3000/mcp/*`

### 生产环境

- **主服务器**：`80` 或 `443`（HTTPS）
- **MCP 端点**：`https://your-domain.com/mcp/*`

### 多实例部署

如果需要运行多个实例：

```yaml
# 实例 1
# config/api.yaml
port: 3000

# 实例 2
# config/api.yaml
port: 3001

# 实例 3
# config/api.yaml
port: 3002
```

对应的 MCP 端点：
- 实例 1：`http://127.0.0.1:3000/mcp/sse`
- 实例 2：`http://127.0.0.1:3001/mcp/sse`
- 实例 3：`http://127.0.0.1:3002/mcp/sse`

## 总结

1. **MCP 使用主 HTTP 服务器端口**（`config/api.yaml` 中的 `port`）
2. **MCP 配置中的端口已废弃**（`config/mcp.yaml` 中的 `transport.port`）
3. **客户端配置使用主服务器端口**（例如 `http://127.0.0.1:3000/mcp/sse`）
4. **启动日志显示正确的端点地址**

---

**老铁，记住：MCP 端点 = 主服务器地址 + MCP 路径！** 🚀
