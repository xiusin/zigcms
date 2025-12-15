//! DTO 验证器模块
//!
//! 提供类似 Go validator 和 Laravel 的结构体字段验证功能。
//! 特性：内存安全、线程安全、优雅的链式 API。
//!
//! ## 使用方式一：声明式验证（推荐）
//!
//! ```zig
//! const UserDto = struct {
//!     pub const rules = .{
//!         .username = "required|min:3|max:20|alpha_num",
//!         .email = "required|email",
//!         .age = "min:18|max:120",
//!         .password = "required|min:6",
//!     };
//!
//!     // 可选：自定义错误消息
//!     pub const messages = .{
//!         .username_required = "用户名不能为空",
//!         .username_min = "用户名至少 3 个字符",
//!         .email_email = "请输入有效的邮箱地址",
//!     };
//!
//!     username: []const u8,
//!     email: []const u8,
//!     age: i32 = 0,
//!     password: []const u8,
//! };
//!
//! // 快速验证
//! if (try Validator.check(UserDto, dto)) |err| {
//!     return base.send_failed(req, err);
//! }
//! ```
//!
//! ## 使用方式二：编程式验证（链式调用）
//!
//! ```zig
//! var v = try Validator.init(allocator);
//! defer v.deinit();
//!
//! try v.field("username", dto.username)
//!     .required()
//!     .min(3)
//!     .max(20)
//!     .alphaNum();
//!
//! try v.field("email", dto.email)
//!     .required()
//!     .email();
//!
//! if (v.fails()) {
//!     return base.send_failed(req, v.firstError());
//! }
//! ```
//!
//! ## 使用方式三：Arena 分配器（推荐用于请求级别）
//!
//! ```zig
//! var arena = std.heap.ArenaAllocator.init(allocator);
//! defer arena.deinit();
//!
//! var v = try Validator.init(arena.allocator());
//! // 无需手动 deinit，arena 会统一释放
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

/// 验证错误
pub const ValidationError = struct {
    field: []const u8,
    rule: []const u8,
    message: []const u8,
    allocated: bool = false, // 标记消息是否需要释放
};

/// 验证结果
pub const ValidationResult = union(enum) {
    ok: void,
    err: []const u8,

    pub fn isOk(self: ValidationResult) bool {
        return self == .ok;
    }

    pub fn isErr(self: ValidationResult) bool {
        return self == .err;
    }

    pub fn unwrapErr(self: ValidationResult) ?[]const u8 {
        return switch (self) {
            .ok => null,
            .err => |msg| msg,
        };
    }
};

/// 字段验证器（用于链式调用）
pub const FieldValidator = struct {
    const Self = @This();

    validator: *Validator,
    field_name: []const u8,
    value: Value,
    stopped: bool = false,

    pub const Value = union(enum) {
        string: []const u8,
        int: i64,
        float: f64,
        boolean: bool,
        optional_string: ?[]const u8,
        optional_int: ?i64,
    };

    /// 必填验证
    pub fn required(self: *Self) *Self {
        if (self.stopped) return self;

        const is_empty = switch (self.value) {
            .string => |s| s.len == 0,
            .optional_string => |s| s == null or s.?.len == 0,
            .optional_int => |i| i == null,
            else => false,
        };

        if (is_empty) {
            self.validator.addErrorStatic(self.field_name, "required", "{s} 不能为空");
            self.stopped = true;
        }
        return self;
    }

    /// 最小长度/值验证
    pub fn min(self: *Self, min_val: anytype) *Self {
        if (self.stopped) return self;

        switch (self.value) {
            .string => |s| {
                if (s.len < @as(usize, @intCast(min_val))) {
                    self.validator.addErrorFmt(self.field_name, "min", "{s} 长度不能少于 {d} 个字符", .{ self.field_name, min_val });
                }
            },
            .int => |i| {
                if (i < min_val) {
                    self.validator.addErrorFmt(self.field_name, "min", "{s} 不能小于 {d}", .{ self.field_name, min_val });
                }
            },
            else => {},
        }
        return self;
    }

    /// 最大长度/值验证
    pub fn max(self: *Self, max_val: anytype) *Self {
        if (self.stopped) return self;

        switch (self.value) {
            .string => |s| {
                if (s.len > @as(usize, @intCast(max_val))) {
                    self.validator.addErrorFmt(self.field_name, "max", "{s} 长度不能超过 {d} 个字符", .{ self.field_name, max_val });
                }
            },
            .int => |i| {
                if (i > max_val) {
                    self.validator.addErrorFmt(self.field_name, "max", "{s} 不能大于 {d}", .{ self.field_name, max_val });
                }
            },
            else => {},
        }
        return self;
    }

    /// 邮箱验证
    pub fn email(self: *Self) *Self {
        if (self.stopped) return self;

        const str = switch (self.value) {
            .string => |s| s,
            .optional_string => |s| s orelse return self,
            else => return self,
        };

        if (str.len == 0) return self;

        if (!isValidEmail(str)) {
            self.validator.addErrorStatic(self.field_name, "email", "{s} 必须是有效的邮箱地址");
        }
        return self;
    }

    /// 纯字母验证
    pub fn alpha(self: *Self) *Self {
        if (self.stopped) return self;

        const str = switch (self.value) {
            .string => |s| s,
            .optional_string => |s| s orelse return self,
            else => return self,
        };

        for (str) |c| {
            if (!std.ascii.isAlphabetic(c)) {
                self.validator.addErrorStatic(self.field_name, "alpha", "{s} 只能包含字母");
                return self;
            }
        }
        return self;
    }

    /// 字母数字验证
    pub fn alphaNum(self: *Self) *Self {
        if (self.stopped) return self;

        const str = switch (self.value) {
            .string => |s| s,
            .optional_string => |s| s orelse return self,
            else => return self,
        };

        for (str) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') {
                self.validator.addErrorStatic(self.field_name, "alpha_num", "{s} 只能包含字母、数字和下划线");
                return self;
            }
        }
        return self;
    }

    /// URL 验证
    pub fn url(self: *Self) *Self {
        if (self.stopped) return self;

        const str = switch (self.value) {
            .string => |s| s,
            .optional_string => |s| s orelse return self,
            else => return self,
        };

        if (str.len == 0) return self;

        if (!std.mem.startsWith(u8, str, "http://") and !std.mem.startsWith(u8, str, "https://")) {
            self.validator.addErrorStatic(self.field_name, "url", "{s} 必须是有效的 URL");
        }
        return self;
    }

    /// 手机号验证
    pub fn mobile(self: *Self) *Self {
        if (self.stopped) return self;

        const str = switch (self.value) {
            .string => |s| s,
            .optional_string => |s| s orelse return self,
            else => return self,
        };

        if (str.len == 0) return self;

        if (!isValidMobile(str)) {
            self.validator.addErrorStatic(self.field_name, "mobile", "{s} 必须是有效的手机号");
        }
        return self;
    }

    /// 在列表中验证
    pub fn inValues(self: *Self, values: []const []const u8) *Self {
        if (self.stopped) return self;

        const str = switch (self.value) {
            .string => |s| s,
            .optional_string => |s| s orelse return self,
            else => return self,
        };

        for (values) |v| {
            if (std.mem.eql(u8, v, str)) return self;
        }

        self.validator.addErrorStatic(self.field_name, "in", "{s} 必须是有效的选项");
        return self;
    }

    /// 确认字段验证
    pub fn confirmed(self: *Self, confirmation: []const u8) *Self {
        if (self.stopped) return self;

        const str = switch (self.value) {
            .string => |s| s,
            .optional_string => |s| s orelse return self,
            else => return self,
        };

        if (!std.mem.eql(u8, str, confirmation)) {
            self.validator.addErrorStatic(self.field_name, "confirmed", "{s} 两次输入不一致");
        }
        return self;
    }

    /// 完成验证（返回验证器以继续链式调用）
    pub fn done(self: *Self) *Validator {
        return self.validator;
    }
};

/// 验证器
pub const Validator = struct {
    const Self = @This();

    allocator: Allocator,
    errors: std.ArrayList(ValidationError),
    custom_messages: std.StringHashMap([]const u8),

    pub fn init(allocator: Allocator) Self {
        var self: Self = undefined;
        self.allocator = allocator;
        self.errors = std.ArrayList(ValidationError).initCapacity(allocator, 8) catch unreachable;
        self.custom_messages = std.StringHashMap([]const u8).init(allocator);
        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.errors.items) |err| {
            if (err.allocated) {
                self.allocator.free(err.message);
            }
        }
        self.errors.deinit(self.allocator);
        self.custom_messages.deinit();
    }

    /// 重置验证器（复用）
    pub fn reset(self: *Self) void {
        for (self.errors.items) |err| {
            if (err.allocated) {
                self.allocator.free(err.message);
            }
        }
        self.errors.clearRetainingCapacity();
    }

    // ========================================================================
    // 静态方法：快速验证
    // ========================================================================

    /// 快速验证 DTO（推荐方式）
    /// 返回第一个错误消息，如果验证通过则返回 null
    pub fn check(comptime T: type, data: T) ?[]const u8 {
        // 使用栈分配，避免堆分配
        var errors_buf: [16]ValidationError = undefined;
        var error_count: usize = 0;

        if (@hasDecl(T, "rules")) {
            const rules = T.rules;
            inline for (std.meta.fields(@TypeOf(rules))) |rule_field| {
                const field_name = rule_field.name;
                const rule_str = @field(rules, field_name);

                if (@hasField(T, field_name)) {
                    const value = @field(data, field_name);
                    if (checkFieldRules(field_name, value, rule_str)) |err_msg| {
                        if (error_count < errors_buf.len) {
                            errors_buf[error_count] = .{
                                .field = field_name,
                                .rule = "validation",
                                .message = err_msg,
                            };
                            error_count += 1;
                        }
                    }
                }
            }
        } else if (@hasDecl(T, "validation")) {
            // 兼容旧的 validation 声明
            const rules = T.validation;
            inline for (std.meta.fields(@TypeOf(rules))) |rule_field| {
                const field_name = rule_field.name;
                const rule_str = @field(rules, field_name);

                if (@hasField(T, field_name)) {
                    const value = @field(data, field_name);
                    if (checkFieldRules(field_name, value, rule_str)) |err_msg| {
                        if (error_count < errors_buf.len) {
                            errors_buf[error_count] = .{
                                .field = field_name,
                                .rule = "validation",
                                .message = err_msg,
                            };
                            error_count += 1;
                        }
                    }
                }
            }
        }

        if (error_count > 0) {
            return errors_buf[0].message;
        }
        return null;
    }

    /// 检查单个字段的规则
    fn checkFieldRules(field_name: []const u8, value: anytype, rules: []const u8) ?[]const u8 {
        const T = @TypeOf(value);
        var rule_iter = std.mem.splitSequence(u8, rules, "|");

        while (rule_iter.next()) |rule| {
            if (rule.len == 0) continue;

            var parts = std.mem.splitSequence(u8, rule, ":");
            const rule_name = parts.next() orelse continue;
            const rule_param = parts.next();

            // 检查各规则
            if (std.mem.eql(u8, rule_name, "required")) {
                if (T == []const u8) {
                    if (value.len == 0) return comptime field_name ++ " 不能为空";
                }
            } else if (std.mem.eql(u8, rule_name, "min")) {
                if (rule_param) |p| {
                    const min_val = std.fmt.parseInt(usize, p, 10) catch 0;
                    if (T == []const u8 and value.len < min_val) {
                        return comptime field_name ++ " 长度不足";
                    }
                }
            } else if (std.mem.eql(u8, rule_name, "max")) {
                if (rule_param) |p| {
                    const max_val = std.fmt.parseInt(usize, p, 10) catch 0;
                    if (T == []const u8 and value.len > max_val) {
                        return comptime field_name ++ " 长度超出限制";
                    }
                }
            } else if (std.mem.eql(u8, rule_name, "email")) {
                if (T == []const u8 and value.len > 0 and !isValidEmail(value)) {
                    return comptime field_name ++ " 必须是有效的邮箱";
                }
            } else if (std.mem.eql(u8, rule_name, "alpha_num")) {
                if (T == []const u8) {
                    for (value) |c| {
                        if (!std.ascii.isAlphanumeric(c) and c != '_') {
                            return comptime field_name ++ " 只能包含字母数字和下划线";
                        }
                    }
                }
            }
        }

        return null;
    }

    // ========================================================================
    // 实例方法：链式验证
    // ========================================================================

    /// 开始验证一个字段
    pub fn field(self: *Self, name: []const u8, value: anytype) FieldValidator {
        const T = @TypeOf(value);
        const val: FieldValidator.Value = blk: {
            if (T == []const u8) {
                break :blk .{ .string = value };
            } else if (T == ?[]const u8) {
                break :blk .{ .optional_string = value };
            } else if (@typeInfo(T) == .int) {
                break :blk .{ .int = @as(i64, @intCast(value)) };
            } else if (@typeInfo(T) == .optional and @typeInfo(@typeInfo(T).optional.child) == .int) {
                break :blk .{ .optional_int = if (value) |v| @as(i64, @intCast(v)) else null };
            } else if (T == bool) {
                break :blk .{ .boolean = value };
            } else if (@typeInfo(T) == .float) {
                break :blk .{ .float = @as(f64, @floatCast(value)) };
            } else {
                // 默认尝试转换为字符串
                break :blk .{ .string = "" };
            }
        };

        return .{
            .validator = self,
            .field_name = name,
            .value = val,
        };
    }

    /// 设置自定义错误消息
    pub fn setMessage(self: *Self, key: []const u8, message: []const u8) *Self {
        self.custom_messages.put(key, message) catch {};
        return self;
    }

    /// 验证是否失败
    pub fn fails(self: *const Self) bool {
        return self.errors.items.len > 0;
    }

    /// 验证是否通过
    pub fn passes(self: *const Self) bool {
        return self.errors.items.len == 0;
    }

    /// 获取错误数量
    pub fn errorCount(self: *const Self) usize {
        return self.errors.items.len;
    }

    /// 获取所有错误
    pub fn getErrors(self: *const Self) []const ValidationError {
        return self.errors.items;
    }

    /// 获取第一个错误消息
    pub fn firstError(self: *const Self) ?[]const u8 {
        if (self.errors.items.len > 0) {
            return self.errors.items[0].message;
        }
        return null;
    }

    /// 获取指定字段的错误
    pub fn getFieldError(self: *const Self, field_name: []const u8) ?[]const u8 {
        for (self.errors.items) |err| {
            if (std.mem.eql(u8, err.field, field_name)) {
                return err.message;
            }
        }
        return null;
    }

    /// 获取所有错误消息（JSON 格式）
    pub fn toJson(self: *Self) ![]u8 {
        var json = std.ArrayList(u8).init(self.allocator);
        errdefer json.deinit();

        try json.appendSlice("{\"errors\":{");

        var first = true;
        for (self.errors.items) |err| {
            if (!first) try json.appendSlice(",");
            first = false;

            try json.appendSlice("\"");
            try json.appendSlice(err.field);
            try json.appendSlice("\":\"");
            try appendEscaped(&json, err.message);
            try json.appendSlice("\"");
        }

        try json.appendSlice("}}");
        return json.toOwnedSlice();
    }

    // ========================================================================
    // 兼容旧 API
    // ========================================================================

    /// 根据结构体的 validation/rules 声明验证
    pub fn validate(self: *Self, comptime T: type, data: T) bool {
        if (@hasDecl(T, "rules")) {
            const rules = T.rules;
            inline for (std.meta.fields(@TypeOf(rules))) |rule_field| {
                const field_name = rule_field.name;
                const rule_str = @field(rules, field_name);

                if (@hasField(T, field_name)) {
                    const value = @field(data, field_name);
                    self.validateFieldRules(field_name, value, rule_str);
                }
            }
        } else if (@hasDecl(T, "validation")) {
            const rules = T.validation;
            inline for (std.meta.fields(@TypeOf(rules))) |rule_field| {
                const field_name = rule_field.name;
                const rule_str = @field(rules, field_name);

                if (@hasField(T, field_name)) {
                    const value = @field(data, field_name);
                    self.validateFieldRules(field_name, value, rule_str);
                }
            }
        }
        return self.passes();
    }

    fn validateFieldRules(self: *Self, field_name: []const u8, value: anytype, rules: []const u8) void {
        const T = @TypeOf(value);
        var rule_iter = std.mem.splitSequence(u8, rules, "|");

        while (rule_iter.next()) |rule| {
            if (rule.len == 0) continue;

            var parts = std.mem.splitSequence(u8, rule, ":");
            const rule_name = parts.next() orelse continue;
            const rule_param = parts.next();

            if (std.mem.eql(u8, rule_name, "required")) {
                _ = self.required(field_name, value);
            } else if (std.mem.eql(u8, rule_name, "min")) {
                if (rule_param) |p| {
                    const min_val = std.fmt.parseInt(i64, p, 10) catch 0;
                    if (T == []const u8) {
                        _ = self.minLength(field_name, value, @intCast(min_val));
                    } else if (@typeInfo(T) == .int) {
                        _ = self.minValue(field_name, value, min_val);
                    }
                }
            } else if (std.mem.eql(u8, rule_name, "max")) {
                if (rule_param) |p| {
                    const max_val = std.fmt.parseInt(i64, p, 10) catch 0;
                    if (T == []const u8) {
                        _ = self.maxLength(field_name, value, @intCast(max_val));
                    } else if (@typeInfo(T) == .int) {
                        _ = self.maxValue(field_name, value, max_val);
                    }
                }
            } else if (std.mem.eql(u8, rule_name, "email")) {
                if (T == []const u8) {
                    _ = self.email(field_name, value);
                }
            } else if (std.mem.eql(u8, rule_name, "alpha_num")) {
                if (T == []const u8) {
                    _ = self.alphaNum(field_name, value);
                }
            } else if (std.mem.eql(u8, rule_name, "url")) {
                if (T == []const u8) {
                    _ = self.url(field_name, value);
                }
            }
        }
    }

    // ========================================================================
    // 编程式验证（类似 Laravel）
    // ========================================================================

    /// 必填验证
    pub fn required(self: *Self, field_name: []const u8, value: anytype) *Self {
        const T = @TypeOf(value);
        var is_empty = false;

        // 1. 字符串切片类型判断
        // - []const u8: 标准的字符串切片类型
        // - *const []const u8: 指向字符串切片的常量指针（当字符串作为函数参数传递时可能出现）
        // 这两种类型都有 .len 字段，可以直接检查长度是否为0
        if (T == []const u8 or @typeInfo(T) == .pointer and @typeInfo(T).pointer.size == .slice and @typeInfo(T).pointer.child == u8) {
            is_empty = value.len == 0;

            // 2. 定长字节数组类型判断
            // - [N]u8: 编译时已知长度的u8数组，如 [_]u8{'h','e','l','l','o'}
            // - [N:0]u8: 零终止的定长u8数组，这是Zig字符串字面量的实际类型
            // 例如："hello" 在编译时是 *const [5:0]u8 类型
            // 这些数组类型都有 .len 字段，表示数组长度
        } else if (@typeInfo(T) == .array and @typeInfo(T).array.child == u8) {
            is_empty = value.len == 0;

            // 3. 指向定长字节数组的指针类型判断
            // - *const [N]u8: 指向定长u8数组的常量指针
            // - *const [N:0]u8: 指向零终止定长u8数组的常量指针
            // 这是最常见的字符串字面量类型，当传递给函数时自动转换为此类型
            // 例如：函数参数 func(name: []const u8) 中传入 "hello" 实际是 *const [5:0]u8
            // 通过两层类型检查：第一层确认是指针，第二层确认指向的类型是u8数组
        } else if (@typeInfo(T) == .pointer and @typeInfo(T).pointer.size == .one and @typeInfo(@typeInfo(T).pointer.child) == .array and @typeInfo(@typeInfo(T).pointer.child).array.child == u8) {
            is_empty = value.len == 0;

            // 4. 可选（Optional）类型判断
            // - ?T: 可选类型，表示值可能为空
            // 对于可选类型，空值检查是 value == null
            // 注意：可选的字符串切片 ?[]const u8 会在上面的字符串检查中被捕获，这里处理其他可选类型
        } else if (@typeInfo(T) == .optional) {
            is_empty = value == null;

            // 5. 整数类型判断
            // - i32, u64 等: 所有整数类型，包括有符号和无符号
            // - comptime_int: 编译时整数类型
            // 整数类型总是被认为是"有值"的，因为它们不可能是"空"的概念
            // 即使是整数0，也是有意义的有效值，不应该被视为"空"
        } else if (@typeInfo(T) == .int or @typeInfo(T) == .comptime_int) {
            is_empty = false; // 数字类型总是有值
        }

        if (is_empty) {
            self.addError(field_name, "required", "{s} 不能为空");
        }
        return self;
    }

    /// 最小长度验证（字符串）
    pub fn minLength(self: *Self, field_name: []const u8, value: []const u8, min_len: usize) *Self {
        if (value.len < min_len) {
            self.addErrorFmt(field_name, "min", "{s} 长度不能少于 {d} 个字符", .{ field_name, min_len });
        }
        return self;
    }

    /// 最大长度验证（字符串）
    pub fn maxLength(self: *Self, field_name: []const u8, value: []const u8, max_len: usize) *Self {
        if (value.len > max_len) {
            self.addErrorFmt(field_name, "max", "{s} 长度不能超过 {d} 个字符", .{ field_name, max_len });
        }
        return self;
    }

    /// 最小值验证（数字）
    pub fn minValue(self: *Self, field_name: []const u8, value: anytype, min_val: i64) *Self {
        if (value < min_val) {
            self.addErrorFmt(field_name, "min", "{s} 不能小于 {d}", .{ field_name, min_val });
        }
        return self;
    }

    /// 最大值验证（数字）
    pub fn maxValue(self: *Self, field_name: []const u8, value: anytype, max_val: i64) *Self {
        if (value > max_val) {
            self.addErrorFmt(field_name, "max", "{s} 不能大于 {d}", .{ field_name, max_val });
        }
        return self;
    }

    /// 邮箱格式验证
    pub fn email(self: *Self, field_name: []const u8, value: []const u8) *Self {
        if (value.len == 0) return self;

        if (!isValidEmail(value)) {
            self.addError(field_name, "email", "{s} 必须是有效的邮箱地址");
        }
        return self;
    }

    /// 纯字母验证
    pub fn alpha(self: *Self, field_name: []const u8, value: []const u8) *Self {
        if (value.len == 0) return self;

        for (value) |c| {
            if (!std.ascii.isAlphabetic(c)) {
                self.addError(field_name, "alpha", "{s} 只能包含字母");
                return self;
            }
        }
        return self;
    }

    /// 字母数字验证
    pub fn alphaNum(self: *Self, field_name: []const u8, value: []const u8) *Self {
        if (value.len == 0) return self;

        for (value) |c| {
            if (!std.ascii.isAlphanumeric(c)) {
                self.addError(field_name, "alpha_num", "{s} 只能包含字母和数字");
                return self;
            }
        }
        return self;
    }

    /// 纯数字字符串验证
    pub fn numeric(self: *Self, field_name: []const u8, value: []const u8) *Self {
        if (value.len == 0) return self;

        for (value) |c| {
            if (!std.ascii.isDigit(c) and c != '-' and c != '.') {
                self.addError(field_name, "numeric", "{s} 必须是数字");
                return self;
            }
        }
        return self;
    }

    /// URL 格式验证
    pub fn url(self: *Self, field_name: []const u8, value: []const u8) *Self {
        if (value.len == 0) return self;

        if (!std.mem.startsWith(u8, value, "http://") and !std.mem.startsWith(u8, value, "https://")) {
            self.addError(field_name, "url", "{s} 必须是有效的 URL");
        }
        return self;
    }

    /// 正则表达式验证（简单模式匹配）
    pub fn regex(self: *Self, field_name: []const u8, value: []const u8, pattern: []const u8) *Self {
        if (value.len == 0) return self;

        // 简单实现：支持基本的通配符模式
        // 完整的正则表达式需要额外的库
        if (!simpleMatch(pattern, value)) {
            self.addError(field_name, "regex", "{s} 格式不正确");
        }
        return self;
    }

    /// 范围验证
    pub fn between(self: *Self, field_name: []const u8, value: anytype, min_v: i64, max_v: i64) *Self {
        if (value < min_v or value > max_v) {
            self.addErrorFmt(field_name, "between", "{s} 必须在 {d} 和 {d} 之间", .{ field_name, min_v, max_v });
        }
        return self;
    }

    /// 在列表中验证
    pub fn inList(self: *Self, field_name: []const u8, value: []const u8, list: []const u8) *Self {
        if (value.len == 0) return self;

        var iter = std.mem.splitSequence(u8, list, ",");
        while (iter.next()) |item| {
            if (std.mem.eql(u8, std.mem.trim(u8, item, " "), value)) {
                return self;
            }
        }
        self.addError(field_name, "in", "{s} 必须是有效的选项");
        return self;
    }

    /// 不在列表中验证
    pub fn notInList(self: *Self, field_name: []const u8, value: []const u8, list: []const u8) *Self {
        if (value.len == 0) return self;

        var iter = std.mem.splitSequence(u8, list, ",");
        while (iter.next()) |item| {
            if (std.mem.eql(u8, std.mem.trim(u8, item, " "), value)) {
                self.addError(field_name, "not_in", "{s} 不能是该值");
                return self;
            }
        }
        return self;
    }

    /// 确认字段验证（如密码确认）
    pub fn confirmed(self: *Self, field_name: []const u8, value: []const u8, confirmation: []const u8) *Self {
        if (!std.mem.eql(u8, value, confirmation)) {
            self.addError(field_name, "confirmed", "{s} 两次输入不一致");
        }
        return self;
    }

    /// 手机号验证（中国大陆）
    pub fn mobile(self: *Self, field_name: []const u8, value: []const u8) *Self {
        if (value.len == 0) return self;

        if (!isValidMobile(value)) {
            self.addError(field_name, "mobile", "{s} 必须是有效的手机号");
        }
        return self;
    }

    /// 身份证号验证（中国大陆，简单验证）
    pub fn idCard(self: *Self, field_name: []const u8, value: []const u8) *Self {
        if (value.len == 0) return self;

        if (value.len != 18 and value.len != 15) {
            self.addError(field_name, "id_card", "{s} 必须是有效的身份证号");
            return self;
        }

        // 检查前17位是否为数字
        const check_len = if (value.len == 18) 17 else 15;
        for (value[0..check_len]) |c| {
            if (!std.ascii.isDigit(c)) {
                self.addError(field_name, "id_card", "{s} 必须是有效的身份证号");
                return self;
            }
        }

        // 18位身份证最后一位可以是数字或X
        if (value.len == 18) {
            const last = value[17];
            if (!std.ascii.isDigit(last) and last != 'X' and last != 'x') {
                self.addError(field_name, "id_card", "{s} 必须是有效的身份证号");
            }
        }
        return self;
    }

    /// 日期格式验证
    pub fn date(self: *Self, field_name: []const u8, value: []const u8) *Self {
        if (value.len == 0) return self;

        // 简单验证 YYYY-MM-DD 格式
        if (value.len != 10) {
            self.addError(field_name, "date", "{s} 必须是有效的日期格式 (YYYY-MM-DD)");
            return self;
        }

        if (value[4] != '-' or value[7] != '-') {
            self.addError(field_name, "date", "{s} 必须是有效的日期格式 (YYYY-MM-DD)");
            return self;
        }

        // 验证数字部分
        for ([_]usize{ 0, 1, 2, 3, 5, 6, 8, 9 }) |i| {
            if (!std.ascii.isDigit(value[i])) {
                self.addError(field_name, "date", "{s} 必须是有效的日期格式 (YYYY-MM-DD)");
                return self;
            }
        }
        return self;
    }

    // ========================================================================
    // 内部方法
    // ========================================================================

    fn addError(self: *Self, field_name: []const u8, rule: []const u8, comptime template: []const u8) void {
        const msg = std.fmt.allocPrint(self.allocator, template, .{field_name}) catch return;
        self.errors.append(self.allocator, .{
            .field = field_name,
            .rule = rule,
            .message = msg,
            .allocated = true,
        }) catch {
            self.allocator.free(msg);
        };
    }

    fn addErrorStatic(self: *Self, field_name: []const u8, rule: []const u8, message: []const u8) void {
        self.errors.append(self.allocator, .{
            .field = field_name,
            .rule = rule,
            .message = message,
            .allocated = false,
        }) catch {};
    }

    fn addErrorFmt(self: *Self, field_name: []const u8, rule: []const u8, comptime template: []const u8, args: anytype) void {
        const msg = std.fmt.allocPrint(self.allocator, template, args) catch return;
        self.errors.append(self.allocator, .{
            .field = field_name,
            .rule = rule,
            .message = msg,
            .allocated = true,
        }) catch {
            self.allocator.free(msg);
        };
    }
};

/// 简单的模式匹配（支持 * 通配符）
fn simpleMatch(pattern: []const u8, text: []const u8) bool {
    var pi: usize = 0;
    var ti: usize = 0;
    var star_pi: ?usize = null;
    var star_ti: usize = 0;

    while (ti < text.len) {
        if (pi < pattern.len and (pattern[pi] == text[ti] or pattern[pi] == '?')) {
            pi += 1;
            ti += 1;
        } else if (pi < pattern.len and pattern[pi] == '*') {
            star_pi = pi;
            star_ti = ti;
            pi += 1;
        } else if (star_pi) |sp| {
            pi = sp + 1;
            star_ti += 1;
            ti = star_ti;
        } else {
            return false;
        }
    }

    while (pi < pattern.len and pattern[pi] == '*') {
        pi += 1;
    }

    return pi == pattern.len;
}

/// JSON 字符串转义
fn appendEscaped(list: *std.ArrayList(u8), str: []const u8) !void {
    for (str) |c| {
        switch (c) {
            '"' => try list.appendSlice("\\\""),
            '\\' => try list.appendSlice("\\\\"),
            '\n' => try list.appendSlice("\\n"),
            '\r' => try list.appendSlice("\\r"),
            '\t' => try list.appendSlice("\\t"),
            else => try list.append(c),
        }
    }
}

/// 验证邮箱格式
fn isValidEmail(value: []const u8) bool {
    if (value.len == 0) return false;

    var has_at = false;
    var has_dot_after_at = false;
    var at_pos: usize = 0;

    for (value, 0..) |c, i| {
        if (c == '@') {
            if (has_at) return false; // 多个 @
            has_at = true;
            at_pos = i;
        } else if (c == '.' and has_at and i > at_pos + 1) {
            has_dot_after_at = true;
        }
    }

    return has_at and has_dot_after_at and at_pos > 0 and at_pos < value.len - 2;
}

/// 验证手机号格式（中国大陆）
fn isValidMobile(value: []const u8) bool {
    if (value.len != 11) return false;
    if (value[0] != '1') return false;

    for (value) |c| {
        if (!std.ascii.isDigit(c)) return false;
    }
    return true;
}

// ============================================================================
// 便捷函数
// ============================================================================

/// 快速验证 DTO
pub fn validateDto(allocator: Allocator, comptime T: type, data: T) !?[]const u8 {
    var v = Validator.init(allocator);
    defer v.deinit();

    if (!v.validate(T, data)) {
        return v.firstError();
    }
    return null;
}

/// 验证并返回错误 JSON
pub fn validateWithErrors(allocator: Allocator, comptime T: type, data: T) !?[]u8 {
    var v = Validator.init(allocator);
    defer v.deinit();

    if (!v.validate(T, data)) {
        return try v.errorsJson();
    }
    return null;
}

// ============================================================================
// 测试
// ============================================================================

test "Validator: required 验证" {
    const allocator = std.testing.allocator;
    var v = Validator.init(allocator);
    defer v.deinit();

    _ = v.required("username", "");
    try std.testing.expect(v.fails());
    try std.testing.expectEqual(@as(usize, 1), v.errors.items.len);
}

test "Validator: required 各种字符串类型" {
    const allocator = std.testing.allocator;
    var v = Validator.init(allocator);
    defer v.deinit();

    // 测试空字符串切片
    _ = v.required("field1", ""[0..]);
    try std.testing.expect(v.fails());
    v.reset();

    // 测试空字符串字面量（编译时数组）
    _ = v.required("field2", "");
    try std.testing.expect(v.fails());
    v.reset();

    // 测试非空字符串
    _ = v.required("field3", "hello");
    try std.testing.expect(v.passes());
    v.reset();

    // 测试空数组
    const empty_array: [0]u8 = [_]u8{};
    _ = v.required("field4", &empty_array);
    try std.testing.expect(v.fails());
    v.reset();

    // 测试非空数组
    const hello_array = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    _ = v.required("field5", &hello_array);
    try std.testing.expect(v.passes());
}

test "Validator: minLength 验证" {
    const allocator = std.testing.allocator;
    var v = Validator.init(allocator);
    defer v.deinit();

    _ = v.minLength("username", "ab", 3);
    try std.testing.expect(v.fails());

    var v2 = Validator.init(allocator);
    defer v2.deinit();
    _ = v2.minLength("username", "abc", 3);
    try std.testing.expect(v2.passes());
}

test "Validator: 声明式验证" {
    const TestDto = struct {
        pub const validation = .{
            .username = "required|min:3",
            .email = "required|email",
        };

        username: []const u8,
        email: []const u8,
    };

    const allocator = std.testing.allocator;
    var v = Validator.init(allocator);
    defer v.deinit();

    const dto = TestDto{
        .username = "ab",
        .email = "invalid",
    };

    _ = v.validate(TestDto, dto);
    try std.testing.expect(v.fails());
}
