// 控制器命名空间 - 按功能分组
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
};

// 第三方服务控制器
pub const external = struct {
    pub const Github = @import("github.controller.zig");
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
};
