//! API 层入口文件 (API Layer)
//!
//! ZigCMS API 层是系统的最外层，负责处理 HTTP 请求和响应。
//! 该层将外部请求转换为应用层可以处理的格式，并将结果返回给客户端。
//!
//! ## 职责
//! - 处理 HTTP 请求路由
//! - 请求参数验证和转换
//! - 响应格式化和序列化
//! - 中间件处理（认证、日志、CORS 等）
//!
//! ## 模块结构
//! - `controllers`: HTTP 控制器（处理具体的 API 端点）
//! - `dto`: 数据传输对象（请求/响应数据结构）
//! - `middleware`: 中间件（认证、日志、错误处理等）
//!
//! ## 使用示例
//! ```zig
//! const api = @import("api/Api.zig");
//!
//! // 初始化 API 层
//! try api.init(allocator, .{
//!     .host = "127.0.0.1",
//!     .port = 8080,
//! });
//!
//! // 使用控制器
//! const LoginController = api.controllers.auth.Login;
//!
//! // 使用 DTO
//! const UserLoginDto = api.dto.user.Login;
//! ```
//!
//! ## 依赖规则
//! - API 层依赖应用层（调用用例和服务）
//! - 不直接依赖领域层或基础设施层
//! - 通过应用层间接访问业务逻辑

const std = @import("std");
const logger = @import("../application/services/logger/logger.zig");

// ============================================================================
// 公共 API 导出
// ============================================================================

/// HTTP 控制器
///
/// 按功能分组的控制器集合，处理各种 API 端点。
/// 包括认证、管理、CMS、会员等功能模块。
pub const controllers = @import("controllers/mod.zig");

/// 数据传输对象 (DTO)
///
/// 定义 API 请求和响应的数据结构。
/// DTO 用于在 API 层和应用层之间传递数据。
pub const dto = @import("dto/mod.zig");

/// 中间件
///
/// 提供请求处理管道中的中间件功能。
/// 包括认证、日志、CORS、错误处理等。
pub const middleware = @import("middleware");

// ============================================================================
// 层配置
// ============================================================================

/// API 服务器配置
///
/// 配置 HTTP 服务器的运行参数。
pub const ServerConfig = struct {
    /// 监听地址
    host: []const u8 = "127.0.0.1",
    /// 监听端口
    port: u16 = 3000,
    /// 最大客户端连接数
    max_clients: u32 = 10000,
    /// 请求超时时间（秒）
    timeout: u32 = 30,
    /// 静态资源目录
    public_folder: []const u8 = "resources",
};

// ============================================================================
// 生命周期管理
// ============================================================================

/// 初始化 API 层
///
/// 在应用程序启动时调用，初始化 API 层组件。
///
/// ## 参数
/// - `allocator`: 内存分配器
/// - `config`: API 服务器配置
pub fn init(allocator: std.mem.Allocator, config: ServerConfig) !void {
    _ = allocator;
    // 初始化 API 层组件
    logger.info("API 层初始化完成，配置: host={s}, port={}, max_clients={}", .{ config.host, config.port, config.max_clients });
}
