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
const logger = @import("application/services/logger/logger.zig");
const sql_orm = @import("application/services/sql/orm.zig");

// 用户服务相关导入
const UserService = @import("api/services/user_service.zig").UserService;
const UserRepository = @import("domain/repositories/user_repository.zig").UserRepository;
const SqliteUserRepository = @import("infrastructure/database/sqlite_user_repository.zig").SqliteUserRepository;

// 会员服务相关导入
const MemberService = @import("api/services/member_service.zig").MemberService;
const MemberRepository = @import("domain/repositories/member_repository.zig").MemberRepository;
const SqliteMemberRepository = @import("infrastructure/database/sqlite_member_repository.zig").SqliteMemberRepository;

// 分类服务相关导入
const CategoryService = @import("api/services/category_service.zig").CategoryService;
const CategoryRepository = @import("domain/repositories/category_repository.zig").CategoryRepository;
const SqliteCategoryRepository = @import("infrastructure/database/sqlite_category_repository.zig").SqliteCategoryRepository;

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
pub const api = @import("api/Api.zig");

/// 应用层 - 业务用例编排
///
/// 包含用例、服务管理器、ORM、缓存等应用服务。
pub const application = @import("application/mod.zig");

/// 领域层 - 核心业务逻辑
///
/// 包含实体、领域服务、仓储接口等业务核心。
pub const domain = @import("domain/mod.zig");

/// 基础设施层 - 外部服务实现
///
/// 包含数据库、缓存、HTTP 客户端等外部服务实现。
pub const infrastructure = @import("infrastructure/mod.zig");

/// 共享层 - 通用组件
///
/// 包含工具函数、类型定义、错误处理等跨层共享组件。
pub const shared = @import("shared/mod.zig");

/// SQL ORM 模块 - 数据库操作
///
/// 提供完整的多数据库 ORM 功能（MySQL/SQLite/PostgreSQL）。
pub const sql = @import("application/services/sql/mod.zig");

/// Redis 客户端模块 - 缓存和键值存储
///
/// 提供完整的 Redis 客户端功能，支持连接池、所有数据类型操作。
pub const redis = @import("application/services/redis/redis.zig");

// ============================================================================
// 服务管理
// ============================================================================

/// 服务管理器类型
pub const ServiceManager = @import("application/services/mod.zig").ServiceManager;

// 全局服务实例
var service_manager: ?ServiceManager = null;
// 基础设施数据库连接（需要清理）
var infrastructure_db: ?*sql_orm.Database = null;
// 用户服务相关实例（需要清理）
var user_service_instance: ?*UserService = null;
var user_repository_instance: ?UserRepository = null;
var sqlite_repo_instance: ?*SqliteUserRepository = null;
// 会员服务相关实例（需要清理）
var member_service_instance: ?*MemberService = null;
var member_repository_instance: ?MemberRepository = null;
var sqlite_member_repo_instance: ?*SqliteMemberRepository = null;
// 分类服务相关实例（需要清理）
var category_service_instance: ?*CategoryService = null;
var category_repository_instance: ?CategoryRepository = null;
var sqlite_category_repo_instance: ?*SqliteCategoryRepository = null;
// 全局分配器（用于清理资源）
var global_allocator: ?std.mem.Allocator = null;

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
pub const SystemConfig = struct {
    /// API 层配置
    api: api.ServerConfig = .{},
    /// 应用层配置
    app: application.AppConfig = .{},
    /// 基础设施层配置
    infra: infrastructure.InfraConfig = .{},
    /// 领域层配置
    domain: domain.DomainConfig = .{},
    /// 共享层配置
    shared: shared.SharedConfig = .{},
};

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
///
/// ## 参数
/// - `allocator`: 内存分配器
///
/// ## 返回
/// 返回可用于 initSystem 的 SystemConfig
pub fn loadSystemConfig(allocator: std.mem.Allocator) !SystemConfig {
    const file_config = try loadConfigFromFiles(allocator, "configs");

    // 应用环境变量覆盖
    var system_config = SystemConfig{
        .api = .{
            .host = file_config.api.host,
            .port = file_config.api.port,
            .max_clients = file_config.api.max_clients,
            .timeout = file_config.api.timeout,
            .public_folder = file_config.api.public_folder,
        },
        .app = .{
            .enable_cache = file_config.app.enable_cache,
            .cache_ttl_seconds = file_config.app.cache_ttl_seconds,
            .max_concurrent_tasks = file_config.app.max_concurrent_tasks,
            .enable_plugins = file_config.app.enable_plugins,
            .plugin_directory = file_config.app.plugin_directory,
        },
        .domain = .{
            .validate_models = file_config.domain.validate_models,
            .enforce_business_rules = file_config.domain.enforce_business_rules,
        },
        .infra = .{
            .db_host = file_config.infra.db_host,
            .db_port = file_config.infra.db_port,
            .db_name = file_config.infra.db_name,
            .db_user = file_config.infra.db_user,
            .db_password = file_config.infra.db_password,
            .db_pool_size = file_config.infra.db_pool_size,
            .cache_enabled = file_config.infra.cache_enabled,
            .cache_host = file_config.infra.cache_host,
            .cache_port = file_config.infra.cache_port,
            .cache_ttl = file_config.infra.cache_ttl,
            .http_timeout_ms = file_config.infra.http_timeout_ms,
        },
        .shared = .{},
    };

    // 应用环境变量覆盖
    if (std.posix.getenv("ZIGCMS_API_HOST")) |val| {
        system_config.api.host = val;
    }
    if (std.posix.getenv("ZIGCMS_API_PORT")) |val| {
        system_config.api.port = std.fmt.parseInt(u16, val, 10) catch system_config.api.port;
    }
    if (std.posix.getenv("ZIGCMS_DB_HOST")) |val| {
        system_config.infra.db_host = val;
    }
    if (std.posix.getenv("ZIGCMS_DB_PORT")) |val| {
        system_config.infra.db_port = std.fmt.parseInt(u16, val, 10) catch system_config.infra.db_port;
    }
    if (std.posix.getenv("ZIGCMS_DB_NAME")) |val| {
        system_config.infra.db_name = val;
    }
    if (std.posix.getenv("ZIGCMS_DB_USER")) |val| {
        system_config.infra.db_user = val;
    }
    if (std.posix.getenv("ZIGCMS_DB_PASSWORD")) |val| {
        system_config.infra.db_password = val;
    }

    return system_config;
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
    // 存储分配器以便后续清理
    global_allocator = allocator;

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

    // 在这里添加应用服务的依赖注入组装
    try initApplicationServices(allocator, db);

    logger.info("系统初始化完成", .{});

    // 初始化全局模块（使用基础设施层创建的数据库连接）
    // 这样控制器可以通过 global.get_db() 访问数据库
    shared.global.initWithDb(allocator, db);
    errdefer shared.global.deinit();

    // 初始化服务管理器
    service_manager = try ServiceManager.init(allocator, db, config);
    logger.info("服务管理器初始化完成", .{});
}

/// 初始化应用服务
///
/// 按照依赖倒置原则组装用户、会员和分类相关的各层组件：
/// 1. 创建基础设施层实现（SqliteUserRepository, SqliteMemberRepository, SqliteCategoryRepository）
/// 2. 创建领域层接口（UserRepository, MemberRepository, CategoryRepository）
/// 3. 创建应用层服务（UserService, MemberService, CategoryService）
/// 4. 注册到全局服务管理器
///
/// ## 参数
/// - `allocator`: 内存分配器
/// - `db`: 数据库连接
///
/// ## 错误
/// 如果服务初始化失败，返回相应的错误。
fn initApplicationServices(allocator: std.mem.Allocator, db: *sql_orm.Database) !void {
    // 1. 创建用户服务基础设施层实现
    const sqlite_repo_impl = try allocator.create(SqliteUserRepository);
    errdefer allocator.destroy(sqlite_repo_impl);

    sqlite_repo_impl.* = SqliteUserRepository.init(allocator, db);

    // 2. 创建用户领域层接口（注入基础设施实现）
    const user_repository = domain.repositories.user_repository.create(sqlite_repo_impl, &SqliteUserRepository.vtable());

    // 3. 创建用户应用层服务（注入领域层接口）
    const user_service = try allocator.create(UserService);
    errdefer allocator.destroy(user_service);

    user_service.* = UserService.init(allocator, user_repository);

    // 4. 创建会员服务基础设施层实现
    const sqlite_member_repo_impl = try allocator.create(SqliteMemberRepository);
    errdefer allocator.destroy(sqlite_member_repo_impl);

    sqlite_member_repo_impl.* = SqliteMemberRepository.init(allocator, db);

    // 5. 创建会员领域层接口（注入基础设施实现）
    const member_repository = domain.repositories.member_repository.create(sqlite_member_repo_impl, &SqliteMemberRepository.vtable());

    // 6. 创建会员应用层服务（注入领域层接口）
    const member_service = try allocator.create(MemberService);
    errdefer allocator.destroy(member_service);

    member_service.* = MemberService.init(allocator, member_repository);

    // 7. 创建分类服务基础设施层实现
    const sqlite_category_repo_impl = try allocator.create(SqliteCategoryRepository);
    errdefer allocator.destroy(sqlite_category_repo_impl);

    sqlite_category_repo_impl.* = SqliteCategoryRepository.init(allocator, db);

    // 8. 创建分类领域层接口（注入基础设施实现）
    const category_repository = domain.repositories.category_repository.create(sqlite_category_repo_impl, &SqliteCategoryRepository.vtable());

    // 9. 创建分类应用层服务（注入领域层接口）
    const category_service = try allocator.create(CategoryService);
    errdefer allocator.destroy(category_service);

    category_service.* = CategoryService.init(allocator, category_repository);

    // 10. 存储服务实例以便后续清理
    user_service_instance = user_service;
    user_repository_instance = user_repository;
    sqlite_repo_instance = sqlite_repo_impl;

    member_service_instance = member_service;
    member_repository_instance = member_repository;
    sqlite_member_repo_instance = sqlite_member_repo_impl;

    category_service_instance = category_service;
    category_repository_instance = category_repository;
    sqlite_category_repo_instance = sqlite_category_repo_impl;

    logger.info("应用服务初始化完成", .{});
}

/// 清理整个系统
///
/// 按照初始化的逆序清理各层资源。
/// 应在程序退出前调用以避免内存泄漏。
pub fn deinitSystem() void {
    std.debug.print("[INFO] 开始系统清理...\n", .{});

    // 清理服务管理器
    if (service_manager) |*sm| {
        sm.deinit();
    }
    service_manager = null;

    // 清理全局模块（在数据库之前，因为它持有数据库引用）
    shared.global.deinit();

    // 清理分类服务实例
    if (category_service_instance) |service| {
        if (global_allocator) |allocator| {
            allocator.destroy(service);
        }
    }
    category_service_instance = null;
    category_repository_instance = null;

    // 清理分类仓储实现实例
    if (sqlite_category_repo_instance) |repo| {
        if (global_allocator) |allocator| {
            allocator.destroy(repo);
        }
    }
    sqlite_category_repo_instance = null;

    // 清理会员服务实例
    if (member_service_instance) |service| {
        if (global_allocator) |allocator| {
            allocator.destroy(service);
        }
    }
    member_service_instance = null;
    member_repository_instance = null;

    // 清理会员仓储实现实例
    if (sqlite_member_repo_instance) |repo| {
        if (global_allocator) |allocator| {
            allocator.destroy(repo);
        }
    }
    sqlite_member_repo_instance = null;

    // 清理用户服务实例
    if (user_service_instance) |service| {
        if (global_allocator) |allocator| {
            allocator.destroy(service);
        }
    }
    user_service_instance = null;
    user_repository_instance = null;

    // 清理用户仓储实现实例
    if (sqlite_repo_instance) |repo| {
        if (global_allocator) |allocator| {
            allocator.destroy(repo);
        }
    }
    sqlite_repo_instance = null;

    // 清理基础设施数据库连接
    if (infrastructure_db) |db| {
        db.deinit();
        // 释放数据库结构体内存
        if (global_allocator) |allocator| {
            allocator.destroy(db);
        }
    }
    infrastructure_db = null;

    // 清理配置加载器
    if (global_config_loader) |*loader| {
        loader.deinit();
    }
    global_config_loader = null;

    // 其他各层清理
    shared.deinit();

    // 清理全局分配器引用
    global_allocator = null;

    std.debug.print("[INFO] 系统清理完成\n", .{});
}
