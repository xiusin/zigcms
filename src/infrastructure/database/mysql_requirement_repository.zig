//! MySQL 需求仓储实现
//!
//! 实现需求仓储接口，使用 ORM QueryBuilder 构建查询，
//! 遵循 ZigCMS 开发范式：参数化查询、关系预加载、内存安全管理。

const std = @import("std");
const Allocator = std.mem.Allocator;
const sql = @import("../../application/services/sql/orm.zig");

// 导入领域层定义
const Requirement = @import("../../domain/entities/requirement.model.zig").Requirement;
const Priority = Requirement.Priority;
const RequirementStatus = Requirement.RequirementStatus;
const RequirementRepository = @import("../../domain/repositories/requirement_repository.zig").RequirementRepository;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;
const PageResult = @import("../../domain/repositories/test_case_repository.zig").PageResult;

/// MySQL 需求仓储实现
pub const MysqlRequirementRepository = struct {
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
    const OrmRequirement = sql.define(struct {
        pub const table_name = "quality_requirements";
        pub const primary_key = "id";

        id: ?i32 = null,
        project_id: i32 = 0,
        title: []const u8 = "",
        description: []const u8 = "",
        priority: []const u8 = "medium",
        status: []const u8 = "pending",
        assignee: ?[]const u8 = null,
        estimated_cases: i32 = 0,
        actual_cases: i32 = 0,
        coverage_rate: f32 = 0.0,
        created_by: []const u8 = "",
        created_at: ?i64 = null,
        updated_at: ?i64 = null,
    });

    /// 定义测试用例 ORM 模型（用于关联操作）
    const OrmTestCase = sql.define(struct {
        pub const table_name = "quality_test_cases";
        pub const primary_key = "id";

        id: ?i32 = null,
        requirement_id: ?i32 = null,
    });

    /// 根据 ID 查询需求
    pub fn findById(self: *Self, id: i32) !?Requirement {
        // 使用 ORM QueryBuilder 构建查询
        var q = OrmRequirement.query(self.db);
        defer q.deinit();

        // 参数化查询防止 SQL 注入
        _ = q.where("id", "=", id);

        // 可选：使用关系预加载优化查询（避免 N+1 查询）
        // _ = q.with(&.{"test_cases"});

        // 执行查询
        const rows = try q.get();
        defer OrmRequirement.freeModels(rows);

        if (rows.len == 0) return null;

        // 深拷贝字符串字段（防止悬垂指针）
        return try self.ormToEntity(rows[0]);
    }

    /// 根据项目 ID 分页查询需求
    pub fn findByProject(self: *Self, project_id: i32, query: PageQuery) !PageResult(Requirement) {
        // 构建查询
        var q = OrmRequirement.query(self.db);
        defer q.deinit();

        // 参数化查询，按创建时间倒序排列（最新的在前）
        _ = q.where("project_id", "=", project_id)
            .orderBy("created_at", sql.OrderDir.desc)
            .limit(@intCast(query.page_size))
            .offset(@intCast((query.page - 1) * query.page_size));

        // 执行查询
        const rows = try q.get();
        defer OrmRequirement.freeModels(rows);

        // 查询总数
        var count_q = OrmRequirement.query(self.db);
        defer count_q.deinit();
        _ = count_q.where("project_id", "=", project_id);
        const total = try count_q.count();

        // 转换为实体
        var items = try self.allocator.alloc(Requirement, rows.len);
        errdefer self.allocator.free(items);

        for (rows, 0..) |row, i| {
            items[i] = try self.ormToEntity(row);
        }

        return PageResult(Requirement){
            .items = items,
            .total = @intCast(total),
            .page = query.page,
            .page_size = query.page_size,
        };
    }

    /// 保存需求（创建或更新）
    pub fn save(_: *Self, requirement: *Requirement) !void {
        if (requirement.id) |id| {
            // 更新现有记录
            _ = try OrmRequirement.UpdateWith(id, .{
                .project_id = requirement.project_id,
                .title = requirement.title,
                .description = requirement.description,
                .priority = requirement.priority.toString(),
                .status = requirement.status.toString(),
                .assignee = requirement.assignee,
                .estimated_cases = requirement.estimated_cases,
                .actual_cases = requirement.actual_cases,
                .coverage_rate = requirement.coverage_rate,
                .updated_at = std.time.timestamp(),
            });
        } else {
            // 创建新记录
            const created = try OrmRequirement.Create(.{
                .project_id = requirement.project_id,
                .title = requirement.title,
                .description = requirement.description,
                .priority = requirement.priority.toString(),
                .status = requirement.status.toString(),
                .assignee = requirement.assignee,
                .estimated_cases = requirement.estimated_cases,
                .actual_cases = requirement.actual_cases,
                .coverage_rate = requirement.coverage_rate,
                .created_by = requirement.created_by,
                .created_at = std.time.timestamp(),
                .updated_at = std.time.timestamp(),
            });
            requirement.id = created.id;
        }
    }

    /// 删除需求
    pub fn delete(self: *Self, id: i32) !void {
        // 1. 先取消所有关联的测试用例
        var q = OrmTestCase.query(self.db);
        defer q.deinit();

        _ = q.where("requirement_id", "=", id);
        _ = try q.update(.{
            .requirement_id = null,
        });

        // 2. 删除需求
        var del_q = OrmRequirement.query(self.db);
        defer del_q.deinit();
        
        _ = del_q.where("id", "=", id);
        _ = try del_q.delete();
    }

    /// 关联测试用例
    pub fn linkTestCase(self: *Self, requirement_id: i32, test_case_id: i32) !void {
        // 1. 更新测试用例的 requirement_id
        _ = try OrmTestCase.UpdateWith(test_case_id, .{
            .requirement_id = requirement_id,
        });

        // 2. 更新需求的 actual_cases 和 coverage_rate
        try self.updateCoverage(requirement_id);
    }

    /// 取消关联测试用例
    pub fn unlinkTestCase(self: *Self, requirement_id: i32, test_case_id: i32) !void {
        // 1. 清空测试用例的 requirement_id
        _ = try OrmTestCase.UpdateWith(test_case_id, .{
            .requirement_id = null,
        });

        // 2. 更新需求的 actual_cases 和 coverage_rate
        try self.updateCoverage(requirement_id);
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 更新需求的覆盖率
    fn updateCoverage(self: *Self, requirement_id: i32) !void {
        // 1. 查询需求
        const requirement = try self.findById(requirement_id) orelse return error.RequirementNotFound;
        defer self.freeRequirement(requirement);

        // 2. 查询关联的测试用例数量
        var q = OrmTestCase.query(self.db);
        defer q.deinit();
        _ = q.where("requirement_id", "=", requirement_id);
        const actual_cases = try q.count();

        // 3. 计算覆盖率
        var coverage_rate: f32 = 0.0;
        if (requirement.estimated_cases > 0) {
            coverage_rate = @as(f32, @floatFromInt(actual_cases)) / @as(f32, @floatFromInt(requirement.estimated_cases)) * 100.0;
        }

        // 4. 更新需求
        _ = try OrmRequirement.UpdateWith(requirement_id, .{
            .actual_cases = @as(i32, @intCast(actual_cases)),
            .coverage_rate = coverage_rate,
            .updated_at = std.time.timestamp(),
        });
    }

    /// 将 ORM 模型转换为领域实体（深拷贝字符串字段）
    fn ormToEntity(self: *Self, orm: OrmRequirement.Model) !Requirement {
        return Requirement{
            .id = orm.id,
            .project_id = orm.project_id,
            .title = try self.allocator.dupe(u8, orm.title),
            .description = try self.allocator.dupe(u8, orm.description),
            .priority = Priority.fromString(orm.priority) orelse .medium,
            .status = RequirementStatus.fromString(orm.status) orelse .pending,
            .assignee = if (orm.assignee) |a| try self.allocator.dupe(u8, a) else null,
            .estimated_cases = orm.estimated_cases,
            .actual_cases = orm.actual_cases,
            .coverage_rate = orm.coverage_rate,
            .created_by = try self.allocator.dupe(u8, orm.created_by),
            .created_at = orm.created_at,
            .updated_at = orm.updated_at,
        };
    }

    /// 释放需求内存
    pub fn freeRequirement(self: *Self, requirement: Requirement) void {
        self.allocator.free(requirement.title);
        self.allocator.free(requirement.description);
        if (requirement.assignee) |a| self.allocator.free(a);
        self.allocator.free(requirement.created_by);
    }

    /// 释放分页结果内存
    pub fn freePageResult(self: *Self, result: PageResult(Requirement)) void {
        for (result.items) |item| {
            self.freeRequirement(item);
        }
        self.allocator.free(result.items);
    }

    // ========================================================================
    // VTable 实现
    // ========================================================================

    pub fn vtable() RequirementRepository.VTable {
        return .{
            .findById = findByIdImpl,
            .findByProject = findByProjectImpl,
            .save = saveImpl,
            .delete = deleteImpl,
            .linkTestCase = linkTestCaseImpl,
            .unlinkTestCase = unlinkTestCaseImpl,
        };
    }

    fn findByIdImpl(ptr: *anyopaque, id: i32) anyerror!?Requirement {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findById(id);
    }

    fn findByProjectImpl(ptr: *anyopaque, project_id: i32, query: PageQuery) anyerror!PageResult(Requirement) {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findByProject(project_id, query);
    }

    fn saveImpl(ptr: *anyopaque, requirement: *Requirement) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.save(requirement);
    }

    fn deleteImpl(ptr: *anyopaque, id: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.delete(id);
    }

    fn linkTestCaseImpl(ptr: *anyopaque, requirement_id: i32, test_case_id: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.linkTestCase(requirement_id, test_case_id);
    }

    fn unlinkTestCaseImpl(ptr: *anyopaque, requirement_id: i32, test_case_id: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.unlinkTestCase(requirement_id, test_case_id);
    }
};

/// 创建需求仓储实例
pub fn create(allocator: Allocator, db: *sql.Database) !*RequirementRepository {
    const repo = try allocator.create(MysqlRequirementRepository);
    errdefer allocator.destroy(repo);

    repo.* = MysqlRequirementRepository.init(allocator, db);

    const interface = try allocator.create(RequirementRepository);
    errdefer allocator.destroy(interface);

    interface.* = @import("../../domain/repositories/requirement_repository.zig").create(
        repo,
        &MysqlRequirementRepository.vtable(),
    );

    return interface;
}
