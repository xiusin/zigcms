//! 字典响应数据传输对象
//!
//! 用于返回字典实体的数据结构

const std = @import("std");

pub const DictResponseDto = struct {
    id: ?i32 = null,
    dict_type: []const u8,
    dict_label: []const u8,
    dict_value: []const u8,
    dict_desc: []const u8,
    sort: i32,
    status: i32,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    remark: []const u8 = "",
};