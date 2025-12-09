//! 领域层入口文件
//!
//! 职责：
//! - 定义业务实体和值对象
//! - 定义领域服务和仓库接口
//! - 包含业务规则和逻辑
//! - 独立于基础设施和应用层

const std = @import("std");

// 领域实体
pub const entities = @import("../domain/entities/models.zig");

/// 领域层配置（通常很少有配置）
pub const DomainConfig = struct {
    // 领域层通常不需要太多配置，保持简单
};

/// 领域层初始化函数
pub fn init(allocator: std.mem.Allocator) !void {
    _ = allocator;
    // 验证领域模型完整性
    std.log.info("领域层初始化完成", .{});
}