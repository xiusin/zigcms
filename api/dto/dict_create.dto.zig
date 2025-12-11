//! 字典创建数据传输对象
//!
//! 用于创建字典实体的数据结构

const std = @import("std");

/// 字典创建 DTO
pub const DictCreateDto = struct {
    /// 字典类型（必填）
    dict_type: []const u8,
    /// 字典标签（必填）
    dict_label: []const u8,
    /// 字典值（必填）
    dict_value: []const u8,
    /// 字典描述
    dict_desc: []const u8 = "",
    /// 排序
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 备注
    remark: []const u8 = "",
};
