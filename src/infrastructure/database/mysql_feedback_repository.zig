//! MySQL 反馈仓储实现
//!
//! 实现反馈仓储接口，使用 ORM QueryBuilder 构建查询，
//! 遵循 ZigCMS 开发范式：参数化查询、内存安全管理。
//! 支持跟进记录的 JSON 序列化和反序列化。

const std = @import("std");
const Allocator = std.mem.Allocator;
const sql = @import("../../application/services/sql/orm.zig");

// 导入领域层定义
const Feedback = @import("../../domain/entities/feedback.model.zig").Feedback;
const FeedbackType = Feedback.FeedbackType;
const Severity = Feedback.Severity;
const FeedbackStatus = Feedback.FeedbackStatus;
const FeedbackRepository = @import("../../domain/repositories/feedback_repository.zig").FeedbackRepository;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;
const PageResult = @import("../../domain/repositories/test_case_repository.zig").PageResult;

/// MySQL 反馈仓储实现
pub const MysqlFeedbackRepository = struct {
    allocator: Allocator,
    db: *sql.Database,

    const Self = @This();

    /// 初始化仓储
    pub fn init(allocator: Allocator, db: *sql.Database) Self {
        return .{
            .allocator = allocator,
            .db = db,
        };
    }

    /// 清理资源
    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// 定义 ORM 模型
    const OrmFeedback = sql.define(struct {
        pub const table_name = "quality_feedbacks";
        pub const primary_key = "id";

        id: ?i32 = null,
        title: []const u8 = "",
        content: []const u8 = "",
        type: []const u8 = "bug",
        severity: []const u8 = "medium",
        status: []const u8 = "pending",
        assignee: ?[]const u8 = null,
        submitter: []const u8 = "",
        follow_ups: []const u8 = "",
        follow_count: i32 = 0,
        last_follow_at: ?i64 = null,
        created_at: ?i64 = null,
        updated_at: ?i64 = null,
    });

    /// 根据 ID 查询反馈
    pub fn findById(self: *Self, id: i32) !?Feedback {
        // 使用 ORM QueryBuilder 构建查询
        var q = OrmFeedback.query(self.db);
        defer q.deinit();

        // 参数化查询防止 SQL 注入
        _ = q.where("id", "=", id);

        // 执行查询
        const rows = try q.get();
        defer OrmFeedback.freeModels(rows);

        if (rows.len == 0) return null;

        // 深拷贝字符串字段（防止悬垂指针）
        return try self.ormToEntity(rows[0]);
    }

    /// 分页查询所有反馈
    pub fn findAll(self: *Self, query: PageQuery) !PageResult(Feedback) {
        // 构建查询
        var q = OrmFeedback.query(self.db);
        defer q.deinit();

        // 按创建时间倒序排列（最新的在前）
        _ = q.orderBy("created_at", sql.OrderDir.desc)
            .limit(@intCast(query.page_size))
            .offset(@intCast((query.page - 1) * query.page_size));

        // 执行查询
        const rows = try q.get();
        defer OrmFeedback.freeModels(rows);

        // 查询总数
        var count_q = OrmFeedback.query(self.db);
        defer count_q.deinit();
        const total = try count_q.count();

        // 转换为实体
        var items = try self.allocator.alloc(Feedback, rows.len);
        errdefer self.allocator.free(items);

        for (rows, 0..) |row, i| {
            items[i] = try self.ormToEntity(row);
        }

        return PageResult(Feedback){
            .items = items,
            .total = @intCast(total),
            .page = query.page,
            .page_size = query.page_size,
        };
    }

    /// 保存反馈（创建或更新）
    pub fn save(_: *Self, feedback: *Feedback) !void {
        if (feedback.id) |id| {
            // 更新现有记录
            _ = try OrmFeedback.UpdateWith(id, .{
                .title = feedback.title,
                .content = feedback.content,
                .type = feedback.type.toString(),
                .severity = feedback.severity.toString(),
                .status = feedback.status.toString(),
                .assignee = feedback.assignee,
                .submitter = feedback.submitter,
                .follow_ups = feedback.follow_ups,
                .follow_count = feedback.follow_count,
                .last_follow_at = feedback.last_follow_at,
                .updated_at = std.time.timestamp(),
            });
        } else {
            // 创建新记录
            const created = try OrmFeedback.Create(.{
                .title = feedback.title,
                .content = feedback.content,
                .type = feedback.type.toString(),
                .severity = feedback.severity.toString(),
                .status = feedback.status.toString(),
                .assignee = feedback.assignee,
                .submitter = feedback.submitter,
                .follow_ups = feedback.follow_ups,
                .follow_count = feedback.follow_count,
                .last_follow_at = feedback.last_follow_at,
                .created_at = std.time.timestamp(),
                .updated_at = std.time.timestamp(),
            });
            feedback.id = created.id;
        }
    }

    /// 删除反馈
    pub fn delete(self: *Self, id: i32) !void {
        var q = OrmFeedback.query(self.db);
        defer q.deinit();
        _ = q.where("id", "=", id);
        _ = try q.delete();
    }

    /// 添加跟进记录
    pub fn addFollowUp(self: *Self, feedback_id: i32, follower: []const u8, content: []const u8) !void {
        // 1. 查询反馈
        const feedback = try self.findById(feedback_id) orelse return error.FeedbackNotFound;
        defer self.freeFeedback(feedback);

        // 2. 解析现有跟进记录
        var follow_ups = std.ArrayListUnmanaged(u8){};
        defer follow_ups.deinit(self.allocator);

        // 如果已有跟进记录，先复制
        if (feedback.follow_ups.len > 2) { // 不是空数组 "[]"
            try follow_ups.appendSlice(self.allocator, feedback.follow_ups[0 .. feedback.follow_ups.len - 1]); // 去掉最后的 ']'
            try follow_ups.appendSlice(self.allocator, ",");
        } else {
            try follow_ups.appendSlice(self.allocator, "[");
        }

        // 3. 添加新的跟进记录（JSON 格式）
        const now = std.time.timestamp();
        const follow_up_json = try std.fmt.allocPrint(
            self.allocator,
            \\{{"time":{d},"user":"{s}","content":"{s}"}}]
        ,
            .{ now, follower, content },
        );
        defer self.allocator.free(follow_up_json);

        try follow_ups.appendSlice(self.allocator, follow_up_json);

        // 4. 更新反馈
        _ = try OrmFeedback.UpdateWith(feedback_id, .{
            .follow_ups = follow_ups.items,
            .follow_count = feedback.follow_count + 1,
            .last_follow_at = now,
            .updated_at = now,
        });
    }

    /// 批量指派反馈负责人
    pub fn batchAssign(self: *Self, ids: []const i32, assignee: []const u8) !void {
        if (ids.len == 0) return;
        if (ids.len > 1000) return error.TooManyRecords;

        // 使用 whereIn 批量更新（避免 N+1 查询）
        var q = OrmFeedback.query(self.db);
        defer q.deinit();

        _ = q.whereIn("id", ids);
        _ = try q.update(.{
            .assignee = assignee,
            .updated_at = std.time.timestamp(),
        });
    }

    /// 批量更新反馈状态
    pub fn batchUpdateStatus(self: *Self, ids: []const i32, status: FeedbackStatus) !void {
        if (ids.len == 0) return;
        if (ids.len > 1000) return error.TooManyRecords;

        // 使用 whereIn 批量更新（避免 N+1 查询）
        var q = OrmFeedback.query(self.db);
        defer q.deinit();

        _ = q.whereIn("id", ids);
        _ = try q.update(.{
            .status = status.toString(),
            .updated_at = std.time.timestamp(),
        });
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 将 ORM 模型转换为领域实体（深拷贝字符串字段）
    fn ormToEntity(self: *Self, orm: OrmFeedback.Model) !Feedback {
        return Feedback{
            .id = orm.id,
            .title = try self.allocator.dupe(u8, orm.title),
            .content = try self.allocator.dupe(u8, orm.content),
            .type = FeedbackType.fromString(orm.type) orelse .bug,
            .severity = Severity.fromString(orm.severity) orelse .medium,
            .status = FeedbackStatus.fromString(orm.status) orelse .pending,
            .assignee = if (orm.assignee) |a| try self.allocator.dupe(u8, a) else null,
            .submitter = try self.allocator.dupe(u8, orm.submitter),
            .follow_ups = try self.allocator.dupe(u8, orm.follow_ups),
            .follow_count = orm.follow_count,
            .last_follow_at = orm.last_follow_at,
            .created_at = orm.created_at,
            .updated_at = orm.updated_at,
        };
    }

    /// 释放反馈内存
    pub fn freeFeedback(self: *Self, feedback: Feedback) void {
        self.allocator.free(feedback.title);
        self.allocator.free(feedback.content);
        if (feedback.assignee) |a| self.allocator.free(a);
        self.allocator.free(feedback.submitter);
        self.allocator.free(feedback.follow_ups);
    }

    /// 释放分页结果内存
    pub fn freePageResult(self: *Self, result: PageResult(Feedback)) void {
        for (result.items) |item| {
            self.freeFeedback(item);
        }
        self.allocator.free(result.items);
    }

    // ========================================================================
    // VTable 实现
    // ========================================================================

    pub fn vtable() FeedbackRepository.VTable {
        return .{
            .findById = findByIdImpl,
            .findAll = findAllImpl,
            .save = saveImpl,
            .delete = deleteImpl,
            .addFollowUp = addFollowUpImpl,
            .batchAssign = batchAssignImpl,
            .batchUpdateStatus = batchUpdateStatusImpl,
        };
    }

    fn findByIdImpl(ptr: *anyopaque, id: i32) anyerror!?Feedback {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findById(id);
    }

    fn findAllImpl(ptr: *anyopaque, query: PageQuery) anyerror!PageResult(Feedback) {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findAll(query);
    }

    fn saveImpl(ptr: *anyopaque, feedback: *Feedback) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.save(feedback);
    }

    fn deleteImpl(ptr: *anyopaque, id: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.delete(id);
    }

    fn addFollowUpImpl(ptr: *anyopaque, feedback_id: i32, follower: []const u8, content: []const u8) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.addFollowUp(feedback_id, follower, content);
    }

    fn batchAssignImpl(ptr: *anyopaque, ids: []const i32, assignee: []const u8) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.batchAssign(ids, assignee);
    }

    fn batchUpdateStatusImpl(ptr: *anyopaque, ids: []const i32, status: FeedbackStatus) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.batchUpdateStatus(ids, status);
    }
};

/// 创建反馈仓储实例
pub fn create(allocator: Allocator, db: *sql.Database) !*FeedbackRepository {
    const repo = try allocator.create(MysqlFeedbackRepository);
    errdefer allocator.destroy(repo);

    repo.* = MysqlFeedbackRepository.init(allocator, db);

    const interface = try allocator.create(FeedbackRepository);
    errdefer allocator.destroy(interface);

    interface.* = @import("../../domain/repositories/feedback_repository.zig").create(
        repo,
        &MysqlFeedbackRepository.vtable(),
    );

    return interface;
}
