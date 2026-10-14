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
const core_io = @import("../io.zig");
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

        /// 事件列表所属分配器（发布/清空事件时使用）
        allocator: std.mem.Allocator,

        /// 聚合根元数据
        metadata: AggregateMetadata(),

        /// 获取聚合ID
        pub fn getId(self: Self) IdType(T) {
            return self.data.id;
        }

        /// 检查聚合是否有ID
        pub fn hasId(self: Self) bool {
            if (comptime @typeInfo(IdType(T)) == .optional) {
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

        /// 获取并清空未发布的事件；返回的列表由调用方 `deinit(agg.allocator)` 释放
        pub fn drainEvents(self: *Self) std.ArrayList(EventType) {
            const events = self.uncommitted_events;
            self.uncommitted_events = .empty;
            return events;
        }

        /// 创建新聚合根
        pub fn create(data: T, allocator: std.mem.Allocator) !Self {
            try validateData(data);

            return Self{
                .data = data,
                .uncommitted_events = .empty,
                .allocator = allocator,
                .metadata = .{
                    .created_at = @divTrunc(std.Io.Timestamp.now(core_io.getIo(), .real).toMilliseconds(), 1000),
                    .updated_at = @divTrunc(std.Io.Timestamp.now(core_io.getIo(), .real).toMilliseconds(), 1000),
                    .version = 0,
                },
            };
        }

        /// 从事件重放创建聚合根
        pub fn fromEvents(events: []const EventType, allocator: std.mem.Allocator) !Self {
            if (events.len == 0) {
                return error.NoEventsToReplay;
            }

            var agg = try Self.create(std.mem.zeroes(T), allocator);

            // 重放所有事件：版本号由 apply 逐事件推进（回填状态 + version +1）
            for (events) |event| {
                try agg.apply(event);
            }

            return agg;
        }

        /// 应用事件到聚合根（事件溯源的状态回填点）
        ///
        /// 编译期探测回填实现，优先级：
        /// 1. 聚合数据 `T.applyEvent(self: *T, event: EventType) void|!void`（聚合自有业务逻辑，推荐）
        /// 2. 事件类型 `EventType.applyTo(self: EventType, data: *T) void|!void`（事件侧映射）
        /// 均未定义时仅推进版本号（保持旧行为）。
        ///
        /// 语义：版本号 +1 并刷新 updated_at；不追加到 uncommitted_events——
        /// 重放（fromEvents）的历史事件不应被再次发布，运行期事件发布走 DomainEventBus。
        pub fn apply(self: *Self, event: EventType) !void {
            if (comptime hasApplyEvent(T, EventType)) {
                const Ret = @typeInfo(@TypeOf(T.applyEvent)).@"fn".return_type.?;
                if (Ret == void) {
                    self.data.applyEvent(event);
                } else {
                    try self.data.applyEvent(event);
                }
            } else if (comptime @hasDecl(EventType, "applyTo")) {
                const Ret = @typeInfo(@TypeOf(EventType.applyTo)).@"fn".return_type.?;
                if (Ret == void) {
                    EventType.applyTo(event, &self.data);
                } else {
                    try EventType.applyTo(event, &self.data);
                }
            }
            self.metadata.version += 1;
            self.metadata.updated_at = @divTrunc(std.Io.Timestamp.now(core_io.getIo(), .real).toMilliseconds(), 1000);
        }

        /// 比较两个聚合根是否相等
        pub fn equals(self: Self, other: Self) bool {
            return self.getId() == other.getId();
        }

        /// 获取聚合的数据副本
        pub fn getData(self: Self) T {
            return self.data;
        }

        /// 释放聚合数据的堆内存（字符串字段；create 不拥有，toAggregate 拥有）
        pub fn freeData(self: Self, allocator: std.mem.Allocator) void {
            freeStrings(T, self.data, allocator);
        }

        /// 释放聚合根内存
        pub fn deinit(self: *Self) void {
            self.uncommitted_events.deinit(self.allocator);
        }
    };
}

/// 获取实体的ID类型
fn IdType(comptime T: type) type {
    return @TypeOf(@field(std.mem.zeroes(T), "id"));
}

/// 检测聚合数据 T 是否定义了签名匹配的 applyEvent：
/// `fn (self: *T, event: EventType) void|!void`
fn hasApplyEvent(comptime T: type, comptime EventType: type) bool {
    if (!@hasDecl(T, "applyEvent")) return false;
    const info = @typeInfo(@TypeOf(@field(T, "applyEvent")));
    if (info != .@"fn") return false;
    const param_types = info.@"fn".param_types;
    if (param_types.len != 2) return false;
    return param_types[0] != null and param_types[1] != null and
        param_types[0].? == *T and param_types[1].? == EventType;
}

/// 验证聚合数据
fn validateData(data: anytype) !void {
    _ = data;
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
        events: []const EventType,
    ) !*AggregateRoot(T, EventType) {
        const agg = try allocator.create(AggregateRoot(T, EventType));
        agg.* = try AggregateRoot(T, EventType).fromEvents(events, allocator);
        return agg;
    }
};

/// 深拷贝字符串字段（递归进入嵌套结构体），所有权转移给 allocator
fn ownStrings(comptime S: type, s: *S, allocator: std.mem.Allocator) !void {
    const names = @typeInfo(S).@"struct".field_names;
    inline for (names) |name| {
        const FieldT = fieldTypeNamed(S, name);
        try ownField(FieldT, &@field(s, name), allocator);
    }
}

/// 释放字符串字段（递归进入嵌套结构体）
fn freeStrings(comptime S: type, s: S, allocator: std.mem.Allocator) void {
    const names = @typeInfo(S).@"struct".field_names;
    inline for (names) |name| {
        const FieldT = fieldTypeNamed(S, name);
        freeField(FieldT, @field(s, name), allocator);
    }
}

/// 按字段名在编译期取字段类型
fn fieldTypeNamed(comptime S: type, comptime name: []const u8) type {
    const ti = @typeInfo(S).@"struct";
    inline for (ti.field_names, 0..) |n, i| {
        if (std.mem.eql(u8, n, name)) return ti.field_types[i];
    }
    @compileError("no field named " ++ name);
}

fn ownField(comptime FieldT: type, field: *FieldT, allocator: std.mem.Allocator) !void {
    if (comptime isStrSlice(FieldT)) {
        field.* = try allocator.dupe(u8, field.*);
    } else if (comptime isOptStrSlice(FieldT)) {
        field.* = if (field.*) |str| try allocator.dupe(u8, str) else null;
    } else if (comptime isPlainStruct(FieldT)) {
        try ownStrings(FieldT, field, allocator);
    }
}

fn freeField(comptime FieldT: type, field: FieldT, allocator: std.mem.Allocator) void {
    if (comptime isStrSlice(FieldT)) {
        allocator.free(field);
    } else if (comptime isOptStrSlice(FieldT)) {
        if (field) |str| allocator.free(str);
    } else if (comptime isPlainStruct(FieldT)) {
        freeStrings(FieldT, field, allocator);
    }
}

fn isStrSlice(comptime T: type) bool {
    if (@typeInfo(T) != .pointer) return false;
    const p = @typeInfo(T).pointer;
    return p.size == .slice and p.attrs.@"const" and p.child == u8;
}

fn isOptStrSlice(comptime T: type) bool {
    if (@typeInfo(T) != .optional) return false;
    return isStrSlice(@typeInfo(T).optional.child);
}

fn isPlainStruct(comptime T: type) bool {
    return @typeInfo(T) == .@"struct";
}

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
                .created_at = @divTrunc(std.Io.Timestamp.now(core_io.getIo(), .real).toMilliseconds(), 1000),
            };
        }

        /// 从快照恢复聚合（堆分配；字符串字段已深拷贝，聚合自包含。
        /// 调用方负责 `freeData` + `deinit` 后 `allocator.destroy`）
        pub fn toAggregate(self: Self, allocator: std.mem.Allocator) !*AggregateRoot(T, EventType) {
            const agg = try allocator.create(AggregateRoot(T, EventType));
            errdefer allocator.destroy(agg);
            agg.* = try AggregateRoot(T, EventType).create(self.data, allocator);
            // 深拷贝 data 字符串字段，保证聚合自包含（快照内存可先行释放）
            try ownStrings(T, &agg.data, allocator);
            agg.metadata.version = self.version;
            return agg;
        }

        /// 序列化快照为 JSON 字符串（调用方拥有，allocator.free 释放）
        pub fn toJSON(self: Self, allocator: std.mem.Allocator) ![]u8 {
            return try std.json.Stringify.valueAlloc(allocator, self, .{});
        }

        /// 从 JSON 字符串恢复快照：字符串字段深拷贝（allocator 拥有），
        /// 原始 bytes 调用返回后即可释放
        pub fn fromJSON(allocator: std.mem.Allocator, bytes: []const u8) !Self {
            const parsed = try std.json.parseFromSlice(Self, allocator, bytes, .{});
            defer parsed.deinit();
            var owned = parsed.value;
            // 解析默认借用 bytes，深拷贝字符串使快照自包含
            try ownStrings(Self, &owned, allocator);
            return owned;
        }

        /// 释放本快照拥有的堆内存（data 的字符串字段）
        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            freeStrings(T, self.data, allocator);
        }
    };
}
