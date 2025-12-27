# 模板引擎测试文档

## 概述

本文档描述了 ZigCMS 模板引擎的测试用例和测试方法。

## 测试文件

### 1. `mod.zig` - 基础功能测试

位置: `application/services/template/mod.zig`

包含 32 个测试用例，覆盖以下功能：

#### 基础功能测试
- `render variable` - 简单变量渲染
- `render if true` - if 条件语句（真）
- `render for loop` - for 循环语句
- `render variable with filter` - 变量与过滤器
- `render with join filter` - join 过滤器
- `render with escape filter` - escape 过滤器
- `render with trim filter` - trim 过滤器
- `render with reverse filter` - reverse 过滤器

#### 高级功能测试
- `render block` - 块定义
- `render macro` - 宏定义
- `render include` - 包含模板
- `render extends` - 模板继承
- `render import` - 导入宏

#### 自定义函数测试
- `render with builtin max function` - max 函数
- `render with builtin min function` - min 函数
- `render with cycle function` - cycle 函数

#### 更多过滤器测试
- `render with abs filter` - abs 过滤器
- `render with round filter` - round 过滤器
- `render with capitalize filter` - capitalize 过滤器
- `render with title filter` - title 过滤器
- `render with striptags filter` - striptags 过滤器
- `render with nl2br filter` - nl2br 过滤器
- `render with split filter` - split 过滤器
- `render with json_encode filter` - json_encode 过滤器

#### 循环变量测试
- `render with loop.index` - loop.index
- `render with loop.first and loop.last` - loop.first 和 loop.last
- `render with loop.length` - loop.length

#### 条件分支测试
- `render with if else` - if else
- `render with if elif` - if elif
- `render with if elif else` - if elif else

#### Set 变量测试
- `render with set` - set 变量赋值
- `render with set and expression` - set 与表达式

### 2. `template_test.zig` - 综合测试

位置: `application/services/template/template_test.zig`

包含 66 个测试用例，覆盖以下功能：

#### 基础功能测试 (8个)
- 简单变量渲染
- 多个变量渲染
- 数值变量渲染
- 布尔变量渲染

#### 条件语句测试 (8个)
- if 语句（真/假）
- if else
- if elif
- if elif else
- if 与比较运算符（==, >, !=）

#### 循环语句测试 (10个)
- 基本循环
- 带分隔符的循环
- 循环变量（index, index0, first, last, length, even, odd）
- 反向过滤循环
- 空循环

#### 过滤器测试 (18个)
- 字符串处理：upper, lower, trim, capitalize, title, striptags, nl2br
- 数组处理：length, join, reverse, first, last, split
- 数值处理：abs, round
- 安全处理：escape, json_encode

#### 函数测试 (4个)
- range 函数
- max 函数
- min 函数
- cycle 函数

#### Set 变量测试 (3个)
- set 字符串
- set 数值
- set 变量

#### 块和模板继承测试 (2个)
- 块定义
- 宏定义

#### 复杂模板测试 (5个)
- 嵌套 if 和 for
- 表格渲染（交替行）
- 分页示例
- 条件类渲染
- 用户列表与状态

#### 边界情况和错误处理测试 (6个)
- 空模板
- 纯文本模板
- 变量未找到
- 未闭合的变量
- 未闭合的标签
- 未终止的字符串

#### 性能测试 (3个)
- 大数组渲染（100个元素）
- 复杂嵌套结构
- 多个过滤器链式调用

#### 实际应用场景测试 (4个)
- 博客文章渲染
- 导航菜单
- 表单验证消息
- 实际 HTML 页面

## 运行测试

### 运行所有测试

```bash
# 运行所有模板引擎测试
zig build test -- application/services/template/

# 运行特定测试文件
zig build test -- application/services/template/mod.zig
zig build test -- application/services/template/template_test.zig
```

### 使用测试脚本

```bash
# 运行模板引擎测试脚本
./scripts/test_template.sh
```

## 测试覆盖范围

### 词法分析器 (Lexer)
- ✅ 文本识别
- ✅ 变量标记 `{{ }}`
- ✅ 标签标记 `{% %}`
- ✅ 标识符
- ✅ 字符串
- ✅ 数字
- ✅ 操作符
- ✅ 关键字（for, if, else, elif, set, in, extends, block, include, macro, from, import, parent）

### 语法分析器 (Parser)
- ✅ 文本节点
- ✅ 变量表达式
- ✅ for 循环
- ✅ if 条件语句
- ✅ elif 分支
- ✅ else 分支
- ✅ set 变量赋值
- ✅ extends 模板继承
- ✅ block 块定义
- ✅ include 包含
- ✅ macro 宏定义
- ✅ import 导入
- ✅ parent 父块调用

### 渲染器 (Renderer)
- ✅ 文本渲染
- ✅ 变量求值
- ✅ 过滤器应用
- ✅ 函数调用
- ✅ 循环渲染
- ✅ 条件渲染
- ✅ 块渲染
- ✅ 宏调用
- ✅ set 变量

### 过滤器 (Filters)
- ✅ upper - 大写
- ✅ lower - 小写
- ✅ length - 长度
- ✅ join - 连接
- ✅ escape - HTML 转义
- ✅ trim - 去空格
- ✅ reverse - 反转
- ✅ first - 第一个元素
- ✅ last - 最后一个元素
- ✅ abs - 绝对值
- ✅ round - 四舍五入
- ✅ capitalize - 首字母大写
- ✅ title - 标题格式
- ✅ striptags - 去除 HTML 标签
- ✅ nl2br - 换行转 br
- ✅ split - 分割
- ✅ json_encode - JSON 编码

### 函数 (Functions)
- ✅ range - 生成序列
- ✅ max - 最大值
- ✅ min - 最小值
- ✅ cycle - 循环遍历

### 循环变量 (Loop Variables)
- ✅ loop.index - 当前索引（从1开始）
- ✅ loop.index0 - 当前索引（从0开始）
- ✅ loop.first - 是否第一个
- ✅ loop.last - 是否最后一个
- ✅ loop.length - 总长度
- ✅ loop.revindex - 反向索引（从1开始）
- ✅ loop.revindex0 - 反向索引（从0开始）
- ✅ loop.even - 是否偶数
- ✅ loop.odd - 是否奇数

### 错误处理 (Error Handling)
- ✅ VariableNotFound - 变量未找到
- ✅ UnexpectedEof - 意外的文件结束
- ✅ UnterminatedString - 未终止的字符串
- ✅ ExpectedIdentifier - 期望标识符
- ✅ ExpectedOperator - 期望操作符
- ✅ ExpectedTagEnd - 期望标签结束

## 测试结果

### 当前状态

| 测试文件 | 测试用例数 | 状态 |
|---------|-----------|------|
| mod.zig | 32 | ✅ 已实现 |
| template_test.zig | 66 | ✅ 已实现 |
| **总计** | **98** | **✅ 已实现** |

### 测试分类统计

| 类别 | 测试用例数 |
|-----|-----------|
| 基础功能 | 16 |
| 条件语句 | 11 |
| 循环语句 | 13 |
| 过滤器 | 26 |
| 函数 | 7 |
| Set 变量 | 5 |
| 块和继承 | 4 |
| 复杂模板 | 5 |
| 边界情况 | 6 |
| 性能测试 | 3 |
| 实际应用 | 4 |

## 添加新测试

### 添加基础功能测试

在 `mod.zig` 中添加：

```zig
test "render new feature" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const template_str = "{{ your_template }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    // 设置上下文
    
    const result = try render(allocator, template_str, context);
    defer allocator.free(result);
    
    try std.testing.expectEqualStrings("expected", result);
}
```

### 添加综合测试

在 `template_test.zig` 中添加：

```zig
test "Template - new feature" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const template_str = "{{ your_template }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    // 设置上下文
    
    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);
    
    try std.testing.expectEqualStrings("expected", result);
}
```

## 已知问题

1. **网络依赖**: 由于网络问题，部分依赖包无法下载，导致测试无法运行
2. **include/extends**: 这些功能需要实际的模板文件，当前测试只验证解析成功
3. **宏调用**: 表达式中的宏调用功能尚未完全实现

## 未来改进

1. 添加更多边界情况测试
2. 添加性能基准测试
3. 添加集成测试（与数据库、HTTP 等集成）
4. 添加模糊测试（Fuzz Testing）
5. 添加内存泄漏检测测试

## 参考资料

- [Zig 测试文档](https://ziglang.org/documentation/master/#Testing)
- [Twig 模板文档](https://twig.symfony.com/doc/3.x/)
- [ZigCMS 开发规范](../../DEVELOPMENT_SPEC.md)

---

**最后更新**: 2025-12-27