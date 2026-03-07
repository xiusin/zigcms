// 反馈评论控制器
//
// 功能：
// - 添加评论
// - 回复评论
// - 编辑评论
// - 删除评论
// - 查询评论列表

const std = @import("std");
const zap = @import("zap");
const zigcms = @import("zigcms");
const base = @import("../base.zig");

/// 评论数据结构
pub const Comment = struct {
    id: ?i32 = null,
    feedback_id: i32,
    parent_id: ?i32 = null,
    author: []const u8,
    content: []const u8,
    attachments: []const u8 = "[]",
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

/// 添加评论
pub fn create(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 权限检查
    const RbacMiddleware = @import("../../middleware/rbac.zig").RbacMiddleware;
    const QualityCenterPermissions = @import("../../middleware/rbac.zig").QualityCenterPermissions;
    const container = zigcms.core.di.getGlobalContainer();
    
    const rbac = try container.resolve(RbacMiddleware);
    rbac.checkPermission(&req, QualityCenterPermissions.FEEDBACK_COMMENT) catch {
        try base.send_error(req, 403, "无权限添加评论");
        return;
    };
    
    // 解析请求参数
    const feedback_id_str = req.getParamStr("feedback_id") orelse {
        try base.send_error(req, 400, "缺少 feedback_id 参数");
        return;
    };
    
    const feedback_id = std.fmt.parseInt(i32, feedback_id_str, 10) catch {
        try base.send_error(req, 400, "feedback_id 参数无效");
        return;
    };
    
    // 解析请求体
    const body = req.body orelse {
        try base.send_error(req, 400, "缺少请求体");
        return;
    };
    
    var parsed = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        body,
        .{},
    ) catch {
        try base.send_error(req, 400, "JSON 解析失败");
        return;
    };
    defer parsed.deinit();
    
    const obj = parsed.value.object;
    
    // 提取字段
    const content = if (obj.get("content")) |v| 
        if (v == .string) v.string else "" 
        else "";
    
    const author = if (obj.get("author")) |v| 
        if (v == .string) v.string else "匿名" 
        else "匿名";
    
    const attachments = if (obj.get("attachments")) |v|
        if (v == .array) blk: {
            var list = std.ArrayList(u8).init(allocator);
            defer list.deinit();
            
            try std.json.stringify(v, .{}, list.writer());
            break :blk try list.toOwnedSlice();
        } else "[]"
        else "[]";
    defer allocator.free(attachments);
    
    // 审核内容
    const ModerationEngine = @import("../../infrastructure/moderation/moderation_engine.zig").ModerationEngine;
    const ModerationContext = @import("../../infrastructure/moderation/moderation_engine.zig").ModerationContext;
    
    var engine = try ModerationEngine.init(allocator);
    defer engine.deinit();
    
    // 加载敏感词
    try engine.loadSensitiveWords();
    
    // 审核上下文
    const ctx = ModerationContext{
        .content_text = content,
        .user_id = 1, // TODO: 从用户信息中获取
        .user_register_days = 30, // TODO: 从用户信息中获取
        .user_credit_score = 100, // TODO: 从用户信用表中获取
        .recent_comment_count = 0, // TODO: 从数据库统计
    };
    
    var moderation_result = try engine.moderate(ctx);
    defer engine.freeResult(&moderation_result);
    
    // 根据审核结果处理
    const ModerationAction = @import("../../infrastructure/moderation/moderation_engine.zig").ModerationAction;
    
    switch (moderation_result.action) {
        .auto_reject => {
            // 自动拒绝，返回错误
            try base.send_error(req, 400, moderation_result.reason);
            return;
        },
        .review => {
            // 需要人工审核，创建评论但标记为待审核
            std.debug.print("评论需要人工审核: {s}\n", .{moderation_result.reason});
            
            // TODO: 保存审核记录到数据库
            // TODO: 创建评论，状态为待审核
            
            try base.send_success(req, .{
                .id = 1,
                .feedback_id = feedback_id,
                .author = author,
                .content = content,
                .moderation_status = "pending",
                .moderation_reason = moderation_result.reason,
                .created_at = std.time.timestamp(),
            });
            return;
        },
        .auto_approve => {
            // 自动通过，使用清理后的内容（如果有）
            const final_content = moderation_result.cleaned_text orelse content;
            
            // 创建评论
            const comment = Comment{
                .feedback_id = feedback_id,
                .author = author,
                .content = final_content,
                .attachments = attachments,
                .created_at = std.time.timestamp(),
                .updated_at = std.time.timestamp(),
            };
            
            // TODO: 保存到数据库
            std.debug.print("创建评论: feedback_id={d}, author={s}\n", .{ feedback_id, author });
            
            // 返回成功响应
            try base.send_success(req, .{
                .id = 1,
                .feedback_id = feedback_id,
                .author = author,
                .content = final_content,
                .moderation_status = "auto_approved",
                .created_at = comment.created_at,
            });
        },
    }
}

/// 回复评论
pub fn reply(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 权限检查
    const RbacMiddleware = @import("../../middleware/rbac.zig").RbacMiddleware;
    const QualityCenterPermissions = @import("../../middleware/rbac.zig").QualityCenterPermissions;
    const container = zigcms.core.di.getGlobalContainer();
    
    const rbac = try container.resolve(RbacMiddleware);
    rbac.checkPermission(&req, QualityCenterPermissions.FEEDBACK_COMMENT) catch {
        try base.send_error(req, 403, "无权限回复评论");
        return;
    };
    
    // 解析请求参数
    const feedback_id_str = req.getParamStr("feedback_id") orelse {
        try base.send_error(req, 400, "缺少 feedback_id 参数");
        return;
    };
    
    const comment_id_str = req.getParamStr("comment_id") orelse {
        try base.send_error(req, 400, "缺少 comment_id 参数");
        return;
    };
    
    const feedback_id = std.fmt.parseInt(i32, feedback_id_str, 10) catch {
        try base.send_error(req, 400, "feedback_id 参数无效");
        return;
    };
    
    const comment_id = std.fmt.parseInt(i32, comment_id_str, 10) catch {
        try base.send_error(req, 400, "comment_id 参数无效");
        return;
    };
    
    // 解析请求体
    const body = req.body orelse {
        try base.send_error(req, 400, "缺少请求体");
        return;
    };
    
    var parsed = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        body,
        .{},
    ) catch {
        try base.send_error(req, 400, "JSON 解析失败");
        return;
    };
    defer parsed.deinit();
    
    const obj = parsed.value.object;
    
    // 提取字段
    const content = if (obj.get("content")) |v| 
        if (v == .string) v.string else "" 
        else "";
    
    const author = if (obj.get("author")) |v| 
        if (v == .string) v.string else "匿名" 
        else "匿名";
    
    const reply_to = if (obj.get("reply_to")) |v| 
        if (v == .string) v.string else null 
        else null;
    
    // 创建回复
    const reply_comment = Comment{
        .feedback_id = feedback_id,
        .parent_id = comment_id,
        .author = author,
        .content = content,
        .created_at = std.time.timestamp(),
        .updated_at = std.time.timestamp(),
    };
    
    // TODO: 保存到数据库
    std.debug.print("回复评论: comment_id={d}, author={s}, reply_to={?s}\n", .{ comment_id, author, reply_to });
    
    // 返回成功响应
    try base.send_success(req, .{
        .id = 2,
        .feedback_id = feedback_id,
        .parent_id = comment_id,
        .author = author,
        .content = content,
        .reply_to = reply_to,
        .created_at = reply_comment.created_at,
    });
}

/// 编辑评论
pub fn update(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 权限检查
    const RbacMiddleware = @import("../../middleware/rbac.zig").RbacMiddleware;
    const QualityCenterPermissions = @import("../../middleware/rbac.zig").QualityCenterPermissions;
    const container = zigcms.core.di.getGlobalContainer();
    
    const rbac = try container.resolve(RbacMiddleware);
    rbac.checkPermission(&req, QualityCenterPermissions.FEEDBACK_UPDATE) catch {
        try base.send_error(req, 403, "无权限编辑评论");
        return;
    };
    
    // 解析请求参数
    const feedback_id_str = req.getParamStr("feedback_id") orelse {
        try base.send_error(req, 400, "缺少 feedback_id 参数");
        return;
    };
    
    const comment_id_str = req.getParamStr("comment_id") orelse {
        try base.send_error(req, 400, "缺少 comment_id 参数");
        return;
    };
    
    const feedback_id = std.fmt.parseInt(i32, feedback_id_str, 10) catch {
        try base.send_error(req, 400, "feedback_id 参数无效");
        return;
    };
    
    const comment_id = std.fmt.parseInt(i32, comment_id_str, 10) catch {
        try base.send_error(req, 400, "comment_id 参数无效");
        return;
    };
    
    // 解析请求体
    const body = req.body orelse {
        try base.send_error(req, 400, "缺少请求体");
        return;
    };
    
    var parsed = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        body,
        .{},
    ) catch {
        try base.send_error(req, 400, "JSON 解析失败");
        return;
    };
    defer parsed.deinit();
    
    const obj = parsed.value.object;
    
    // 提取字段
    const content = if (obj.get("content")) |v| 
        if (v == .string) v.string else "" 
        else "";
    
    // TODO: 更新数据库
    std.debug.print("更新评论: feedback_id={d}, comment_id={d}\n", .{ feedback_id, comment_id });
    
    // 返回成功响应
    try base.send_success(req, .{
        .message = "评论已更新",
        .updated_at = std.time.timestamp(),
    });
}

/// 删除评论
pub fn delete(req: zap.Request) !void {
    // 权限检查
    const RbacMiddleware = @import("../../middleware/rbac.zig").RbacMiddleware;
    const QualityCenterPermissions = @import("../../middleware/rbac.zig").QualityCenterPermissions;
    const container = zigcms.core.di.getGlobalContainer();
    
    const rbac = try container.resolve(RbacMiddleware);
    rbac.checkPermission(&req, QualityCenterPermissions.FEEDBACK_DELETE) catch {
        try base.send_error(req, 403, "无权限删除评论");
        return;
    };
    
    // 解析请求参数
    const feedback_id_str = req.getParamStr("feedback_id") orelse {
        try base.send_error(req, 400, "缺少 feedback_id 参数");
        return;
    };
    
    const comment_id_str = req.getParamStr("comment_id") orelse {
        try base.send_error(req, 400, "缺少 comment_id 参数");
        return;
    };
    
    const feedback_id = std.fmt.parseInt(i32, feedback_id_str, 10) catch {
        try base.send_error(req, 400, "feedback_id 参数无效");
        return;
    };
    
    const comment_id = std.fmt.parseInt(i32, comment_id_str, 10) catch {
        try base.send_error(req, 400, "comment_id 参数无效");
        return;
    };
    
    // TODO: 从数据库删除
    std.debug.print("删除评论: feedback_id={d}, comment_id={d}\n", .{ feedback_id, comment_id });
    
    // 返回成功响应
    try base.send_success(req, .{
        .message = "评论已删除",
    });
}

/// 查询评论列表
pub fn list(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 权限检查
    const RbacMiddleware = @import("../../middleware/rbac.zig").RbacMiddleware;
    const QualityCenterPermissions = @import("../../middleware/rbac.zig").QualityCenterPermissions;
    const container = zigcms.core.di.getGlobalContainer();
    
    const rbac = try container.resolve(RbacMiddleware);
    rbac.checkPermission(&req, QualityCenterPermissions.FEEDBACK_VIEW) catch {
        try base.send_error(req, 403, "无权限查看评论");
        return;
    };
    
    // 解析请求参数
    const feedback_id_str = req.getParamStr("feedback_id") orelse {
        try base.send_error(req, 400, "缺少 feedback_id 参数");
        return;
    };
    
    const feedback_id = std.fmt.parseInt(i32, feedback_id_str, 10) catch {
        try base.send_error(req, 400, "feedback_id 参数无效");
        return;
    };
    
    // TODO: 从数据库查询
    std.debug.print("查询评论列表: feedback_id={d}\n", .{feedback_id});
    
    // 模拟数据
    const comments = try allocator.alloc(std.json.Value, 2);
    defer allocator.free(comments);
    
    comments[0] = .{
        .object = std.json.ObjectMap.init(allocator),
    };
    comments[1] = .{
        .object = std.json.ObjectMap.init(allocator),
    };
    
    // 返回成功响应
    try base.send_success(req, .{
        .items = comments,
        .total = 2,
    });
}
