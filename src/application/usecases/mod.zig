//! 业务用例模块 (Use Cases Module)
//!
//! 定义具体的业务流程，协调领域服务和基础设施服务完成业务目标。
//! 用例是应用层的核心，代表系统的功能需求。
//!
//! ## 功能
//! - 定义用例基类接口（UseCase）
//! - 提供用例执行器（UseCaseExecutor）
//! - 按功能分组的用例模块
//!
//! ## 使用示例
//! ```zig
//! const usecases = @import("application/usecases/mod.zig");
//!
//! // 创建用例执行器
//! var executor = usecases.UseCaseExecutor.init(allocator);
//!
//! // 执行用例
//! const result = try executor.run(RegisterUserUseCase, &use_case, input);
//! ```

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
