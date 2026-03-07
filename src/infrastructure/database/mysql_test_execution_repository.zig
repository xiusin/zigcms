//! MySQL 测试执行记录仓储实现
//!
//! 实现测试执行记录仓储接口，使用 ORM QueryBuilder 构建查询，
//! 遵循 ZigCMS 开发范式：参数化查询、内存安全管理。

const std = @import("std");
const Allocator = std.mem.Allocator;
const sql = @import("../../application/services/sql/orm.zig");

// 导入领域层定义
const TestExecution = @import("../../domain/entities/test_execution.model.zig").TestExecution;
const ExecutionStatus = TestExecution.ExecutionStatus;
const TestExecutionRepository = @import("../../domain/repositories/test_execution_repository.zig").TestExecutionRepository;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;
const PageResult = @import("../../domain/repositories/test_case_repository.zig").PageResult;

/// MySQL 测试执行记录仓储实现
pub const MysqlTestExecutionRepository = struct {
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
    const OrmTestExecution = sql.define(struct {
        pub const table_name = "quality_test_executions";
        pub const primary_key = "id";

        id: ?i32 = null,
        test_case_id: i32 = 0,
        executor: []const u8 = "",
        status: []const u8 = "passed",
        actual_result: []const u8 = "",
        remark: []const u8 = "",
        duration_ms: i32 = 0,
        executed_at: i64 = 0,
    });

    /// 根据 ID 查询测试执行记录
    pub fn findById(self: *Self, id: i32) !?TestExecution {
        // 使用 ORM QueryBuilder 构建查询
        var q = OrmTestExecution.query(self.db);
        defer q.deinit();

        // 参数化查询防止 SQL 注入
        _ = q.where("id", "=", id);

        // 执行查询
        const rows = try q.get();
        defer OrmTestExecution.freeModels(rows);

        if (rows.len == 0) return null;

        // 深拷贝字符串字段（防止悬垂指针）
        return try self.ormToEntity(rows[0]);
    }

    /// 根据测试用例 ID 分页查询执行历史
    pub fn findByTestCase(self: *Self, test_case_id: i32, query: PageQuery) !PageResult(TestExecution) {
        // 构建查询
        var q = OrmTestExecution.query(self.db);
        defer q.deinit();

        // 参数化查询，按执行时间倒序排列（最新的在前）
        _ = q.where("test_case_id", "=", test_case_id)
            .orderBy("executed_at", sql.OrderDir.desc)
            .limit(@intCast(query.page_size))
            .offset(@intCast((query.page - 1) * query.page_size));

        // 执行查询
        const rows = try q.get();
        defer OrmTestExecution.freeModels(rows);

        // 查询总数
        var count_q = OrmTestExecution.query(self.db);
        defer count_q.deinit();
        _ = count_q.where("test_case_id", "=", test_case_id);
        const total = try count_q.count();

        // 转换为实体
        var items = try self.allocator.alloc(TestExecution, rows.len);
        errdefer self.allocator.free(items);

        for (rows, 0..) |row, i| {
            items[i] = try self.ormToEntity(row);
        }

        return PageResult(TestExecution){
            .items = items,
            .total = @intCast(total),
            .page = query.page,
            .page_size = query.page_size,
        };
    }

    /// 保存测试执行记录（创建或更新）
    pub fn save(_: *Self, execution: *TestExecution) !void {
        if (execution.id) |id| {
            // 更新现有记录
            _ = try OrmTestExecution.UpdateWith(id, .{
                .test_case_id = execution.test_case_id,
                .executor = execution.executor,
                .status = execution.status.toString(),
                .actual_result = execution.actual_result,
                .remark = execution.remark,
                .duration_ms = execution.duration_ms,
                .executed_at = execution.executed_at,
            });
        } else {
            // 创建新记录
            const created = try OrmTestExecution.Create(.{
                .test_case_id = execution.test_case_id,
                .executor = execution.executor,
                .status = execution.status.toString(),
                .actual_result = execution.actual_result,
                .remark = execution.remark,
                .duration_ms = execution.duration_ms,
                .executed_at = execution.executed_at,
            });
            execution.id = created.id;
        }
    }

    /// 删除测试执行记录
    pub fn delete(self: *Self, id: i32) !void {
        var q = OrmTestExecution.query(self.db);
        defer q.deinit();
        
        _ = q.where("id", "=", id);
        _ = try q.delete();
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 将 ORM 模型转换为领域实体（深拷贝字符串字段）
    fn ormToEntity(self: *Self, orm: OrmTestExecution.Model) !TestExecution {
        return TestExecution{
            .id = orm.id,
            .test_case_id = orm.test_case_id,
            .executor = try self.allocator.dupe(u8, orm.executor),
            .status = ExecutionStatus.fromString(orm.status) orelse .passed,
            .actual_result = try self.allocator.dupe(u8, orm.actual_result),
            .remark = try self.allocator.dupe(u8, orm.remark),
            .duration_ms = orm.duration_ms,
            .executed_at = orm.executed_at,
        };
    }

    /// 释放测试执行记录内存
    pub fn freeTestExecution(self: *Self, execution: TestExecution) void {
        self.allocator.free(execution.executor);
        self.allocator.free(execution.actual_result);
        self.allocator.free(execution.remark);
    }

    /// 释放分页结果内存
    pub fn freePageResult(self: *Self, result: PageResult(TestExecution)) void {
        for (result.items) |item| {
            self.freeTestExecution(item);
        }
        self.allocator.free(result.items);
    }

    // ========================================================================
    // VTable 实现
    // ========================================================================

    pub fn vtable() TestExecutionRepository.VTable {
        return .{
            .findById = findByIdImpl,
            .findByTestCase = findByTestCaseImpl,
            .save = saveImpl,
            .delete = deleteImpl,
        };
    }

    fn findByIdImpl(ptr: *anyopaque, id: i32) anyerror!?TestExecution {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findById(id);
    }

    fn findByTestCaseImpl(ptr: *anyopaque, test_case_id: i32, query: PageQuery) anyerror!PageResult(TestExecution) {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findByTestCase(test_case_id, query);
    }

    fn saveImpl(ptr: *anyopaque, execution: *TestExecution) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.save(execution);
    }

    fn deleteImpl(ptr: *anyopaque, id: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.delete(id);
    }
};

/// 创建测试执行记录仓储实例
pub fn create(allocator: Allocator, db: *sql.Database) !*TestExecutionRepository {
    const repo = try allocator.create(MysqlTestExecutionRepository);
    errdefer allocator.destroy(repo);

    repo.* = MysqlTestExecutionRepository.init(allocator, db);

    const interface = try allocator.create(TestExecutionRepository);
    errdefer allocator.destroy(interface);

    interface.* = @import("../../domain/repositories/test_execution_repository.zig").create(
        repo,
        &MysqlTestExecutionRepository.vtable(),
    );

    return interface;
}
