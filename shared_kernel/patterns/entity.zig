//! 实体模式 (Entity Pattern)
//!
//! 实体是具有唯一标识的领域对象，其相等性基于标识而不是属性值。
//! 实体可以随时间变化，但其标识保持不变。
//!
//! ## 特性
//! - 唯一标识：每个实体都有唯一的标识符
//! - 可变性：实体的属性可以随时间变化
//! - 标识相等性：两个实体相等当且仅当它们的ID相等
//!
//! ## 使用示例
//! ```zig
//! const User = Entity(struct {
//!     id: i32,
//!     username: []const u8,
//!     email: []const u8,
//! }).create(.{
//!     .username = "john",
//!     .email = "john@example.com",
//! });
//!
//! // 获取实体的ID
//! const id = User.getId();
//! ```
//!
//! ## 与值对象的区别
//! - 实体有唯一标识，相等性基于ID
//! - 值对象无标识，相等性基于属性值

const std = @import("std");

/// 实体元数据
pub fn EntityMetadata() type {
    return struct {
        /// 创建时间戳
        created_at: i64,
        /// 更新时间戳
        updated_at: i64,
        /// 版本号（用于乐观并发控制）
        version: u32 = 1,
    };
}

/// 实体基类生成器
///
/// ## 类型参数
/// - `T`: 实体的数据结构（必须包含 `id` 字段）
///
/// ## 泛型约束
/// - `T.id` 必须是可比较的类型（i32, u64, []const u8 等）
pub fn Entity(comptime T: type) type {
    return struct {
        const Self = @This();

        /// 实体数据
        data: T,

        /// 元数据
        metadata: EntityMetadata(),

        /// 获取实体ID
        pub fn getId(self: Self) IdType(T) {
            return self.data.id;
        }

        /// 检查实体是否有ID（用于判断是否为新实体）
        pub fn hasId(self: Self) bool {
            if (comptime std.meta.trait.isOptional(IdType(T))) {
                return self.data.id != null;
            }
            return true;
        }

        /// 获取实体的创建时间
        pub fn getCreatedAt(self: Self) i64 {
            return self.metadata.created_at;
        }

        /// 获取实体的更新时间
        pub fn getUpdatedAt(self: Self) i64 {
            return self.metadata.updated_at;
        }

        /// 获取实体版本
        pub fn getVersion(self: Self) u32 {
            return self.metadata.version;
        }

        /// 增加版本号（用于乐观并发控制）
        pub fn incrementVersion(self: *Self) void {
            self.metadata.version += 1;
            self.metadata.updated_at = std.time.timestamp();
        }

        /// 创建新实体
        pub fn create(data: T) !Self {
            // 验证数据
            try validateData(data);

            return Self{
                .data = data,
                .metadata = .{
                    .created_at = std.time.timestamp(),
                    .updated_at = std.time.timestamp(),
                    .version = 1,
                },
            };
        }

        /// 创建带有元数据的实体（用于从数据库加载）
        pub fn createWithMetadata(data: T, metadata: EntityMetadata()) Self {
            return Self{
                .data = data,
                .metadata = metadata,
            };
        }

        /// 刷新实体的更新时间
        pub fn touch(self: *Self) void {
            self.metadata.updated_at = std.time.timestamp();
            self.metadata.version += 1;
        }

        /// 比较两个实体是否相等
        pub fn equals(self: Self, other: Self) bool {
            return self.getId() == other.getId();
        }

        /// 获取实体的字段值
        pub fn getField(self: Self, comptime field_name: []const u8) FieldType(T, field_name) {
            return @field(self.data, field_name);
        }

        /// 设置实体的字段值
        pub fn setField(self: *Self, comptime field_name: []const u8, value: FieldType(T, field_name)) void {
            @field(self.data, field_name) = value;
            self.touch();
        }

        /// 转换为通用实体接口
        pub fn toInterface(self: Self) EntityInterface(T) {
            return .{
                .data = self.data,
                .metadata = self.metadata,
            };
        }
    };
}

/// 获取实体的ID类型
fn IdType(comptime T: type) type {
    return @TypeOf(@field(std.mem.zeroes(T), "id"));
}

/// 获取字段类型
fn FieldType(comptime T: type, comptime field_name: []const u8) type {
    return @TypeOf(@field(std.mem.zeroes(T), field_name));
}

/// 验证实体数据
fn validateData(comptime T: type) !void {
    _ = T;
    // 子类可以实现更详细的验证逻辑
    // 默认不进行任何验证
}

/// 通用实体接口
///
/// 用于实现多态实体操作
pub fn EntityInterface(comptime T: type) type {
    return struct {
        const Self = @This();

        /// 实体数据
        data: T,

        /// 实体元数据
        metadata: EntityMetadata(),

        /// 获取实体ID
        pub fn getId(self: Self) IdType(T) {
            return self.data.id;
        }

        /// 获取实体的类型名称
        pub fn getTypeName(self: Self) []const u8 {
            return @typeName(T);
        }

        /// 比较两个实体是否相等
        pub fn equals(self: Self, other: Self) bool {
            return self.getId() == other.getId();
        }
    };
}

/// 实体工厂
///
/// 提供创建实体的便捷方法
pub const EntityFactory = struct {
    /// 创建一个新实体（ID为null）
    pub fn new(comptime T: type, allocator: std.mem.Allocator, data: T) !*Entity(T) {
        const entity = try allocator.create(Entity(T));
        entity.* = try Entity(T).create(data);
        return entity;
    }

    /// 从数据库记录创建实体
    pub fn fromRecord(comptime T: type, allocator: std.mem.Allocator, data: T, metadata: EntityMetadata()) !*Entity(T) {
        const entity = try allocator.create(Entity(T));
        entity.* = Entity(T).createWithMetadata(data, metadata);
        return entity;
    }

    /// 释放实体内存
    pub fn destroy(entity: *anyopaque, allocator: std.mem.Allocator) void {
        const T = @TypeOf(entity.*);
        const concrete = @as(*Entity(T), @ptrCast(@alignCast(entity)));
        allocator.destroy(concrete);
    }
};
