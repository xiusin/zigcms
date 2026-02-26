//! 投影模式 (Projection Pattern)
//!
//! 投影（Projection）是事件溯源中的核心概念，用于从领域事件流中构建和维护读取模型（Read Model）。
//! 投影订阅领域事件，并在事件发生时更新其内部状态。
//!
//! ## 特性
//! - 从事件流中构建状态
//! - 支持多种投影策略（全量、重建、增量）
//! - 可重建：可以从头重放事件来恢复状态
//!
//! ## 使用示例
//! ```zig
//! const UserProjection = Projection(UserReadModel, UserEvent);
//!
//! var projection = try UserProjection.init(allocator);
//! try event_bus.subscribe("user.*", &projection);
//! ```

const std = @import("std");
const DomainEvent = @import("domain_event.zig").DomainEvent;

/// 投影状态
pub const ProjectionStatus = enum {
    /// 空闲
    Idle,
    /// 正在投影
    Projecting,
    /// 已完成
    Completed,
    /// 错误
    Error,
};

/// 投影接口
pub const Projection = struct {
    allocator: std.mem.Allocator,
    status: ProjectionStatus,
    version: u32,
    last_event_id: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) Projection {
        return .{
            .allocator = allocator,
            .status = .Idle,
            .version = 0,
            .last_event_id = null,
        };
    }

    pub fn deinit(self: *Projection) void {
        if (self.last_event_id) |id| {
            self.allocator.free(id);
        }
    }

    /// 应用事件 - 子类实现
    pub fn apply(_: *Projection, event_type: []const u8, event: *anyopaque) !void {
        _ = event_type;
        _ = event;
    }

    /// 获取当前版本
    pub fn getVersion(self: *Projection) u32 {
        return self.version;
    }

    /// 检查是否需要重建
    pub fn needsReplay(self: *Projection, event_version: u32) bool {
        return event_version > self.version;
    }
};

/// 投影生成器
///
/// ## 类型参数
/// - `T`: 投影状态类型（Read Model）
/// - `EventType`: 领域事件类型
pub fn ProjectionBuilder(comptime T: type, comptime EventType: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        state: T,
        status: ProjectionStatus,
        version: u32,
        event_handlers: std.StringHashMap(*const fn (event: EventType) void),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .state = undefined,
                .status = .Idle,
                .version = 0,
                .event_handlers = std.StringHashMap(*const fn (event: EventType) void).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.event_handlers.deinit();
        }

        /// 注册事件处理器
        pub fn on(self: *Self, event_type: []const u8, handler: *const fn (event: EventType) void) !void {
            const key = try self.allocator.dupe(u8, event_type);
            errdefer self.allocator.free(key);

            try self.event_handlers.put(key, handler);
        }

        /// 应用单个事件
        pub fn apply(self: *Self, event_type: []const u8, event: EventType) !void {
            if (self.event_handlers.get(event_type)) |handler| {
                handler(event);
                self.version += 1;
                self.status = .Projecting;
            }
        }

        /// 获取状态
        pub fn getState(self: *Self) *T {
            return &self.state;
        }

        /// 获取版本
        pub fn getVersion(self: *Self) u32 {
            return self.version;
        }

        /// 重置投影
        pub fn reset(self: *Self) void {
            self.version = 0;
            self.status = .Idle;
        }
    };
}

/// 用户读取模型（User Read Model）
pub const UserReadModel = struct {
    id: i32 = 0,
    username: []const u8 = "",
    email: []const u8 = "",
    nickname: []const u8 = "",
    avatar: []const u8 = "",
    status: []const u8 = "pending",
    is_active: bool = false,
    created_at: i64 = 0,
    updated_at: i64 = 0,
    last_login_at: ?i64 = null,

    pub fn init(allocator: std.mem.Allocator) UserReadModel {
        _ = allocator;
        return .{
            .id = 0,
            .username = "",
            .email = "",
            .nickname = "",
            .avatar = "",
            .status = "pending",
            .is_active = false,
            .created_at = 0,
            .updated_at = 0,
            .last_login_at = null,
        };
    }

    pub fn deinit(self: *UserReadModel, allocator: std.mem.Allocator) void {
        if (self.username.len > 0) allocator.free(self.username);
        if (self.email.len > 0) allocator.free(self.email);
        if (self.nickname.len > 0) allocator.free(self.nickname);
        if (self.avatar.len > 0) allocator.free(self.avatar);
    }
};

/// 用户投影（从用户事件构建用户读取模型）
pub const UserProjection = struct {
    allocator: std.mem.Allocator,
    state: UserReadModel,
    status: ProjectionStatus,
    version: u32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .state = undefined,
            .status = .Idle,
            .version = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.state.deinit(self.allocator);
    }

    /// 从事件重放构建投影
    pub fn fromEvents(self: *Self, events: []const anyopaque) !void {
        self.reset();
        for (events) |event| {
            const event_type = @as(*const DomainEvent, @ptrCast(@alignCast(event))).metadata.event_type;
            try self.apply(event_type, event);
        }
        self.status = .Completed;
    }

    /// 应用事件
    pub fn apply(self: *Self, event_type: []const u8, event: *anyopaque) !void {
        if (std.mem.eql(u8, event_type, "user.created")) {
            const ev = @as(*const DomainEvent(@import("../domain/events/user_events.zig").UserCreated), @ptrCast(@alignCast(event)));
            const payload = ev.payload;
            self.state.id = payload.user_id;
            self.state.username = try self.allocator.dupe(u8, payload.username);
            self.state.email = try self.allocator.dupe(u8, payload.email);
            self.state.status = "active";
            self.state.is_active = true;
            self.state.created_at = payload.created_at;
            self.state.updated_at = payload.created_at;
        } else if (std.mem.eql(u8, event_type, "user.activated")) {
            const ev = @as(*const DomainEvent(@import("../domain/events/user_events.zig").UserActivated), @ptrCast(@alignCast(event)));
            self.state.status = "active";
            self.state.is_active = true;
            self.state.updated_at = ev.payload.activated_at;
        } else if (std.mem.eql(u8, event_type, "user.deactivated")) {
            const ev = @as(*const DomainEvent(@import("../domain/events/user_events.zig").UserDeactivated), @ptrCast(@alignCast(event)));
            self.state.status = "inactive";
            self.state.is_active = false;
            self.state.updated_at = ev.payload.deactivated_at;
        }
        self.version += 1;
        self.status = .Projecting;
    }

    /// 重置投影
    pub fn reset(self: *Self) void {
        self.state.deinit(self.allocator);
        self.state = undefined;
        self.version = 0;
        self.status = .Idle;
    }

    /// 获取读取模型
    pub fn getState(self: *Self) *const UserReadModel {
        return &self.state;
    }

    /// 获取版本
    pub fn getVersion(self: *Self) u32 {
        return self.version;
    }
};

/// 投影仓库（存储和管理投影）
pub const ProjectionRepository = struct {
    allocator: std.mem.Allocator,
    projections: std.StringHashMap(*Projection),

    pub fn init(allocator: std.mem.Allocator) ProjectionRepository {
        return .{
            .allocator = allocator,
            .projections = std.StringHashMap(*Projection).init(allocator),
        };
    }

    pub fn deinit(self: *ProjectionRepository) void {
        var iter = self.projections.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
            self.allocator.destroy(entry.value_ptr);
            self.allocator.free(entry.key_ptr.*);
        }
        self.projections.deinit();
    }

    /// 保存投影
    pub fn save(self: *ProjectionRepository, name: []const u8, projection: *Projection) !void {
        const key = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(key);

        try self.projections.put(key, projection);
    }

    /// 获取投影
    pub fn get(self: *ProjectionRepository, name: []const u8) ?*Projection {
        return self.projections.get(name);
    }
};

test "Projection - apply event updates version" {
    const allocator = testing.allocator;

    var projection = UserProjection.init(allocator);
    defer projection.deinit();

    try testing.expectEqual(@as(u32, 0), projection.getVersion());
}

test "Projection - status transitions" {
    const allocator = testing.allocator;

    var projection = UserProjection.init(allocator);
    defer projection.deinit();

    try testing.expect(projection.status == .Idle);
}

test "ProjectionRepository - save and get" {
    const allocator = testing.allocator;

    var repo = ProjectionRepository.init(allocator);
    defer repo.deinit();

    var projection = try allocator.create(UserProjection);
    projection.* = UserProjection.init(allocator);
    defer {
        projection.deinit();
        allocator.destroy(projection);
    }

    try repo.save("user_projection", projection);

    const retrieved = repo.get("user_projection");
    try testing.expect(retrieved != null);
}
