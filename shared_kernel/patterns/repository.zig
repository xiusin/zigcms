//! 仓储模式 (Repository Pattern)
//!
//! 仓储抽象了领域对象持久化的细节，提供了一个集合式的接口来访问聚合。
//! 仓储隐藏了数据访问的技术细节，使领域层与基础设施层解耦。
//!
//! ## 特性
//! - 集合式接口：像操作集合一样操作聚合
//! - 领域驱动：返回领域对象，不暴露内部实现
//! - 多态实现：可以切换不同的持久化方式
//!
//! ## 使用示例
//! ```zig
//! // 定义用户仓储接口（领域层）
//! const UserRepository = Repository(User, i32);
//!
//! // 实现仓储接口（基础设施层）
//! const PostgresUserRepo = struct {
//!     pub fn toInterface(self: *PostgresUserRepo) UserRepository {
//!         return .{
//!             .ptr = self,
//!             .vtable = &UserRepository.VTable{
//!                 .findById = findByIdImpl,
//!                 .save = saveImpl,
//!                 ...
//!             },
//!         };
//! }
//! ```
//!
//! ## 设计原则
//! - 只暴露必要的操作
//! - 不暴露SQL或数据库细节
//! - 返回领域对象

const std = @import("std");
const Entity = @import("entity.zig").Entity;

/// 仓储生成器
///
/// ## 类型参数
/// - `T`: 聚合根类型
/// - `IdType`: ID类型（默认为T的id字段类型）
pub fn Repository(comptime T: type, comptime IdType: type) type {
    _ = IdType;
    return struct {
        const Self = @This();

        /// 指向实现实例的指针
        ptr: *anyopaque,

        /// 虚函数表
        vtable: *const VTable,

        /// 仓储虚函数表
        pub const VTable = struct {
            /// 根据ID查找
            findById: *const fn (*anyopaque, IdType(T)) anyerror!?T,
            /// 查找所有
            findAll: *const fn (*anyopaque) anyerror![]T,
            /// 保存（新增或更新）
            save: *const fn (*anyopaque, T) anyerror!T,
            /// 删除
            delete: *const fn (*anyopaque, IdType(T)) anyerror!void,
            /// 统计数量
            count: *const fn (*anyopaque) anyerror!usize,
            /// 根据条件查找
            findBy: *const fn (*anyopaque, []const []const u8, []const Value) anyerror![]T,
            /// 分页查询
            findPage: *const fn (*anyopaque, u32, u32) anyerror!PageResult(T),
        };

        /// 分页结果
        pub const PageResult = struct {
            items: []T,
            total: usize,
            page: u32,
            page_size: u32,
        };

        /// 值类型（用于查询条件）
        pub const Value = std.json.Value;

        /// 根据ID查找聚合
        pub fn findById(self: Self, id: IdType(T)) !?T {
            return self.vtable.findById(self.ptr, id);
        }

        /// 查找所有聚合
        pub fn findAll(self: Self) ![]T {
            return self.vtable.findAll(self.ptr);
        }

        /// 保存聚合（新增或更新）
        pub fn save(self: Self, agg: T) !T {
            return self.vtable.save(self.ptr, agg);
        }

        /// 删除聚合
        pub fn delete(self: Self, id: IdType(T)) !void {
            return self.vtable.delete(self.ptr, id);
        }

        /// 统计数量
        pub fn count(self: Self) !usize {
            return self.vtable.count(self.ptr);
        }

        /// 根据条件查找
        pub fn findBy(self: Self, fields: []const []const u8, values: []const Value) ![]T {
            return self.vtable.findBy(self.ptr, fields, values);
        }

        /// 分页查询
        pub fn findPage(self: Self, page: u32, page_size: u32) !PageResult(T) {
            return self.vtable.findPage(self.ptr, page, page_size);
        }

        /// 创建接口实例
        pub fn create(ptr: *anyopaque, vtable: *const VTable) Self {
            return .{ .ptr = ptr, .vtable = vtable };
        }
    };
}

/// 仓储工厂
pub const RepositoryFactory = struct {
    /// 创建仓储接口
    pub fn create(
        comptime T: type,
        comptime IdType: type,
        ptr: *anyopaque,
        vtable: *const Repository(T, IdType).VTable,
    ) Repository(T, IdType) {
        return Repository(T, IdType).create(ptr, vtable);
    }
};

/// 仓储实现基类
///
/// 为常用操作提供默认实现
pub fn RepositoryImpl(comptime T: type, comptime IdType: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        /// 默认的 findById 实现
        pub fn findById(_: *Self, _: IdType(T)) !?T {
            return null;
        }

        /// 默认的 findAll 实现
        pub fn findAll(_: *Self) ![]T {
            return &[_]T{};
        }

        /// 默认的 save 实现
        pub fn save(_: *Self, agg: T) !T {
            return agg;
        }

        /// 默认的 delete 实现
        pub fn delete(_: *Self, _: IdType(T)) !void {}

        /// 默认的 count 实现
        pub fn count(_: *Self) !usize {
            return 0;
        }

        /// 默认的 findBy 实现
        pub fn findBy(_: *Self, _: []const []const u8, _: []const std.json.Value) ![]T {
            return &[_]T{};
        }

        /// 默认的 findPage 实现
        pub fn findPage(_: *Self, _: u32, _: u32) !Repository(T, IdType).PageResult(T) {
            return .{
                .items = &[_]T{},
                .total = 0,
                .page = 0,
                .page_size = 0,
            };
        }

        /// 创建vtable
        pub fn vtable() Repository(T, IdType).VTable {
            return .{
                .findById = findById,
                .findAll = findAll,
                .save = save,
                .delete = delete,
                .count = count,
                .findBy = findBy,
                .findPage = findPage,
            };
        }
    };
}

/// 查询规约 (Specification Pattern)
///
/// 用于构建复杂的查询条件
pub const Specification = struct {
    const Self = @This();

    /// 查询条件
    conditions: std.ArrayList(Condition),

    /// 查询条件类型
    pub const Condition = struct {
        field: []const u8,
        operator: Operator,
        value: std.json.Value,
    };

    /// 操作符
    pub const Operator = enum {
        equals,
        not_equals,
        greater_than,
        less_than,
        greater_than_or_equals,
        less_than_or_equals,
        like,
        in_array,
        between,
        is_null,
        is_not_null,
    };

    /// 添加相等条件
    pub fn equals(self: *Self, field: []const u8, value: std.json.Value) !void {
        try self.conditions.append(.{
            .field = field,
            .operator = .equals,
            .value = value,
        });
    }

    /// 添加IN条件
    pub fn inArray(self: *Self, field: []const u8, values: []const std.json.Value) !void {
        try self.conditions.append(.{
            .field = field,
            .operator = .in_array,
            .value = .{ .array = values },
        });
    }

    /// 构建查询条件
    pub fn build(self: Self) []Condition {
        return self.conditions.items;
    }

    /// 初始化规约
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .conditions = std.ArrayList(Condition).init(allocator),
        };
    }

    /// 清理
    pub fn deinit(self: *Self) void {
        self.conditions.deinit();
    }
};
