//! 插件代码生成器 - 根据配置自动生成插件代码框架
//!
//! 本工具用于快速生成 ZigCMS 插件的基础代码结构，
//! 支持配置插件能力（HTTP、中间件、调度器等）。
//!
//! ## 使用方式
//! ```
//! zig build plugin-gen -- --name=MyPlugin
//! zig build plugin-gen -- --name=AuthPlugin --caps=http,middleware
//! zig build plugin-gen -- --help
//! ```

const std = @import("std");
const base = @import("base");

const Command = base.Command;
const CommandArgs = base.CommandArgs;
const OptionDef = base.OptionDef;

/// 插件生成命令定义
pub const command = Command{
    .name = "plugin-gen",
    .description = "插件代码生成器 - 根据配置自动生成插件代码框架",
    .usage = "zig build plugin-gen -- --name=<插件名> [选项]",
    .options = &[_]OptionDef{
        .{
            .name = "name",
            .short = 'n',
            .description = "插件名称（PascalCase，如 MyPlugin）",
            .required = true,
        },
        .{
            .name = "desc",
            .short = 'd',
            .description = "插件描述",
            .default = "A ZigCMS plugin",
        },
        .{
            .name = "author",
            .short = 'a',
            .description = "作者名称",
            .default = "Anonymous",
        },
        .{
            .name = "version",
            .short = 'v',
            .description = "插件版本",
            .default = "0.1.0",
        },
        .{
            .name = "caps",
            .short = 'c',
            .description = "能力列表（逗号分隔）: http, middleware, scheduler, storage",
        },
        .{
            .name = "help",
            .short = 'h',
            .description = "显示帮助信息",
            .is_flag = true,
        },
    },
    .examples = &[_][]const u8{
        "zig build plugin-gen -- --name=MyPlugin",
        "zig build plugin-gen -- --name=AuthPlugin --author=\"张三\" --desc=\"认证插件\"",
        "zig build plugin-gen -- --name=CachePlugin --caps=http,middleware",
        "zig build plugin-gen -- --name=TaskPlugin --caps=scheduler",
    },
};

/// 插件能力
const Capability = enum {
    http,
    middleware,
    scheduler,
    storage,
};

/// 运行插件生成命令
pub fn run(allocator: std.mem.Allocator) !void {
    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    // 跳过程序名
    _ = args_iter.skip();

    var args = try base.parseArgs(allocator, &args_iter);
    defer args.deinit();

    // 检查帮助标志
    if (args.hasFlag("help") or args.hasFlag("h")) {
        command.showHelp();
        return;
    }

    // 获取插件名称
    const name = args.getOption("name") orelse args.getOption("n") orelse {
        command.showError("缺少必填参数: --name");
        return;
    };

    // 获取其他参数
    const desc = args.getOptionOr("desc", "A ZigCMS plugin");
    const author = args.getOptionOr("author", "Anonymous");
    const version = args.getOptionOr("version", "0.1.0");

    // 解析能力列表
    var capabilities = std.ArrayListUnmanaged(Capability){};
    defer capabilities.deinit(allocator);

    if (args.getOption("caps") orelse args.getOption("c")) |caps_str| {
        var iter = std.mem.splitScalar(u8, caps_str, ',');
        while (iter.next()) |cap| {
            const trimmed = std.mem.trim(u8, cap, " ");
            if (std.mem.eql(u8, trimmed, "http")) {
                try capabilities.append(allocator, .http);
            } else if (std.mem.eql(u8, trimmed, "middleware")) {
                try capabilities.append(allocator, .middleware);
            } else if (std.mem.eql(u8, trimmed, "scheduler")) {
                try capabilities.append(allocator, .scheduler);
            } else if (std.mem.eql(u8, trimmed, "storage")) {
                try capabilities.append(allocator, .storage);
            }
        }
    }

    Command.showInfo("开始生成插件代码...");

    // 生成插件文件
    try generatePlugin(allocator, name, desc, author, version, capabilities.items);

    Command.showSuccess("插件代码生成完成！");
}

/// 生成插件文件
fn generatePlugin(
    allocator: std.mem.Allocator,
    name: []const u8,
    desc: []const u8,
    author: []const u8,
    version: []const u8,
    capabilities: []const Capability,
) !void {
    const snake_name = try toSnakeCase(allocator, name);
    defer allocator.free(snake_name);

    const path = try std.fmt.allocPrint(allocator, "plugins/{s}_plugin.zig", .{snake_name});
    defer allocator.free(path);

    // 检查文件是否已存在
    if (base.fileExists(path)) {
        const warning_msg = try std.fmt.allocPrint(allocator, "文件已存在: {s}，跳过生成", .{path});
        defer allocator.free(warning_msg);
        Command.showWarning(warning_msg);
        return;
    }

    var content = std.ArrayListUnmanaged(u8){};
    defer content.deinit(allocator);

    const writer = content.writer(allocator);

    // 写入文件头
    try writer.print(
        \\//! {s} - {s}
        \\//!
        \\//! 作者: {s}
        \\//! 版本: {s}
        \\//!
        \\//! 自动生成的插件代码框架
        \\
        \\const std = @import("std");
        \\const PluginInterface = @import("plugin_interface.zig").PluginInterface;
        \\
        \\/// {s} 插件
        \\pub const {s}Plugin = struct {{
        \\    const Self = @This();
        \\
        \\    allocator: std.mem.Allocator,
        \\    initialized: bool = false,
        \\
        \\    /// 插件元数据
        \\    pub const metadata = .{{
        \\        .name = "{s}",
        \\        .version = "{s}",
        \\        .description = "{s}",
        \\        .author = "{s}",
        \\    }};
        \\
        \\    /// 创建插件实例
        \\    pub fn init(allocator: std.mem.Allocator) Self {{
        \\        return .{{
        \\            .allocator = allocator,
        \\            .initialized = false,
        \\        }};
        \\    }}
        \\
        \\    /// 清理插件资源
        \\    pub fn deinit(self: *Self) void {{
        \\        if (self.initialized) {{
        \\            // TODO: 清理插件资源
        \\            self.initialized = false;
        \\        }}
        \\    }}
        \\
        \\    /// 启动插件
        \\    pub fn start(self: *Self) !void {{
        \\        if (self.initialized) return;
        \\
        \\        std.log.info("[{s}] 插件启动中...", .{{}});
        \\
        \\        // TODO: 初始化插件
        \\
        \\        self.initialized = true;
        \\        std.log.info("[{s}] 插件启动完成", .{{}});
        \\    }}
        \\
        \\    /// 停止插件
        \\    pub fn stop(self: *Self) void {{
        \\        if (!self.initialized) return;
        \\
        \\        std.log.info("[{s}] 插件停止中...", .{{}});
        \\
        \\        // TODO: 停止插件服务
        \\
        \\        self.initialized = false;
        \\        std.log.info("[{s}] 插件已停止", .{{}});
        \\    }}
        \\
    , .{ name, desc, author, version, name, name, name, version, desc, author, name, name, name, name });

    // 根据能力生成对应的方法
    for (capabilities) |cap| {
        switch (cap) {
            .http => {
                try writer.writeAll(
                    \\
                    \\    // ========================================
                    \\    // HTTP 能力
                    \\    // ========================================
                    \\
                    \\    /// 注册 HTTP 路由
                    \\    pub fn registerRoutes(self: *Self, router: anytype) !void {
                    \\        _ = self;
                    \\        // TODO: 注册插件路由
                    \\        // 例如: router.get("/api/plugin/example", handleExample);
                    \\        _ = router;
                    \\    }
                    \\
                    \\    /// 示例 HTTP 处理函数
                    \\    fn handleExample(req: anytype) !void {
                    \\        _ = req;
                    \\        // TODO: 实现处理逻辑
                    \\    }
                    \\
                );
            },
            .middleware => {
                try writer.writeAll(
                    \\
                    \\    // ========================================
                    \\    // 中间件能力
                    \\    // ========================================
                    \\
                    \\    /// 中间件处理函数
                    \\    pub fn middleware(self: *Self, req: anytype, res: anytype) !bool {
                    \\        _ = self;
                    \\        _ = req;
                    \\        _ = res;
                    \\        // TODO: 实现中间件逻辑
                    \\        // 返回 true 继续处理，false 中断请求
                    \\        return true;
                    \\    }
                    \\
                );
            },
            .scheduler => {
                try writer.writeAll(
                    \\
                    \\    // ========================================
                    \\    // 调度器能力
                    \\    // ========================================
                    \\
                    \\    /// 定时任务
                    \\    pub fn scheduledTask(self: *Self) !void {
                    \\        _ = self;
                    \\        // TODO: 实现定时任务逻辑
                    \\    }
                    \\
                    \\    /// 获取调度间隔（毫秒）
                    \\    pub fn getScheduleInterval(_: *Self) u64 {
                    \\        return 60 * 1000; // 默认 1 分钟
                    \\    }
                    \\
                );
            },
            .storage => {
                try writer.writeAll(
                    \\
                    \\    // ========================================
                    \\    // 存储能力
                    \\    // ========================================
                    \\
                    \\    /// 存储数据
                    \\    pub fn store(self: *Self, key: []const u8, value: []const u8) !void {
                    \\        _ = self;
                    \\        _ = key;
                    \\        _ = value;
                    \\        // TODO: 实现存储逻辑
                    \\    }
                    \\
                    \\    /// 读取数据
                    \\    pub fn retrieve(self: *Self, key: []const u8) !?[]const u8 {
                    \\        _ = self;
                    \\        _ = key;
                    \\        // TODO: 实现读取逻辑
                    \\        return null;
                    \\    }
                    \\
                    \\    /// 删除数据
                    \\    pub fn remove(self: *Self, key: []const u8) !void {
                    \\        _ = self;
                    \\        _ = key;
                    \\        // TODO: 实现删除逻辑
                    \\    }
                    \\
                );
            },
        }
    }

    // 写入接口实现
    try writer.writeAll(
        \\
        \\    // ========================================
        \\    // 插件接口实现
        \\    // ========================================
        \\
        \\    /// 获取插件接口
        \\    pub fn interface(self: *Self) PluginInterface {
        \\        return .{
        \\            .ptr = self,
        \\            .vtable = &.{
        \\                .getName = getName,
        \\                .getVersion = getVersion,
        \\                .start = startWrapper,
        \\                .stop = stopWrapper,
        \\            },
        \\        };
        \\    }
        \\
        \\    fn getName(_: *anyopaque) []const u8 {
        \\        return metadata.name;
        \\    }
        \\
        \\    fn getVersion(_: *anyopaque) []const u8 {
        \\        return metadata.version;
        \\    }
        \\
        \\    fn startWrapper(ptr: *anyopaque) void {
        \\        const self: *Self = @ptrCast(@alignCast(ptr));
        \\        self.start() catch |err| {
        \\            std.log.err("[{s}] 启动失败: {}", .{metadata.name, err});
        \\        };
        \\    }
        \\
        \\    fn stopWrapper(ptr: *anyopaque) void {
        \\        const self: *Self = @ptrCast(@alignCast(ptr));
        \\        self.stop();
        \\    }
        \\};
        \\
        \\// ========================================
        \\// 测试
        \\// ========================================
        \\
        \\test "plugin initialization" {
        \\    var plugin = @This().init(std.testing.allocator);
        \\    defer plugin.deinit();
        \\
        \\    try plugin.start();
        \\    try std.testing.expect(plugin.initialized);
        \\
        \\    plugin.stop();
        \\    try std.testing.expect(!plugin.initialized);
        \\}
        \\
    );

    try base.writeFile(path, content.items);
    
    const success_msg = try std.fmt.allocPrint(allocator, "生成插件: {s}", .{path});
    defer allocator.free(success_msg);
    Command.showSuccess(success_msg);

    // 显示能力信息
    if (capabilities.len > 0) {
        var caps_str_list = std.ArrayListUnmanaged(u8){};
        defer caps_str_list.deinit(allocator);

        for (capabilities, 0..) |cap, i| {
            if (i > 0) try caps_str_list.appendSlice(allocator, ", ");
            try caps_str_list.appendSlice(allocator, @tagName(cap));
        }

        const info_msg = try std.fmt.allocPrint(allocator, "已启用能力: {s}", .{caps_str_list.items});
        defer allocator.free(info_msg);
        Command.showInfo(info_msg);
    }
}

/// 转换为 snake_case
fn toSnakeCase(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    for (input, 0..) |c, i| {
        if (std.ascii.isUpper(c)) {
            if (i > 0) {
                try result.append(allocator, '_');
            }
            try result.append(allocator, std.ascii.toLower(c));
        } else {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    try run(gpa.allocator());
}
