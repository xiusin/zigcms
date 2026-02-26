//! 聚合根模式 (Aggregate Root Pattern)
//!
//! 聚合根是聚合的入口点，负责维护聚合的不变性和一致性边界。
//! 所有对聚合内对象的访问必须通过聚合根进行。
//!
//! ## 特性
//! - 入口点：外部世界访问聚合的唯一入口
//! - 不变性维护：确保聚合内所有对象满足业务规则
//! - 事件管理：收集和发布领域事件
//! - 版本控制：用于乐观并发控制
//!
//! ## 使用示例
//! ```zig
//! const UserAgg = AggregateRoot(struct {
//!     id: i32,
//!     username: []const u8,
//!     email: []const u8,
//! });
//!
//! var user = try UserAgg.create(.{
//!     .username = "john",
//!     .email = "john@example.com",
//! });
//!
//! // 通过聚合根访问子实体
//! try user.updateEmail("new@example.com");
//!
//! // 获取未发布的事件
//! const events = user.getUncommittedEvents();
//! ```
//!
//! ## 聚合设计原则
//! - 聚合根负责维护不变性
//! - 聚合内对象只能被聚合根引用
//! - 外部只能持有聚合根的引用

const std = @import("std");
const DomainEvent = @import("domain_event.zig").DomainEvent;

/// 聚合元数据
pub fn AggregateMetadata() type {
    return struct {
        /// 创建时间戳
        created_at: i64,
        /// 更新时间戳
        updated_at: i64,
        /// 版本号（用于乐观并发控制）
        version: u32 = 0,
    };
}

/// 聚合根生成器
///
/// ## 类型参数
/// - `T`: 聚合的数据结构（必须包含 `id` 字段）
/// - `EventType`: 领域事件类型
///
/// ## 使用示例
/// ```zig
/// const UserAgg = AggregateRoot(struct {
///     id: i32,
///     username: []const u8,
///     email: []const u8,
/// }, UserEvent);
/// ```
pub fn AggregateRoot(comptime T: type, comptime EventType: type) type {
    return struct {
        const Self = @This();

        /// 聚合数据
        data: T,

        /// 未发布的领域事件
        uncommitted_events: std.ArrayList(EventType),

        /// 聚合根元数据
        metadata: AggregateMetadata(),

        /// 获取聚合ID
        pub fn getId(self: Self) IdType(T) {
            return self.data.id;
        }

        /// 检查聚合是否有ID
        pub fn hasId(self: Self) bool {
            if (comptime std.meta.trait.isOptional(IdType(T))) {
                return self.data.id != null;
            }
            return true;
        }

        /// 获取聚合版本
        pub fn getVersion(self: Self) u32 {
            return self.metadata.version;
        }

        /// 获取创建时间
        pub fn getCreatedAt(self: Self) i64 {
            return self.metadata.created_at;
        }

        /// 获取更新时间
        pub fn getUpdatedAt(self: Self) i64 {
            return self.metadata.updated_at;
        }

        /// 获取未发布的领域事件
        pub fn getUncommittedEvents(self: *Self) []EventType {
            return self.uncommitted_events.items;
        }

        /// 获取并清空未发布的事件
        pub fn drainEvents(self: *Self) std.ArrayList(EventType) {
            const events = self.uncommitted_events;
            self.uncommitted_events = std.ArrayList(EventType).init(self.uncommitted_events.allocator);
            return events;
        }

        /// 发布领域事件
        fn publish(self: *Self, event: EventType) void {
            self.uncommitted_events.append(event) catch {};
            self.metadata.version += 1;
            self.metadata.updated_at = std.time.timestamp();
        }

        /// 创建新聚合根
        pub fn create(data: T, allocator: std.mem.Allocator) !Self {
            try validateData(data);

            return Self{
                .data = data,
                .uncommitted_events = std.ArrayList(EventType).init(allocator),
                .metadata = .{
                    .created_at = std.time.timestamp(),
                    .updated_at = std.time.timestamp(),
                    .version = 0,
                },
            };
        }

        /// 从事件重放创建聚合根
        pub fn fromEvents(events: []EventType, allocator: std.mem.Allocator) !Self {
            if (events.len == 0) {
                return error.NoEventsToReplay;
            }

            var agg = try Self.create(std.mem.zeroes(T), allocator);
            agg.metadata.version = @intCast(events.len);

            // 重放所有事件
            for (events) |event| {
                try agg.apply(event);
            }

            return agg;
        }

        /// 应用事件到聚合根
        pub fn apply(_: *Self, event: EventType) !void {
            _ = event;
            // 子类实现事件应用逻辑
            // 更新聚合状态
        }

        /// 比较两个聚合根是否相等
        pub fn equals(self: Self, other: Self) bool {
            return self.getId() == other.getId();
        }

        /// 获取聚合的数据副本
        pub fn getData(self: Self) T {
            return self.data;
        }

        /// 释放聚合根内存
        pub fn deinit(self: *Self) void {
            self.uncommitted_events.deinit();
        }
    };
}

/// 获取实体的ID类型
fn IdType(comptime T: type) type {
    return @TypeOf(@field(std.mem.zeroes(T), "id"));
}

/// 验证聚合数据
fn validateData(comptime T: type) !void {
    _ = T;
    // 子类实现验证逻辑
}

/// 聚合根工厂
pub const AggregateRootFactory = struct {
    /// 创建新聚合根
    pub fn new(
        comptime T: type,
        comptime EventType: type,
        allocator: std.mem.Allocator,
        data: T,
    ) !*AggregateRoot(T, EventType) {
        const agg = try allocator.create(AggregateRoot(T, EventType));
        agg.* = try AggregateRoot(T, EventType).create(data, allocator);
        return agg;
    }

    /// 从事件重放创建聚合根
    pub fn fromEvents(
        comptime T: type,
        comptime EventType: type,
        allocator: std.mem.Allocator,
        events: []EventType,
    ) !*AggregateRoot(T, EventType) {
        const agg = try allocator.create(AggregateRoot(T, EventType));
        agg.* = try AggregateRoot(T, EventType).fromEvents(events, allocator);
        return agg;
    }

    /// 释放聚合根内存
    pub fn destroy(_: *anyopaque, _: std.mem.Allocator) void {
        // 注意：这里需要知道具体类型才能正确释放
        // 在实际使用中，应该使用具体类型的 destroy 函数
    }
};

/// 聚合快照（用于优化事件溯源）
pub fn AggregateSnapshot(comptime T: type, comptime EventType: type) type {
    return struct {
        const Self = @This();

        /// 聚合ID
        id: IdType(T),

        /// 聚合数据
        data: T,

        /// 快照版本
        version: u32,

        /// 创建时间
        created_at: i64,

        /// 从聚合创建快照
        pub fn fromAggregate(agg: *AggregateRoot(T, EventType)) Self {
            return Self{
                .id = agg.getId(),
                .data = agg.getData(),
                .version = agg.getVersion(),
                .created_at = std.time.timestamp(),
            };
        }

        /// 从快照恢复聚合
        pub fn toAggregate(self: Self, allocator: std.mem.Allocator) !*AggregateRoot(T, EventType) {
            var agg = try AggregateRoot(T, EventType).create(self.data, allocator);
            agg.metadata.version = self.version;
            return agg;
        }
    };
}
