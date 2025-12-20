//! 字典更新数据传输对象
//!
//! 用于更新字典实体的数据结构

const std = @import("std");

pub const DictUpdateDto = struct {
    id: ?i32 = null,
    dict_type: ?[]const u8 = null,
    dict_label: ?[]const u8 = null,
    dict_value: ?[]const u8 = null,
    dict_desc: ?[]const u8 = null,
    sort: ?i32 = null,
    status: ?i32 = null,
    remark: ?[]const u8 = null,
};
