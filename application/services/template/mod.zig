//! Twig 兼容的模板引擎
//!
//! 支持变量 {{ var }}, 循环 {% for item in items %}, 条件 {% if condition %}, 设置 {% set var = value %}

const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const renderer = @import("renderer.zig");

/// 渲染模板
pub fn render(allocator: std.mem.Allocator, template: []const u8, context: std.json.Value) ![]u8 {
    var lex = lexer.Lexer.init(template);
    const ast = try parser.parse(allocator, &lex, null);
    defer parser.freeAst(allocator, ast);
    return renderer.render(allocator, ast, context);
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
    const template = "{% if show == true %}Visible{% endif %}";
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
