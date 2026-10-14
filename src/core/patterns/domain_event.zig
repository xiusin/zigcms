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
const core_io = @import("../io.zig");

/// 领域事件元数据
pub fn EventMetadata() type {
    return struct {
        /// 事件唯一ID
        id: [16]u8,
        /// 事件发生时间
        occurred_on: i64,
        /// 事件类型名称
        event_type: []const u8,
        /// event_type 是否由本事件分配（true=需 deinit 释放；createSimple 借用外部字符串时为 false）
        owns_event_type: bool = false,
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
            std.Io.random(core_io.getIo(), &id);

            return Self{
                .payload = payload,
                .metadata = .{
                    .id = id,
                    .occurred_on = @divTrunc(std.Io.Timestamp.now(core_io.getIo(), .real).toMilliseconds(), 1000),
                    .event_type = try allocator.dupe(u8, event_type),
                    .owns_event_type = true,
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
            std.Io.random(core_io.getIo(), &id);

            return Self{
                .payload = payload,
                .metadata = .{
                    .id = id,
                    .occurred_on = @divTrunc(std.Io.Timestamp.now(core_io.getIo(), .real).toMilliseconds(), 1000),
                    .event_type = try allocator.dupe(u8, event_type),
                    .owns_event_type = true,
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
            std.Io.random(core_io.getIo(), &id);

            return Self{
                .payload = payload,
                .metadata = .{
                    .id = id,
                    .occurred_on = @divTrunc(std.Io.Timestamp.now(core_io.getIo(), .real).toMilliseconds(), 1000),
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
            var event_obj = std.json.ObjectMap.empty;
            defer event_obj.deinit(allocator);

            // 添加事件类型
            try event_obj.put(allocator, "event_type", std.json.Value{ .string = self.metadata.event_type });

            // 添加时间戳
            try event_obj.put(allocator, "occurred_on", std.json.Value{ .integer = self.metadata.occurred_on });

            // 添加聚合信息
            if (self.metadata.aggregate_id) |agg_id| {
                try event_obj.put(allocator, "aggregate_id", std.json.Value{ .string = agg_id });
            }
            if (self.metadata.aggregate_type) |agg_type| {
                try event_obj.put(allocator, "aggregate_type", std.json.Value{ .string = agg_type });
            }
            if (self.metadata.aggregate_version) |agg_version| {
                try event_obj.put(allocator, "aggregate_version", std.json.Value{ .integer = agg_version });
            }

            // 添加负载（简化处理）
            const payload_json = try std.json.Stringify.valueAlloc(allocator, self.payload, .{});
            defer allocator.free(payload_json);

            try event_obj.put(allocator, "payload", std.json.Value{ .string = payload_json });

            return std.json.Stringify.valueAlloc(allocator, std.json.Value{ .object = event_obj }, .{});
        }

        /// 从JSON反序列化事件
        ///
        /// 负载 T 的字符串字段所有权无法泛型转移，payload 恒为零值（slice 字段为空），
        /// 调用方不得读取 payload 内容；event_type 从 JSON 复制（复制所有权，需 deinit）。
        pub fn fromJson(json_str: []const u8, allocator: std.mem.Allocator) !Self {
            const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
            defer parsed.deinit();

            if (parsed.value != .object) return error.InvalidEventJson;
            const obj = parsed.value.object;

            const event_type_val = obj.get("event_type") orelse return error.MissingEventType;
            if (event_type_val != .string) return error.InvalidEventType;

            // 必须复制：parsed 树在返回后即释放，借用会产生悬垂指针
            const owned_type = try allocator.dupe(u8, event_type_val.string);
            errdefer allocator.free(owned_type);

            var id: [16]u8 = undefined;
            std.Io.random(core_io.getIo(), &id);

            return Self{
                .payload = std.mem.zeroes(T),
                .metadata = .{
                    .id = id,
                    .occurred_on = @divTrunc(std.Io.Timestamp.now(core_io.getIo(), .real).toMilliseconds(), 1000),
                    .event_type = owned_type,
                    .owns_event_type = true,
                },
            };
        }

        /// 释放事件内存
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            if (self.metadata.owns_event_type and self.metadata.event_type.len > 0) {
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

/// 事件类型注册表（编译时）
///
/// `type` 是 comptime-only 类型，无法存入运行时哈希表，因此注册表在编译期展开：
///
/// ```zig
/// const Registry = EventTypeRegistry(.{
///     .{ "user.created", UserCreated },
///     .{ "user.updated", UserUpdated },
/// });
/// try std.testing.expect(Registry.get("user.created") == UserCreated);
/// ```
pub fn EventTypeRegistry(comptime entries: anytype) type {
    return struct {
        const Self = @This();

        /// 按名称取事件类型（编译期求值，event_type 必须是编译期已知字符串）
        pub fn get(comptime event_type: []const u8) ?type {
            inline for (entries) |entry| {
                if (std.mem.eql(u8, event_type, entry[0])) return entry[1];
            }
            return null;
        }

        /// 运行时判断名称是否已注册
        pub fn contains(event_type: []const u8) bool {
            inline for (entries) |entry| {
                if (std.mem.eql(u8, event_type, entry[0])) return true;
            }
            return false;
        }
    };
}

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
        std.Io.random(core_io.getIo(), &id);

        return Self{
            .id = id,
            .occurred_on = @divTrunc(std.Io.Timestamp.now(core_io.getIo(), .real).toMilliseconds(), 1000),
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
