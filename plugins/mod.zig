//! 插件系统模块入口
//!
//! 提供可插拔模块载入服务，支持：
//! - 动态加载/卸载共享库
//! - 线程安全的插件管理
//! - 完善的异常处理
//! - 内存安全保证
//! - 热重载能力

const std = @import("std");

// 导出核心组件
pub const PluginManager = @import("plugin_manager.zig").PluginManager;
pub const LoadedPlugin = @import("plugin_manager.zig").LoadedPlugin;

// 导出接口定义
pub const interface = @import("plugin_interface.zig");
pub const PluginCapabilities = interface.PluginCapabilities;
pub const PluginInfo = interface.PluginInfo;
pub const PluginState = interface.PluginState;
pub const PluginError = interface.PluginError;
pub const PluginVTable = interface.PluginVTable;
pub const PluginContext = interface.PluginContext;
pub const PLUGIN_API_VERSION = interface.PLUGIN_API_VERSION;

// 导出便捷函数
pub const getGlobalManager = @import("plugin_manager.zig").getGlobalManager;
pub const initGlobalManager = @import("plugin_manager.zig").initGlobalManager;
pub const deinitGlobalManager = @import("plugin_manager.zig").deinitGlobalManager;

/// 快速创建插件管理器
pub fn createManager(allocator: std.mem.Allocator, plugin_dir: []const u8) !PluginManager {
    return PluginManager.init(allocator, plugin_dir);
}

/// 插件开发辅助宏 - 生成标准导出函数
pub fn definePlugin(comptime T: type) type {
    return struct {
        var instance: ?T = null;

        /// 获取插件信息
        pub export fn plugin_get_info() *const PluginInfo {
            return &T.info;
        }

        /// 获取插件能力
        pub export fn plugin_get_capabilities() u32 {
            return T.capabilities.toBitmap();
        }

        /// 初始化插件
        pub export fn plugin_init() ?*anyopaque {
            instance = T.init() catch return null;
            return @ptrCast(&instance.?);
        }

        /// 清理插件
        pub export fn plugin_deinit(handle: ?*anyopaque) void {
            _ = handle;
            if (instance) |*inst| {
                inst.deinit();
                instance = null;
            }
        }

        /// 启动插件
        pub export fn plugin_start(handle: ?*anyopaque) bool {
            _ = handle;
            if (instance) |*inst| {
                if (@hasDecl(T, "start")) {
                    inst.start() catch return false;
                }
                return true;
            }
            return false;
        }

        /// 停止插件
        pub export fn plugin_stop(handle: ?*anyopaque) bool {
            _ = handle;
            if (instance) |*inst| {
                if (@hasDecl(T, "stop")) {
                    inst.stop() catch return false;
                }
                return true;
            }
            return false;
        }
    };
}

test "模块导出正确性" {
    try std.testing.expect(PLUGIN_API_VERSION == 1);
}
