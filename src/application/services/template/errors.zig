//! 模板引擎错误类型
//!
//! 定义所有可能的模板引擎错误，提供详细的错误信息

const std = @import("std");

/// 模板引擎错误类型
pub const TemplateError = error{
    // ========================================================================
    // 词法分析错误
    // ========================================================================
    
    /// 未终止的字符串
    UnterminatedString,
    
    /// 意外的文件结束
    UnexpectedEof,
    
    /// 无效的字符
    InvalidCharacter,
    
    // ========================================================================
    // 语法分析错误
    // ========================================================================
    
    /// 意外的标记
    UnexpectedToken,
    
    /// 期望标识符
    ExpectedIdentifier,
    
    /// 期望字符串
    ExpectedString,
    
    /// 期望操作符
    ExpectedOperator,
    
    /// 期望等于号
    ExpectedEquals,
    
    /// 期望逗号
    ExpectedComma,
    
    /// 期望变量结束
    ExpectedVariableEnd,
    
    /// 期望标签结束
    ExpectedTagEnd,
    
    /// 期望 in 关键字
    ExpectedIn,
    
    /// 期望 import 关键字
    ExpectedImport,
    
    /// 无效的主表达式
    InvalidPrimary,
    
    /// 无效的字面量
    InvalidLiteral,
    
    /// 期望操作符或标签结束
    ExpectedOperatorOrTagEnd,
    
    /// 期望管道或变量结束
    ExpectedPipeOrVariableEnd,
    
    // ========================================================================
    // 语义分析错误
    // ========================================================================
    
    /// 变量未找到
    VariableNotFound,
    
    /// 无效的路径
    InvalidPath,
    
    /// 不支持的操作符
    UnsupportedOp,
    
    /// 未知的函数
    UnknownFunction,
    
    /// 函数未找到
    FunctionNotFound,
    
    /// 参数太少
    TooFewArguments,
    
    /// 参数太多
    TooManyArguments,
    
    /// 无效的参数
    InvalidArguments,
    
    /// 无效的类型
    InvalidType,
    
    /// 无效的宏参数
    InvalidMacroArgs,
    
    /// 常量未找到
    ConstantNotFound,
    
    /// 空数组
    EmptyArray,
    
    /// 不可迭代的类型
    IterableNotArray,
    
    // ========================================================================
    // 运行时错误
    // ========================================================================
    
    /// 溢出
    Overflow,
    
    /// 除以零
    DivisionByZero,
    
    // ========================================================================
    // 模板加载错误
    // ========================================================================
    
    /// 模板未找到
    TemplateNotFound,
    
    /// 模板加载失败
    TemplateLoadFailed,
    
    /// 循环继承
    CircularInheritance,
    
    // ========================================================================
    // 过滤器错误
    // ========================================================================
    
    /// 未知的过滤器
    UnknownFilter,
    
    /// 过滤器参数错误
    FilterArgumentError,
};

/// 错误位置信息
pub const ErrorLocation = struct {
    line: usize = 0,
    column: usize = 0,
    file: []const u8 = "",
};

/// 模板错误（带位置信息）
pub const TemplateErrorWithLocation = struct {
    error: TemplateError,
    location: ErrorLocation,
    message: []const u8 = "",
};

/// 创建带位置信息的错误
pub fn createError(error: TemplateError, location: ErrorLocation, allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !TemplateErrorWithLocation {
    const message = try std.fmt.allocPrint(allocator, fmt, args);
    return TemplateErrorWithLocation{
        .error = error,
        .location = location,
        .message = message,
    };
}

/// 格式化错误信息
pub fn formatError(err: TemplateError, location: ErrorLocation, allocator: std.mem.Allocator) ![]const u8 {
    const error_name = @errorName(err);
    const location_str = if (location.file.len > 0)
        try std.fmt.allocPrint(allocator, "{s}:{d}:{d}", .{ location.file, location.line, location.column })
    else
        try std.fmt.allocPrint(allocator, "line {d}", .{location.line});
    
    return std.fmt.allocPrint(allocator, "Template error: {s} at {s}", .{ error_name, location_str });
}

/// 错误描述
pub fn getErrorDescription(err: TemplateError) []const u8 {
    return switch (err) {
        // 词法分析错误
        .UnterminatedString => "未终止的字符串，缺少引号",
        .UnexpectedEof => "意外的文件结束",
        .InvalidCharacter => "无效的字符",
        
        // 语法分析错误
        .UnexpectedToken => "意外的标记",
        .ExpectedIdentifier => "期望标识符",
        .ExpectedString => "期望字符串",
        .ExpectedOperator => "期望操作符",
        .ExpectedEquals => "期望等于号 (=)",
        .ExpectedComma => "期望逗号 (,)",
        .ExpectedVariableEnd => "期望变量结束 (}})",
        .ExpectedTagEnd => "期望标签结束 (%})",
        .ExpectedIn => "期望 in 关键字",
        .ExpectedImport => "期望 import 关键字",
        .InvalidPrimary => "无效的主表达式",
        .InvalidLiteral => "无效的字面量",
        .ExpectedOperatorOrTagEnd => "期望操作符或标签结束",
        .ExpectedPipeOrVariableEnd => "期望管道符或变量结束",
        
        // 语义分析错误
        .VariableNotFound => "变量未找到",
        .InvalidPath => "无效的路径",
        .UnsupportedOp => "不支持的操作符",
        .UnknownFunction => "未知的函数",
        .FunctionNotFound => "函数未找到",
        .TooFewArguments => "参数太少",
        .TooManyArguments => "参数太多",
        .InvalidArguments => "无效的参数",
        .InvalidType => "无效的类型",
        .InvalidMacroArgs => "无效的宏参数",
        .ConstantNotFound => "常量未找到",
        .EmptyArray => "空数组",
        .IterableNotArray => "不可迭代的类型",
        
        // 运行时错误
        .Overflow => "数值溢出",
        .DivisionByZero => "除以零",
        
        // 模板加载错误
        .TemplateNotFound => "模板未找到",
        .TemplateLoadFailed => "模板加载失败",
        .CircularInheritance => "循环继承",
        
        // 过滤器错误
        .UnknownFilter => "未知的过滤器",
        .FilterArgumentError => "过滤器参数错误",
    };
}

test "formatError creates correct error message" {
    const location = ErrorLocation{ .line = 10, .column = 5 };
    const err = TemplateError.VariableNotFound;
    
    const message = try formatError(err, location, std.testing.allocator);
    defer std.testing.allocator.free(message);
    
    try std.testing.expectEqualStrings("Template error: VariableNotFound at line 10", message);
}

test "getErrorDescription returns correct description" {
    try std.testing.expectEqualStrings("变量未找到", getErrorDescription(TemplateError.VariableNotFound));
    try std.testing.expectEqualStrings("未终止的字符串，缺少引号", getErrorDescription(TemplateError.UnterminatedString));
    try std.testing.expectEqualStrings("函数未找到", getErrorDescription(TemplateError.FunctionNotFound));
}