const std = @import("std");
const Project = @import("../entities/project.model.zig").Project;
const PageQuery = @import("./test_case_repository.zig").PageQuery;
const PageResult = @import("./test_case_repository.zig").PageResult;

/// 项目仓储接口
/// 使用 VTable 模式实现接口抽象,遵循 ZigCMS 整洁架构规范
pub const ProjectRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();

    /// 虚函数表定义
    pub const VTable = struct {
        /// 根据 ID 查询项目
        findById: *const fn (*anyopaque, i32) anyerror!?Project,

        /// 查询所有项目(支持分页)
        findAll: *const fn (*anyopaque, PageQuery) anyerror!PageResult(Project),

        /// 保存项目(创建或更新)
        save: *const fn (*anyopaque, *Project) anyerror!void,

        /// 删除项目
        delete: *const fn (*anyopaque, i32) anyerror!void,

        /// 归档项目
        archive: *const fn (*anyopaque, i32) anyerror!void,

        /// 恢复项目
        restore: *const fn (*anyopaque, i32) anyerror!void,
    };

    /// 根据 ID 查询项目
    /// 参数:
    ///   - id: 项目 ID
    /// 返回:
    ///   - ?Project: 项目对象,如果不存在则返回 null
    /// 说明:
    ///   - 可使用关系预加载 with(&.{"modules", "test_cases", "requirements"}) 优化查询
    pub fn findById(self: *Self, id: i32) !?Project {
        return self.vtable.findById(self.ptr, id);
    }

    /// 查询所有项目(支持分页)
    /// 参数:
    ///   - query: 分页查询参数
    /// 返回:
    ///   - PageResult(Project): 分页结果
    /// 说明:
    ///   - 按创建时间倒序排列(最新的在前)
    ///   - 默认不包含归档项目
    pub fn findAll(self: *Self, query: PageQuery) !PageResult(Project) {
        return self.vtable.findAll(self.ptr, query);
    }

    /// 保存项目(创建或更新)
    /// 参数:
    ///   - project: 项目对象指针
    /// 说明:
    ///   - 如果 project.id 为 null,则创建新记录并设置 id
    ///   - 如果 project.id 不为 null,则更新现有记录
    pub fn save(self: *Self, project: *Project) !void {
        return self.vtable.save(self.ptr, project);
    }

    /// 删除项目
    /// 参数:
    ///   - id: 项目 ID
    /// 说明:
    ///   - 删除项目前应提示用户确认
    ///   - 删除项目会级联删除关联的模块、测试用例、需求等数据
    pub fn delete(self: *Self, id: i32) !void {
        return self.vtable.delete(self.ptr, id);
    }

    /// 归档项目
    /// 参数:
    ///   - id: 项目 ID
    /// 说明:
    ///   - 归档后的项目不会在默认列表中显示
    ///   - 归档项目的数据仍然保留,可以恢复
    pub fn archive(self: *Self, id: i32) !void {
        return self.vtable.archive(self.ptr, id);
    }

    /// 恢复项目
    /// 参数:
    ///   - id: 项目 ID
    /// 说明:
    ///   - 恢复归档的项目,使其重新显示在列表中
    pub fn restore(self: *Self, id: i32) !void {
        return self.vtable.restore(self.ptr, id);
    }
};

/// 创建项目仓储实例
/// 参数:
///   - ptr: 实现类实例指针
///   - vtable: 虚函数表指针
/// 返回:
///   - ProjectRepository: 仓储接口实例
pub fn create(ptr: anytype, vtable: *const ProjectRepository.VTable) ProjectRepository {
    return .{
        .ptr = ptr,
        .vtable = vtable,
    };
}
