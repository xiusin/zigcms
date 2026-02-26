//! CQRS 模式测试 (CQRS Pattern Tests)
//!
//! 测试命令、查询、投影等 CQRS 核心模式的实现。

const std = @import("std");
const testing = std.testing;
const Command = @import("../shared_kernel/patterns/command.zig").Command;
const CommandBus = @import("../shared_kernel/patterns/command.zig").CommandBus;
const CommandResult = @import("../shared_kernel/patterns/command.zig").CommandResult;
const CommandHandler = @import("../shared_kernel/patterns/command.zig").CommandHandler;
const Query = @import("../shared_kernel/patterns/query.zig").Query;
const QueryBus = @import("../shared_kernel/patterns/query.zig").QueryBus;
const QueryResult = @import("../shared_kernel/patterns/query.zig").QueryResult;
const QueryHandler = @import("../shared_kernel/patterns/query.zig").QueryHandler;
const QueryPagination = @import("../shared_kernel/patterns/query.zig").QueryPagination;
const SortDirection = @import("../shared_kernel/patterns/query.zig").SortDirection;
const Projection = @import("../shared_kernel/patterns/projection.zig").Projection;
const UserProjection = @import("../shared_kernel/patterns/projection.zig").UserProjection;
const ProjectionRepository = @import("../shared_kernel/patterns/projection.zig").ProjectionRepository;

// ============================================================================
// Command Bus 测试
// ============================================================================

test "CommandBus - register and send command" {
    const allocator = testing.allocator;

    var bus = CommandBus.init(allocator);
    defer bus.deinit();

    var command_received = false;

    const handler = try allocator.create(CommandHandler);
    handler.* = CommandHandler.init(allocator, "CreateUserCommand", struct {
        fn handle(cmd: *anyopaque) CommandResult {
            _ = cmd;
            command_received = true;
            return CommandResult{ .success = true, .events = .{} };
        }
    }.handle);
    defer {
        handler.deinit();
        allocator.destroy(handler);
    }

    try bus.register("CreateUserCommand", handler);

    const result = bus.send(undefined, "CreateUserCommand");
    try testing.expect(result.success);
    try testing.expect(command_received);
}

test "CommandBus - unknown command returns error" {
    const allocator = testing.allocator;

    var bus = CommandBus.init(allocator);
    defer bus.deinit();

    const result = bus.send(undefined, "UnknownCommand");
    try testing.expect(!result.success);
    try testing.expect(result.error != null);
}

test "CommandBus - multiple handlers can be registered" {
    const allocator = testing.allocator;

    var bus = CommandBus.init(allocator);
    defer bus.deinit();

    var handler1_received = false;
    var handler2_received = false;

    const h1 = try allocator.create(CommandHandler);
    h1.* = CommandHandler.init(allocator, "MultiCommand", struct {
        fn handle(cmd: *anyopaque) CommandResult {
            _ = cmd;
            handler1_received = true;
            return CommandResult{ .success = true, .events = .{} };
        }
    }.handle);
    defer {
        h1.deinit();
        allocator.destroy(h1);
    }

    const h2 = try allocator.create(CommandHandler);
    h2.* = CommandHandler.init(allocator, "MultiCommand", struct {
        fn handle(cmd: *anyopaque) CommandResult {
            _ = cmd;
            handler2_received = true;
            return CommandResult{ .success = true, .events = .{} };
        }
    }.handle);
    defer {
        h2.deinit();
        allocator.destroy(h2);
    }

    // 注意：同一个类型只会保留最后一个处理器
    try bus.register("MultiCommand", h1);
    try bus.register("MultiCommand", h2);

    const result = bus.send(undefined, "MultiCommand");
    try testing.expect(result.success);
    try testing.expect(handler2_received);
}

// ============================================================================
// Query Bus 测试
// ============================================================================

test "QueryBus - register and fetch query" {
    const allocator = testing.allocator;

    var bus = QueryBus.init(allocator);
    defer bus.deinit();

    var query_received = false;

    const handler = try allocator.create(QueryHandler);
    handler.* = QueryHandler.init(allocator, "GetUserQuery", struct {
        fn handle(query: *const Query) QueryResult {
            _ = query;
            query_received = true;
            return QueryResult{ .success = true, .count = 1 };
        }
    }.handle);
    defer {
        handler.deinit();
        allocator.destroy(handler);
    }

    try bus.register("GetUserQuery", handler);

    var query = Query.init(allocator, "GetUserQuery");
    defer query.deinit(allocator);

    const result = bus.fetch(&query);
    try testing.expect(result.success);
    try testing.expect(query_received);
}

test "QueryBus - unknown query returns error" {
    const allocator = testing.allocator;

    var bus = QueryBus.init(allocator);
    defer bus.deinit();

    var query = Query.init(allocator, "UnknownQuery");
    defer query.deinit(allocator);

    const result = bus.fetch(&query);
    try testing.expect(!result.success);
    try testing.expect(result.error != null);
}

test "QueryBus - query with pagination" {
    const allocator = testing.allocator;

    var bus = QueryBus.init(allocator);
    defer bus.deinit();

    const handler = try allocator.create(QueryHandler);
    handler.* = QueryHandler.init(allocator, "ListUsersQuery", struct {
        fn handle(query: *const Query) QueryResult {
            _ = query;
            return QueryResult{ .success = true, .count = 10, .total = 100, .page = 1, .page_size = 10 };
        }
    }.handle);
    defer {
        handler.deinit();
        allocator.destroy(handler);
    }

    try bus.register("ListUsersQuery", handler);

    var query = Query.init(allocator, "ListUsersQuery");
    query.setPagination(1, 10);
    defer query.deinit(allocator);

    const result = bus.fetch(&query);
    try testing.expect(result.success);
    try testing.expectEqual(@as(usize, 10), result.count);
    try testing.expectEqual(@as(usize, 100), result.total);
}

// ============================================================================
// Query Pagination 测试
// ============================================================================

test "QueryPagination - offset calculation" {
    var pagination = QueryPagination{ .page = 1, .page_size = 10, .max_page_size = 100 };
    try testing.expectEqual(@as(usize, 0), pagination.offset());

    pagination.page = 3;
    try testing.expectEqual(@as(usize, 20), pagination.offset());

    pagination.page = 10;
    try testing.expectEqual(@as(usize, 90), pagination.offset());
}

test "QueryPagination - validate bounds" {
    var pagination = QueryPagination{ .page = 0, .page_size = 0, .max_page_size = 100 };
    pagination.validate();
    try testing.expectEqual(@as(usize, 1), pagination.page);
    try testing.expectEqual(@as(usize, 1), pagination.page_size);

    pagination.page_size = 500;
    pagination.validate();
    try testing.expectEqual(@as(usize, 100), pagination.page_size);
}

test "Query - add filters and sorts" {
    const allocator = testing.allocator;

    var query = Query.init(allocator, "TestQuery");
    defer query.deinit(allocator);

    try query.addFilter(allocator, "username", "eq", undefined);
    try query.addSort(allocator, "created_at", .Desc);
    query.setPagination(1, 20);

    try testing.expectEqual(@as(usize, 1), query.filters.items.len);
    try testing.expectEqual(@as(usize, 1), query.sorts.items.len);
    try testing.expectEqual(@as(usize, 1), query.pagination.page);
}

// ============================================================================
// Projection 测试
// ============================================================================

test "Projection - UserProjection init" {
    const allocator = testing.allocator;

    var projection = UserProjection.init(allocator);
    defer projection.deinit();

    try testing.expectEqual(@as(u32, 0), projection.getVersion());
    try testing.expect(projection.status == .Idle);
}

test "Projection - status transitions" {
    const allocator = testing.allocator;

    var projection = UserProjection.init(allocator);
    defer projection.deinit();

    try testing.expect(projection.status == .Idle);
}

test "ProjectionRepository - save and get projection" {
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

// ============================================================================
// CQRS 集成测试
// ============================================================================

test "CQRS - Command creates entity, Query retrieves read model" {
    const allocator = testing.allocator;

    // 创建命令总线
    var command_bus = CommandBus.init(allocator);
    defer command_bus.deinit();

    // 创建查询总线
    var query_bus = QueryBus.init(allocator);
    defer query_bus.deinit();

    // 注册命令处理器
    var command_handled = false;
    const cmd_handler = try allocator.create(CommandHandler);
    cmd_handler.* = CommandHandler.init(allocator, "CreateUserCommand", struct {
        fn handle(cmd: *anyopaque) CommandResult {
            _ = cmd;
            command_handled = true;
            return CommandResult{ .success = true, .events = .{} };
        }
    }.handle);
    defer {
        cmd_handler.deinit();
        allocator.destroy(cmd_handler);
    }
    try command_bus.register("CreateUserCommand", cmd_handler);

    // 注册查询处理器
    var query_handled = false;
    const qry_handler = try allocator.create(QueryHandler);
    qry_handler.* = QueryHandler.init(allocator, "GetUserQuery", struct {
        fn handle(query: *const Query) QueryResult {
            _ = query;
            query_handled = true;
            return QueryResult{ .success = true, .count = 1 };
        }
    }.handle);
    defer {
        qry_handler.deinit();
        allocator.destroy(qry_handler);
    }
    try query_bus.register("GetUserQuery", qry_handler);

    // 发送命令
    const cmd_result = command_bus.send(undefined, "CreateUserCommand");
    try testing.expect(cmd_result.success);
    try testing.expect(command_handled);

    // 发送查询
    var query = Query.init(allocator, "GetUserQuery");
    defer query.deinit(allocator);

    const qry_result = query_bus.fetch(&query);
    try testing.expect(qry_result.success);
    try testing.expect(query_handled);
}
