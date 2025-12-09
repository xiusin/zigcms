pub const Task = struct {
    id: ?i32 = null,
    name: []const u8 = "", // 任务名称
    remark: []const u8 = "", // 备注
    type: []const u8 = "", // 任务类型
    cron: []const u8 = "", // 任务表达式
    service: []const u8 = "", // 运行服务内容
    tick: i32 = 0, // 间隔秒数
    begin_time: []const u8 = "", // 开始时间
    create_time: ?i64 = null,
    update_time: ?i64 = null,
};
