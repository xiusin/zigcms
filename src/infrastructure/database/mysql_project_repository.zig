//! MySQL 项目仓储实现
//!
//! 实现项目仓储接口，使用 ORM QueryBuilder 构建查询，
//! 遵循 ZigCMS 开发范式：参数化查询、关系预加载、内存安全管理。

const std = @import("std");
const Allocator = std.mem.Allocator;
const sql = @import("../../application/services/sql/orm.zig");

// 导入领域层定义
const Project = @import("../../domain/entities/project.model.zig").Project;
const ProjectStatus = Project.ProjectStatus;
const ProjectRepository = @import("../../domain/repositories/project_repository.zig").ProjectRepository;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;
const PageResult = @import("../../domain/repositories/test_case_repository.zig").PageResult;

/// MySQL 项目仓储实现
pub const MysqlProjectRepository = struct {
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
    const OrmProject = sql.define(struct {
        pub const table_name = "quality_projects";
        pub const primary_key = "id";

        id: ?i32 = null,
        name: []const u8 = "",
        description: []const u8 = "",
        status: []const u8 = "active",
        owner: []const u8 = "",
        members: []const u8 = "",
        settings: []const u8 = "",
        archived: i32 = 0,
        created_by: []const u8 = "",
        created_at: ?i64 = null,
        updated_at: ?i64 = null,
    });

    /// 根据 ID 查询项目
    pub fn findById(self: *Self, id: i32) !?Project {
        // 使用 ORM QueryBuilder 构建查询
        var q = OrmProject.query(self.db);
        defer q.deinit();

        // 参数化查询防止 SQL 注入
        _ = q.where("id", "=", id);

        // 可选：使用关系预加载优化查询（避免 N+1 查询）
        // _ = q.with(&.{"modules", "test_cases", "requirements"});

        // 执行查询
        const rows = try q.get();
        defer OrmProject.freeModels(rows);

        if (rows.len == 0) return null;

        // 深拷贝字符串字段（防止悬垂指针）
        return try self.ormToEntity(rows[0]);
    }

    /// 查询所有项目（支持分页）
    pub fn findAll(self: *Self, query: PageQuery) !PageResult(Project) {
        // 构建查询
        var q = OrmProject.query(self.db);
        defer q.deinit();

        // 默认不包含归档项目
        _ = q.where("archived", "=", 0)
            .orderBy("created_at", sql.OrderDir.desc)
            .limit(@intCast(query.page_size))
            .offset(@intCast((query.page - 1) * query.page_size));

        // 执行查询
        const rows = try q.get();
        defer OrmProject.freeModels(rows);

        // 查询总数
        var count_q = OrmProject.query(self.db);
        defer count_q.deinit();
        _ = count_q.where("archived", "=", 0);
        const total = try count_q.count();

        // 转换为实体
        var items = try self.allocator.alloc(Project, rows.len);
        errdefer self.allocator.free(items);

        for (rows, 0..) |row, i| {
            items[i] = try self.ormToEntity(row);
        }

        return PageResult(Project){
            .items = items,
            .total = @intCast(total),
            .page = query.page,
            .page_size = query.page_size,
        };
    }

    /// 保存项目（创建或更新）
    pub fn save(_: *Self, project: *Project) !void {
        if (project.id) |id| {
            // 更新现有记录
            _ = try OrmProject.UpdateWith(id, .{
                .name = project.name,
                .description = project.description,
                .status = project.status.toString(),
                .owner = project.owner,
                .members = project.members,
                .settings = project.settings,
                .archived = if (project.archived) @as(i32, 1) else @as(i32, 0),
                .updated_at = std.time.timestamp(),
            });
        } else {
            // 创建新记录
            const created = try OrmProject.Create(.{
                .name = project.name,
                .description = project.description,
                .status = project.status.toString(),
                .owner = project.owner,
                .members = project.members,
                .settings = project.settings,
                .archived = if (project.archived) @as(i32, 1) else @as(i32, 0),
                .created_by = project.created_by,
                .created_at = std.time.timestamp(),
                .updated_at = std.time.timestamp(),
            });
            project.id = created.id;
        }
    }

    /// 删除项目
    pub fn delete(self: *Self, id: i32) !void {
        var q = OrmProject.query(self.db);
        defer q.deinit();
        
        _ = q.where("id", "=", id);
        _ = try q.delete();
    }

    /// 归档项目
    pub fn archive(_: *Self, id: i32) !void {
        _ = try OrmProject.UpdateWith(id, .{
            .archived = @as(i32, 1),
            .status = "archived",
            .updated_at = std.time.timestamp(),
        });
    }

    /// 恢复项目
    pub fn restore(_: *Self, id: i32) !void {
        _ = try OrmProject.UpdateWith(id, .{
            .archived = @as(i32, 0),
            .status = "active",
            .updated_at = std.time.timestamp(),
        });
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 将 ORM 模型转换为领域实体（深拷贝字符串字段）
    fn ormToEntity(self: *Self, orm: OrmProject.Model) !Project {
        return Project{
            .id = orm.id,
            .name = try self.allocator.dupe(u8, orm.name),
            .description = try self.allocator.dupe(u8, orm.description),
            .status = ProjectStatus.fromString(orm.status) orelse .active,
            .owner = try self.allocator.dupe(u8, orm.owner),
            .members = try self.allocator.dupe(u8, orm.members),
            .settings = try self.allocator.dupe(u8, orm.settings),
            .archived = orm.archived != 0,
            .created_by = try self.allocator.dupe(u8, orm.created_by),
            .created_at = orm.created_at,
            .updated_at = orm.updated_at,
        };
    }

    /// 释放项目内存
    pub fn freeProject(self: *Self, project: Project) void {
        self.allocator.free(project.name);
        self.allocator.free(project.description);
        self.allocator.free(project.owner);
        self.allocator.free(project.members);
        self.allocator.free(project.settings);
        self.allocator.free(project.created_by);
    }

    /// 释放分页结果内存
    pub fn freePageResult(self: *Self, result: PageResult(Project)) void {
        for (result.items) |item| {
            self.freeProject(item);
        }
        self.allocator.free(result.items);
    }

    // ========================================================================
    // VTable 实现
    // ========================================================================

    pub fn vtable() ProjectRepository.VTable {
        return .{
            .findById = findByIdImpl,
            .findAll = findAllImpl,
            .save = saveImpl,
            .delete = deleteImpl,
            .archive = archiveImpl,
            .restore = restoreImpl,
        };
    }

    fn findByIdImpl(ptr: *anyopaque, id: i32) anyerror!?Project {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findById(id);
    }

    fn findAllImpl(ptr: *anyopaque, query: PageQuery) anyerror!PageResult(Project) {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findAll(query);
    }

    fn saveImpl(ptr: *anyopaque, project: *Project) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.save(project);
    }

    fn deleteImpl(ptr: *anyopaque, id: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.delete(id);
    }

    fn archiveImpl(ptr: *anyopaque, id: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.archive(id);
    }

    fn restoreImpl(ptr: *anyopaque, id: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.restore(id);
    }
};

/// 创建项目仓储实例
pub fn create(allocator: Allocator, db: *sql.Database) !*ProjectRepository {
    const repo = try allocator.create(MysqlProjectRepository);
    errdefer allocator.destroy(repo);

    repo.* = MysqlProjectRepository.init(allocator, db);

    const interface = try allocator.create(ProjectRepository);
    errdefer allocator.destroy(interface);

    interface.* = @import("../../domain/repositories/project_repository.zig").create(
        repo,
        &MysqlProjectRepository.vtable(),
    );

    return interface;
}
