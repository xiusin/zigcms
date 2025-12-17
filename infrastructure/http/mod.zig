//! HTTP Client Infrastructure Module
//!
//! HTTP 客户端基础设施层
//!
//! 职责：
//! - 提供统一的 HTTP 客户端接口
//! - 支持各种 HTTP 方法
//! - 处理请求和响应

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
