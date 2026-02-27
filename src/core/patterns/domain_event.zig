//! 领域事件模式 (Domain Event Pattern)
//!
//! 领域事件是领域中发生的重要事情的记录。
//! 事件表示过去发生的事情，是不可变的。
//!
//! ## 特性
//! - 不可变性：事件一旦发生就不能修改
//! - 时间戳：记录事件发生的时间
//! - 标识：每个事件有唯一的ID
//! - 元数据：可以包含额外的上下文信息
//!
//! ## 使用示例
//! ```zig
//! const UserCreated = DomainEvent(struct {
//!     user_id: i32,
//!     username: []const u8,
//!     email: []const u8,
//! });
//!
//! var event = try UserCreated.create(.{
//!     .user_id = 1,
//!     .username = "john",
//!     .email = "john@example.com",
//! });
//!
//! std.debug.print("Event occurred at: {d}\n", .{event.getOccurredOn()});
//! ```
//!
//! ## 事件处理
//! 事件通常由事件处理器处理：
//! - 同步处理：在事务内处理
//! - 异步处理：通过消息队列处理

const std = @import("std");

/// 领域事件元数据
pub fn EventMetadata() type {
    return struct {
        /// 事件唯一ID
        id: [16]u8,
        /// 事件发生时间
        occurred_on: i64,
        /// 事件类型名称
        event_type: []const u8,
        /// 聚合根ID
        aggregate_id: ?[]const u8 = null,
        /// 聚合根类型
        aggregate_type: ?[]const u8 = null,
        /// 聚合根版本
        aggregate_version: ?u32 = null,
        /// 元数据（可选的额外信息）
        metadata: ?std.json.Value = null,
    };
}

/// 基础领域事件结构
///
/// ## 类型参数
/// - `T`: 事件的负载数据结构
pub fn DomainEvent(comptime T: type) type {
    return struct {
        const Self = @This();

        /// 事件负载
        payload: T,

        /// 事件元数据
        metadata: EventMetadata(),

        /// 获取事件ID
        pub fn getId(self: Self) [16]u8 {
            return self.metadata.id;
        }

        /// 获取事件发生时间
        pub fn getOccurredOn(self: Self) i64 {
            return self.metadata.occurred_on;
        }

        /// 获取事件类型名称
        pub fn getEventType(self: Self) []const u8 {
            return self.metadata.event_type;
        }

        /// 获取聚合根ID
        pub fn getAggregateId(self: Self) ?[]const u8 {
            return self.metadata.aggregate_id;
        }

        /// 获取聚合根版本
        pub fn getAggregateVersion(self: Self) ?u32 {
            return self.metadata.aggregate_version;
        }

        /// 创建领域事件
        pub fn create(payload: T, allocator: std.mem.Allocator, event_type: []const u8) !Self {
            var id: [16]u8 = undefined;
            std.crypto.random.bytes(&id);

            return Self{
                .payload = payload,
                .metadata = .{
                    .id = id,
                    .occurred_on = std.time.timestamp(),
                    .event_type = try allocator.dupe(u8, event_type),
                    .aggregate_id = null,
                    .aggregate_type = null,
                    .aggregate_version = null,
                    .metadata = null,
                },
            };
        }

        /// 创建带聚合信息的领域事件
        pub fn createWithAggregate(
            payload: T,
            allocator: std.mem.Allocator,
            event_type: []const u8,
            aggregate_id: []const u8,
            aggregate_type: []const u8,
            aggregate_version: u32,
        ) !Self {
            var id: [16]u8 = undefined;
            std.crypto.random.bytes(&id);

            return Self{
                .payload = payload,
                .metadata = .{
                    .id = id,
                    .occurred_on = std.time.timestamp(),
                    .event_type = try allocator.dupe(u8, event_type),
                    .aggregate_id = try allocator.dupe(u8, aggregate_id),
                    .aggregate_type = try allocator.dupe(u8, aggregate_type),
                    .aggregate_version = aggregate_version,
                    .metadata = null,
                },
            };
        }

        /// 创建简单领域事件（不分配额外内存）
        pub fn createSimple(payload: T, event_type: []const u8) Self {
            var id: [16]u8 = undefined;
            std.crypto.random.bytes(&id);

            return Self{
                .payload = payload,
                .metadata = .{
                    .id = id,
                    .occurred_on = std.time.timestamp(),
                    .event_type = event_type,
                    .aggregate_id = null,
                    .aggregate_type = null,
                    .aggregate_version = null,
                    .metadata = null,
                },
            };
        }

        /// 获取事件负载
        pub fn getPayload(self: Self) T {
            return self.payload;
        }

        /// 序列化事件为JSON
        pub fn toJson(self: Self, allocator: std.mem.Allocator) ![]u8 {
            var event_obj = std.json.ObjectMap.init(allocator);
            defer event_obj.deinit();

            // 添加事件类型
            try event_obj.put("event_type", std.json.Value{ .string = self.metadata.event_type });

            // 添加时间戳
            try event_obj.put("occurred_on", std.json.Value{ .integer = self.metadata.occurred_on });

            // 添加聚合信息
            if (self.metadata.aggregate_id) |agg_id| {
                try event_obj.put("aggregate_id", std.json.Value{ .string = agg_id });
            }
            if (self.metadata.aggregate_type) |agg_type| {
                try event_obj.put("aggregate_type", std.json.Value{ .string = agg_type });
            }
            if (self.metadata.aggregate_version) |agg_version| {
                try event_obj.put("aggregate_version", std.json.Value{ .integer = agg_version });
            }

            // 添加负载（简化处理）
            const payload_json = try std.json.stringifyAlloc(allocator, self.payload, .{});
            defer allocator.free(payload_json);

            try event_obj.put("payload", std.json.Value{ .string = payload_json });

            return std.json.stringifyAlloc(allocator, event_obj, .{});
        }

        /// 从JSON反序列化事件
        pub fn fromJson(json_str: []const u8, allocator: std.mem.Allocator) !Self {
            const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
            defer parsed.deinit();

            const root = parsed.value;
            const obj = root.object;

            const event_type = obj.get("event_type").?.string;

            // 简化处理：返回空事件
            return Self.createSimple(undefined, event_type);
        }

        /// 释放事件内存
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            if (self.metadata.event_type.len > 0) {
                allocator.free(self.metadata.event_type);
            }
            if (self.metadata.aggregate_id) |id| {
                allocator.free(id);
            }
            if (self.metadata.aggregate_type) |type_| {
                allocator.free(type_);
            }
        }
    };
}

/// 事件类型注册表
pub const EventTypeRegistry = struct {
    const Self = @This();

    /// 事件类型映射
    registry: std.StringHashMap(type),

    /// 注册事件类型
    pub fn register(self: *Self, event_type: []const u8, comptime T: type) !void {
        try self.registry.put(event_type, T);
    }

    /// 获取事件类型
    pub fn get(self: *Self, event_type: []const u8) ?type {
        return self.registry.get(event_type);
    }

    /// 初始化
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .registry = std.StringHashMap(type).init(allocator),
        };
    }

    /// 清理
    pub fn deinit(self: *Self) void {
        self.registry.deinit();
    }
};

/// 领域事件基类（用于不需要负载的事件）
pub const DomainEventBase = struct {
    const Self = @This();

    id: [16]u8,
    occurred_on: i64,
    event_type: []const u8,
    aggregate_id: ?[]const u8,
    aggregate_version: ?u32,

    pub fn init(comptime event_type: []const u8, aggregate_id: ?[]const u8, aggregate_version: ?u32) Self {
        var id: [16]u8 = undefined;
        std.crypto.random.bytes(&id);

        return Self{
            .id = id,
            .occurred_on = std.time.timestamp(),
            .event_type = event_type,
            .aggregate_id = aggregate_id,
            .aggregate_version = aggregate_version,
        };
    }

    pub fn getId(self: Self) [16]u8 {
        return self.id;
    }

    pub fn getOccurredOn(self: Self) i64 {
        return self.occurred_on;
    }

    pub fn getEventType(self: Self) []const u8 {
        return self.event_type;
    }
};

/// 常用的事件宏
///
/// 用于简化事件定义
pub const DomainEvents = struct {
    /// 定义一个简单的事件类型
    pub fn Define(_: []const u8, comptime PayloadType: type) type {
        return DomainEvent(PayloadType);
    }

    /// 定义一个仅包含ID的事件
    pub fn DefineIdOnly(_: []const u8, comptime IdType: type) type {
        return DomainEvent(struct {
            id: IdType,
        });
    }
};
