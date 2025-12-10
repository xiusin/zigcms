//! 字典创建数据传输对象
//!
//! 用于创建字典实体的数据结构

const std = @import("std");

pub const DictCreateDto = struct {
    dict_type: []const u8,
    dict_label: []const u8,
    dict_value: []const u8,
    dict_desc: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 1,
    remark: []const u8 = "",
};