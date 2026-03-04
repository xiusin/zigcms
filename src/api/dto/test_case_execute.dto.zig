//! 测试用例执行数据传输对象
//!
//! 用于执行测试用例的数据结构

const std = @import("std");
const TestExecution = @import("../../domain/entities/test_execution.model.zig").TestExecution;

/// 测试用例执行 DTO
pub const TestCaseExecuteDto = struct {
    /// 测试用例 ID（必填）
    test_case_id: i32,
    /// 执行人（必填）
    executor: []const u8,
    /// 执行状态（passed/failed/blocked）
    status: TestExecution.ExecutionStatus,
    /// 实际结果
    actual_result: []const u8 = "",
    /// 备注
    remark: []const u8 = "",
    /// 执行时长（毫秒）
    duration_ms: i32 = 0,

    /// 验证执行数据有效性
    pub fn validate(self: @This()) !void {
        if (self.test_case_id == 0) return error.TestCaseIdRequired;
        if (self.executor.len == 0) return error.ExecutorRequired;
    }

    /// 转换为领域实体
    pub fn toEntity(self: @This()) TestExecution {
        return TestExecution{
            .test_case_id = self.test_case_id,
            .executor = self.executor,
            .status = self.status,
            .actual_result = self.actual_result,
            .remark = self.remark,
            .duration_ms = self.duration_ms,
            .executed_at = std.time.timestamp(),
        };
    }
};
