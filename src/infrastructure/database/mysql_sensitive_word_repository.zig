//! MySQL 敏感词仓储实现
//!
//! 基于 sql ORM（defineWithConfig）实现领域层 SensitiveWordRepository 接口。
//! 表结构见 migrations/008_comment_moderation.sql（sensitive_words）。

const std = @import("std");
const Allocator = std.mem.Allocator;
const sql = @import("../../application/services/sql/orm.zig");
const SensitiveWord = @import("../../domain/entities/sensitive_word.model.zig").SensitiveWord;
const SensitiveWordRepository = @import("../../domain/repositories/sensitive_word_repository.zig").SensitiveWordRepository;

/// 敏感词 ORM 模型（sensitive_words，字段与领域实体一致）
const OrmSensitiveWord = sql.defineWithConfig(SensitiveWord, .{
    .table_name = "sensitive_words",
    .primary_key = "id",
});

/// MySQL 敏感词仓储实现
pub const MysqlSensitiveWordRepository = struct {
    allocator: Allocator,
    db: *sql.Database,

    const Self = @This();

    pub fn init(allocator: Allocator, db: *sql.Database) Self {
        if (!OrmSensitiveWord.hasDb()) OrmSensitiveWord.use(db);
        return .{ .allocator = allocator, .db = db };
    }

    /// 根据 ID 查找
    pub fn findById(self: *Self, id: i32) !?SensitiveWord {
        var q = OrmSensitiveWord.Query();
        _ = q.where("id", "=", id);
        var result = try q.getWithArena(self.allocator);
        defer result.deinit();

        if (result.items().len == 0) return null;
        return try self.deepCopy(result.items()[0]);
    }

    /// 查找所有敏感词
    pub fn findAll(self: *Self) ![]SensitiveWord {
        var q = OrmSensitiveWord.Query();
        var result = try q.getWithArena(self.allocator);
        defer result.deinit();
        return try self.deepCopyAll(result.items());
    }

    /// 根据分类查找
    pub fn findByCategory(self: *Self, category: []const u8) ![]SensitiveWord {
        var q = OrmSensitiveWord.Query();
        _ = q.where("category", "=", category);
        var result = try q.getWithArena(self.allocator);
        defer result.deinit();
        return try self.deepCopyAll(result.items());
    }

    /// 根据等级查找
    pub fn findByLevel(self: *Self, level: i32) ![]SensitiveWord {
        var q = OrmSensitiveWord.Query();
        _ = q.where("level", "=", level);
        var result = try q.getWithArena(self.allocator);
        defer result.deinit();
        return try self.deepCopyAll(result.items());
    }

    /// 查找启用的敏感词
    pub fn findEnabled(self: *Self) ![]SensitiveWord {
        var q = OrmSensitiveWord.Query();
        _ = q.where("status", "=", 1);
        var result = try q.getWithArena(self.allocator);
        defer result.deinit();
        return try self.deepCopyAll(result.items());
    }

    /// 保存敏感词（存在 id 则更新，否则创建）
    pub fn save(self: *Self, word: *SensitiveWord) !void {
        _ = self;
        if (word.id) |id| {
            _ = try OrmSensitiveWord.UpdateWith(id, .{
                .word = word.word,
                .category = word.category,
                .level = word.level,
                .action = word.action,
                .replacement = word.replacement,
                .status = word.status,
            });
        } else {
            const created = try OrmSensitiveWord.Create(.{
                .word = word.word,
                .category = word.category,
                .level = word.level,
                .action = word.action,
                .replacement = word.replacement,
                .status = word.status,
            });
            word.id = created.id orelse return error.MissingId;
        }
    }

    /// 删除敏感词
    pub fn delete(self: *Self, id: i32) !void {
        _ = self;
        _ = try OrmSensitiveWord.Destroy(id);
    }

    /// 统计数量
    pub fn count(self: *Self) !i32 {
        _ = self;
        var q = OrmSensitiveWord.Query();
        const n = try q.count();
        return @intCast(n);
    }

    /// 释放 deepCopy/deepCopyAll 返回的内存（与查询成对使用）
    pub fn freeWords(self: *Self, words: []SensitiveWord) void {
        for (words) |*w| {
            self.allocator.free(w.word);
            self.allocator.free(w.category);
            self.allocator.free(w.action);
            self.allocator.free(w.replacement);
        }
        self.allocator.free(words);
    }

    // ========================================================================
    // 内部：ORM 结果深拷贝为自包含领域对象（arena 释放后仍可用）
    // ========================================================================

    fn deepCopy(self: *Self, w: SensitiveWord) !SensitiveWord {
        return SensitiveWord{
            .id = w.id,
            .word = try self.allocator.dupe(u8, w.word),
            .category = try self.allocator.dupe(u8, w.category),
            .level = w.level,
            .action = try self.allocator.dupe(u8, w.action),
            .replacement = try self.allocator.dupe(u8, w.replacement),
            .status = w.status,
            .created_at = w.created_at,
            .updated_at = w.updated_at,
        };
    }

    fn deepCopyAll(self: *Self, words: []const SensitiveWord) ![]SensitiveWord {
        var list: std.ArrayList(SensitiveWord) = .empty;
        errdefer list.deinit(self.allocator);
        for (words) |w| {
            try list.append(self.allocator, try self.deepCopy(w));
        }
        return try list.toOwnedSlice(self.allocator);
    }

    /// 领域接口 VTable
    pub fn vtable() SensitiveWordRepository.VTable {
        return .{
            .findById = findByIdImpl,
            .findAll = findAllImpl,
            .findByCategory = findByCategoryImpl,
            .findByLevel = findByLevelImpl,
            .findEnabled = findEnabledImpl,
            .save = saveImpl,
            .delete = deleteImpl,
            .count = countImpl,
            .freeWords = freeWordsImpl,
        };
    }

    fn findByIdImpl(ptr: *anyopaque, id: i32) anyerror!?SensitiveWord {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findById(id);
    }

    fn findAllImpl(ptr: *anyopaque) anyerror![]SensitiveWord {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findAll();
    }

    fn findByCategoryImpl(ptr: *anyopaque, category: []const u8) anyerror![]SensitiveWord {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findByCategory(category);
    }

    fn findByLevelImpl(ptr: *anyopaque, level: i32) anyerror![]SensitiveWord {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findByLevel(level);
    }

    fn findEnabledImpl(ptr: *anyopaque) anyerror![]SensitiveWord {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findEnabled();
    }

    fn saveImpl(ptr: *anyopaque, word: *SensitiveWord) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.save(word);
    }

    fn deleteImpl(ptr: *anyopaque, id: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.delete(id);
    }

    fn countImpl(ptr: *anyopaque) anyerror!i32 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.count();
    }

    fn freeWordsImpl(ptr: *anyopaque, words: []SensitiveWord) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.freeWords(words);
    }
};
