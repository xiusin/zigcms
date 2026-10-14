# MCP 完整工具集使用指南

## 工具总览

ZigCMS MCP 提供 6 个核心工具：

| 工具 | 功能 | 用途 |
|------|------|------|
| project_structure | 项目结构分析 | 了解项目架构 |
| file_search | 文件搜索 | 查找文件和代码 |
| file_read | 文件读取 | 读取文件内容 |
| crud_generator | CRUD 生成器 | 生成完整 CRUD 模块 |
| model_generator | 模型生成器 | 生成 ORM 模型 |
| migration_generator | 迁移生成器 | 生成数据库迁移 SQL |

---

## 1. model_generator - 模型生成器

### 功能
生成带 ORM 集成的 ZigCMS 模型。

### 输入参数
```json
{
  "name": "Article",
  "table": "articles",
  "fields": [
    {
      "name": "id",
      "type": "int",
      "required": true,
      "primary_key": true
    },
    {
      "name": "title",
      "type": "string",
      "required": true
    },
    {
      "name": "content",
      "type": "text",
      "required": true
    },
    {
      "name": "created_at",
      "type": "timestamp",
      "required": false
    }
  ]
}
```

### 字段属性
- `name`: 字段名
- `type`: 字段类型
- `required`: 是否必填
- `primary_key`: 是否主键（可选）

### 输出示例
```zig
//! Article 模型
//! 表名: articles

const std = @import("std");
const orm = @import("../../application/services/sql/orm.zig");

pub const Article = struct {
    id: i32,
    title: []const u8,
    content: []const u8,
    created_at: ?i64 = null,

    // ORM 配置
    pub const table_name = "articles";
    pub const primary_key = "id";
};
```

---

## 2. migration_generator - 迁移生成器

### 功能
生成数据库迁移 SQL（CREATE TABLE）。

### 输入参数
```json
{
  "table": "articles",
  "fields": [
    {
      "name": "id",
      "type": "int",
      "required": true,
      "primary_key": true,
      "auto_increment": true
    },
    {
      "name": "title",
      "type": "string",
      "required": true
    },
    {
      "name": "content",
      "type": "text",
      "required": true
    },
    {
      "name": "created_at",
      "type": "timestamp",
      "required": false
    }
  ]
}
```

### 字段属性
- `name`: 字段名
- `type`: SQL 类型
- `required`: 是否 NOT NULL
- `primary_key`: 是否主键
- `auto_increment`: 是否自增（可选）

### 支持的 SQL 类型
| 类型 | SQL 类型 |
|------|----------|
| string | VARCHAR(255) |
| text | TEXT |
| int | INT |
| bigint | BIGINT |
| bool | BOOLEAN |
| float | DOUBLE |
| timestamp | TIMESTAMP |
| datetime | DATETIME |

### 输出示例
```json
{
  "up": "-- 创建 articles 表\nCREATE TABLE IF NOT EXISTS articles (\n    id INT AUTO_INCREMENT PRIMARY KEY,\n    title VARCHAR(255) NOT NULL,\n    content TEXT NOT NULL,\n    created_at TIMESTAMP\n);",
  "down": "-- 删除 articles 表\nDROP TABLE IF EXISTS articles;",
  "filename": "1709352000_create_articles_table.sql",
  "path": "migrations/1709352000_create_articles_table.sql"
}
```

---

## 完整工作流示例

### 场景：创建文章管理模块

#### 步骤 1：生成数据库迁移

**AI 对话**：
```
你：请帮我生成文章表的迁移 SQL，包含 id、title、content、author_id、created_at 字段

AI：好的，我将使用 migration_generator 工具...
```

**生成的 SQL**：
```sql
-- UP
CREATE TABLE IF NOT EXISTS articles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    author_id INT NOT NULL,
    created_at TIMESTAMP
);

-- DOWN
DROP TABLE IF EXISTS articles;
```

#### 步骤 2：生成模型

**AI 对话**：
```
你：请生成 Article 模型，对应 articles 表

AI：好的，我将使用 model_generator 工具...
```

**生成的模型**：
```zig
pub const Article = struct {
    id: i32,
    title: []const u8,
    content: []const u8,
    author_id: i32,
    created_at: ?i64 = null,

    pub const table_name = "articles";
    pub const primary_key = "id";
};
```

#### 步骤 3：生成 CRUD 模块

**AI 对话**：
```
你：请生成完整的 Article CRUD 模块

AI：好的，我将使用 crud_generator 工具...
```

**生成的代码**：
- 模型代码
- 控制器代码（list/get/create/update/delete）
- 路由注册代码

#### 步骤 4：应用代码

1. **执行迁移**：
```bash
mysql -u root -p zigcms < migrations/1709352000_create_articles_table.sql
```

2. **保存模型**：
```bash
# 保存到 src/domain/entities/Article.model.zig
```

3. **保存控制器**：
```bash
# 保存到 src/api/controllers/Article.controller.zig
```

4. **注册路由**：
```zig
// 在 bootstrap.zig 中添加路由注册代码
```

5. **编译测试**：
```bash
zig build
```

---

## 工具组合使用

### 组合 1：快速原型
```
1. migration_generator → 生成数据库表
2. crud_generator → 生成完整模块
3. 执行迁移 + 应用代码
```

### 组合 2：精细控制
```
1. migration_generator → 生成数据库表
2. model_generator → 生成模型
3. 手动实现控制器（自定义业务逻辑）
```

### 组合 3：数据库优先
```
1. 已有数据库表
2. model_generator → 生成模型
3. crud_generator → 生成控制器
```

---

## 最佳实践

### 1. 命名规范
- **模型名**：大驼峰（Article、UserProfile）
- **表名**：小写下划线（articles、user_profiles）
- **字段名**：小写下划线（created_at、author_id）

### 2. 字段设计
- **主键**：始终使用 `id` 作为主键
- **时间戳**：使用 `created_at`、`updated_at`
- **外键**：使用 `{table}_id` 格式（author_id、category_id）
- **布尔值**：使用 `is_` 前缀（is_published、is_active）

### 3. 迁移管理
- **文件名**：时间戳 + 描述（`1709352000_create_articles_table.sql`）
- **版本控制**：将迁移文件纳入 Git
- **回滚**：保留 DOWN SQL 用于回滚

### 4. 代码组织
```
src/
├── domain/
│   └── entities/
│       └── Article.model.zig      # 模型
├── api/
│   └── controllers/
│       └── Article.controller.zig  # 控制器
└── migrations/
    └── 1709352000_create_articles_table.sql  # 迁移
```

---

## 故障排除

### 问题 1：生成的 SQL 类型不正确

**解决方案**：
- 检查字段类型是否在支持列表中
- 使用自定义类型（直接传递 SQL 类型）

### 问题 2：模型编译失败

**解决方案**：
- 检查字段名是否符合 Zig 命名规范
- 检查类型映射是否正确
- 确保导入路径正确

### 问题 3：迁移执行失败

**解决方案**：
- 检查表是否已存在
- 检查字段类型是否兼容数据库
- 检查外键约束

---

## 高级用法

### 自定义字段类型
```json
{
  "name": "metadata",
  "type": "JSON",  // 直接使用 SQL 类型
  "required": false
}
```

### 复合主键
```json
{
  "fields": [
    {
      "name": "user_id",
      "type": "int",
      "primary_key": true
    },
    {
      "name": "role_id",
      "type": "int",
      "primary_key": true
    }
  ]
}
```

### 索引和约束
生成的 SQL 可以手动添加：
```sql
CREATE TABLE articles (
    ...
);

-- 添加索引
CREATE INDEX idx_author_id ON articles(author_id);

-- 添加外键
ALTER TABLE articles ADD CONSTRAINT fk_author 
    FOREIGN KEY (author_id) REFERENCES users(id);
```

---

## 参考资料

- [CRUD 生成器指南](mcp_code_generator_guide.md)
- [MCP 设计方案](mcp_design_plan.md)
- [ZigCMS 开发规范](../AGENTS.md)
- [ORM 使用指南](../knowlages/orm_memory_lifecycle.md)
