const std = @import("std");
const Feedback = @import("../entities/feedback.model.zig").Feedback;
const FeedbackStatus = @import("../entities/feedback.model.zig").FeedbackStatus;
const PageQuery = @import("./test_case_repository.zig").PageQuery;
const PageResult = @import("./test_case_repository.zig").PageResult;

/// 反馈仓储接口
/// 使用 VTable 模式实现接口抽象,遵循 ZigCMS 整洁架构规范
pub const FeedbackRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();

    /// 虚函数表定义
    pub const VTable = struct {
        /// 根据 ID 查询反馈
        findById: *const fn (*anyopaque, i32) anyerror!?Feedback,

        /// 分页查询所有反馈
        findAll: *const fn (*anyopaque, PageQuery) anyerror!PageResult(Feedback),

        /// 保存反馈(创建或更新)
        save: *const fn (*anyopaque, *Feedback) anyerror!void,

        /// 删除反馈
        delete: *const fn (*anyopaque, i32) anyerror!void,

        /// 添加跟进记录
        addFollowUp: *const fn (*anyopaque, i32, []const u8, []const u8) anyerror!void,

        /// 批量指派反馈负责人
        batchAssign: *const fn (*anyopaque, []const i32, []const u8) anyerror!void,

        /// 批量更新反馈状态
        batchUpdateStatus: *const fn (*anyopaque, []const i32, FeedbackStatus) anyerror!void,
    };

    /// 根据 ID 查询反馈
    /// 参数:
    ///   - id: 反馈 ID
    /// 返回:
    ///   - ?Feedback: 反馈对象,如果不存在则返回 null
    pub fn findById(self: *Self, id: i32) !?Feedback {
        return self.vtable.findById(self.ptr, id);
    }

    /// 分页查询所有反馈
    /// 参数:
    ///   - query: 分页查询参数
    /// 返回:
    ///   - PageResult(Feedback): 分页结果
    /// 说明:
    ///   - 按创建时间倒序排列(最新的在前)
    ///   - 支持按状态、负责人、严重程度、提交时间、关键字筛选
    pub fn findAll(self: *Self, query: PageQuery) !PageResult(Feedback) {
        return self.vtable.findAll(self.ptr, query);
    }

    /// 保存反馈(创建或更新)
    /// 参数:
    ///   - feedback: 反馈对象指针
    /// 说明:
    ///   - 如果 feedback.id 为 null,则创建新记录并设置 id
    ///   - 如果 feedback.id 不为 null,则更新现有记录
    pub fn save(self: *Self, feedback: *Feedback) !void {
        return self.vtable.save(self.ptr, feedback);
    }

    /// 删除反馈
    /// 参数:
    ///   - id: 反馈 ID
    pub fn delete(self: *Self, id: i32) !void {
        return self.vtable.delete(self.ptr, id);
    }

    /// 添加跟进记录
    /// 参数:
    ///   - feedback_id: 反馈 ID
    ///   - follower: 跟进人
    ///   - content: 跟进内容(支持富文本)
    /// 说明:
    ///   - 将跟进记录追加到 follow_ups JSON 数组
    ///   - 更新 follow_count 和 last_follow_at
    ///   - 发送通知给反馈提交人和负责人
    pub fn addFollowUp(self: *Self, feedback_id: i32, follower: []const u8, content: []const u8) !void {
        return self.vtable.addFollowUp(self.ptr, feedback_id, follower, content);
    }

    /// 批量指派反馈负责人
    /// 参数:
    ///   - ids: 反馈 ID 数组
    ///   - assignee: 负责人用户名
    /// 说明:
    ///   - 最多支持 1000 条记录
    ///   - 使用事务确保原子性
    pub fn batchAssign(self: *Self, ids: []const i32, assignee: []const u8) !void {
        return self.vtable.batchAssign(self.ptr, ids, assignee);
    }

    /// 批量更新反馈状态
    /// 参数:
    ///   - ids: 反馈 ID 数组
    ///   - status: 目标状态
    /// 说明:
    ///   - 最多支持 1000 条记录
    ///   - 使用事务确保原子性
    pub fn batchUpdateStatus(self: *Self, ids: []const i32, status: FeedbackStatus) !void {
        return self.vtable.batchUpdateStatus(self.ptr, ids, status);
    }
};

/// 创建反馈仓储实例
/// 参数:
///   - ptr: 实现类实例指针
///   - vtable: 虚函数表指针
/// 返回:
///   - FeedbackRepository: 仓储接口实例
pub fn create(ptr: anytype, vtable: *const FeedbackRepository.VTable) FeedbackRepository {
    return .{
        .ptr = ptr,
        .vtable = vtable,
    };
}
