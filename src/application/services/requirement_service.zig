//! 需求服务
//!
//! 提供需求管理的业务逻辑编排,包括:
//! - 创建、更新、删除需求
//! - 需求状态流转管理
//! - 关联和取消关联测试用例
//! - 计算需求覆盖率
//! - 导入和导出需求
//!
//! ## 设计原则
//!
//! - **职责单一**: Service 只做业务编排,不直接操作数据库
//! - **依赖抽象**: 依赖仓储接口和缓存接口,不依赖具体实现
//! - **内存安全**: 使用 errdefer 确保资源正确释放
//! - **缓存策略**: 查询带缓存,更新/删除清除缓存
//! - **状态流转**: 验证状态流转合法性
//!
//! ## 使用示例
//!
//! ```zig
//! const service = RequirementService.init(
//!     allocator,
//!     requirement_repo,
//!     test_case_repo,
//!     cache,
//! );
//!
//! // 创建需求
//! var requirement = Requirement{
//!     .project_id = 1,
//!     .title = "用户登录功能",
//!     .description = "实现用户登录功能",
//!     .priority = .high,
//!     .created_by = "admin",
//! };
//! try service.create(&requirement);
//!
//! // 更新需求状态
//! try service.updateStatus(requirement.id.?, .reviewed, "admin");
//! ```

const std = @import("std");
const Requirement = @import("../../domain/entities/requirement.model.zig").Requirement;
const RequirementStatus = @import("../../domain/entities/requirement.model.zig").RequirementStatus;
const Priority = @import("../../domain/entities/requirement.model.zig").Priority;
const RequirementRepository = @import("../../domain/repositories/requirement_repository.zig").RequirementRepository;
const TestCaseRepository = @import("../../domain/repositories/test_case_repository.zig").TestCaseRepository;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;
const PageResult = @import("../../domain/repositories/test_case_repository.zig").PageResult;
const CacheInterface = @import("../../infrastructure/cache/contract.zig").CacheInterface;
const qc_cache = @import("../../infrastructure/cache/quality_center_cache.zig");

const Allocator = std.mem.Allocator;

/// 状态变更历史记录
pub const StatusChangeHistory = struct {
    timestamp: i64,
    operator: []const u8,
    old_status: RequirementStatus,
    new_status: RequirementStatus,
};

/// 需求服务
///
/// 负责需求管理的业务逻辑编排,遵循整洁架构原则。
pub const RequirementService = struct {
    allocator: Allocator,
    requirement_repo: RequirementRepository,
    test_case_repo: TestCaseRepository,
    cache: CacheInterface,

    const Self = @This();

    /// 初始化需求服务
    ///
    /// 参数:
    /// - allocator: 内存分配器
    /// - requirement_repo: 需求仓储接口
    /// - test_case_repo: 测试用例仓储接口
    /// - cache: 缓存接口
    ///
    /// 返回:
    /// - RequirementService 实例
    pub fn init(
        allocator: Allocator,
        requirement_repo: RequirementRepository,
        test_case_repo: TestCaseRepository,
        cache: CacheInterface,
    ) Self {
        return .{
            .allocator = allocator,
            .requirement_repo = requirement_repo,
            .test_case_repo = test_case_repo,
            .cache = cache,
        };
    }

    // ========================================
    // 创建、更新、删除操作
    // ========================================

    /// 创建需求
    ///
    /// 验证必填字段后创建需求,并清除相关缓存。
    ///
    /// 参数:
    /// - requirement: 需求对象指针
    ///
    /// 错误:
    /// - TitleRequired: 需求标题为空
    /// - ProjectIdRequired: 项目 ID 为 0
    /// - DescriptionRequired: 需求描述为空
    ///
    /// 需求: 5.1, 5.2
    pub fn create(self: *Self, requirement: *Requirement) !void {
        // 1. 验证必填字段
        if (requirement.title.len == 0) return error.TitleRequired;
        if (requirement.project_id == 0) return error.ProjectIdRequired;
        if (requirement.description.len == 0) return error.DescriptionRequired;

        // 2. 设置创建时间
        if (requirement.created_at == null) {
            requirement.created_at = std.time.timestamp();
        }
        requirement.updated_at = requirement.created_at;

        // 3. 保存到数据库
        try self.requirement_repo.save(requirement);

        // 4. 清除相关缓存
        try self.clearRequirementCache(requirement.project_id);
    }

    /// 更新需求
    ///
    /// 查询需求,更新字段后保存,并清除相关缓存。
    ///
    /// 参数:
    /// - id: 需求 ID
    /// - requirement: 包含更新字段的需求对象
    ///
    /// 错误:
    /// - RequirementNotFound: 需求不存在
    /// - TitleRequired: 需求标题为空
    /// - DescriptionRequired: 需求描述为空
    ///
    /// 需求: 5.2
    pub fn update(self: *Self, id: i32, requirement: *const Requirement) !void {
        // 1. 查询现有需求
        const existing = try self.requirement_repo.findById(id) orelse {
            return error.RequirementNotFound;
        };
        defer self.freeRequirement(existing);

        // 2. 验证更新后的数据
        if (requirement.title.len == 0) return error.TitleRequired;
        if (requirement.description.len == 0) return error.DescriptionRequired;

        // 3. 创建更新后的需求
        var updated = requirement.*;
        updated.id = id;
        updated.updated_at = std.time.timestamp();

        // 4. 保存到数据库
        try self.requirement_repo.save(&updated);

        // 5. 清除相关缓存
        try self.clearRequirementCache(existing.project_id);
    }

    /// 删除需求
    ///
    /// 删除需求并清除相关缓存。
    ///
    /// 参数:
    /// - id: 需求 ID
    ///
    /// 需求: 5.1
    pub fn delete(self: *Self, id: i32) !void {
        // 1. 查询需求获取项目 ID(用于清除缓存)
        const requirement = try self.requirement_repo.findById(id) orelse {
            return error.RequirementNotFound;
        };
        defer self.freeRequirement(requirement);

        const project_id = requirement.project_id;

        // 2. 删除需求
        try self.requirement_repo.delete(id);

        // 3. 清除相关缓存
        try self.clearRequirementCache(project_id);
    }

    // ========================================
    // 状态流转
    // ========================================

    /// 更新需求状态
    ///
    /// 验证状态流转合法性后更新状态,并记录变更历史。
    ///
    /// 参数:
    /// - id: 需求 ID
    /// - new_status: 新状态
    /// - operator: 操作人
    ///
    /// 错误:
    /// - RequirementNotFound: 需求不存在
    /// - InvalidStatusTransition: 非法的状态流转
    ///
    /// 需求: 5.4, 5.5
    pub fn updateStatus(self: *Self, id: i32, new_status: RequirementStatus, operator: []const u8) !void {
        // 1. 查询需求
        const requirement = try self.requirement_repo.findById(id) orelse {
            return error.RequirementNotFound;
        };
        defer self.freeRequirement(requirement);

        // 2. 验证状态流转合法性
        if (!self.isValidStatusTransition(requirement.status, new_status)) {
            return error.InvalidStatusTransition;
        }

        // 3. 记录状态变更历史
        const history = StatusChangeHistory{
            .timestamp = std.time.timestamp(),
            .operator = operator,
            .old_status = requirement.status,
            .new_status = new_status,
        };
        _ = history; // TODO: 保存历史记录到数据库

        // 4. 更新需求状态
        var updated = requirement;
        updated.status = new_status;
        updated.updated_at = std.time.timestamp();

        try self.requirement_repo.save(&updated);

        // 5. 清除相关缓存
        try self.clearRequirementCache(requirement.project_id);
    }

    /// 验证状态流转合法性
    ///
    /// 状态流转规则:
    /// - pending → reviewed
    /// - reviewed → developing
    /// - developing → testing
    /// - testing → in_test
    /// - in_test → completed
    /// - completed → closed
    /// - 任何状态 → closed(允许直接关闭)
    fn isValidStatusTransition(self: *Self, old_status: RequirementStatus, new_status: RequirementStatus) bool {
        _ = self;

        // 允许直接关闭
        if (new_status == .closed) {
            return true;
        }

        // 不允许状态回退
        const old_order = @intFromEnum(old_status);
        const new_order = @intFromEnum(new_status);
        if (new_order <= old_order) {
            return false;
        }

        // 只允许相邻状态流转
        return new_order == old_order + 1;
    }

    // ========================================
    // 关联测试用例
    // ========================================

    /// 关联测试用例
    ///
    /// 将测试用例关联到需求,并更新覆盖率。
    ///
    /// 参数:
    /// - requirement_id: 需求 ID
    /// - test_case_id: 测试用例 ID
    ///
    /// 需求: 5.7, 5.8
    pub fn linkTestCase(self: *Self, requirement_id: i32, test_case_id: i32) !void {
        // 1. 关联测试用例
        try self.requirement_repo.linkTestCase(requirement_id, test_case_id);

        // 2. 更新覆盖率
        try self.updateCoverage(requirement_id);

        // 3. 清除相关缓存
        const requirement = try self.requirement_repo.findById(requirement_id) orelse {
            return error.RequirementNotFound;
        };
        defer self.freeRequirement(requirement);

        try self.clearRequirementCache(requirement.project_id);
    }

    /// 取消关联测试用例
    ///
    /// 取消测试用例与需求的关联,并更新覆盖率。
    ///
    /// 参数:
    /// - requirement_id: 需求 ID
    /// - test_case_id: 测试用例 ID
    ///
    /// 需求: 5.8
    pub fn unlinkTestCase(self: *Self, requirement_id: i32, test_case_id: i32) !void {
        // 1. 取消关联测试用例
        try self.requirement_repo.unlinkTestCase(requirement_id, test_case_id);

        // 2. 更新覆盖率
        try self.updateCoverage(requirement_id);

        // 3. 清除相关缓存
        const requirement = try self.requirement_repo.findById(requirement_id) orelse {
            return error.RequirementNotFound;
        };
        defer self.freeRequirement(requirement);

        try self.clearRequirementCache(requirement.project_id);
    }

    // ========================================
    // 覆盖率计算
    // ========================================

    /// 计算需求覆盖率
    ///
    /// 覆盖率 = 实际测试用例数 / 建议测试用例数
    ///
    /// 参数:
    /// - requirement_id: 需求 ID
    ///
    /// 返回:
    /// - 覆盖率(0.0 - 1.0)
    ///
    /// 需求: 5.6
    pub fn calculateCoverage(self: *Self, requirement_id: i32) !f32 {
        // 1. 查询需求
        const requirement = try self.requirement_repo.findById(requirement_id) orelse {
            return error.RequirementNotFound;
        };
        defer self.freeRequirement(requirement);

        // 2. 计算覆盖率
        if (requirement.estimated_cases == 0) {
            return 0.0;
        }

        return @as(f32, @floatFromInt(requirement.actual_cases)) / @as(f32, @floatFromInt(requirement.estimated_cases));
    }

    /// 更新需求覆盖率
    fn updateCoverage(self: *Self, requirement_id: i32) !void {
        // 1. 查询需求
        const requirement = try self.requirement_repo.findById(requirement_id) orelse {
            return error.RequirementNotFound;
        };
        defer self.freeRequirement(requirement);

        // 2. 查询关联的测试用例数量
        // TODO: 实现查询关联测试用例数量的逻辑
        const actual_cases: i32 = 0;

        // 3. 计算覆盖率
        const coverage_rate = if (requirement.estimated_cases > 0)
            @as(f32, @floatFromInt(actual_cases)) / @as(f32, @floatFromInt(requirement.estimated_cases))
        else
            0.0;

        // 4. 更新需求
        var updated = requirement;
        updated.actual_cases = actual_cases;
        updated.coverage_rate = coverage_rate;
        updated.updated_at = std.time.timestamp();

        try self.requirement_repo.save(&updated);
    }

    // ========================================
    // 导入和导出
    // ========================================

    /// 从 Excel 导入需求
    ///
    /// 参数:
    /// - project_id: 项目 ID
    /// - file_path: Excel 文件路径
    ///
    /// 返回:
    /// - 导入的需求数量
    ///
    /// 需求: 5.10
    pub fn importFromExcel(self: *Self, project_id: i32, file_path: []const u8) !i32 {
        _ = self;
        _ = project_id;
        _ = file_path;
        // TODO: 实现 Excel 导入逻辑
        return 0;
    }

    /// 导出需求到 Excel
    ///
    /// 参数:
    /// - project_id: 项目 ID
    /// - file_path: Excel 文件路径
    ///
    /// 返回:
    /// - 导出的需求数量
    ///
    /// 需求: 5.10
    pub fn exportToExcel(self: *Self, project_id: i32, file_path: []const u8) !i32 {
        _ = self;
        _ = project_id;
        _ = file_path;
        // TODO: 实现 Excel 导出逻辑
        return 0;
    }

    // ========================================
    // 查询操作
    // ========================================

    /// 根据 ID 查询需求
    ///
    /// 参数:
    /// - id: 需求 ID
    ///
    /// 返回:
    /// - 需求对象(调用者拥有所有权,必须调用 freeRequirement 释放)
    /// - null(如果不存在)
    ///
    /// 需求: 5.1
    pub fn findById(self: *Self, id: i32) !?Requirement {
        return try self.requirement_repo.findById(id);
    }

    /// 根据项目 ID 分页查询需求
    ///
    /// 参数:
    /// - project_id: 项目 ID
    /// - query: 分页查询参数
    ///
    /// 返回:
    /// - 分页结果(调用者拥有所有权,必须调用 freePageResult 释放)
    ///
    /// 需求: 5.9
    pub fn findByProject(self: *Self, project_id: i32, query: PageQuery) !PageResult(Requirement) {
        return try self.requirement_repo.findByProject(project_id, query);
    }

    // ========================================
    // 缓存管理
    // ========================================

    /// 清除需求相关缓存
    fn clearRequirementCache(self: *Self, project_id: i32) !void {
        // 清除项目需求列表缓存
        const prefix = try std.fmt.allocPrint(
            self.allocator,
            "quality:requirement:project:{d}:",
            .{project_id},
        );
        defer self.allocator.free(prefix);
        try self.cache.delByPrefix(prefix);

        // 清除所有需求相关缓存
        try self.cache.delByPrefix("quality:requirement:");
    }

    // ========================================
    // 内存管理
    // ========================================

    /// 释放需求对象
    ///
    /// 释放需求对象中所有字符串字段的内存。
    ///
    /// 参数:
    /// - requirement: 需求对象
    pub fn freeRequirement(self: *Self, requirement: Requirement) void {
        if (requirement.title.len > 0) self.allocator.free(requirement.title);
        if (requirement.description.len > 0) self.allocator.free(requirement.description);
        if (requirement.assignee) |assignee| {
            if (assignee.len > 0) self.allocator.free(assignee);
        }
        if (requirement.created_by.len > 0) self.allocator.free(requirement.created_by);
    }

    /// 释放分页结果
    ///
    /// 释放分页结果中所有需求对象的内存。
    ///
    /// 参数:
    /// - result: 分页结果
    pub fn freePageResult(self: *Self, result: PageResult(Requirement)) void {
        for (result.items) |requirement| {
            self.freeRequirement(requirement);
        }
        self.allocator.free(result.items);
    }
};
