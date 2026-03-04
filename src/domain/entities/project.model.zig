// 项目实体
// 用于质量中心的项目管理

const std = @import("std");

/// 项目实体
pub const Project = struct {
    id: ?i32 = null,
    name: []const u8 = "", // 项目名称（必填）
    description: []const u8 = "", // 项目描述（必填）
    status: ProjectStatus = .active, // 项目状态
    owner: []const u8 = "", // 项目负责人
    members: []const u8 = "", // 成员列表（JSON 数组）
    settings: []const u8 = "", // 项目设置（JSON 对象）
    archived: bool = false, // 是否归档
    created_by: []const u8 = "", // 创建人
    created_at: ?i64 = null, // 创建时间
    updated_at: ?i64 = null, // 更新时间

    // 关联数据（预加载）
    modules: ?[]Module = null, // 模块列表
    test_cases: ?[]TestCase = null, // 测试用例列表
    requirements: ?[]Requirement = null, // 需求列表

    /// 项目状态枚举
    pub const ProjectStatus = enum {
        active, // 活跃
        archived, // 已归档
        closed, // 已关闭

        pub fn toString(self: ProjectStatus) []const u8 {
            return switch (self) {
                .active => "active",
                .archived => "archived",
                .closed => "closed",
            };
        }

        pub fn fromString(str: []const u8) ?ProjectStatus {
            if (std.mem.eql(u8, str, "active")) return .active;
            if (std.mem.eql(u8, str, "archived")) return .archived;
            if (std.mem.eql(u8, str, "closed")) return .closed;
            return null;
        }
    };

    /// 关系定义（用于 ORM 关系预加载）
    pub const relations = .{
        .modules = .{
            .type = .has_many,
            .model = @import("module.model.zig").Module,
            .foreign_key = "project_id",
        },
        .test_cases = .{
            .type = .has_many,
            .model = @import("test_case.model.zig").TestCase,
            .foreign_key = "project_id",
        },
        .requirements = .{
            .type = .has_many,
            .model = @import("requirement.model.zig").Requirement,
            .foreign_key = "project_id",
        },
    };

    /// 验证项目数据是否有效
    pub fn validate(self: *const Project) !void {
        if (self.name.len == 0) {
            return error.NameRequired;
        }
        if (self.name.len > 200) {
            return error.NameTooLong;
        }
        if (self.description.len == 0) {
            return error.DescriptionRequired;
        }
        if (self.description.len > 500) {
            return error.DescriptionTooLong;
        }
    }

    /// 判断项目是否活跃
    pub fn isActive(self: *const Project) bool {
        return self.status == .active and !self.archived;
    }

    /// 判断项目是否已归档
    pub fn isArchived(self: *const Project) bool {
        return self.archived or self.status == .archived;
    }

    /// 判断项目是否已关闭
    pub fn isClosed(self: *const Project) bool {
        return self.status == .closed;
    }
};

// 导入关联实体类型（避免循环依赖）
const Module = @import("module.model.zig").Module;
const TestCase = @import("test_case.model.zig").TestCase;
const Requirement = @import("requirement.model.zig").Requirement;
