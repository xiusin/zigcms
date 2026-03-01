//! 参数构建器
//! 用于动态构建 SQL 参数

const std = @import("std");
const Allocator = std.mem.Allocator;
const query_mod = @import("query.zig");

/// 参数构建器
pub const ParamBuilder = struct {
    allocator: Allocator,
    params: std.ArrayListUnmanaged(query_mod.Value),

    pub fn init(allocator: Allocator) ParamBuilder {
        return .{
            .allocator = allocator,
            .params = .{},
        };
    }

    pub fn deinit(self: *ParamBuilder) void {
        for (self.params.items) |param| {
            switch (param) {
                .string_val => |s| self.allocator.free(s),
                else => {},
            }
        }
        self.params.deinit(self.allocator);
    }

    /// 添加参数
    pub fn add(self: *ParamBuilder, val: anytype) !void {
        var param = query_mod.Value.from(val);
        if (param == .string_val) {
            const str_copy = try self.allocator.dupe(u8, param.string_val);
            param = .{ .string_val = str_copy };
        }
        try self.params.append(self.allocator, param);
    }

    /// 添加多个参数
    pub fn addMany(self: *ParamBuilder, vals: anytype) !void {
        const ValsType = @TypeOf(vals);
        const type_info = @typeInfo(ValsType);

        switch (type_info) {
            .pointer => |ptr| {
                if (ptr.size == .slice or @typeInfo(ptr.child) == .array) {
                    for (vals) |v| {
                        try self.add(v);
                    }
                }
            },
            .array => {
                for (vals) |v| {
                    try self.add(v);
                }
            },
            .@"struct" => |s| {
                if (s.is_tuple) {
                    inline for (vals) |v| {
                        try self.add(v);
                    }
                }
            },
            else => {},
        }
    }

    /// 条件添加参数
    pub fn addIf(self: *ParamBuilder, condition: bool, val: anytype) !void {
        if (condition) {
            try self.add(val);
        }
    }

    /// 获取参数切片
    pub fn items(self: *const ParamBuilder) []const query_mod.Value {
        return self.params.items;
    }

    /// 获取参数数量
    pub fn count(self: *const ParamBuilder) usize {
        return self.params.items.len;
    }
};
