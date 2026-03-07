//! 敏感词仓储接口

const std = @import("std");
const SensitiveWord = @import("../entities/sensitive_word.model.zig").SensitiveWord;

/// 敏感词仓储接口
pub const SensitiveWordRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    
    const Self = @This();
    
    pub const VTable = struct {
        findById: *const fn (*anyopaque, i32) anyerror!?SensitiveWord,
        findAll: *const fn (*anyopaque) anyerror![]SensitiveWord,
        findByCategory: *const fn (*anyopaque, []const u8) anyerror![]SensitiveWord,
        findByLevel: *const fn (*anyopaque, i32) anyerror![]SensitiveWord,
        findEnabled: *const fn (*anyopaque) anyerror![]SensitiveWord,
        save: *const fn (*anyopaque, *SensitiveWord) anyerror!void,
        delete: *const fn (*anyopaque, i32) anyerror!void,
        count: *const fn (*anyopaque) anyerror!i32,
    };
    
    /// 根据 ID 查找
    pub fn findById(self: *Self, id: i32) !?SensitiveWord {
        return self.vtable.findById(self.ptr, id);
    }
    
    /// 查找所有敏感词
    pub fn findAll(self: *Self) ![]SensitiveWord {
        return self.vtable.findAll(self.ptr);
    }
    
    /// 根据分类查找
    pub fn findByCategory(self: *Self, category: []const u8) ![]SensitiveWord {
        return self.vtable.findByCategory(self.ptr, category);
    }
    
    /// 根据等级查找
    pub fn findByLevel(self: *Self, level: i32) ![]SensitiveWord {
        return self.vtable.findByLevel(self.ptr, level);
    }
    
    /// 查找启用的敏感词
    pub fn findEnabled(self: *Self) ![]SensitiveWord {
        return self.vtable.findEnabled(self.ptr);
    }
    
    /// 保存敏感词
    pub fn save(self: *Self, word: *SensitiveWord) !void {
        return self.vtable.save(self.ptr, word);
    }
    
    /// 删除敏感词
    pub fn delete(self: *Self, id: i32) !void {
        return self.vtable.delete(self.ptr, id);
    }
    
    /// 统计数量
    pub fn count(self: *Self) !i32 {
        return self.vtable.count(self.ptr);
    }
};

/// 创建仓储实例
pub fn create(impl: anytype, vtable: *const SensitiveWordRepository.VTable) SensitiveWordRepository {
    return .{
        .ptr = impl,
        .vtable = vtable,
    };
}
