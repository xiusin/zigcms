//! 日志模块
//!
//! 提供类似 Go zap 的高性能结构化日志功能。
//!
//! ## 功能特性
//!
//! - **多级别日志**：debug、info、warn、error、fatal
//! - **结构化日志**：支持字段附加
//! - **多种格式**：纯文本、JSON、彩色终端
//! - **多输出目标**：stderr、stdout、文件
//! - **高性能**：零分配日志（使用栈缓冲区）
//!
//! ## 快速开始
//!
//! ```zig
//! const logger = @import("services/logger/mod.zig");
//!
//! var log = logger.createLogger(allocator);
//! defer log.deinit();
//!
//! log.info("服务启动", .{});
//! log.warn("连接超时: {d}ms", .{timeout});
//! log.err("数据库错误: {s}", .{err_msg});
//! ```
//!
//! ## 结构化日志
//!
//! ```zig
//! // 附加字段
//! log.with(.{ .user_id = 123, .action = "login" }).info("用户登录", .{});
//!
//! // JSON 格式输出
//! var json_log = logger.createJsonLogger(allocator);
//! json_log.info("API 请求", .{});
//! // {"time":"2025-12-06T09:18:00","level":"INFO","msg":"API 请求"}
//! ```
//!
//! ## 输出到文件
//!
//! ```zig
//! var file_writer = try logger.FileWriter.init("app.log");
//! defer file_writer.deinit();
//!
//! var log = logger.createLogger(allocator);
//! try log.addWriter(file_writer.writer());
//! log.info("写入文件", .{});
//! ```
//!
//! ## 日志级别
//!
//! | 级别 | 说明 |
//! |------|------|
//! | debug | 调试信息，生产环境通常关闭 |
//! | info | 一般信息，默认级别 |
//! | warn | 警告信息，需要注意 |
//! | error | 错误信息，需要处理 |
//! | fatal | 致命错误，程序无法继续 |

const log = @import("logger.zig");

// 核心类型
pub const Logger = log.Logger;
pub const Level = log.Level;
pub const Format = log.Format;
pub const LoggerConfig = log.LoggerConfig;
pub const Field = log.Field;
pub const FieldValue = log.FieldValue;
pub const ScopedLogger = log.ScopedLogger;

// 输出类型
pub const Writer = log.Writer;
pub const StderrWriter = log.StderrWriter;
pub const StdoutWriter = log.StdoutWriter;
pub const FileWriter = log.FileWriter;
pub const RotatingFileWriter = log.RotatingFileWriter;
pub const MultiWriter = log.MultiWriter;

// 高性能异步写入
pub const AsyncWriter = log.AsyncWriter;
pub const BufferedFileWriter = log.BufferedFileWriter;

// 便捷函数
pub const createLogger = log.createLogger;
pub const createJsonLogger = log.createJsonLogger;
pub const createColoredLogger = log.createColoredLogger;
pub const setGlobalLogger = log.setGlobalLogger;
pub const getGlobalLogger = log.getGlobalLogger;

// 类似 std.log 的 API
pub const scoped = log.scoped;
pub const default = log.default;

/// 创建带模块名的日志器
pub fn createModuleLogger(allocator: @import("std").mem.Allocator, module: []const u8) Logger {
    return Logger.init(allocator, .{ .module_name = module });
}

/// 创建用于生产环境的日志器（JSON 格式）
pub fn createProductionLogger(allocator: @import("std").mem.Allocator, module: ?[]const u8) Logger {
    return Logger.init(allocator, .{
        .format = .json,
        .module_name = module,
        .level = .info,
    });
}

/// 创建用于开发环境的日志器（彩色格式）
pub fn createDevelopmentLogger(allocator: @import("std").mem.Allocator, module: ?[]const u8) Logger {
    return Logger.init(allocator, .{
        .format = .colored,
        .module_name = module,
        .level = .debug,
    });
}

test {
    _ = log;
}
