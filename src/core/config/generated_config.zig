pub const Config = struct {
    PG_DATABASE_HOST: []const u8 = "124.222.103.232",
    PG_DATABASE_PORT: u16 = 5432,
    PG_DATABASE_USER: []const u8 = "postgres",
    PG_DATABASE_PASS: []const u8 = "postgres",
    PG_DATABASE_CLIENT_NAME: []const u8 = "zigcms",
    PG_DATABASE_POOL_SIZE: u16 = 10,
    
    SERVER_HOST: []const u8 = "localhost",
    SERVER_PORT: u16 = 3000,
    SERVER_ENV: []const u8 = "development",
    
    CACHE_ENABLED: bool = true,
    CACHE_TTL: u32 = 3600,
    CACHE_HOST: []const u8 = "127.0.0.1",
    CACHE_PORT: u16 = 6379,
};

pub const config = Config{};
