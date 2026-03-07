//! 审核规则引擎
//!
//! 功能：
//! - 规则匹配
//! - 自动审核
//! - 审核决策

const std = @import("std");
const Allocator = std.mem.Allocator;
const SensitiveWordFilter = @import("sensitive_word_filter.zig").SensitiveWordFilter;
const MatchResult = @import("sensitive_word_filter.zig").MatchResult;

/// 审核动作
pub const ModerationAction = enum {
    auto_approve,   // 自动通过
    auto_reject,    // 自动拒绝
    review,         // 人工审核
    
    pub fn toString(self: ModerationAction) []const u8 {
        return switch (self) {
            .auto_approve => "auto_approve",
            .auto_reject => "auto_reject",
            .review => "review",
        };
    }
};

/// 审核结果
pub const ModerationResult = struct {
    action: ModerationAction,
    reason: []const u8,
    matched_words: []MatchResult,
    matched_rules: [][]const u8,
    cleaned_text: ?[]const u8 = null,
};

/// 审核上下文
pub const ModerationContext = struct {
    content_text: []const u8,
    user_id: i32,
    user_register_days: i32 = 0,
    user_credit_score: i32 = 100,
    recent_comment_count: i32 = 0,
};

/// 审核规则引擎
pub const ModerationEngine = struct {
    allocator: Allocator,
    filter: SensitiveWordFilter,
    
    const Self = @This();
    
    pub fn init(allocator: Allocator) !Self {
        return .{
            .allocator = allocator,
            .filter = try SensitiveWordFilter.init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.filter.deinit();
    }
    
    /// 加载敏感词（使用模拟数据）
    pub fn loadSensitiveWords(self: *Self) !void {
        const words = try @import("sensitive_word_filter.zig").loadSensitiveWordsMock(self.allocator);
        defer @import("sensitive_word_filter.zig").freeSensitiveWords(self.allocator, words);
        
        for (words) |word| {
            try self.filter.addWord(word);
        }
    }
    
    /// 加载敏感词（从数据库）
    pub fn loadSensitiveWordsFromDb(self: *Self, repository: anytype) !void {
        const words = try @import("sensitive_word_filter.zig").loadSensitiveWords(self.allocator, repository);
        defer @import("sensitive_word_filter.zig").freeSensitiveWords(self.allocator, words);
        
        for (words) |word| {
            try self.filter.addWord(word);
        }
    }
    
    /// 审核内容
    pub fn moderate(self: *Self, ctx: ModerationContext) !ModerationResult {
        var matched_rules = std.ArrayList([]const u8).init(self.allocator);
        defer matched_rules.deinit();
        
        // 1. 检查内容长度
        if (ctx.content_text.len < 5) {
            try matched_rules.append(try self.allocator.dupe(u8, "内容过短拦截"));
            return ModerationResult{
                .action = .auto_reject,
                .reason = try self.allocator.dupe(u8, "内容长度小于5个字符"),
                .matched_words = &[_]MatchResult{},
                .matched_rules = try matched_rules.toOwnedSlice(),
            };
        }
        
        if (ctx.content_text.len > 1000) {
            try matched_rules.append(try self.allocator.dupe(u8, "内容过长审核"));
            return ModerationResult{
                .action = .review,
                .reason = try self.allocator.dupe(u8, "内容长度超过1000个字符，需要人工审核"),
                .matched_words = &[_]MatchResult{},
                .matched_rules = try matched_rules.toOwnedSlice(),
            };
        }
        
        // 2. 检查敏感词
        const matches = try self.filter.detect(ctx.content_text);
        
        if (matches.len > 0) {
            // 获取最高敏感词等级
            const max_level = try self.filter.getMaxLevel(ctx.content_text);
            
            if (max_level >= 3) {
                // 高危敏感词，直接拦截
                try matched_rules.append(try self.allocator.dupe(u8, "高危敏感词拦截"));
                return ModerationResult{
                    .action = .auto_reject,
                    .reason = try self.allocator.dupe(u8, "包含高危敏感词"),
                    .matched_words = matches,
                    .matched_rules = try matched_rules.toOwnedSlice(),
                };
            } else if (max_level >= 2) {
                // 中危敏感词，人工审核
                try matched_rules.append(try self.allocator.dupe(u8, "中危敏感词审核"));
                return ModerationResult{
                    .action = .review,
                    .reason = try self.allocator.dupe(u8, "包含中危敏感词，需要人工审核"),
                    .matched_words = matches,
                    .matched_rules = try matched_rules.toOwnedSlice(),
                };
            } else {
                // 低危敏感词，自动替换后通过
                try matched_rules.append(try self.allocator.dupe(u8, "低危敏感词替换"));
                const cleaned = try self.filter.replace(ctx.content_text);
                return ModerationResult{
                    .action = .auto_approve,
                    .reason = try self.allocator.dupe(u8, "包含低危敏感词，已自动替换"),
                    .matched_words = matches,
                    .matched_rules = try matched_rules.toOwnedSlice(),
                    .cleaned_text = cleaned,
                };
            }
        }
        
        // 3. 检查发布频率
        if (ctx.recent_comment_count > 5) {
            try matched_rules.append(try self.allocator.dupe(u8, "高频发布审核"));
            return ModerationResult{
                .action = .review,
                .reason = try self.allocator.dupe(u8, "发布频率过高，需要人工审核"),
                .matched_words = &[_]MatchResult{},
                .matched_rules = try matched_rules.toOwnedSlice(),
            };
        }
        
        // 4. 检查用户等级
        if (ctx.user_register_days < 7) {
            try matched_rules.append(try self.allocator.dupe(u8, "新用户审核"));
            return ModerationResult{
                .action = .review,
                .reason = try self.allocator.dupe(u8, "新用户评论需要人工审核"),
                .matched_words = &[_]MatchResult{},
                .matched_rules = try matched_rules.toOwnedSlice(),
            };
        }
        
        // 5. 检查用户信用分
        if (ctx.user_credit_score < 60) {
            try matched_rules.append(try self.allocator.dupe(u8, "低信用用户审核"));
            return ModerationResult{
                .action = .review,
                .reason = try self.allocator.dupe(u8, "用户信用分过低，需要人工审核"),
                .matched_words = &[_]MatchResult{},
                .matched_rules = try matched_rules.toOwnedSlice(),
            };
        }
        
        // 6. 默认自动通过
        return ModerationResult{
            .action = .auto_approve,
            .reason = try self.allocator.dupe(u8, "内容正常，自动通过"),
            .matched_words = &[_]MatchResult{},
            .matched_rules = try matched_rules.toOwnedSlice(),
        };
    }
    
    /// 释放审核结果
    pub fn freeResult(self: *Self, result: *ModerationResult) void {
        self.allocator.free(result.reason);
        self.allocator.free(result.matched_words);
        for (result.matched_rules) |rule| {
            self.allocator.free(rule);
        }
        self.allocator.free(result.matched_rules);
        if (result.cleaned_text) |text| {
            self.allocator.free(text);
        }
    }
};
