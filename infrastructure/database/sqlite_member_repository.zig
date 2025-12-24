//! SQLite 会员仓储实现 (SQLite Member Repository Implementation)
//
//! 基础设施层会员仓储的具体实现，使用SQLite数据库。
//! 实现领域层定义的MemberRepository接口。

const std = @import("std");
const sql = @import("../../application/services/sql/orm.zig");
const Member = @import("../../domain/entities/member.model.zig").Member;
const MemberRepository = @import("../../domain/repositories/member_repository.zig").MemberRepository;

/// SQLite 会员仓储实现
///
/// 实现MemberRepository接口，负责会员数据的持久化。
/// 使用项目的ORM模块与SQLite数据库交互。
pub const SqliteMemberRepository = struct {
    allocator: std.mem.Allocator,
    db: *sql.Database,

    /// 初始化SQLite会员仓储
    pub fn init(allocator: std.mem.Allocator, db: *sql.Database) SqliteMemberRepository {
        return .{
            .allocator = allocator,
            .db = db,
        };
    }

    /// 实现findById方法
    pub fn findById(ptr: *anyopaque, id: i32) !?Member {
        const self: *SqliteMemberRepository = @ptrCast(@alignCast(ptr));

        // 使用Database.rawQuery查询会员
        const query = "SELECT id, username, email, mobile, nickname, avatar, gender, birthday, location, signature, group_id, points, experience, level, total_consume, last_login_time, last_login_ip, register_time, register_ip, status, email_verified, mobile_verified, remark, create_time, update_time, is_delete FROM members WHERE id = ? AND is_delete = 0";
        var result_set = try self.db.rawQuery(query, .{id});
        defer result_set.deinit();

        if (!result_set.next()) {
            return null;
        }

        // 构建Member实体
        return Member{
            .id = try result_set.get(i32, 0),
            .username = try self.allocator.dupe(u8, try result_set.get([]const u8, 1)),
            .email = try self.allocator.dupe(u8, try result_set.get([]const u8, 2)),
            .mobile = try self.allocator.dupe(u8, try result_set.get([]const u8, 3)),
            .nickname = try self.allocator.dupe(u8, try result_set.get([]const u8, 4)),
            .avatar = try self.allocator.dupe(u8, try result_set.get([]const u8, 5)),
            .gender = try result_set.get(i32, 6),
            .birthday = try result_set.get(?i64, 7),
            .location = try self.allocator.dupe(u8, try result_set.get([]const u8, 8)),
            .signature = try self.allocator.dupe(u8, try result_set.get([]const u8, 9)),
            .group_id = try result_set.get(i32, 10),
            .points = try result_set.get(i32, 11),
            .experience = try result_set.get(i32, 12),
            .level = try result_set.get(i32, 13),
            .total_consume = @as(f64, @floatCast(try result_set.get(f64, 14))),
            .last_login_time = try result_set.get(?i64, 15),
            .last_login_ip = try self.allocator.dupe(u8, try result_set.get([]const u8, 16)),
            .register_time = try result_set.get(?i64, 17),
            .register_ip = try self.allocator.dupe(u8, try result_set.get([]const u8, 18)),
            .status = try result_set.get(i32, 19),
            .email_verified = try result_set.get(i32, 20),
            .mobile_verified = try result_set.get(i32, 21),
            .remark = try self.allocator.dupe(u8, try result_set.get([]const u8, 22)),
            .create_time = try result_set.get(?i64, 23),
            .update_time = try result_set.get(?i64, 24),
            .is_delete = try result_set.get(i32, 25),
        };
    }

    /// 实现findAll方法
    pub fn findAll(ptr: *anyopaque) ![]Member {
        const self: *SqliteMemberRepository = @ptrCast(@alignCast(ptr));

        // 查询所有未删除的会员
        const query = "SELECT id, username, email, mobile, nickname, avatar, gender, birthday, location, signature, group_id, points, experience, level, total_consume, last_login_time, last_login_ip, register_time, register_ip, status, email_verified, mobile_verified, remark, create_time, update_time, is_delete FROM members WHERE is_delete = 0 ORDER BY create_time DESC";
        var result_set = try self.db.rawQuery(query, .{});
        defer result_set.deinit();

        // 转换为Member数组
        var members = try std.ArrayList(Member).initCapacity(self.allocator, 16);
        defer members.deinit(self.allocator);

        while (result_set.next()) {
            const member = Member{
                .id = try result_set.get(i32, 0),
                .username = try self.allocator.dupe(u8, try result_set.get([]const u8, 1)),
                .email = try self.allocator.dupe(u8, try result_set.get([]const u8, 2)),
                .mobile = try self.allocator.dupe(u8, try result_set.get([]const u8, 3)),
                .nickname = try self.allocator.dupe(u8, try result_set.get([]const u8, 4)),
                .avatar = try self.allocator.dupe(u8, try result_set.get([]const u8, 5)),
                .gender = try result_set.get(i32, 6),
                .birthday = try result_set.get(?i64, 7),
                .location = try self.allocator.dupe(u8, try result_set.get([]const u8, 8)),
                .signature = try self.allocator.dupe(u8, try result_set.get([]const u8, 9)),
                .group_id = try result_set.get(i32, 10),
                .points = try result_set.get(i32, 11),
                .experience = try result_set.get(i32, 12),
                .level = try result_set.get(i32, 13),
                .total_consume = @as(f64, @floatCast(try result_set.get(f64, 14))),
                .last_login_time = try result_set.get(?i64, 15),
                .last_login_ip = try self.allocator.dupe(u8, try result_set.get([]const u8, 16)),
                .register_time = try result_set.get(?i64, 17),
                .register_ip = try self.allocator.dupe(u8, try result_set.get([]const u8, 18)),
                .status = try result_set.get(i32, 19),
                .email_verified = try result_set.get(i32, 20),
                .mobile_verified = try result_set.get(i32, 21),
                .remark = try self.allocator.dupe(u8, try result_set.get([]const u8, 22)),
                .create_time = try result_set.get(?i64, 23),
                .update_time = try result_set.get(?i64, 24),
                .is_delete = try result_set.get(i32, 25),
            };
            try members.append(self.allocator, member);
        }

        return members.toOwnedSlice(self.allocator);
    }

    /// 实现save方法
    pub fn save(ptr: *anyopaque, member: Member) !Member {
        const self: *SqliteMemberRepository = @ptrCast(@alignCast(ptr));

        // 检查是否为新会员
        const is_new = member.id == null;

        if (is_new) {
            // 插入新会员
            const insert_query = "INSERT INTO members (username, email, mobile, nickname, avatar, gender, birthday, location, signature, group_id, points, experience, level, total_consume, last_login_time, last_login_ip, register_time, register_ip, status, email_verified, mobile_verified, remark, create_time, update_time, is_delete) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)";
            const now = std.time.timestamp();
            _ = try self.db.rawExec(insert_query, .{
                member.username,
                member.email,
                member.mobile,
                member.nickname,
                member.avatar,
                member.gender,
                member.birthday,
                member.location,
                member.signature,
                member.group_id,
                member.points,
                member.experience,
                member.level,
                member.total_consume,
                member.last_login_time,
                member.last_login_ip,
                now,
                member.register_ip,
                member.status,
                member.email_verified,
                member.mobile_verified,
                member.remark,
                now,
                now,
            });

            // 获取插入的ID
            const last_id = self.db.lastInsertId();

            // 返回包含ID的会员
            return Member{
                .id = @as(i32, @intCast(last_id)),
                .username = try self.allocator.dupe(u8, member.username),
                .email = try self.allocator.dupe(u8, member.email),
                .mobile = try self.allocator.dupe(u8, member.mobile),
                .nickname = try self.allocator.dupe(u8, member.nickname),
                .avatar = try self.allocator.dupe(u8, member.avatar),
                .gender = member.gender,
                .birthday = member.birthday,
                .location = try self.allocator.dupe(u8, member.location),
                .signature = try self.allocator.dupe(u8, member.signature),
                .group_id = member.group_id,
                .points = member.points,
                .experience = member.experience,
                .level = member.level,
                .total_consume = member.total_consume,
                .last_login_time = member.last_login_time,
                .last_login_ip = try self.allocator.dupe(u8, member.last_login_ip),
                .register_time = now,
                .register_ip = try self.allocator.dupe(u8, member.register_ip),
                .status = member.status,
                .email_verified = member.email_verified,
                .mobile_verified = member.mobile_verified,
                .remark = try self.allocator.dupe(u8, member.remark),
                .create_time = now,
                .update_time = now,
                .is_delete = 0,
            };
        } else {
            // 更新现有会员
            const update_query = "UPDATE members SET username = ?, email = ?, mobile = ?, nickname = ?, avatar = ?, gender = ?, birthday = ?, location = ?, signature = ?, group_id = ?, points = ?, experience = ?, level = ?, total_consume = ?, last_login_time = ?, last_login_ip = ?, status = ?, email_verified = ?, mobile_verified = ?, remark = ?, update_time = ? WHERE id = ? AND is_delete = 0";
            const now = std.time.timestamp();
            _ = try self.db.rawExec(update_query, .{
                member.username,
                member.email,
                member.mobile,
                member.nickname,
                member.avatar,
                member.gender,
                member.birthday,
                member.location,
                member.signature,
                member.group_id,
                member.points,
                member.experience,
                member.level,
                member.total_consume,
                member.last_login_time,
                member.last_login_ip,
                member.status,
                member.email_verified,
                member.mobile_verified,
                member.remark,
                now,
                member.id.?,
            });

            // 返回更新后的会员
            return Member{
                .id = member.id,
                .username = try self.allocator.dupe(u8, member.username),
                .email = try self.allocator.dupe(u8, member.email),
                .mobile = try self.allocator.dupe(u8, member.mobile),
                .nickname = try self.allocator.dupe(u8, member.nickname),
                .avatar = try self.allocator.dupe(u8, member.avatar),
                .gender = member.gender,
                .birthday = member.birthday,
                .location = try self.allocator.dupe(u8, member.location),
                .signature = try self.allocator.dupe(u8, member.signature),
                .group_id = member.group_id,
                .points = member.points,
                .experience = member.experience,
                .level = member.level,
                .total_consume = member.total_consume,
                .last_login_time = member.last_login_time,
                .last_login_ip = try self.allocator.dupe(u8, member.last_login_ip),
                .register_time = member.register_time,
                .register_ip = try self.allocator.dupe(u8, member.register_ip),
                .status = member.status,
                .email_verified = member.email_verified,
                .mobile_verified = member.mobile_verified,
                .remark = try self.allocator.dupe(u8, member.remark),
                .create_time = member.create_time,
                .update_time = now,
                .is_delete = 0,
            };
        }
    }

    /// 实现update方法
    pub fn update(ptr: *anyopaque, member: Member) !void {
        const self: *SqliteMemberRepository = @ptrCast(@alignCast(ptr));

        if (member.id == null) {
            return error.InvalidMemberId;
        }

        const query = "UPDATE members SET username = ?, email = ?, mobile = ?, nickname = ?, avatar = ?, gender = ?, birthday = ?, location = ?, signature = ?, group_id = ?, points = ?, experience = ?, level = ?, total_consume = ?, last_login_time = ?, last_login_ip = ?, status = ?, email_verified = ?, mobile_verified = ?, remark = ?, update_time = ? WHERE id = ? AND is_delete = 0";
        const now = std.time.timestamp();
        _ = try self.db.rawExec(query, .{
            member.username,
            member.email,
            member.mobile,
            member.nickname,
            member.avatar,
            member.gender,
            member.birthday,
            member.location,
            member.signature,
            member.group_id,
            member.points,
            member.experience,
            member.level,
            member.total_consume,
            member.last_login_time,
            member.last_login_ip,
            member.status,
            member.email_verified,
            member.mobile_verified,
            member.remark,
            now,
            member.id.?,
        });
    }

    /// 实现delete方法（软删除）
    pub fn delete(ptr: *anyopaque, id: i32) !void {
        const self: *SqliteMemberRepository = @ptrCast(@alignCast(ptr));

        const query = "UPDATE members SET is_delete = 1, update_time = ? WHERE id = ? AND is_delete = 0";
        const now = std.time.timestamp();
        _ = try self.db.rawExec(query, .{ now, id });
    }

    /// 实现count方法
    pub fn count(ptr: *anyopaque) !usize {
        const self: *SqliteMemberRepository = @ptrCast(@alignCast(ptr));

        const query = "SELECT COUNT(*) as count FROM members WHERE is_delete = 0";
        var result_set = try self.db.rawQuery(query, .{});
        defer result_set.deinit();

        if (!result_set.next()) {
            return 0;
        }

        return @as(usize, @intCast(try result_set.get(i64, 0)));
    }

    /// 创建vtable（供MemberRepository使用）
    pub fn vtable() MemberRepository.VTable {
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
