//! 用户应用服务 (User Application Service)
//!
//! 应用层用户服务，实现用户相关的业务逻辑。
//! 该服务协调领域层实体和仓储，处理复杂的业务用例。

const std = @import("std");
const User = @import("../../domain/entities/user.model.zig").User;
const UserRepository = @import("../../domain/repositories/user_repository.zig").UserRepository;

/// 用户应用服务
///
/// 应用层服务，负责协调领域对象，处理业务用例逻辑。
/// 遵循应用服务模式，封装业务流程。
pub const UserService = struct {
    allocator: std.mem.Allocator,
    user_repository: UserRepository,

    /// 初始化用户服务
    pub fn init(allocator: std.mem.Allocator, user_repository: UserRepository) UserService {
        return .{
            .allocator = allocator,
            .user_repository = user_repository,
        };
    }

    /// 根据ID获取用户
    ///
    /// ## 参数
    /// - `user_id`: 用户ID
    ///
    /// ## 返回
    /// 用户实体，如果不存在返回null
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getUser(self: *UserService, user_id: i32) !?User {
        // 调用领域层仓储接口
        const user = try self.user_repository.findById(user_id);
        return user;
    }

    /// 根据用户名获取用户
    ///
    /// ## 参数
    /// - `username`: 用户名
    ///
    /// ## 返回
    /// 用户实体，如果不存在返回null
    ///
    /// ## 注意
    /// 这个方法需要仓储层支持按用户名查找，当前示例中未实现
    pub fn getUserByUsername(_: *UserService, _: []const u8) !?User {
        // 注意：当前UserRepository只支持按ID查找
        // 实际项目中需要扩展仓储接口支持更多查询方式
        return null;
    }

    /// 创建新用户
    ///
    /// ## 参数
    /// - `username`: 用户名
    /// - `email`: 邮箱
    /// - `nickname`: 昵称
    ///
    /// ## 返回
    /// 创建的用户实体
    ///
    /// ## 错误
    /// - 用户名已存在
    /// - 邮箱格式无效
    /// - 仓储层错误
    pub fn createUser(self: *UserService, username: []const u8, email: []const u8, nickname: []const u8) !User {
        // 业务规则验证
        if (username.len == 0) {
            return error.InvalidUsername;
        }

        if (!User.isValidEmail(User{}, email)) {
            return error.InvalidEmail;
        }

        // 检查用户名是否已存在
        // 注意：当前仓储接口不支持按用户名查找，实际项目中需要扩展
        // const existing = try self.getUserByUsername(username);
        // if (existing != null) {
        //     return error.UsernameExists;
        // }

        // 创建用户实体
        const user = User.create(username, email, nickname);

        // 保存到仓储
        const saved_user = try self.user_repository.save(user);

        return saved_user;
    }

    /// 更新用户信息
    ///
    /// ## 参数
    /// - `user_id`: 用户ID
    /// - `nickname`: 新昵称（可选）
    /// - `avatar`: 新头像（可选）
    ///
    /// ## 错误
    /// - 用户不存在
    /// - 仓储层错误
    pub fn updateUser(self: *UserService, user_id: i32, nickname: ?[]const u8, avatar: ?[]const u8) !void {
        // 获取现有用户
        const existing_user = try self.user_repository.findById(user_id) orelse {
            return error.UserNotFound;
        };

        // 复制用户进行修改（避免直接修改）
        var user = existing_user;
        user.update(nickname, avatar);

        // 保存更新
        try self.user_repository.update(user);
    }

    /// 启用用户
    ///
    /// ## 参数
    /// - `user_id`: 用户ID
    ///
    /// ## 错误
    /// - 用户不存在
    /// - 仓储层错误
    pub fn enableUser(self: *UserService, user_id: i32) !void {
        const user = try self.user_repository.findById(user_id) orelse {
            return error.UserNotFound;
        };

        var updated_user = user;
        updated_user.enable();
        try self.user_repository.update(updated_user);
    }

    /// 禁用用户
    ///
    /// ## 参数
    /// - `user_id`: 用户ID
    ///
    /// ## 错误
    /// - 用户不存在
    /// - 仓储层错误
    pub fn disableUser(self: *UserService, user_id: i32) !void {
        const user = try self.user_repository.findById(user_id) orelse {
            return error.UserNotFound;
        };

        var updated_user = user;
        updated_user.disable();
        try self.user_repository.update(updated_user);
    }

    /// 删除用户
    ///
    /// ## 参数
    /// - `user_id`: 用户ID
    ///
    /// ## 错误
    /// - 用户不存在
    /// - 仓储层错误
    pub fn deleteUser(self: *UserService, user_id: i32) !void {
        // 验证用户存在
        _ = try self.user_repository.findById(user_id) orelse {
            return error.UserNotFound;
        };

        // 删除用户
        try self.user_repository.delete(user_id);
    }

    /// 获取用户统计信息
    ///
    /// ## 返回
    /// 用户总数
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getUserCount(self: *UserService) !usize {
        return try self.user_repository.count();
    }

    /// 获取所有用户
    ///
    /// ## 返回
    /// 用户列表
    ///
    /// ## 注意
    /// 这个方法可能返回大量数据，生产环境中应该分页
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getAllUsers(self: *UserService) ![]User {
        return try self.user_repository.findAll();
    }
};
