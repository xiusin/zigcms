# ZigCMS MCP 快速开始

## 5 分钟上手指南

### 1. 启动服务器（1 分钟）

```bash
cd /path/to/zigcms
./zig-out/bin/zigcms
```

看到以下输出说明启动成功：

```
[INFO] MCP Server started on http://127.0.0.1:8889
[INFO] SSE endpoint: /mcp/sse
[INFO] Message endpoint: /mcp/message
```

### 2. 配置 AI 编辑器（2 分钟）

#### Claude Code

打开 `~/.config/claude-code/mcp.json`，添加：

```json
{
  "zigcms-mcp": {
    "command": "/path/to/zigcms/zig-out/bin/zigcms",
    "args": ["--mcp"]
  }
}
```

#### Cursor

打开 Settings → MCP，添加：

```json
{
  "mcpServers": {
    "zigcms": {
      "url": "http://127.0.0.1:8889/mcp/sse"
    }
  }
}
```

### 3. 测试连接（1 分钟）

在 AI 编辑器中输入：

```
请列出 ZigCMS 项目的结构
```

如果返回项目结构，说明连接成功！

### 4. 生成第一个模块（1 分钟）

```
请生成 Article CRUD 模块，包含以下字段：
- title: 标题（字符串，必填，5-200 字符）
- content: 内容（文本，必填）
- author_id: 作者 ID（整数，必填）
- status: 状态（整数，默认 1）
```

等待 10 秒，完整的 CRUD 模块就生成好了！

---

## 常用命令

### 项目分析

```
请分析 ZigCMS 项目的架构
```

### 文件搜索

```
搜索所有的控制器文件
```

### 代码生成

```
请生成 [模块名] CRUD 模块，包含以下字段：
- [字段名]: [说明]（[类型]，[约束]）
```

### 代码审查

```
请审查 [文件路径] 的代码质量
```

---

## 示例：生成博客系统

### 1. 生成 Article 模块

```
请生成 Article CRUD 模块，包含以下字段：
- title: 标题（字符串，必填，5-200 字符，可搜索）
- content: 内容（文本，必填，可搜索）
- author_id: 作者 ID（整数，必填，可过滤）
- category_id: 分类 ID（整数，可过滤）
- status: 状态（整数，默认 1，可过滤）
- view_count: 浏览次数（整数，默认 0）
- created_at: 创建时间（时间戳，可排序）
- updated_at: 更新时间（时间戳）
```

### 2. 生成 Category 模块

```
请生成 Category CRUD 模块，包含以下字段：
- name: 分类名称（字符串，必填，2-50 字符，可搜索）
- slug: URL 别名（字符串，必填，唯一）
- description: 描述（文本）
- parent_id: 父分类 ID（整数，可为空）
- sort_order: 排序（整数，默认 0）
- status: 状态（整数，默认 1，可过滤）
```

### 3. 生成 Comment 模块

```
请生成 Comment CRUD 模块，包含以下字段：
- article_id: 文章 ID（整数，必填，可过滤）
- user_id: 用户 ID（整数，必填，可过滤）
- content: 评论内容（文本，必填，可搜索）
- parent_id: 父评论 ID（整数，可为空）
- status: 状态（整数，默认 1，可过滤）
- created_at: 创建时间（时间戳，可排序）
```

### 4. 运行迁移

```bash
zig build migrate -- up
```

### 5. 启动服务器

```bash
./zig-out/bin/zigcms
```

### 6. 测试 API

```bash
# 创建文章
curl -X POST http://localhost:3000/api/articles \
  -H "Content-Type: application/json" \
  -d '{
    "title": "我的第一篇文章",
    "content": "这是文章内容",
    "author_id": 1,
    "category_id": 1
  }'

# 获取文章列表
curl http://localhost:3000/api/articles?page=1&page_size=10

# 搜索文章
curl http://localhost:3000/api/articles?keyword=第一篇

# 过滤文章
curl http://localhost:3000/api/articles?status=1&category_id=1

# 排序文章
curl http://localhost:3000/api/articles?sort_by=created_at&sort_order=DESC
```

---

## 效率对比

### 传统方式（5.75 小时）

1. 创建模型文件（10 分钟）
2. 编写 CRUD 方法（95 分钟）
3. 添加验证规则（30 分钟）
4. 实现搜索过滤（45 分钟）
5. 编写测试代码（90 分钟）
6. 添加注释文档（20 分钟）
7. 注册路由（5 分钟）
8. 测试调试（50 分钟）

**总计：345 分钟（5.75 小时）**

### MCP 方式（19 分钟）

1. AI 对话描述需求（2 分钟）
2. 等待代码生成（10 秒）
3. 注册路由（2 分钟）
4. 测试调试（17 分钟）

**总计：19 分钟**

**效率提升：18.2 倍！**

---

## 常见问题

### Q: 服务器启动失败？

**A**: 检查端口是否被占用：

```bash
lsof -i :8889
```

如果被占用，修改配置文件 `config/mcp.yaml`：

```yaml
transport:
  port: 8890  # 改为其他端口
```

### Q: AI 编辑器连接失败？

**A**: 检查服务器是否启动：

```bash
curl http://127.0.0.1:8889/mcp/sse
```

### Q: 生成的代码编译失败？

**A**: 运行编译测试：

```bash
zig build
```

查看错误信息并反馈给 AI。

### Q: 如何自定义生成的代码？

**A**: 在 AI 对话中详细描述需求：

```
请生成 Article CRUD 模块，要求：
1. title 字段长度 5-200 字符
2. content 字段必填
3. status 字段默认值为 1
4. 添加 view_count 字段，默认值为 0
5. 添加 created_at 和 updated_at 时间戳
6. title 和 content 可搜索
7. status 和 author_id 可过滤
8. created_at 可排序
```

---

## 下一步

- 阅读 [完整使用指南](mcp_user_guide.md)
- 查看 [API 参考](mcp_complete_summary.md)
- 学习 [最佳实践](mcp_tools_complete_guide.md)
- 了解 [关系查询](mcp_relation_query_guide.md)

---

**祝你使用愉快！老铁！** 🚀
