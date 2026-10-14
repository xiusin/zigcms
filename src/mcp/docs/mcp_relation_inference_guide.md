# MCP 数据关系推导与自动生成指南

## 简介

ZigCMS MCP 代码生成器现在支持**自动推导数据关系**并生成对应的关联关系代码，包括：

- 自动识别外键字段（`_id` 结尾）
- 自动推导关系类型（belongs_to、has_one、has_many、many_to_many）
- 自动生成关系定义代码
- 自动生成关系预加载代码

## 关系类型

### 1. belongs_to（属于/多对一）

**自动推导规则**：字段名以 `_id` 结尾且类型为 `int`

**示例**：

```json
{
  "name": "Article",
  "fields": [
    {
      "name": "user_id",
      "type": "int",
      "required": true
    }
  ]
}
```

**自动推导结果**：
- 关系类型：`belongs_to`
- 关联模型：`User`
- 外键：`user_id`

**生成的模型代码**：

```zig
pub const Article = struct {
    id: ?i32 = null,
    user_id: i32,
    
    // 关联数据字段（可选，用于预加载）
    user: ?User = null,
    
    // 关系定义
    pub const relations = .{
        .user = .{
            .type = .belongs_to,
            .model = User,
            .foreign_key = "user_id",
        },
    };
};
```

### 2. has_one（拥有一个/一对一）

**显式定义**（需要手动指定）：

```json
{
  "name": "User",
  "fields": [
    {
      "name": "profile",
      "type": "relation",
      "relation": {
        "type": "has_one",
        "model": "Profile"
      }
    }
  ]
}
```

**生成的模型代码**：

```zig
pub const User = struct {
    id: ?i32 = null,
    
    // 关联数据字段（可选，用于预加载）
    profile: ?Profile = null,
    
    // 关系定义
    pub const relations = .{
        .profile = .{
            .type = .has_one,
            .model = Profile,
            .foreign_key = "user_id",
        },
    };
};
```

### 3. has_many（拥有多个/一对多）

**显式定义**：

```json
{
  "name": "User",
  "fields": [
    {
      "name": "articles",
      "type": "relation",
      "relation": {
        "type": "has_many",
        "model": "Article"
      }
    }
  ]
}
```

**生成的模型代码**：

```zig
pub const User = struct {
    id: ?i32 = null,
    
    // 关联数据字段（可选，用于预加载）
    articles: ?[]Article = null,
    
    // 关系定义
    pub const relations = .{
        .articles = .{
            .type = .has_many,
            .model = Article,
            .foreign_key = "user_id",
        },
    };
};
```

### 4. many_to_many（多对多）

**显式定义**：

```json
{
  "name": "Article",
  "fields": [
    {
      "name": "tags",
      "type": "relation",
      "relation": {
        "type": "many_to_many",
        "model": "Tag",
        "through": "article_tags"
      }
    }
  ]
}
```

**生成的模型代码**：

```zig
pub const Article = struct {
    id: ?i32 = null,
    
    // 关联数据字段（可选，用于预加载）
    tags: ?[]Tag = null,
    
    // 关系定义
    pub const relations = .{
        .tags = .{
            .type = .many_to_many,
            .model = Tag,
            .through = "article_tags",
            .foreign_key = "article_id",
            .related_key = "tag_id",
        },
    };
};
```

## 自动推导规则

### 规则 1：外键字段 -> belongs_to

**条件**：
- 字段名以 `_id` 结尾
- 字段类型为 `int`

**推导逻辑**：
1. 去掉 `_id` 后缀：`user_id` -> `user`
2. 首字母大写：`user` -> `User`
3. 关系类型：`belongs_to`
4. 外键：原字段名（`user_id`）

**示例**：

| 字段名 | 推导模型 | 关系类型 |
|--------|----------|----------|
| `user_id` | `User` | `belongs_to` |
| `author_id` | `Author` | `belongs_to` |
| `category_id` | `Category` | `belongs_to` |
| `parent_id` | `Parent` | `belongs_to` |

### 规则 2：复数字段 + relation 类型 -> has_many

**条件**：
- 字段名以 `s` 结尾
- 字段类型为 `relation`

**推导逻辑**：
1. 去掉 `s` 后缀：`articles` -> `article`
2. 首字母大写：`article` -> `Article`
3. 关系类型：`has_many`

**示例**：

| 字段名 | 推导模型 | 关系类型 |
|--------|----------|----------|
| `articles` | `Article` | `has_many` |
| `comments` | `Comment` | `has_many` |
| `tags` | `Tag` | `has_many` |

### 规则 3：单数字段 + relation 类型 -> has_one

**条件**：
- 字段类型为 `relation`
- 字段名不以 `s` 结尾

**推导逻辑**：
1. 首字母大写：`profile` -> `Profile`
2. 关系类型：`has_one`

**示例**：

| 字段名 | 推导模型 | 关系类型 |
|--------|----------|----------|
| `profile` | `Profile` | `has_one` |
| `setting` | `Setting` | `has_one` |
| `avatar` | `Avatar` | `has_one` |

## 生成的控制器代码

### 关系预加载支持

生成的控制器自动支持关系预加载：

#### list 方法

```zig
pub fn list(self: *@This(), req: zap.Request) !void {
    var mutable_req = req;
    
    // 获取分页参数
    const page = mutable_req.getParamInt("page", i32, 1) catch 1;
    const page_size = mutable_req.getParamInt("page_size", i32, 20) catch 20;
    
    // 查询数据
    var q = OrmArticle.Query();
    defer q.deinit();
    
    // 获取预加载参数
    const with_param = mutable_req.getParam("with");
    if (with_param) |with_str| {
        // 解析预加载关系（逗号分隔）
        var relations = std.ArrayList([]const u8).init(self.allocator);
        defer relations.deinit();
        var iter = std.mem.split(u8, with_str, ",");
        while (iter.next()) |rel| {
            try relations.append(std.mem.trim(u8, rel, " "));
        }
        _ = q.with(relations.items);
    }
    
    _ = q.orderBy("id", "DESC")
         .limit(page_size)
         .offset((page - 1) * page_size);
    
    const items = try q.get();
    defer OrmArticle.freeModels(items);
    
    // ...
}
```

#### get 方法

```zig
pub fn get(self: *@This(), req: zap.Request) !void {
    var mutable_req = req;
    
    const id = mutable_req.getParamInt("id", i32, 0) catch {
        try base.send_error(&mutable_req, "Invalid ID", 400);
        return;
    };
    
    // 获取预加载参数
    const with_param = mutable_req.getParam("with");
    var q = OrmArticle.Query();
    defer q.deinit();
    _ = q.where("id", "=", id);
    if (with_param) |with_str| {
        var relations = std.ArrayList([]const u8).init(self.allocator);
        defer relations.deinit();
        var iter = std.mem.split(u8, with_str, ",");
        while (iter.next()) |rel| {
            try relations.append(std.mem.trim(u8, rel, " "));
        }
        _ = q.with(relations.items);
    }
    const items = try q.get();
    if (items.len == 0) {
        try base.send_error(&mutable_req, "Not found", 404);
        return;
    }
    const item = items[0];
    defer OrmArticle.freeModels(items);
    
    try base.send_success(&mutable_req, item);
}
```

## 使用示例

### 示例 1：博客系统

#### 生成 Article 模块

```
请生成 Article CRUD 模块，包含以下字段：
- title: 标题（字符串，必填，5-200 字符，可搜索）
- content: 内容（文本，必填，可搜索）
- user_id: 作者 ID（整数，必填，可过滤）
- category_id: 分类 ID（整数，可过滤）
- status: 状态（整数，默认 1，可过滤）
- created_at: 创建时间（时间戳，可排序）
```

**自动推导结果**：
- `user_id` -> `belongs_to User`
- `category_id` -> `belongs_to Category`

#### 生成 User 模块（带关系）

```
请生成 User CRUD 模块，包含以下字段：
- username: 用户名（字符串，必填，3-20 字符，唯一）
- email: 邮箱（字符串，必填，唯一）
- articles: 文章列表（关系，has_many，关联 Article）
- profile: 用户资料（关系，has_one，关联 Profile）
```

**显式定义关系**：

```json
{
  "name": "User",
  "fields": [
    {
      "name": "username",
      "type": "string",
      "required": true,
      "min_length": 3,
      "max_length": 20
    },
    {
      "name": "email",
      "type": "string",
      "required": true
    },
    {
      "name": "articles",
      "type": "relation",
      "relation": {
        "type": "has_many",
        "model": "Article"
      }
    },
    {
      "name": "profile",
      "type": "relation",
      "relation": {
        "type": "has_one",
        "model": "Profile"
      }
    }
  ]
}
```

### 示例 2：电商系统

#### 生成 Product 模块

```
请生成 Product CRUD 模块，包含以下字段：
- name: 产品名称（字符串，必填，3-100 字符，可搜索）
- price: 价格（浮点数，必填，最小 0.01）
- category_id: 分类 ID（整数，必填，可过滤）
- tags: 标签（关系，many_to_many，关联 Tag，中间表 product_tags）
```

**关系定义**：

```json
{
  "name": "Product",
  "fields": [
    {
      "name": "name",
      "type": "string",
      "required": true,
      "min_length": 3,
      "max_length": 100,
      "searchable": true
    },
    {
      "name": "price",
      "type": "float",
      "required": true,
      "min_value": 0.01
    },
    {
      "name": "category_id",
      "type": "int",
      "required": true,
      "filterable": true
    },
    {
      "name": "tags",
      "type": "relation",
      "relation": {
        "type": "many_to_many",
        "model": "Tag",
        "through": "product_tags"
      }
    }
  ]
}
```

**自动推导结果**：
- `category_id` -> `belongs_to Category`
- `tags` -> `many_to_many Tag` (显式定义)

## API 使用

### 预加载单个关系

```bash
# 获取文章列表，预加载作者信息
GET /api/articles?with=user

# 获取文章详情，预加载作者信息
GET /api/articles/1?with=user
```

### 预加载多个关系

```bash
# 预加载作者和分类
GET /api/articles?with=user,category

# 预加载作者、分类和标签
GET /api/articles?with=user,category,tags
```

### 嵌套预加载

```bash
# 预加载作者及其资料
GET /api/articles?with=user.profile

# 预加载作者、分类及分类的父分类
GET /api/articles?with=user,category.parent
```

### 组合查询

```bash
# 分页 + 搜索 + 过滤 + 排序 + 预加载
GET /api/articles?page=1&page_size=10&keyword=zig&status=1&sort_by=created_at&sort_order=DESC&with=user,category
```

## 性能优化

### N+1 查询问题

**❌ 不使用预加载（N+1 查询）**：

```bash
GET /api/articles
# 1 次查询获取文章列表
# N 次查询获取每篇文章的作者（N = 文章数量）
# 总计：1 + N 次查询
```

**✅ 使用预加载（2 次查询）**：

```bash
GET /api/articles?with=user
# 1 次查询获取文章列表
# 1 次查询批量获取所有作者
# 总计：2 次查询
```

**性能提升**：
- 10 篇文章：从 11 次查询减少到 2 次（**81.8% 提升**）
- 100 篇文章：从 101 次查询减少到 2 次（**98% 提升**）

### 嵌套预加载性能

**❌ 不使用预加载（N+1+M 查询）**：

```bash
GET /api/articles
# 1 次查询获取文章列表
# N 次查询获取每篇文章的作者
# M 次查询获取每个作者的资料
# 总计：1 + N + M 次查询
```

**✅ 使用嵌套预加载（3 次查询）**：

```bash
GET /api/articles?with=user.profile
# 1 次查询获取文章列表
# 1 次查询批量获取所有作者
# 1 次查询批量获取所有资料
# 总计：3 次查询
```

**性能提升**：
- 10 篇文章 + 10 个作者：从 21 次查询减少到 3 次（**85.7% 提升**）
- 100 篇文章 + 100 个作者：从 201 次查询减少到 3 次（**98.5% 提升**）

## 最佳实践

### 1. 合理使用预加载

**✅ 推荐**：只预加载需要的关系

```bash
# 只预加载作者
GET /api/articles?with=user
```

**❌ 避免**：预加载所有关系

```bash
# 预加载所有关系（可能导致性能问题）
GET /api/articles?with=user,category,tags,comments
```

### 2. 嵌套深度控制

**✅ 推荐**：2-3 层嵌套

```bash
GET /api/articles?with=user.profile
GET /api/articles?with=user.profile.avatar
```

**❌ 避免**：过深嵌套

```bash
GET /api/articles?with=user.profile.avatar.file.storage
```

### 3. 字段命名规范

**✅ 推荐**：遵循命名约定

```json
{
  "name": "user_id",      // 自动推导为 belongs_to User
  "name": "author_id",    // 自动推导为 belongs_to Author
  "name": "category_id"   // 自动推导为 belongs_to Category
}
```

**❌ 避免**：不规范的命名

```json
{
  "name": "userId",       // 无法自动推导
  "name": "user",         // 无法自动推导（需要显式定义）
  "name": "uid"           // 无法自动推导
}
```

### 4. 显式定义复杂关系

对于 `has_one`、`has_many`、`many_to_many` 关系，建议显式定义：

```json
{
  "name": "articles",
  "type": "relation",
  "relation": {
    "type": "has_many",
    "model": "Article",
    "foreign_key": "user_id"  // 可选，默认为 {model}_id
  }
}
```

## 注意事项

### 1. 关系字段不作为数据库字段

关系字段（`type: "relation"`）不会生成数据库列，只用于定义关系：

```json
{
  "name": "articles",
  "type": "relation",  // 不会生成 articles 列
  "relation": {
    "type": "has_many",
    "model": "Article"
  }
}
```

### 2. 外键字段必须存在

`belongs_to` 关系需要对应的外键字段：

```json
{
  "name": "user_id",  // 外键字段（数据库列）
  "type": "int",
  "required": true
}
```

### 3. 中间表需要手动创建

`many_to_many` 关系需要手动创建中间表：

```sql
CREATE TABLE article_tags (
    article_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    PRIMARY KEY (article_id, tag_id)
);
```

### 4. 关系定义向后兼容

不使用 `with()` 参数时，关系定义不影响查询：

```bash
# 不预加载，只返回文章数据
GET /api/articles

# 预加载，返回文章 + 作者数据
GET /api/articles?with=user
```

## 总结

ZigCMS MCP 代码生成器的关系推导功能：

1. **自动推导**：基于字段名自动识别 `belongs_to` 关系
2. **显式定义**：支持手动定义所有关系类型
3. **自动生成**：生成完整的关系定义和预加载代码
4. **性能优化**：避免 N+1 查询，提升 80%-98% 性能
5. **易于使用**：通过 URL 参数控制预加载
6. **向后兼容**：不影响现有代码

老铁，开始使用关系推导功能，让你的代码生成更智能！🚀
