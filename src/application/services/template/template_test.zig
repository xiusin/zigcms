//! 模板引擎集成测试
//!
//! 测试模板引擎的各种功能，包括变量、条件、循环、过滤器、函数等

const std = @import("std");
const core_meta = @import("../../../core/meta.zig");
const core_io = @import("../../../core/io.zig");
const template = @import("mod.zig");
const engine_mod = @import("engine.zig");
const loader = @import("loader.zig");
const errors = @import("errors.zig");

// ============================================================================
// 测试辅助函数
// ============================================================================

/// 创建简单的上下文对象
fn createContext(allocator: std.mem.Allocator, key: []const u8, value: []const u8) !std.json.Value {
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, key, std.json.Value{ .string = value });
    return std.json.Value{ .object = obj };
}

/// 创建带数组的上下文
fn createArrayContext(allocator: std.mem.Allocator, key: []const u8, values: []const []const u8) !std.json.Value {
    var obj = std.json.ObjectMap.empty;
    var arr = std.json.Array.init(allocator);
    for (values) |v| {
        try arr.append(std.json.Value{ .string = v });
    }
    try obj.put(allocator, key, std.json.Value{ .array = arr });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "greeting", std.json.Value{ .string = "Hello" });
    try obj.put(allocator, "name", std.json.Value{ .string = "World" });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "count", std.json.Value{ .integer = 42 });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "active", std.json.Value{ .bool = true });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "show", std.json.Value{ .bool = true });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "show", std.json.Value{ .bool = false });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "show", std.json.Value{ .bool = false });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "value1", std.json.Value{ .bool = false });
    try obj.put(allocator, "value2", std.json.Value{ .bool = true });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "value1", std.json.Value{ .bool = false });
    try obj.put(allocator, "value2", std.json.Value{ .bool = false });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "count", std.json.Value{ .integer = 5 });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "count", std.json.Value{ .integer = 10 });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "name", std.json.Value{ .string = "hello" });
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
    var obj = std.json.ObjectMap.empty;
    const arr = std.json.Array.init(allocator);
    try obj.put(allocator, "items", std.json.Value{ .array = arr });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "content", std.json.Value{ .string = "<script>alert('xss')</script>" });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "text", std.json.Value{ .string = "  hello world  " });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "value", std.json.Value{ .integer = -5 });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "value", std.json.Value{ .float = 3.14159 });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "text", std.json.Value{ .string = "hello world" });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "text", std.json.Value{ .string = "hello world" });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "content", std.json.Value{ .string = "<p>Hello <b>World</b></p>" });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "text", std.json.Value{ .string = "Line 1\nLine 2" });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "text", std.json.Value{ .string = "a,b,c" });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "data", std.json.Value{ .string = "test" });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
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
    const context = std.json.Value{ .object = std.json.ObjectMap.empty };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("12345", result);
}

test "Template - max function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ max(values) }}";
    var obj = std.json.ObjectMap.empty;
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .integer = 1 });
    try arr.append(std.json.Value{ .integer = 5 });
    try arr.append(std.json.Value{ .integer = 3 });
    try obj.put(allocator, "values", std.json.Value{ .array = arr });
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
    var obj = std.json.ObjectMap.empty;
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .integer = 1 });
    try arr.append(std.json.Value{ .integer = 5 });
    try arr.append(std.json.Value{ .integer = 3 });
    try obj.put(allocator, "values", std.json.Value{ .array = arr });
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
    var obj = std.json.ObjectMap.empty;
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .string = "odd" });
    try arr.append(std.json.Value{ .string = "even" });
    try obj.put(allocator, "values", std.json.Value{ .array = arr });
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
    const context = std.json.Value{ .object = std.json.ObjectMap.empty };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello", result);
}

test "Template - set with number" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% set count = 42 %}{{ count }}";
    const context = std.json.Value{ .object = std.json.ObjectMap.empty };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("42", result);
}

test "Template - set with variable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% set greeting = name %}{{ greeting }}";
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "name", std.json.Value{ .string = "World" });
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
    const context = std.json.Value{ .object = std.json.ObjectMap.empty };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Default content", result);
}

test "Template - macro definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% macro greet(name) %}Hello {{ name }}!{% endmacro %}";
    const context = std.json.Value{ .object = std.json.ObjectMap.empty };

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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "show", std.json.Value{ .bool = true });
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .string = "a" });
    try arr.append(std.json.Value{ .string = "b" });
    try obj.put(allocator, "items", std.json.Value{ .array = arr });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "page", std.json.Value{ .integer = 1 });
    try obj.put(allocator, "total_pages", std.json.Value{ .integer = 5 });
    var arr = std.json.Array.init(allocator);
    try arr.append(std.json.Value{ .string = "a" });
    try arr.append(std.json.Value{ .string = "b" });
    try arr.append(std.json.Value{ .string = "c" });
    try obj.put(allocator, "items", std.json.Value{ .array = arr });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "active", std.json.Value{ .bool = true });
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
    var obj = std.json.ObjectMap.empty;
    var arr = std.json.Array.init(allocator);
    
    var user1 = std.json.ObjectMap.empty;
    try user1.put(allocator, "name", std.json.Value{ .string = "Alice" });
    try user1.put(allocator, "status", std.json.Value{ .string = "active" });
    try arr.append(std.json.Value{ .object = user1 });
    
    var user2 = std.json.ObjectMap.empty;
    try user2.put(allocator, "name", std.json.Value{ .string = "Bob" });
    try user2.put(allocator, "status", std.json.Value{ .string = "inactive" });
    try arr.append(std.json.Value{ .object = user2 });
    
    try obj.put(allocator, "users", std.json.Value{ .array = arr });
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
    const context = std.json.Value{ .object = std.json.ObjectMap.empty };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "Template - template with only text" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "Hello World";
    const context = std.json.Value{ .object = std.json.ObjectMap.empty };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World", result);
}

test "Template - variable not found" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ missing_var }}";
    const context = std.json.Value{ .object = std.json.ObjectMap.empty };

    const result = template.render(allocator, template_str, context);
    try std.testing.expectError(errors.TemplateError.VariableNotFound, result);
}

test "Template - unclosed variable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ name";
    const context = std.json.Value{ .object = std.json.ObjectMap.empty };

    const result = template.render(allocator, template_str, context);
    try std.testing.expectError(errors.TemplateError.UnexpectedEof, result);
}

test "Template - unclosed tag" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% if show";
    const context = std.json.Value{ .object = std.json.ObjectMap.empty };

    const result = template.render(allocator, template_str, context);
    try std.testing.expectError(errors.TemplateError.UnexpectedEof, result);
}

test "Template - unterminated string" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{{ \"hello }}";
    const context = std.json.Value{ .object = std.json.ObjectMap.empty };

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
    var obj = std.json.ObjectMap.empty;
    var arr = std.json.Array.init(allocator);
    
    // 创建100个元素的数组
    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        try arr.append(std.json.Value{ .integer = i });
    }
    
    try obj.put(allocator, "items", std.json.Value{ .array = arr });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    // 0..9 共 10 个字符，10..99 各 2 个字符，总长 10 + 90*2 = 190
    try std.testing.expectEqual(@as(usize, 190), result.len);
}

test "Template - complex nested structure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const template_str = "{% for category in categories %}<h2>{{ category.name }}</h2><ul>{% for item in category.items %}<li>{{ item.name }} - {{ item.price }}</li>{% endfor %}</ul>{% endfor %}";
    var obj = std.json.ObjectMap.empty;
    var categories = std.json.Array.init(allocator);
    
    // 创建第一个分类
    var cat1 = std.json.ObjectMap.empty;
    try cat1.put(allocator, "name", std.json.Value{ .string = "Electronics" });
    var items1 = std.json.Array.init(allocator);
    var item1 = std.json.ObjectMap.empty;
    try item1.put(allocator, "name", std.json.Value{ .string = "Laptop" });
    try item1.put(allocator, "price", std.json.Value{ .integer = 999 });
    try items1.append(std.json.Value{ .object = item1 });
    try cat1.put(allocator, "items", std.json.Value{ .array = items1 });
    try categories.append(std.json.Value{ .object = cat1 });
    
    try obj.put(allocator, "categories", std.json.Value{ .array = categories });
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
    var obj = std.json.ObjectMap.empty;
    try obj.put(allocator, "text", std.json.Value{ .string = "  hello world  " });
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

    var obj = std.json.ObjectMap.empty;
    var post = std.json.ObjectMap.empty;
    try post.put(allocator, "title", std.json.Value{ .string = "My First Post" });
    try post.put(allocator, "author", std.json.Value{ .string = "John Doe" });
    try post.put(allocator, "date", std.json.Value{ .string = "2025-01-01" });
    try post.put(allocator, "content", std.json.Value{ .string = "This is my first blog post." });
    try obj.put(allocator, "post", std.json.Value{ .object = post });
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
        \\<li><a href="{{ item.url }}"{% if item.active %} class="active"{% endif %}>{{ item.label }}</a></li>
        \\  {% endfor %}
        \\  </ul>
        \\</nav>
    ;

    var obj = std.json.ObjectMap.empty;
    var menu = std.json.Array.init(allocator);
    
    var item1 = std.json.ObjectMap.empty;
    try item1.put(allocator, "url", std.json.Value{ .string = "/home" });
    try item1.put(allocator, "label", std.json.Value{ .string = "Home" });
    try item1.put(allocator, "active", std.json.Value{ .bool = true });
    try menu.append(std.json.Value{ .object = item1 });
    
    var item2 = std.json.ObjectMap.empty;
    try item2.put(allocator, "url", std.json.Value{ .string = "/about" });
    try item2.put(allocator, "label", std.json.Value{ .string = "About" });
    try item2.put(allocator, "active", std.json.Value{ .bool = false });
    try menu.append(std.json.Value{ .object = item2 });
    
    try obj.put(allocator, "menu", std.json.Value{ .array = menu });
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

    var obj = std.json.ObjectMap.empty;
    var validation_errors = std.json.ObjectMap.empty;
    try validation_errors.put(allocator, "email", std.json.Value{ .string = "Invalid email format" });
    try validation_errors.put(allocator, "password", std.json.Value{ .string = "Password too short" });
    try obj.put(allocator, "errors", std.json.Value{ .object = validation_errors });
    const context = std.json.Value{ .object = obj };

    const result = try template.render(allocator, template_str, context);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "Invalid email format") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Password too short") != null);
}

// ============================================================================
// 模板继承（Engine extends / block / parent）端到端测试
// ============================================================================

/// 测试模板仓库：load_fn 无上下文参数，经模块级状态注入；Zig 测试串行执行，安全
var test_repo: ?*std.StringHashMap([]const u8) = null;

fn testLoadFn(allocator: std.mem.Allocator, template_name: []const u8) anyerror![]const u8 {
    const repo = test_repo orelse return error.TemplateNotFound;
    const content = repo.get(template_name) orelse return error.TemplateNotFound;
    return try allocator.dupe(u8, content);
}

/// loader/engine 用 testing.allocator（泄漏/双重释放可被检出），repo 等临时数据走 arena
fn setupInheritEngine(
    allocator: std.mem.Allocator,
    ld: *loader.Loader,
    eng: *engine_mod.Engine,
    repo: *std.StringHashMap([]const u8),
) !void {
    test_repo = repo;
    ld.* = loader.Loader.init(allocator, testLoadFn);
    eng.* = engine_mod.Engine.init(allocator, ld);
}

const inherit_parent =
    \\<html><title>{% block title %}Default Title{% endblock %}</title><body>{% block content %}Default Body{% endblock %}</body></html>
;

const inherit_child_full =
    \\{% extends "parent" %}{% block title %}My Page{% endblock %}{% block content %}Hello {{ name }}{% endblock %}
;

test "Template Engine - child overrides parent blocks" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);
    try repo.put("parent", inherit_parent);
    try repo.put("child", inherit_child_full);

    var ld: loader.Loader = undefined;
    var eng: engine_mod.Engine = undefined;
    try setupInheritEngine(allocator, &ld, &eng, &repo);
    defer eng.deinit();
    defer ld.deinit();

    var obj = std.json.ObjectMap.empty;
    try obj.put(a, "name", std.json.Value{ .string = "World" });

    const result = try eng.render("child", .{ .object = obj });
    defer allocator.free(result);

    try std.testing.expectEqualStrings(
        "<html><title>My Page</title><body>Hello World</body></html>",
        result,
    );
}

test "Template Engine - child keeps parent default and drops top-level junk" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);
    try repo.put("parent", inherit_parent);
    // Twig 语义：extends 之外的顶层内容不渲染
    try repo.put("child", \\{% extends "parent" %}SHOULD-NOT-RENDER{% block title %}Only Title{% endblock %}
    );

    var ld: loader.Loader = undefined;
    var eng: engine_mod.Engine = undefined;
    try setupInheritEngine(allocator, &ld, &eng, &repo);
    defer eng.deinit();
    defer ld.deinit();

    const result = try eng.render("child", .{ .object = std.json.ObjectMap.empty });
    defer allocator.free(result);

    try std.testing.expectEqualStrings(
        "<html><title>Only Title</title><body>Default Body</body></html>",
        result,
    );
    try std.testing.expect(std.mem.indexOf(u8, result, "SHOULD-NOT-RENDER") == null);
}

test "Template Engine - multi-level chain with parent at each level" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);
    try repo.put("grand", \\[GP:{% block content %}gp{% endblock %}]
    );
    try repo.put("middle", \\{% extends "grand" %}{% block content %}[mid+{% parent %}]{% endblock %}
    );
    try repo.put("kid", \\{% extends "middle" %}{% block content %}[kid+{% parent %}]{% endblock %}
    );

    var ld: loader.Loader = undefined;
    var eng: engine_mod.Engine = undefined;
    try setupInheritEngine(allocator, &ld, &eng, &repo);
    defer eng.deinit();
    defer ld.deinit();

    // 子覆盖 -> parent 回溯到 middle -> middle 的 parent 回溯到 grand
    const result = try eng.render("kid", .{ .object = std.json.ObjectMap.empty });
    defer allocator.free(result);
    try std.testing.expectEqualStrings("[GP:[kid+[mid+gp]]]", result);

    // 直接渲染父模板：块就地取自身默认定义
    const parent_result = try eng.render("grand", .{ .object = std.json.ObjectMap.empty });
    defer allocator.free(parent_result);
    try std.testing.expectEqualStrings("[GP:gp]", parent_result);
}

test "Template Engine - macro defined in parent used by child block" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);
    try repo.put("parent", \\{% macro badge(name) %}<b>{{ name }}</b>{% endmacro %}{% block content %}{{ badge("none") }}{% endblock %}
    );
    try repo.put("child", \\{% extends "parent" %}{% block content %}{{ badge("Zig") }}{% endblock %}
    );

    var ld: loader.Loader = undefined;
    var eng: engine_mod.Engine = undefined;
    try setupInheritEngine(allocator, &ld, &eng, &repo);
    defer eng.deinit();
    defer ld.deinit();

    const result = try eng.render("child", .{ .object = std.json.ObjectMap.empty });
    defer allocator.free(result);
    try std.testing.expectEqualStrings("<b>Zig</b>", result);
}

test "Template Engine - circular extends rejected" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);
    try repo.put("a", \\{% extends "b" %}
    );
    try repo.put("b", \\{% extends "a" %}
    );

    var ld: loader.Loader = undefined;
    var eng: engine_mod.Engine = undefined;
    try setupInheritEngine(allocator, &ld, &eng, &repo);
    defer eng.deinit();
    defer ld.deinit();

    try std.testing.expectError(error.CircularExtends, eng.render("a", .{ .object = std.json.ObjectMap.empty }));
}

test "Template Engine - missing template errors" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);

    var ld: loader.Loader = undefined;
    var eng: engine_mod.Engine = undefined;
    try setupInheritEngine(allocator, &ld, &eng, &repo);
    defer eng.deinit();
    defer ld.deinit();

    try std.testing.expectError(error.TemplateNotFound, eng.render("nope", .{ .object = std.json.ObjectMap.empty }));
}

test "Template Engine - cached template renders consistently" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);
    try repo.put("parent", inherit_parent);
    try repo.put("child", inherit_child_full);

    var ld: loader.Loader = undefined;
    var eng: engine_mod.Engine = undefined;
    try setupInheritEngine(allocator, &ld, &eng, &repo);
    defer eng.deinit();
    defer ld.deinit();

    // 第一次渲染走解析路径，第二次走缓存路径，两者结果必须一致（防缓存借用被破坏）
    var obj = std.json.ObjectMap.empty;
    try obj.put(a, "name", std.json.Value{ .string = "World" });
    const ctx = std.json.Value{ .object = obj };

    const first = try eng.render("child", ctx);
    defer allocator.free(first);
    const second = try eng.render("child", ctx);
    defer allocator.free(second);
    try std.testing.expectEqualStrings(first, second);
    try std.testing.expectEqualStrings(
        "<html><title>My Page</title><body>Hello World</body></html>",
        second,
    );
}

// ============================================================================
// include 指令端到端测试
// ============================================================================

test "Template Engine - include inlines partial with shared context" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);
    try repo.put("greeting", "Hello {{ who }}!");
    try repo.put("page", "START[{% include \"greeting\" %}]END");

    var ld: loader.Loader = undefined;
    var eng: engine_mod.Engine = undefined;
    try setupInheritEngine(allocator, &ld, &eng, &repo);
    defer eng.deinit();
    defer ld.deinit();

    var obj = std.json.ObjectMap.empty;
    try obj.put(a, "who", std.json.Value{ .string = "Zig" });
    const ctx = std.json.Value{ .object = obj };

    const out = try eng.render("page", ctx);
    defer allocator.free(out);
    try std.testing.expectEqualStrings("START[Hello Zig!]END", out);
}

test "Template Engine - include renders own macros, no leak to outer" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);
    // 被包含模板里定义宏并在其中调用（include 链内自洽）
    try repo.put("macro_lib", "{% macro shout(x) %}!!{{ x }}!!{% endmacro %}[{{ shout(\"hi\") }}]");
    try repo.put("page", "{% include \"macro_lib\" %}");
    // include 的宏不外泄：外层调用报未知函数（Twig 严格语义）
    try repo.put("page_leak", "{% include \"macro_lib\" %}<{{ shout(\"yo\") }}>");
    // 外层自有宏与 include 内部同名宏互不影响
    try repo.put("page2", "{% macro shout(x) %}outer:{{ x }}{% endmacro %}{% include \"macro_lib\" %}<{{ shout(\"yo\") }}>");

    var ld: loader.Loader = undefined;
    var eng: engine_mod.Engine = undefined;
    try setupInheritEngine(allocator, &ld, &eng, &repo);
    defer eng.deinit();
    defer ld.deinit();

    const ctx = std.json.Value{ .object = std.json.ObjectMap.empty };

    const out1 = try eng.render("page", ctx);
    defer allocator.free(out1);
    try std.testing.expectEqualStrings("[!!hi!!]", out1);

    try std.testing.expectError(error.UnknownFunction, eng.render("page_leak", ctx));

    const out2 = try eng.render("page2", ctx);
    defer allocator.free(out2);
    try std.testing.expectEqualStrings("[!!hi!!]<outer:yo>", out2);
}

test "Template Engine - include with merges context, only isolates" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);
    try repo.put("card", "[{{ lang }}:Hello {{ name }}!]");
    try repo.put("card2", "[Hello {{ name }}!]");
    // with 合并：user 的键覆盖外层同名键，外层其余键保留
    try repo.put("page", "{% include \"card\" with user %}");
    // only 隔离：仅使用 with 变量，lang 不可见（渲染报变量未找到）
    try repo.put("page2", "{% include \"card\" with user only %}");
    // only 正向：模板只引用 with 内的变量时正常渲染
    try repo.put("page4", "{% include \"card2\" with user only %}");
    // with 路径缺失：按空对象兜底（合并语义下上下文不变）
    try repo.put("page3", "{% include \"card\" with missing.path %}");

    var ld: loader.Loader = undefined;
    var eng: engine_mod.Engine = undefined;
    try setupInheritEngine(allocator, &ld, &eng, &repo);
    defer eng.deinit();
    defer ld.deinit();

    var user_obj = std.json.ObjectMap.empty;
    try user_obj.put(a, "name", std.json.Value{ .string = "U" });

    var obj = std.json.ObjectMap.empty;
    try obj.put(a, "lang", std.json.Value{ .string = "zh" });
    try obj.put(a, "name", std.json.Value{ .string = "Outer" });
    try obj.put(a, "user", std.json.Value{ .object = user_obj });
    const ctx = std.json.Value{ .object = obj };

    const out1 = try eng.render("page", ctx);
    defer allocator.free(out1);
    try std.testing.expectEqualStrings("[zh:Hello U!]", out1);

    try std.testing.expectError(error.VariableNotFound, eng.render("page2", ctx));

    const out4 = try eng.render("page4", ctx);
    defer allocator.free(out4);
    try std.testing.expectEqualStrings("[Hello U!]", out4);

    const out3 = try eng.render("page3", ctx);
    defer allocator.free(out3);
    try std.testing.expectEqualStrings("[zh:Hello Outer!]", out3);
}

test "Template Engine - from import macros" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);
    try repo.put("macro_lib", "{% macro greet(name) %}Hi {{ name }}{% endmacro %}{% macro bye() %}Bye{% endmacro %}");
    try repo.put("page", "{% from \"macro_lib\" import greet %}[{{ greet(\"Zig\") }}]");
    try repo.put("page2", "{% from \"macro_lib\" import greet, bye %}[{{ greet(\"A\") }}|{{ bye() }}]");
    try repo.put("page3", "{% from \"macro_lib\" import * %}[{{ greet(\"B\") }}|{{ bye() }}]");
    // import 覆盖外层同名宏
    try repo.put("page4", "{% macro greet(name) %}X{% endmacro %}{% from \"macro_lib\" import greet %}[{{ greet(\"C\") }}]");

    var ld: loader.Loader = undefined;
    var eng: engine_mod.Engine = undefined;
    try setupInheritEngine(allocator, &ld, &eng, &repo);
    defer eng.deinit();
    defer ld.deinit();

    const ctx = std.json.Value{ .object = std.json.ObjectMap.empty };

    const out1 = try eng.render("page", ctx);
    defer allocator.free(out1);
    try std.testing.expectEqualStrings("[Hi Zig]", out1);

    const out2 = try eng.render("page2", ctx);
    defer allocator.free(out2);
    try std.testing.expectEqualStrings("[Hi A|Bye]", out2);

    const out3 = try eng.render("page3", ctx);
    defer allocator.free(out3);
    try std.testing.expectEqualStrings("[Hi B|Bye]", out3);

    const out4 = try eng.render("page4", ctx);
    defer allocator.free(out4);
    try std.testing.expectEqualStrings("[Hi C]", out4);
}

test "Template Engine - nested include works, circular include rejected" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);
    try repo.put("c", "C");
    try repo.put("b", "B[{% include \"c\" %}]");
    try repo.put("a", "A[{% include \"b\" %}]");
    // 循环 include：x -> y -> x ...，由嵌套深度上限拦截
    try repo.put("x", "X[{% include \"y\" %}]");
    try repo.put("y", "Y[{% include \"x\" %}]");

    var ld: loader.Loader = undefined;
    var eng: engine_mod.Engine = undefined;
    try setupInheritEngine(allocator, &ld, &eng, &repo);
    defer eng.deinit();
    defer ld.deinit();

    const ctx = std.json.Value{ .object = std.json.ObjectMap.empty };

    const out = try eng.render("a", ctx);
    defer allocator.free(out);
    try std.testing.expectEqualStrings("A[B[C]]", out);

    try std.testing.expectError(error.IncludeNestingTooDeep, eng.render("x", ctx));
}

// ============================================================================
// 并发渲染测试
// ============================================================================

test "Template Engine - concurrent renders of same template" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var repo = std.StringHashMap([]const u8).init(a);
    try repo.put("parent", inherit_parent);
    try repo.put("child", inherit_child_full);

    // 并发环境需线程安全分配器（testing.allocator 的泄漏检查不覆盖多线程路径）
    var gpa = std.heap.DebugAllocator(.{}).init;
    const galloc = gpa.allocator();

    // engine/loader 生命周期收进块作用域：退出块时全部释放，之后才能做 gpa 泄漏检查
    {
        var ld: loader.Loader = undefined;
        var eng: engine_mod.Engine = undefined;
        try setupInheritEngine(galloc, &ld, &eng, &repo);
        defer eng.deinit();
        defer ld.deinit();

        var obj = std.json.ObjectMap.empty;
        try obj.put(a, "name", std.json.Value{ .string = "World" });
        const ctx = std.json.Value{ .object = obj };

        const Worker = struct {
            fn run(eng_ptr: *engine_mod.Engine, context: std.json.Value, out: *?[]u8) void {
                if (eng_ptr.render("child", context)) |result| {
                    out.* = result;
                } else |_| {
                    out.* = null;
                }
            }
        };

        var r1: ?[]u8 = null;
        var r2: ?[]u8 = null;
        const t1 = try std.Thread.spawn(.{}, Worker.run, .{ &eng, ctx, &r1 });
        const t2 = try std.Thread.spawn(.{}, Worker.run, .{ &eng, ctx, &r2 });
        t1.join();
        t2.join();

        defer {
            if (r1) |s| galloc.free(s);
            if (r2) |s| galloc.free(s);
        }

        try std.testing.expect(r1 != null and r2 != null);
        try std.testing.expectEqualStrings(
            "<html><title>My Page</title><body>Hello World</body></html>",
            r1.?,
        );
        try std.testing.expectEqualStrings(r1.?, r2.?);
    }

    try std.testing.expect(gpa.deinit() == .ok);
}