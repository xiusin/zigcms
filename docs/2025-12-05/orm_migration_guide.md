# ORM 模块迁移指南

## 痛点分析

原 `generic.controller.zig` 存在以下问题：

1. **手动 struct_2_tuple 转换**：需要复杂的元编程将结构体转换为元组
2. **字段顺序依赖**：假设 `id` 是第一个字段，非常脆弱
3. **更新逻辑繁琐**：手动遍历字段构建参数
4. **类型不一致**：不同模型的字段类型不同，难以泛化

## 新方案

新的 `orm` 模块和 `Crud` 控制器解决了这些问题：

### 1. EntityMeta - 编译期元数据

```zig
const orm = @import("services/orm/orm.zig");
const Meta = orm.EntityMeta(Article);

// 编译期自动提取：
Meta.field_count    // 字段数量（不含 id）
Meta.field_names    // 字段名数组
Meta.table_name     // 表名（从类型名推导）

// 编译期生成 SQL
Meta.insertSQL("zigcms")  // INSERT INTO zigcms.article (...) VALUES (...)
Meta.updateSQL("zigcms")  // UPDATE zigcms.article SET ... WHERE id = $N
Meta.selectSQL("zigcms")  // SELECT * FROM zigcms.article
Meta.deleteSQL("zigcms")  // DELETE FROM zigcms.article WHERE id = $1

// 运行时提取参数元组
const params = Meta.toParams(entity);  // 自动跳过 id 字段
```

### 2. Crud 控制器

```zig
// 旧方式
const ArticleCtrl = Generic(models.Article);

// 新方式
const ArticleCtrl = Crud(models.Article, "zigcms");

var ctrl = ArticleCtrl.init(allocator);
// ctrl.list, ctrl.get, ctrl.save, ctrl.delete, ctrl.modify
```

## Go vs Zig 对比

### Go GORM

```go
// 创建
db.Create(&user)

// 查询
db.First(&user, id)

// 更新
db.Model(&user).Updates(User{Name: "hello"})

// 删除
db.Delete(&user, id)

// 保存（自动判断）
db.Save(&user)
```

### Zig Crud

```zig
// 创建
const params = Meta.toParams(user);
pool.exec(INSERT_SQL, params);

// 查询
pool.rowOpts(SELECT_SQL ++ " WHERE id = $1", .{id}, .{});

// 更新
pool.exec(UPDATE_SQL, params ++ .{id});

// 删除
pool.exec(DELETE_SQL, .{id});

// 保存（控制器自动判断）
// 在 save() 方法中自动处理
```

## 迁移步骤

1. **创建 ORM 模块**
   - `src/services/orm/entity.zig` - 实体元数据
   - `src/services/orm/repository.zig` - 泛型仓储
   - `src/services/orm/orm.zig` - 入口文件

2. **替换控制器**
   - 将 `Generic(T)` 替换为 `Crud(T, "zigcms")`
   - 删除 `struct_2_tuple` 相关代码

3. **模型约定**
   - `id` 字段必须是 `?i32` 类型
   - 需要 `create_time` 和 `update_time` 字段（可选）

## 优势

| 方面 | 旧方案 | 新方案 |
|------|--------|--------|
| SQL 生成 | 运行时拼接 | 编译期生成 |
| 类型安全 | 需要手动转换 | 自动类型推导 |
| 时间戳 | 手动设置 | 自动处理 |
| 代码量 | 冗长 | 简洁 |
| 性能 | 有运行时开销 | 零运行时开销 |

## 示例：Article 控制器

```zig
// controllers/article.controller.zig
const std = @import("std");
const Crud = @import("crud.controller.zig").Crud;
const models = @import("../models/models.zig");

pub const ArticleController = Crud(models.Article, "zigcms");
```

使用：

```zig
var ctrl = ArticleController.init(allocator);

// 路由注册
router.get("/api/articles", ctrl.list);
router.get("/api/article", ctrl.get);
router.post("/api/article/save", ctrl.save);
router.post("/api/article/delete", ctrl.delete);
router.post("/api/article/modify", ctrl.modify);
```
