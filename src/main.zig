const std = @import("std");
const zap = @import("zap");
const pretty = @import("pretty");
const Allocator = std.mem.Allocator;

const global = @import("global/global.zig");
const controllers = @import("./controllers/controllers.zig");
const base = @import("./controllers/base.fn.zig");
const models = @import("./models/models.zig");

const FnParam = std.builtin.Type.Fn.Param;

/// generate a fuction's param tuple
pub fn FnParamsToTuple(comptime params: []const FnParam) type {
    const Type = std.builtin.Type;
    const fields: [params.len]Type.StructField = blk: {
        var res: [params.len]Type.StructField = undefined;

        for (params, 0..params.len) |param, i| {
            if (param.type) |t| {
                res[i] = Type.StructField{
                    .type = t,
                    .alignment = @alignOf(t),
                    .default_value = null,
                    .is_comptime = false,
                    .name = std.fmt.comptimePrint("{}", .{i}),
                };
            } else {
                const error_message = std.fmt.comptimePrint(
                    "sorry the param is anytype!",
                    .{param},
                );
                @compileError(error_message);
            }
        }
        break :blk res;
    };
    return @Type(.{
        .Struct = std.builtin.Type.Struct{
            .layout = .Auto,
            .is_tuple = true,
            .decls = &.{},
            .fields = &fields,
        },
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    global.set_allocator(allocator);

    const sql = try base.build_insert_sql(models.Admin, allocator);
    defer allocator.free(sql);

    // var pool = try global.get_pg_pool();

    const admin = models.Admin{
        .username = "admin",
        .password = "123456",
    };

    std.log.debug("{?}", .{admin});

    // try pool.exec(sql, structToTuple(admin));

    var simpleRouter = zap.Router.init(allocator, .{});
    defer simpleRouter.deinit();

    var login = controllers.Login.init(allocator);
    try simpleRouter.handle_func("/login", &login, &controllers.Login.login);
    try simpleRouter.handle_func("/register", &login, &controllers.Login.register);

    var public = controllers.Public.init(allocator);
    try simpleRouter.handle_func("/public/upload", &public, &controllers.Public.upload);

    var menu = controllers.Menu.init(allocator);
    try simpleRouter.handle_func("/menu/list", &menu, &controllers.Menu.list);

    var setting = controllers.Setting.init(allocator);
    try simpleRouter.handle_func("/setting/get", &setting, &controllers.Setting.get);
    try simpleRouter.handle_func("/setting/save", &setting, &controllers.Setting.save);

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = simpleRouter.on_request_handler(),
        .log = false,
        .public_folder = "resources",
        .max_clients = 10000,
    });
    zap.enableDebugLog();
    try listener.listen();
    zap.start(.{ .threads = 2, .workers = 2 });
}
