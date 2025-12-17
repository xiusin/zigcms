//! Shared Utils Module
//!
//! 通用工具函数模块入口
//! 提供字符串处理、时间处理、加密等常用工具

// 字符串工具
pub const strings = @import("strings.zig");

// JWT 工具
pub const jwt = @import("jwt.zig");

// Redis 工具
pub const redis = @import("redis.zig");

// 颜色工具
pub const color = @import("color.zig");

// 正则表达式工具
pub const regex = @import("regex.zig");

// GitHub 工具
pub const github = @import("github.zig");

// TOS (腾讯云对象存储) 工具
pub const tos = @import("tos.zig");

// WebUI 工具
pub const webui = @import("webui.zig");

// 导出所有工具模块
pub const Utils = struct {
    pub const Strings = strings;
    pub const JWT = jwt;
    pub const Redis = redis;
    pub const Color = color;
    pub const Regex = regex;
    pub const GitHub = github;
    pub const TOS = tos;
    pub const WebUI = webui;
};
