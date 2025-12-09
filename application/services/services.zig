//! 应用服务入口文件
//!
//! 职责：
//! - 实现业务用例和应用服务
//! - 协调领域对象执行业务逻辑
//! - 处理事务管理
//! - 提供应用级别的接口

const std = @import("std");

// 导入各种应用服务
pub const ServiceManager = @import("Services.zig").ServiceManager;

// 如果有具体的服务，可以在这里导入
// pub const ArticleService = @import("article_service.zig").ArticleService;
// pub const UserService = @import("user_service.zig").UserService;

// 导入基础设施层服务实现
// pub const DatabaseService = @import("../infrastructure/database/database.zig").DatabaseService;
// pub const CacheService = @import("../infrastructure/cache/cache.zig").CacheService;

/// 应用服务配置
pub const ServiceConfig = struct {
    // 服务相关配置
    enable_cache: bool = true,
    cache_ttl_seconds: u64 = 3600,
};