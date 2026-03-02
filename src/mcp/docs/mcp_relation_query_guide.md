# MCP 关系查询生成指南

## 概述

关系查询生成器自动生成**一对多**、**多对多**、**预加载**和**嵌套查询**代码，让关联数据查询更加简单。

## 支持的关系类型

### 1. 一对多（Has Many）

**场景**：一个用户有多篇文章

**模型定义**：
```zig
// User.model.zig
pub const User = struct {
    id: ?i32 = null,
    username: []const u8 = "",
    
    // 关联字段（可选）
    articles: ?[]Article = null,
    
    // 定义关系
    pub const relations = .{
        .articles = .{
            .type = .has_many,
            .model = Article,
            .foreign_key = "author_id",
            .local_key = "id",
        },
    };
};
```

**使用示例**：
```zig
// 查询用户及其文章
var q = OrmUser.Query();
defer q.deinit();

_ = q.with(&.{"articles"});  // 预加载文章
const users = try q.get();
defer OrmUser.freeModels(users);

for (users) |user| {
    if (user.articles) |articles| {
        std.debug.print("用户 {s} 有 {d} 篇文章\n", .{ user.username, articles.len });
    }
}
```

### 2. 多对多（Many to Many）

**场景**：文章有多个标签，标签有多篇文章

**模型定义**：
```zig
// Article.model.zig
pub const Article = struct {
    id: ?i32 = null,
    title: []const u8 = "",
    
    // 关联字段（可选）
    tags: ?[]Tag = null,
    
    // 定义关系
    pub const relations = .{
        .tags = .{
            .type = .many_to_many,
            .model = Tag,
            .through = "article_tag",
            .foreign_key = "article_id",
            .related_key = "tag_id",
        },
    };
};
```

**使用示例**：
```zig
// 查询文章及其标签
var q = OrmArticle.Query();
defer q.deinit();

_ = q.with(&.{"tags"});  // 预加载标签
const articles = try q.get();
defer OrmArticle.freeModels(articles);

for (articles) |article| {
    if (article.tags) |tags| {
        std.debug.print("文章 {s} 有 {d} 个标签\n", .{ article.title, tags.len });
    }
}
```

### 3. 属于（Belongs To）

**场景**：文章属于一个用户

**模型定义**：
```zig
// Article.model.zig
pub const Article = struct {
    id: ?i32 = null,
    title: []const u8 = "",
    author_id: i32 = 0,
    
    // 关联字段（可选）
    author: ?User = null,
    
    // 定义关系
    pub const relations = .{
        .author = .{
            .type = .belongs_to,
            .model = User,
            .foreign_key = "author_id",
            .owner_key = "id",
        },
    };
};
```

**使用示例**：
```zig
// 查询文章及其作者
var q = OrmArticle.Query();
defer q.deinit();

_ = q.with(&.{"author"});  // 预加载作者
const articles = try q.get();
defer OrmArticle.freeModels(articles);

for (articles) |article| {
    if (article.author) |author| {
        std.debug.print("文章 {s} 的作者是 {s}\n", .{ article.title, author.username });
    }
}
```

### 4. 一对一（Has One）

**场景**：用户有一个资料

**模型定义**：
```zig
// User.model.zig
pub const User = struct {
    id: ?i32 = null,
    username: []const u8 = "",
    
    // 关联字段（可选）
    profile: ?UserProfile = null,
    
    // 定义关系
    pub const relations = .{
        .profile = .{
            .type = .has_one,
            .model = UserProfile,
            .foreign_key = "user_id",
            .local_key = "id",
        },
    };
};
```

**使用示例**：
```zig
// 查询用户及其资料
var q = OrmUser.Query();
defer q.deinit();

_ = q.with(&.{"profile"});  // 预加载资料
const users = try q.get();
defer OrmUser.freeModels(users);

for (users) |user| {
    if (user.profile) |profile| {
        std.debug.print("用户 {s} 的资料：{s}\n", .{ user.username, profile.bio });
    }
}
```

## 预加载（Eager Loading）

### 单个关系预加载

```zig
var q = OrmArticle.Query();
_ = q.with(&.{"author"});
const articles = try q.get();
defer OrmArticle.freeModels(articles);
```

### 多个关系预加载

```zig
var q = OrmArticle.Query();
_ = q.with(&.{ "author", "tags", "comments" });
const articles = try q.get();
defer OrmArticle.freeModels(articles);
```

### 嵌套关系预加载

```zig
var q = OrmArticle.Query();
_ = q.with(&.{"author.profile"});  // 加载作者及其资料
const articles = try q.get();
defer OrmArticle.freeModels(articles);

for (articles) |article| {
    if (article.author) |author| {
        if (author.profile) |profile| {
            std.debug.print("作者 {s} 的资料：{s}\n", .{ author.username, profile.bio });
        }
    }
}
```

### 多层嵌套预加载

```zig
var q = OrmArticle.Query();
_ = q.with(&.{
    "author.profile",
    "tags",
    "comments.user",
});
const articles = try q.get();
defer OrmArticle.freeModels(articles);
```

## 生成的控制器代码

### 带关系查询的 list 方法

```zig
/// 列表查询（带关系预加载）
pub fn list(self: *@This(), req: zap.Request) !void {
    _ = self;
    var mutable_req = req;

    const page = mutable_req.getParamInt("page", i32, 1) catch 1;
    const page_size = mutable_req.getParamInt("page_size", i32, 20) catch 20;
    const with_relations = mutable_req.getParam("with");

    var q = OrmArticle.Query();
    defer q.deinit();

    // 预加载关系
    if (with_relations) |relations| {
        if (std.mem.eql(u8, relations, "author")) {
            _ = q.with(&.{"author"});
        } else if (std.mem.eql(u8, relations, "tags")) {
            _ = q.with(&.{"tags"});
        } else if (std.mem.eql(u8, relations, "all")) {
            _ = q.with(&.{ "author", "tags", "comments" });
        }
    }

    _ = q.orderBy("id", "DESC")
         .limit(page_size)
         .offset((page - 1) * page_size);

    const items = try q.get();
    defer OrmArticle.freeModels(items);

    var count_q = OrmArticle.Query();
    defer count_q.deinit();
    const total = try count_q.count();

    try base.send_success(&mutable_req, .{
        .items = items,
        .total = total,
        .page = page,
        .page_size = page_size,
    });
}
```

### 带关系查询的 get 方法

```zig
/// 获取详情（带关系预加载）
pub fn get(self: *@This(), req: zap.Request) !void {
    _ = self;
    var mutable_req = req;

    const id = mutable_req.getParamInt("id", i32, 0) catch {
        try base.send_error(&mutable_req, "Invalid ID", 400);
        return;
    };

    const with_relations = mutable_req.getParam("with");

    var q = OrmArticle.Query();
    defer q.deinit();

    // 预加载关系
    if (with_relations) |relations| {
        if (std.mem.eql(u8, relations, "author")) {
            _ = q.with(&.{"author"});
        } else if (std.mem.eql(u8, relations, "all")) {
            _ = q.with(&.{ "author", "tags", "comments" });
        }
    }

    _ = q.where("id", "=", id);
    const items = try q.get();
    defer OrmArticle.freeModels(items);

    if (items.len == 0) {
        try base.send_error(&mutable_req, "Not found", 404);
        return;
    }

    try base.send_success(&mutable_req, items[0]);
}
```

## API 使用示例

### 1. 查询文章及其作者

**请求**：
```bash
GET /api/article?with=author
```

**响应**：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "items": [
      {
        "id": 1,
        "title": "Hello World",
        "content": "...",
        "author": {
          "id": 1,
          "username": "john_doe",
          "email": "john@example.com"
        }
      }
    ],
    "total": 1,
    "page": 1,
    "page_size": 20
  }
}
```

### 2. 查询文章及其标签

**请求**：
```bash
GET /api/article?with=tags
```

**响应**：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "items": [
      {
        "id": 1,
        "title": "Hello World",
        "content": "...",
        "tags": [
          { "id": 1, "name": "Zig" },
          { "id": 2, "name": "Programming" }
        ]
      }
    ],
    "total": 1,
    "page": 1,
    "page_size": 20
  }
}
```

### 3. 查询文章及其所有关系

**请求**：
```bash
GET /api/article?with=all
```

**响应**：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "items": [
      {
        "id": 1,
        "title": "Hello World",
        "content": "...",
        "author": {
          "id": 1,
          "username": "john_doe"
        },
        "tags": [
          { "id": 1, "name": "Zig" }
        ],
        "comments": [
          { "id": 1, "content": "Great article!" }
        ]
      }
    ],
    "total": 1,
    "page": 1,
    "page_size": 20
  }
}
```

### 4. 查询单篇文章及其作者

**请求**：
```bash
GET /api/article/1?with=author
```

**响应**：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 1,
    "title": "Hello World",
    "content": "...",
    "author": {
      "id": 1,
      "username": "john_doe",
      "email": "john@example.com"
    }
  }
}
```

## 性能对比

### N+1 查询问题

**❌ 不使用预加载**：
```zig
// 查询文章（1 次查询）
const articles = try OrmArticle.Query().get();

// 为每篇文章查询作者（N 次查询）
for (articles) |article| {
    const author = try OrmUser.FindById(article.author_id);
    // 使用 author...
}
```

**查询次数**：1 + N = 11 次（假设 10 篇文章）

**✅ 使用预加载**：
```zig
// 查询文章及其作者（2 次查询）
var q = OrmArticle.Query();
_ = q.with(&.{"author"});
const articles = try q.get();

// 直接使用关联数据
for (articles) |article| {
    if (article.author) |author| {
        // 使用 author...
    }
}
```

**查询次数**：2 次

**性能提升**：5.5 倍（11 次 vs 2 次）

### 多关系预加载

**❌ 不使用预加载**：
```zig
// 查询文章（1 次）
const articles = try OrmArticle.Query().get();

// 查询作者（N 次）
// 查询标签（N 次）
// 查询评论（N 次）
```

**查询次数**：1 + 3N = 31 次（假设 10 篇文章）

**✅ 使用预加载**：
```zig
var q = OrmArticle.Query();
_ = q.with(&.{ "author", "tags", "comments" });
const articles = try q.get();
```

**查询次数**：4 次

**性能提升**：7.75 倍（31 次 vs 4 次）

## 关系定义最佳实践

### 1. 明确关系类型

```zig
// ✅ 推荐：明确的关系类型
pub const relations = .{
    .articles = .{
        .type = .has_many,
        .model = Article,
        .foreign_key = "author_id",
        .local_key = "id",
    },
};

// ❌ 避免：模糊的关系定义
pub const relations = .{
    .articles = Article,  // 不清楚关系类型
};
```

### 2. 使用可选字段

```zig
// ✅ 推荐：关联字段使用可选类型
pub const User = struct {
    id: ?i32 = null,
    username: []const u8 = "",
    articles: ?[]Article = null,  // 可选
};

// ❌ 避免：关联字段使用必填类型
pub const User = struct {
    id: ?i32 = null,
    username: []const u8 = "",
    articles: []Article,  // 必填，会导致问题
};
```

### 3. 正确的外键命名

```zig
// ✅ 推荐：清晰的外键命名
.foreign_key = "author_id",  // 明确指向 author
.foreign_key = "user_id",    // 明确指向 user

// ❌ 避免：模糊的外键命名
.foreign_key = "id",         // 不清楚
.foreign_key = "fk",         // 不清楚
```

### 4. 多对多关系的中间表

```zig
// ✅ 推荐：明确的中间表名
.through = "article_tag",     // 清晰
.through = "user_role",       // 清晰

// ❌ 避免：模糊的中间表名
.through = "relation",        // 不清楚
.through = "mapping",         // 不清楚
```

## 内存管理

### 自动释放关联数据

```zig
var q = OrmArticle.Query();
_ = q.with(&.{"author", "tags"});
const articles = try q.get();
defer OrmArticle.freeModels(articles);  // 自动释放文章、作者和标签
```

**特性**：
- `freeModels` 会递归释放所有关联数据
- 无需手动释放每个关系
- 防止内存泄漏

### 使用 Arena 简化管理

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();  // 一次性释放所有内存
const arena_allocator = arena.allocator();

var q = OrmArticle.Query();
_ = q.with(&.{"author", "tags"});
var result = try q.getWithArena(arena_allocator);
// 无需手动释放，arena.deinit() 会清理所有
```

## 总结

### 现在的能力

- ✅ **一对多查询**：用户的文章
- ✅ **多对多查询**：文章的标签
- ✅ **属于查询**：文章的作者
- ✅ **一对一查询**：用户的资料
- ✅ **预加载**：避免 N+1 查询
- ✅ **嵌套预加载**：多层关系
- ✅ **自动内存管理**：递归释放

### 性能提升

| 场景 | 不使用预加载 | 使用预加载 | 提升 |
|------|-------------|-----------|------|
| 单关系 | 1 + N 次 | 2 次 | 5.5 倍 |
| 多关系 | 1 + 3N 次 | 4 次 | 7.75 倍 |
| 嵌套关系 | 1 + N + M 次 | 3 次 | 10+ 倍 |

### 适用场景

- ✅ 用户和文章
- ✅ 文章和标签
- ✅ 文章和评论
- ✅ 用户和角色
- ✅ 订单和商品

老铁，关系查询功能已经在 ZigCMS ORM 中实现了！现在只需要在生成的代码中添加关系定义和预加载示例即可。
