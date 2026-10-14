//! ZigCMS 根模块 - 库入口点
//!
//! 本模块是 ZigCMS 作为库使用时的入口点，导出所有公共 API。
//! 遵循整洁架构原则，将项目分为以下层次：
//!
//! ## 架构层次
//! - **API 层** (`api`): 处理 HTTP 请求和响应
//! - **应用层** (`application`): 协调业务流程和用例
//! - **领域层** (`domain`): 核心业务逻辑和模型
//! - **基础设施层** (`infrastructure`): 外部服务集成和实现
//! - **共享层** (`shared`): 跨层通用组件
//!
//! ## 使用示例
//!
//! ```zig
//! const zigcms = @import("zigcms");
//!
//! pub fn main() !void {
//!     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//!     defer _ = gpa.deinit();
//!     const allocator = gpa.allocator();
//!
//!     // 初始化系统
//!     try zigcms.initSystem(allocator, .{
//!         .api = .{ .port = 8080 },
//!     });
//!     defer zigcms.deinitSystem();
//!
//!     // 获取服务管理器
//!     if (zigcms.getServiceManager()) |sm| {
//!         // 使用服务...
//!     }
//! }
//! ```
//!
//! ## 公共 API
//! - `initSystem`: 初始化整个系统
//! - `deinitSystem`: 清理系统资源
//! - `getServiceManager`: 获取服务管理器
//! - `SystemConfig`: 系统配置结构体

const std = @import("std");
const logger = @import("src/application/services/logger/logger.zig");
const sql_orm = @import("src/application/services/sql/orm.zig");

// 用户服务相关导入
const UserService = @import("src/application/services/user_service.zig").UserService;
const UserRepository = @import("src/domain/repositories/user_repository.zig").UserRepository;
const SqliteUserRepository = @import("src/infrastructure/database/sqlite_user_repository.zig").SqliteUserRepository;

// 角色/敏感词仓储（MySQL ORM 实现）
const MysqlRoleRepository = @import("src/infrastructure/database/mysql_role_repository.zig").MysqlRoleRepository;
const MysqlSensitiveWordRepository = @import("src/infrastructure/database/mysql_sensitive_word_repository.zig").MysqlSensitiveWordRepository;
const role_repository_mod = @import("src/domain/repositories/role_repository.zig");
const sensitive_word_repository_mod = @import("src/domain/repositories/sensitive_word_repository.zig");
const RoleRepository = role_repository_mod.RoleRepository;
const SensitiveWordRepository = sensitive_word_repository_mod.SensitiveWordRepository;

// 认证服务导入
const AuthService = @import("src/application/services/auth_service.zig").AuthService;

// 缓存接口导入
const CacheInterface = @import("src/infrastructure/cache/contract.zig").CacheInterface;

// 安全服务导入
const CsrfProtection = @import("src/api/middleware/csrf_protection.zig").CsrfProtection;
const RateLimiter = @import("src/api/middleware/rate_limiter.zig").RateLimiter;
const RbacMiddleware = @import("src/api/middleware/rbac.zig").RbacMiddleware;

// ============================================================================
// 编译选项
// ============================================================================

/// 启用 MySQL 驱动
///
/// 告诉 interface.zig 使用真正的 MySQL 驱动而非存根。
pub const mysql_enabled = true;

// ============================================================================
// 层模块导出
// ============================================================================

/// API 层 - HTTP 请求处理
///
/// 包含控制器、DTO、中间件等 HTTP 相关组件。
pub const api = @import("src/api/Api.zig");

/// 应用层 - 业务用例编排
///
/// 包含用例、服务管理器、ORM、缓存等应用服务。
pub const application = @import("src/application/mod.zig");

/// 领域层 - 核心业务逻辑
///
/// 包含实体、领域服务、仓储接口等业务核心。
pub const domain = @import("src/domain/mod.zig");

/// 基础设施层 - 外部服务实现
///
/// 包含数据库、缓存、HTTP 客户端等外部服务实现。
pub const infrastructure = @import("src/infrastructure/mod.zig");

/// 核心层 - 统一基础设施
///
/// 包含 DI、错误处理、日志、配置、类型、工具、DDD 模式等核心组件。
pub const core = @import("src/core/mod.zig");

/// 共享层 - 通用组件（兼容层，建议使用 core）
///
/// 包含工具函数、类型定义、错误处理等跨层共享组件。
// shared 已合并到 core，保留别名以兼容旧代码
pub const shared = core;

/// SQL ORM 模块 - 数据库操作
///
/// 提供完整的多数据库 ORM 功能（MySQL/SQLite/PostgreSQL）。
pub const sql = @import("src/application/services/sql/mod.zig");

/// Redis 客户端模块 - 缓存和键值存储
///
/// 提供完整的 Redis 客户端功能，支持连接池、所有数据类型操作。
pub const redis = @import("src/infrastructure/redis/mod.zig");

/// 缓存驱动模块 - 缓存实现
///
/// 提供内存缓存、Redis缓存等驱动实现。
pub const cache_drivers = @import("src/infrastructure/cache_drivers.zig");

// ============================================================================
// 服务管理
// ============================================================================

/// 服务管理器类型
pub const ServiceManager = @import("src/application/services/mod.zig").ServiceManager;

// 全局服务实例
var service_manager: ?ServiceManager = null;
// 基础设施数据库连接（由 ServiceManager 管理生命周期）
var infrastructure_db: ?*sql_orm.Database = null;
// 服务实例将通过DI容器管理，不再使用全局变量
// 这些变量已被移除，服务生命周期由DI容器统一管理

// ============================================================================
// 配置
// ============================================================================

/// 配置加载器
pub const ConfigLoader = shared.config.ConfigLoader;

/// 系统主配置（从文件加载）
///
/// 包含所有层的配置选项，对应 configs/ 目录下的 TOML 文件。
pub const FileSystemConfig = shared.config.SystemConfig;

/// 系统主配置
///
/// 包含所有层的配置选项。
pub const SystemConfig = shared.config.SystemConfig;

// 全局配置加载器（需要清理）
var global_config_loader: ?ConfigLoader = null;

// ============================================================================
// 公共 API
// ============================================================================

/// 获取全局服务管理器
///
/// 返回服务管理器的指针，如果系统未初始化则返回 null。
pub fn getServiceManager() ?*ServiceManager {
    if (service_manager) |*sm| return sm;
    return null;
}

/// 从配置文件加载并验证配置
///
/// 从 configs/ 目录加载 TOML 配置文件，应用环境变量覆盖，
/// 并验证所有必需字段。
///
/// ## 参数
/// - `allocator`: 内存分配器
/// - `config_dir`: 配置文件目录（默认 "configs"）
///
/// ## 返回
/// 返回加载并验证后的配置
///
/// ## 错误
/// - ParseError: TOML 解析失败
/// - InvalidValue: 配置值无效
/// - MissingRequiredField: 必需字段缺失
pub fn loadConfigFromFiles(allocator: std.mem.Allocator, config_dir: []const u8) !FileSystemConfig {
    // 清理之前的配置加载器
    if (global_config_loader) |*loader| {
        loader.deinit();
    }

    // 创建新的配置加载器
    global_config_loader = ConfigLoader.init(allocator, config_dir);
    var loader = &global_config_loader.?;

    // 加载配置
    const file_config = try loader.loadAll();

    // 验证配置
    try loader.validate(&file_config);

    return file_config;
}

/// 从配置文件加载配置并转换为 SystemConfig
///
/// 这是一个便捷函数，加载文件配置并转换为系统使用的 SystemConfig 格式。
/// 配置加载器已自动处理环境变量覆盖。
///
/// ## 参数
/// - `allocator`: 内存分配器
///
/// ## 返回
/// 返回可用于 initSystem 的 SystemConfig
pub fn loadSystemConfig(allocator: std.mem.Allocator) !SystemConfig {
    const file_config = try loadConfigFromFiles(allocator, "configs");

    const dup = struct {
        fn slice(allocator_: std.mem.Allocator, source: []const u8) ![]const u8 {
            return allocator_.dupe(u8, source);
        }
    };

    const api_host = try dup.slice(allocator, file_config.api.host);
    errdefer allocator.free(api_host);
    const api_public_folder = try dup.slice(allocator, file_config.api.public_folder);
    errdefer allocator.free(api_public_folder);
    const app_plugin_dir = try dup.slice(allocator, file_config.app.plugin_directory);
    errdefer allocator.free(app_plugin_dir);
    const infra_db_host = try dup.slice(allocator, file_config.infra.db_host);
    errdefer allocator.free(infra_db_host);
    const infra_db_name = try dup.slice(allocator, file_config.infra.db_name);
    errdefer allocator.free(infra_db_name);
    const infra_db_user = try dup.slice(allocator, file_config.infra.db_user);
    errdefer allocator.free(infra_db_user);
    const infra_db_password = try dup.slice(allocator, file_config.infra.db_password);
    errdefer allocator.free(infra_db_password);
    const infra_cache_host = try dup.slice(allocator, file_config.infra.cache_host);
    errdefer allocator.free(infra_cache_host);
    const infra_cache_password = if (file_config.infra.cache_password) |pwd| blk: {
        const copy = try dup.slice(allocator, pwd);
        errdefer allocator.free(copy);
        break :blk copy;
    } else null;

    // 将文件配置映射到系统配置（防腐层转换）
    const system_config = SystemConfig{
        .api = .{
            .host = api_host,
            .port = file_config.api.port,
            .max_clients = file_config.api.max_clients,
            .timeout = file_config.api.timeout,
            .public_folder = api_public_folder,
        },
        .app = .{
            .enable_cache = file_config.app.enable_cache,
            .cache_ttl_seconds = file_config.app.cache_ttl_seconds,
            .max_concurrent_tasks = file_config.app.max_concurrent_tasks,
            .enable_plugins = file_config.app.enable_plugins,
            .plugin_directory = app_plugin_dir,
        },
        .domain = .{
            .validate_models = file_config.domain.validate_models,
            .enforce_business_rules = file_config.domain.enforce_business_rules,
        },
        .infra = .{
            .db_engine = file_config.infra.db_engine,
            .db_host = infra_db_host,
            .db_port = file_config.infra.db_port,
            .db_name = infra_db_name,
            .db_user = infra_db_user,
            .db_password = infra_db_password,
            .db_pool_size = file_config.infra.db_pool_size,
            .cache_enabled = file_config.infra.cache_enabled,
            .cache_host = infra_cache_host,
            .cache_port = file_config.infra.cache_port,
            .cache_password = infra_cache_password,
            .cache_ttl = file_config.infra.cache_ttl,
            .http_timeout_ms = file_config.infra.http_timeout_ms,
        },
        .shared = .{},
    };

    // file_config 中的字符串由 ConfigLoader 分配，完成映射后立即释放
    if (global_config_loader) |*loader| {
        loader.deinit();
        global_config_loader = null;
    }

    return system_config;
}

/// 释放 loadSystemConfig 分配的字符串
pub fn freeSystemConfig(allocator: std.mem.Allocator, config: *SystemConfig) void {
    // api
    allocator.free(config.api.host);
    allocator.free(config.api.public_folder);

    // app
    allocator.free(config.app.plugin_directory);

    // infra
    allocator.free(config.infra.db_host);
    allocator.free(config.infra.db_name);
    allocator.free(config.infra.db_user);
    allocator.free(config.infra.db_password);
    allocator.free(config.infra.cache_host);
    if (config.infra.cache_password) |pwd| allocator.free(pwd);
}

/// 初始化整个系统
///
/// 按照依赖关系顺序初始化各层：
/// 1. 共享层
/// 2. 领域层
/// 3. 应用层
/// 4. API 层
/// 5. 基础设施层
/// 6. 服务管理器
///
/// ## 参数
/// - `allocator`: 内存分配器
/// - `config`: 系统配置
///
/// ## 错误
/// 如果任何层初始化失败，返回相应的错误。
pub fn initSystem(allocator: std.mem.Allocator, config: SystemConfig) !void {
    // allocator 用于初始化各层，之后由 ServiceManager 管理

    // 初始化各层，遵照依赖关系
    try shared.init(allocator, config.shared);
    errdefer shared.deinit();

    try domain.init(allocator, config.domain);
    // domain 层目前没有 deinit，跳过 errdefer

    try application.init(allocator, config.app);
    // application 层目前没有 deinit，跳过 errdefer

    try api.init(allocator, config.api);
    // api 层目前没有 deinit，跳过 errdefer

    const db = try infrastructure.init(allocator, config.infra);
    errdefer {
        db.deinit();
        allocator.destroy(db);
    }

    // 存储基础设施数据库连接以便后续清理
    infrastructure_db = db;

    // 使用新的DI系统注册应用服务
    try registerApplicationServices(allocator, db);

    logger.info("系统初始化完成", .{});

    // 初始化全局模块（使用基础设施层创建的数据库连接）
    // 这样控制器可以通过 global.get_db() 访问数据库
    shared.global.initWithDb(allocator, db);
    errdefer shared.global.deinit();

    // 初始化服务管理器
    service_manager = try ServiceManager.init(allocator, db, config);
    logger.info("服务管理器初始化完成", .{});

    // 同步服务管理器借用引用到 global 模块，供兼容路径读取
    shared.global.setServiceManager(&service_manager.?);

    // 将服务管理器注册到 DI 容器，实现更好的生命周期管理
    if (core.di.getGlobalContainer()) |container| {
        try container.registerInstance(ServiceManager, &service_manager.?, null);

        // 注册 CacheInterface（从 ServiceManager 获取）
        const cache_service = service_manager.?.getCacheService();
        const cache_interface = cache_service.asInterface();
        const cache_ptr = try container.allocator.create(CacheInterface);
        errdefer container.allocator.destroy(cache_ptr);
        cache_ptr.* = cache_interface;
        try container.registerInstance(CacheInterface, cache_ptr, null);
    }
}

/// 注册应用服务到DI容器
///
/// 使用新的DI系统注册用户、会员和分类相关的服务，采用依赖注入模式管理服务生命周期。
///
/// ## 参数
/// - `allocator`: 内存分配器
/// - `db`: 数据库连接
///
/// ## 错误
/// 如果服务注册失败，返回相应的错误。
fn registerApplicationServices(allocator: std.mem.Allocator, db: *sql_orm.Database) !void {
    if (core.di.getGlobalContainer()) |container| {
        // 1. 注册用户服务相关
        try registerUserServices(container, allocator, db);

        // 2. 注册认证服务
        try registerAuthServices(container);

        // 3. 注册基础设施服务（必须在安全服务之前）
        try container.registerInstance(sql_orm.Database, db, null);

        // 3.1 注册角色仓储（MySQL ORM 实现，供 rbac 中间件解析）
        const role_repo_impl = try container.allocator.create(MysqlRoleRepository);
        role_repo_impl.* = MysqlRoleRepository.init(container.allocator, db);
        const role_repo = try container.allocator.create(RoleRepository);
        errdefer container.allocator.destroy(role_repo);
        role_repo.* = role_repository_mod.create(role_repo_impl, MysqlRoleRepository.vtable());
        try container.registerInstance(RoleRepository, role_repo, null);

        // 3.2 注册敏感词仓储（MySQL ORM 实现，供审核引擎解析）
        const sw_repo_impl = try container.allocator.create(MysqlSensitiveWordRepository);
        sw_repo_impl.* = MysqlSensitiveWordRepository.init(container.allocator, db);
        const sw_repo = try container.allocator.create(SensitiveWordRepository);
        errdefer container.allocator.destroy(sw_repo);
        sw_repo.* = sensitive_word_repository_mod.create(sw_repo_impl, &MysqlSensitiveWordRepository.vtable());
        try container.registerInstance(SensitiveWordRepository, sw_repo, null);

        // 4. 注册安全服务
        try registerSecurityServices(container, allocator);

        logger.info("应用服务注册到DI容器完成", .{});
    } else {
        return error.DIContainerNotInitialized;
    }
}

/// 注册用户服务
fn registerUserServices(container: *core.di.DIContainer, func_allocator: std.mem.Allocator, db: *sql_orm.Database) !void {
    _ = func_allocator;

    // 创建仓储实例
    const sqlite_repo = try createSqliteUserRepository(container.allocator, db);
    const user_repo = try container.allocator.create(UserRepository);
    errdefer container.allocator.destroy(user_repo);
    user_repo.* = domain.repositories.user_repository.create(sqlite_repo, &SqliteUserRepository.vtable());

    // 注册到容器
    try container.registerInstance(SqliteUserRepository, sqlite_repo, null);
    try container.registerInstance(UserRepository, user_repo, null);

    try container.registerSingleton(UserService, UserService, struct {
        fn factory(di: *core.di.DIContainer, allocator: std.mem.Allocator) anyerror!*UserService {
            const resolved_user_repo = try di.resolve(UserRepository);

            const user_service = try allocator.create(UserService);
            errdefer allocator.destroy(user_service);
            user_service.* = UserService.init(allocator, resolved_user_repo.*);
            return user_service;
        }
    }.factory, null);
}

/// 创建用户仓储实现
fn createSqliteUserRepository(allocator: std.mem.Allocator, db: *sql_orm.Database) !*SqliteUserRepository {
    const repo = try allocator.create(SqliteUserRepository);
    errdefer allocator.destroy(repo);
    repo.* = SqliteUserRepository.init(allocator, db);
    return repo;
}

/// 注册认证服务
fn registerAuthServices(container: *core.di.DIContainer) !void {
    try container.registerSingleton(AuthService, AuthService, struct {
        fn factory(_: *core.di.DIContainer, allocator: std.mem.Allocator) anyerror!*AuthService {
            const auth_service = try allocator.create(AuthService);
            errdefer allocator.destroy(auth_service);
            auth_service.* = AuthService.init(allocator);
            return auth_service;
        }
    }.factory, null);
}

/// 注册安全服务到DI容器
///
/// 注册所有安全相关的中间件和服务，包括CSRF防护、速率限制、RBAC权限控制、
/// 安全监控和审计日志。
///
/// ## 参数
/// - `container`: DI容器
/// - `allocator`: 内存分配器
///
/// ## 错误
/// 如果服务注册失败，返回相应的错误。
fn registerSecurityServices(container: *core.di.DIContainer, allocator: std.mem.Allocator) !void {
    
    // 1. 注册 CSRF 防护
    try container.registerSingleton(CsrfProtection, CsrfProtection, struct {
        fn factory(di: *core.di.DIContainer, alloc: std.mem.Allocator) anyerror!*CsrfProtection {
            const cache_ptr = try di.resolve(CacheInterface);
            const csrf = try alloc.create(CsrfProtection);
            errdefer alloc.destroy(csrf);
            csrf.* = CsrfProtection.init(alloc, .{
                .enabled = true,
                .header_name = "X-CSRF-Token",
                .cookie_name = "csrf_token",
                .safe_methods = &.{ "GET", "HEAD", "OPTIONS" },
                .whitelist_paths = &.{
                    "/api/auth/login",
                    "/api/auth/register",
                    "/api/health",
                },
            }, cache_ptr);
            return csrf;
        }
    }.factory, null);
    
    // 2. 注册速率限制器
    try container.registerSingleton(RateLimiter, RateLimiter, struct {
        fn factory(di: *core.di.DIContainer, alloc: std.mem.Allocator) anyerror!*RateLimiter {
            const cache_ptr = try di.resolve(CacheInterface);
            const limiter = try alloc.create(RateLimiter);
            errdefer alloc.destroy(limiter);
            
            const endpoint_limits = [_]RateLimiter.EndpointLimit{
                .{ .path = "/api/auth/login", .limit = 5, .window = 60 },
            };
            const whitelist_ips = [_][]const u8{ "127.0.0.1", "::1" };
            const blacklist_ips = [_][]const u8{};
            
            limiter.* = RateLimiter.init(alloc, cache_ptr, .{
                .global_limit = 1000,
                .global_window = 60,
                .ip_limit = 100,
                .ip_window = 60,
                .user_limit = 200,
                .user_window = 60,
                .endpoint_limits = @as([]RateLimiter.EndpointLimit, @constCast(&endpoint_limits)),
                .whitelist_ips = @as([][]const u8, @constCast(&whitelist_ips)),
                .blacklist_ips = @as([][]const u8, @constCast(&blacklist_ips)),
            });
            return limiter;
        }
    }.factory, null);
    
    // 3. 注册 RBAC 中间件
    try container.registerSingleton(RbacMiddleware, RbacMiddleware, struct {
        fn factory(di: *core.di.DIContainer, alloc: std.mem.Allocator) anyerror!*RbacMiddleware {
            const cache_ptr = try di.resolve(CacheInterface);
            const rbac = try alloc.create(RbacMiddleware);
            errdefer alloc.destroy(rbac);
            rbac.* = RbacMiddleware.init(alloc, .{
                .enabled = true,
                .super_admin_role = "super_admin",
                .public_paths = &.{
                    "/api/auth/login",
                    "/api/auth/register",
                    "/api/health",
                },
            }, cache_ptr);
            return rbac;
        }
    }.factory, null);
    
    // 4. 注册钉钉通知器（可选，从环境变量读取配置）
    const DingTalkNotifier = @import("src/infrastructure/notification/dingtalk_notifier.zig").DingTalkNotifier;
    const DingTalkConfig = @import("src/infrastructure/notification/dingtalk_notifier.zig").DingTalkConfig;
    
    const webhook_ptr = std.c.getenv("DINGTALK_WEBHOOK");
    if (webhook_ptr) |webhook_raw| {
        const webhook = std.mem.span(webhook_raw);
        
        const secret_ptr = std.c.getenv("DINGTALK_SECRET");
        const secret = if (secret_ptr) |s| std.mem.span(s) else null;
        
        const dingtalk_config = DingTalkConfig{
            .webhook_url = try allocator.dupe(u8, webhook),
            .secret = if (secret) |s| try allocator.dupe(u8, s) else null,
        };
        
        const dingtalk_notifier = try allocator.create(DingTalkNotifier);
        errdefer allocator.destroy(dingtalk_notifier);
        dingtalk_notifier.* = DingTalkNotifier.init(allocator, dingtalk_config);
        
        try container.registerInstance(DingTalkNotifier, dingtalk_notifier, null);
        logger.info("✅ 钉钉通知器已注册", .{});
    } else {
        logger.info("⚠️  未配置钉钉通知器（缺少 DINGTALK_WEBHOOK 环境变量）", .{});
    }
    
    logger.info("安全服务注册到DI容器完成", .{});
}

/// 清理整个系统
pub fn deinitSystem() void {
    std.debug.print("[INFO] 开始系统清理...\n", .{});

    // 1. 清理服务管理器
    if (service_manager) |*sm| {
        std.debug.print("[INFO] 清理阶段 1.1: ServiceManager.deinit 开始\n", .{});
        const allocator = sm.getAllocator();
        sm.deinit();
        std.debug.print("[INFO] 清理阶段 1.1: ServiceManager.deinit 完成\n", .{});

        std.debug.print("[INFO] 清理阶段 1.2: Database.deinit 开始\n", .{});
        infrastructure_db.?.deinit();
        allocator.destroy(infrastructure_db.?);
        std.debug.print("[INFO] 清理阶段 1.2: Database.deinit 完成\n", .{});
    }
    service_manager = null;
    infrastructure_db = null;

    // 2. 清理全局模块
    std.debug.print("[INFO] 清理阶段 2: global.deinit 开始\n", .{});
    shared.global.deinit();
    std.debug.print("[INFO] 清理阶段 2: global.deinit 完成\n", .{});

    // 3. 清理配置加载器
    std.debug.print("[INFO] 清理阶段 3: config_loader.deinit 开始\n", .{});
    if (global_config_loader) |*loader| loader.deinit();
    global_config_loader = null;
    std.debug.print("[INFO] 清理阶段 3: config_loader.deinit 完成\n", .{});

    // 4. 核心：由 DI 系统的 Arena 回收所有单例和服务资源
    std.debug.print("[INFO] 清理阶段 4: shared.deinit 开始\n", .{});
    shared.deinit();
    std.debug.print("[INFO] 清理阶段 4: shared.deinit 完成\n", .{});

    std.debug.print("[INFO] 系统清理完成\n", .{});
}

// ============================================================================
// 测试聚合：显式引用全部含测试块的文件（Zig 0.17 懒编译下普通 import 不会收集用例）
// ============================================================================
test {
    _ = @import("src/api/controllers/system_admin.controller.zig");
    _ = @import("src/api/controllers/system_dept.controller.zig");
    _ = @import("src/api/middleware/chain.zig");
    _ = @import("src/api/middleware/request_id.middleware.zig");
    _ = @import("src/api/middleware/wrapper.zig");
    _ = @import("src/application/services/ai/ai.zig");
    _ = @import("src/infrastructure/cache/cache.zig");
    _ = @import("src/infrastructure/cache/contract.zig");
    _ = @import("src/infrastructure/cache/typed_cache.zig");
    _ = @import("src/application/services/cookie/mod.zig");
    _ = @import("src/application/services/datetime/datetime.zig");
    _ = @import("src/application/services/errors/errors.zig");
    _ = @import("src/application/services/events/events.zig");
    _ = @import("src/infrastructure/http/client.zig");
    _ = @import("src/infrastructure/http/pool.zig");
    _ = @import("src/application/services/json/json.zig");
    _ = @import("src/application/services/logger/logger.zig");
    _ = @import("src/application/services/pool/pool.zig");
    _ = @import("src/infrastructure/redis/args.zig");
    _ = @import("src/infrastructure/redis/command.zig");
    _ = @import("src/infrastructure/redis/mod.zig");
    _ = @import("src/infrastructure/redis/protocol.zig");
    _ = @import("src/infrastructure/redis/reply.zig");
    _ = @import("src/infrastructure/redis/result.zig");
    _ = @import("src/infrastructure/redis/tests.zig");
    _ = @import("src/infrastructure/redis/types.zig");
    _ = @import("src/application/services/session/mod.zig");
    _ = @import("src/application/services/sql/advanced.zig");
    _ = @import("src/application/services/sql/driver.zig");
    _ = @import("src/application/services/sql/dynamic.zig");
    _ = @import("src/application/services/sql/field_binding.zig");
    _ = @import("src/application/services/sql/interface.zig");
    _ = @import("src/application/services/sql/json_field.zig");
    _ = @import("src/application/services/sql/model.zig");
    _ = @import("src/application/services/sql/orm.zig");
    _ = @import("src/application/services/sql/query.zig");
    _ = @import("src/application/services/sql/sql_errors.zig");
    _ = @import("src/application/services/template/errors.zig");
    _ = @import("src/application/services/template/functions.zig");
    _ = @import("src/application/services/template/mod.zig");
    _ = @import("src/application/services/template/template_test.zig");
    _ = @import("src/application/services/thread/thread_manager.zig");
    _ = @import("src/application/services/validator/security.zig");
    _ = @import("src/application/services/validator/validator.zig");
    _ = @import("src/core/config/system_config.zig");
    _ = @import("src/core/patterns/command.zig");
    _ = @import("src/core/patterns/ddd_errors.zig");
    _ = @import("src/core/patterns/domain_event_bus.zig");
    _ = @import("src/core/patterns/patterns_test.zig");
    _ = @import("src/core/patterns/projection.zig");
    _ = @import("src/core/patterns/query.zig");
    _ = @import("src/core/primitives/logger.zig");
    _ = @import("src/core/primitives/registry.zig");
    _ = @import("src/core/utils/benchmark_test.zig");
    _ = @import("src/core/utils/jwt.zig");
    _ = @import("src/domain/entities/relations_test.zig");
    _ = @import("src/infrastructure/cache/cache.zig");
    _ = @import("src/infrastructure/cache/contract.zig");
    _ = @import("src/infrastructure/cache/typed_cache.zig");
    _ = @import("src/infrastructure/database/connection_pool_manager.zig");
    _ = @import("src/infrastructure/http/client.zig");
    _ = @import("src/infrastructure/http/pool.zig");
    _ = @import("src/infrastructure/notification/mod.zig");
    _ = @import("src/plugins/dependency_resolver.zig");
    _ = @import("src/plugins/event_bus.zig");
    _ = @import("src/plugins/example_plugin.zig");
    _ = @import("src/plugins/mod.zig");
    _ = @import("src/plugins/plugin_interface.zig");
    _ = @import("src/plugins/plugin_manager.zig");
    _ = @import("src/plugins/plugin_manifest.zig");
    _ = @import("src/plugins/plugin_registry.zig");
    _ = @import("src/plugins/plugin_test.zig");
    _ = @import("src/plugins/plugin_verifier.zig");
    _ = @import("src/plugins/resource_tracker.zig");
    _ = @import("src/plugins/security_policy.zig");
}
