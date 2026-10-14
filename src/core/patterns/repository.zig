//! 仓储模式 (Repository Pattern)
//!
//! 仓储抽象了领域对象持久化的细节，提供集合式接口访问聚合。
//! 这是统一的仓储接口定义，消除了原 shared_kernel 和 domain/repositories 的重复。

const std = @import("std");
const core_io = @import("../io.zig");

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
            if (self.page_size == 0) return 0;
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
///
/// Zig 没有闭包，叶子规约用 `ctx + predicate` 显式捕获上下文；
/// `and_`/`or_`/`not` 组合时在堆上分配 Combo 节点。
///
/// 所有权约定：组合结果拥有左右操作数身上的 Combo 节点（所有权转移），
/// 调用方只需对**最终结果**调用 `deinit`，不得再释放中间规约。
pub fn Specification(comptime T: type) type {
    return struct {
        const Self = @This();

        /// 判定函数：ctx 传递上下文（叶子为调用方数据，组合为 Combo 节点）
        pub const Predicate = *const fn (ctx: ?*const anyopaque, entity: *const T) bool;

        const ComboOp = enum { and_op, or_op, not_op };

        const Combo = struct {
            op: ComboOp,
            left: Self,
            right: ?Self = null, // not 时为 null
        };

        allocator: std.mem.Allocator,
        predicate: Predicate,
        ctx: ?*const anyopaque = null,
        /// 非 null 表示本规约是组合节点（拥有它，deinit 递归释放）
        combo: ?*Combo = null,

        /// 创建无上下文的叶子规约
        pub fn init(allocator: std.mem.Allocator, predicate: Predicate) Self {
            return .{ .allocator = allocator, .predicate = predicate };
        }

        /// 创建带上下文的叶子规约
        pub fn initWithCtx(allocator: std.mem.Allocator, ctx: *const anyopaque, predicate: Predicate) Self {
            return .{ .allocator = allocator, .predicate = predicate, .ctx = ctx };
        }

        pub fn isSatisfiedBy(self: Self, entity: *const T) bool {
            return self.predicate(self.ctx, entity);
        }

        fn evalCombo(ctx: ?*const anyopaque, entity: *const T) bool {
            const node: *const Combo = @ptrCast(@alignCast(ctx.?));
            const left = node.left.isSatisfiedBy(entity);
            return switch (node.op) {
                .and_op => left and node.right.?.isSatisfiedBy(entity),
                .or_op => left or node.right.?.isSatisfiedBy(entity),
                .not_op => !left,
            };
        }

        /// 与操作；结果拥有新 Combo 节点与两侧操作数的 Combo，用完对结果 `deinit`
        pub fn and_(self: Self, other: Self) !Self {
            const node = try self.allocator.create(Combo);
            errdefer self.allocator.destroy(node);
            node.* = .{ .op = .and_op, .left = self, .right = other };
            return .{ .allocator = self.allocator, .predicate = evalCombo, .ctx = node, .combo = node };
        }

        /// 或操作；所有权同 `and_`
        pub fn or_(self: Self, other: Self) !Self {
            const node = try self.allocator.create(Combo);
            errdefer self.allocator.destroy(node);
            node.* = .{ .op = .or_op, .left = self, .right = other };
            return .{ .allocator = self.allocator, .predicate = evalCombo, .ctx = node, .combo = node };
        }

        /// 非操作；所有权同 `and_`
        pub fn not(self: Self) !Self {
            const node = try self.allocator.create(Combo);
            errdefer self.allocator.destroy(node);
            node.* = .{ .op = .not_op, .left = self };
            return .{ .allocator = self.allocator, .predicate = evalCombo, .ctx = node, .combo = node };
        }

        /// 释放本规约拥有的 Combo 节点（叶子规约为空操作，可安全调用）
        pub fn deinit(self: *Self) void {
            if (self.combo) |node| {
                var left = node.left;
                left.deinit();
                if (node.right) |*right| right.deinit();
                self.allocator.destroy(node);
                self.combo = null;
            }
        }
    };
}
