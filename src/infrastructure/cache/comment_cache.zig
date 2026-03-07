// 评论缓存策略
//
// 功能：
// - 评论列表缓存
// - 评论数量缓存
// - 缓存失效策略

const std = @import("std");
const CacheInterface = @import("../../application/services/cache/contract.zig").CacheInterface;
const FeedbackComment = @import("../../domain/entities/feedback_comment.model.zig").FeedbackComment;

/// 评论缓存
pub const CommentCache = struct {
    allocator: std.mem.Allocator,
    cache: *CacheInterface,
    
    const Self = @This();
    
    // 缓存键前缀
    const COMMENT_LIST_PREFIX = "comment:list:";
    const COMMENT_COUNT_PREFIX = "comment:count:";
    const COMMENT_DETAIL_PREFIX = "comment:detail:";
    
    // 缓存过期时间（秒）
    const CACHE_TTL = 300; // 5分钟
    
    pub fn init(allocator: std.mem.Allocator, cache: *CacheInterface) Self {
        return .{
            .allocator = allocator,
            .cache = cache,
        };
    }
    
    pub fn deinit(self: *Self) void {
        _ = self;
    }
    
    /// 获取评论列表缓存键
    fn getListCacheKey(self: *Self, feedback_id: i32) ![]const u8 {
        return try std.fmt.allocPrint(
            self.allocator,
            "{s}{d}",
            .{ COMMENT_LIST_PREFIX, feedback_id },
        );
    }
    
    /// 获取评论数量缓存键
    fn getCountCacheKey(self: *Self, feedback_id: i32) ![]const u8 {
        return try std.fmt.allocPrint(
            self.allocator,
            "{s}{d}",
            .{ COMMENT_COUNT_PREFIX, feedback_id },
        );
    }
    
    /// 获取评论详情缓存键
    fn getDetailCacheKey(self: *Self, comment_id: i32) ![]const u8 {
        return try std.fmt.allocPrint(
            self.allocator,
            "{s}{d}",
            .{ COMMENT_DETAIL_PREFIX, comment_id },
        );
    }
    
    /// 缓存评论列表
    pub fn cacheCommentList(self: *Self, feedback_id: i32, comments: []const FeedbackComment) !void {
        const cache_key = try self.getListCacheKey(feedback_id);
        defer self.allocator.free(cache_key);
        
        // 序列化评论列表为 JSON
        var json_str = std.ArrayList(u8).init(self.allocator);
        defer json_str.deinit();
        
        try std.json.stringify(comments, .{}, json_str.writer());
        
        // 存入缓存
        try self.cache.set(cache_key, json_str.items, CACHE_TTL);
        
        std.debug.print("✅ 缓存评论列表: feedback_id={d}, count={d}\n", .{ feedback_id, comments.len });
    }
    
    /// 获取评论列表缓存
    pub fn getCommentList(self: *Self, feedback_id: i32) !?[]FeedbackComment {
        const cache_key = try self.getListCacheKey(feedback_id);
        defer self.allocator.free(cache_key);
        
        // 从缓存读取
        const cached = self.cache.get(cache_key, self.allocator) catch |err| {
            std.debug.print("⚠️  缓存读取失败: {}\n", .{err});
            return null;
        };
        
        if (cached) |json_str| {
            defer self.allocator.free(json_str);
            
            // 反序列化 JSON
            var parsed = std.json.parseFromSlice(
                []FeedbackComment,
                self.allocator,
                json_str,
                .{},
            ) catch |err| {
                std.debug.print("⚠️  JSON 解析失败: {}\n", .{err});
                return null;
            };
            defer parsed.deinit();
            
            std.debug.print("✅ 命中评论列表缓存: feedback_id={d}\n", .{feedback_id});
            return try self.allocator.dupe(FeedbackComment, parsed.value);
        }
        
        return null;
    }
    
    /// 缓存评论数量
    pub fn cacheCommentCount(self: *Self, feedback_id: i32, count: i32) !void {
        const cache_key = try self.getCountCacheKey(feedback_id);
        defer self.allocator.free(cache_key);
        
        const count_str = try std.fmt.allocPrint(self.allocator, "{d}", .{count});
        defer self.allocator.free(count_str);
        
        try self.cache.set(cache_key, count_str, CACHE_TTL);
        
        std.debug.print("✅ 缓存评论数量: feedback_id={d}, count={d}\n", .{ feedback_id, count });
    }
    
    /// 获取评论数量缓存
    pub fn getCommentCount(self: *Self, feedback_id: i32) !?i32 {
        const cache_key = try self.getCountCacheKey(feedback_id);
        defer self.allocator.free(cache_key);
        
        const cached = self.cache.get(cache_key, self.allocator) catch {
            return null;
        };
        
        if (cached) |count_str| {
            defer self.allocator.free(count_str);
            
            const count = std.fmt.parseInt(i32, count_str, 10) catch {
                return null;
            };
            
            std.debug.print("✅ 命中评论数量缓存: feedback_id={d}, count={d}\n", .{ feedback_id, count });
            return count;
        }
        
        return null;
    }
    
    /// 缓存评论详情
    pub fn cacheCommentDetail(self: *Self, comment: FeedbackComment) !void {
        if (comment.id) |comment_id| {
            const cache_key = try self.getDetailCacheKey(comment_id);
            defer self.allocator.free(cache_key);
            
            var json_str = std.ArrayList(u8).init(self.allocator);
            defer json_str.deinit();
            
            try std.json.stringify(comment, .{}, json_str.writer());
            
            try self.cache.set(cache_key, json_str.items, CACHE_TTL);
            
            std.debug.print("✅ 缓存评论详情: comment_id={d}\n", .{comment_id});
        }
    }
    
    /// 获取评论详情缓存
    pub fn getCommentDetail(self: *Self, comment_id: i32) !?FeedbackComment {
        const cache_key = try self.getDetailCacheKey(comment_id);
        defer self.allocator.free(cache_key);
        
        const cached = self.cache.get(cache_key, self.allocator) catch {
            return null;
        };
        
        if (cached) |json_str| {
            defer self.allocator.free(json_str);
            
            var parsed = std.json.parseFromSlice(
                FeedbackComment,
                self.allocator,
                json_str,
                .{},
            ) catch {
                return null;
            };
            defer parsed.deinit();
            
            std.debug.print("✅ 命中评论详情缓存: comment_id={d}\n", .{comment_id});
            return parsed.value;
        }
        
        return null;
    }
    
    /// 清除反馈的所有评论缓存
    pub fn invalidateFeedbackCache(self: *Self, feedback_id: i32) !void {
        // 清除评论列表缓存
        const list_key = try self.getListCacheKey(feedback_id);
        defer self.allocator.free(list_key);
        try self.cache.del(list_key);
        
        // 清除评论数量缓存
        const count_key = try self.getCountCacheKey(feedback_id);
        defer self.allocator.free(count_key);
        try self.cache.del(count_key);
        
        std.debug.print("🗑️  清除反馈评论缓存: feedback_id={d}\n", .{feedback_id});
    }
    
    /// 清除评论详情缓存
    pub fn invalidateCommentCache(self: *Self, comment_id: i32) !void {
        const cache_key = try self.getDetailCacheKey(comment_id);
        defer self.allocator.free(cache_key);
        try self.cache.del(cache_key);
        
        std.debug.print("🗑️  清除评论详情缓存: comment_id={d}\n", .{comment_id});
    }
    
    /// 批量清除评论缓存
    pub fn invalidateBatch(self: *Self, feedback_ids: []const i32) !void {
        for (feedback_ids) |feedback_id| {
            try self.invalidateFeedbackCache(feedback_id);
        }
    }
};
