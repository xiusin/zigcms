//! 自动生成的配置结构 - 从 .env 文件生成
//!
//! 警告: 此文件由 config-gen 工具自动生成，请勿手动修改
//! 重新生成: zig build config-gen

const std = @import("std");

/// Cache 配置
pub const CacheConfig = struct {
    /// CACHE_PORT = 6379
    c_a_c_h_e__p_o_r_t: i32 = 6379,
    /// CACHE_ENABLED = true
    c_a_c_h_e__e_n_a_b_l_e_d: bool = true,
    /// CACHE_HOST = 127.0.0.1
    c_a_c_h_e__h_o_s_t: []const u8 = "127.0.0.1",
    /// CACHE_TTL = 3600
    c_a_c_h_e__t_t_l: i32 = 3600,
};

/// Database 配置
pub const DatabaseConfig = struct {
    /// PG_DATABASE_PORT = 5432
    p_g__d_a_t_a_b_a_s_e__p_o_r_t: i32 = 5432,
    /// PG_DATABASE_PASS = postgres
    p_g__d_a_t_a_b_a_s_e__p_a_s_s: []const u8 = "postgres",
    /// PG_DATABASE_CLIENT_NAME = zigcms
    p_g__d_a_t_a_b_a_s_e__c_l_i_e_n_t__n_a_m_e: []const u8 = "zigcms",
    /// PG_DATABASE_HOST = 124.222.103.232
    p_g__d_a_t_a_b_a_s_e__h_o_s_t: []const u8 = "124.222.103.232",
    /// PG_DATABASE_USER = postgres
    p_g__d_a_t_a_b_a_s_e__u_s_e_r: []const u8 = "postgres",
    /// PG_DATABASE_POOL_SIZE = 10
    p_g__d_a_t_a_b_a_s_e__p_o_o_l__s_i_z_e: i32 = 10,
};

/// Server 配置
pub const ServerConfig = struct {
    /// SERVER_HOST = localhost
    s_e_r_v_e_r__h_o_s_t: []const u8 = "localhost",
    /// SERVER_ENV = development
    s_e_r_v_e_r__e_n_v: []const u8 = "development",
    /// SERVER_PORT = 3000
    s_e_r_v_e_r__p_o_r_t: i32 = 3000,
};

/// 主配置结构
pub const Config = struct {
    cache: CacheConfig = .{},
    database: DatabaseConfig = .{},
    server: ServerConfig = .{},

    /// 从环境变量加载配置（运行时）
    pub fn loadFromEnvironment(allocator: std.mem.Allocator) !Config {
        _ = allocator;
        // TODO: 实现运行时环境变量加载
        return .{};
    }
};
