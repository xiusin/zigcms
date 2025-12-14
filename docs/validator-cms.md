# ZigCMS 验证器与 CMS 模块文档

## 验证器模块

ZigCMS 提供类似 Go validator 和 Laravel 的验证器，支持声明式和编程式两种验证方式。

### 特性

- **内存安全**：自动管理内存，支持 Arena 分配器
- **线程安全**：可在多线程环境中使用
- **优雅的 API**：支持链式调用
- **零分配验证**：静态 `check()` 方法使用栈分配

### 使用方式一：声明式验证（推荐）

在 DTO 结构体中使用 `rules` 常量定义验证规则：

```zig
const UserDto = struct {
    // 定义验证规则
    pub const rules = .{
        .username = "required|min:3|max:20|alpha_num",
        .email = "required|email",
        .age = "min:18|max:120",
        .password = "required|min:6",
    };

    username: []const u8,
    email: []const u8,
    age: i32 = 0,
    password: []const u8,
};

// 快速验证（零分配，推荐）
if (Validator.check(UserDto, dto)) |err| {
    return base.send_failed(req, err);
}
```

### 使用方式二：编程式验证（链式调用）

```zig
var v = Validator.init(allocator);
defer v.deinit();

// 链式验证字段
_ = v.field("username", dto.username)
    .required()
    .min(3)
    .max(20)
    .alphaNum();

_ = v.field("email", dto.email)
    .required()
    .email();

if (v.fails()) {
    return base.send_failed(req, v.firstError() orelse "验证失败");
}
```

### 使用方式三：Arena 分配器（推荐用于请求级别）

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

var v = Validator.init(arena.allocator());
// 无需手动 deinit，arena 会统一释放所有内存

_ = v.field("name", dto.name).required().min(2);

if (v.fails()) {
    return base.send_failed(req, v.firstError() orelse "验证失败");
}
```

### 验证规则表

| 规则 | 说明 | 示例 |
|------|------|------|
| `required` | 必填字段 | `"required"` |
| `min:n` | 最小长度/值 | `"min:3"` |
| `max:n` | 最大长度/值 | `"max:20"` |
| `email` | 邮箱格式 | `"email"` |
| `alpha` | 仅字母 | `"alpha"` |
| `alpha_num` | 字母数字下划线 | `"alpha_num"` |
| `numeric` | 数字字符串 | `"numeric"` |
| `url` | URL 格式 | `"url"` |
| `in:a,b,c` | 在列表中 | `"in:active,pending"` |
| `mobile` | 手机号（中国） | `"mobile"` |
| `date` | 日期格式 | `"date"` |

### 组合多个规则

```zig
pub const rules = .{
    .username = "required|min:3|max:20|alpha_num",
    .email = "required|email",
    .status = "required|in:active,pending,disabled",
};
```

---

## 安全防护模块

ZigCMS 提供全局安全防护，自动检测和拦截常见攻击。

### 防护类型

- **SQL 注入**：检测 UNION、注释、引号等注入特征
- **XSS 攻击**：检测 script、事件处理器等恶意代码
- **命令注入**：检测 shell 命令特征
- **路径遍历**：检测 ../ 等目录穿越攻击
- **HTTP 头注入**：检测 CRLF 注入

### 使用示例

```zig
const security = @import("validator/security.zig");

// 检查输入是否安全
if (!security.isClean(user_input)) {
    return error.PotentialAttack;
}

// 获取详细威胁信息
var sec = security.Security.init(allocator);
const result = sec.check(user_input);
if (!result.is_safe) {
    std.log.warn("检测到攻击: {s}", .{security.getThreatName(result.threat_type)});
}

// 清理用户输入
const safe_input = try security.sanitize(allocator, dangerous_input);
defer allocator.free(safe_input);

// HTML 转义
const escaped = try security.escapeHtml(allocator, user_input);
defer allocator.free(escaped);
```

---

## CMS 内容管理模块

ZigCMS 提供通用的内容管理系统模块，支持动态模型、自定义字段和文档管理。

### 核心概念

- **模型 (Model)**：定义内容的结构和行为
- **字段 (Field)**：定义模型的数据结构
- **文档 (Document)**：存储实际的内容数据

### 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                      CMS Manager                             │
│  - 统一管理入口                                              │
│  - 线程安全（Mutex 保护）                                    │
│  - 缓存优化                                                  │
└─────────────────────────────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
  ┌───────────┐       ┌───────────┐       ┌───────────┐
  │   Model   │──1:N──│   Field   │       │ Document  │
  │  模型定义 │       │  字段定义 │       │  文档内容 │
  └───────────┘       └───────────┘       └───────────┘
        │                                       │
        └─────────────────1:N───────────────────┘
```

### 模型类型

| 类型 | 说明 | 应用场景 |
|------|------|----------|
| `单页` | 单一内容页面 | 关于我们、联系方式 |
| `列表` | 多条目内容 | 文章、新闻、产品 |
| `封面` | 栏目入口页 | 栏目首页、频道页 |

### 字段类型

| 类型 | 数据库类型 | 说明 |
|------|------------|------|
| `text` | VARCHAR(255) | 单行文本 |
| `textarea` | TEXT | 多行文本 |
| `richtext` | TEXT | 富文本编辑器 |
| `number` | INT | 整数 |
| `decimal` | DECIMAL(10,2) | 小数 |
| `select` | VARCHAR(100) | 下拉选择 |
| `radio` | VARCHAR(100) | 单选 |
| `checkbox` | TEXT | 多选 |
| `switch` | TINYINT(1) | 开关 |
| `date` | DATE | 日期 |
| `datetime` | DATETIME | 日期时间 |
| `image` | VARCHAR(500) | 图片上传 |
| `images` | TEXT | 多图上传 |
| `file` | VARCHAR(500) | 文件上传 |
| `relation` | INT | 关联其他模型 |
| `json` | TEXT | JSON 编辑器 |
| `markdown` | TEXT | Markdown 编辑器 |

### 文档状态

| 状态 | 值 | 说明 |
|------|-----|------|
| 草稿 | `0` | 未发布，仅作者可见 |
| 已发布 | `1` | 公开可访问 |
| 待审核 | `2` | 等待管理员审核 |
| 已下架 | `3` | 已从前台隐藏 |

### 使用示例

```zig
const cms = @import("cms/mod.zig");

// 初始化 CMS 管理器（线程安全）
var manager = cms.Manager.init(allocator);
defer manager.deinit();

// 创建文章模型
const article_model = cms.Model{
    .id = 1,
    .name = "文章",
    .table_name = "article",
    .model_type = .list,
    .icon = "file-text",
    .list_fields = "[\"title\", \"author\", \"status\"]",
    .search_fields = "[\"title\", \"keywords\"]",
};

// 缓存模型
try manager.cacheModel(article_model);

// 定义字段
const title_field = cms.Field{
    .model_id = 1,
    .field_name = "title",
    .field_label = "标题",
    .field_type = .text,
    .is_required = true,
    .is_list_show = true,
    .is_search = true,
    .min_length = 2,
    .max_length = 200,
};

// 创建文档
const doc = cms.Document{
    .model_id = 1,
    .category_id = 5,
    .title = "Hello World",
    .content = "文章内容...",
    .status = .published,
    .is_recommend = true,
};
```

---

## API 路由

### 模型管理 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/cms/model/list` | 获取模型列表 |
| GET | `/api/cms/model/get?id=1` | 获取模型详情 |
| POST | `/api/cms/model/save` | 创建/更新模型 |
| DELETE | `/api/cms/model/delete?id=1` | 删除模型 |
| GET | `/api/cms/model/select` | 获取模型选项（下拉） |
| GET | `/api/cms/model/fields?model_id=1` | 获取模型字段 |

### 字段管理 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/cms/field/list` | 获取字段列表 |
| GET | `/api/cms/field/get?id=1` | 获取字段详情 |
| POST | `/api/cms/field/save` | 创建/更新字段 |
| DELETE | `/api/cms/field/delete?id=1` | 删除字段 |
| POST | `/api/cms/field/batch-sort` | 批量排序 |
| GET | `/api/cms/field/types` | 获取字段类型列表 |

### 文档管理 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/cms/document/list` | 获取文档列表 |
| GET | `/api/cms/document/get?id=1` | 获取文档详情 |
| POST | `/api/cms/document/save` | 创建/更新文档 |
| DELETE | `/api/cms/document/delete?id=1` | 删除文档 |
| POST | `/api/cms/document/publish?id=1` | 发布文档 |
| POST | `/api/cms/document/unpublish?id=1` | 下架文档 |
| POST | `/api/cms/document/batch-delete` | 批量删除 |
| POST | `/api/cms/document/batch-publish` | 批量发布 |

---

## 最佳实践

### 内存安全

1. **使用 Arena 分配器**：在请求级别使用 Arena，统一释放
2. **defer 释放**：始终使用 `defer` 确保资源释放
3. **检查返回值**：处理所有可能的错误

### 线程安全

1. **CMS Manager**：使用 Mutex 保护共享状态
2. **验证器**：每个请求创建独立实例
3. **缓存**：通过 Manager 统一管理缓存

### 安全建议

1. **始终验证输入**：使用验证器检查所有用户输入
2. **清理输出**：使用 `escapeHtml` 防止 XSS
3. **参数绑定**：使用 ORM 参数绑定防止 SQL 注入
4. **频率限制**：配置适当的请求频率限制
