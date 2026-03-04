const std = @import("std");
const TestCase = @import("../entities/test_case.model.zig").TestCase;
const TestCaseStatus = @import("../entities/test_case.model.zig").TestCaseStatus;

/// 分页查询参数
pub const PageQuery = struct {
    page: i32 = 1,
    page_size: i32 = 20,
};

/// 搜索查询参数
pub const SearchQuery = struct {
    project_id: ?i32 = null,
    module_id: ?i32 = null,
    status: ?TestCaseStatus = null,
    assignee: ?[]const u8 = null,
    keyword: ?[]const u8 = null,
    page: i32 = 1,
    page_size: i32 = 20,
};

/// 分页结果
pub fn PageResult(comptime T: type) type {
    return struct {
        items: []T,
        total: i32,
        page: i32,
        page_size: i32,
    };
}

/// 测试用例仓储接口
/// 使用 VTable 模式实现接口抽象,遵循 ZigCMS 整洁架构规范
pub const TestCaseRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();

    /// 虚函数表定义
    pub const VTable = struct {
        /// 根据 ID 查询测试用例
        findById: *const fn (*anyopaque, i32) anyerror!?TestCase,

        /// 根据项目 ID 分页查询测试用例
        findByProject: *const fn (*anyopaque, i32, PageQuery) anyerror!PageResult(TestCase),

        /// 根据模块 ID 分页查询测试用例
        findByModule: *const fn (*anyopaque, i32, PageQuery) anyerror!PageResult(TestCase),

        /// 保存测试用例(创建或更新)
        save: *const fn (*anyopaque, *TestCase) anyerror!void,

        /// 删除测试用例
        delete: *const fn (*anyopaque, i32) anyerror!void,

        /// 批量删除测试用例
        batchDelete: *const fn (*anyopaque, []const i32) anyerror!void,

        /// 批量更新测试用例状态
        batchUpdateStatus: *const fn (*anyopaque, []const i32, TestCaseStatus) anyerror!void,

        /// 批量更新测试用例负责人
        batchUpdateAssignee: *const fn (*anyopaque, []const i32, []const u8) anyerror!void,

        /// 搜索测试用例(支持多条件筛选和分页)
        search: *const fn (*anyopaque, SearchQuery) anyerror!PageResult(TestCase),
    };

    /// 根据 ID 查询测试用例
    /// 参数:
    ///   - id: 测试用例 ID
    /// 返回:
    ///   - ?TestCase: 测试用例对象,如果不存在则返回 null
    pub fn findById(self: *Self, id: i32) !?TestCase {
        return self.vtable.findById(self.ptr, id);
    }

    /// 根据项目 ID 分页查询测试用例
    /// 参数:
    ///   - project_id: 项目 ID
    ///   - query: 分页查询参数
    /// 返回:
    ///   - PageResult(TestCase): 分页结果
    pub fn findByProject(self: *Self, project_id: i32, query: PageQuery) !PageResult(TestCase) {
        return self.vtable.findByProject(self.ptr, project_id, query);
    }

    /// 根据模块 ID 分页查询测试用例
    /// 参数:
    ///   - module_id: 模块 ID
    ///   - query: 分页查询参数
    /// 返回:
    ///   - PageResult(TestCase): 分页结果
    pub fn findByModule(self: *Self, module_id: i32, query: PageQuery) !PageResult(TestCase) {
        return self.vtable.findByModule(self.ptr, module_id, query);
    }

    /// 保存测试用例(创建或更新)
    /// 参数:
    ///   - test_case: 测试用例对象指针
    /// 说明:
    ///   - 如果 test_case.id 为 null,则创建新记录并设置 id
    ///   - 如果 test_case.id 不为 null,则更新现有记录
    pub fn save(self: *Self, test_case: *TestCase) !void {
        return self.vtable.save(self.ptr, test_case);
    }

    /// 删除测试用例
    /// 参数:
    ///   - id: 测试用例 ID
    pub fn delete(self: *Self, id: i32) !void {
        return self.vtable.delete(self.ptr, id);
    }

    /// 批量删除测试用例
    /// 参数:
    ///   - ids: 测试用例 ID 数组
    /// 说明:
    ///   - 最多支持 1000 条记录
    ///   - 使用事务确保原子性
    pub fn batchDelete(self: *Self, ids: []const i32) !void {
        return self.vtable.batchDelete(self.ptr, ids);
    }

    /// 批量更新测试用例状态
    /// 参数:
    ///   - ids: 测试用例 ID 数组
    ///   - status: 目标状态
    /// 说明:
    ///   - 最多支持 1000 条记录
    ///   - 使用事务确保原子性
    pub fn batchUpdateStatus(self: *Self, ids: []const i32, status: TestCaseStatus) !void {
        return self.vtable.batchUpdateStatus(self.ptr, ids, status);
    }

    /// 批量更新测试用例负责人
    /// 参数:
    ///   - ids: 测试用例 ID 数组
    ///   - assignee: 负责人用户名
    /// 说明:
    ///   - 最多支持 1000 条记录
    ///   - 使用事务确保原子性
    pub fn batchUpdateAssignee(self: *Self, ids: []const i32, assignee: []const u8) !void {
        return self.vtable.batchUpdateAssignee(self.ptr, ids, assignee);
    }

    /// 搜索测试用例(支持多条件筛选和分页)
    /// 参数:
    ///   - query: 搜索查询参数
    /// 返回:
    ///   - PageResult(TestCase): 分页结果
    /// 说明:
    ///   - 支持按项目、模块、状态、负责人、关键字筛选
    ///   - 关键字搜索匹配标题、前置条件、测试步骤、预期结果
    ///   - 使用参数化查询防止 SQL 注入
    pub fn search(self: *Self, query: SearchQuery) !PageResult(TestCase) {
        return self.vtable.search(self.ptr, query);
    }
};

/// 创建测试用例仓储实例
/// 参数:
///   - ptr: 实现类实例指针
///   - vtable: 虚函数表指针
/// 返回:
///   - TestCaseRepository: 仓储接口实例
pub fn create(ptr: anytype, vtable: *const TestCaseRepository.VTable) TestCaseRepository {
    return .{
        .ptr = ptr,
        .vtable = vtable,
    };
}
