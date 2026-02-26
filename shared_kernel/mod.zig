//! 共享内核 (Shared Kernel)
//!
//! 这是整个系统中最核心、最稳定的部分，包含所有领域驱动设计的核心模式。
//! 共享内核被所有有界上下文（Bounded Contexts）共享。
//!
//! ## 模块结构
//! - `patterns/`: 核心设计模式实现
//!   - ValueObject: 值对象模式
//!   - Entity: 实体模式
//!   - AggregateRoot: 聚合根模式
//!   - DomainEvent: 领域事件模式
//!   - Repository: 仓储模式
//!
//! ## 使用原则
//! - 保持共享内核的稳定性和最小化
//! - 任何对共享内核的修改都会影响整个系统
//! - 共享内核应该是高度内聚的
//!
//! ## 依赖关系
//! - 共享内核不依赖任何其他模块
//! - 其他模块可以依赖共享内核

const std = @import("std");

// ============================================================================
// 核心模式 (Patterns)
// ============================================================================

/// 值对象模式
pub const ValueObject = @import("patterns/value_object.zig");

/// 实体模式
pub const Entity = @import("patterns/entity.zig");

/// 聚合根模式
pub const AggregateRoot = @import("patterns/aggregate_root.zig");

/// 领域事件模式
pub const DomainEvent = @import("patterns/domain_event.zig");

/// 仓储模式
pub const Repository = @import("patterns/repository.zig");

// ============================================================================
// 基础设施 (Infrastructure)
// ============================================================================

/// 领域基础设施
pub const infrastructure = @import("infrastructure/mod.zig");

// ============================================================================
// 便捷类型别名
// ============================================================================

/// 常用验证函数
pub const Validators = ValueObject.Validators;

/// 领域事件基类
pub const DomainEventBase = DomainEvent.DomainEventBase;

/// 事件类型注册表
pub const EventTypeRegistry = DomainEvent.EventTypeRegistry;

/// 仓储工厂
pub const RepositoryFactory = Repository.RepositoryFactory;

/// 仓储实现基类
pub fn RepositoryImpl(comptime T: type, comptime IdType: type) type {
    return Repository.RepositoryImpl(T, IdType);
}

/// 查询规约
pub const Specification = Repository.Specification;

// ============================================================================
// 初始化和清理
// ============================================================================

/// 初始化共享内核
pub fn init() void {
    std.debug.print("✅ 共享内核初始化完成\n", .{});
}

/// 清理共享内核
pub fn deinit() void {
    std.debug.print("👋 共享内核已清理\n", .{});
}
