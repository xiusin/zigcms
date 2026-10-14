//! HTTP 服务模块
//!
//! 提供可复用的 HTTP 客户端功能，支持文件上传、Cookie 管理、连接池等。

pub const client = @import("client.zig");
pub const pool = @import("pool.zig");

// 客户端类型
pub const HttpClient = client.HttpClient;
pub const Response = client.Response;
pub const RequestOptions = client.RequestOptions;
pub const RequestBuilder = client.RequestBuilder;
pub const Cookie = client.Cookie;
pub const FormField = client.FormField;
pub const Method = client.Method;

// 连接池类型
pub const ClientPool = pool.ClientPool;
pub const ClientHandle = pool.ClientHandle;
pub const PoolConfig = pool.PoolConfig;
pub const createPool = pool.createPool;
pub const createPoolWithSize = pool.createPoolWithSize;

test {
    _ = client;
    _ = pool;
}
