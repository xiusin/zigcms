//! 应用层入口文件 (Application Layer)
//!
//! ZigCMS 应用层负责编排业务用例，协调领域对象和基础设施服务。
//! 该层是连接 API 层和领域层的桥梁，处理事务边界和数据转换。
//!
//! ## 职责
//! - 定义业务用例和应用服务
//! - 协调领域对象执行业务逻辑
//! - 处理事务管理和边界
//! - 提供应用级别的接口（DTO 转换、验证等）
//!
//! ## 模块结构
//!
//! - `usecases`: 业务用例（用户注册、文章发布等）
//! - `services`: 应用服务集合
//!   - `manager`: 服务管理器
//!   - `orm`: 对象关系映射
//!   - `cache`: 缓存服务
//!   - `logger`: 日志服务
//!   - `validator`: 数据验证服务
//!
//! ## 使用示例
//! ```zig
//! const app = @import("application/mod.zig");
//!
//! // 使用服务管理器
//! var manager = try app.services.manager.init(allocator);
//! defer manager.deinit();
//!
//! // 使用 ORM 服务
//! const User = app.services.orm.Model(UserEntity);
//! const users = try User.all();
//!
//! // 使用缓存服务
//! try app.services.cache.set("key", "value", 3600);
//! ```
//!
//! ## 依赖规则
//! - 应用层依赖领域层和共享层
//! - 不直接依赖基础设施层的具体实现
//! - 通过接口与基础设施层交互

const std = @import("std");
const logger = @import("services/logger/logger.zig");

// ============================================================================
// 公共 API 导出
// ============================================================================

/// 业务用例模块
/// 定义具体的业务流程，如用户注册、登录、内容发布等。
/// 用例协调领域服务和基础设施服务完成业务目标。
pub const usecases = @import("usecases/mod.zig");

/// 应用服务模块
///
/// 提供应用层的通用功能服务，包括 ORM、缓存、日志、验证等。
/// 这些服务被用例和控制器使用。
pub const services = struct {
    /// 服务管理器 - 统一管理服务生命周期
    pub const manager = @import("services/mod.zig").ServiceManager;

    /// ORM 服务 - 对象关系映射
    pub const orm = @import("services/orm/orm.zig");

    /// 缓存服务 - 数据缓存
    pub const cache = @import("services/cache/cache.zig");

    /// 日志服务 - 统一日志记录
    pub const logger = @import("services/logger/logger.zig");

    /// 验证服务 - 数据验证
    pub const validator = @import("services/validator/validator.zig");
};

// ============================================================================
// 层配置
// ============================================================================

/// 应用层配置
///
/// 控制应用层的行为，如缓存策略、插件系统、事件系统等。
pub const AppConfig = struct {
    /// 是否启用缓存
    enable_cache: bool = true,
    /// 缓存默认 TTL（秒）
    cache_ttl_seconds: u64 = 3600,
    /// 最大并发任务数
    max_concurrent_tasks: u32 = 100,

    /// 是否启用插件系统
    enable_plugins: bool = true,
    /// 插件目录
    plugin_directory: []const u8 = "plugins",

    /// 是否启用事件系统
    enable_events: bool = true,
    /// 事件队列大小
    event_queue_size: u32 = 1000,
};

// ============================================================================
// 生命周期管理
// ============================================================================

/// 初始化应用层
///
/// 在应用程序启动时调用，初始化应用层组件。
///
/// ## 参数
/// - `allocator`: 内存分配器
/// - `config`: 应用层配置
pub fn init(allocator: std.mem.Allocator, config: AppConfig) !void {
    _ = allocator;
    _ = config;

    std.debug.print("✅ 应用层初始化完成\n", .{});

    // 初始化用例模块
    _ = usecases;

    // 初始化服务
    _ = services;
}

/// 清理应用层
///
/// 在应用程序关闭时调用，释放应用层资源。
pub fn deinit() void {
    std.debug.print("👋 应用层已清理\n", .{});
}
