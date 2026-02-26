//! DDD 错误处理测试 (DDD Error Handling Tests)
//!
//! 测试领域错误、业务规则错误、聚合根错误、仓储错误、事件错误的处理。

const std = @import("std");
const testing = std.testing;
const DddErrors = @import("../shared_kernel/patterns/ddd_errors.zig");
const DomainError = DddErrors.DomainError;
const BusinessRuleError = DddErrors.BusinessRuleError;
const AggregateError = DddErrors.AggregateError;
const RepositoryError = DddErrors.RepositoryError;
const EventError = DddErrors.EventError;
const DomainResult = DddErrors.DomainResult;
const DomainErrorCodes = DddErrors.DomainErrorCodes;

// ============================================================================
// 错误代码测试
// ============================================================================

test "DomainErrorCodes - 错误代码范围正确" {
    // 领域错误 (10000-19999)
    try testing.expect(DomainErrorCodes.Unknown >= 10000 and DomainErrorCodes.Unknown < 20000);
    try testing.expect(DomainErrorCodes.AggregateNotFound >= 10000 and DomainErrorCodes.AggregateNotFound < 20000);
    try testing.expect(DomainErrorCodes.BusinessRuleViolation >= 10000 and DomainErrorCodes.BusinessRuleViolation < 20000);
}

test "DomainErrorCodes - 聚合根错误代码" {
    try testing.expectEqual(@as(i32, 10300), DomainErrorCodes.AggregateNotFound);
    try testing.expectEqual(@as(i32, 10301), DomainErrorCodes.AggregateVersionConflict);
    try testing.expectEqual(@as(i32, 10302), DomainErrorCodes.AggregateConcurrencyError);
}

test "DomainErrorCodes - 仓储错误代码" {
    try testing.expectEqual(@as(i32, 10500), DomainErrorCodes.RepositoryError);
    try testing.expectEqual(@as(i32, 10501), DomainErrorCodes.RepositoryNotFound);
    try testing.expectEqual(@as(i32, 10502), DomainErrorCodes.RepositoryDuplicateKey);
    try testing.expectEqual(@as(i32, 10503), DomainErrorCodes.RepositoryConnectionFailed);
}

test "DomainErrorCodes - 事件错误代码" {
    try testing.expectEqual(@as(i32, 10600), DomainErrorCodes.EventError);
    try testing.expectEqual(@as(i32, 10601), DomainErrorCodes.EventPublishFailed);
    try testing.expectEqual(@as(i32, 10602), DomainErrorCodes.EventHandlerNotFound);
    try testing.expectEqual(@as(i32, 10603), DomainErrorCodes.EventHandlerExecutionFailed);
}

test "DomainErrorCodes - 业务规则错误代码" {
    try testing.expectEqual(@as(i32, 10700), DomainErrorCodes.BusinessRuleViolation);
    try testing.expectEqual(@as(i32, 10701), DomainErrorCodes.PreConditionFailed);
    try testing.expectEqual(@as(i32, 10702), DomainErrorCodes.PostConditionFailed);
}

// ============================================================================
// 业务规则错误测试
// ============================================================================

test "BusinessRuleError - 创建基本错误" {
    const err = BusinessRuleError.init("EmailUnique", "邮箱已被注册");

    try testing.expectEqualStrings("EmailUnique", err.rule);
    try testing.expectEqualStrings("邮箱已被注册", err.message);
    try testing.expect(err.aggregate_id == null);
    try testing.expect(err.context == null);
}

test "BusinessRuleError - 添加聚合根ID" {
    const err = BusinessRuleError.init("UsernameUnique", "用户名已存在")
        .withAggregateId(12345);

    try testing.expectEqual(@as(?i32, 12345), err.aggregate_id);
}

test "BusinessRuleError - 添加上下文" {
    const err = BusinessRuleError.init("StockSufficient", "库存不足")
        .withContext(.{ .requested = 100, .available = 50 });

    try testing.expect(err.context != null);
}

// ============================================================================
// 聚合根错误测试
// ============================================================================

test "AggregateError - notFound" {
    const err = AggregateError.notFound("User", 123);

    try testing.expectEqualStrings("User", err.aggregate_type);
    try testing.expectEqual(@as(?i32, 123), err.aggregate_id);
    try testing.expectEqual(DomainErrorCodes.AggregateNotFound, err.code);
    try testing.expect(std.mem.indexOf(u8, err.message, "User") != null);
    try testing.expect(std.mem.indexOf(u8, err.message, "123") != null);
}

test "AggregateError - versionConflict" {
    const err = AggregateError.versionConflict("Order", 456, 5, 6);

    try testing.expectEqualStrings("Order", err.aggregate_type);
    try testing.expectEqual(@as(?i32, 456), err.aggregate_id);
    try testing.expectEqual(DomainErrorCodes.AggregateVersionConflict, err.code);
    try testing.expectEqual(@as(?u32, 6), err.conflicting_version);
    try testing.expect(std.mem.indexOf(u8, err.message, "expected 5") != null);
    try testing.expect(std.mem.indexOf(u8, err.message, "got 6") != null);
}

test "AggregateError - stateTransitionNotAllowed" {
    const err = AggregateError.stateTransitionNotAllowed("Article", "draft", "published");

    try testing.expectEqualStrings("Article", err.aggregate_type);
    try testing.expectEqual(DomainErrorCodes.StateTransitionNotAllowed, err.code);
    try testing.expectEqualStrings("draft", err.current_state.?);
    try testing.expectEqualStrings("published", err.expected_state.?);
    try testing.expect(std.mem.indexOf(u8, err.message, "draft") != null);
    try testing.expect(std.mem.indexOf(u8, err.message, "published") != null);
}

// ============================================================================
// 仓储错误测试
// ============================================================================

test "RepositoryError - notFound" {
    const err = RepositoryError.notFound("UserRepository", "User", 789);

    try testing.expectEqualStrings("UserRepository", err.repository_name);
    try testing.expectEqual(.FindById, err.operation);
    try testing.expectEqual(DomainErrorCodes.RepositoryNotFound, err.code);
    try testing.expectEqual(@as(?i32, 789), err.entity_id);
    try testing.expect(std.mem.indexOf(u8, err.message, "User") != null);
}

test "RepositoryError - duplicateKey" {
    const err = RepositoryError.duplicateKey("ProductRepository", "sku", "SKU-12345");

    try testing.expectEqual(.Save, err.operation);
    try testing.expectEqual(DomainErrorCodes.RepositoryDuplicateKey, err.code);
    try testing.expect(std.mem.indexOf(u8, err.message, "sku") != null);
    try testing.expect(std.mem.indexOf(u8, err.message, "SKU-12345") != null);
}

test "RepositoryError - connectionFailed" {
    const err = RepositoryError.connectionFailed("OrderRepository", "connection timeout");

    try testing.expectEqual(.Transaction, err.operation);
    try testing.expectEqual(DomainErrorCodes.RepositoryConnectionFailed, err.code);
    try testing.expect(std.mem.indexOf(u8, err.message, "connection timeout") != null);
}

test "RepositoryError - 操作类型枚举" {
    try testing.expectEqual(@as(RepositoryError.RepositoryOperation, .FindById), .FindById);
    try testing.expectEqual(@as(RepositoryError.RepositoryOperation, .Save), .Save);
    try testing.expectEqual(@as(RepositoryError.RepositoryOperation, .Delete), .Delete);
    try testing.expectEqual(@as(RepositoryError.RepositoryOperation, .Exists), .Exists);
}

// ============================================================================
// 事件错误测试
// ============================================================================

test "EventError - publishFailed" {
    const err = EventError.publishFailed("user.created", "message queue disconnected");

    try testing.expectEqualStrings("user.created", err.event_type);
    try testing.expectEqual(DomainErrorCodes.EventPublishFailed, err.code);
    try testing.expect(std.mem.indexOf(u8, err.message, "user.created") != null);
    try testing.expect(std.mem.indexOf(u8, err.message, "message queue disconnected") != null);
}

test "EventError - handlerNotFound" {
    const err = EventError.handlerNotFound("order.shipped", "NotificationHandler");

    try testing.expectEqualStrings("NotificationHandler", err.handler_name.?);
    try testing.expectEqual(DomainErrorCodes.EventHandlerNotFound, err.code);
    try testing.expect(std.mem.indexOf(u8, err.message, "NotificationHandler") != null);
}

test "EventError - handlerExecutionFailed" {
    const err = EventError.handlerExecutionFailed("user.created", "EmailHandler", "SMTP error");

    try testing.expectEqualStrings("EmailHandler", err.handler_name.?);
    try testing.expectEqual(DomainErrorCodes.EventHandlerExecutionFailed, err.code);
    try testing.expect(std.mem.indexOf(u8, err.message, "SMTP error") != null);
}

// ============================================================================
// DomainResult 测试
// ============================================================================

test "DomainResult - 成功结果" {
    const Result = DomainResult(i32);

    const result = Result{ .ok = 42 };

    try testing.expect(result.isOk());
    try testing.expect(!result.isErr());
    try testing.expectEqual(@as(?i32, 42), result.getValue());
    try testing.expectEqual(@as(?DomainError, null), result.getError());
    try testing.expectEqual(@as(i32, 42), result.unwrap());
    try testing.expectEqual(@as(i32, 100), result.unwrapOr(100));
}

test "DomainResult - 领域错误" {
    const Result = DomainResult(i32);

    const result = Result{ .err = error.EntityNotFound };

    try testing.expect(!result.isOk());
    try testing.expect(result.isErr());
    try testing.expect(result.getValue() == null);
    try testing.expect(result.getError() != null);
    try testing.expectEqual(@as(i32, 0), result.unwrapOr(0));
}

test "DomainResult - 业务规则违反" {
    const Result = DomainResult(i32);

    const rule_err = BusinessRuleError.init("UserEmailUnique", "邮箱已被使用");
    const result = Result{ .business_rule_violation = rule_err };

    try testing.expect(!result.isOk());
    try testing.expect(result.getBusinessRuleError() != null);
    try testing.expectEqualStrings("UserEmailUnique", result.getBusinessRuleError().?.rule);
    try testing.expectEqual(@as(i32, 0), result.unwrapOr(0));
}

test "DomainResult - 聚合根错误" {
    const Result = DomainResult(i32);

    const agg_err = AggregateError.notFound("User", 123);
    const result = Result{ .aggregate_error = agg_err };

    try testing.expect(!result.isOk());
}

test "DomainResult - 仓储错误" {
    const Result = DomainResult(i32);

    const repo_err = RepositoryError.notFound("UserRepo", "User", 456);
    const result = Result{ .repository_error = repo_err };

    try testing.expect(!result.isOk());
}

test "DomainResult - 事件错误" {
    const Result = DomainResult(i32);

    const evt_err = EventError.publishFailed("user.created", "queue full");
    const result = Result{ .event_error = evt_err };

    try testing.expect(!result.isOk());
}

test "DomainResult - toZigError 成功" {
    const Result = DomainResult(i32);

    const result = Result{ .ok = 100 };
    const value = try result.toZigError();
    try testing.expectEqual(@as(i32, 100), value);
}

test "DomainResult - toZigError 错误转换" {
    const Result = DomainResult(i32);

    // 转换为领域错误
    const domain_err = Result{ .err = error.EntityNotFound };
    _ = domain_err.toZigError() catch |e| {
        try testing.expectEqual(error.EntityNotFound, e);
    };

    // 转换为业务规则错误
    const rule_err = Result{ .business_rule_violation = .{ .rule = "test", .message = "msg" } };
    _ = rule_err.toZigError() catch |e| {
        try testing.expectEqual(error.BusinessRuleViolation, e);
    };
}

// ============================================================================
// 错误转换测试
// ============================================================================

test "repositoryToDomainError - 映射所有错误类型" {
    // NotFound -> RepositoryNotFound
    const not_found = RepositoryError.notFound("Test", "Test", 1);
    try testing.expectEqual(error.RepositoryNotFound, DddErrors.repositoryToDomainError(not_found));

    // DuplicateKey -> RepositoryDuplicateKey
    const dup_key = RepositoryError.duplicateKey("Test", "field", "value");
    try testing.expectEqual(error.RepositoryDuplicateKey, DddErrors.repositoryToDomainError(dup_key));

    // ConnectionFailed -> RepositoryConnectionFailed
    const conn_failed = RepositoryError.connectionFailed("Test", "timeout");
    try testing.expectEqual(error.RepositoryConnectionFailed, DddErrors.repositoryToDomainError(conn_failed));

    // 其他错误 -> RepositoryError
    const generic = RepositoryError{
        .repository_name = "Test",
        .operation = .FindBy,
        .code = DomainErrorCodes.RepositoryError,
        .message = "unknown error",
    };
    try testing.expectEqual(error.RepositoryError, DddErrors.repositoryToDomainError(generic));
}

test "eventToDomainError - 转换为事件错误" {
    const err = EventError.publishFailed("test", "cause");
    try testing.expectEqual(error.EventError, DddErrors.eventToDomainError(err));
}

test "businessRuleToDomainError - 转换为领域错误" {
    const err = BusinessRuleError.init("TestRule", "Test message");
    try testing.expectEqual(error.BusinessRuleViolation, DddErrors.businessRuleToDomainError(err));
}

test "aggregateToDomainError - 转换为领域错误" {
    const err = AggregateError.notFound("Test", 1);
    try testing.expectEqual(error.AggregateNotFound, DddErrors.aggregateToDomainError(err));
}

// ============================================================================
// 错误格式化测试
// ============================================================================

test "formatDomainError - 格式化基本错误" {
    const allocator = testing.allocator;

    const message = try DddErrors.formatDomainError(allocator, error.EntityNotFound, null);
    defer allocator.free(message);

    try testing.expect(message.len > 0);
}

test "formatDomainError - 格式化带上下文" {
    const allocator = testing.allocator;

    const context = .{ .user_id = 123, .action = "login" };
    const message = try DddErrors.formatDomainError(allocator, error.InvalidState, context);
    defer allocator.free(message);

    try testing.expect(message.len > 0);
    try testing.expect(std.mem.indexOf(u8, message, "Context:") != null);
}

// ============================================================================
// DomainError 变体测试
// ============================================================================

test "DomainError - 所有错误变体" {
    // 验证所有错误变体可以创建
    _ = error.InvalidState;
    _ = error.StateTransitionNotAllowed;
    _ = error.InvariantViolation;
    _ = error.ValueObjectCreationFailed;
    _ = error.ValueObjectValidationFailed;
    _ = error.EntityNotFound;
    _ = error.EntityAlreadyExists;
    _ = error.EntityVersionMismatch;
    _ = error.AggregateNotFound;
    _ = error.AggregateVersionConflict;
    _ = error.AggregateConcurrencyError;
    _ = error.DomainServiceError;
    _ = error.ServiceAlreadyRegistered;
    _ = error.RepositoryError;
    _ = error.RepositoryNotFound;
    _ = error.RepositoryDuplicateKey;
    _ = error.RepositoryConnectionFailed;
    _ = error.RepositoryTransactionFailed;
    _ = error.EventError;
    _ = error.EventPublishFailed;
    _ = error.EventHandlerNotFound;
    _ = error.EventHandlerExecutionFailed;
    _ = error.EventReplayingFailed;
    _ = error.BusinessRuleViolation;
    _ = error.PreConditionFailed;
    _ = error.PostConditionFailed;
    _ = error.InvariantNotSatisfied;
}

// ============================================================================
// 集成测试
// ============================================================================

test "DDD Errors - 完整集成场景" {
    const Result = DomainResult(i32);

    // 场景1: 成功创建用户
    const success = Result{ .ok = 1 };
    try testing.expect(success.isOk());
    try testing.expectEqual(@as(i32, 1), success.unwrap());

    // 场景2: 业务规则违反
    const rule_err = BusinessRuleError.init("EmailUnique", "邮箱已存在").withAggregateId(1);
    const rule_result = Result{ .business_rule_violation = rule_err };
    try testing.expect(!rule_result.isOk());
    try testing.expectEqualStrings("EmailUnique", rule_result.getBusinessRuleError().?.rule);

    // 场景3: 聚合根不存在
    const agg_err = AggregateError.notFound("User", 999);
    const agg_result = Result{ .aggregate_error = agg_err };
    try testing.expect(!agg_result.isOk());

    // 场景4: 仓储错误
    const repo_err = RepositoryError.notFound("UserRepository", "User", 888);
    const repo_result = Result{ .repository_error = repo_err };
    try testing.expect(!repo_result.isOk());
}
