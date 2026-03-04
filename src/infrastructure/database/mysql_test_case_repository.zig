//! MySQL 测试用例仓储实现
//!
//! 实现测试用例仓储接口，使用 ORM QueryBuilder 构建查询，
//! 遵循 ZigCMS 开发范式：参数化查询、关系预加载、内存安全管理。
//!
//! ## 使用示例
//!
//! ```zig
//! const repo = try MysqlTestCaseRepository.init(allocator, db);
//! defer repo.deinit();
//!
//! // 查询测试用例
//! const test_case = try repo.findById(1);
//! defer if (test_case) |tc| repo.freeTestCase(tc);
//!
//! // 搜索测试用例
//! const result = try repo.search(.{
//!     .project_id = 1,
//!     .status = .pending,
//!     .page = 1,
//!     .page_size = 20,
//! });
//! defer repo.freePageResult(result);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const sql = @import("../../application/services/sql/orm.zig");

// 导入领域层定义
const TestCase = @import("../../domain/entities/test_case.model.zig").TestCase;
const TestCaseStatus = @import("../../domain/entities/test_case.model.zig").TestCaseStatus;
const Priority = @import("../../domain/entities/test_case.model.zig").Priority;
const TestCaseRepository = @import("../../domain/repositories/test_case_repository.zig").TestCaseRepository;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;
const SearchQuery = @import("../../domain/repositories/test_case_repository.zig").SearchQuery;
const PageResult = @import("../../domain/repositories/test_case_repository.zig").PageResult;

/// MySQL 测试用例仓储实现
pub const MysqlTestCaseRepository = struct {
    allocator: Allocator,
    db: *sql.Database,

    const Self = @This();

    /// 初始化仓储
    pub fn init(allocator: Allocator, db: *sql.Database) Self {
        return .{
            .allocator = allocator,
            .db = db,
        };
    }

    /// 清理资源
    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// 定义 ORM 模型
    const OrmTestCase = sql.define(struct {
        pub const table_name = "quality_test_cases";
        pub const primary_key = "id";

        id: ?i32 = null,
        title: []const u8 = "",
        project_id: i32 = 0,
        module_id: i32 = 0,
        requirement_id: ?i32 = null,
        priority: []const u8 = "medium",
        status: []const u8 = "pending",
        precondition: []const u8 = "",
        steps: []const u8 = "",
        expected_result: []const u8 = "",
        actual_result: []const u8 = "",
        assignee: ?[]const u8 = null,
        tags: []const u8 = "",
        created_by: []const u8 = "",
        created_at: ?i64 = null,
        updated_at: ?i64 = null,
    });

    /// 根据 ID 查询测试用例
    pub fn findById(self: *Self, id: i32) !?TestCase {
        // 使用 ORM QueryBuilder 构建查询
        var q = OrmTestCase.query(self.db);
        defer q.deinit();

        // 参数化查询防止 SQL 注入
        _ = q.where("id", "=", id);

        // 执行查询
        const rows = try q.get();
        defer OrmTestCase.freeModels(rows);

        if (rows.len == 0) return null;

        // 深拷贝字符串字段（防止悬垂指针）
        return try self.ormToEntity(rows[0]);
    }

    /// 根据项目 ID 分页查询测试用例
    pub fn findByProject(self: *Self, project_id: i32, query: PageQuery) !PageResult(TestCase) {
        // 构建查询
        var q = OrmTestCase.query(self.db);
        defer q.deinit();

        // 参数化查询
        _ = q.where("project_id", "=", project_id)
            .orderBy("created_at", "DESC")
            .limit(query.page_size)
            .offset((query.page - 1) * query.page_size);

        // 执行查询
        const rows = try q.get();
        defer OrmTestCase.freeModels(rows);

        // 查询总数
        var count_q = OrmTestCase.query(self.db);
        defer count_q.deinit();
        _ = count_q.where("project_id", "=", project_id);
        const total = try count_q.count();

        // 转换为实体
        var items = try self.allocator.alloc(TestCase, rows.len);
        errdefer self.allocator.free(items);

        for (rows, 0..) |row, i| {
            items[i] = try self.ormToEntity(row);
        }

        return PageResult(TestCase){
            .items = items,
            .total = @intCast(total),
            .page = query.page,
            .page_size = query.page_size,
        };
    }

    /// 根据模块 ID 分页查询测试用例
    pub fn findByModule(self: *Self, module_id: i32, query: PageQuery) !PageResult(TestCase) {
        // 构建查询
        var q = OrmTestCase.query(self.db);
        defer q.deinit();

        // 参数化查询
        _ = q.where("module_id", "=", module_id)
            .orderBy("created_at", "DESC")
            .limit(query.page_size)
            .offset((query.page - 1) * query.page_size);

        // 执行查询
        const rows = try q.get();
        defer OrmTestCase.freeModels(rows);

        // 查询总数
        var count_q = OrmTestCase.query(self.db);
        defer count_q.deinit();
        _ = count_q.where("module_id", "=", module_id);
        const total = try count_q.count();

        // 转换为实体
        var items = try self.allocator.alloc(TestCase, rows.len);
        errdefer self.allocator.free(items);

        for (rows, 0..) |row, i| {
            items[i] = try self.ormToEntity(row);
        }

        return PageResult(TestCase){
            .items = items,
            .total = @intCast(total),
            .page = query.page,
            .page_size = query.page_size,
        };
    }

    /// 保存测试用例（创建或更新）
    pub fn save(self: *Self, test_case: *TestCase) !void {
        if (test_case.id) |id| {
            // 更新现有记录
            _ = try OrmTestCase.UpdateWith(id, .{
                .title = test_case.title,
                .project_id = test_case.project_id,
                .module_id = test_case.module_id,
                .requirement_id = test_case.requirement_id,
                .priority = test_case.priority.toString(),
                .status = test_case.status.toString(),
                .precondition = test_case.precondition,
                .steps = test_case.steps,
                .expected_result = test_case.expected_result,
                .actual_result = test_case.actual_result,
                .assignee = test_case.assignee,
                .tags = test_case.tags,
                .updated_at = std.time.timestamp(),
            });
        } else {
            // 创建新记录
            const created = try OrmTestCase.Create(.{
                .title = test_case.title,
                .project_id = test_case.project_id,
                .module_id = test_case.module_id,
                .requirement_id = test_case.requirement_id,
                .priority = test_case.priority.toString(),
                .status = test_case.status.toString(),
                .precondition = test_case.precondition,
                .steps = test_case.steps,
                .expected_result = test_case.expected_result,
                .actual_result = test_case.actual_result,
                .assignee = test_case.assignee,
                .tags = test_case.tags,
                .created_by = test_case.created_by,
                .created_at = std.time.timestamp(),
                .updated_at = std.time.timestamp(),
            });
            test_case.id = created.id;
        }
    }

    /// 删除测试用例
    pub fn delete(self: *Self, id: i32) !void {
        _ = self;
        try OrmTestCase.Delete(id);
    }

    /// 批量删除测试用例
    pub fn batchDelete(self: *Self, ids: []const i32) !void {
        if (ids.len == 0) return;
        if (ids.len > 1000) return error.TooManyRecords;

        // 使用 whereIn 批量删除（避免 N+1 查询）
        var q = OrmTestCase.query(self.db);
        defer q.deinit();

        _ = q.whereIn("id", ids);
        try q.delete();
    }

    /// 批量更新测试用例状态
    pub fn batchUpdateStatus(self: *Self, ids: []const i32, status: TestCaseStatus) !void {
        if (ids.len == 0) return;
        if (ids.len > 1000) return error.TooManyRecords;

        // 使用 whereIn 批量更新（避免 N+1 查询）
        var q = OrmTestCase.query(self.db);
        defer q.deinit();

        _ = q.whereIn("id", ids);
        try q.update(.{
            .status = status.toString(),
            .updated_at = std.time.timestamp(),
        });
    }

    /// 批量更新测试用例负责人
    pub fn batchUpdateAssignee(self: *Self, ids: []const i32, assignee: []const u8) !void {
        if (ids.len == 0) return;
        if (ids.len > 1000) return error.TooManyRecords;

        // 使用 whereIn 批量更新（避免 N+1 查询）
        var q = OrmTestCase.query(self.db);
        defer q.deinit();

        _ = q.whereIn("id", ids);
        try q.update(.{
            .assignee = assignee,
            .updated_at = std.time.timestamp(),
        });
    }

    /// 搜索测试用例（支持多条件筛选和分页）
    pub fn search(self: *Self, query: SearchQuery) !PageResult(TestCase) {
        // 构建查询
        var q = OrmTestCase.query(self.db);
        defer q.deinit();

        // 动态添加查询条件（参数化查询）
        if (query.project_id) |project_id| {
            _ = q.where("project_id", "=", project_id);
        }

        if (query.module_id) |module_id| {
            _ = q.where("module_id", "=", module_id);
        }

        if (query.status) |status| {
            _ = q.where("status", "=", status.toString());
        }

        if (query.assignee) |assignee| {
            _ = q.where("assignee", "=", assignee);
        }

        if (query.keyword) |keyword| {
            // 关键字搜索（匹配标题、前置条件、测试步骤、预期结果）
            const pattern = try std.fmt.allocPrint(self.allocator, "%{s}%", .{keyword});
            defer self.allocator.free(pattern);

            _ = q.where("title", "LIKE", pattern)
                .orWhere("precondition", "LIKE", pattern)
                .orWhere("steps", "LIKE", pattern)
                .orWhere("expected_result", "LIKE", pattern);
        }

        // 分页和排序
        _ = q.orderBy("created_at", "DESC")
            .limit(query.page_size)
            .offset((query.page - 1) * query.page_size);

        // 执行查询
        const rows = try q.get();
        defer OrmTestCase.freeModels(rows);

        // 查询总数（使用相同的查询条件）
        var count_q = OrmTestCase.query(self.db);
        defer count_q.deinit();

        if (query.project_id) |project_id| {
            _ = count_q.where("project_id", "=", project_id);
        }
        if (query.module_id) |module_id| {
            _ = count_q.where("module_id", "=", module_id);
        }
        if (query.status) |status| {
            _ = count_q.where("status", "=", status.toString());
        }
        if (query.assignee) |assignee| {
            _ = count_q.where("assignee", "=", assignee);
        }
        if (query.keyword) |keyword| {
            const pattern = try std.fmt.allocPrint(self.allocator, "%{s}%", .{keyword});
            defer self.allocator.free(pattern);

            _ = count_q.where("title", "LIKE", pattern)
                .orWhere("precondition", "LIKE", pattern)
                .orWhere("steps", "LIKE", pattern)
                .orWhere("expected_result", "LIKE", pattern);
        }

        const total = try count_q.count();

        // 转换为实体
        var items = try self.allocator.alloc(TestCase, rows.len);
        errdefer self.allocator.free(items);

        for (rows, 0..) |row, i| {
            items[i] = try self.ormToEntity(row);
        }

        return PageResult(TestCase){
            .items = items,
            .total = @intCast(total),
            .page = query.page,
            .page_size = query.page_size,
        };
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 将 ORM 模型转换为领域实体（深拷贝字符串字段）
    fn ormToEntity(self: *Self, orm: OrmTestCase.Model) !TestCase {
        return TestCase{
            .id = orm.id,
            .title = try self.allocator.dupe(u8, orm.title),
            .project_id = orm.project_id,
            .module_id = orm.module_id,
            .requirement_id = orm.requirement_id,
            .priority = Priority.fromString(orm.priority) orelse .medium,
            .status = TestCaseStatus.fromString(orm.status) orelse .pending,
            .precondition = try self.allocator.dupe(u8, orm.precondition),
            .steps = try self.allocator.dupe(u8, orm.steps),
            .expected_result = try self.allocator.dupe(u8, orm.expected_result),
            .actual_result = try self.allocator.dupe(u8, orm.actual_result),
            .assignee = if (orm.assignee) |a| try self.allocator.dupe(u8, a) else null,
            .tags = try self.allocator.dupe(u8, orm.tags),
            .created_by = try self.allocator.dupe(u8, orm.created_by),
            .created_at = orm.created_at,
            .updated_at = orm.updated_at,
        };
    }

    /// 释放测试用例内存
    pub fn freeTestCase(self: *Self, test_case: TestCase) void {
        self.allocator.free(test_case.title);
        self.allocator.free(test_case.precondition);
        self.allocator.free(test_case.steps);
        self.allocator.free(test_case.expected_result);
        self.allocator.free(test_case.actual_result);
        if (test_case.assignee) |a| self.allocator.free(a);
        self.allocator.free(test_case.tags);
        self.allocator.free(test_case.created_by);
    }

    /// 释放分页结果内存
    pub fn freePageResult(self: *Self, result: PageResult(TestCase)) void {
        for (result.items) |item| {
            self.freeTestCase(item);
        }
        self.allocator.free(result.items);
    }

    // ========================================================================
    // VTable 实现
    // ========================================================================

    pub fn vtable() TestCaseRepository.VTable {
        return .{
            .findById = findByIdImpl,
            .findByProject = findByProjectImpl,
            .findByModule = findByModuleImpl,
            .save = saveImpl,
            .delete = deleteImpl,
            .batchDelete = batchDeleteImpl,
            .batchUpdateStatus = batchUpdateStatusImpl,
            .batchUpdateAssignee = batchUpdateAssigneeImpl,
            .search = searchImpl,
        };
    }

    fn findByIdImpl(ptr: *anyopaque, id: i32) anyerror!?TestCase {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findById(id);
    }

    fn findByProjectImpl(ptr: *anyopaque, project_id: i32, query: PageQuery) anyerror!PageResult(TestCase) {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findByProject(project_id, query);
    }

    fn findByModuleImpl(ptr: *anyopaque, module_id: i32, query: PageQuery) anyerror!PageResult(TestCase) {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findByModule(module_id, query);
    }

    fn saveImpl(ptr: *anyopaque, test_case: *TestCase) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.save(test_case);
    }

    fn deleteImpl(ptr: *anyopaque, id: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.delete(id);
    }

    fn batchDeleteImpl(ptr: *anyopaque, ids: []const i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.batchDelete(ids);
    }

    fn batchUpdateStatusImpl(ptr: *anyopaque, ids: []const i32, status: TestCaseStatus) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.batchUpdateStatus(ids, status);
    }

    fn batchUpdateAssigneeImpl(ptr: *anyopaque, ids: []const i32, assignee: []const u8) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.batchUpdateAssignee(ids, assignee);
    }

    fn searchImpl(ptr: *anyopaque, query: SearchQuery) anyerror!PageResult(TestCase) {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.search(query);
    }
};

/// 创建测试用例仓储实例
pub fn create(allocator: Allocator, db: *sql.Database) !*TestCaseRepository {
    const repo = try allocator.create(MysqlTestCaseRepository);
    errdefer allocator.destroy(repo);

    repo.* = MysqlTestCaseRepository.init(allocator, db);

    const interface = try allocator.create(TestCaseRepository);
    errdefer allocator.destroy(interface);

    interface.* = @import("../../domain/repositories/test_case_repository.zig").create(
        repo,
        &MysqlTestCaseRepository.vtable(),
    );

    return interface;
}
