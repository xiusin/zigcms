//! 敏感词过滤器（DFA 算法实现）
//!
//! 功能：
//! - 敏感词检测
//! - 敏感词替换
//! - 高性能匹配（DFA 状态机）

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 敏感词信息
pub const SensitiveWord = struct {
    word: []const u8,
    category: []const u8,
    level: u8,
    action: []const u8,
    replacement: []const u8,
};

/// 匹配结果
pub const MatchResult = struct {
    word: []const u8,
    start_pos: usize,
    end_pos: usize,
    category: []const u8,
    level: u8,
    action: []const u8,
};

/// DFA 节点
const DFANode = struct {
    children: std.StringHashMap(*DFANode),
    is_end: bool = false,
    word_info: ?SensitiveWord = null,
    allocator: Allocator,
    
    const Self = @This();
    
    pub fn init(allocator: Allocator) !*Self {
        const node = try allocator.create(Self);
        node.* = .{
            .children = std.StringHashMap(*DFANode).init(allocator),
            .allocator = allocator,
        };
        return node;
    }
    
    pub fn deinit(self: *Self) void {
        var it = self.children.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.children.deinit();
        self.allocator.destroy(self);
    }
};

/// 敏感词过滤器
pub const SensitiveWordFilter = struct {
    allocator: Allocator,
    root: *DFANode,
    
    const Self = @This();
    
    pub fn init(allocator: Allocator) !Self {
        return .{
            .allocator = allocator,
            .root = try DFANode.init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.root.deinit();
    }
    
    /// 添加敏感词
    pub fn addWord(self: *Self, word_info: SensitiveWord) !void {
        var current = self.root;
        
        // 遍历敏感词的每个字符
        var i: usize = 0;
        while (i < word_info.word.len) {
            // 获取 UTF-8 字符
            const char_len = std.unicode.utf8ByteSequenceLength(word_info.word[i]) catch 1;
            const char = word_info.word[i..i + char_len];
            
            // 查找或创建子节点
            const child = current.children.get(char) orelse blk: {
                const new_node = try DFANode.init(self.allocator);
                try current.children.put(try self.allocator.dupe(u8, char), new_node);
                break :blk new_node;
            };
            
            current = child;
            i += char_len;
        }
        
        // 标记为敏感词结束节点
        current.is_end = true;
        current.word_info = .{
            .word = try self.allocator.dupe(u8, word_info.word),
            .category = try self.allocator.dupe(u8, word_info.category),
            .level = word_info.level,
            .action = try self.allocator.dupe(u8, word_info.action),
            .replacement = try self.allocator.dupe(u8, word_info.replacement),
        };
    }
    
    /// 检测文本中的敏感词
    pub fn detect(self: *Self, text: []const u8) ![]MatchResult {
        var results = std.ArrayList(MatchResult).init(self.allocator);
        errdefer results.deinit();
        
        var i: usize = 0;
        while (i < text.len) {
            const char_len = std.unicode.utf8ByteSequenceLength(text[i]) catch 1;
            
            // 从当前位置开始匹配
            if (try self.matchFrom(text, i)) |match| {
                try results.append(match);
                i = match.end_pos;
            } else {
                i += char_len;
            }
        }
        
        return try results.toOwnedSlice();
    }
    
    /// 从指定位置开始匹配
    fn matchFrom(self: *Self, text: []const u8, start: usize) !?MatchResult {
        var current = self.root;
        var i = start;
        var last_match: ?MatchResult = null;
        
        while (i < text.len) {
            const char_len = std.unicode.utf8ByteSequenceLength(text[i]) catch 1;
            const char = text[i..i + char_len];
            
            // 查找子节点
            const child = current.children.get(char) orelse break;
            current = child;
            i += char_len;
            
            // 如果是敏感词结束节点，记录匹配结果
            if (current.is_end) {
                if (current.word_info) |info| {
                    last_match = MatchResult{
                        .word = info.word,
                        .start_pos = start,
                        .end_pos = i,
                        .category = info.category,
                        .level = info.level,
                        .action = info.action,
                    };
                }
            }
        }
        
        return last_match;
    }
    
    /// 替换文本中的敏感词
    pub fn replace(self: *Self, text: []const u8) ![]const u8 {
        const matches = try self.detect(text);
        defer self.allocator.free(matches);
        
        if (matches.len == 0) {
            return try self.allocator.dupe(u8, text);
        }
        
        // 构建替换后的文本
        var result = std.ArrayList(u8).init(self.allocator);
        defer result.deinit();
        
        var last_pos: usize = 0;
        for (matches) |match| {
            // 添加匹配前的文本
            try result.appendSlice(text[last_pos..match.start_pos]);
            
            // 根据 action 决定如何处理
            if (std.mem.eql(u8, match.action, "replace")) {
                // 替换为 ***
                try result.appendSlice("***");
            } else if (std.mem.eql(u8, match.action, "block")) {
                // 拦截（不添加）
            } else {
                // 其他情况保留原文
                try result.appendSlice(text[match.start_pos..match.end_pos]);
            }
            
            last_pos = match.end_pos;
        }
        
        // 添加剩余文本
        try result.appendSlice(text[last_pos..]);
        
        return try result.toOwnedSlice();
    }
    
    /// 检查文本是否包含敏感词
    pub fn contains(self: *Self, text: []const u8) !bool {
        const matches = try self.detect(text);
        defer self.allocator.free(matches);
        return matches.len > 0;
    }
    
    /// 获取文本中的最高敏感词等级
    pub fn getMaxLevel(self: *Self, text: []const u8) !u8 {
        const matches = try self.detect(text);
        defer self.allocator.free(matches);
        
        var max_level: u8 = 0;
        for (matches) |match| {
            if (match.level > max_level) {
                max_level = match.level;
            }
        }
        
        return max_level;
    }
};

/// 从数据库加载敏感词
pub fn loadSensitiveWords(allocator: Allocator, repository: anytype) ![]SensitiveWord {
    // 从数据库查询启用的敏感词
    const db_words = try repository.findEnabled();
    
    // 转换为 SensitiveWord 结构
    const words = try allocator.alloc(SensitiveWord, db_words.len);
    for (db_words, 0..) |db_word, i| {
        words[i] = .{
            .word = try allocator.dupe(u8, db_word.word),
            .category = try allocator.dupe(u8, db_word.category),
            .level = @intCast(db_word.level),
            .action = try allocator.dupe(u8, db_word.action),
            .replacement = try allocator.dupe(u8, db_word.replacement),
        };
    }
    
    return words;
}

/// 从数据库加载敏感词（模拟数据版本，用于测试）
pub fn loadSensitiveWordsMock(allocator: Allocator) ![]SensitiveWord {
    const words = try allocator.alloc(SensitiveWord, 5);
    words[0] = .{
        .word = try allocator.dupe(u8, "傻逼"),
        .category = try allocator.dupe(u8, "abuse"),
        .level = 2,
        .action = try allocator.dupe(u8, "replace"),
        .replacement = try allocator.dupe(u8, "***"),
    };
    words[1] = .{
        .word = try allocator.dupe(u8, "垃圾"),
        .category = try allocator.dupe(u8, "abuse"),
        .level = 1,
        .action = try allocator.dupe(u8, "replace"),
        .replacement = try allocator.dupe(u8, "***"),
    };
    words[2] = .{
        .word = try allocator.dupe(u8, "加微信"),
        .category = try allocator.dupe(u8, "ad"),
        .level = 1,
        .action = try allocator.dupe(u8, "replace"),
        .replacement = try allocator.dupe(u8, "***"),
    };
    words[3] = .{
        .word = try allocator.dupe(u8, "敏感词1"),
        .category = try allocator.dupe(u8, "political"),
        .level = 3,
        .action = try allocator.dupe(u8, "block"),
        .replacement = try allocator.dupe(u8, ""),
    };
    words[4] = .{
        .word = try allocator.dupe(u8, "色情词1"),
        .category = try allocator.dupe(u8, "porn"),
        .level = 3,
        .action = try allocator.dupe(u8, "block"),
        .replacement = try allocator.dupe(u8, ""),
    };
    
    return words;
}

/// 释放敏感词列表
pub fn freeSensitiveWords(allocator: Allocator, words: []SensitiveWord) void {
    for (words) |word| {
        allocator.free(word.word);
        allocator.free(word.category);
        allocator.free(word.action);
        allocator.free(word.replacement);
    }
    allocator.free(words);
}
