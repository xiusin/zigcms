const std = @import("std");
const Requirement = @import("../entities/requirement.model.zig").Requirement;
const PageQuery = @import("./test_case_repository.zig").PageQuery;
const PageResult = @import("./test_case_repository.zig").PageResult;

/// 需求仓储接口
/// 使用 VTable 模式实现接口抽象,遵循 ZigCMS 整洁架构规范
pub const RequirementRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();

    /// 虚函数表定义
    pub const VTable = struct {
        /// 根据 ID 查询需求
        findById: *const fn (*anyopaque, i32) anyerror!?Requirement,

        /// 根据项目 ID 分页查询需求
        findByProject: *const fn (*anyopaque, i32, PageQuery) anyerror!PageResult(Requirement),

        /// 保存需求(创建或更新)
        save: *const fn (*anyopaque, *Requirement) anyerror!void,

        /// 删除需求
        delete: *const fn (*anyopaque, i32) anyerror!void,

        /// 关联测试用例
        linkTestCase: *const fn (*anyopaque, i32, i32) anyerror!void,

        /// 取消关联测试用例
        unlinkTestCase: *const fn (*anyopaque, i32, i32) anyerror!void,
    };

    /// 根据 ID 查询需求
    /// 参数:
    ///   - id: 需求 ID
    /// 返回:
    ///   - ?Requirement: 需求对象,如果不存在则返回 null
    /// 说明:
    ///   - 可使用关系预加载 with(&.{"test_cases"}) 优化查询
    pub fn findById(self: *Self, id: i32) !?Requirement {
        return self.vtable.findById(self.ptr, id);
    }

    /// 根据项目 ID 分页查询需求
    /// 参数:
    ///   - project_id: 项目 ID
    ///   - query: 分页查询参数
    /// 返回:
    ///   - PageResult(Requirement): 分页结果
    /// 说明:
    ///   - 按创建时间倒序排列(最新的在前)
    pub fn findByProject(self: *Self, project_id: i32, query: PageQuery) !PageResult(Requirement) {
        return self.vtable.findByProject(self.ptr, project_id, query);
    }

    /// 保存需求(创建或更新)
    /// 参数:
    ///   - requirement: 需求对象指针
    /// 说明:
    ///   - 如果 requirement.id 为 null,则创建新记录并设置 id
    ///   - 如果 requirement.id 不为 null,则更新现有记录
    pub fn save(self: *Self, requirement: *Requirement) !void {
        return self.vtable.save(self.ptr, requirement);
    }

    /// 删除需求
    /// 参数:
    ///   - id: 需求 ID
    /// 说明:
    ///   - 删除需求前应提示用户确认
    ///   - 删除需求会取消所有关联的测试用例
    pub fn delete(self: *Self, id: i32) !void {
        return self.vtable.delete(self.ptr, id);
    }

    /// 关联测试用例
    /// 参数:
    ///   - requirement_id: 需求 ID
    ///   - test_case_id: 测试用例 ID
    /// 说明:
    ///   - 在测试用例表中设置 requirement_id 字段
    ///   - 更新需求的 actual_cases 和 coverage_rate
    pub fn linkTestCase(self: *Self, requirement_id: i32, test_case_id: i32) !void {
        return self.vtable.linkTestCase(self.ptr, requirement_id, test_case_id);
    }

    /// 取消关联测试用例
    /// 参数:
    ///   - requirement_id: 需求 ID
    ///   - test_case_id: 测试用例 ID
    /// 说明:
    ///   - 在测试用例表中清空 requirement_id 字段
    ///   - 更新需求的 actual_cases 和 coverage_rate
    pub fn unlinkTestCase(self: *Self, requirement_id: i32, test_case_id: i32) !void {
        return self.vtable.unlinkTestCase(self.ptr, requirement_id, test_case_id);
    }
};

/// 创建需求仓储实例
/// 参数:
///   - ptr: 实现类实例指针
///   - vtable: 虚函数表指针
/// 返回:
///   - RequirementRepository: 仓储接口实例
pub fn create(ptr: anytype, vtable: *const RequirementRepository.VTable) RequirementRepository {
    return .{
        .ptr = ptr,
        .vtable = vtable,
    };
}
