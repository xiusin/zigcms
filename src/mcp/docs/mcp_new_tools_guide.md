# MCP 新增工具指南

## 工具概览

ZigCMS MCP 现已支持 **9 个工具**：

### 原有工具（7 个）

1. **项目结构工具** - 查看项目目录结构
2. **文件搜索工具** - 搜索文件内容
3. **文件读取工具** - 读取文件内容
4. **CRUD 生成工具** - 生成完整 CRUD 模块
5. **模型生成工具** - 生成数据模型
6. **迁移生成工具** - 生成数据库迁移
7. **测试生成工具** - 生成测试代码

### 新增工具（2 个）

8. **知识库问答工具** - 查询项目文档和最佳实践
9. **数据库操作工具** - 查询和操作数据库

---

## 工具 8：知识库问答工具

### 功能说明

智能查询 ZigCMS 项目的文档、架构、最佳实践等知识库内容。

### 工具定义

```json
{
  "name": "knowledge_base_query",
  "description": "查询 ZigCMS 项目知识库，包括文档、架构、最佳实践等",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "查询问题，例如：'如何使用 ORM'、'内存管理规范'、'MCP 工具列表'"
      }
    },
    "required": ["query"]
  }
}
```

### 使用示例

#### 示例 1：查询 ORM 使用方法

**请求**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "knowledge_base_query",
    "arguments": {
      "query": "如何使用 ORM"
    }
  },
  "id": 1
}
```

**响应**：
```markdown
# 知识库查询结果

**查询**: 如何使用 ORM

## 相关文档

## orm_memory_lifecycle.md

ZigCMS ORM 内存生命周期管理

### 核心原则

1. ORM 查询返回的对象由 ORM 内部分配器管理
2. 使用 `defer freeModels()` 释放
3. 需要长期持有数据时必须深拷贝字符串字段
...

---

## orm_update_with_anonymous_struct.md

ORM 部分更新优化

### 推荐方案：UpdateWith

使用匿名结构体 .{} 动态构建更新字段
...
```

#### 示例 2：查询内存管理规范

**请求**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "knowledge_base_query",
    "arguments": {
      "query": "内存管理 内存泄漏"
    }
  },
  "id": 2
}
```

**响应**：
```markdown
# 知识库查询结果

**查询**: 内存管理 内存泄漏

## 相关文档

## memory_leak_basics.md

Zig 内存泄漏防范基础

### 常见内存泄漏场景

1. 忘记释放分配的内存
2. 错误的生命周期管理
3. 循环引用
...

---

## AGENTS.md

### 关键注意事项与常见陷阱

#### 1.1 ORM 查询结果的悬垂指针

**问题**：ORM 查询返回的对象在 `freeModels()` 后内存被释放，浅拷贝会导致悬垂指针。
...
```

#### 示例 3：查询 MCP 工具列表

**请求**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "knowledge_base_query",
    "arguments": {
      "query": "MCP 工具"
    }
  },
  "id": 3
}
```

**响应**：
```markdown
# 知识库查询结果

**查询**: MCP 工具

## 相关文档

## mcp_tools_complete_guide.md

# ZigCMS MCP 工具集完整指南

## 工具概览

ZigCMS MCP 提供 7 个核心工具：

1. **项目结构工具** (project_structure)
2. **文件搜索工具** (file_search)
3. **文件读取工具** (file_read)
...
```

### 搜索范围

知识库工具会搜索以下目录：

1. **docs/** - 项目文档
2. **src/mcp/docs/** - MCP 文档
3. **knowlages/** - 技术知识库
4. **AGENTS.md** - 开发规范
5. **README.md** - 项目概览

### 搜索策略

1. **关键词提取**：从查询中提取关键词（长度 > 2）
2. **文件匹配**：搜索所有 `.md` 文件
3. **内容匹配**：检查文件内容是否包含关键词
4. **结果预览**：返回匹配文件的前 500 字符

### 最佳实践

1. **使用具体关键词**：
   - ✅ "ORM 查询 内存管理"
   - ❌ "怎么用"

2. **组合多个关键词**：
   - ✅ "MCP 工具 数据库"
   - ❌ "MCP"

3. **使用技术术语**：
   - ✅ "内存泄漏 悬垂指针"
   - ❌ "内存问题"

---

## 工具 9：数据库操作工具

### 功能说明

安全地查询和操作 ZigCMS 数据库，支持表结构查询、记录统计、数据查询等。

### 工具定义

```json
{
  "name": "database_query",
  "description": "查询和操作 ZigCMS 数据库",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query_type": {
        "type": "string",
        "enum": ["list_tables", "describe_table", "count_records", "query_records", "execute_sql"],
        "description": "查询类型"
      },
      "params": {
        "type": "object",
        "description": "查询参数",
        "properties": {
          "table": {
            "type": "string",
            "description": "表名"
          },
          "limit": {
            "type": "integer",
            "description": "查询限制（默认 10）"
          },
          "sql": {
            "type": "string",
            "description": "SQL 语句（危险操作）"
          }
        }
      }
    },
    "required": ["query_type", "params"]
  }
}
```

### 查询类型

#### 1. list_tables - 列出所有表

**请求**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "database_query",
    "arguments": {
      "query_type": "list_tables",
      "params": {}
    }
  },
  "id": 1
}
```

**响应**：
```markdown
# 数据库表列表

| 表名 | 类型 |
|------|------|
| sys_admin | table |
| sys_role | table |
| sys_menu | table |
| sys_dept | table |
| sys_role_menu | table |
| sys_admin_role | table |
```

#### 2. describe_table - 描述表结构

**请求**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "database_query",
    "arguments": {
      "query_type": "describe_table",
      "params": {
        "table": "sys_admin"
      }
    }
  },
  "id": 2
}
```

**响应**：
```markdown
# 表结构: sys_admin

| 字段名 | 类型 | 可空 | 默认值 | 备注 |
|--------|------|------|--------|------|
| id | INTEGER | NO | NULL | 主键 |
| username | TEXT | NO | NULL | 用户名 |
| password | TEXT | NO | NULL | 密码 |
| nickname | TEXT | YES | NULL | 昵称 |
| email | TEXT | YES | NULL | 邮箱 |
| status | INTEGER | NO | 1 | 状态 |
| created_at | INTEGER | YES | NULL | 创建时间 |
| updated_at | INTEGER | YES | NULL | 更新时间 |
```

#### 3. count_records - 统计记录数

**请求**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "database_query",
    "arguments": {
      "query_type": "count_records",
      "params": {
        "table": "sys_admin"
      }
    }
  },
  "id": 3
}
```

**响应**：
```markdown
# 记录统计: sys_admin

总记录数: 10
```

#### 4. query_records - 查询记录

**请求**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "database_query",
    "arguments": {
      "query_type": "query_records",
      "params": {
        "table": "sys_admin",
        "limit": 5
      }
    }
  },
  "id": 4
}
```

**响应**：
```markdown
# 查询结果: sys_admin

**限制**: 5 条

```json
[
  {
    "id": 1,
    "username": "admin",
    "nickname": "管理员",
    "email": "admin@example.com",
    "status": 1
  },
  {
    "id": 2,
    "username": "user1",
    "nickname": "用户1",
    "email": "user1@example.com",
    "status": 1
  }
]
```
```

#### 5. execute_sql - 执行 SQL（危险操作）

**请求**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "database_query",
    "arguments": {
      "query_type": "execute_sql",
      "params": {
        "sql": "SELECT COUNT(*) FROM sys_admin WHERE status = 1"
      }
    }
  },
  "id": 5
}
```

**响应**：
```markdown
# SQL 执行结果

**SQL**: SELECT COUNT(*) FROM sys_admin WHERE status = 1

执行成功
```

### 安全限制

#### 1. 写操作限制

默认情况下，写操作（INSERT/UPDATE/DELETE）被禁用。

需要在配置中启用：

```yaml
# config/mcp.yaml
security:
  allow_write_operations: true
```

#### 2. 危险 SQL 检测

以下 SQL 语句会被拒绝：

- `DROP` - 删除表
- `DELETE` - 删除记录
- `TRUNCATE` - 清空表

#### 3. 查询限制

- 默认查询限制：10 条记录
- 最大查询限制：100 条记录

### 最佳实践

#### 1. 优先使用安全查询

```json
// ✅ 推荐：使用 query_records
{
  "query_type": "query_records",
  "params": {
    "table": "sys_admin",
    "limit": 10
  }
}

// ❌ 避免：使用 execute_sql
{
  "query_type": "execute_sql",
  "params": {
    "sql": "SELECT * FROM sys_admin LIMIT 10"
  }
}
```

#### 2. 先查看表结构

```json
// 1. 列出所有表
{ "query_type": "list_tables", "params": {} }

// 2. 查看表结构
{ "query_type": "describe_table", "params": { "table": "sys_admin" } }

// 3. 查询数据
{ "query_type": "query_records", "params": { "table": "sys_admin", "limit": 5 } }
```

#### 3. 使用合理的限制

```json
// ✅ 推荐：小批量查询
{ "query_type": "query_records", "params": { "table": "sys_admin", "limit": 10 } }

// ❌ 避免：大批量查询
{ "query_type": "query_records", "params": { "table": "sys_admin", "limit": 1000 } }
```

---

## 工具集成

### 启动日志

启动服务器时会显示工具信息：

```
╔══════════════════════════════════════════════════════════════╗
║                    ZigCMS 启动摘要                           ║
╠══════════════════════════════════════════════════════════════╣
║ 🤖 MCP 服务:                                                 ║
║    状态: ✅ 已启用                                            ║
║    SSE 端点: http://127.0.0.1:3000/mcp/sse                   ║
║    消息端点: http://127.0.0.1:3000/mcp/message               ║
║    工具数量: 9 个                                            ║
║      - 项目结构/搜索/读取                                    ║
║      - CRUD/模型/迁移/测试生成                               ║
║      - 知识库问答/数据库操作                                 ║
║    📖 文档: src/mcp/docs/INDEX.md                            ║
╚══════════════════════════════════════════════════════════════╝
```

### 工具列表

通过 MCP 协议查询工具列表：

```json
{
  "jsonrpc": "2.0",
  "method": "tools/list",
  "id": 1
}
```

**响应**：
```json
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {
        "name": "project_structure",
        "description": "查看项目目录结构"
      },
      {
        "name": "file_search",
        "description": "搜索文件内容"
      },
      {
        "name": "file_read",
        "description": "读取文件内容"
      },
      {
        "name": "crud_generator",
        "description": "生成完整 CRUD 模块"
      },
      {
        "name": "model_generator",
        "description": "生成数据模型"
      },
      {
        "name": "migration_generator",
        "description": "生成数据库迁移"
      },
      {
        "name": "test_generator",
        "description": "生成测试代码"
      },
      {
        "name": "knowledge_base_query",
        "description": "查询 ZigCMS 项目知识库"
      },
      {
        "name": "database_query",
        "description": "查询和操作 ZigCMS 数据库"
      }
    ]
  },
  "id": 1
}
```

---

## 使用场景

### 场景 1：学习项目架构

```json
// 1. 查询架构文档
{
  "name": "knowledge_base_query",
  "arguments": {
    "query": "整洁架构 分层"
  }
}

// 2. 查看项目结构
{
  "name": "project_structure",
  "arguments": {
    "path": "src"
  }
}

// 3. 查看数据库表
{
  "name": "database_query",
  "arguments": {
    "query_type": "list_tables",
    "params": {}
  }
}
```

### 场景 2：开发新功能

```json
// 1. 查询最佳实践
{
  "name": "knowledge_base_query",
  "arguments": {
    "query": "CRUD 生成 关系推导"
  }
}

// 2. 查看表结构
{
  "name": "database_query",
  "arguments": {
    "query_type": "describe_table",
    "params": {
      "table": "sys_admin"
    }
  }
}

// 3. 生成 CRUD 模块
{
  "name": "crud_generator",
  "arguments": {
    "model_name": "Article",
    "fields": [...]
  }
}
```

### 场景 3：调试问题

```json
// 1. 查询错误处理规范
{
  "name": "knowledge_base_query",
  "arguments": {
    "query": "错误处理 内存安全"
  }
}

// 2. 查看数据
{
  "name": "database_query",
  "arguments": {
    "query_type": "query_records",
    "params": {
      "table": "sys_admin",
      "limit": 5
    }
  }
}

// 3. 读取相关代码
{
  "name": "file_read",
  "arguments": {
    "path": "src/api/controllers/admin.zig"
  }
}
```

---

## 配置

### 启用新工具

新工具默认启用，无需额外配置。

### 安全配置

```yaml
# config/mcp.yaml
security:
  # 允许写操作（数据库工具需要）
  allow_write_operations: false
  
  # 允许访问的路径（知识库工具需要）
  allowed_paths:
    - "src/"
    - "docs/"
    - "knowlages/"
    - "AGENTS.md"
    - "README.md"
```

---

## 总结

### 新增工具优势

1. **知识库问答**：
   - ✅ 快速查找文档
   - ✅ 智能关键词匹配
   - ✅ 多目录搜索
   - ✅ 结果预览

2. **数据库操作**：
   - ✅ 安全查询
   - ✅ 表结构查看
   - ✅ 记录统计
   - ✅ 数据查询
   - ✅ SQL 执行（受限）

### 工具总数

**9 个工具**：
1. 项目结构
2. 文件搜索
3. 文件读取
4. CRUD 生成
5. 模型生成
6. 迁移生成
7. 测试生成
8. **知识库问答**（新增）
9. **数据库操作**（新增）

### 下一步

- 查看 [MCP 文档索引](INDEX.md)
- 查看 [MCP 快速开始](mcp_quick_start.md)
- 查看 [MCP 完整指南](mcp_user_guide.md)

---

**老铁，开始使用新工具吧！** 🚀
