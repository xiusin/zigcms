//! 会员管理模型
//!
//! 系统会员实体，用于用户会员信息管理
//! 遵循领域驱动设计原则，封装会员相关的业务规则和方法

const std = @import("std");

/// 会员实体
pub const Member = struct {
    /// 会员ID
    id: ?i32 = null,
    /// 用户名
    username: []const u8 = "",
    /// 邮箱
    email: []const u8 = "",
    /// 手机号
    mobile: []const u8 = "",
    /// 昵称
    nickname: []const u8 = "",
    /// 头像
    avatar: []const u8 = "",
    /// 性别（0未知 1男 2女）
    gender: i32 = 0,
    /// 生日
    birthday: ?i64 = null,
    /// 所在地
    location: []const u8 = "",
    /// 个人签名
    signature: []const u8 = "",
    /// 会员分组ID
    group_id: i32 = 0,
    /// 积分
    points: i32 = 0,
    /// 经验值
    experience: i32 = 0,
    /// 等级
    level: i32 = 1,
    /// 总消费金额
    total_consume: f64 = 0.0,
    /// 最后登录时间
    last_login_time: ?i64 = null,
    /// 最后登录IP
    last_login_ip: []const u8 = "",
    /// 注册时间
    register_time: ?i64 = null,
    /// 注册IP
    register_ip: []const u8 = "",
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 是否邮箱验证
    email_verified: i32 = 0,
    /// 是否手机验证
    mobile_verified: i32 = 0,
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
    /// 软删除标记
    is_delete: i32 = 0,

    /// 创建新会员
    pub fn create(username: []const u8, email: []const u8, nickname: []const u8) Member {
        const now = std.time.timestamp();
        return .{
            .username = username,
            .email = email,
            .nickname = nickname,
            .status = 1,
            .register_time = now,
            .create_time = now,
            .update_time = now,
        };
    }

    /// 更新会员基本信息
    pub fn updateProfile(self: *Member, nickname: ?[]const u8, avatar: ?[]const u8, signature: ?[]const u8, location: ?[]const u8) void {
        const now = std.time.timestamp();

        if (nickname) |nick| {
            self.nickname = nick;
        }
        if (avatar) |ava| {
            self.avatar = ava;
        }
        if (signature) |sig| {
            self.signature = sig;
        }
        if (location) |loc| {
            self.location = loc;
        }
        self.update_time = now;
    }

    /// 更新联系信息
    pub fn updateContact(self: *Member, email: ?[]const u8, mobile: ?[]const u8) void {
        const now = std.time.timestamp();

        if (email) |em| {
            self.email = em;
            self.email_verified = 0; // 邮箱变更需要重新验证
        }
        if (mobile) |mob| {
            self.mobile = mob;
            self.mobile_verified = 0; // 手机号变更需要重新验证
        }
        self.update_time = now;
    }

    /// 增加积分
    pub fn addPoints(self: *Member, points: i32) void {
        self.points += points;
        self.update_time = std.time.timestamp();
        self.updateLevel(); // 积分变化可能影响等级
    }

    /// 减少积分
    pub fn deductPoints(self: *Member, points: i32) !void {
        if (self.points < points) {
            return error.InsufficientPoints;
        }
        self.points -= points;
        self.update_time = std.time.timestamp();
        self.updateLevel();
    }

    /// 增加经验值
    pub fn addExperience(self: *Member, exp: i32) void {
        self.experience += exp;
        self.update_time = std.time.timestamp();
        self.updateLevel();
    }

    /// 记录消费
    pub fn recordConsumption(self: *Member, amount: f64) void {
        self.total_consume += amount;
        self.update_time = std.time.timestamp();
        // 消费可能带来积分奖励
        const bonus_points = @as(i32, @intFromFloat(amount / 10.0)); // 每消费10元得1积分
        if (bonus_points > 0) {
            self.addPoints(bonus_points);
        }
    }

    /// 更新会员等级（基于经验值）
    pub fn updateLevel(self: *Member) void {
        // 简单的等级计算逻辑：每1000经验值升一级
        const new_level = @as(i32, @intCast(self.experience / 1000)) + 1;
        if (new_level != self.level) {
            self.level = new_level;
        }
    }

    /// 记录登录信息
    pub fn recordLogin(self: *Member, ip: []const u8) void {
        const now = std.time.timestamp();
        self.last_login_time = now;
        self.last_login_ip = ip;
        self.update_time = now;
    }

    /// 启用会员
    pub fn enable(self: *Member) void {
        self.status = 1;
        self.update_time = std.time.timestamp();
    }

    /// 禁用会员
    pub fn disable(self: *Member) void {
        self.status = 0;
        self.update_time = std.time.timestamp();
    }

    /// 检查会员是否激活
    pub fn isActive(self: Member) bool {
        return self.status == 1 and self.is_delete == 0;
    }

    /// 验证邮箱格式
    pub fn isValidEmail(_: Member, email: []const u8) bool {
        if (email.len == 0) return false;

        const at_index = std.mem.indexOf(u8, email, "@");
        const dot_index = std.mem.lastIndexOf(u8, email, ".");

        if (at_index == null or dot_index == null) return false;
        return at_index.? < dot_index.? and at_index.? > 0 and dot_index.? < email.len - 1;
    }

    /// 验证手机号格式（中国手机号）
    pub fn isValidMobile(_: Member, mobile: []const u8) bool {
        if (mobile.len != 11) return false;

        // 检查是否以1开头
        if (mobile[0] != '1') return false;

        // 检查其余字符是否都是数字
        for (mobile[1..]) |c| {
            if (c < '0' or c > '9') return false;
        }

        return true;
    }

    /// 获取显示名称
    pub fn getDisplayName(self: Member) []const u8 {
        if (self.nickname.len > 0) {
            return self.nickname;
        }
        return self.username;
    }

    /// 获取会员等级名称
    pub fn getLevelName(self: Member) []const u8 {
        return switch (self.level) {
            1 => "普通会员",
            2 => "银卡会员",
            3 => "金卡会员",
            4 => "钻石会员",
            5 => "至尊会员",
            else => "超级会员",
        };
    }

    /// 检查是否可以升级
    pub fn canUpgrade(self: Member) bool {
        const next_level_exp = self.level * 1000;
        return self.experience >= next_level_exp;
    }
};
