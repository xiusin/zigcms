//! 用户控制器 (User Controller)
//!
//! 表现层用户控制器，处理HTTP请求并调用应用层服务。
//! 该控制器遵循RESTful API设计原则。

const std = @import("std");
const http = @import("../../application/services/http/http.zig");
const UserService = @import("../../application/services/user_service.zig").UserService;
const User = @import("../../domain/entities/user.model.zig").User;

/// 用户控制器
///
/// 表现层控制器，负责处理HTTP请求，调用应用层服务，返回HTTP响应。
/// 遵循RESTful API设计，处理用户相关的HTTP端点。
pub const UserController = struct {
    allocator: std.mem.Allocator,
    user_service: *UserService,

    /// 初始化用户控制器
    pub fn init(allocator: std.mem.Allocator, user_service: *UserService) UserController {
        return .{
            .allocator = allocator,
            .user_service = user_service,
        };
    }

    /// 获取用户详情
    ///
    /// GET /api/users/{id}
    ///
    /// ## 响应
    /// - 200: 用户信息JSON
    /// - 404: 用户不存在
    /// - 500: 服务器错误
    pub fn getUser(self: *UserController, request: *http.Request, response: *http.Response) !void {
        // 从URL路径参数获取用户ID
        const user_id_str = request.params.get("id") orelse {
            try response.jsonError(400, "Missing user ID parameter");
            return;
        };

        // 转换字符串为整数
        const user_id = std.fmt.parseInt(i32, user_id_str, 10) catch {
            try response.jsonError(400, "Invalid user ID format");
            return;
        };

        // 调用应用层服务
        var user = try self.user_service.getUser(user_id) orelse {
            try response.jsonError(404, "User not found");
            return;
        };
        defer user.deinit(self.allocator);

        // 返回用户JSON
        try response.json(user);
    }

    /// 创建新用户
    ///
    /// POST /api/users
    ///
    /// ## 请求体
    /// ```json
    /// {
    ///   "username": "johndoe",
    ///   "email": "john@example.com",
    ///   "nickname": "John Doe"
    /// }
    /// ```
    ///
    /// ## 响应
    /// - 201: 创建的用户信息JSON
    /// - 400: 请求参数错误
    /// - 409: 用户名已存在
    /// - 500: 服务器错误
    pub fn createUser(self: *UserController, request: *http.Request, response: *http.Response) !void {
        // 解析请求体JSON
        const body = try request.json() orelse {
            try response.jsonError(400, "Missing request body");
            return;
        };
        defer body.deinit();

        // 提取字段
        const username = body.getString("username") orelse {
            try response.jsonError(400, "Missing username field");
            return;
        };

        const email = body.getString("email") orelse {
            try response.jsonError(400, "Missing email field");
            return;
        };

        const nickname = body.getString("nickname") orelse "";

        // 调用应用层服务创建用户
        var user = try self.user_service.createUser(username, email, nickname) catch |err| switch (err) {
            error.InvalidUsername => {
                try response.jsonError(400, "Invalid username");
                return;
            },
            error.InvalidEmail => {
                try response.jsonError(400, "Invalid email format");
                return;
            },
            else => return err,
        };
        defer user.deinit(self.allocator);

        // 返回创建的用户
        try response.jsonWithStatus(201, user);
    }

    /// 更新用户信息
    ///
    /// PUT /api/users/{id}
    ///
    /// ## 请求体
    /// ```json
    /// {
    ///   "nickname": "New Nickname",
    ///   "avatar": "https://example.com/avatar.jpg"
    /// }
    /// ```
    ///
    /// ## 响应
    /// - 200: 更新成功
    /// - 400: 请求参数错误
    /// - 404: 用户不存在
    /// - 500: 服务器错误
    pub fn updateUser(self: *UserController, request: *http.Request, response: *http.Response) !void {
        // 获取用户ID
        const user_id_str = request.params.get("id") orelse {
            try response.jsonError(400, "Missing user ID parameter");
            return;
        };

        const user_id = std.fmt.parseInt(i32, user_id_str, 10) catch {
            try response.jsonError(400, "Invalid user ID format");
            return;
        };

        // 解析请求体
        const body = try request.json() orelse {
            try response.jsonError(400, "Missing request body");
            return;
        };
        defer body.deinit();

        // 提取可选字段
        const nickname = body.getString("nickname");
        const avatar = body.getString("avatar");

        // 调用应用层服务更新用户
        try self.user_service.updateUser(user_id, nickname, avatar) catch |err| switch (err) {
            error.UserNotFound => {
                try response.jsonError(404, "User not found");
                return;
            },
            else => return err,
        };

        // 返回成功响应
        try response.json(.{ .message = "User updated successfully" });
    }

    /// 启用用户
    ///
    /// POST /api/users/{id}/enable
    ///
    /// ## 响应
    /// - 200: 启用成功
    /// - 404: 用户不存在
    /// - 500: 服务器错误
    pub fn enableUser(self: *UserController, request: *http.Request, response: *http.Response) !void {
        const user_id_str = request.params.get("id") orelse {
            try response.jsonError(400, "Missing user ID parameter");
            return;
        };

        const user_id = std.fmt.parseInt(i32, user_id_str, 10) catch {
            try response.jsonError(400, "Invalid user ID format");
            return;
        };

        try self.user_service.enableUser(user_id) catch |err| switch (err) {
            error.UserNotFound => {
                try response.jsonError(404, "User not found");
                return;
            },
            else => return err,
        };

        try response.json(.{ .message = "User enabled successfully" });
    }

    /// 禁用用户
    ///
    /// POST /api/users/{id}/disable
    ///
    /// ## 响应
    /// - 200: 禁用成功
    /// - 404: 用户不存在
    /// - 500: 服务器错误
    pub fn disableUser(self: *UserController, request: *http.Request, response: *http.Response) !void {
        const user_id_str = request.params.get("id") orelse {
            try response.jsonError(400, "Missing user ID parameter");
            return;
        };

        const user_id = std.fmt.parseInt(i32, user_id_str, 10) catch {
            try response.jsonError(400, "Invalid user ID format");
            return;
        };

        try self.user_service.disableUser(user_id) catch |err| switch (err) {
            error.UserNotFound => {
                try response.jsonError(404, "User not found");
                return;
            },
            else => return err,
        };

        try response.json(.{ .message = "User disabled successfully" });
    }

    /// 删除用户
    ///
    /// DELETE /api/users/{id}
    ///
    /// ## 响应
    /// - 200: 删除成功
    /// - 404: 用户不存在
    /// - 500: 服务器错误
    pub fn deleteUser(self: *UserController, request: *http.Request, response: *http.Response) !void {
        const user_id_str = request.params.get("id") orelse {
            try response.jsonError(400, "Missing user ID parameter");
            return;
        };

        const user_id = std.fmt.parseInt(i32, user_id_str, 10) catch {
            try response.jsonError(400, "Invalid user ID format");
            return;
        };

        try self.user_service.deleteUser(user_id) catch |err| switch (err) {
            error.UserNotFound => {
                try response.jsonError(404, "User not found");
                return;
            },
            else => return err,
        };

        try response.json(.{ .message = "User deleted successfully" });
    }

    /// 获取用户列表
    ///
    /// GET /api/users
    ///
    /// ## 响应
    /// - 200: 用户列表JSON
    /// - 500: 服务器错误
    pub fn getUsers(self: *UserController, request: *http.Request, response: *http.Response) !void {
        _ = request; // 未使用请求参数

        var users = try self.user_service.getAllUsers();
        defer {
            for (users) |*user| {
                user.deinit(self.allocator);
            }
            self.allocator.free(users);
        }

        try response.json(.{ .users = users });
    }

    /// 获取用户统计信息
    ///
    /// GET /api/users/stats
    ///
    /// ## 响应
    /// - 200: 统计信息JSON
    /// - 500: 服务器错误
    pub fn getUserStats(self: *UserController, request: *http.Request, response: *http.Response) !void {
        _ = request; // 未使用请求参数

        const count = try self.user_service.getUserCount();

        try response.json(.{
            .total_users = count,
        });
    }
};
