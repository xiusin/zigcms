//! 全局模块 - 系统级服务管理器
//!
//! 该模块管理全局性的组件和服务：
//! - 内存分配器
//! - 数据库连接
//! - 服务管理器
//! - 插件系统
//! - 配置管理
//!
//! 内存所有权说明：
//! - _allocator: 由调用者提供，全局模块只持有引用
//! - _db: 由全局模块创建和拥有，在 deinit 中释放
//! - _service_manager: 由全局模块创建和拥有，在 deinit 中释放
//! - _plugin_system: 由全局模块创建和拥有，在 deinit 中释放
//! - config: 由全局模块创建和拥有，在 deinit 中释放
//!
//! 初始化顺序：
//! 1. 日志器
//! 2. ORM 数据库连接
//! 3. 服务管理器
//! 4. 插件系统
//!
//! 清理顺序（逆序）：
//! 1. 插件系统
//! 2. 服务管理器
//! 3. ORM 数据库连接
//! 4. 日志器
//! 5. 配置

const std = @import("std");
const Allocator = std.mem.Allocator;
const pretty = @import("pretty");
const models = @import("../../domain/entities/models.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const strings = @import("../../shared/utils/strings.zig");
const base = @import("../../api/controllers/base.fn.zig");
const services = @import("../../application/services/mod.zig");
const sql = @import("../../application/services/sql/orm.zig");
// const PluginSystemService = @import("../../application/services/plugins/plugin_system.zig").PluginSystemService;
const PluginSystemService = struct {};
pub const logger = @import("../../application/services/logger/logger.zig");
const root = @import("../../root.zig");

// 资源所有权模式
const ResourceOwnership = enum {
    owned,
    borrowed,
};

// 全局单例实例
var _allocator: ?Allocator = null;
var _db: ?*sql.Database = null;
var _db_ownership: ResourceOwnership = .borrowed;
var _service_manager: ?*services.ServiceManager = null;
var _plugin_system: ?*PluginSystemService = null;
var config: std.StringHashMap([]const u8) = undefined;
var mu: std.Thread.Mutex = std.Thread.Mutex{};

pub const JwtTokenSecret = "this is a secret";
var is_initialized: bool = false;

/// 清理全局模块资源
///
/// 清理顺序（与初始化相反）：
/// 1. 插件系统（最后初始化，最先清理）
/// 2. 服务管理器
/// 3. 数据库（如果owned）
/// 4. 配置
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

    // 1. 先执行插件系统清理（独立于 ServiceManager 的插件系统实例）
    if (_plugin_system) |plugin_sys| {
        plugin_sys.shutdown() catch |err| {
            std.debug.print("[ERROR] 插件系统关闭失败: {}\n", .{err});
        };
        plugin_sys.deinit();
        _allocator.?.destroy(plugin_sys);
        _plugin_system = null;
    }

    // 2. 清理服务管理器（ServiceManager 有自己的插件系统实例，会在其 deinit 中清理）
    if (_service_manager) |sm| {
        sm.deinit();
        _allocator.?.destroy(sm);
        _service_manager = null;
    }

    // 3. 根据所有权决定是否清理数据库
    if (_db) |db| {
        if (_db_ownership == .owned) {
            std.debug.print("[INFO] global module deinit: cleaning owned database\n", .{});
            db.deinit();
            _allocator.?.destroy(db);
        } else {
            std.debug.print("[INFO] global module deinit: releasing borrowed database reference\n", .{});
        }
        _db = null;
    }

    // 4. 注意：日志器由 main.zig 管理，不在此处清理

    // 5. 清理配置
    config.deinit();
    config = undefined;
    _allocator = null;

    // 6. 重置初始化状态，允许重新初始化（用于测试）
    is_initialized = false;
    init_once = std.once.Once{};

    std.debug.print("[INFO] global module cleanup completed\n", .{});
}

fn init_some() void {
    config = std.StringHashMap([]const u8).init(_allocator.?);
    errdefer config.deinit();

    // 首先初始化日志器
    logger.initDefault(_allocator.?, .{
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
        if (_db) |db| {
            db.deinit();
            _allocator.?.destroy(db);
            _db = null;
        }
    }

    // 初始化服务管理器
    initServiceManager(_allocator.?) catch |e| {
        logger.err("Failed to initialize Service Manager: {}", .{e});
        @panic("无法初始化服务管理器");
    };
    errdefer {
        if (_service_manager) |sm| {
            sm.deinit();
            _allocator.?.destroy(sm);
            _service_manager = null;
        }
    }

    // 初始化插件系统
    initPluginSystem(_allocator.?) catch |e| {
        logger.err("Failed to initialize Plugin System: {}", .{e});
        @panic("无法初始化插件系统");
    };

    restore_setting() catch {};

    is_initialized = true;
}

/// 初始化 ORM 数据库连接
///
/// 创建数据库连接并初始化 ORM 模型。
/// 如果初始化失败，会自动清理已分配的资源。
/// 设置所有权为 owned，表示由全局模块负责清理。
fn initOrmDatabase() !void {
    logger.info("[global] 正在连接数据库...", .{});

    const db = try _allocator.?.create(sql.Database);
    errdefer _allocator.?.destroy(db);

    // db.* = try sql.Database.mysql(_allocator.?, .{
    //     .port = 3306,
    //     .host = "117.72.107.213",
    //     .user = "zigcms",
    //     .password = "zigcms",
    //     .database = "zigcms",
    //     .keepalive_interval_ms = 0, // 暂时禁用 keepalive 避免线程问题
    // });

    db.* = sql.Database.sqlite(_allocator.?, "zigcms.db") catch |e| {
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

    logger.info("[global] 服务管理器初始化完成", .{});
}

/// 初始化插件系统
///
/// 创建并启动独立的插件系统实例。
/// 注意：这是独立于 ServiceManager 中插件系统的另一个实例。
/// 依赖：必须先初始化服务管理器 (_service_manager)
fn initPluginSystem(allocator: Allocator) !void {
    logger.info("[global] 初始化插件系统...", .{});

    if (_service_manager == null) return error.ServiceManagerNotInitialized;

    const plugin_sys_instance = try allocator.create(PluginSystemService);
    errdefer allocator.destroy(plugin_sys_instance);

    plugin_sys_instance.* = PluginSystemService.init(allocator);
    errdefer plugin_sys_instance.deinit();

    // 启动插件系统
    try plugin_sys_instance.startup();

    _plugin_system = plugin_sys_instance;

    logger.info("[global] 插件系统初始化完成", .{});
}

/// 初始化全局模块（使用外部数据库连接）
///
/// 设置全局分配器和数据库连接。
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

    _allocator = allocator;
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
/// 初始化顺序：日志器 → 数据库 → 服务管理器 → 插件系统
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

    _allocator = allocator;
    init_some();
}

/// 获取全局分配器
///
/// 返回：全局内存分配器
/// 注意：必须先调用 init() 初始化
pub fn get_allocator() Allocator {
    return _allocator.?;
}

/// 获取 ORM 数据库连接
///
/// 返回：数据库连接指针
/// 注意：如果数据库未初始化会 panic
pub fn get_db() *sql.Database {
    return _db orelse @panic("ORM database not initialized");
}

/// 获取服务管理器
///
/// 返回：服务管理器指针
/// 注意：如果服务管理器未初始化会 panic
pub fn getServiceManager() *services.ServiceManager {
    return _service_manager orelse @panic("Service manager not initialized");
}

/// 获取插件系统服务
///
/// 返回：插件系统服务指针
/// 注意：如果插件系统未初始化会 panic
pub fn getPluginSystem() *PluginSystemService {
    return _plugin_system orelse @panic("Plugin system not initialized");
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
