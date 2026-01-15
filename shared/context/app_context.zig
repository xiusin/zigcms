//! Application Context - 应用上下文
//!
//! 替代全局状态，使用显式依赖注入模式。
//! 将所有共享资源集中管理，通过上下文对象传递。
//!
//! ## 设计目标
//! - 消除全局可变状态
//! - 支持依赖注入和单元测试
//! - 明确资源所有权
//! - 线程安全的资源访问
//!
//! ## 使用示例
//! ```zig
//! var ctx = try AppContext.init(allocator, config);
//! defer ctx.deinit();
//!
//! const db = ctx.getDatabase();
//! const cache = try ctx.getCache();
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const sql = @import("../../application/services/sql/mod.zig");
const services = @import("../../application/services/mod.zig");
const DIContainer = @import("../di/container.zig").DIContainer;
const SystemConfig = @import("../config/system_config.zig").SystemConfig;
const logger = @import("../../application/services/logger/logger.zig");

/// 应用上下文 - 集中管理所有共享资源
///
/// 职责：
/// - 持有并管理数据库连接
/// - 持有服务管理器（缓存、插件系统等）
/// - 持有 DI 容器
/// - 提供线程安全的资源访问
///
/// 所有权：
/// - AppContext 拥有所有内部资源
/// - 调用者必须调用 deinit() 清理资源
/// - 提供的引用为借用，不可释放
pub const AppContext = struct {
    allocator: Allocator,
    config: *const SystemConfig,
    db: *sql.Database,
    service_manager: ?*services.ServiceManager,
    di_container: *DIContainer,
    logger: ?*logger.Logger,
    
    const Self = @This();
    
    /// 初始化应用上下文
    ///
    /// 参数：
    /// - allocator: 内存分配器
    /// - config: 系统配置（借用，外部管理生命周期）
    /// - db: 数据库连接（转移所有权）
    /// - di_container: DI容器（转移所有权）
    ///
    /// 返回：AppContext 指针（调用者拥有，必须调用 deinit）
    ///
    /// 注意：
    /// - db 和 di_container 的所有权转移给 AppContext
    /// - config 为借用引用，AppContext 不负责释放
    pub fn init(
        allocator: Allocator,
        config: *const SystemConfig,
        db: *sql.Database,
        di_container: *DIContainer,
    ) !*Self {
        const ctx = try allocator.create(Self);
        errdefer allocator.destroy(ctx);
        
        ctx.* = .{
            .allocator = allocator,
            .config = config,
            .db = db,
            .service_manager = null,
            .di_container = di_container,
            .logger = null,
        };
        
        return ctx;
    }
    
    /// 设置服务管理器
    ///
    /// 参数：
    /// - service_manager: 服务管理器（转移所有权）
    ///
    /// 注意：服务管理器的所有权转移给 AppContext
    pub fn setServiceManager(self: *Self, service_manager: *services.ServiceManager) void {
        self.service_manager = service_manager;
    }
    
    /// 设置日志器
    ///
    /// 参数：
    /// - log: 日志器（借用引用，外部管理生命周期）
    pub fn setLogger(self: *Self, log: *logger.Logger) void {
        self.logger = log;
    }
    
    /// 获取数据库连接
    ///
    /// 返回：数据库连接引用（借用，不可释放）
    pub fn getDatabase(self: *const Self) *sql.Database {
        return self.db;
    }
    
    /// 获取服务管理器
    ///
    /// 返回：服务管理器引用（借用，不可释放）
    /// 错误：如果服务管理器未初始化
    pub fn getServiceManager(self: *const Self) !*services.ServiceManager {
        return self.service_manager orelse error.ServiceManagerNotInitialized;
    }
    
    /// 获取 DI 容器
    ///
    /// 返回：DI 容器引用（借用，不可释放）
    pub fn getContainer(self: *const Self) *DIContainer {
        return self.di_container;
    }
    
    /// 获取配置
    ///
    /// 返回：系统配置引用（借用，不可释放）
    pub fn getConfig(self: *const Self) *const SystemConfig {
        return self.config;
    }
    
    /// 获取日志器
    ///
    /// 返回：日志器引用（借用，不可释放）
    /// 如果未设置则返回 null
    pub fn getLogger(self: *const Self) ?*logger.Logger {
        return self.logger;
    }
    
    /// 获取缓存服务
    ///
    /// 返回：缓存服务接口
    /// 错误：如果服务管理器未初始化
    pub fn getCache(self: *const Self) !@import("../../application/services/cache/contract.zig").CacheInterface {
        const sm = try self.getServiceManager();
        return sm.cache;
    }
    
    /// 释放资源
    ///
    /// 释放顺序（与初始化相反）：
    /// 1. 服务管理器（如果存在）
    /// 2. 数据库连接
    /// 3. DI 容器
    /// 4. AppContext 自身
    ///
    /// 注意：
    /// - 配置和日志器由外部管理，不在此释放
    /// - 此方法会销毁 AppContext 实例本身
    pub fn deinit(self: *Self) void {
        // 1. 清理服务管理器
        if (self.service_manager) |sm| {
            sm.deinit();
            self.allocator.destroy(sm);
            self.service_manager = null;
        }
        
        // 2. 清理数据库（AppContext 拥有所有权）
        self.db.deinit();
        self.allocator.destroy(self.db);
        
        // 3. 清理 DI 容器
        self.di_container.deinit();
        self.allocator.destroy(self.di_container);
        
        // 4. 销毁 AppContext 自身
        const allocator = self.allocator;
        allocator.destroy(self);
    }
};
