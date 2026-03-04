// 测试执行记录实体
// 用于记录测试用例的执行历史

const std = @import("std");

/// 测试执行记录实体
pub const TestExecution = struct {
    id: ?i32 = null,
    test_case_id: i32 = 0, // 测试用例 ID（必填）
    executor: []const u8 = "", // 执行人（必填）
    status: ExecutionStatus = .passed, // 执行状态（必填）
    actual_result: []const u8 = "", // 实际结果
    remark: []const u8 = "", // 备注
    duration_ms: i32 = 0, // 执行时长（毫秒）
    executed_at: i64 = 0, // 执行时间（必填）

    /// 执行状态枚举
    pub const ExecutionStatus = enum {
        passed, // 通过
        failed, // 失败
        blocked, // 阻塞

        pub fn toString(self: ExecutionStatus) []const u8 {
            return switch (self) {
                .passed => "passed",
                .failed => "failed",
                .blocked => "blocked",
            };
        }

        pub fn fromString(str: []const u8) ?ExecutionStatus {
            if (std.mem.eql(u8, str, "passed")) return .passed;
            if (std.mem.eql(u8, str, "failed")) return .failed;
            if (std.mem.eql(u8, str, "blocked")) return .blocked;
            return null;
        }
    };

    /// 验证执行记录数据是否有效
    pub fn validate(self: *const TestExecution) !void {
        if (self.test_case_id == 0) {
            return error.TestCaseIdRequired;
        }
        if (self.executor.len == 0) {
            return error.ExecutorRequired;
        }
        if (self.executed_at == 0) {
            return error.ExecutedAtRequired;
        }
    }

    /// 判断执行是否通过
    pub fn isPassed(self: *const TestExecution) bool {
        return self.status == .passed;
    }

    /// 判断执行是否失败
    pub fn isFailed(self: *const TestExecution) bool {
        return self.status == .failed;
    }

    /// 判断执行是否阻塞
    pub fn isBlocked(self: *const TestExecution) bool {
        return self.status == .blocked;
    }

    /// 获取执行时长（秒）
    pub fn getDurationSeconds(self: *const TestExecution) f32 {
        return @as(f32, @floatFromInt(self.duration_ms)) / 1000.0;
    }
};
