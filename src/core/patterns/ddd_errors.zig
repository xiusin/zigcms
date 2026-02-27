//! DDD 错误处理模式 (DDD Error Handling Patterns)
//!
//! 为领域驱动设计提供的专用错误类型，包含：
//! - 领域错误 (DomainError)
//! - 聚合根错误 (AggregateError)
//! - 仓储错误 (RepositoryError)
//! - 事件错误 (EventError)
//! - 业务规则错误 (BusinessRuleError)
//!
//! ## 使用示例
//! ```zig
//! const DddErrors = @import("shared_kernel/patterns/ddd_errors.zig");
//!
//! // 领域错误
//! return error(DddErrors.DomainValidationFailed);
//!
//! // 业务规则错误
//! return DddErrors.BusinessRuleViolation{
//!     .rule = "UserEmailMustBeUnique",
//!     .message = "邮箱已被注册",
//! };
//! ```

const std = @import("std");

// ============================================================================
// 领域错误代码定义
// ============================================================================

/// 领域层错误代码范围: 10000-19999
pub const DomainErrorCodes = struct {
    // 通用领域错误 (10000-10099)
    pub const Unknown: i32 = 10000;
    pub const InvalidState: i32 = 10001;
    pub const StateTransitionNotAllowed: i32 = 10002;
    pub const InvariantViolation: i32 = 10003;

    // 值对象错误 (10100-10199)
    pub const ValueObjectCreationFailed: i32 = 10100;
    pub const ValueObjectValidationFailed: i32 = 10101;

    // 实体错误 (10200-10299)
    pub const EntityNotFound: i32 = 10200;
    pub const EntityAlreadyExists: i32 = 10201;
    pub const EntityVersionMismatch: i32 = 10202;

    // 聚合根错误 (10300-10399)
    pub const AggregateNotFound: i32 = 10300;
    pub const AggregateVersionConflict: i32 = 10301;
    pub const AggregateConcurrencyError: i32 = 10302;

    // 领域服务错误 (10400-10499)
    pub const DomainServiceError: i32 = 10400;
    pub const ServiceAlreadyRegistered: i32 = 10401;

    // 仓储错误 (10500-10599)
    pub const RepositoryError: i32 = 10500;
    pub const RepositoryNotFound: i32 = 10501;
    pub const RepositoryDuplicateKey: i32 = 10502;
    pub const RepositoryConnectionFailed: i32 = 10503;
    pub const RepositoryTransactionFailed: i32 = 10504;

    // 事件错误 (10600-10699)
    pub const EventError: i32 = 10600;
    pub const EventPublishFailed: i32 = 10601;
    pub const EventHandlerNotFound: i32 = 10602;
    pub const EventHandlerExecutionFailed: i32 = 10603;
    pub const EventReplayingFailed: i32 = 10604;

    // 业务规则错误 (10700-10799)
    pub const BusinessRuleViolation: i32 = 10700;
    pub const PreConditionFailed: i32 = 10701;
    pub const PostConditionFailed: i32 = 10702;
    pub const InvariantNotSatisfied: i32 = 10703;
};

// ============================================================================
// 领域错误类型
// ============================================================================

/// 领域层通用错误
pub const DomainError = error{
    // 通用领域错误
    InvalidState,
    StateTransitionNotAllowed,
    InvariantViolation,

    // 值对象错误
    ValueObjectCreationFailed,
    ValueObjectValidationFailed,

    // 实体错误
    EntityNotFound,
    EntityAlreadyExists,
    EntityVersionMismatch,

    // 聚合根错误
    AggregateNotFound,
    AggregateVersionConflict,
    AggregateConcurrencyError,

    // 领域服务错误
    DomainServiceError,
    ServiceAlreadyRegistered,

    // 仓储错误
    RepositoryError,
    RepositoryNotFound,
    RepositoryDuplicateKey,
    RepositoryConnectionFailed,
    RepositoryTransactionFailed,

    // 事件错误
    EventError,
    EventPublishFailed,
    EventHandlerNotFound,
    EventHandlerExecutionFailed,
    EventReplayingFailed,

    // 业务规则错误
    BusinessRuleViolation,
    PreConditionFailed,
    PostConditionFailed,
    InvariantNotSatisfied,
};

// ============================================================================
// 业务规则错误
// ============================================================================

/// 业务规则违反错误
pub const BusinessRuleError = struct {
    /// 规则名称
    rule: []const u8,
    /// 错误消息
    message: []const u8,
    /// 违反的聚合根ID
    aggregate_id: ?i32 = null,
    /// 额外上下文
    context: ?std.json.Value = null,

    pub fn init(rule: []const u8, message: []const u8) BusinessRuleError {
        return .{
            .rule = rule,
            .message = message,
        };
    }

    pub fn withAggregateId(self: BusinessRuleError, id: i32) BusinessRuleError {
        var result = self;
        result.aggregate_id = id;
        return result;
    }

    pub fn withContext(self: BusinessRuleError, ctx: std.json.Value) BusinessRuleError {
        var result = self;
        result.context = ctx;
        return result;
    }
};

// ============================================================================
// 聚合根错误
// ============================================================================

/// 聚合根错误详情
pub const AggregateError = struct {
    /// 聚合根类型名称
    aggregate_type: []const u8,
    /// 聚合根ID
    aggregate_id: ?i32 = null,
    /// 错误代码
    code: i32,
    /// 错误消息
    message: []const u8,
    /// 期望的状态
    expected_state: ?[]const u8 = null,
    /// 当前状态
    current_state: ?[]const u8 = null,
    /// 冲突的版本号（用于并发错误）
    conflicting_version: ?u32 = null,

    pub fn notFound(aggregate_type: []const u8, id: i32) AggregateError {
        return .{
            .aggregate_type = aggregate_type,
            .aggregate_id = id,
            .code = DomainErrorCodes.AggregateNotFound,
            .message = std.fmt.allocPrint(
                std.heap.page_allocator,
                "{s} with ID {d} not found",
                .{ aggregate_type, id },
            ) catch "aggregate not found",
        };
    }

    pub fn versionConflict(
        aggregate_type: []const u8,
        id: i32,
        expected_version: u32,
        actual_version: u32,
    ) AggregateError {
        return .{
            .aggregate_type = aggregate_type,
            .aggregate_id = id,
            .code = DomainErrorCodes.AggregateVersionConflict,
            .message = std.fmt.allocPrint(
                std.heap.page_allocator,
                "Version conflict for {s} {d}: expected {d}, got {d}",
                .{ aggregate_type, id, expected_version, actual_version },
            ) catch "version conflict",
            .conflicting_version = actual_version,
        };
    }

    pub fn stateTransitionNotAllowed(
        aggregate_type: []const u8,
        from_state: []const u8,
        to_state: []const u8,
    ) AggregateError {
        return .{
            .aggregate_type = aggregate_type,
            .aggregate_id = null,
            .code = DomainErrorCodes.StateTransitionNotAllowed,
            .message = std.fmt.allocPrint(
                std.heap.page_allocator,
                "Cannot transition {s} from '{s}' to '{s}'",
                .{ aggregate_type, from_state, to_state },
            ) catch "state transition not allowed",
            .expected_state = to_state,
            .current_state = from_state,
        };
    }
};

// ============================================================================
// 仓储错误
// ============================================================================

/// 仓储操作错误
pub const RepositoryError = struct {
    /// 仓储名称
    repository_name: []const u8,
    /// 操作类型
    operation: RepositoryOperation,
    /// 错误代码
    code: i32,
    /// 错误消息
    message: []const u8,
    /// 实体ID（如果适用）
    entity_id: ?i32 = null,
    /// 底层错误
    cause: ?anyerror = null,

    pub const RepositoryOperation = enum {
        FindById,
        FindBy,
        Save,
        Update,
        Delete,
        Exists,
        Count,
        List,
        Transaction,
    };

    pub fn notFound(repo_name: []const u8, entity_type: []const u8, id: i32) RepositoryError {
        return .{
            .repository_name = repo_name,
            .operation = .FindById,
            .code = DomainErrorCodes.RepositoryNotFound,
            .message = std.fmt.allocPrint(
                std.heap.page_allocator,
                "{s} with ID {d} not found in {s}",
                .{ entity_type, id, repo_name },
            ) catch "not found",
            .entity_id = id,
        };
    }

    pub fn duplicateKey(repo_name: []const u8, field: []const u8, value: []const u8) RepositoryError {
        return .{
            .repository_name = repo_name,
            .operation = .Save,
            .code = DomainErrorCodes.RepositoryDuplicateKey,
            .message = std.fmt.allocPrint(
                std.heap.page_allocator,
                "Duplicate key for field '{s}' with value '{s}' in {s}",
                .{ field, value, repo_name },
            ) catch "duplicate key",
        };
    }

    pub fn connectionFailed(repo_name: []const u8, reason: []const u8) RepositoryError {
        return .{
            .repository_name = repo_name,
            .operation = .Transaction,
            .code = DomainErrorCodes.RepositoryConnectionFailed,
            .message = std.fmt.allocPrint(
                std.heap.page_allocator,
                "Connection failed for {s}: {s}",
                .{ repo_name, reason },
            ) catch "connection failed",
        };
    }
};

// ============================================================================
// 事件错误
// ============================================================================

/// 事件处理错误
pub const EventError = struct {
    /// 事件类型
    event_type: []const u8,
    /// 聚合根类型
    aggregate_type: []const u8,
    /// 聚合根ID
    aggregate_id: ?i32 = null,
    /// 错误代码
    code: i32,
    /// 错误消息
    message: []const u8,
    /// 处理器名称（如果适用）
    handler_name: ?[]const u8 = null,
    /// 事件元数据
    metadata: ?std.json.Value = null,

    pub fn publishFailed(event_type: []const u8, cause: []const u8) EventError {
        return .{
            .event_type = event_type,
            .aggregate_type = "",
            .aggregate_id = null,
            .code = DomainErrorCodes.EventPublishFailed,
            .message = std.fmt.allocPrint(
                std.heap.page_allocator,
                "Failed to publish event '{s}': {s}",
                .{ event_type, cause },
            ) catch "event publish failed",
            .handler_name = null,
        };
    }

    pub fn handlerNotFound(event_type: []const u8, handler: []const u8) EventError {
        return .{
            .event_type = event_type,
            .aggregate_type = "",
            .aggregate_id = null,
            .code = DomainErrorCodes.EventHandlerNotFound,
            .message = std.fmt.allocPrint(
                std.heap.page_allocator,
                "Handler '{s}' not found for event '{s}'",
                .{ handler, event_type },
            ) catch "handler not found",
            .handler_name = handler,
        };
    }

    pub fn handlerExecutionFailed(
        event_type: []const u8,
        handler: []const u8,
        cause: []const u8,
    ) EventError {
        return .{
            .event_type = event_type,
            .aggregate_type = "",
            .aggregate_id = null,
            .code = DomainErrorCodes.EventHandlerExecutionFailed,
            .message = std.fmt.allocPrint(
                std.heap.page_allocator,
                "Handler '{s}' failed for event '{s}': {s}",
                .{ handler, event_type, cause },
            ) catch "handler execution failed",
            .handler_name = handler,
        };
    }
};

// ============================================================================
// 领域错误结果类型
// ============================================================================

/// 领域操作结果类型
pub fn DomainResult(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: DomainError,
        business_rule_violation: BusinessRuleError,
        aggregate_error: AggregateError,
        repository_error: RepositoryError,
        event_error: EventError,

        const Self = @This();

        pub fn isOk(self: Self) bool {
            return self == .ok;
        }

        pub fn isErr(self: Self) bool {
            return switch (self) {
                .ok => false,
                else => true,
            };
        }

        pub fn getValue(self: Self) ?T {
            return switch (self) {
                .ok => |v| v,
                else => null,
            };
        }

        pub fn getError(self: Self) ?DomainError {
            return switch (self) {
                .err => |e| e,
                else => null,
            };
        }

        pub fn getBusinessRuleError(self: Self) ?BusinessRuleError {
            return switch (self) {
                .business_rule_violation => |e| e,
                else => null,
            };
        }

        pub fn unwrap(self: Self) T {
            return switch (self) {
                .ok => |v| v,
                .err => @panic("unwrap on error"),
                .business_rule_violation => |e| @panic(e.message),
                .aggregate_error => @panic("aggregate error"),
                .repository_error => @panic("repository error"),
                .event_error => @panic("event error"),
            };
        }

        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .ok => |v| v,
                else => default,
            };
        }

        /// 转换为 Zig 原生 error union
        pub fn toZigError(self: Self) DomainError!T {
            return switch (self) {
                .ok => |v| v,
                .err => |e| e,
                .business_rule_violation => error.BusinessRuleViolation,
                .aggregate_error => error.AggregateNotFound,
                .repository_error => error.RepositoryError,
                .event_error => error.EventError,
            };
        }
    };
}

// ============================================================================
// 错误转换辅助函数
// ============================================================================

/// 将业务规则错误转换为 DomainError
pub fn businessRuleToDomainError(rule_error: BusinessRuleError) DomainError {
    _ = rule_error;
    return error.BusinessRuleViolation;
}

/// 将聚合错误转换为 DomainError
pub fn aggregateToDomainError(_: AggregateError) DomainError {
    return error.AggregateNotFound;
}

/// 将仓储错误转换为 DomainError
pub fn repositoryToDomainError(repo_error: RepositoryError) DomainError {
    return switch (repo_error.code) {
        DomainErrorCodes.RepositoryNotFound => error.RepositoryNotFound,
        DomainErrorCodes.RepositoryDuplicateKey => error.RepositoryDuplicateKey,
        DomainErrorCodes.RepositoryConnectionFailed => error.RepositoryConnectionFailed,
        DomainErrorCodes.RepositoryTransactionFailed => error.RepositoryTransactionFailed,
        else => error.RepositoryError,
    };
}

/// 将事件错误转换为 DomainError
pub fn eventToDomainError(_: EventError) DomainError {
    return error.EventError;
}

// ============================================================================
// 错误格式化
// ============================================================================

/// 格式化领域错误消息
pub fn formatDomainError(
    allocator: std.mem.Allocator,
    err: DomainError,
    context: ?std.json.Value,
) ![]u8 {
    const message = switch (err) {
        error.InvalidState => "实体状态无效",
        error.StateTransitionNotAllowed => "状态转换不允许",
        error.InvariantViolation => "不变量被违反",
        error.ValueObjectCreationFailed => "值对象创建失败",
        error.ValueObjectValidationFailed => "值对象验证失败",
        error.EntityNotFound => "实体不存在",
        error.EntityAlreadyExists => "实体已存在",
        error.EntityVersionMismatch => "实体版本不匹配",
        error.AggregateNotFound => "聚合根不存在",
        error.AggregateVersionConflict => "聚合根版本冲突",
        error.AggregateConcurrencyError => "聚合根并发错误",
        error.DomainServiceError => "领域服务错误",
        error.ServiceAlreadyRegistered => "服务已注册",
        error.RepositoryError => "仓储错误",
        error.RepositoryNotFound => "仓储中未找到实体",
        error.RepositoryDuplicateKey => "仓储唯一键冲突",
        error.RepositoryConnectionFailed => "仓储连接失败",
        error.RepositoryTransactionFailed => "仓储事务失败",
        error.EventError => "事件错误",
        error.EventPublishFailed => "事件发布失败",
        error.EventHandlerNotFound => "事件处理器未找到",
        error.EventHandlerExecutionFailed => "事件处理器执行失败",
        error.EventReplayingFailed => "事件重放失败",
        error.BusinessRuleViolation => "违反业务规则",
        error.PreConditionFailed => "前置条件失败",
        error.PostConditionFailed => "后置条件失败",
        error.InvariantNotSatisfied => "不变量未满足",
    };

    var buf = try std.ArrayList(u8).initCapacity(allocator, 256);
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator, message);

    if (context) |ctx| {
        const json_str = try std.json.stringifyAlloc(allocator, ctx, .{});
        defer allocator.free(json_str);
        try buf.appendSlice(allocator, "\nContext: ");
        try buf.appendSlice(allocator, json_str);
    }

    return buf.toOwnedSlice(allocator);
}

// ============================================================================
// 测试
// ============================================================================

test "DomainError - 基本错误代码" {
    try std.testing.expectEqual(@as(i32, 10000), DomainErrorCodes.Unknown);
    try std.testing.expectEqual(@as(i32, 10200), DomainErrorCodes.EntityNotFound);
    try std.testing.expectEqual(@as(i32, 10300), DomainErrorCodes.AggregateNotFound);
    try std.testing.expectEqual(@as(i32, 10700), DomainErrorCodes.BusinessRuleViolation);
}

test "BusinessRuleError - 创建和配置" {
    const err = BusinessRuleError.init("UserEmailUnique", "邮箱已被注册")
        .withAggregateId(123);

    try std.testing.expectEqualStrings("UserEmailUnique", err.rule);
    try std.testing.expectEqualStrings("邮箱已被注册", err.message);
    try std.testing.expectEqual(@as(?i32, 123), err.aggregate_id);
}

test "AggregateError - notFound" {
    const err = AggregateError.notFound("User", 123);

    try std.testing.expectEqualStrings("User", err.aggregate_type);
    try std.testing.expectEqual(@as(?i32, 123), err.aggregate_id);
    try std.testing.expectEqual(DomainErrorCodes.AggregateNotFound, err.code);
}

test "AggregateError - versionConflict" {
    const err = AggregateError.versionConflict("User", 123, 5, 6);

    try std.testing.expectEqual(DomainErrorCodes.AggregateVersionConflict, err.code);
    try std.testing.expectEqual(@as(?u32, 6), err.conflicting_version);
}

test "AggregateError - stateTransitionNotAllowed" {
    const err = AggregateError.stateTransitionNotAllowed("Order", "pending", "shipped");

    try std.testing.expectEqual(DomainErrorCodes.StateTransitionNotAllowed, err.code);
    try std.testing.expectEqualStrings("pending", err.current_state.?);
    try std.testing.expectEqualStrings("shipped", err.expected_state.?);
}

test "RepositoryError - notFound" {
    const err = RepositoryError.notFound("UserRepository", "User", 123);

    try std.testing.expectEqualStrings("UserRepository", err.repository_name);
    try std.testing.expectEqual(.FindById, err.operation);
    try std.testing.expectEqual(DomainErrorCodes.RepositoryNotFound, err.code);
}

test "RepositoryError - duplicateKey" {
    const err = RepositoryError.duplicateKey("UserRepository", "email", "test@example.com");

    try std.testing.expectEqual(.Save, err.operation);
    try std.testing.expectEqual(DomainErrorCodes.RepositoryDuplicateKey, err.code);
}

test "EventError - publishFailed" {
    const err = EventError.publishFailed("user.created", "connection refused");

    try std.testing.expectEqualStrings("user.created", err.event_type);
    try std.testing.expectEqual(DomainErrorCodes.EventPublishFailed, err.code);
}

test "EventError - handlerNotFound" {
    const err = EventError.handlerNotFound("user.created", "AuditHandler");

    try std.testing.expectEqualStrings("AuditHandler", err.handler_name.?);
    try std.testing.expectEqual(DomainErrorCodes.EventHandlerNotFound, err.code);
}

test "DomainResult - 基本操作" {
    const Result = DomainResult(i32);

    const success = Result{ .ok = 42 };
    try std.testing.expect(success.isOk());
    try std.testing.expect(!success.isErr());
    try std.testing.expectEqual(@as(?i32, 42), success.getValue());
    try std.testing.expectEqual(@as(i32, 42), success.unwrap());

    const fail = Result{ .err = error.EntityNotFound };
    try std.testing.expect(!fail.isOk());
    try std.testing.expect(fail.isErr());
    try std.testing.expect(fail.getValue() == null);
    try std.testing.expectEqual(@as(i32, 0), fail.unwrapOr(0));
}

test "DomainResult - business_rule_violation" {
    const Result = DomainResult(i32);

    const rule_err = BusinessRuleError.init("EmailUnique", "邮箱已存在");
    const result = Result{ .business_rule_violation = rule_err };

    try std.testing.expect(!result.isOk());
    const rule = result.getBusinessRuleError();
    try std.testing.expect(rule != null);
    try std.testing.expectEqualStrings("EmailUnique", rule.?.rule);
}

test "DomainResult - toZigError" {
    const Result = DomainResult(i32);

    const success = Result{ .ok = 42 };
    const value = try success.toZigError();
    try std.testing.expectEqual(@as(i32, 42), value);

    const fail = Result{ .err = error.EntityNotFound };
    _ = fail.toZigError() catch |e| {
        try std.testing.expectEqual(error.EntityNotFound, e);
    };
}

test "repositoryToDomainError - 映射" {
    const not_found = RepositoryError.notFound("UserRepo", "User", 1);
    try std.testing.expectEqual(error.RepositoryNotFound, repositoryToDomainError(not_found));

    const dup_key = RepositoryError.duplicateKey("UserRepo", "email", "test");
    try std.testing.expectEqual(error.RepositoryDuplicateKey, repositoryToDomainError(dup_key));
}
