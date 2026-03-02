//! OAuth 提供商抽象接口
//!
//! 定义统一的 OAuth 提供商接口，支持多种第三方登录

const std = @import("std");
const Allocator = std.mem.Allocator;

/// OAuth Token 响应
pub const OAuthTokenResponse = struct {
    access_token: []const u8,
    refresh_token: []const u8,
    expires_in: i64,
};

/// OAuth 用户信息
pub const OAuthUserInfo = struct {
    open_id: []const u8,
    union_id: []const u8,
    name: []const u8,
    email: []const u8,
    mobile: []const u8,
    avatar_url: []const u8,
};

/// OAuth 提供商接口
pub const OAuthProvider = struct {
    const Self = @This();
    
    ptr: *anyopaque,
    vtable: *const VTable,
    
    pub const VTable = struct {
        /// 获取应用访问令牌
        getAppAccessToken: *const fn (ptr: *anyopaque) anyerror![]const u8,
        
        /// 获取用户访问令牌
        getUserAccessToken: *const fn (ptr: *anyopaque, code: []const u8) anyerror!OAuthTokenResponse,
        
        /// 获取用户信息
        getUserInfo: *const fn (ptr: *anyopaque, access_token: []const u8) anyerror!OAuthUserInfo,
        
        /// 刷新访问令牌
        refreshAccessToken: *const fn (ptr: *anyopaque, refresh_token: []const u8) anyerror!OAuthTokenResponse,
        
        /// 获取提供商名称
        getProviderName: *const fn (ptr: *anyopaque) []const u8,
    };
    
    pub fn init(ptr: *anyopaque, vtable: *const VTable) Self {
        return .{
            .ptr = ptr,
            .vtable = vtable,
        };
    }
    
    pub fn getAppAccessToken(self: Self) ![]const u8 {
        return self.vtable.getAppAccessToken(self.ptr);
    }
    
    pub fn getUserAccessToken(self: Self, code: []const u8) !OAuthTokenResponse {
        return self.vtable.getUserAccessToken(self.ptr, code);
    }
    
    pub fn getUserInfo(self: Self, access_token: []const u8) !OAuthUserInfo {
        return self.vtable.getUserInfo(self.ptr, access_token);
    }
    
    pub fn refreshAccessToken(self: Self, refresh_token: []const u8) !OAuthTokenResponse {
        return self.vtable.refreshAccessToken(self.ptr, refresh_token);
    }
    
    pub fn getProviderName(self: Self) []const u8 {
        return self.vtable.getProviderName(self.ptr);
    }
};

/// OAuth 提供商工厂
pub const OAuthProviderFactory = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) OAuthProviderFactory {
        return .{ .allocator = allocator };
    }
    
    /// 创建提供商实例
    pub fn createProvider(self: *OAuthProviderFactory, provider_name: []const u8) !OAuthProvider {
        _ = self;
        
        if (std.mem.eql(u8, provider_name, "feishu")) {
            // 返回飞书提供商
            // TODO: 实现飞书提供商适配器
            return error.NotImplemented;
        } else if (std.mem.eql(u8, provider_name, "wechat")) {
            // 返回微信提供商
            return error.NotImplemented;
        } else if (std.mem.eql(u8, provider_name, "qq")) {
            // 返回 QQ 提供商
            return error.NotImplemented;
        } else if (std.mem.eql(u8, provider_name, "github")) {
            // 返回 GitHub 提供商
            return error.NotImplemented;
        } else {
            return error.UnsupportedProvider;
        }
    }
};
