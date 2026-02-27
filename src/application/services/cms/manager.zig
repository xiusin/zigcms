//! CMS 管理器
//!
//! 提供统一的 CMS 管理入口，支持线程安全操作。

const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const model_mod = @import("model.zig");
const field_mod = @import("field.zig");
const document_mod = @import("document.zig");

const Model = model_mod.Model;
const ModelType = model_mod.ModelType;
const Field = field_mod.Field;
const FieldType = field_mod.FieldType;
const Document = document_mod.Document;
const DocumentStatus = document_mod.DocumentStatus;

/// CMS 管理器
/// 线程安全的单例模式，统一管理模型、字段、文档
pub const Manager = struct {
    const Self = @This();

    allocator: Allocator,
    mutex: Mutex,

    // 缓存
    model_cache: std.AutoHashMap(i32, Model),
    field_cache: std.AutoHashMap(i32, []Field),

    /// 初始化管理器
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .mutex = .{},
            .model_cache = std.AutoHashMap(i32, Model).init(allocator),
            .field_cache = std.AutoHashMap(i32, []Field).init(allocator),
        };
    }

    /// 释放资源
    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // 清理字段缓存
        var field_iter = self.field_cache.valueIterator();
        while (field_iter.next()) |fields| {
            self.allocator.free(fields.*);
        }
        self.field_cache.deinit();
        self.model_cache.deinit();
    }

    // ========================================================================
    // 模型管理
    // ========================================================================

    /// 获取模型（带缓存）
    pub fn getModel(self: *Self, model_id: i32) ?Model {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.model_cache.get(model_id);
    }

    /// 缓存模型
    pub fn cacheModel(self: *Self, model: Model) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (model.id) |id| {
            try self.model_cache.put(id, model);
        }
    }

    /// 清除模型缓存
    pub fn invalidateModelCache(self: *Self, model_id: i32) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        _ = self.model_cache.remove(model_id);
        // 同时清除关联的字段缓存
        if (self.field_cache.fetchRemove(model_id)) |kv| {
            self.allocator.free(kv.value);
        }
    }

    // ========================================================================
    // 字段管理
    // ========================================================================

    /// 获取模型的所有字段（带缓存）
    pub fn getFields(self: *Self, model_id: i32) ?[]Field {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.field_cache.get(model_id);
    }

    /// 缓存字段列表
    pub fn cacheFields(self: *Self, model_id: i32, fields: []Field) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // 如果已存在，先释放
        if (self.field_cache.fetchRemove(model_id)) |kv| {
            self.allocator.free(kv.value);
        }

        // 复制字段数据
        const fields_copy = try self.allocator.dupe(Field, fields);
        try self.field_cache.put(model_id, fields_copy);
    }

    /// 清除字段缓存
    pub fn invalidateFieldCache(self: *Self, model_id: i32) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.field_cache.fetchRemove(model_id)) |kv| {
            self.allocator.free(kv.value);
        }
    }

    // ========================================================================
    // 文档验证
    // ========================================================================

    /// 验证文档数据
    pub fn validateDocument(self: *Self, model_id: i32, data: anytype) !?[]const u8 {
        const fields = self.getFields(model_id) orelse return null;

        for (fields) |field| {
            if (field.is_required) {
                // 检查必填字段
                if (@hasField(@TypeOf(data), field.field_name)) {
                    const value = @field(data, field.field_name);
                    if (@TypeOf(value) == []const u8 and value.len == 0) {
                        return std.fmt.allocPrint(self.allocator, "{s} 不能为空", .{field.field_label});
                    }
                }
            }
        }

        return null;
    }

    // ========================================================================
    // 统计信息
    // ========================================================================

    /// 获取缓存统计
    pub fn getCacheStats(self: *Self) CacheStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        return .{
            .model_count = self.model_cache.count(),
            .field_cache_count = self.field_cache.count(),
        };
    }
};

/// 缓存统计
pub const CacheStats = struct {
    model_count: usize,
    field_cache_count: usize,
};

/// 创建管理器实例
pub fn create(allocator: Allocator) Manager {
    return Manager.init(allocator);
}

// ============================================================================
// 测试
// ============================================================================

test "Manager: 基本操作" {
    const allocator = std.testing.allocator;
    var manager = Manager.init(allocator);
    defer manager.deinit();

    // 缓存模型
    const model = Model{
        .id = 1,
        .name = "测试模型",
        .table_name = "test",
    };
    try manager.cacheModel(model);

    // 获取模型
    const cached = manager.getModel(1);
    try std.testing.expect(cached != null);
    try std.testing.expectEqualStrings("测试模型", cached.?.name);

    // 清除缓存
    manager.invalidateModelCache(1);
    try std.testing.expect(manager.getModel(1) == null);
}

test "Manager: 线程安全" {
    const allocator = std.testing.allocator;
    var manager = Manager.init(allocator);
    defer manager.deinit();

    // 并发测试
    var threads: [4]std.Thread = undefined;
    for (&threads, 0..) |*t, i| {
        t.* = try std.Thread.spawn(.{}, struct {
            fn run(mgr: *Manager, id: usize) void {
                const model = Model{
                    .id = @intCast(id),
                    .name = "test",
                    .table_name = "test",
                };
                mgr.cacheModel(model) catch {};
                _ = mgr.getModel(@intCast(id));
            }
        }.run, .{ &manager, i });
    }

    for (&threads) |*t| {
        t.join();
    }
}
