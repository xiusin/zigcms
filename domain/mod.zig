//! 领域层入口文件
//!
//! 职责：
//! - 定义核心业务实体和值对象
//! - 实现业务规则和约束
//! - 定义领域服务接口
//! - 提供业务实体的仓储接口

const std = @import("std");

/// 领域层配置
pub const DomainConfig = struct {
    // 领域层特定配置
    validate_models: bool = true,
    enforce_business_rules: bool = true,
};

/// 领域层初始化函数
pub fn init(allocator: std.mem.Allocator) !void {
    _ = allocator;
    std.log.info("领域层初始化完成", .{});
    
    // 初始化实体模型
    @import("entities/models.zig");
}