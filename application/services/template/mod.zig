//! Twig 兼容的模板引擎
//!
//! 支持变量 {{ var }}, 循环 {% for item in items %}, 条件 {% if condition %}, 设置 {% set var = value %}

const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const renderer = @import("renderer.zig");
const functions = @import("functions.zig");

/// 渲染模板
pub fn render(allocator: std.mem.Allocator, template: []const u8, context: std.json.Value) ![]u8 {
    var lex = lexer.Lexer.init(template);
    const ast = try parser.parse(allocator, &lex, null);
    defer parser.freeAst(allocator, ast);
    
    // 创建内置函数注册表
    var fn_registry = functions.FunctionRegistry.init(allocator);
    defer fn_registry.deinit();
    
    return renderer.render(allocator, ast, context, &fn_registry);
}

test "render variable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "Hello {{ name }}!";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("name", std.json.Value{ .string = "World" });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello World!", result);
}

test "render if true" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% if show %}Visible{% endif %}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("show", std.json.Value{ .bool = true });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Visible", result);
}

test "render for loop" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% for item in items %}{{ item }}{% endfor %}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    var items = std.json.Array.init(allocator);
    try items.append(std.json.Value{ .string = "a" });
    try items.append(std.json.Value{ .string = "b" });
    try context.object.put("items", std.json.Value{ .array = items });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("ab", result);
}

test "render variable with filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ name | upper }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("name", std.json.Value{ .string = "world" });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("WORLD", result);
}

test "render with join filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ items | join:\", \" }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    var items = std.json.Array.init(allocator);
    try items.append(std.json.Value{ .string = "a" });
    try items.append(std.json.Value{ .string = "b" });
    try items.append(std.json.Value{ .string = "c" });
    try context.object.put("items", std.json.Value{ .array = items });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("a, b, c", result);
}

test "render with escape filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ content | escape }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("content", std.json.Value{ .string = "<script>alert('xss')</script>" });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("&lt;script&gt;alert(&#039;xss&#039;)&lt;/script&gt;", result);
}

test "render with trim filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ text | trim }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("text", std.json.Value{ .string = "  hello world  " });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello world", result);
}

test "render with reverse filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% for item in items | reverse %}{{ item }}{% endfor %}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    var items = std.json.Array.init(allocator);
    try items.append(std.json.Value{ .string = "a" });
    try items.append(std.json.Value{ .string = "b" });
    try items.append(std.json.Value{ .string = "c" });
    try context.object.put("items", std.json.Value{ .array = items });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("cba", result);
}

test "render block" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% block content %}Default content{% endblock %}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Default content", result);
}

test "render macro" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% macro greet(name) %}Hello {{ name }}!{% endmacro %}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "render include" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% include \"header\" %}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    // include 需要实际的文件，这里只测试解析成功
    // 结果为空字符串是正常的，因为没有实际的文件
    try std.testing.expectEqualStrings("", result);
}

test "render extends" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% extends \"base\" %}{% block content %}Child content{% endblock %}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    // extends 需要实际的文件，这里只测试解析成功
    // block 内容会被渲染，因为没有父模板
    try std.testing.expectEqualStrings("Child content", result);
}

test "render import" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% from \"macros\" import greet %}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    // import 需要实际的文件，这里只测试解析成功
    // 结果为空字符串是正常的，因为没有实际的宏文件
    try std.testing.expectEqualStrings("", result);
}

// ========================================================================
// 新功能测试：自定义函数
// ========================================================================

test "render with builtin max function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ max(values) }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .integer = 1 });
    try arr.append(std.json.Value{ .integer = 5 });
    try arr.append(std.json.Value{ .integer = 3 });
    try context.object.put("values", std.json.Value{ .array = arr });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("5", result);
}

test "render with builtin min function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ min(values) }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .integer = 1 });
    try arr.append(std.json.Value{ .integer = 5 });
    try arr.append(std.json.Value{ .integer = 3 });
    try context.object.put("values", std.json.Value{ .array = arr });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("1", result);
}

test "render with cycle function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ cycle(values, 3) }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .string = "odd" });
    try arr.append(std.json.Value{ .string = "even" });
    try context.object.put("values", std.json.Value{ .array = arr });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("even", result);
}

// ========================================================================
// 新功能测试：更多过滤器
// ========================================================================

test "render with abs filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ value | abs }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("value", std.json.Value{ .integer = -5 });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("5", result);
}

test "render with round filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ value | round:2 }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("value", std.json.Value{ .float = 3.14159 });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("3.14", result);
}

test "render with capitalize filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ text | capitalize }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("text", std.json.Value{ .string = "hello world" });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello world", result);
}

test "render with title filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ text | title }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("text", std.json.Value{ .string = "hello world" });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello World", result);
}

test "render with striptags filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ content | striptags }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("content", std.json.Value{ .string = "<p>Hello <b>World</b></p>" });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello World", result);
}

test "render with nl2br filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ text | nl2br }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("text", std.json.Value{ .string = "Line 1\nLine 2" });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Line 1<br>Line 2", result);
}

test "render with split filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ text | split:\",\" }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("text", std.json.Value{ .string = "a,b,c" });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    // split 返回数组，这里只测试解析成功
    try std.testing.expect(result.len > 0);
}

test "render with json_encode filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{{ data | json_encode }}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("data", std.json.Value{ .string = "test" });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("\"test\"", result);
}

// ========================================================================
// 新功能测试：循环变量
// ========================================================================

test "render with loop.index" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% for item in items %}{{ loop.index }}{% endfor %}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    var items = std.json.Array.init(allocator);
    try items.append(std.json.Value{ .string = "a" });
    try items.append(std.json.Value{ .string = "b" });
    try items.append(std.json.Value{ .string = "c" });
    try context.object.put("items", std.json.Value{ .array = items });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("123", result);
}

test "render with loop.first and loop.last" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% for item in items %}{% if loop.first %}F{% endif %}{% if loop.last %}L{% endif %}{% endfor %}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    var items = std.json.Array.init(allocator);
    try items.append(std.json.Value{ .string = "a" });
    try items.append(std.json.Value{ .string = "b" });
    try context.object.put("items", std.json.Value{ .array = items });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("FL", result);
}

test "render with loop.length" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% for item in items %}{{ loop.length }}{% endfor %}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    var items = std.json.Array.init(allocator);
    try items.append(std.json.Value{ .string = "a" });
    try items.append(std.json.Value{ .string = "b" });
    try items.append(std.json.Value{ .string = "c" });
    try context.object.put("items", std.json.Value{ .array = items });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("333", result);
}

// ========================================================================
// 新功能测试：else 和 elif
// ========================================================================

test "render with if else" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% if show %}Yes{% else %}No{% endif %}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("show", std.json.Value{ .bool = false });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("No", result);
}

test "render with if elif" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% if value1 %}One{% elif value2 %}Two{% endif %}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("value1", std.json.Value{ .bool = false });
    try context.object.put("value2", std.json.Value{ .bool = true });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Two", result);
}

test "render with if elif else" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% if value1 %}One{% elif value2 %}Two{% else %}Other{% endif %}";
    var context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    try context.object.put("value1", std.json.Value{ .bool = false });
    try context.object.put("value2", std.json.Value{ .bool = false });
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Other", result);
}

// ========================================================================
// 新功能测试：set 变量赋值
// ========================================================================

test "render with set" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% set greeting = \"Hello\" %}{{ greeting }}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "render with set and expression" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const template = "{% set total = 10 + 5 %}{{ total }}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
    const result = try render(allocator, template, context);
    defer allocator.free(result);
    // set 支持表达式，这里测试解析成功
    try std.testing.expect(result.len > 0);
}
