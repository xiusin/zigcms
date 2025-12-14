//! 验证器模块入口
//!
//! 提供 DTO 验证和安全防护功能

pub const validator = @import("validator.zig");
pub const security = @import("security.zig");

// 类型导出
pub const Validator = validator.Validator;
pub const ValidationError = validator.ValidationError;

// 便捷函数导出
pub const validateDto = validator.validateDto;
pub const validateWithErrors = validator.validateWithErrors;

// 安全模块导出
pub const Security = security.Security;
pub const sanitize = security.sanitize;
pub const isClean = security.isClean;
