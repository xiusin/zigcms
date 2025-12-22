//! 自动生成的配置文件
//! 
//! 此文件由 .env 文件自动生成，请勿手动修改
//! 生成时间: 2025-12-22

pub const PG_DATABASE_HOST: []const u8 = "124.222.103.232";
pub const PG_DATABASE_PORT: u16 = 5432;
pub const PG_DATABASE_USER: []const u8 = "postgres";
pub const PG_DATABASE_PASS: []const u8 = "postgres";
pub const PG_DATABASE_CLIENT_NAME: []const u8 = "zigcms";
pub const PG_DATABASE_POOL_SIZE: u32 = 10;

pub const SERVER_HOST: []const u8 = "localhost";
pub const SERVER_PORT: u16 = 3000;
pub const SERVER_ENV: []const u8 = "development";

pub const CACHE_ENABLED: bool = true;
pub const CACHE_TTL: u32 = 3600;
pub const CACHE_HOST: []const u8 = "127.0.0.1";
pub const CACHE_PORT: u16 = 6379;