//! CMS 内容管理系统核心模块
//!
//! 提供通用的内容模型、字段、文档管理功能。
//! 核心思想：模型定义结构，字段定义数据，文档存储内容。
//!
//! ## 架构设计
//!
//! ```
//! ┌─────────────────────────────────────────────────────────────┐
//! │                      CMS Manager                             │
//! │  - 统一管理入口                                              │
//! │  - 线程安全的单例模式                                        │
//! └─────────────────────────────────────────────────────────────┘
//!                              │
//!         ┌───────────────────┼───────────────────┐
//!         ▼                   ▼                   ▼
//!   ┌───────────┐      ┌───────────┐      ┌───────────┐
//!   │  Model    │──1:N─│  Field    │      │ Document  │
//!   │  模型定义 │      │  字段定义 │      │  文档内容 │
//!   └───────────┘      └───────────┘      └───────────┘
//!         │                                     │
//!         └─────────────────1:N─────────────────┘
//! ```
//!
//! ## 使用示例
//!
//! ```zig
//! const cms = @import("cms/mod.zig");
//!
//! // 初始化 CMS 管理器
//! var manager = try cms.Manager.init(allocator, db);
//! defer manager.deinit();
//!
//! // 创建内容模型
//! const article_model = try manager.createModel(.{
//!     .name = "文章",
//!     .table_name = "article",
//!     .model_type = .list,
//! });
//!
//! // 为模型添加字段
//! try manager.addField(article_model.id, .{
//!     .field_name = "title",
//!     .field_label = "标题",
//!     .field_type = .text,
//!     .is_required = true,
//! });
//!
//! // 创建文档
//! const doc = try manager.createDocument(article_model.id, .{
//!     .title = "Hello World",
//!     .content = "This is content...",
//! });
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const model = @import("model.zig");
pub const field = @import("field.zig");
pub const document = @import("document.zig");
pub const manager = @import("manager.zig");

// 类型导出
pub const Model = model.Model;
pub const ModelType = model.ModelType;
pub const Field = field.Field;
pub const FieldType = field.FieldType;
pub const Document = document.Document;
pub const DocumentStatus = document.DocumentStatus;
pub const Manager = manager.Manager;

// 便捷函数
pub const createManager = manager.create;
