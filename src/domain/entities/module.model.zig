// 模块实体
// 用于质量中心的模块管理，支持树形结构

const std = @import("std");

/// 模块实体
pub const Module = struct {
    id: ?i32 = null,
    project_id: i32 = 0, // 所属项目（必填）
    parent_id: ?i32 = null, // 父模块 ID
    name: []const u8 = "", // 模块名称（必填）
    description: []const u8 = "", // 模块描述
    level: i32 = 1, // 层级（1-5）
    sort_order: i32 = 0, // 排序
    created_by: []const u8 = "", // 创建人
    created_at: ?i64 = null, // 创建时间
    updated_at: ?i64 = null, // 更新时间

    // 关联数据（预加载）
    children: ?[]Module = null, // 子模块
    test_cases: ?[]TestCase = null, // 测试用例

    /// 最大层级深度
    pub const MAX_LEVEL: i32 = 5;

    /// 关系定义（用于 ORM 关系预加载）
    pub const relations = .{
        .children = .{
            .type = .has_many,
            .model = Module,
            .foreign_key = "parent_id",
        },
        .test_cases = .{
            .type = .has_many,
            .model = @import("test_case.model.zig").TestCase,
            .foreign_key = "module_id",
        },
    };

    /// 验证模块数据是否有效
    pub fn validate(self: *const Module) !void {
        if (self.project_id == 0) {
            return error.ProjectIdRequired;
        }
        if (self.name.len == 0) {
            return error.NameRequired;
        }
        if (self.name.len > 200) {
            return error.NameTooLong;
        }
        if (self.level < 1 or self.level > MAX_LEVEL) {
            return error.InvalidLevel;
        }
    }

    /// 判断是否为根模块
    pub fn isRoot(self: *const Module) bool {
        return self.parent_id == null;
    }

    /// 判断是否为叶子模块
    pub fn isLeaf(self: *const Module) bool {
        if (self.children) |children| {
            return children.len == 0;
        }
        return true;
    }

    /// 判断是否可以添加子模块（层级不超过 5）
    pub fn canAddChild(self: *const Module) bool {
        return self.level < MAX_LEVEL;
    }

    /// 获取子模块数量
    pub fn getChildCount(self: *const Module) usize {
        if (self.children) |children| {
            return children.len;
        }
        return 0;
    }
};

// 导入关联实体类型（避免循环依赖）
const TestCase = @import("test_case.model.zig").TestCase;
