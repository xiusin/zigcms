//! 分类管理模型
//!
//! 系统分类实体，用于文章、产品等内容分类
//! 遵循领域驱动设计原则，封装分类相关的业务规则和方法

const std = @import("std");

/// 分类实体
pub const Category = struct {
    /// 分类ID
    id: ?i32 = null,
    /// 分类名称
    name: []const u8 = "",
    /// 分类编码（唯一标识）
    code: []const u8 = "",
    /// 父分类ID（0=顶级分类）
    parent_id: i32 = 0,
    /// 分类类型（article=文章分类, product=产品分类, page=单页分类等）
    category_type: []const u8 = "article",
    /// 分类描述
    description: []const u8 = "",
    /// 封面图片
    cover_image: []const u8 = "",
    /// 分类图标
    icon: []const u8 = "",
    /// 排序权重
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// SEO标题
    seo_title: []const u8 = "",
    /// SEO关键词
    seo_keywords: []const u8 = "",
    /// SEO描述
    seo_description: []const u8 = "",
    /// 访问量
    views: i32 = 0,
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
    /// 软删除标记
    is_delete: i32 = 0,

    /// 创建新分类
    pub fn create(name: []const u8, code: []const u8, category_type: []const u8, parent_id: i32) Category {
        const now = std.time.timestamp();
        return .{
            .name = name,
            .code = code,
            .category_type = category_type,
            .parent_id = parent_id,
            .status = 1,
            .create_time = now,
            .update_time = now,
        };
    }

    /// 更新分类基本信息
    pub fn updateInfo(self: *Category, name: ?[]const u8, description: ?[]const u8, icon: ?[]const u8) void {
        const now = std.time.timestamp();

        if (name) |n| {
            self.name = n;
        }
        if (description) |desc| {
            self.description = desc;
        }
        if (icon) |i| {
            self.icon = i;
        }
        self.update_time = now;
    }

    /// 更新SEO信息
    pub fn updateSeo(self: *Category, title: ?[]const u8, keywords: ?[]const u8, seo_desc: ?[]const u8) void {
        const now = std.time.timestamp();

        if (title) |t| {
            self.seo_title = t;
        }
        if (keywords) |k| {
            self.seo_keywords = k;
        }
        if (seo_desc) |desc| {
            self.seo_description = desc;
        }
        self.update_time = now;
    }

    /// 设置父分类
    pub fn setParent(self: *Category, parent_id: i32) void {
        self.parent_id = parent_id;
        self.update_time = std.time.timestamp();
    }

    /// 增加访问量
    pub fn incrementViews(self: *Category) void {
        self.views += 1;
        self.update_time = std.time.timestamp();
    }

    /// 启用分类
    pub fn enable(self: *Category) void {
        self.status = 1;
        self.update_time = std.time.timestamp();
    }

    /// 禁用分类
    pub fn disable(self: *Category) void {
        self.status = 0;
        self.update_time = std.time.timestamp();
    }

    /// 检查分类是否激活
    pub fn isActive(self: Category) bool {
        return self.status == 1 and self.is_delete == 0;
    }

    /// 检查是否为顶级分类
    pub fn isRoot(self: Category) bool {
        return self.parent_id == 0;
    }

    /// 检查是否为子分类
    pub fn isChild(self: Category) bool {
        return self.parent_id != 0;
    }

    /// 验证分类编码格式
    pub fn isValidCode(_: Category, code: []const u8) bool {
        if (code.len == 0 or code.len > 50) return false;

        // 只能包含字母、数字、下划线和连字符
        for (code) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') {
                return false;
            }
        }

        // 不能以数字开头
        if (std.ascii.isDigit(code[0])) return false;

        return true;
    }

    /// 验证分类名称
    pub fn isValidName(_: Category, name: []const u8) bool {
        return name.len > 0 and name.len <= 100;
    }

    /// 获取完整的分类路径（需要仓储层支持）
    /// 这个方法需要仓储层来构建完整的路径
    pub fn getFullPath(self: Category, allocator: std.mem.Allocator, repository: anytype) ![]const u8 {
        _ = allocator;
        _ = repository;
        // 实际实现需要仓储层支持递归查询父分类
        // 这里返回简化版本
        return self.name;
    }

    /// 获取分类层级深度（需要仓储层支持）
    pub fn getDepth(self: Category, repository: anytype) !i32 {
        _ = repository;
        // 实际实现需要仓储层支持递归查询
        if (self.isRoot()) return 1;
        return 2; // 简化实现
    }

    /// 获取子分类数量（需要仓储层支持）
    pub fn getChildrenCount(_: Category, _: anytype) !usize {
        // 实际实现需要仓储层支持查询子分类
        return 0; // 简化实现
    }

    /// 检查是否可以移动到指定父分类下
    pub fn canMoveTo(self: Category, new_parent_id: i32, repository: anytype) !bool {
        _ = repository;

        // 不能移动到自己或自己的子分类下
        if (new_parent_id == self.id.?) return false;

        // 不能创建循环引用（需要仓储层验证）
        return true; // 简化实现
    }

    /// 获取分类类型显示名称
    pub fn getTypeDisplayName(self: Category) []const u8 {
        if (std.mem.eql(u8, self.category_type, "article")) {
            return "文章分类";
        } else if (std.mem.eql(u8, self.category_type, "product")) {
            return "产品分类";
        } else if (std.mem.eql(u8, self.category_type, "page")) {
            return "单页分类";
        } else {
            return "其他分类";
        }
    }

    /// 获取排序后的兄弟分类（需要仓储层支持）
    pub fn getSortedSiblings(_: Category, _: std.mem.Allocator, _: anytype) ![]Category {
        // 实际实现需要仓储层支持查询兄弟分类并排序
        return &[_]Category{}; // 简化实现
    }
};
