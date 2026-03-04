// 关联记录实体
// 用于质量中心的多对多关系管理（测试用例-Bug、测试用例-反馈等）

const std = @import("std");

/// 关联记录实体
pub const LinkRecord = struct {
    id: ?i32 = null,
    source_type: []const u8 = "", // 源类型（必填，如 "test_case"）
    source_id: i32 = 0, // 源 ID（必填）
    target_type: []const u8 = "", // 目标类型（必填，如 "bug", "feedback"）
    target_id: i32 = 0, // 目标 ID（必填）
    created_by: []const u8 = "", // 创建人
    created_at: ?i64 = null, // 创建时间

    /// 关联类型常量
    pub const SourceType = struct {
        pub const TEST_CASE: []const u8 = "test_case";
        pub const REQUIREMENT: []const u8 = "requirement";
        pub const BUG: []const u8 = "bug";
        pub const FEEDBACK: []const u8 = "feedback";
    };

    pub const TargetType = struct {
        pub const TEST_CASE: []const u8 = "test_case";
        pub const REQUIREMENT: []const u8 = "requirement";
        pub const BUG: []const u8 = "bug";
        pub const FEEDBACK: []const u8 = "feedback";
    };

    /// 验证关联记录数据是否有效
    pub fn validate(self: *const LinkRecord) !void {
        if (self.source_type.len == 0) {
            return error.SourceTypeRequired;
        }
        if (self.source_id == 0) {
            return error.SourceIdRequired;
        }
        if (self.target_type.len == 0) {
            return error.TargetTypeRequired;
        }
        if (self.target_id == 0) {
            return error.TargetIdRequired;
        }

        // 验证类型是否有效
        if (!isValidType(self.source_type)) {
            return error.InvalidSourceType;
        }
        if (!isValidType(self.target_type)) {
            return error.InvalidTargetType;
        }

        // 防止自关联
        if (std.mem.eql(u8, self.source_type, self.target_type) and self.source_id == self.target_id) {
            return error.SelfLinkNotAllowed;
        }
    }

    /// 判断类型是否有效
    fn isValidType(type_str: []const u8) bool {
        return std.mem.eql(u8, type_str, SourceType.TEST_CASE) or
            std.mem.eql(u8, type_str, SourceType.REQUIREMENT) or
            std.mem.eql(u8, type_str, SourceType.BUG) or
            std.mem.eql(u8, type_str, SourceType.FEEDBACK);
    }

    /// 判断是否为测试用例关联 Bug
    pub fn isTestCaseBugLink(self: *const LinkRecord) bool {
        return std.mem.eql(u8, self.source_type, SourceType.TEST_CASE) and
            std.mem.eql(u8, self.target_type, TargetType.BUG);
    }

    /// 判断是否为测试用例关联反馈
    pub fn isTestCaseFeedbackLink(self: *const LinkRecord) bool {
        return std.mem.eql(u8, self.source_type, SourceType.TEST_CASE) and
            std.mem.eql(u8, self.target_type, TargetType.FEEDBACK);
    }

    /// 判断是否为需求关联测试用例
    pub fn isRequirementTestCaseLink(self: *const LinkRecord) bool {
        return std.mem.eql(u8, self.source_type, SourceType.REQUIREMENT) and
            std.mem.eql(u8, self.target_type, TargetType.TEST_CASE);
    }

    /// 创建测试用例-Bug 关联记录
    pub fn createTestCaseBugLink(test_case_id: i32, bug_id: i32, created_by: []const u8) LinkRecord {
        return LinkRecord{
            .source_type = SourceType.TEST_CASE,
            .source_id = test_case_id,
            .target_type = TargetType.BUG,
            .target_id = bug_id,
            .created_by = created_by,
            .created_at = std.time.timestamp(),
        };
    }

    /// 创建测试用例-反馈关联记录
    pub fn createTestCaseFeedbackLink(test_case_id: i32, feedback_id: i32, created_by: []const u8) LinkRecord {
        return LinkRecord{
            .source_type = SourceType.TEST_CASE,
            .source_id = test_case_id,
            .target_type = TargetType.FEEDBACK,
            .target_id = feedback_id,
            .created_by = created_by,
            .created_at = std.time.timestamp(),
        };
    }

    /// 创建需求-测试用例关联记录
    pub fn createRequirementTestCaseLink(requirement_id: i32, test_case_id: i32, created_by: []const u8) LinkRecord {
        return LinkRecord{
            .source_type = SourceType.REQUIREMENT,
            .source_id = requirement_id,
            .target_type = TargetType.TEST_CASE,
            .target_id = test_case_id,
            .created_by = created_by,
            .created_at = std.time.timestamp(),
        };
    }
};
