//! HTTP 控制器模块 (Controllers Module)
//!
//! 按功能分组的控制器集合，处理各种 API 端点。
//! 控制器负责接收 HTTP 请求、调用应用服务、返回响应。
//!
//! ## 控制器分组
//! - `auth`: 认证相关（登录、注册、令牌刷新）
//! - `admin`: 管理相关（菜单、设置）
//! - `common`: 公共控制器（通用 CRUD、动态路由）
//! - `dict`: 字典管理
//! - `org`: 组织管理（部门、员工、职位、角色）
//! - `cms`: CMS 内容管理（模型、字段、文档、分类、素材）
//! - `member`: 会员管理
//! - `friendlink`: 友链管理
//! - `external`: 第三方服务（GitHub）
//!
//! ## 使用示例
//! ```zig
//! const controllers = @import("api/controllers/mod.zig");
//!
//! // 使用登录控制器
//! const LoginController = controllers.auth.Login;
//!
//! // 使用 CRUD 控制器
//! const CrudController = controllers.common.Crud;
//! ```

const std = @import("std");

// 认证相关控制器
pub const auth = struct {
    pub const Login = @import("login.controller.zig");
};

// 管理相关控制器
pub const admin = struct {
    pub const Menu = @import("menu.controller.zig");
    pub const Setting = @import("setting.controller.zig");
};

// 公共控制器
pub const common = struct {
    pub const Public = @import("public.controller.zig");
    pub const Generic = @import("generic.controller.zig");
    pub const Crud = @import("crud.controller.zig").Crud;
    pub const Dynamic = @import("dynamic.controller.zig");
};

// 组织管理控制器
pub const org = struct {
    pub const Department = @import("department.controller.zig");
    pub const Employee = @import("employee.controller.zig");
    pub const Position = @import("position.controller.zig");
    pub const Role = @import("role.controller.zig");
};

// CMS 内容管理控制器
pub const cms = struct {
    pub const Model = @import("cms_model.controller.zig");
    pub const Field = @import("cms_field.controller.zig");
    pub const Document = @import("document.controller.zig");
    pub const Category = @import("category.controller.zig");
    pub const Material = @import("material.controller.zig");
    pub const MaterialCategory = @import("material_category.controller.zig");
};

// 会员管理控制器
pub const member = struct {
    pub const Member = @import("member.controller.zig");
    pub const MemberGroup = @import("member_group.controller.zig");
};

// 友链管理控制器
pub const friendlink = struct {
    pub const FriendLink = @import("friend_link.controller.zig");
};

// 第三方服务控制器
pub const external = struct {
    pub const Github = @import("github.controller.zig");
};

// 实时通信控制器
pub const realtime = struct {
    // TODO: WebSocket 和 SSE 功能需要 zap 支持，暂时注释
    // pub const WebSocket = @import("websocket.controller.zig").WebSocketController;
    // pub const SSE = @import("sse.controller.zig").SSEController;
};

// 通用控制器类型
pub const ControllerType = enum {
    crud,
    generic,
    login,
    menu,
    public,
    setting,
    task,
    department,
    employee,
    position,
    role,
};
