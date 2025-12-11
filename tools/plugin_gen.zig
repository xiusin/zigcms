//! 插件代码生成器
//!
//! 根据配置自动生成插件代码框架
//!
//! 用法:
//!   zig build plugin-gen -- --name=MyPlugin --desc="我的插件" --caps=http,routes
//!
//! 参数:
//!   --name     插件名称（必填）
//!   --desc     插件描述
//!   --author   作者名称
//!   --caps     能力列表（逗号分隔）: http,middleware,scheduler,db,events,template,routes,websocket
//!   --output   输出目录（默认 plugins/）

const std = @import("std");

/// 插件生成配置
const PluginConfig = struct {
    name: []const u8 = "",
    description: []const u8 = "自动生成的插件",
    author: []const u8 = "ZigCMS",
    output_dir: []const u8 = "plugins",
    // 能力配置
    cap_http: bool = false,
    cap_middleware: bool = false,
    cap_scheduler: bool = false,
    cap_db_hooks: bool = false,
    cap_events: bool = false,
    cap_template: bool = false,
    cap_routes: bool = false,
    cap_websocket: bool = false,
};

/// 模板内容
const TEMPLATE = @embedFile("../plugins/templates/plugin_template.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 解析命令行参数
    var config = PluginConfig{};
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // 跳过程序名

    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--name=")) {
            config.name = arg[7..];
        } else if (std.mem.startsWith(u8, arg, "--desc=")) {
            config.description = arg[7..];
        } else if (std.mem.startsWith(u8, arg, "--author=")) {
            config.author = arg[9..];
        } else if (std.mem.startsWith(u8, arg, "--output=")) {
            config.output_dir = arg[9..];
        } else if (std.mem.startsWith(u8, arg, "--caps=")) {
            const caps_str = arg[7..];
            var caps_iter = std.mem.splitScalar(u8, caps_str, ',');
            while (caps_iter.next()) |cap| {
                if (std.mem.eql(u8, cap, "http")) config.cap_http = true;
                if (std.mem.eql(u8, cap, "middleware")) config.cap_middleware = true;
                if (std.mem.eql(u8, cap, "scheduler")) config.cap_scheduler = true;
                if (std.mem.eql(u8, cap, "db")) config.cap_db_hooks = true;
                if (std.mem.eql(u8, cap, "events")) config.cap_events = true;
                if (std.mem.eql(u8, cap, "template")) config.cap_template = true;
                if (std.mem.eql(u8, cap, "routes")) config.cap_routes = true;
                if (std.mem.eql(u8, cap, "websocket")) config.cap_websocket = true;
            }
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printUsage();
            return;
        }
    }

    // 验证必填参数
    if (config.name.len == 0) {
        std.debug.print("错误: 必须指定插件名称 (--name=XXX)\n\n", .{});
        printUsage();
        return;
    }

    // 生成插件代码
    try generatePlugin(allocator, config);
}

/// 生成插件代码
fn generatePlugin(allocator: std.mem.Allocator, config: PluginConfig) !void {
    std.debug.print("开始生成插件: {s}\n", .{config.name});

    // 转换插件名为文件名（小写+下划线）
    const file_name = try toSnakeCase(allocator, config.name);
    defer allocator.free(file_name);

    // 构建输出路径
    const output_path = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}_plugin.zig",
        .{ config.output_dir, file_name },
    );
    defer allocator.free(output_path);

    // 替换模板占位符
    var content = std.ArrayList(u8).init(allocator);
    defer content.deinit();

    // 获取当前时间
    const timestamp = std.time.timestamp();
    var time_buf: [32]u8 = undefined;
    const time_str = std.fmt.bufPrint(&time_buf, "{d}", .{timestamp}) catch "unknown";

    // 替换模板内容
    const template = TEMPLATE;

    // 逐个替换占位符
    const replacements = [_]struct { from: []const u8, to: []const u8 }{
        .{ .from = "{{PLUGIN_NAME}}", .to = config.name },
        .{ .from = "{{DESCRIPTION}}", .to = config.description },
        .{ .from = "{{AUTHOR}}", .to = config.author },
        .{ .from = "{{CREATE_TIME}}", .to = time_str },
        .{ .from = "{{CAP_HTTP}}", .to = if (config.cap_http) "true" else "false" },
        .{ .from = "{{CAP_MIDDLEWARE}}", .to = if (config.cap_middleware) "true" else "false" },
        .{ .from = "{{CAP_SCHEDULER}}", .to = if (config.cap_scheduler) "true" else "false" },
        .{ .from = "{{CAP_DB_HOOKS}}", .to = if (config.cap_db_hooks) "true" else "false" },
        .{ .from = "{{CAP_EVENTS}}", .to = if (config.cap_events) "true" else "false" },
        .{ .from = "{{CAP_TEMPLATE}}", .to = if (config.cap_template) "true" else "false" },
        .{ .from = "{{CAP_ROUTES}}", .to = if (config.cap_routes) "true" else "false" },
        .{ .from = "{{CAP_WEBSOCKET}}", .to = if (config.cap_websocket) "true" else "false" },
    };

    var result = try allocator.dupe(u8, template);
    defer allocator.free(result);

    for (replacements) |r| {
        const new_result = try replaceAll(allocator, result, r.from, r.to);
        allocator.free(result);
        result = new_result;
    }

    // 确保输出目录存在
    std.fs.cwd().makeDir(config.output_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    // 写入文件
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(result);

    std.debug.print("插件代码已生成: {s}\n", .{output_path});
    std.debug.print("\n下一步:\n", .{});
    std.debug.print("  1. 编辑 {s} 添加业务逻辑\n", .{output_path});
    std.debug.print("  2. 在 build.zig 中添加动态库构建目标\n", .{});
    std.debug.print("  3. 运行 zig build 编译插件\n", .{});
}

/// 字符串替换
fn replaceAll(allocator: std.mem.Allocator, input: []const u8, from: []const u8, to: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    var i: usize = 0;

    while (i < input.len) {
        if (i + from.len <= input.len and std.mem.eql(u8, input[i..][0..from.len], from)) {
            try result.appendSlice(to);
            i += from.len;
        } else {
            try result.append(input[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice();
}

/// 转换为蛇形命名
fn toSnakeCase(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);

    for (input, 0..) |c, i| {
        if (c >= 'A' and c <= 'Z') {
            if (i > 0) try result.append('_');
            try result.append(c + 32);
        } else {
            try result.append(c);
        }
    }

    return result.toOwnedSlice();
}

/// 打印使用说明
fn printUsage() void {
    std.debug.print(
        \\ZigCMS 插件代码生成器
        \\
        \\用法:
        \\  zig build plugin-gen -- [选项]
        \\
        \\选项:
        \\  --name=NAME       插件名称（必填，PascalCase）
        \\  --desc=DESC       插件描述（默认：自动生成的插件）
        \\  --author=AUTHOR   作者名称（默认：ZigCMS）
        \\  --output=DIR      输出目录（默认：plugins）
        \\  --caps=CAPS       能力列表（逗号分隔）
        \\  --help, -h        显示此帮助
        \\
        \\能力选项 (--caps):
        \\  http        HTTP 请求处理
        \\  middleware  中间件支持
        \\  scheduler   定时任务
        \\  db          数据库钩子
        \\  events      事件监听
        \\  template    模板扩展
        \\  routes      自定义路由
        \\  websocket   WebSocket 支持
        \\
        \\示例:
        \\  zig build plugin-gen -- --name=MyPlugin --desc="我的插件" --caps=http,routes
        \\
    , .{});
}
