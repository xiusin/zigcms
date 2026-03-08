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
const models = @import("../../domain/entities/mod.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const strings = @import("../utils/strings.zig");
const base = @import("../../api/controllers/base.fn.zig");
const services = @import("../../application/services/mod.zig");
const sql = @import("../../application/services/sql/orm.zig");
pub const logger = @import("../../application/services/logger/logger.zig");
const root = @import("../../../root.zig");

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
