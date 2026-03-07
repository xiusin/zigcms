// MySQL 反馈评论仓储实现
//
// 功能：
// - 评论 CRUD 操作
// - 查询评论列表
// - 查询回复列表

const std = @import("std");
const FeedbackComment = @import("../../domain/entities/feedback_comment.model.zig").FeedbackComment;
const sql_orm = @import("../../application/services/sql/orm.zig");

/// MySQL 反馈评论仓储
pub const MySQLFeedbackCommentRepository = struct {
    allocator: std.mem.Allocator,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Self) void {
        _ = self;
    }
    
    /// 创建评论
    pub fn create(self: *Self, comment: FeedbackComment) !FeedbackComment {
        // 验证评论
        try comment.validate();
        
        // 构建 SQL
        const sql_str = 
            \\INSERT INTO feedback_comments 
            \\(feedback_id, parent_id, author, content, attachments, created_at, updated_at)
            \\VALUES (?, ?, ?, ?, ?, ?, ?)
        ;
        
        const now = std.time.timestamp();
        
        // 执行插入
        var stmt = try sql_orm.prepare(sql_str);
        defer stmt.deinit();
        
        try stmt.bind(1, comment.feedback_id);
        try stmt.bind(2, comment.parent_id);
        try stmt.bind(3, comment.author);
        try stmt.bind(4, comment.content);
        try stmt.bind(5, comment.attachments);
        try stmt.bind(6, now);
        try stmt.bind(7, now);
        
        const insert_id = try stmt.execute();
        
        // 返回创建的评论
        return FeedbackComment{
            .id = @intCast(insert_id),
            .feedback_id = comment.feedback_id,
            .parent_id = comment.parent_id,
            .author = comment.author,
            .content = comment.content,
            .attachments = comment.attachments,
            .created_at = now,
            .updated_at = now,
        };
    }
    
    /// 更新评论
    pub fn update(self: *Self, id: i32, content: []const u8) !void {
        _ = self;
        
        const sql_str = 
            \\UPDATE feedback_comments 
            \\SET content = ?, updated_at = ?
            \\WHERE id = ?
        ;
        
        const now = std.time.timestamp();
        
        var stmt = try sql_orm.prepare(sql_str);
        defer stmt.deinit();
        
        try stmt.bind(1, content);
        try stmt.bind(2, now);
        try stmt.bind(3, id);
        
        _ = try stmt.execute();
    }
    
    /// 删除评论
    pub fn delete(self: *Self, id: i32) !void {
        _ = self;
        
        const sql_str = "DELETE FROM feedback_comments WHERE id = ?";
        
        var stmt = try sql_orm.prepare(sql_str);
        defer stmt.deinit();
        
        try stmt.bind(1, id);
        
        _ = try stmt.execute();
    }
    
    /// 根据 ID 查询评论
    pub fn findById(self: *Self, id: i32) !?FeedbackComment {
        _ = self;
        
        const sql_str = 
            \\SELECT id, feedback_id, parent_id, author, content, attachments, created_at, updated_at
            \\FROM feedback_comments
            \\WHERE id = ?
        ;
        
        var stmt = try sql_orm.prepare(sql_str);
        defer stmt.deinit();
        
        try stmt.bind(1, id);
        
        const result = try stmt.query();
        defer result.deinit();
        
        if (result.next()) |row| {
            return FeedbackComment{
                .id = try row.getInt(0),
                .feedback_id = try row.getInt(1),
                .parent_id = try row.getIntOpt(2),
                .author = try row.getString(3),
                .content = try row.getString(4),
                .attachments = try row.getString(5),
                .created_at = try row.getInt(6),
                .updated_at = try row.getInt(7),
            };
        }
        
        return null;
    }
    
    /// 查询反馈的所有评论
    pub fn findByFeedbackId(self: *Self, feedback_id: i32) ![]FeedbackComment {
        const sql_str = 
            \\SELECT id, feedback_id, parent_id, author, content, attachments, created_at, updated_at
            \\FROM feedback_comments
            \\WHERE feedback_id = ?
            \\ORDER BY created_at ASC
        ;
        
        var stmt = try sql_orm.prepare(sql_str);
        defer stmt.deinit();
        
        try stmt.bind(1, feedback_id);
        
        const result = try stmt.query();
        defer result.deinit();
        
        var comments = std.ArrayList(FeedbackComment).init(self.allocator);
        errdefer comments.deinit();
        
        while (result.next()) |row| {
            try comments.append(FeedbackComment{
                .id = try row.getInt(0),
                .feedback_id = try row.getInt(1),
                .parent_id = try row.getIntOpt(2),
                .author = try row.getString(3),
                .content = try row.getString(4),
                .attachments = try row.getString(5),
                .created_at = try row.getInt(6),
                .updated_at = try row.getInt(7),
            });
        }
        
        return comments.toOwnedSlice();
    }
    
    /// 查询评论的回复列表
    pub fn findReplies(self: *Self, parent_id: i32) ![]FeedbackComment {
        const sql_str = 
            \\SELECT id, feedback_id, parent_id, author, content, attachments, created_at, updated_at
            \\FROM feedback_comments
            \\WHERE parent_id = ?
            \\ORDER BY created_at ASC
        ;
        
        var stmt = try sql_orm.prepare(sql_str);
        defer stmt.deinit();
        
        try stmt.bind(1, parent_id);
        
        const result = try stmt.query();
        defer result.deinit();
        
        var replies = std.ArrayList(FeedbackComment).init(self.allocator);
        errdefer replies.deinit();
        
        while (result.next()) |row| {
            try replies.append(FeedbackComment{
                .id = try row.getInt(0),
                .feedback_id = try row.getInt(1),
                .parent_id = try row.getIntOpt(2),
                .author = try row.getString(3),
                .content = try row.getString(4),
                .attachments = try row.getString(5),
                .created_at = try row.getInt(6),
                .updated_at = try row.getInt(7),
            });
        }
        
        return replies.toOwnedSlice();
    }
    
    /// 统计反馈的评论数
    pub fn countByFeedbackId(self: *Self, feedback_id: i32) !i32 {
        _ = self;
        
        const sql_str = 
            \\SELECT COUNT(*) 
            \\FROM feedback_comments
            \\WHERE feedback_id = ?
        ;
        
        var stmt = try sql_orm.prepare(sql_str);
        defer stmt.deinit();
        
        try stmt.bind(1, feedback_id);
        
        const result = try stmt.query();
        defer result.deinit();
        
        if (result.next()) |row| {
            return try row.getInt(0);
        }
        
        return 0;
    }
};
