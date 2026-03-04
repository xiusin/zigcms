const std = @import("std");
const TestExecution = @import("../entities/test_execution.model.zig").TestExecution;
const PageQuery = @import("./test_case_repository.zig").PageQuery;
const PageResult = @import("./test_case_repository.zig").PageResult;

/// 测试执行记录仓储接口
/// 使用 VTable 模式实现接口抽象,遵循 ZigCMS 整洁架构规范
pub const TestExecutionRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();

    /// 虚函数表定义
    pub const VTable = struct {
        /// 根据 ID 查询测试执行记录
        findById: *const fn (*anyopaque, i32) anyerror!?TestExecution,

        /// 根据测试用例 ID 分页查询执行历史
        findByTestCase: *const fn (*anyopaque, i32, PageQuery) anyerror!PageResult(TestExecution),

        /// 保存测试执行记录(创建或更新)
        save: *const fn (*anyopaque, *TestExecution) anyerror!void,

        /// 删除测试执行记录
        delete: *const fn (*anyopaque, i32) anyerror!void,
    };

    /// 根据 ID 查询测试执行记录
    /// 参数:
    ///   - id: 测试执行记录 ID
    /// 返回:
    ///   - ?TestExecution: 测试执行记录对象,如果不存在则返回 null
    pub fn findById(self: *Self, id: i32) !?TestExecution {
        return self.vtable.findById(self.ptr, id);
    }

    /// 根据测试用例 ID 分页查询执行历史
    /// 参数:
    ///   - test_case_id: 测试用例 ID
    ///   - query: 分页查询参数
    /// 返回:
    ///   - PageResult(TestExecution): 分页结果
    /// 说明:
    ///   - 按执行时间倒序排列(最新的在前)
    pub fn findByTestCase(self: *Self, test_case_id: i32, query: PageQuery) !PageResult(TestExecution) {
        return self.vtable.findByTestCase(self.ptr, test_case_id, query);
    }

    /// 保存测试执行记录(创建或更新)
    /// 参数:
    ///   - execution: 测试执行记录对象指针
    /// 说明:
    ///   - 如果 execution.id 为 null,则创建新记录并设置 id
    ///   - 如果 execution.id 不为 null,则更新现有记录
    pub fn save(self: *Self, execution: *TestExecution) !void {
        return self.vtable.save(self.ptr, execution);
    }

    /// 删除测试执行记录
    /// 参数:
    ///   - id: 测试执行记录 ID
    pub fn delete(self: *Self, id: i32) !void {
        return self.vtable.delete(self.ptr, id);
    }
};

/// 创建测试执行记录仓储实例
/// 参数:
///   - ptr: 实现类实例指针
///   - vtable: 虚函数表指针
/// 返回:
///   - TestExecutionRepository: 仓储接口实例
pub fn create(ptr: anytype, vtable: *const TestExecutionRepository.VTable) TestExecutionRepository {
    return .{
        .ptr = ptr,
        .vtable = vtable,
    };
}
