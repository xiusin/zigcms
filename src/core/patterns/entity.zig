//! 实体模式 (Entity Pattern)
//!
//! 实体是具有唯一标识的对象，其相等性由标识决定而非属性值。

const std = @import("std");

/// 实体生成器
pub fn Entity(comptime T: type, comptime IdType: type) type {
    return struct {
        const Self = @This();

        id: IdType,
        data: T,
        created_at: i64,
        updated_at: i64,

        /// 创建实体
        pub fn create(id: IdType, data: T) Self {
            const now = std.time.timestamp();
            return .{
                .id = id,
                .data = data,
                .created_at = now,
                .updated_at = now,
            };
        }

        /// 判断是否相等（基于ID）
        pub fn equals(self: Self, other: Self) bool {
            return self.id == other.id;
        }

        /// 更新数据
        pub fn update(self: *Self, data: T) void {
            self.data = data;
            self.updated_at = std.time.timestamp();
        }

        /// 获取ID
        pub fn getId(self: Self) IdType {
            return self.id;
        }

        /// 获取数据
        pub fn getData(self: Self) T {
            return self.data;
        }
    };
}
