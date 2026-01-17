//! 查询模式 (Query Pattern)
//!
//! 查询模式封装数据读取请求作为对象，支持灵活的数据检索。
//! 在 CQRS 模式中，查询是只读操作，不会改变系统状态。
//!
//! ## 特性
//! - 查询是不可变的
//! - 查询可以包含过滤、排序、分页参数
//! - 查询返回预构建的视图模型（Read Model）
//!
//! ## 与命令的区别
//! | 特性 | 命令 | 查询 |
//! |------|------|------|
//! | 目的 | 改变状态 | 读取数据 |
//! | 返回 | CommandResult | QueryResult |
//! | 副作用 | 可能产生事件 | 无副作用 |
//! | 幂等性 | 通常不是 | 应该是 |

const std = @import("std");

/// 查询结果
pub const QueryResult = struct {
    /// 是否成功
    success: bool,
    /// 结果数据
    data: ?*anyopaque = null,
    /// 数据数量
    count: usize = 0,
    /// 总数量（用于分页）
    total: usize = 0,
    /// 页码（用于分页）
    page: usize = 0,
    /// 每页数量（用于分页）
    page_size: usize = 0,
    /// 错误信息（如果失败）
    error: ?[]const u8 = null,
};

/// 查询排序方向
pub const SortDirection = enum {
    Asc,
    Desc,
};

/// 查询排序
pub const QuerySort = struct {
    field: []const u8,
    direction: SortDirection = .Asc,
};

/// 查询分页
pub const QueryPagination = struct {
    /// 页码（从1开始）
    page: usize = 1,
    /// 每页数量
    page_size: usize = 20,
    /// 最大每页数量
    max_page_size: usize = 100,

    /// 计算偏移量
    pub fn offset(self: *const QueryPagination) usize {
        return (self.page - 1) * self.page_size;
    }

    /// 验证分页参数
    pub fn validate(self: *QueryPagination) void {
        if (self.page < 1) self.page = 1;
        if (self.page_size < 1) self.page_size = 1;
        if (self.page_size > self.max_page_size) self.page_size = self.max_page_size;
    }
};

/// 查询过滤条件
pub const QueryFilter = struct {
    field: []const u8,
    operator: []const u8, // "eq", "ne", "gt", "lt", "like", "in", "between"
    value: *anyopaque,
};

/// 查询接口
pub const Query = struct {
    /// 查询类型名称
    type: []const u8,
    /// 过滤条件
    filters: std.ArrayListUnmanaged(QueryFilter),
    /// 排序条件
    sorts: std.ArrayListUnmanaged(QuerySort),
    /// 分页
    pagination: QueryPagination,
    /// 包含的字段
    includes: std.ArrayListUnmanaged([]const u8),

    pub fn init(allocator: std.mem.Allocator, query_type: []const u8) Query {
        return .{
            .type = query_type,
            .filters = .{},
            .sorts = .{},
            .pagination = .{},
            .includes = .{},
        };
    }

    pub fn deinit(self: *Query, allocator: std.mem.Allocator) void {
        for (self.filters.items) |filter| {
            allocator.free(filter.field);
            allocator.free(filter.operator);
        }
        self.filters.deinit(allocator);

        for (self.sorts.items) |sort| {
            allocator.free(sort.field);
        }
        self.sorts.deinit(allocator);

        for (self.includes.items) |include| {
            allocator.free(include);
        }
        self.includes.deinit(allocator);
    }

    /// 添加过滤条件
    pub fn addFilter(self: *Query, allocator: std.mem.Allocator, field: []const u8, operator: []const u8, value: *anyopaque) !void {
        try self.filters.append(allocator, .{
            .field = try allocator.dupe(u8, field),
            .operator = try allocator.dupe(u8, operator),
            .value = value,
        });
    }

    /// 添加排序
    pub fn addSort(self: *Query, allocator: std.mem.Allocator, field: []const u8, direction: SortDirection) !void {
        try self.sorts.append(allocator, .{
            .field = try allocator.dupe(u8, field),
            .direction = direction,
        });
    }

    /// 设置分页
    pub fn setPagination(self: *Query, page: usize, page_size: usize) void {
        self.pagination.page = page;
        self.pagination.page_size = page_size;
        self.pagination.validate();
    }

    /// 添加包含字段
    pub fn addInclude(self: *Query, allocator: std.mem.Allocator, field: []const u8) !void {
        try self.includes.append(allocator, try allocator.dupe(u8, field));
    }
};

/// 查询处理器函数类型
pub fn QueryHandlerFunc(comptime QueryType: type, comptime ResultType: type) type {
    return fn (query: QueryType) ResultType;
}

/// 查询处理器接口
pub const QueryHandler = struct {
    allocator: std.mem.Allocator,
    query_type: []const u8,
    handleFn: *const fn (query: *const Query) QueryResult,

    pub fn init(
        allocator: std.mem.Allocator,
        query_type: []const u8,
        handleFn: *const fn (query: *const Query) QueryResult,
    ) QueryHandler {
        return .{
            .allocator = allocator,
            .query_type = query_type,
            .handleFn = handleFn,
        };
    }

    pub fn deinit(self: *QueryHandler) void {
        self.allocator.free(self.query_type);
    }
};

/// 查询总线 (Query Bus)
///
/// 负责将查询路由到对应的处理器
pub const QueryBus = struct {
    allocator: std.mem.Allocator,
    handlers: std.StringHashMap(*QueryHandler),

    pub fn init(allocator: std.mem.Allocator) QueryBus {
        return .{
            .allocator = allocator,
            .handlers = std.StringHashMap(*QueryHandler).init(allocator),
        };
    }

    pub fn deinit(self: *QueryBus) void {
        var iter = self.handlers.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
            self.allocator.destroy(entry.value_ptr);
        }
        self.handlers.deinit();
    }

    /// 注册查询处理器
    pub fn register(self: *QueryBus, query_type: []const u8, handler: *QueryHandler) !void {
        const key = try self.allocator.dupe(u8, query_type);
        errdefer self.allocator.free(key);

        try self.handlers.put(key, handler);
        std.log.info("Query handler registered for '{s}'", .{query_type});
    }

    /// 发送查询到总线
    pub fn fetch(self: *QueryBus, query: *const Query) QueryResult {
        if (self.handlers.get(query.type)) |handler| {
            return handler.handleFn(query);
        }
        return QueryResult{
            .success = false,
            .data = null,
            .error = try self.allocator.dupe(u8, "No handler registered for query"),
        };
    }
};

/// 用户查询模型（Read Model）
pub const UserReadModel = struct {
    id: i32,
    username: []const u8,
    email: []const u8,
    nickname: []const u8,
    avatar: []const u8,
    status: []const u8,
    created_at: i64,
    last_login_at: ?i64,
};

/// 创建查询
pub fn createQuery(allocator: std.mem.Allocator, query_type: []const u8) !Query {
    return Query{
        .type = try allocator.dupe(u8, query_type),
        .filters = .{},
        .sorts = .{},
        .pagination = .{},
        .includes = .{},
    };
}

test "QueryBus - register and fetch" {
    const allocator = testing.allocator;

    var bus = QueryBus.init(allocator);
    defer bus.deinit();

    var received = false;

    const handler = try allocator.create(QueryHandler);
    handler.* = QueryHandler.init(allocator, "TestQuery", struct {
        fn handle(query: *const Query) QueryResult {
            _ = query;
            received = true;
            return QueryResult{ .success = true, .count = 0 };
        }
    }.handle);
    defer {
        handler.deinit();
        allocator.destroy(handler);
    }

    try bus.register("TestQuery", handler);

    var query = Query.init(allocator, "TestQuery");
    defer query.deinit(allocator);

    const result = bus.fetch(&query);
    try testing.expect(result.success);
    try testing.expect(received);
}

test "QueryPagination - offset calculation" {
    var pagination = QueryPagination{ .page = 3, .page_size = 10, .max_page_size = 100 };
    try testing.expectEqual(@as(usize, 20), pagination.offset());
}

test "QueryPagination - validate bounds" {
    var pagination = QueryPagination{ .page = 0, .page_size = 500, .max_page_size = 100 };
    pagination.validate();
    try testing.expectEqual(@as(usize, 1), pagination.page);
    try testing.expectEqual(@as(usize, 100), pagination.page_size);
}
