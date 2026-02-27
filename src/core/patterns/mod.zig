//! DDD 设计模式模块 (Patterns Module)
//!
//! 从原 shared_kernel/patterns 迁移而来，提供领域驱动设计的核心模式。
//!
//! ## 包含的模式
//! - ValueObject: 值对象模式
//! - Entity: 实体模式
//! - AggregateRoot: 聚合根模式
//! - DomainEvent: 领域事件模式
//! - Repository: 仓储模式

const std = @import("std");

pub const value_object = @import("value_object.zig");
pub const entity = @import("entity.zig");
pub const aggregate_root = @import("aggregate_root.zig");
pub const domain_event = @import("domain_event.zig");
pub const repository = @import("repository.zig");

/// 值对象基类
pub const ValueObject = value_object.ValueObject;

/// 实体基类
pub const Entity = entity.Entity;

/// 聚合根基类
pub const AggregateRoot = aggregate_root.AggregateRoot;

/// 领域事件基类
pub const DomainEvent = domain_event.DomainEvent;

/// 仓储接口
pub const Repository = repository.Repository;
