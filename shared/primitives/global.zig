const std = @import("std");
const Allocator = std.mem.Allocator;
const pretty = @import("pretty");
const models = @import("../../domain/entities/models.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const strings = @import("../../shared/utils/strings.zig");
const base = @import("../../api/controllers/base.fn.zig");
const services = @import("../../application/services/services.zig");
const sql = @import("../../application/services/sql/orm.zig");

var _allocator: ?Allocator = null;
var _db: ?*sql.Database = null;
var _di_container: ?services.Container = null;
var config: std.StringHashMap([]const u8) = undefined;
var mu: std.Thread.Mutex = std.Thread.Mutex{};

pub const JwtTokenSecret = "this is a secret";
var initOnce = std.once(init_some);

pub fn deinit() void {
    std.log.info("global module deinit, cleaning up resources...", .{});

    // 1. 先执行 DI 容器的清理
    if (_di_container) |*c| {
        c.deinit();
        _di_container = null;
    }

    // 2. 清理 ORM 数据库连接
    if (_db) |db| {
        db.deinit();
        _allocator.?.destroy(db);
        _db = null;
    }

    // 3. 清理配置
    config.deinit();
    config = undefined;
    _allocator = undefined;

    std.log.info("global module cleanup completed", .{});
}

fn init_some() void {
    config = std.StringHashMap([]const u8).init(_allocator.?);
    const password = std.process.getEnvVarOwned(_allocator.?, "DB_PASSWORD") catch unreachable;
    defer _allocator.?.free(password);

    // 初始化 SQL ORM 数据库连接
    initOrmDatabase(password) catch |e| {
        std.log.err("Failed to initialize ORM database: {}", .{e});
    };

    // 初始化 DI 容器
    initDiContainer(_allocator.?);

    restore_setting() catch {};
}

/// 初始化 ORM 数据库连接
fn initOrmDatabase(_: []const u8) !void {
    const db = try _allocator.?.create(sql.Database);
    errdefer _allocator.?.destroy(db);

    db.* = try sql.Database.sqlite(_allocator.?, "database.sqlite3");

    _db = db;

    // 初始化所有 ORM 模型
    orm_models.init(db);

    std.log.info("ORM database initialized successfully", .{});
}

/// 初始化 DI 容器
fn initDiContainer(allocator: Allocator) void {
    std.log.info("[global] 初始化 DI 容器...", .{});

    // 使用现有的 services 模块创建容器
    _di_container = services.createContainer(allocator);

    std.log.info("[global] DI 容器初始化完成", .{});
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

/// 获取 DI 容器
pub fn get_container() *services.Container {
    return &_di_container.?;
}

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

const std = @import("std");
const Allocator = std.mem.Allocator;
const pretty = @import("pretty");
const models = @import("../../domain/entities/models.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const strings = @import("../../shared/utils/strings.zig");
const base = @import("../../api/controllers/base.fn.zig");
const services = @import("../../application/services/services.zig");
const sql = @import("../../application/services/sql/orm.zig");

var _allocator: ?Allocator = null;
var _db: ?*sql.Database = null;
var _di_container: ?services.Container = null;
var _service_manager: ?*services.ServiceManager = null;
var config: std.StringHashMap([]const u8) = undefined;
var mu: std.Thread.Mutex = std.Thread.Mutex{};

pub const JwtTokenSecret = "this is a secret";
var initOnce = std.once(init_some);

pub fn deinit() void {
    std.log.info("global module deinit, cleaning up resources...", .{});

    // 1. 先执行 DI 容器的清理
    if (_di_container) |*c| {
        c.deinit();
        _di_container = null;
    }

    // 2. 清理 Service Manager
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

    // 4. 清理配置
    config.deinit();
    config = undefined;
    _allocator = undefined;

    std.log.info("global module cleanup completed", .{});
}

fn init_some() void {
    config = std.StringHashMap([]const u8).init(_allocator.?);
    const password = std.process.getEnvVarOwned(_allocator.?, "DB_PASSWORD") catch unreachable;
    defer _allocator.?.free(password);

    // 初始化 SQL ORM 数据库连接
    initOrmDatabase(password) catch |e| {
        std.log.err("Failed to initialize ORM database: {}", .{e});
    };

    // 初始化 DI 容器
    initDiContainer(_allocator.?);

    // 初始化 Service Manager
    initServiceManager(_allocator.?) catch |e| {
        std.log.err("Failed to initialize Service Manager: {}", .{e});
    };

    restore_setting() catch {};
}

/// 初始化 ORM 数据库连接
fn initOrmDatabase(_: []const u8) !void {
    const db = try _allocator.?.create(sql.Database);
    errdefer _allocator.?.destroy(db);

    db.* = try sql.Database.sqlite(_allocator.?, "database.sqlite3");

    _db = db;

    // 初始化所有 ORM 模型
    orm_models.init(db);

    std.log.info("ORM database initialized successfully", .{});
}

/// 初始化服务管理器
fn initServiceManager(allocator: Allocator) !void {
    std.log.info("[global] 初始化服务管理器...", .{});

    // 创建服务管理器实例
    const service_mgr = try allocator.create(services.ServiceManager);
    errdefer allocator.destroy(service_mgr);

    service_mgr.* = try services.ServiceManager.init(allocator, _db.?);

    _service_manager = service_mgr;

    std.log.info("[global] 服务管理器初始化完成", .{});
}

/// 初始化 DI 容器
fn initDiContainer(allocator: Allocator) void {
    std.log.info("[global] 初始化 DI 容器...", .{});

    // 使用现有的 services 模块创建容器
    _di_container = services.createContainer(allocator);

    std.log.info("[global] DI 容器初始化完成", .{});
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

/// 获取 DI 容器
pub fn get_container() *services.Container {
    return &_di_container.?;
}

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

// 动态结构体定义 https://github.com/ziglang/zig/issues/12330
// https://github.com/ziglang/zig/issues/4335 提案
// const T = @Type(.{
//     .Struct = .{
//         .layout = .Packed,
//         .fields = &.{
//             .{ .name = "0", .field_type = u2, .default_value = null, .is_comptime = false, .alignment = 0 },
//             .{ .name = "1", .field_type = u2, .default_value = null, .is_comptime = false, .alignment = 0 },
//             .{ .name = "2", .field_type = u2, .default_value = null, .is_comptime = false, .alignment = 0 },
//             .{ .name = "3", .field_type = u2, .default_value = null, .is_comptime = false, .alignment = 0 },
//         },
//         .decls = &.{},
//         .is_tuple = true,
//     },
// });


// const ArgTuple = struct {
//     tuple: anytype = .{},
// };
// var arg_list = ArgTuple{};
// for (args) |arg| {
//     if (@TypeOf(arg) == ?u21) {
//         if (arg) |cp| {
//             arg_list.tuple = arg_list.tuple ++ .{ctUtf8EncodeChar(cp)};
//         } else {
//             arg_list.tuple = arg_list.tuple ++ .{"null"};
//         }
//     } else if (@TypeOf(arg) == u21) {
//         arg_list.tuple = arg_list.tuple ++ .{ctUtf8EncodeChar(arg)};
//     } else {
//         arg_list.tuple = arg_list.tuple ++ .{arg};
//     }
// }

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
