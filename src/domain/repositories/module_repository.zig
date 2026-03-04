const std = @import("std");
const Module = @import("../entities/module.model.zig").Module;

/// 模块仓储接口
/// 使用 VTable 模式实现接口抽象,遵循 ZigCMS 整洁架构规范
pub const ModuleRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();

    /// 虚函数表定义
    pub const VTable = struct {
        /// 根据 ID 查询模块
        findById: *const fn (*anyopaque, i32) anyerror!?Module,

        /// 根据项目 ID 查询所有模块
        findByProject: *const fn (*anyopaque, i32) anyerror![]Module,

        /// 根据项目 ID 查询模块树
        findTree: *const fn (*anyopaque, i32) anyerror![]Module,

        /// 保存模块(创建或更新)
        save: *const fn (*anyopaque, *Module) anyerror!void,

        /// 删除模块
        delete: *const fn (*anyopaque, i32) anyerror!void,

        /// 移动模块(拖拽调整层级和顺序)
        move: *const fn (*anyopaque, i32, ?i32, i32) anyerror!void,
    };

    /// 根据 ID 查询模块
    /// 参数:
    ///   - id: 模块 ID
    /// 返回:
    ///   - ?Module: 模块对象,如果不存在则返回 null
    /// 说明:
    ///   - 可使用关系预加载 with(&.{"children", "test_cases"}) 优化查询
    pub fn findById(self: *Self, id: i32) !?Module {
        return self.vtable.findById(self.ptr, id);
    }

    /// 根据项目 ID 查询所有模块
    /// 参数:
    ///   - project_id: 项目 ID
    /// 返回:
    ///   - []Module: 模块数组(平铺结构)
    /// 说明:
    ///   - 返回项目下所有模块的平铺列表
    ///   - 按 sort_order 排序
    pub fn findByProject(self: *Self, project_id: i32) ![]Module {
        return self.vtable.findByProject(self.ptr, project_id);
    }

    /// 根据项目 ID 查询模块树
    /// 参数:
    ///   - project_id: 项目 ID
    /// 返回:
    ///   - []Module: 模块数组(树形结构)
    /// 说明:
    ///   - 返回项目下所有模块的树形结构
    ///   - 根节点的 parent_id 为 null
    ///   - 子节点通过 children 字段关联
    ///   - 最多支持 5 层嵌套
    ///   - 使用关系预加载 with(&.{"children"}) 避免 N+1 查询
    pub fn findTree(self: *Self, project_id: i32) ![]Module {
        return self.vtable.findTree(self.ptr, project_id);
    }

    /// 保存模块(创建或更新)
    /// 参数:
    ///   - module: 模块对象指针
    /// 说明:
    ///   - 如果 module.id 为 null,则创建新记录并设置 id
    ///   - 如果 module.id 不为 null,则更新现有记录
    ///   - 创建时验证模块名称在同一父模块下唯一
    ///   - 创建时验证层级深度不超过 5 层
    pub fn save(self: *Self, module: *Module) !void {
        return self.vtable.save(self.ptr, module);
    }

    /// 删除模块
    /// 参数:
    ///   - id: 模块 ID
    /// 说明:
    ///   - 删除模块前应提示用户确认
    ///   - 删除模块会级联删除子模块和关联的测试用例
    pub fn delete(self: *Self, id: i32) !void {
        return self.vtable.delete(self.ptr, id);
    }

    /// 移动模块(拖拽调整层级和顺序)
    /// 参数:
    ///   - id: 模块 ID
    ///   - new_parent_id: 新的父模块 ID(null 表示移动到根节点)
    ///   - new_sort_order: 新的排序值
    /// 说明:
    ///   - 更新模块的 parent_id 和 sort_order
    ///   - 更新模块的 level(根据新的父模块层级计算)
    ///   - 验证移动后的层级深度不超过 5 层
    ///   - 验证不能将模块移动到自己的子模块下
    pub fn move(self: *Self, id: i32, new_parent_id: ?i32, new_sort_order: i32) !void {
        return self.vtable.move(self.ptr, id, new_parent_id, new_sort_order);
    }
};

/// 创建模块仓储实例
/// 参数:
///   - ptr: 实现类实例指针
///   - vtable: 虚函数表指针
/// 返回:
///   - ModuleRepository: 仓储接口实例
pub fn create(ptr: anytype, vtable: *const ModuleRepository.VTable) ModuleRepository {
    return .{
        .ptr = ptr,
        .vtable = vtable,
    };
}
