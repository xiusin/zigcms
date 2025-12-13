//! 插件系统服务 - 应用层插件管理接口
//!
//! 该服务提供：
//! - 插件加载/卸载/管理的统一接口
//! - 插件与主应用的桥接
//! - 插件安全控制
//! - 插件事件系统

const std = @import("std");
const PluginManager = @import("plugin_manager.zig").PluginManager;
const PluginError = @import("plugin_interface.zig").PluginError;
const PluginInfo = @import("plugin_interface.zig").PluginInfo;
const PluginCapabilities = @import("plugin_interface.zig").PluginCapabilities;

pub const PluginSystemService = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    plugin_manager: PluginManager,

    pub fn init(allocator: std.mem.Allocator) PluginSystemService {
        return .{
            .allocator = allocator,
            .plugin_manager = PluginManager.init(allocator),
        };
    }

    pub fn deinit(self: *PluginSystemService) void {
        self.plugin_manager.deinit();
    }

    /// 初始化插件系统
    pub fn startup(self: *PluginSystemService) !void {
        // 从预定义目录加载插件
        try self.loadSystemPlugins();
    }

    /// 关闭插件系统
    pub fn shutdown(self: *PluginSystemService) !void {
        // 停止所有插件
        try self.plugin_manager.stopAllPlugins();

        // 卸载所有插件
        try self.plugin_manager.unloadAllPlugins();
    }

    /// 加载系统插件
    fn loadSystemPlugins(self: *PluginSystemService) !void {
        // 从 plugins 目录加载所有插件
        const plugins_dir = "plugins";
        try self.plugin_manager.loadPluginsFromDirectory(plugins_dir);
    }

    /// 加载单个插件
    pub fn loadPlugin(self: *PluginSystemService, path: []const u8, name: ?[]const u8) !void {
        try self.plugin_manager.loadPlugin(path, name);
        std.debug.print("插件 {s} 已加载\n", .{name orelse std.fs.path.basename(path)});
    }

    /// 卸载插件
    pub fn unloadPlugin(self: *PluginSystemService, name: []const u8) !void {
        try self.plugin_manager.unloadPlugin(name);
        std.debug.print("插件 {s} 已卸载\n", .{name});
    }

    /// 启动插件
    pub fn startPlugin(self: *PluginSystemService, name: []const u8) !void {
        try self.plugin_manager.startPlugin(name);
        std.debug.print("插件 {s} 已启动\n", .{name});
    }

    /// 停止插件
    pub fn stopPlugin(self: *PluginSystemService, name: []const u8) !void {
        try self.plugin_manager.stopPlugin(name);
        std.debug.print("插件 {s} 已停止\n", .{name});
    }

    /// 重新加载插件（热重载）
    pub fn reloadPlugin(self: *PluginSystemService, name: []const u8) !void {
        try self.plugin_manager.reloadPlugin(name);
        std.debug.print("插件 {s} 已重新加载\n", .{name});
    }

    /// 获取插件信息
    pub fn getPluginInfo(self: *PluginSystemService, name: []const u8) !PluginInfo {
        return try self.plugin_manager.getPluginInfo(name);
    }

    /// 获取插件能力
    pub fn getPluginCapabilities(self: *PluginSystemService, name: []const u8) !PluginCapabilities {
        return try self.plugin_manager.getPluginCapabilities(name);
    }

    /// 检查插件是否运行中
    pub fn isPluginRunning(self: *PluginSystemService, name: []const u8) bool {
        return self.plugin_manager.isPluginRunning(name);
    }

    /// 获取插件状态
    pub fn getPluginStatus(self: *PluginSystemService, name: []const u8) !struct {
        loaded: bool,
        initialized: bool,
        running: bool,
        capabilities: PluginCapabilities,
    } {
        return try self.plugin_manager.getPluginStatus(name);
    }

    /// 获取所有插件名称
    pub fn getAllPluginNames(self: *PluginSystemService) ![][]const u8 {
        return try self.plugin_manager.getPluginNames();
    }

    /// 安全沙箱检查 - 验证插件是否符合安全要求
    pub fn verifyPluginSafety(self: *PluginSystemService, path: []const u8) !bool {
        _ = self;
        _ = path;
        // 在实际实现中，这里会进行安全性检查
        // 例如：签名验证、权限检查、沙箱限制等
        return true; // 简化实现
    }

    /// 生成插件加载报告
    pub fn generateReport(self: *PluginSystemService) ![]u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        defer result.deinit();

        try result.writer().print("=== 插件系统报告 ===\n", .{});

        const plugin_names = try self.getAllPluginNames();
        defer self.allocator.free(plugin_names);

        for (plugin_names) |name| {
            const status = self.getPluginStatus(name) catch continue;
            const info = self.getPluginInfo(name) catch continue;

            try result.writer().print("插件: {s}\n", .{name});
            try result.writer().print("  名称: {s}\n", .{info.name});
            try result.writer().print("  版本: {s}\n", .{info.version});
            try result.writer().print("  描述: {s}\n", .{info.description});
            try result.writer().print("  作者: {s}\n", .{info.author});
            try result.writer().print("  许可证: {s}\n", .{info.license});
            try result.writer().print("  状态: ", .{});
            if (status.loaded) {
                try result.writer().print("已加载", .{});
                if (status.initialized) try result.writer().print(", 已初始化", .{});
                if (status.running) try result.writer().print(", 运行中", .{});
            } else {
                try result.writer().print("未加载", .{});
            }
            try result.writer().print("\n", .{});

            // 显示插件能力
            const caps = status.capabilities;
            try result.writer().print("  能力: ", .{});
            var cap_count: u32 = 0;
            if (caps.http_handlers) {
                try result.writer().print("HTTP,", .{});
                cap_count += 1;
            }
            if (caps.database_drivers) {
                try result.writer().print("数据库,", .{});
                cap_count += 1;
            }
            if (caps.authentication) {
                try result.writer().print("认证,", .{});
                cap_count += 1;
            }
            if (caps.middleware) {
                try result.writer().print("中间件,", .{});
                cap_count += 1;
            }
            if (caps.event_listeners) {
                try result.writer().print("事件,", .{});
                cap_count += 1;
            }
            if (caps.scheduled_tasks) {
                try result.writer().print("任务,", .{});
                cap_count += 1;
            }
            if (caps.custom_routes) {
                try result.writer().print("路由,", .{});
                cap_count += 1;
            }
            if (caps.file_processors) {
                try result.writer().print("文件,", .{});
                cap_count += 1;
            }
            if (caps.cache_providers) {
                try result.writer().print("缓存,", .{});
                cap_count += 1;
            }
            if (caps.storage_backends) {
                try result.writer().print("存储,", .{});
                cap_count += 1;
            }
            if (caps.encryption) {
                try result.writer().print("加密,", .{});
                cap_count += 1;
            }
            if (caps.logging) {
                try result.writer().print("日志,", .{});
                cap_count += 1;
            }

            if (cap_count == 0) {
                try result.writer().print("无", .{});
            } else {
                // 移除最后的逗号（通过截断）
                if (result.items.len > 0 and result.items[result.items.len - 1] == ',') {
                    _ = result.pop();
                }
            }
            try result.writer().print("\n", .{});
            try result.writer().print("\n", .{});
        }

        return result.toOwnedSlice();
    }

    /// 获取插件系统统计信息
    pub fn getStatistics(self: *PluginSystemService) !struct {
        total_plugins: usize,
        running_plugins: usize,
        loaded_plugins: usize,
    } {
        const plugin_names = try self.getAllPluginNames();
        defer self.allocator.free(plugin_names);

        var loaded_count: usize = 0;
        var running_count: usize = 0;

        for (plugin_names) |name| {
            const status = self.getPluginStatus(name) catch continue;
            if (status.loaded) loaded_count += 1;
            if (status.running) running_count += 1;
        }

        return .{
            .total_plugins = plugin_names.len,
            .loaded_plugins = loaded_count,
            .running_plugins = running_count,
        };
    }

    /// 启动所有插件
    pub fn startAllPlugins(self: *PluginSystemService) !void {
        try self.plugin_manager.startAllPlugins();
        std.debug.print("所有插件已启动\n", .{});
    }

    /// 停止所有插件
    pub fn stopAllPlugins(self: *PluginSystemService) !void {
        try self.plugin_manager.stopAllPlugins();
        std.debug.print("所有插件已停止\n", .{});
    }

    /// 安全卸载所有插件
    pub fn safeUnloadAllPlugins(self: *PluginSystemService) !void {
        // 先停止所有插件
        try self.stopAllPlugins();

        // 再卸载所有插件
        try self.plugin_manager.unloadAllPlugins();
        std.debug.print("所有插件已安全卸载\n", .{});
    }

    /// 检查插件兼容性
    pub fn checkPluginCompatibility(self: *PluginSystemService, plugin_name: []const u8) !bool {
        _ = self;
        _ = plugin_name;
        // 在实际实现中，这里会检查插件与当前系统的兼容性
        return true; // 简化实现
    }

    /// 获取插件文件校验和
    pub fn getPluginChecksum(self: *PluginSystemService, name: []const u8) ![]u8 {
        const path = self.plugin_manager.plugin_paths.get(name) orelse return PluginError.InvalidPlugin;

        // 读取文件并计算校验和
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, std.math.maxInt(usize));
        defer self.allocator.free(content);

        // 使用简单的哈希算法计算校验和
        const hash = std.hash.Wyhash.hash(0, content);
        return try std.fmt.alloc(self.allocator, "{X}", .{hash});
    }

    /// 验证插件文件完整性
    pub fn verifyPluginIntegrity(self: *PluginSystemService, name: []const u8, checksum: []const u8) !bool {
        const calculated_checksum = try self.getPluginChecksum(name);
        defer self.allocator.free(calculated_checksum);

        return std.mem.eql(u8, calculated_checksum, checksum);
    }
};

test "PluginSystemService basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var service = PluginSystemService.init(allocator);
    defer service.deinit();

    // 测试基本功能
    try std.testing.expect(service.plugin_manager.plugins.count() == 0);

    std.debug.print("PluginSystemService interface defined correctly\n", .{});
}
