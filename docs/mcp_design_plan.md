# ZigCMS MCP 功能设计与实现方案

**日期**: 2026-03-02  
**版本**: v1.0  
**参考项目**: gin-vue-admin, Model Context Protocol Specification

---

## 📋 目录

1. [项目概述](#项目概述)
2. [MCP 协议简介](#mcp-协议简介)
3. [功能目标](#功能目标)
4. [架构设计](#架构设计)
5. [技术选型](#技术选型)
6. [实现计划](#实现计划)
7. [安全考虑](#安全考虑)

---

## 项目概述

### 什么是 MCP？

**Model Context Protocol (MCP)** 是一个开放协议，用于在 LLM 应用和外部数据源/工具之间建立标准化集成。

### 为什么 ZigCMS 需要 MCP？

1. **AI 辅助开发**: 让 AI 编辑器（Claude、Cursor、Windsurf 等）深度理解 ZigCMS 项目结构
2. **智能代码生成**: AI 自动生成符合 ZigCMS 架构的 CRUD 代码
3. **提升开发效率**: 通过自然语言描述需求，AI 自动完成代码编写
4. **降低学习成本**: 新开发者通过 AI 助手快速上手 ZigCMS

### 参考实现

**gin-vue-admin MCP 功能**:
- SSE (Server-Sent Events) 传输协议
- 智能代码生成工具
- 文件搜索和定位
- 项目结构理解
- 自动化 CRUD 生成

---

## MCP 协议简介

### 核心概念

```
┌─────────────────────────────────────────────────────────┐
│                    MCP 架构                              │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐         ┌──────────┐         ┌─────────┐ │
│  │   Host   │────────▶│  Client  │────────▶│ Server  │ │
│  │ (AI编辑器)│◀────────│ (连接器)  │◀────────│(ZigCMS) │ │
│  └──────────┘         └──────────┘         └─────────┘ │
│                                                          │
│  - Claude Code        - MCP Client        - MCP Server  │
│  - Cursor             - JSON-RPC          - Tools       │
│  - Windsurf           - SSE/stdio         - Resources   │
│                                            - Prompts     │
└─────────────────────────────────────────────────────────┘
```

### 协议特性

1. **JSON-RPC 2.0**: 消息格式
2. **传输协议**: SSE (Server-Sent Events) 或 stdio
3. **服务端功能**:
   - **Resources**: 上下文和数据
   - **Tools**: AI 可执行的函数
   - **Prompts**: 模板化消息和工作流
4. **客户端功能**:
   - **Sampling**: 服务端发起的 LLM 交互

---

## 功能目标

### 第一阶段：基础 MCP 服务 (v1.0)

**核心功能**:
- ✅ MCP Server 基础框架
- ✅ SSE 传输协议实现
- ✅ 项目结构理解工具
- ✅ 文件搜索和读取工具
- ✅ 基础配置管理

**预期效果**:
- AI 能理解 ZigCMS 项目结构
- AI 能搜索和读取项目文件
- AI 能提供代码建议

### 第二阶段：代码生成工具 (v1.1)

**核心功能**:
- ✅ CRUD 代码生成工具
- ✅ 模型生成工具
- ✅ 控制器生成工具
- ✅ 路由注册工具
- ✅ 数据库迁移生成

**预期效果**:
- AI 自动生成完整的 CRUD 模块
- AI 自动生成符合架构的代码
- AI 自动注册路由和权限

### 第三阶段：高级功能 (v1.2)

**核心功能**:
- ✅ 智能重构工具
- ✅ 代码分析工具
- ✅ 性能优化建议
- ✅ 安全审计工具
- ✅ 测试生成工具

**预期效果**:
- AI 提供代码重构建议
- AI 发现潜在问题
- AI 生成测试用例

---

## 架构设计

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      ZigCMS MCP 架构                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              AI 编辑器 (Host)                       │    │
│  │  - Claude Code / Cursor / Windsurf                 │    │
│  └────────────────────┬───────────────────────────────┘    │
│                       │ JSON-RPC over SSE                   │
│                       ▼                                      │
│  ┌────────────────────────────────────────────────────┐    │
│  │           ZigCMS MCP Server                         │    │
│  │  ┌──────────────────────────────────────────────┐  │    │
│  │  │  Transport Layer (SSE)                       │  │    │
│  │  │  - HTTP Server (端口 8889)                   │  │    │
│  │  │  - SSE Endpoint: /mcp/sse                    │  │    │
│  │  │  - Message Endpoint: /mcp/message            │  │    │
│  │  └──────────────────────────────────────────────┘  │    │
│  │  ┌──────────────────────────────────────────────┐  │    │
│  │  │  Protocol Layer (JSON-RPC 2.0)               │  │    │
│  │  │  - Request Handler                           │  │    │
│  │  │  - Response Builder                          │  │    │
│  │  │  - Error Handler                             │  │    │
│  │  └──────────────────────────────────────────────┘  │    │
│  │  ┌──────────────────────────────────────────────┐  │    │
│  │  │  Tools Layer                                 │  │    │
│  │  │  - Project Structure Tool                    │  │    │
│  │  │  - File Search Tool                          │  │    │
│  │  │  - Code Generation Tool                      │  │    │
│  │  │  - CRUD Generator Tool                       │  │    │
│  │  └──────────────────────────────────────────────┘  │    │
│  │  ┌──────────────────────────────────────────────┐  │    │
│  │  │  Resources Layer                             │  │    │
│  │  │  - Project Files                             │  │    │
│  │  │  - Configuration                             │  │    │
│  │  │  - Documentation                             │  │    │
│  │  └──────────────────────────────────────────────┘  │    │
│  │  ┌──────────────────────────────────────────────┐  │    │
│  │  │  Prompts Layer                               │  │    │
│  │  │  - CRUD Generation Prompt                    │  │    │
│  │  │  - Refactor Prompt                           │  │    │
│  │  │  - Debug Prompt                              │  │    │
│  │  └──────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────┘    │
│                       │                                      │
│                       ▼                                      │
│  ┌────────────────────────────────────────────────────┐    │
│  │           ZigCMS Core Services                      │    │
│  │  - File System                                      │    │
│  │  - Code Generator                                   │    │
│  │  - ORM                                              │    │
│  │  - Router                                           │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 目录结构

```
src/
├── mcp/
│   ├── mod.zig                    # MCP 模块入口
│   ├── server.zig                 # MCP Server 主逻辑
│   ├── transport/
│   │   ├── mod.zig                # 传输层入口
│   │   ├── sse.zig                # SSE 传输实现
│   │   └── stdio.zig              # stdio 传输实现（可选）
│   ├── protocol/
│   │   ├── mod.zig                # 协议层入口
│   │   ├── jsonrpc.zig            # JSON-RPC 2.0 实现
│   │   ├── types.zig              # 协议类型定义
│   │   └── handler.zig            # 请求处理器
│   ├── tools/
│   │   ├── mod.zig                # 工具层入口
│   │   ├── project_structure.zig  # 项目结构工具
│   │   ├── file_search.zig        # 文件搜索工具
│   │   ├── code_generator.zig     # 代码生成工具
│   │   └── crud_generator.zig     # CRUD 生成工具
│   ├── resources/
│   │   ├── mod.zig                # 资源层入口
│   │   ├── files.zig              # 文件资源
│   │   └── config.zig             # 配置资源
│   └── prompts/
│       ├── mod.zig                # 提示层入口
│       ├── crud.zig               # CRUD 生成提示
│       └── refactor.zig           # 重构提示
├── core/
│   └── config/
│       └── mcp.zig                # MCP 配置
└── ...
```

---

## 技术选型

### 传输协议

**选择**: SSE (Server-Sent Events)

**理由**:
1. ✅ HTTP 协议，易于实现和调试
2. ✅ 单向推送，适合服务端主动通知
3. ✅ 浏览器原生支持
4. ✅ gin-vue-admin 使用 SSE，成熟方案

**实现**:
- 使用 Zig 的 HTTP 服务器（zap）
- SSE 端点：`http://127.0.0.1:8889/mcp/sse`
- 消息端点：`http://127.0.0.1:8889/mcp/message`

### 消息格式

**选择**: JSON-RPC 2.0

**理由**:
1. ✅ MCP 协议标准
2. ✅ 简单易用
3. ✅ 广泛支持

**示例**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "generate_crud",
    "arguments": {
      "model_name": "Article",
      "fields": ["title", "content", "author"]
    }
  }
}
```

### 数据序列化

**选择**: std.json

**理由**:
1. ✅ Zig 标准库
2. ✅ 零依赖
3. ✅ 性能优秀

---

## 实现计划

### 阶段 1：基础框架（第 1-2 周）

#### 任务 1.1：MCP Server 基础框架
- [ ] 创建 MCP 模块目录结构
- [ ] 实现 MCP Server 主逻辑
- [ ] 实现配置加载
- [ ] 实现生命周期管理

#### 任务 1.2：SSE 传输层
- [ ] 实现 SSE HTTP 端点
- [ ] 实现消息接收端点
- [ ] 实现连接管理
- [ ] 实现心跳机制

#### 任务 1.3：JSON-RPC 协议层
- [ ] 实现 JSON-RPC 2.0 解析
- [ ] 实现请求路由
- [ ] 实现响应构建
- [ ] 实现错误处理

#### 任务 1.4：基础工具
- [ ] 实现项目结构工具
- [ ] 实现文件搜索工具
- [ ] 实现文件读取工具

**交付物**:
- ✅ 可运行的 MCP Server
- ✅ AI 编辑器可连接
- ✅ 基础工具可用

---

### 阶段 2：代码生成工具（第 3-4 周）

#### 任务 2.1：CRUD 生成器
- [ ] 实现模型生成
- [ ] 实现 DTO 生成
- [ ] 实现控制器生成
- [ ] 实现路由注册

#### 任务 2.2：数据库迁移
- [ ] 实现迁移文件生成
- [ ] 实现迁移执行

#### 任务 2.3：测试生成
- [ ] 实现单元测试生成
- [ ] 实现集成测试生成

**交付物**:
- ✅ 完整的 CRUD 生成工具
- ✅ AI 可自动生成代码
- ✅ 生成的代码符合架构

---

### 阶段 3：高级功能（第 5-6 周）

#### 任务 3.1：智能重构
- [ ] 实现代码分析
- [ ] 实现重构建议
- [ ] 实现自动重构

#### 任务 3.2：安全审计
- [ ] 实现安全扫描
- [ ] 实现漏洞检测
- [ ] 实现修复建议

#### 任务 3.3：性能优化
- [ ] 实现性能分析
- [ ] 实现优化建议

**交付物**:
- ✅ 智能重构工具
- ✅ 安全审计工具
- ✅ 性能优化工具

---

## 安全考虑

### 用户同意和控制

1. **显式同意**: 所有工具执行前需要用户确认
2. **权限控制**: 限制工具可访问的文件和目录
3. **操作日志**: 记录所有工具执行历史

### 数据隐私

1. **本地运行**: MCP Server 在本地运行，不上传数据
2. **敏感数据过滤**: 自动过滤敏感信息（密码、密钥等）
3. **访问控制**: 限制可访问的文件类型

### 工具安全

1. **沙箱执行**: 工具在受限环境中执行
2. **输入验证**: 严格验证所有输入参数
3. **输出过滤**: 过滤敏感输出

### 配置示例

```yaml
mcp:
  name: ZigCMS_MCP
  version: v1.0.0
  enabled: true
  
  # 传输配置
  transport:
    type: sse
    host: 127.0.0.1
    port: 8889
    sse_path: /mcp/sse
    message_path: /mcp/message
  
  # 安全配置
  security:
    # 允许访问的目录
    allowed_paths:
      - src/
      - docs/
      - knowlages/
    # 禁止访问的目录
    forbidden_paths:
      - .git/
      - .env
      - config/secrets/
    # 允许的文件类型
    allowed_extensions:
      - .zig
      - .md
      - .yaml
      - .json
  
  # 工具配置
  tools:
    enabled:
      - project_structure
      - file_search
      - file_read
      - generate_crud
      - generate_model
      - generate_controller
```

---

## 下一步

1. **评审方案**: 确认设计方案
2. **开始实现**: 按阶段实施
3. **测试验证**: 每个阶段完成后测试
4. **文档编写**: 编写使用文档

---

**参考资料**:
- [Model Context Protocol Specification](https://modelcontextprotocol.io/specification/2025-03-26)
- [gin-vue-admin MCP 文档](https://www.gin-vue-admin.com/guide/server/mcp.html)
- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/)
