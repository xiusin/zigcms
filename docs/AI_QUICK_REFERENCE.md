# ZigCMS AI 快速参考

> 供 AI 助手快速查阅的关键信息摘要

---

## 项目速览

| 项目 | 值 |
|------|-----|
| 语言 | **Zig** (≥0.13.0) |
| 框架 | **Zap** (HTTP) |
| 数据库 | **PostgreSQL** |
| 前端 | **LayUI** |
| 端口 | **3000** |

---

## 目录结构速查

```
src/
├── main.zig                 # 入口 + 路由注册
├── controllers/             # 控制器
│   ├── generic.controller.zig   # 泛型CRUD（核心）
│   ├── login.controller.zig     # 登录注册
│   └── public.controller.zig    # 文件上传
├── models/                  # 数据模型（结构体）
├── global/global.zig        # 全局状态（DB连接池）
├── modules/strings.zig      # 字符串工具
└── dto/                     # 请求/响应DTO
resources/                   # 前端静态文件
```

---

## 核心设计模式

### 泛型 CRUD 自动注册
```zig
// main.zig 中的 cruds 定义决定了哪些模型自动生成接口
const cruds = .{
    .category = models.Category,
    .article = models.Article,
    // 添加新模型只需在此注册
};
```
自动生成端点: `/{model}/list`, `/get`, `/save`, `/delete`, `/modify`, `/select`

### 模型结构规范
```zig
pub const XxxModel = struct {
    id: ?i32 = null,              // 必须：可选主键
    field_name: []const u8 = "",  // 字符串
    status: i32 = 0,              // 整型
    create_time: ?i64 = null,     // 必须：创建时间
    update_time: ?i64 = null,     // 必须：更新时间
};
```

### 响应格式
```zig
// 成功
base.send_ok(req, data);     // { code: 0, msg: "操作成功", data: {...} }

// 失败
base.send_failed(req, msg);  // { code: 500, msg: "..." }

// 列表
base.send_layui_table_response(req, items, count, extra);
```

---

## 关键文件作用

| 文件 | 职责 |
|------|------|
| `global/global.zig` | DB连接池、全局分配器、配置缓存 |
| `controllers/base.fn.zig` | 响应封装、SQL构建、表名推导 |
| `controllers/generic.controller.zig` | 编译期泛型CRUD |
| `modules/strings.zig` | 字符串工具（split/trim/md5等） |

---

## 数据库约定

- Schema: `zigcms`
- 表名推导: `Article` → `zigcms.article`
- 时间戳: 微秒级 `i64`

---

## 常用操作

### 新增模型
1. `src/models/xxx.model.zig` - 定义结构体
2. `src/models/models.zig` - 导出
3. `main.zig` cruds - 注册

### 新增独立接口
1. `src/controllers/xxx.controller.zig` - 编写控制器
2. `main.zig` - `router.handle_func("/path", &ctrl, &fn)`

### 数据库操作
```zig
var pool = global.get_pg_pool();

// 查询单行
var row = try pool.rowOpts(sql, args, .{.column_names = true});
var item = try row.to(Model, .{.map = .name});

// 查询多行
var result = try pool.queryOpts(sql, args, .{.column_names = true});
const mapper = result.mapper(Model, .{.allocator = alloc});
while (try mapper.next()) |item| { ... }

// 执行
_ = try pool.exec(sql, args);
```

---

## 注意事项

1. **内存**：必须 `defer` 释放，使用 `gpa.allocator()`
2. **JWT**：`check_auth()` 当前已注释，需启用
3. **表名**：由 `base.get_table_name(T)` 自动推导
4. **SQL构建**：使用 `base.build_insert_sql` / `build_update_sql`

---

*快速参考 v1.0*
