//! 泛型仓储模块
//!
//! 提供类似 Go GORM 的简洁 CRUD 接口，解决 Zig 泛型控制器的痛点。
//!
//! ## 设计思路
//!
//! 由于 Zig 的编译期特性，Repository 使用泛型 Pool 类型参数，
//! 避免类型擦除带来的运行时开销。

const std = @import("std");
const entity = @import("entity.zig");

/// 分页结果
pub fn PageResult(comptime T: type) type {
    return struct {
        items: []T,
        total: u64,
        page: u32,
        limit: u32,
        allocator: std.mem.Allocator,

        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.items);
        }
    };
}

/// 泛型仓储工厂
///
/// 使用示例：
/// ```zig
/// // 在 global.zig 中定义
/// pub const UserRepo = orm.RepositoryFn(User, "zigcms", PgPool);
///
/// // 使用
/// var repo = UserRepo.init(pool, allocator);
/// const id = try repo.create(&user);
/// ```
pub fn RepositoryFn(comptime T: type, comptime schema: []const u8, comptime Pool: type) type {
    return struct {
        const Self = @This();
        const Meta = entity.EntityMeta(T);

        pool: *Pool,
        allocator: std.mem.Allocator,

        // 编译期生成的 SQL
        pub const INSERT_SQL = Meta.insertSQL(schema);
        pub const UPDATE_SQL = Meta.updateSQL(schema);
        pub const SELECT_SQL = Meta.selectSQL(schema);
        pub const DELETE_SQL = Meta.deleteSQL(schema);

        pub fn init(pool: *Pool, allocator: std.mem.Allocator) Self {
            return .{ .pool = pool, .allocator = allocator };
        }

        /// 创建实体，返回新 ID
        pub fn create(self: *Self, e: *T) !i32 {
            Meta.setTimestamps(e, true);
            const params = Meta.toParams(e.*);

            var row = (try self.pool.rowOpts(INSERT_SQL, params, .{ .column_names = true })) orelse
                return error.InsertFailed;
            defer row.deinit() catch {};

            const result = try row.to(struct { id: i32 }, .{});
            @field(e, "id") = result.id;
            return result.id;
        }

        /// 通过 ID 查询
        pub fn findById(self: *Self, id: i32) !?T {
            const sql = SELECT_SQL ++ " WHERE id = $1";
            var row = (try self.pool.rowOpts(sql, .{id}, .{ .column_names = true })) orelse
                return null;
            defer row.deinit() catch {};
            return try row.to(T, .{ .map = .name, .allocator = self.allocator });
        }

        /// 更新实体
        pub fn update(self: *Self, e: *T) !bool {
            Meta.setTimestamps(e, false);
            const id = Meta.getId(e.*) orelse return error.MissingId;
            const params = Meta.toParams(e.*);
            const affected = try self.pool.exec(UPDATE_SQL, params ++ .{id});
            return affected != null and affected.? > 0;
        }

        /// 删除
        pub fn deleteById(self: *Self, id: i32) !bool {
            const affected = try self.pool.exec(DELETE_SQL, .{id});
            return affected != null and affected.? > 0;
        }

        /// 批量删除
        pub fn deleteByIds(self: *Self, ids: []const i32) !usize {
            var count: usize = 0;
            for (ids) |id| {
                const affected = try self.pool.exec(DELETE_SQL, .{id});
                if (affected != null and affected.? > 0) count += 1;
            }
            return count;
        }

        /// 保存（自动判断 insert/update）
        pub fn save(self: *Self, e: *T) !i32 {
            if (Meta.getId(e.*)) |id| {
                if (id > 0) {
                    _ = try self.update(e);
                    return id;
                }
            }
            return try self.create(e);
        }

        /// 分页查询
        pub fn findPage(
            self: *Self,
            page: u32,
            limit: u32,
            order_by: []const u8,
            order: []const u8,
        ) !PageResult(T) {
            // 查询总数
            const count_sql = "SELECT COUNT(*) as total FROM " ++ schema ++ "." ++ comptime lowerStr(Meta.table_name);
            var count_row = (try self.pool.row(count_sql, .{})) orelse return error.QueryFailed;
            defer count_row.deinit() catch {};
            const count_result = try count_row.to(struct { total: i64 }, .{});

            // 查询数据
            const offset = (page - 1) * limit;
            const query = try std.fmt.allocPrint(
                self.allocator,
                SELECT_SQL ++ " ORDER BY {s} {s} OFFSET $1 LIMIT $2",
                .{ order_by, order },
            );
            defer self.allocator.free(query);

            var result = try self.pool.queryOpts(query, .{ offset, limit }, .{ .column_names = true });
            defer result.deinit();

            var items = std.ArrayList(T).init(self.allocator);
            const mapper = result.mapper(T, .{ .allocator = self.allocator });
            while (try mapper.next()) |item| {
                try items.append(item);
            }

            return PageResult(T){
                .items = try items.toOwnedSlice(),
                .total = @intCast(count_result.total),
                .page = page,
                .limit = limit,
                .allocator = self.allocator,
            };
        }

        /// 查询所有
        pub fn findAll(self: *Self) ![]T {
            var result = try self.pool.queryOpts(SELECT_SQL, .{}, .{ .column_names = true });
            defer result.deinit();

            var items = std.ArrayList(T).init(self.allocator);
            const mapper = result.mapper(T, .{ .allocator = self.allocator });
            while (try mapper.next()) |item| {
                try items.append(item);
            }
            return try items.toOwnedSlice();
        }

        /// 执行原生 SQL
        pub fn execRaw(self: *Self, sql: []const u8, params: anytype) !?i64 {
            return try self.pool.exec(sql, params);
        }

        fn lowerStr(comptime s: []const u8) []const u8 {
            comptime {
                var lower: [s.len]u8 = undefined;
                for (s, 0..) |c, i| {
                    lower[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
                }
                return &lower;
            }
        }
    };
}
