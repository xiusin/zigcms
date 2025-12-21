//! 命令行工具模块入口
//!
//! 本模块提供 ZigCMS 的命令行工具集，包括：
//! - codegen: 代码生成工具（模型、控制器、DTO）
//! - migrate: 数据库迁移工具
//! - plugin_gen: 插件代码生成器
//! - config_gen: 配置结构生成器
//!
//! ## 使用方式
//! ```
//! zig build codegen -- --help
//! zig build migrate -- up
//! zig build plugin-gen -- --name=MyPlugin
//! zig build config-gen -- .env ./generated_config.zig
//! ```

pub const base = @import("base.zig");
pub const codegen = @import("codegen.zig");
pub const migrate = @import("migrate.zig");
pub const plugin_gen = @import("plugin_gen.zig");
pub const config_gen = @import("config_gen.zig");

// 导出常用类型
pub const Command = base.Command;
pub const CommandArgs = base.CommandArgs;
pub const OptionDef = base.OptionDef;
pub const parseArgs = base.parseArgs;
pub const validateRequired = base.validateRequired;
