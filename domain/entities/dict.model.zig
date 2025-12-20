//! 字典模型 - 用于管理常用系统内字典项
//!
//! 该模型支持：
//! - 字典类型和字典项目的管理
//! - 字典项的分类和分组
//! - 字典项的描述和排序
//!
//! 表结构：
//! - id: 主键
//! - dict_type: 字典类型（如：user_status, order_status等）
//! - dict_label: 字典标签（显示名称）
//! - dict_value: 字典值（实际存储值）
//! - dict_desc: 字典描述
//! - sort: 排序
//! - status: 状态（0-禁用，1-启用）
//! - create_time: 创建时间
//! - update_time: 更新时间
//! - remark: 备注

const std = @import("std");

pub const Dict = struct {
    id: ?i32 = null,
    dict_type: []const u8 = "",
    dict_label: []const u8 = "",
    dict_value: []const u8 = "",
    dict_desc: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 1, // 0-禁用，1-启用
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    remark: []const u8 = "",
};
