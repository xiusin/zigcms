//! Application Use Cases Module
//!
//! 应用用例层 - 编排业务流程
//!
//! 职责：
//! - 协调领域服务和基础设施服务
//! - 实现具体的业务用例
//! - 处理事务边界
//! - 转换 DTO 和领域对象

const std = @import("std");

// 用例基类接口
pub fn UseCase(comptime Input: type, comptime Output: type) type {
    return struct {
        pub const InputType = Input;
        pub const OutputType = Output;

        /// 执行用例
        pub fn execute(self: *@This(), input: Input) !Output {
            _ = self;
            _ = input;
            @compileError("UseCase.execute must be implemented");
        }
    };
}

// 用例执行器 - 提供通用的执行框架
pub const UseCaseExecutor = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) UseCaseExecutor {
        return .{ .allocator = allocator };
    }

    /// 执行用例（带日志和错误处理）
    pub fn run(
        self: *UseCaseExecutor,
        comptime UC: type,
        use_case: *UC,
        input: UC.InputType,
    ) !UC.OutputType {
        _ = self;

        // TODO: 添加日志、监控、错误处理
        return try use_case.execute(input);
    }
};

// 导出用例模块
pub const user = struct {
    // TODO: 用户相关用例
    // pub const RegisterUser = @import("user/register_user.zig");
    // pub const LoginUser = @import("user/login_user.zig");
};

pub const content = struct {
    // TODO: 内容管理用例
    // pub const CreateArticle = @import("content/create_article.zig");
    // pub const PublishArticle = @import("content/publish_article.zig");
};

pub const member = struct {
    // TODO: 会员管理用例
};
