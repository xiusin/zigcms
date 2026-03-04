//! 模块移动数据传输对象
//!
//! 用于拖拽移动模块的数据结构

const std = @import("std");

/// 模块移动 DTO
pub const ModuleMoveDto = struct {
    /// 新的父模块 ID（可选，null 表示移动到根节点）
    new_parent_id: ?i32 = null,
    /// 新的排序值（必填）
    new_sort_order: i32,

    /// 验证模块移动数据有效性
    pub fn validate(self: @This()) !void {
        _ = self;
        // 排序值可以为任意整数，无需验证
    }
};
