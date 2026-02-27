//! 仓储模式 (Repository Pattern)
//!
//! 仓储抽象了领域对象持久化的细节，提供集合式接口访问聚合。
//! 这是统一的仓储接口定义，消除了原 shared_kernel 和 domain/repositories 的重复。

const std = @import("std");

/// 仓储接口生成器
pub fn Repository(comptime T: type, comptime IdType: type) type {
    return struct {
        const Self = @This();

        ptr: *anyopaque,
        vtable: *const VTable,

        pub const VTable = struct {
            findById: *const fn (*anyopaque, IdType) anyerror!?T,
            findAll: *const fn (*anyopaque) anyerror![]T,
            save: *const fn (*anyopaque, T) anyerror!T,
            update: *const fn (*anyopaque, T) anyerror!void,
            delete: *const fn (*anyopaque, IdType) anyerror!void,
            count: *const fn (*anyopaque) anyerror!usize,
        };

        /// 根据 ID 查找
        pub fn findById(self: Self, id: IdType) !?T {
            return self.vtable.findById(self.ptr, id);
        }

        /// 查找所有
        pub fn findAll(self: Self) ![]T {
            return self.vtable.findAll(self.ptr);
        }

        /// 保存（新增）
        pub fn save(self: Self, entity: T) !T {
            return self.vtable.save(self.ptr, entity);
        }

        /// 更新
        pub fn update(self: Self, entity: T) !void {
            return self.vtable.update(self.ptr, entity);
        }

        /// 删除
        pub fn delete(self: Self, id: IdType) !void {
            return self.vtable.delete(self.ptr, id);
        }

        /// 统计数量
        pub fn count(self: Self) !usize {
            return self.vtable.count(self.ptr);
        }
    };
}

/// 分页结果
pub fn PageResult(comptime T: type) type {
    return struct {
        items: []T,
        total: usize,
        page: u32,
        page_size: u32,

        pub fn totalPages(self: @This()) u32 {
            return @intCast((self.total + @as(usize, self.page_size) - 1) / @as(usize, self.page_size));
        }

        pub fn hasNext(self: @This()) bool {
            return self.page < self.totalPages();
        }

        pub fn hasPrev(self: @This()) bool {
            return self.page > 1;
        }
    };
}

/// 查询规约
pub fn Specification(comptime T: type) type {
    return struct {
        const Self = @This();

        is_satisfied_fn: *const fn (*const T) bool,

        pub fn isSatisfiedBy(self: Self, entity: *const T) bool {
            return self.is_satisfied_fn(entity);
        }

        /// 与操作
        pub fn and_(self: Self, other: Self) Self {
            const combined = struct {
                fn check(e: *const T) bool {
                    return self.isSatisfiedBy(e) and other.isSatisfiedBy(e);
                }
            };
            return .{ .is_satisfied_fn = combined.check };
        }

        /// 或操作
        pub fn or_(self: Self, other: Self) Self {
            const combined = struct {
                fn check(e: *const T) bool {
                    return self.isSatisfiedBy(e) or other.isSatisfiedBy(e);
                }
            };
            return .{ .is_satisfied_fn = combined.check };
        }

        /// 非操作
        pub fn not(self: Self) Self {
            const negated = struct {
                fn check(e: *const T) bool {
                    return !self.isSatisfiedBy(e);
                }
            };
            return .{ .is_satisfied_fn = negated.check };
        }
    };
}
