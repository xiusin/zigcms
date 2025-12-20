//! 共享层入口文件
//!
//! 职责：
//! - 提供跨层共享的工具函数
//! - 定义通用类型和常量
//! - 提供基础原语和辅助功能
//! - 不包含业务逻辑

const std = @import("std");

// 共享工具
pub const utils = @import("../shared/utils/strings.zig"); // 作为示例，实际可能需要统一的 utils 导出

// 共享原语
pub const primitives = @import("../shared/primitives/global.zig");

/// 共享层配置
pub const SharedConfig = struct {
    // 通用配置参数
};

/// 共享层初始化函数
pub fn init(allocator: std.mem.Allocator, config: SharedConfig) !void {
    _ = config;
    // 初始化全局模块（包括数据库连接和日志器）
    primitives.init(allocator);
    primitives.logger.info("共享层初始化完成", .{});
}

/// 共享层清理函数
pub fn deinit() void {
    primitives.deinit();
}
