const std = @import("std");
const json = std.json;

pub const AutoConfigError = error{
    ParseError,
    InvalidValue,
    MissingRequiredField,
    FileReadError,
    OutOfMemory,
};

pub const AutoConfigLoader = struct {
    allocator: std.mem.Allocator,
    config_dir: []const u8,
    allocated_strings: std.ArrayList([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config_dir: []const u8) Self {
        return .{
            .allocator = allocator,
            .config_dir = config_dir,
            .allocated_strings = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.allocated_strings.items) |str| {
            self.allocator.free(str);
        }
        self.allocated_strings.deinit();
    }

    pub fn loadConfig(
        self: *Self,
        comptime T: type,
        filename: []const u8,
    ) !T {
        const content = try self.readConfigFile(filename);
        defer self.allocator.free(content);

        const parsed = json.parseFromSlice(T, self.allocator, content, .{}) catch {
            std.debug.print("❌ 配置解析失败: {s}\n", .{filename});
            return AutoConfigError.ParseError;
        };
        defer parsed.deinit();

        var config = parsed.value;
        try self.copyStringFields(T, &config);

        return config;
    }

    pub fn loadConfigOr(
        self: *Self,
        comptime T: type,
        filename: []const u8,
        default: T,
    ) T {
        return self.loadConfig(T, filename) catch |err| blk: {
            if (err == error.FileNotFound) {
                std.debug.print("⚠️ {s} 未找到，使用默认配置\n", .{filename});
            } else {
                std.debug.print("⚠️ 加载 {s} 失败: {any}，使用默认配置\n", .{ filename, err });
            }
            break :blk default;
        };
    }

    fn copyStringFields(self: *Self, comptime T: type, config: *T) !void {
        const fields = std.meta.fields(T);
        inline for (fields) |field| {
            const field_value = @field(config.*, field.name);

            if (field.type == []const u8) {
                const str = try self.allocString(field_value);
                @field(config, field.name) = str;
            } else if (@typeInfo(field.type) == .optional) {
                const ChildType = @typeInfo(field.type).optional.child;
                if (ChildType == []const u8) {
                    if (field_value) |v| {
                        const str = try self.allocString(v);
                        @field(config, field.name) = str;
                    }
                }
            }
        }
    }

    fn readConfigFile(self: *Self, filename: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}",
            .{ self.config_dir, filename },
        );
        defer self.allocator.free(path);

        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return error.FileNotFound;
            }
            return AutoConfigError.FileReadError;
        };
        defer file.close();

        const content = file.readToEndAlloc(self.allocator, 1024 * 1024) catch {
            return AutoConfigError.FileReadError;
        };

        return content;
    }

    fn allocString(self: *Self, value: []const u8) ![]const u8 {
        const str = try self.allocator.dupe(u8, value);
        try self.allocated_strings.append(str);
        return str;
    }

    pub fn applyEnvOverride(
        self: *Self,
        comptime T: type,
        config: *T,
        field_name: []const u8,
        env_var: []const u8,
    ) !void {
        if (std.posix.getenv(env_var)) |val| {
            const fields = std.meta.fields(T);
            inline for (fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    const field_type = field.type;
                    const type_info = @typeInfo(field_type);

                    if (field_type == []const u8) {
                        @field(config, field.name) = try self.allocString(val);
                    } else if (field_type == u16) {
                        @field(config, field.name) = std.fmt.parseInt(u16, val, 10) catch @field(config, field.name);
                    } else if (field_type == u32) {
                        @field(config, field.name) = std.fmt.parseInt(u32, val, 10) catch @field(config, field.name);
                    } else if (field_type == u64) {
                        @field(config, field.name) = std.fmt.parseInt(u64, val, 10) catch @field(config, field.name);
                    } else if (field_type == bool) {
                        @field(config, field.name) = std.mem.eql(u8, val, "true") or std.mem.eql(u8, val, "1");
                    } else if (type_info == .optional) {
                        const ChildType = type_info.optional.child;
                        if (ChildType == []const u8) {
                            @field(config, field.name) = try self.allocString(val);
                        }
                    }

                    std.debug.print("📝 环境变量覆盖: {s} = {s}\n", .{ env_var, val });
                    return;
                }
            }
        }
    }

    pub fn applyEnvOverrides(
        self: *Self,
        comptime T: type,
        config: *T,
        mappings: []const struct { field: []const u8, env: []const u8 },
    ) !void {
        for (mappings) |mapping| {
            try self.applyEnvOverride(T, config, mapping.field, mapping.env);
        }
    }
};
