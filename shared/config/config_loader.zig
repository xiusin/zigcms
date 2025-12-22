//! 配置加载器模块 - 从 JSON 文件加载配置
//!
//! 本模块提供从 configs/ 目录加载 JSON 配置文件的功能。
//! 支持默认值、环境变量覆盖和配置验证。
//!
//! ## 使用示例
//! ```zig
//! const ConfigLoader = @import("shared/config/config_loader.zig").ConfigLoader;
//!
//! var loader = ConfigLoader.init(allocator, "configs");
//! const config = try loader.loadAll();
//! defer loader.deinit();
//! ```
//!
//! ## 配置文件对应关系 key名称和文件名匹配
//! - api.json → ApiConfig
//! - app.json → AppConfig
//! - domain.json → DomainConfig
//! - infra.json → InfraConfig

const std = @import("std");
const json = std.json;
const SystemConfig = @import("system_config.zig").SystemConfig;
const ApiConfig = @import("system_config.zig").ApiConfig;
const AppConfig = @import("system_config.zig").AppConfig;
const DomainConfig = @import("system_config.zig").DomainConfig;
const InfraConfig = @import("system_config.zig").InfraConfig;

/// 配置加载错误类型
pub const ConfigError = error{
    /// 配置文件解析失败
    ParseError,
    /// 配置值无效
    InvalidValue,
    /// 必需字段缺失
    MissingRequiredField,
    /// 文件读取失败
    FileReadError,
    /// 内存分配失败
    OutOfMemory,
};

/// 配置加载器
///
/// 负责从 TOML 文件加载配置，支持默认值和环境变量覆盖。
pub const ConfigLoader = struct {
    allocator: std.mem.Allocator,
    config_dir: []const u8,
    /// 存储需要释放的字符串
    allocated_strings: std.ArrayList([]const u8),

    const Self = @This();

    /// 初始化配置加载器
    ///
    /// ## 参数
    /// - `allocator`: 内存分配器
    /// - `config_dir`: 配置文件目录路径
    pub fn init(allocator: std.mem.Allocator, config_dir: []const u8) Self {
        return .{
            .allocator = allocator,
            .config_dir = config_dir,
            .allocated_strings = std.ArrayList([]const u8).init(allocator),
        };
    }

    /// 清理配置加载器
    pub fn deinit(self: *Self) void {
        for (self.allocated_strings.items) |str| {
            self.allocator.free(str);
        }
        self.allocated_strings.deinit(self.allocator);
    }

    /// 加载所有配置文件
    ///
    /// 从 configs/ 目录加载所有 TOML 配置文件，
    /// 缺失的文件使用默认值。
    ///
    /// ## 返回
    /// 返回完整的 SystemConfig 结构体
    ///
    /// ## 错误
    /// - ParseError: TOML 解析失败
    /// - InvalidValue: 配置值无效
    pub fn loadAll(self: *Self) !SystemConfig {
        var config = SystemConfig{};

        // 加载各个配置文件，缺失则使用默认值
        config.api = self.loadApiConfig() catch |err| blk: {
            if (err == error.FileNotFound) {
                std.debug.print("⚠️ api.json 未找到，使用默认配置\n", .{});
                break :blk ApiConfig{};
            }
            return err;
        };

        config.app = self.loadAppConfig() catch |err| blk: {
            if (err == error.FileNotFound) {
                std.debug.print("⚠️ app.json 未找到，使用默认配置\n", .{});
                break :blk AppConfig{};
            }
            return err;
        };

        config.domain = self.loadDomainConfig() catch |err| blk: {
            if (err == error.FileNotFound) {
                std.debug.print("⚠️ domain.json 未找到，使用默认配置\n", .{});
                break :blk DomainConfig{};
            }
            return err;
        };

        config.infra = self.loadInfraConfig() catch |err| blk: {
            if (err == error.FileNotFound) {
                std.debug.print("⚠️ infra.json 未找到，使用默认配置\n", .{});
                break :blk InfraConfig{};
            }
            return err;
        };

        // 应用环境变量覆盖
        try self.applyEnvOverrides(&config);

        return config;
    }

    /// 加载 API 配置
    fn loadApiConfig(self: *Self) !ApiConfig {
        const json_value = try self.readJsonConfigFile("api.toml");
        defer json_value.deinit();
        return self.parseConfigFromJson(ApiConfig, json_value);
    }

    /// 加载应用配置
    fn loadAppConfig(self: *Self) !AppConfig {
        const json_value = try self.readJsonConfigFile("app.toml");
        defer json_value.deinit();
        return self.parseConfigFromJson(AppConfig, json_value);
    }

    /// 加载领域配置
    fn loadDomainConfig(self: *Self) !DomainConfig {
        const json_value = try self.readJsonConfigFile("domain.toml");
        defer json_value.deinit();
        return self.parseConfigFromJson(DomainConfig, json_value);
    }

    /// 加载基础设施配置
    fn loadInfraConfig(self: *Self) !InfraConfig {
        const json_value = try self.readJsonConfigFile("infra.toml");
        defer json_value.deinit();
        return self.parseConfigFromJson(InfraConfig, json_value);
    }

    /// 读取并解析JSON配置文件内容
    fn readJsonConfigFile(self: *Self, filename: []const u8) !json.Value {
        const json_filename = try std.fmt.allocPrint(self.allocator, "{s}.json", .{std.fs.path.stem(filename)});
        defer self.allocator.free(json_filename);

        const content = try self.readConfigFile(json_filename);
        defer self.allocator.free(content);

        const parsed = json.parseFromSlice(json.Value, self.allocator, content, .{}) catch {
            return ConfigError.ParseError;
        };
        errdefer parsed.deinit();

        if (parsed.value != .object) {
            parsed.deinit();
            return ConfigError.ParseError;
        }

        return parsed.value;
    }

    /// 通用JSON配置解析函数 - 使用反射扫描结构体字段
    fn parseConfigFromJson(self: *Self, comptime T: type, json_obj: json.Value) !T {
        var config = T{};
        const type_info = @typeInfo(T);

        if (type_info != .@"struct") {
            return ConfigError.ParseError;
        }

        inline for (type_info.@"struct".fields) |field| {
            // 先尝试直接匹配字段名
            if (json_obj.object.get(field.name)) |json_value| {
                @field(config, field.name) = try self.parseJsonField(field.type, json_value);
            } else {
                // 尝试蛇形转驼峰转换
                const camel_name = try self.snakeToCamel(field.name);
                defer self.allocator.free(camel_name);
                if (json_obj.object.get(camel_name)) |json_value| {
                    @field(config, field.name) = try self.parseJsonField(field.type, json_value);
                } else {
                    // 尝试驼峰转蛇形转换
                    const snake_name = try self.camelToSnake(field.name);
                    defer self.allocator.free(snake_name);
                    if (json_obj.object.get(snake_name)) |json_value| {
                        @field(config, field.name) = try self.parseJsonField(field.type, json_value);
                    }
                    // 如果都找不到，使用默认值（结构体已初始化为默认值）
                }
            }
        }

        return config;
    }

    /// 将蛇形命名转换为驼峰命名
    /// db_port -> dbPort
    fn snakeToCamel(self: *Self, name: []const u8) ![]const u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        defer result.deinit();

        var i: usize = 0;
        while (i < name.len) {
            const char = name[i];
            if (char == '_') {
                if (i + 1 < name.len) {
                    i += 1;
                    const next_char = name[i];
                    if (next_char >= 'a' and next_char <= 'z') {
                        try result.append(next_char - 32); // 转换为大写
                    } else {
                        try result.append(next_char);
                    }
                }
            } else {
                try result.append(char);
            }
            i += 1;
        }

        return result.toOwnedSlice();
    }

    /// 将驼峰命名转换为蛇形命名
    /// dbPort -> db_port
    fn camelToSnake(self: *Self, name: []const u8) ![]const u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        defer result.deinit();

        for (name, 0..) |char, i| {
            if (char >= 'A' and char <= 'Z') {
                if (i > 0) {
                    try result.append('_');
                }
                try result.append(char + 32); // 转换为小写
            } else {
                try result.append(char);
            }
        }

        return result.toOwnedSlice();
    }

    /// 解析单个JSON字段值
    fn parseJsonField(self: *Self, comptime FieldType: type, json_value: json.Value) !FieldType {
        const type_info = @typeInfo(FieldType);

        switch (type_info) {
            .bool => return json_value.bool,
            .int => |int_info| {
                _ = int_info; // 标记为已使用

                if (json_value == .integer) {
                    return @intCast(json_value.integer);
                } else if (json_value == .float) {
                    return @intFromFloat(json_value.float);
                } else {
                    return ConfigError.InvalidValue;
                }
            },
            .float => |float_info| {
                _ = float_info; // 标记为已使用

                if (json_value == .float) {
                    return @floatCast(json_value.float);
                } else if (json_value == .integer) {
                    return @floatFromInt(json_value.integer);
                } else {
                    return ConfigError.InvalidValue;
                }
            },
            .pointer => |ptr_info| {
                if (ptr_info.size == .slice and ptr_info.child == u8) {
                    // []const u8
                    if (json_value == .string) {
                        return try self.allocString(json_value.string);
                    } else {
                        return ConfigError.InvalidValue;
                    }
                } else {
                    return ConfigError.InvalidValue;
                }
            },
            .optional => |opt_info| {
                if (json_value == .null) {
                    return null;
                } else {
                    return try self.parseJsonField(opt_info.child, json_value);
                }
            },
            else => {
                return ConfigError.InvalidValue;
            },
        }
    }

    /// 读取配置文件内容
    fn readConfigFile(self: *Self, filename: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.config_dir, filename });
        defer self.allocator.free(path);

        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return error.FileNotFound;
            }
            return ConfigError.FileReadError;
        };
        defer file.close();

        const content = file.readToEndAlloc(self.allocator, 1024 * 1024) catch {
            return ConfigError.FileReadError;
        };

        return content;
    }

    /// 静态解析键值对（不需要 self）
    fn parseKeyValueStatic(line: []const u8) ?struct { key: []const u8, value: []const u8 } {
        const eq_pos = std.mem.indexOf(u8, line, "=") orelse return null;
        const key = std.mem.trim(u8, line[0..eq_pos], " \t");
        var value = std.mem.trim(u8, line[eq_pos + 1 ..], " \t");

        // 移除引号
        if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
            value = value[1 .. value.len - 1];
        }

        return .{ .key = key, .value = value };
    }

    /// 分配并存储字符串
    fn allocString(self: *Self, value: []const u8) ![]const u8 {
        const str = try self.allocator.dupe(u8, value);
        try self.allocated_strings.append(str);
        return str;
    }

    /// 应用环境变量覆盖
    ///
    /// 敏感配置支持通过环境变量覆盖：
    /// - ZIGCMS_DB_HOST: 数据库主机
    /// - ZIGCMS_DB_PORT: 数据库端口
    /// - ZIGCMS_DB_NAME: 数据库名称
    /// - ZIGCMS_DB_USER: 数据库用户
    /// - ZIGCMS_DB_PASSWORD: 数据库密码
    /// - ZIGCMS_DB_POOL_SIZE: 数据库连接池大小
    /// - ZIGCMS_API_HOST: API 监听地址
    /// - ZIGCMS_API_PORT: API 监听端口
    /// - ZIGCMS_CACHE_ENABLED: 是否启用缓存
    /// - ZIGCMS_CACHE_HOST: 缓存主机
    /// - ZIGCMS_CACHE_PORT: 缓存端口
    /// - ZIGCMS_CACHE_TTL: 缓存 TTL
    /// - ZIGCMS_ENABLE_PLUGINS: 是否启用插件
    /// - ZIGCMS_PLUGIN_DIR: 插件目录
    pub fn applyEnvOverrides(self: *Self, sys_config: *SystemConfig) !void {
        // ========================================================================
        // 数据库配置覆盖
        // ========================================================================
        if (std.posix.getenv("ZIGCMS_DB_HOST")) |val| {
            sys_config.infra.db_host = try self.allocString(val);
            std.debug.print("📝 环境变量覆盖: ZIGCMS_DB_HOST = {s}\n", .{val});
        }
        if (std.posix.getenv("ZIGCMS_DB_PORT")) |val| {
            sys_config.infra.db_port = std.fmt.parseInt(u16, val, 10) catch sys_config.infra.db_port;
            std.debug.print("📝 环境变量覆盖: ZIGCMS_DB_PORT = {s}\n", .{val});
        }
        if (std.posix.getenv("ZIGCMS_DB_NAME")) |val| {
            sys_config.infra.db_name = try self.allocString(val);
            std.debug.print("📝 环境变量覆盖: ZIGCMS_DB_NAME = {s}\n", .{val});
        }
        if (std.posix.getenv("ZIGCMS_DB_USER")) |val| {
            sys_config.infra.db_user = try self.allocString(val);
            std.debug.print("📝 环境变量覆盖: ZIGCMS_DB_USER = {s}\n", .{val});
        }
        if (std.posix.getenv("ZIGCMS_DB_PASSWORD")) |val| {
            sys_config.infra.db_password = try self.allocString(val);
            std.debug.print("📝 环境变量覆盖: ZIGCMS_DB_PASSWORD = ****\n", .{});
        }
        if (std.posix.getenv("ZIGCMS_DB_POOL_SIZE")) |val| {
            sys_config.infra.db_pool_size = std.fmt.parseInt(u32, val, 10) catch sys_config.infra.db_pool_size;
            std.debug.print("📝 环境变量覆盖: ZIGCMS_DB_POOL_SIZE = {s}\n", .{val});
        }

        // ========================================================================
        // API 配置覆盖
        // ========================================================================
        if (std.posix.getenv("ZIGCMS_API_HOST")) |val| {
            sys_config.api.host = try self.allocString(val);
            std.debug.print("📝 环境变量覆盖: ZIGCMS_API_HOST = {s}\n", .{val});
        }
        if (std.posix.getenv("ZIGCMS_API_PORT")) |val| {
            sys_config.api.port = std.fmt.parseInt(u16, val, 10) catch sys_config.api.port;
            std.debug.print("📝 环境变量覆盖: ZIGCMS_API_PORT = {s}\n", .{val});
        }

        // ========================================================================
        // 缓存配置覆盖
        // ========================================================================
        if (std.posix.getenv("ZIGCMS_CACHE_ENABLED")) |val| {
            sys_config.infra.cache_enabled = std.mem.eql(u8, val, "true") or std.mem.eql(u8, val, "1");
            std.debug.print("📝 环境变量覆盖: ZIGCMS_CACHE_ENABLED = {s}\n", .{val});
        }
        if (std.posix.getenv("ZIGCMS_CACHE_HOST")) |val| {
            sys_config.infra.cache_host = try self.allocString(val);
            std.debug.print("📝 环境变量覆盖: ZIGCMS_CACHE_HOST = {s}\n", .{val});
        }
        if (std.posix.getenv("ZIGCMS_CACHE_PORT")) |val| {
            sys_config.infra.cache_port = std.fmt.parseInt(u16, val, 10) catch sys_config.infra.cache_port;
            std.debug.print("📝 环境变量覆盖: ZIGCMS_CACHE_PORT = {s}\n", .{val});
        }
        if (std.posix.getenv("ZIGCMS_CACHE_TTL")) |val| {
            sys_config.infra.cache_ttl = std.fmt.parseInt(u64, val, 10) catch sys_config.infra.cache_ttl;
            std.debug.print("📝 环境变量覆盖: ZIGCMS_CACHE_TTL = {s}\n", .{val});
        }

        // ========================================================================
        // 应用配置覆盖
        // ========================================================================
        if (std.posix.getenv("ZIGCMS_ENABLE_PLUGINS")) |val| {
            sys_config.app.enable_plugins = std.mem.eql(u8, val, "true") or std.mem.eql(u8, val, "1");
            std.debug.print("📝 环境变量覆盖: ZIGCMS_ENABLE_PLUGINS = {s}\n", .{val});
        }
        if (std.posix.getenv("ZIGCMS_PLUGIN_DIR")) |val| {
            sys_config.app.plugin_directory = try self.allocString(val);
            std.debug.print("📝 环境变量覆盖: ZIGCMS_PLUGIN_DIR = {s}\n", .{val});
        }
        if (std.posix.getenv("ZIGCMS_ENABLE_CACHE")) |val| {
            sys_config.app.enable_cache = std.mem.eql(u8, val, "true") or std.mem.eql(u8, val, "1");
            std.debug.print("📝 环境变量覆盖: ZIGCMS_ENABLE_CACHE = {s}\n", .{val});
        }
    }

    /// 验证配置
    ///
    /// 验证所有必需字段是否有效。
    ///
    /// ## 错误
    /// - MissingRequiredField: 必需字段缺失
    /// - InvalidValue: 配置值无效
    pub fn validate(self: *Self, config_ptr: *const SystemConfig) !void {
        _ = self;

        // 验证 API 配置
        if (config_ptr.api.port == 0) {
            std.debug.print("❌ 配置错误: API 端口不能为 0\n", .{});
            return ConfigError.InvalidValue;
        }
        if (config_ptr.api.host.len == 0) {
            std.debug.print("❌ 配置错误: API 主机地址不能为空\n", .{});
            return ConfigError.MissingRequiredField;
        }
        if (config_ptr.api.timeout == 0) {
            std.debug.print("❌ 配置错误: API 超时时间不能为 0\n", .{});
            return ConfigError.InvalidValue;
        }
        if (config_ptr.api.max_clients == 0) {
            std.debug.print("❌ 配置错误: 最大客户端数不能为 0\n", .{});
            return ConfigError.InvalidValue;
        }

        // 验证基础设施配置
        if (config_ptr.infra.db_host.len == 0) {
            std.debug.print("❌ 配置错误: 数据库主机地址不能为空\n", .{});
            return ConfigError.MissingRequiredField;
        }
        if (config_ptr.infra.db_port == 0) {
            std.debug.print("❌ 配置错误: 数据库端口不能为 0\n", .{});
            return ConfigError.InvalidValue;
        }
        if (config_ptr.infra.db_name.len == 0) {
            std.debug.print("❌ 配置错误: 数据库名称不能为空\n", .{});
            return ConfigError.MissingRequiredField;
        }
        if (config_ptr.infra.db_user.len == 0) {
            std.debug.print("❌ 配置错误: 数据库用户名不能为空\n", .{});
            return ConfigError.MissingRequiredField;
        }

        // 验证缓存配置
        if (config_ptr.infra.cache_enabled) {
            if (config_ptr.infra.cache_host.len == 0) {
                std.debug.print("❌ 配置错误: 缓存已启用但主机地址为空\n", .{});
                return ConfigError.MissingRequiredField;
            }
            if (config_ptr.infra.cache_port == 0) {
                std.debug.print("❌ 配置错误: 缓存已启用但端口为 0\n", .{});
                return ConfigError.InvalidValue;
            }
        }

        // 验证应用配置
        if (config_ptr.app.enable_plugins) {
            if (config_ptr.app.plugin_directory.len == 0) {
                std.debug.print("❌ 配置错误: 插件已启用但目录为空\n", .{});
                return ConfigError.MissingRequiredField;
            }
        }

        // 验证 HTTP 超时
        if (config_ptr.infra.http_timeout_ms == 0) {
            std.debug.print("❌ 配置错误: HTTP 超时时间不能为 0\n", .{});
            return ConfigError.InvalidValue;
        }

        std.debug.print("✅ 配置验证通过\n", .{});
    }

    /// 验证并返回详细错误信息
    ///
    /// 返回所有验证错误的列表，而不是在第一个错误时停止。
    pub fn validateWithDetails(self: *Self, config_ptr: *const SystemConfig, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
        _ = self;
        var errors_list = std.ArrayList([]const u8).init(allocator);
        errdefer {
            for (errors_list.items) |err| {
                allocator.free(err);
            }
            errors_list.deinit();
        }

        // 验证 API 配置
        if (config_ptr.api.port == 0) {
            try errors_list.append(try allocator.dupe(u8, "API 端口不能为 0"));
        }
        if (config_ptr.api.host.len == 0) {
            try errors_list.append(try allocator.dupe(u8, "API 主机地址不能为空"));
        }

        // 验证基础设施配置
        if (config_ptr.infra.db_host.len == 0) {
            try errors_list.append(try allocator.dupe(u8, "数据库主机地址不能为空"));
        }
        if (config_ptr.infra.db_port == 0) {
            try errors_list.append(try allocator.dupe(u8, "数据库端口不能为 0"));
        }
        if (config_ptr.infra.db_name.len == 0) {
            try errors_list.append(try allocator.dupe(u8, "数据库名称不能为空"));
        }

        return errors_list;
    }
};
