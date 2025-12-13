//! 全局模块 - 系统级服务管理器
//!
//! 该模块管理全局性的组件和服务：
//! - 内存分配器
//! - 数据库连接
//! - 服务管理器
//! - 插件系统
//! - 配置管理

const std = @import("std");
const Allocator = std.mem.Allocator;
const pretty = @import("pretty");
const models = @import("../../domain/entities/models.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const strings = @import("../../shared/utils/strings.zig");
const base = @import("../../api/controllers/base.fn.zig");
const services = @import("../../application/services/services.zig");
const sql = @import("../../application/services/sql/orm.zig");
const PluginSystemService = @import("../../application/services/plugins/plugin_system.zig").PluginSystemService;
pub const logger = @import("../../application/services/logger/logger.zig");

// 全局单例实例
var _allocator: ?Allocator = null;
var _db: ?*sql.Database = null;
var _service_manager: ?*services.ServiceManager = null;
var _plugin_system: ?*PluginSystemService = null;
var config: std.StringHashMap([]const u8) = undefined;
var mu: std.Thread.Mutex = std.Thread.Mutex{};

pub const JwtTokenSecret = "this is a secret";
var initOnce = std.once(init_some);

pub fn deinit() void {
    logger.info("global module deinit, cleaning up resources...", .{});

    // 1. 先执行插件系统清理
    if (_plugin_system) |plugin_sys| {
        plugin_sys.shutdown() catch {};
        _allocator.?.destroy(plugin_sys);
        _plugin_system = null;
    }

    // 2. 清理服务管理器
    if (_service_manager) |sm| {
        sm.deinit();
        _allocator.?.destroy(sm);
        _service_manager = null;
    }

    // 3. 清理 ORM 数据库连接
    if (_db) |db| {
        db.deinit();
        _allocator.?.destroy(db);
        _db = null;
    }

    // 4. 清理日志器
    logger.deinitDefault();

    // 5. 清理配置
    config.deinit();
    config = undefined;
    _allocator = undefined;

    std.debug.print("[INFO] global module cleanup completed\n", .{});
}

fn init_some() void {
    config = std.StringHashMap([]const u8).init(_allocator.?);

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

    logger.info("[global] 开始初始化全局模块...", .{});
    logger.info("[global] 准备初始化 ORM 数据库连接...", .{});

    // 初始化 SQL ORM 数据库连接（使用配置文件中的密码）
    initOrmDatabase() catch |e| {
        logger.err("[global] 初始化 ORM 数据库失败: {}", .{e});
        @panic("无法初始化数据库连接，请检查数据库配置和网络连接");
    };

    // 初始化服务管理器
    initServiceManager(_allocator.?) catch |e| {
        logger.err("Failed to initialize Service Manager: {}", .{e});
    };

    // 初始化插件系统
    initPluginSystem(_allocator.?) catch |e| {
        logger.err("Failed to initialize Plugin System: {}", .{e});
    };

    restore_setting() catch {};
}

/// 初始化 ORM 数据库连接
fn initOrmDatabase() !void {
    logger.info("[global] 正在连接 MySQL 数据库...", .{});

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

    db.* = try sql.Database.sqlite(_allocator.?, "zigcms.db");

    _db = db;

    // 初始化所有 ORM 模型
    orm_models.init(db);

    // 执行模型迁移，创建数据表
    orm_models.migrate(db) catch |e| {
        logger.err("[global] 模型迁移失败: {}", .{e});
        @panic("无法执行模型迁移，请检查数据库权限或配置");
    };

    logger.info("[global] ORM 数据库连接成功!", .{});
}

/// 初始化服务管理器
fn initServiceManager(allocator: Allocator) !void {
    logger.info("[global] 初始化服务管理器...", .{});

    if (_db == null) return error.DatabaseNotInitialized;

    const service_mgr = try allocator.create(services.ServiceManager);
    errdefer allocator.destroy(service_mgr);

    service_mgr.* = try services.ServiceManager.init(allocator, _db.?);

    _service_manager = service_mgr;

    logger.info("[global] 服务管理器初始化完成", .{});
}

/// 初始化插件系统
fn initPluginSystem(allocator: Allocator) !void {
    logger.info("[global] 初始化插件系统...", .{});

    if (_service_manager == null) return error.ServiceManagerNotInitialized;

    const plugin_sys_instance = try allocator.create(PluginSystemService);
    errdefer allocator.destroy(plugin_sys_instance);

    plugin_sys_instance.* = PluginSystemService.init(allocator);

    // 启动插件系统
    try plugin_sys_instance.startup();

    _plugin_system = plugin_sys_instance;

    logger.info("[global] 插件系统初始化完成", .{});
}

pub fn init(allocator: Allocator) void {
    _allocator = allocator;
    initOnce.call();
}

pub fn get_allocator() Allocator {
    return _allocator.?;
}

/// 获取 ORM 数据库连接
pub fn get_db() *sql.Database {
    return _db orelse @panic("ORM database not initialized");
}

/// 获取服务管理器
pub fn getServiceManager() *services.ServiceManager {
    return _service_manager orelse @panic("Service manager not initialized");
}

/// 获取插件系统服务
pub fn getPluginSystem() *PluginSystemService {
    return _plugin_system orelse @panic("Plugin system not initialized");
}

// get_container 已弃用，使用 getServiceManager() 代替

/// 获取配置项（直接返回 config 中存储的值或默认值）
pub fn get_setting(key: []const u8, def_value: []const u8) []const u8 {
    mu.lock();
    defer mu.unlock();

    // 直接返回 config 中的值，无需拷贝（config 生命周期与程序一致）
    return config.get(key) orelse def_value;
}

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
