//! 全局模块 - 系统级服务管理器
//!
//! 该模块管理全局性的组件和服务：
//! - 服务管理器（包含所有子服务：缓存、插件、指标、JSON、事件、日志）
//! - 数据库连接
//! - 配置管理
//!
//! 内存所有权说明：
//! - allocator: 从 ServiceManager 获取
//! - _db: 由 root.zig 创建和拥有
//! - _service_manager: 由 root.zig 创建和拥有
//! - config: 由全局模块创建和拥有，在 deinit 中释放
//!
//! 初始化顺序：
//! 1. 日志器
//! 2. ORM 数据库连接
//! 3. 服务管理器（包含所有子服务）
//!
//! 清理顺序（逆序）：
//! 1. 服务管理器（通过 ServiceManager 清理所有子服务）
//! 2. ORM 数据库连接
//! 3. 日志器
//! 4. 配置

const std = @import("std");
const Allocator = std.mem.Allocator;
const pretty = @import("pretty");
const models = @import("../../domain/entities/models.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const strings = @import("../../shared/utils/strings.zig");
const base = @import("../../api/controllers/base.fn.zig");
const services = @import("../../application/services/mod.zig");
const sql = @import("../../application/services/sql/orm.zig");
pub const logger = @import("../../application/services/logger/logger.zig");
const root = @import("../../root.zig");

// 资源所有权模式
const ResourceOwnership = enum {
    owned,
    borrowed,
};

// 移除全局 _allocator，改为从 ServiceManager 获取
// var _allocator: ?Allocator = null;
var _db: ?*sql.Database = null;
var _db_ownership: ResourceOwnership = .borrowed;
var _service_manager: ?*services.ServiceManager = null;
var _service_manager_ownership: ResourceOwnership = .borrowed;
// 移除独立的 _plugin_system，改为从 ServiceManager 获取
var config: std.StringHashMap([]const u8) = undefined;
var mu: std.Thread.Mutex = std.Thread.Mutex{};

pub const JwtTokenSecret = "this is a secret";
var is_initialized: bool = false;

/// 清理全局模块资源
///
/// 清理顺序（与初始化相反）：
/// 1. 服务管理器（通过 ServiceManager 清理所有子服务）
/// 2. 数据库（如果 owned）
/// 3. 配置
///
/// 注意：
/// - 此函数应在程序退出前调用
/// - 数据库连接是否清理取决于所有权（owned vs borrowed）
/// - 日志器由 main.zig 管理，不在此处清理
/// - 线程安全：使用 mutex 保护
pub fn deinit() void {
    mu.lock();
    defer mu.unlock();

    if (!is_initialized) return;

    std.debug.print("[INFO] global module deinit, cleaning up resources...\n", .{});

    // 1. 根据所有权决定是否清理服务管理器
    if (_service_manager) |sm| {
        if (_service_manager_ownership == .owned) {
            const allocator = sm.getAllocator();
            sm.deinit();
            allocator.destroy(sm);
        }
        _service_manager = null;
        _service_manager_ownership = .borrowed;
    }

    // 2. 根据所有权决定是否清理数据库
    if (_db) |_| {
        // db 的清理由 root.zig 中的 ServiceManager 处理
        std.debug.print("[INFO] global module deinit: releasing database reference\n", .{});
        _db = null;
    }

    // 3. 注意：日志器由 main.zig 管理，不在此处清理

    // 4. 清理配置
    // 使用一个临时方法检查：尝试获取迭代器，如果失败说明未初始化
    if (config.count() >= 0) {
        config.deinit();
    }
    config = undefined;

    // 5. 重置初始化状态，允许重新初始化（用于测试）
    is_initialized = false;

    std.debug.print("[INFO] global module cleanup completed\n", .{});
}

fn init_some() void {
    // 获取一个临时 allocator 用于初始化
    // 注意：这里使用 page_allocator，因为还没有 ServiceManager
    const allocator = std.heap.page_allocator;

    config = std.StringHashMap([]const u8).init(allocator);
    errdefer config.deinit();

    // 首先初始化日志器
    logger.initDefault(allocator, .{
        .level = .debug,
        .format = .colored,
        .module_name = "zigcms",
        .include_timestamp = true,
        .sync_on_error = true,
    }) catch |e| {
        std.debug.print("[ERROR] 初始化日志器失败: {}\n", .{e});
        @panic("无法初始化日志器");
    };
    errdefer logger.deinitDefault();

    logger.info("[global] 开始初始化全局模块...", .{});
    logger.info("[global] 准备初始化 ORM 数据库连接...", .{});

    // 初始化 SQL ORM 数据库连接（使用配置文件中的密码）
    initOrmDatabase() catch |e| {
        logger.err("[global] 初始化 ORM 数据库失败: {}", .{e});
        @panic("无法初始化数据库连接，请检查数据库配置和网络连接");
    };
    errdefer {
        if (_db) |_| {
            logger.err("[global] ORM 数据库初始化失败，回滚操作", .{});
        }
    }

    // 注意：init_some() 不再初始化 ServiceManager，它由 root.zig 管理
    // ServiceManager 包含所有子服务：缓存、插件、指标、JSON、事件、日志

    is_initialized = true;
}

/// 初始化 ORM 数据库连接
///
/// 创建数据库连接并初始化 ORM 模型。
/// 如果初始化失败，会自动清理已分配的资源。
/// 设置所有权为 owned，表示由全局模块负责清理。
fn initOrmDatabase() !void {
    logger.info("[global] 正在连接数据库...", .{});

    // 使用 page_allocator 创建数据库连接
    const allocator = std.heap.page_allocator;

    const db = try allocator.create(sql.Database);
    errdefer allocator.destroy(db);

    // db.* = try sql.Database.mysql(allocator, .{
    //     .port = 3306,
    //     .host = "117.72.107.213",
    //     .user = "zigcms",
    //     .password = "zigcms",
    //     .database = "zigcms",
    //     .keepalive_interval_ms = 0, // 暂时禁用 keepalive 避免线程问题
    // });

    db.* = sql.Database.sqlite(allocator, "zigcms.db") catch |e| {
        return e;
    };
    errdefer db.deinit();

    // 初始化所有 ORM 模型
    orm_models.init(db);

    // 执行模型迁移，创建数据表
    orm_models.migrate(db) catch |e| {
        logger.err("[global] 模型迁移失败: {}", .{e});
        return e;
    };

    // 所有初始化成功后，保存数据库连接，并标记为 owned
    _db = db;
    _db_ownership = .owned;

    logger.info("[global] ORM 数据库连接成功!", .{});
}

/// 初始化服务管理器
///
/// 创建并初始化服务管理器，包括缓存服务、字典服务和插件系统。
/// 依赖：必须先初始化数据库连接 (_db)
fn initServiceManager(allocator: Allocator) !void {
    logger.info("[global] 初始化服务管理器...", .{});

    if (_db == null) return error.DatabaseNotInitialized;

    // 加载配置（包括环境变量覆盖）
    const config_loader = @import("../config/config_loader.zig").ConfigLoader;
    const system_config = try config_loader.loadInfraConfig(allocator);

    // 调试：检查环境变量是否被正确读取
    if (std.posix.getenv("ZIGCMS_API_PORT")) |port_val| {
        std.debug.print("🔧 环境变量 ZIGCMS_API_PORT 已设置: {s}\n", .{port_val});
    } else {
        std.debug.print("⚠️ 环境变量 ZIGCMS_API_PORT 未设置，使用默认值\n", .{});
    }

    // 调试：显示最终配置的端口
    std.debug.print("🔧 最终配置端口: {d}\n", .{system_config.api.port});

    const service_mgr = try allocator.create(services.ServiceManager);
    errdefer allocator.destroy(service_mgr);

    service_mgr.* = try services.ServiceManager.init(allocator, _db.?, system_config);

    _service_manager = service_mgr;
    _service_manager_ownership = .owned;

    logger.info("[global] 服务管理器初始化完成", .{});
}

/// 初始化全局模块（使用外部数据库连接）
///
/// 设置全局数据库连接。
/// 注意：此函数不再创建数据库连接，而是使用外部提供的连接。
/// 数据库所有权为 borrowed，不会在 deinit 中清理。
///
/// 参数：
/// - allocator: 全局使用的内存分配器
/// - db: 外部提供的数据库连接（由 root.zig 创建）
///
/// 线程安全：使用mutex保护
pub fn initWithDb(allocator: Allocator, db: *sql.Database) void {
    mu.lock();
    defer mu.unlock();

    if (is_initialized) return;

    _db = db;
    _db_ownership = .borrowed;

    // 初始化配置
    config = std.StringHashMap([]const u8).init(allocator);

    // 初始化所有 ORM 模型
    orm_models.init(db);

    is_initialized = true;
    logger.info("[global] 全局模块初始化完成（使用外部数据库连接）", .{});
}

/// 初始化全局模块（旧版本，创建自己的数据库连接）
/// @deprecated 请使用 initWithDb 代替
///
/// 设置全局分配器并触发一次性初始化。
/// 初始化顺序：日志器 → 数据库 → 服务管理器
/// 数据库所有权为 owned，会在 deinit 中清理。
///
/// 参数：
/// - allocator: 全局使用的内存分配器
///
/// 线程安全：使用mutex保护
pub fn init(allocator: Allocator) void {
    mu.lock();
    defer mu.unlock();

    if (is_initialized) return;

    // 注意：allocator 不再存储，从 ServiceManager 获取
    _ = allocator;
    init_some();
}

/// 获取全局分配器
///
/// 返回：全局内存分配器
/// 注意：必须先调用 init() 初始化，并且 ServiceManager 必须已创建
pub fn get_allocator() Allocator {
    if (_service_manager) |sm| {
        return sm.getAllocator();
    }
    @panic("Service manager not initialized, cannot get allocator");
}

/// 获取 ORM 数据库连接
///
/// 返回：数据库连接指针
/// 注意：如果数据库未初始化会 panic
pub fn get_db() *sql.Database {
    return _db orelse @panic("ORM database not initialized");
}

/// 设置服务管理器引用
///
/// 参数：
/// - sm: 由 root.zig 持有生命周期的服务管理器指针
///
/// 注意：
/// - 仅保存借用引用，不接管所有权
/// - 线程安全：使用 mutex 保护
pub fn setServiceManager(sm: *services.ServiceManager) void {
    mu.lock();
    defer mu.unlock();
    _service_manager = sm;
    _service_manager_ownership = .borrowed;
}

/// 获取服务管理器
///
/// 返回：服务管理器指针（可空）
/// 注意：未初始化时返回 null，由调用方决定处理方式
pub fn getServiceManager() ?*services.ServiceManager {
    return _service_manager;
}

/// 获取插件系统服务
///
/// 返回：插件系统服务指针
/// 注意：如果服务管理器未初始化会 panic
pub fn getPluginSystem() *services.PluginSystemService {
    return getServiceManager().?.getPluginSystemService();
}

// get_container 已弃用，使用 getServiceManager() 代替

/// 获取配置项（直接返回 config 中存储的值或默认值）
///
/// 线程安全：使用 mutex 保护
///
/// 参数：
/// - key: 配置项键名
/// - def_value: 默认值（如果键不存在）
///
/// 返回：配置值或默认值
pub fn get_setting(key: []const u8, def_value: []const u8) []const u8 {
    mu.lock();
    defer mu.unlock();

    // 直接返回 config 中的值，无需拷贝（config 生命周期与程序一致）
    return config.get(key) orelse def_value;
}

/// 检查值是否为 false
pub fn is_false(comptime T: type, val: T) bool {
    if (T == bool) { // 可以直接判断类型是否满足
        return !val;
    }

    return false;
}

pub fn restore_setting() !void {
    mu.lock();
    defer mu.unlock();
    return;

    // const sql = try strings.sprinf("SELECT * FROM {s}", .{base.get_table_name(models.Setting)});
    // var result = try get_pg_pool().queryOpts(sql, .{}, .{ .column_names = true });

    // defer result.deinit();
    // const mapper = result.mapper(models.Setting, .{ .allocator = _allocator.? });
    // config.clearAndFree();

    // while (try mapper.next()) |item| {
    //     try config.put(
    //         item.key,
    //         item.value,
    //     );
    // }
}

/// 动态将结构体转换为对应字段数量的元组
pub inline fn struct_2_tuple(T: type) type {
    const Type = std.builtin.Type;

    const fields: [std.meta.fields(T).len - 1]Type.StructField = blk: {
        var res: [std.meta.fields(T).len - 1]Type.StructField = undefined;

        var i: usize = 0;
        inline for (std.meta.fields(T)) |field| {
            if (!std.mem.eql(u8, field.name, "id")) {
                res[i] = Type.StructField{
                    .type = field.type,
                    .alignment = @alignOf(field.type),
                    .default_value = field.default_value,
                    .is_comptime = false,
                    .name = std.fmt.comptimePrint("{}", .{i}),
                };
                i += 1;
            }
        }
        break :blk res;
    };

    return @Type(.{
        .Struct = std.builtin.Type.Struct{
            .layout = .auto,
            .is_tuple = true,
            .decls = &.{},
            .fields = &fields,
        },
    });
}
