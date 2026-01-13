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
const UserService = @import("application/services/user_service.zig").UserService;
const UserRepository = @import("domain/repositories/user_repository.zig").UserRepository;
const SqliteUserRepository = @import("infrastructure/database/sqlite_user_repository.zig").SqliteUserRepository;

// 会员服务相关导入
const MemberService = @import("application/services/member_service.zig").MemberService;
const MemberRepository = @import("domain/repositories/member_repository.zig").MemberRepository;
const SqliteMemberRepository = @import("infrastructure/database/sqlite_member_repository.zig").SqliteMemberRepository;

// 分类服务相关导入
const CategoryService = @import("application/services/category_service.zig").CategoryService;
const CategoryRepository = @import("domain/repositories/category_repository.zig").CategoryRepository;
const SqliteCategoryRepository = @import("infrastructure/database/sqlite_category_repository.zig").SqliteCategoryRepository;

// 认证服务导入
const AuthService = @import("application/services/auth_service.zig").AuthService;

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
pub const redis = @import("application/services/redis/mod.zig");

// ============================================================================
// 服务管理
// ============================================================================

/// 服务管理器类型
pub const ServiceManager = @import("application/services/mod.zig").ServiceManager;

// 全局服务实例
var service_manager: ?ServiceManager = null;
// 基础设施数据库连接（需要清理）
var infrastructure_db: ?*sql_orm.Database = null;
// 服务实例将通过DI容器管理，不再使用全局变量
// 这些变量已被移除，服务生命周期由DI容器统一管理
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

    // 将文件配置映射到系统配置（防腐层转换）
    return SystemConfig{
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

    // 将服务管理器注册到 DI 容器，实现更好的生命周期管理
    const di = @import("shared/di/mod.zig");
    if (di.getGlobalContainer()) |container| {
        try container.registerInstance(ServiceManager, &service_manager.?);
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
    const di_module = @import("shared/di/mod.zig");

    if (di_module.getGlobalContainer()) |container| {
        // 1. 注册用户服务相关
        try registerUserServices(container, allocator, db);

        // 2. 注册会员服务相关
        try registerMemberServices(container, allocator, db);

        // 3. 注册分类服务相关
        try registerCategoryServices(container, allocator, db);

        // 4. 注册认证服务
        try registerAuthServices(container);

        // 5. 注册基础设施服务
        try container.registerInstance(sql_orm.Database, db);

        logger.info("应用服务注册到DI容器完成", .{});
    } else {
        return error.DIContainerNotInitialized;
    }
}

/// 注册用户服务
fn registerUserServices(container: *@import("shared/di/container.zig").DIContainer, func_allocator: std.mem.Allocator, db: *sql_orm.Database) !void {
    // 创建仓储实例
    const sqlite_repo = try createSqliteUserRepository(func_allocator, db);
    const user_repo = try func_allocator.create(UserRepository);
    errdefer func_allocator.destroy(user_repo);
    user_repo.* = domain.repositories.user_repository.create(sqlite_repo, &SqliteUserRepository.vtable());

    // 注册到容器
    try container.registerInstance(SqliteUserRepository, sqlite_repo);
    try container.registerInstance(UserRepository, user_repo);

    try container.registerSingleton(UserService, UserService, struct {
        fn factory(di: *@import("shared/di/container.zig").DIContainer, allocator: std.mem.Allocator) anyerror!*UserService {
            const resolved_user_repo = try di.resolve(UserRepository);

            const user_service = try allocator.create(UserService);
            errdefer allocator.destroy(user_service);
            user_service.* = UserService.init(allocator, resolved_user_repo.*);
            return user_service;
        }
    }.factory);
}

/// 创建用户仓储实现
fn createSqliteUserRepository(allocator: std.mem.Allocator, db: *sql_orm.Database) !*SqliteUserRepository {
    const repo = try allocator.create(SqliteUserRepository);
    errdefer allocator.destroy(repo);
    repo.* = SqliteUserRepository.init(allocator, db);
    return repo;
}

/// 注册会员服务
fn registerMemberServices(container: *@import("shared/di/container.zig").DIContainer, func_allocator: std.mem.Allocator, db: *sql_orm.Database) !void {
    // 创建仓储实例
    const sqlite_repo = try createSqliteMemberRepository(func_allocator, db);
    const member_repo = try func_allocator.create(MemberRepository);
    errdefer func_allocator.destroy(member_repo);
    member_repo.* = domain.repositories.member_repository.create(sqlite_repo, &SqliteMemberRepository.vtable());

    // 注册到容器
    try container.registerInstance(SqliteMemberRepository, sqlite_repo);
    try container.registerInstance(MemberRepository, member_repo);

    try container.registerSingleton(MemberService, MemberService, struct {
        fn factory(di: *@import("shared/di/container.zig").DIContainer, allocator: std.mem.Allocator) anyerror!*MemberService {
            const resolved_member_repo = try di.resolve(MemberRepository);

            const member_service = try allocator.create(MemberService);
            errdefer allocator.destroy(member_service);
            member_service.* = MemberService.init(allocator, resolved_member_repo.*);
            return member_service;
        }
    }.factory);
}

/// 注册分类服务
fn registerCategoryServices(container: *@import("shared/di/container.zig").DIContainer, func_allocator: std.mem.Allocator, db: *sql_orm.Database) !void {
    // 创建仓储实例
    const sqlite_repo = try createSqliteCategoryRepository(func_allocator, db);
    const category_repo = try func_allocator.create(CategoryRepository);
    errdefer func_allocator.destroy(category_repo);
    category_repo.* = domain.repositories.category_repository.create(sqlite_repo, &SqliteCategoryRepository.vtable());

    // 注册到容器
    try container.registerInstance(SqliteCategoryRepository, sqlite_repo);
    try container.registerInstance(CategoryRepository, category_repo);

    try container.registerSingleton(CategoryService, CategoryService, struct {
        fn factory(di: *@import("shared/di/container.zig").DIContainer, allocator: std.mem.Allocator) anyerror!*CategoryService {
            const resolved_category_repo = try di.resolve(CategoryRepository);

            const category_service = try allocator.create(CategoryService);
            errdefer allocator.destroy(category_service);
            category_service.* = CategoryService.init(allocator, resolved_category_repo.*);
            return category_service;
        }
    }.factory);
}

/// 创建会员仓储实现
fn createSqliteMemberRepository(allocator: std.mem.Allocator, db: *sql_orm.Database) !*SqliteMemberRepository {
    const repo = try allocator.create(SqliteMemberRepository);
    errdefer allocator.destroy(repo);
    repo.* = SqliteMemberRepository.init(allocator, db);
    return repo;
}

/// 注册分类服务实现
fn createSqliteCategoryRepository(allocator: std.mem.Allocator, db: *sql_orm.Database) !*SqliteCategoryRepository {
    const repo = try allocator.create(SqliteCategoryRepository);
    errdefer allocator.destroy(repo);
    repo.* = SqliteCategoryRepository.init(allocator, db);
    return repo;
}

/// 注册认证服务
fn registerAuthServices(container: *@import("shared/di/container.zig").DIContainer) !void {
    try container.registerSingleton(AuthService, AuthService, struct {
        fn factory(_: *@import("shared/di/container.zig").DIContainer, allocator: std.mem.Allocator) anyerror!*AuthService {
            const auth_service = try allocator.create(AuthService);
            errdefer allocator.destroy(auth_service);
            auth_service.* = AuthService.init(allocator);
            return auth_service;
        }
    }.factory);
}

/// 清理整个系统
pub fn deinitSystem() void {
    std.debug.print("[INFO] 开始系统清理...\n", .{});

    // 1. 清理服务管理器
    if (service_manager) |*sm| sm.deinit();
    service_manager = null;

    // 2. 清理全局模块
    shared.global.deinit();

    // 3. 清理基础设施数据库
    if (infrastructure_db) |db| {
        db.deinit();
        if (global_allocator) |allocator| allocator.destroy(db);
    }
    infrastructure_db = null;

    // 4. 清理配置加载器
    if (global_config_loader) |*loader| loader.deinit();
    global_config_loader = null;

    // 5. 核心：由 DI 系统的 Arena 回收所有单例和服务资源
    shared.deinit();

    global_allocator = null;
    std.debug.print("[INFO] 系统清理完成\n", .{});
}
