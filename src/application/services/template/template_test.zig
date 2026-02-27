//! 模板引擎集成测试
//!
//! 测试模板引擎的各种功能，包括变量、条件、循环、过滤器、函数等

const std = @import("std");
const template = @import("mod.zig");
const engine_mod = @import("engine.zig");
const loader = @import("loader.zig");
const errors = @import("errors.zig");

// ============================================================================
// 测试辅助函数
// ============================================================================

/// 创建简单的上下文对象
fn createContext(allocator: std.mem.Allocator, key: []const u8, value: []const u8) !std.json.Value {
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put(key, std.json.Value{ .string = value });
    return std.json.Value{ .object = obj };
}

/// 创建带数组的上下文
fn createArrayContext(allocator: std.mem.Allocator, key: []const u8, values: []const []const u8) !std.json.Value {
    var obj = std.json.ObjectMap.init(allocator);
    var arr = std.json.Array.init(allocator);
    for (values) |v| {
        try arr.append(std.json.Value{ .string = v });
    }
    try obj.put(key, std.json.Value{ .array = arr });
    return std.json.Value{ .object = obj };
}

// ============================================================================
// 基础功能测试
// ============================================================================

test "Template - simple variable rendering" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "Hello {{ name }}!";
    const context = try createContext(allocator, "name", "World");

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World!", result);
}

test "Template - multiple variables" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ greeting }} {{ name }}!";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("greeting", std.json.Value{ .string = "Hello" });
    try obj.put("name", std.json.Value{ .string = "World" });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World!", result);
}

test "Template - numeric variable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "Count: {{ count }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("count", std.json.Value{ .integer = 42 });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Count: 42", result);
}

test "Template - boolean variable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "Active: {{ active }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("active", std.json.Value{ .bool = true });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Active: true", result);
}

// ============================================================================
// 条件语句测试
// ============================================================================

test "Template - if statement true" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% if show %}Visible{% endif %}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("show", std.json.Value{ .bool = true });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Visible", result);
}

test "Template - if statement false" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% if show %}Visible{% endif %}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("show", std.json.Value{ .bool = false });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "Template - if else" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% if show %}Yes{% else %}No{% endif %}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("show", std.json.Value{ .bool = false });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("No", result);
}

test "Template - if elif" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% if value1 %}One{% elif value2 %}Two{% endif %}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("value1", std.json.Value{ .bool = false });
    try obj.put("value2", std.json.Value{ .bool = true });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Two", result);
}

test "Template - if elif else" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% if value1 %}One{% elif value2 %}Two{% else %}Other{% endif %}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("value1", std.json.Value{ .bool = false });
    try obj.put("value2", std.json.Value{ .bool = false });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Other", result);
}

test "Template - if with comparison" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% if count == 5 %}Five{% endif %}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("count", std.json.Value{ .integer = 5 });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Five", result);
}

test "Template - if with greater than" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% if count > 5 %}Greater{% endif %}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("count", std.json.Value{ .integer = 10 });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Greater", result);
}

test "Template - if with not equal" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% if name != \"test\" %}Not test{% endif %}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("name", std.json.Value{ .string = "hello" });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Not test", result);
}

// ============================================================================
// 循环语句测试
// ============================================================================

test "Template - for loop" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for item in items %}{{ item }}{% endfor %}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("abc", result);
}

test "Template - for loop with separator" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for item in items %}{{ item }}, {% endfor %}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("a, b, c, ", result);
}

test "Template - for loop with loop.index" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for item in items %}{{ loop.index }}{% endfor %}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("123", result);
}

test "Template - for loop with loop.index0" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for item in items %}{{ loop.index0 }}{% endfor %}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("012", result);
}

test "Template - for loop with loop.first" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for item in items %}{% if loop.first %}F{% endif %}{% endfor %}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("F", result);
}

test "Template - for loop with loop.last" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for item in items %}{% if loop.last %}L{% endif %}{% endfor %}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("L", result);
}

test "Template - for loop with loop.length" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for item in items %}{{ loop.length }}{% endfor %}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("333", result);
}

test "Template - for loop with loop.even and loop.odd" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for item in items %}{% if loop.even %}E{% endif %}{% if loop.odd %}O{% endif %}{% endfor %}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c", "d" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("EOEO", result);
}

test "Template - for loop with reverse filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for item in items | reverse %}{{ item }}{% endfor %}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("cba", result);
}

test "Template - empty for loop" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for item in items %}{{ item }}{% endfor %}";
    var obj = std.json.ObjectMap.init(allocator);
    const arr = std.json.Array.init(allocator);
    try obj.put("items", std.json.Value{ .array = arr });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

// ============================================================================
// 过滤器测试
// ============================================================================

test "Template - upper filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ name | upper }}";
    const context = try createContext(allocator, "name", "world");

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("WORLD", result);
}

test "Template - lower filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ name | lower }}";
    const context = try createContext(allocator, "name", "WORLD");

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("world", result);
}

test "Template - length filter on string" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ name | length }}";
    const context = try createContext(allocator, "name", "hello");

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("5", result);
}

test "Template - length filter on array" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ items | length }}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("3", result);
}

test "Template - join filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ items | join:\", \" }}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("a, b, c", result);
}

test "Template - escape filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ content | escape }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("content", std.json.Value{ .string = "<script>alert('xss')</script>" });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("&lt;script&gt;alert(&#039;xss&#039;)&lt;/script&gt;", result);
}

test "Template - trim filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ text | trim }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("text", std.json.Value{ .string = "  hello world  " });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("hello world", result);
}

test "Template - reverse filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for item in items | reverse %}{{ item }}{% endfor %}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("cba", result);
}

test "Template - first filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ items | first }}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("a", result);
}

test "Template - last filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ items | last }}";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("c", result);
}

test "Template - abs filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ value | abs }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("value", std.json.Value{ .integer = -5 });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("5", result);
}

test "Template - round filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ value | round:2 }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("value", std.json.Value{ .float = 3.14159 });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("3.14", result);
}

test "Template - capitalize filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ text | capitalize }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("text", std.json.Value{ .string = "hello world" });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello world", result);
}

test "Template - title filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ text | title }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("text", std.json.Value{ .string = "hello world" });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World", result);
}

test "Template - striptags filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ content | striptags }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("content", std.json.Value{ .string = "<p>Hello <b>World</b></p>" });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World", result);
}

test "Template - nl2br filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ text | nl2br }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("text", std.json.Value{ .string = "Line 1\nLine 2" });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Line 1<br>Line 2", result);
}

test "Template - split filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for part in text | split:\",\" %}{{ part }}{% endfor %}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("text", std.json.Value{ .string = "a,b,c" });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("abc", result);
}

test "Template - json_encode filter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ data | json_encode }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("data", std.json.Value{ .string = "test" });
    const context = std.json.Value{ .object = obj };

    const result = try template(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("\"test\"", result);
}

// ============================================================================
// 函数测试
// ============================================================================

test "Template - range function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for i in range(1, 5) %}{{ i }}{% endfor %}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("12345", result);
}

test "Template - max function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ max(values) }}";
    var obj = std.json.ObjectMap.init(allocator);
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .integer = 1 });
    try arr.append(std.json.Value{ .integer = 5 });
    try arr.append(std.json.Value{ .integer = 3 });
    try obj.put("values", std.json.Value{ .array = arr });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("5", result);
}

test "Template - min function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ min(values) }}";
    var obj = std.json.ObjectMap.init(allocator);
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .integer = 1 });
    try arr.append(std.json.Value{ .integer = 5 });
    try arr.append(std.json.Value{ .integer = 3 });
    try obj.put("values", std.json.Value{ .array = arr });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("1", result);
}

test "Template - cycle function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ cycle(values, 3) }}";
    var obj = std.json.ObjectMap.init(allocator);
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .string = "odd" });
    try arr.append(std.json.Value{ .string = "even" });
    try obj.put("values", std.json.Value{ .array = arr });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("even", result);
}

// ============================================================================
// Set 变量测试
// ============================================================================

test "Template - set with string" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% set greeting = \"Hello\" %}{{ greeting }}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello", result);
}

test "Template - set with number" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% set count = 42 %}{{ count }}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("42", result);
}

test "Template - set with variable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% set greeting = name %}{{ greeting }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("name", std.json.Value{ .string = "World" });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("World", result);
}

// ============================================================================
// 块和模板继承测试
// ============================================================================

test "Template - block definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% block content %}Default content{% endblock %}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Default content", result);
}

test "Template - macro definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% macro greet(name) %}Hello {{ name }}!{% endmacro %}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

// ============================================================================
// 复杂模板测试
// ============================================================================

test "Template - nested if and for" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% if show %}{% for item in items %}{{ item }}{% endfor %}{% endif %}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("show", std.json.Value{ .bool = true });
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .string = "a" });
    try arr.append(std.json.Value{ .string = "b" });
    try obj.put("items", std.json.Value{ .array = arr });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("ab", result);
}

test "Template - table rendering with alternating rows" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "<table>{% for item in items %}<tr class=\"{% if loop.even %}even{% else %}odd{% endif %}\"><td>{{ item }}</td></tr>{% endfor %}</table>";
    const context = try createArrayContext(allocator, "items", &[_][]const u8{ "a", "b", "c" });

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expect(result.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, result, "<tr class=\"even\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "<tr class=\"odd\">") != null);
}

test "Template - pagination example" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "Page {{ page }} of {{ total_pages }} - Showing {{ items | length }} items";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("page", std.json.Value{ .integer = 1 });
    try obj.put("total_pages", std.json.Value{ .integer = 5 });
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .string = "a" });
    try arr.append(std.json.Value{ .string = "b" });
    try arr.append(std.json.Value{ .string = "c" });
    try obj.put("items", std.json.Value{ .array = arr });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Page 1 of 5 - Showing 3 items", result);
}

test "Template - conditional class rendering" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "<div class=\"item {% if active %}active{% endif %}\">Content</div>";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("active", std.json.Value{ .bool = true });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("<div class=\"item active\">Content</div>", result);
}

test "Template - user list with status" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "<ul>{% for user in users %}<li>{{ user.name }} - {% if user.status == 'active' %}Active{% else %}Inactive{% endif %}</li>{% endfor %}</ul>";
    var obj = std.json.ObjectMap.init(allocator);
    var arr = std.json.Array.init(allocator);
    
    var user1 = std.json.ObjectMap.init(allocator);
    try user1.put("name", std.json.Value{ .string = "Alice" });
    try user1.put("status", std.json.Value{ .string = "active" });
    try arr.append(std.json.Value{ .object = user1 });
    
    var user2 = std.json.ObjectMap.init(allocator);
    try user2.put("name", std.json.Value{ .string = "Bob" });
    try user2.put("status", std.json.Value{ .string = "inactive" });
    try arr.append(std.json.Value{ .object = user2 });
    
    try obj.put("users", std.json.Value{ .array = arr });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expect(result.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, result, "Alice - Active") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Bob - Inactive") != null);
}

// ============================================================================
// 边界情况和错误处理测试
// ============================================================================

test "Template - empty template" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "Template - template with only text" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "Hello World";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World", result);
}

test "Template - variable not found" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ missing_var }}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

    const result = template.render(allocator, template_str, context);
    try std.testing.expectError(errors.TemplateError.VariableNotFound, result);
}

test "Template - unclosed variable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ name";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

    const result = template.render(allocator, template_str, context);
    try std.testing.expectError(errors.TemplateError.UnexpectedEof, result);
}

test "Template - unclosed tag" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% if show";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

    const result = template.render(allocator, template_str, context);
    try std.testing.expectError(errors.TemplateError.UnexpectedEof, result);
}

test "Template - unterminated string" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ \"hello }}";
    const context = std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

    const result = template.render(allocator, template_str, context);
    try std.testing.expectError(errors.TemplateError.UnterminatedString, result);
}

// ============================================================================
// 性能测试
// ============================================================================

test "Template - large array rendering" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for item in items %}{{ item }}{% endfor %}";
    var obj = std.json.ObjectMap.init(allocator);
    var arr = std.json.Array.init(allocator);
    
    // 创建100个元素的数组
    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        try arr.append(std.json.Value{ .integer = i });
    }
    
    try obj.put("items", std.json.Value{ .array = arr });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 100), result.len);
}

test "Template - complex nested structure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for category in categories %}<h2>{{ category.name }}</h2><ul>{% for item in category.items %}<li>{{ item.name }} - {{ item.price }}</li>{% endfor %}</ul>{% endfor %}";
    var obj = std.json.ObjectMap.init(allocator);
    var categories = std.json.Array.init(allocator);
    
    // 创建第一个分类
    var cat1 = std.json.ObjectMap.init(allocator);
    try cat1.put("name", std.json.Value{ .string = "Electronics" });
    var items1 = std.json.Array.init(allocator);
    var item1 = std.json.ObjectMap.init(allocator);
    try item1.put("name", std.json.Value{ .string = "Laptop" });
    try item1.put("price", std.json.Value{ .integer = 999 });
    try items1.append(std.json.Value{ .object = item1 });
    try cat1.put("items", std.json.Value{ .array = items1 });
    try categories.append(std.json.Value{ .object = cat1 });
    
    try obj.put("categories", std.json.Value{ .array = categories });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expect(result.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, result, "<h2>Electronics</h2>") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Laptop - 999") != null);
}

test "Template - multiple filters chained" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ text | trim | upper | capitalize }}";
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("text", std.json.Value{ .string = "  hello world  " });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("HELLO WORLD", result);
}

// ============================================================================
// 实际应用场景测试
// ============================================================================

test "Template - blog post rendering" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = 
        \\<!DOCTYPE html>
        \\<html>
        \\<head><title>{{ post.title }}</title></head>
        \\<body>
        \\  <article>
        \\    <h1>{{ post.title }}</h1>
        \\    <p>By {{ post.author }} on {{ post.date }}</p>
        \\    <div>{{ post.content }}</div>
        \\  </article>
        \\<\body>
        \\</html>
    ;

    var obj = std.json.ObjectMap.init(allocator);
    var post = std.json.ObjectMap.init(allocator);
    try post.put("title", std.json.Value{ .string = "My First Post" });
    try post.put("author", std.json.Value{ .string = "John Doe" });
    try post.put("date", std.json.Value{ .string = "2025-01-01" });
    try post.put("content", std.json.Value{ .string = "This is my first blog post." });
    try obj.put("post", std.json.Value{ .object = post });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "My First Post") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "John Doe") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "This is my first blog post.") != null);
}

test "Template - navigation menu" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = 
        \\<nav>
        \\  <ul>
        \\  {% for item in menu %}
        \\    <li><a href=\"{{ item.url }}\"{% if item.active %} class=\"active\"{% endif %}>{{ item.label }}</a></li>
        \\  {% endfor %}
        \\  </ul>
        \\</nav>
    ;

    var obj = std.json.ObjectMap.init(allocator);
    var menu = std.json.Array.init(allocator);
    
    var item1 = std.json.ObjectMap.init(allocator);
    try item1.put("url", std.json.Value{ .string = "/home" });
    try item1.put("label", std.json.Value{ .string = "Home" });
    try item1.put("active", std.json.Value{ .bool = true });
    try menu.append(std.json.Value{ .object = item1 });
    
    var item2 = std.json.ObjectMap.init(allocator);
    try item2.put("url", std.json.Value{ .string = "/about" });
    try item2.put("label", std.json.Value{ .string = "About" });
    try item2.put("active", std.json.Value{ .bool = false });
    try menu.append(std.json.Value{ .object = item2 });
    
    try obj.put("menu", std.json.Value{ .array = menu });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "class=\"active\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Home") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "About") != null);
}

test "Template - form validation messages" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = 
        \\{% if errors %}
        \\  <div class=\"errors\">
        \\    {% for field, message in errors %}
        \\      <p>{{ field }}: {{ message }}</p>
        \\    {% endfor %}
        \\  </div>
        \\{% endif %}
    ;

    var obj = std.json.ObjectMap.init(allocator);
    var validation_errors = std.json.ObjectMap.init(allocator);
    try validation_errors.put("email", std.json.Value{ .string = "Invalid email format" });
    try validation_errors.put("password", std.json.Value{ .string = "Password too short" });
    try obj.put("errors", std.json.Value{ .object = validation_errors });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "Invalid email format") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Password too short") != null);
}