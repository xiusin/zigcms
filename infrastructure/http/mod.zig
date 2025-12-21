//! HTTP 客户端基础设施模块 (HTTP Module)
//!
//! 提供 HTTP 客户端功能，用于与外部 API 交互。
//! 支持各种 HTTP 方法、超时设置、重试机制。
//!
//! ## 功能
//! - HTTP 方法枚举（HttpMethod）
//! - HTTP 请求结构（HttpRequest）
//! - HTTP 响应结构（HttpResponse）
//! - HTTP 客户端接口（HttpClient）
//!
//! ## 使用示例
//! ```zig
//! const http = @import("infrastructure/http/mod.zig");
//!
//! // 发送 GET 请求
//! const response = try client.get("https://api.example.com/users");
//!
//! // 发送 POST 请求
//! const response = try client.post("https://api.example.com/users", body);
//!
//! // 发送自定义请求
//! const response = try client.request(.{
//!     .method = .PUT,
//!     .url = "https://api.example.com/users/1",
//!     .body = body,
//!     .timeout = 30,
//! });
//! ```

const std = @import("std");

/// HTTP 方法
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,
};

/// HTTP 请求
pub const HttpRequest = struct {
    method: HttpMethod,
    url: []const u8,
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8 = null,
    timeout: u64 = 30, // 秒
};

/// HTTP 响应
pub const HttpResponse = struct {
    status: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
};

/// HTTP 客户端接口
pub const HttpClient = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        request: *const fn (*anyopaque, HttpRequest) anyerror!HttpResponse,
        get: *const fn (*anyopaque, []const u8) anyerror!HttpResponse,
        post: *const fn (*anyopaque, []const u8, []const u8) anyerror!HttpResponse,
    };

    pub fn request(self: @This(), req: HttpRequest) !HttpResponse {
        return self.vtable.request(self.ptr, req);
    }

    pub fn get(self: @This(), url: []const u8) !HttpResponse {
        return self.vtable.get(self.ptr, url);
    }

    pub fn post(self: @This(), url: []const u8, body: []const u8) !HttpResponse {
        return self.vtable.post(self.ptr, url, body);
    }
};
