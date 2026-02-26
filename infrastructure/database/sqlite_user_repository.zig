//! SQLite 用户仓储实现 (SQLite User Repository Implementation)
//!
//! 基础设施层用户仓储的具体实现，使用SQLite数据库。
//! 实现领域层定义的UserRepository接口。

const std = @import("std");
const sql = @import("../../application/services/sql/orm.zig");
const UserData = @import("../../domain/entities/user.model.zig").UserData;
const UserRepository = @import("../../domain/repositories/user_repository.zig").UserRepository;

/// SQLite 用户仓储实现
///
/// 实现UserRepository接口，负责用户数据的持久化。
/// 使用项目的ORM模块与SQLite数据库交互。
pub const SqliteUserRepository = struct {
    allocator: std.mem.Allocator,
    db: *sql.Database,

    /// 初始化SQLite用户仓储
    pub fn init(allocator: std.mem.Allocator, db: *sql.Database) SqliteUserRepository {
        return .{
            .allocator = allocator,
            .db = db,
        };
    }

    /// 实现findById方法
    pub fn findById(ptr: *anyopaque, id: i32) !?UserData {
        const self: *SqliteUserRepository = @ptrCast(@alignCast(ptr));

        // 使用Database.rawQuery查询用户
        const query = "SELECT id, username, email, nickname, avatar, status, create_time, update_time FROM users WHERE id = ? AND is_delete = 0";
        var result_set = try self.db.rawQuery(query, .{id});
        defer result_set.deinit();

        if (!result_set.next()) {
            return null;
        }

        // 构建UserData实体
        return UserData{
            .id = try result_set.get(i32, 0),
            .username = try self.allocator.dupe(u8, try result_set.get([]const u8, 1)),
            .email = try self.allocator.dupe(u8, try result_set.get([]const u8, 2)),
            .nickname = try self.allocator.dupe(u8, try result_set.get([]const u8, 3)),
            .avatar = try self.allocator.dupe(u8, try result_set.get([]const u8, 4)),
            .status = @enumFromInt(try result_set.get(i32, 5)),
            .create_time = try result_set.get(?i64, 6),
            .update_time = try result_set.get(?i64, 7),
        };
    }

    /// 实现findAll方法
    pub fn findAll(ptr: *anyopaque) ![]UserData {
        const self: *SqliteUserRepository = @ptrCast(@alignCast(ptr));

        // 查询所有未删除的用户
        const query = "SELECT id, username, email, nickname, avatar, status, create_time, update_time FROM users WHERE is_delete = 0 ORDER BY create_time DESC";
        var result_set = try self.db.rawQuery(query, .{});
        defer result_set.deinit();

        // 转换为UserData数组
        var users = try std.ArrayList(UserData).initCapacity(self.allocator, 16);
        defer users.deinit(self.allocator);

        while (result_set.next()) {
            const user = UserData{
                .id = try result_set.get(i32, 0),
                .username = try self.allocator.dupe(u8, try result_set.get([]const u8, 1)),
                .email = try self.allocator.dupe(u8, try result_set.get([]const u8, 2)),
                .nickname = try self.allocator.dupe(u8, try result_set.get([]const u8, 3)),
                .avatar = try self.allocator.dupe(u8, try result_set.get([]const u8, 4)),
                .status = @enumFromInt(try result_set.get(i32, 5)),
                .create_time = try result_set.get(?i64, 6),
                .update_time = try result_set.get(?i64, 7),
            };
            try users.append(self.allocator, user);
        }

        return users.toOwnedSlice(self.allocator);
    }

    /// 实现save方法
    pub fn save(ptr: *anyopaque, user: UserData) !UserData {
        const self: *SqliteUserRepository = @ptrCast(@alignCast(ptr));

        // 检查是否为新用户
        const is_new = user.id == null;

        if (is_new) {
            // 插入新用户
            const insert_query = "INSERT INTO users (username, email, nickname, avatar, status, create_time, update_time, is_delete) VALUES (?, ?, ?, ?, ?, ?, ?, 0)";
            const now = std.time.timestamp();
            _ = try self.db.rawExec(insert_query, .{
                user.username,
                user.email,
                user.nickname,
                user.avatar,
                user.status,
                now,
                now,
            });

            // 获取插入的ID
            const last_id = self.db.lastInsertId();

            // 返回包含ID的用户
            return UserData{
                .id = @as(i32, @intCast(last_id)),
                .username = try self.allocator.dupe(u8, user.username),
                .email = try self.allocator.dupe(u8, user.email),
                .nickname = try self.allocator.dupe(u8, user.nickname),
                .avatar = try self.allocator.dupe(u8, user.avatar),
                .status = user.status,
                .create_time = now,
                .update_time = now,
            };
        } else {
            // 更新现有用户
            const update_query = "UPDATE users SET username = ?, email = ?, nickname = ?, avatar = ?, status = ?, update_time = ? WHERE id = ? AND is_delete = 0";
            const now = std.time.timestamp();
            _ = try self.db.rawExec(update_query, .{
                user.username,
                user.email,
                user.nickname,
                user.avatar,
                user.status,
                now,
                user.id.?,
            });

            // 返回更新后的用户
            return UserData{
                .id = user.id,
                .username = try self.allocator.dupe(u8, user.username),
                .email = try self.allocator.dupe(u8, user.email),
                .nickname = try self.allocator.dupe(u8, user.nickname),
                .avatar = try self.allocator.dupe(u8, user.avatar),
                .status = user.status,
                .create_time = user.create_time,
                .update_time = now,
            };
        }
    }

    /// 实现update方法
    pub fn update(ptr: *anyopaque, user: UserData) !void {
        const self: *SqliteUserRepository = @ptrCast(@alignCast(ptr));

        if (user.id == null) {
            return error.InvalidUserId;
        }

        const query = "UPDATE users SET username = ?, email = ?, nickname = ?, avatar = ?, status = ?, update_time = ? WHERE id = ? AND is_delete = 0";
        const now = std.time.timestamp();
        _ = try self.db.rawExec(query, .{
            user.username,
            user.email,
            user.nickname,
            user.avatar,
            user.status,
            now,
            user.id.?,
        });
    }

    /// 实现delete方法（软删除）
    pub fn delete(ptr: *anyopaque, id: i32) !void {
        const self: *SqliteUserRepository = @ptrCast(@alignCast(ptr));

        const query = "UPDATE users SET is_delete = 1, update_time = ? WHERE id = ? AND is_delete = 0";
        const now = std.time.timestamp();
        _ = try self.db.rawExec(query, .{ now, id });
    }

    /// 实现count方法
    pub fn count(ptr: *anyopaque) !usize {
        const self: *SqliteUserRepository = @ptrCast(@alignCast(ptr));

        const query = "SELECT COUNT(*) as count FROM users WHERE is_delete = 0";
        var result_set = try self.db.rawQuery(query, .{});
        defer result_set.deinit();

        if (!result_set.next()) {
            return 0;
        }

        return @as(usize, @intCast(try result_set.get(i64, 0)));
    }

    /// 创建vtable（供UserRepository使用）
    pub fn vtable() UserRepository.VTable {
        return .{
            .findById = findById,
            .findAll = findAll,
            .save = save,
            .update = update,
            .delete = delete,
            .count = count,
        };
    }
};
