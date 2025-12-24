//! 会员应用服务 (Member Application Service)
//!
//! 应用层会员服务，实现会员相关的业务逻辑。
//! 该服务协调领域层实体和仓储，处理复杂的业务用例。

const std = @import("std");
const Member = @import("../../domain/entities/member.model.zig").Member;
const MemberRepository = @import("../../domain/repositories/member_repository.zig").MemberRepository;

/// 会员应用服务
///
/// 应用层服务，负责协调领域对象，处理业务用例逻辑。
/// 遵循应用服务模式，封装会员相关的业务流程。
pub const MemberService = struct {
    allocator: std.mem.Allocator,
    member_repository: MemberRepository,

    /// 初始化会员服务
    pub fn init(allocator: std.mem.Allocator, member_repository: MemberRepository) MemberService {
        return .{
            .allocator = allocator,
            .member_repository = member_repository,
        };
    }

    /// 根据ID获取会员
    ///
    /// ## 参数
    /// - `member_id`: 会员ID
    ///
    /// ## 返回
    /// 会员实体，如果不存在返回null
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getMember(self: *MemberService, member_id: i32) !?Member {
        // 调用领域层仓储接口
        const member = try self.member_repository.findById(member_id);
        return member;
    }

    /// 创建新会员
    ///
    /// ## 参数
    /// - `username`: 用户名
    /// - `email`: 邮箱
    /// - `nickname`: 昵称
    ///
    /// ## 返回
    /// 创建的会员实体
    ///
    /// ## 错误
    /// - 用户名已存在
    /// - 邮箱格式无效
    /// - 仓储层错误
    pub fn createMember(self: *MemberService, username: []const u8, email: []const u8, nickname: []const u8) !Member {
        // 业务规则验证
        if (username.len == 0) {
            return error.InvalidUsername;
        }

        if (!Member.isValidEmail(Member{}, email)) {
            return error.InvalidEmail;
        }

        // 创建会员实体
        const member = Member.create(username, email, nickname);

        // 保存到仓储
        const saved_member = try self.member_repository.save(member);

        return saved_member;
    }

    /// 更新会员基本信息
    ///
    /// ## 参数
    /// - `member_id`: 会员ID
    /// - `nickname`: 新昵称（可选）
    /// - `avatar`: 新头像（可选）
    /// - `signature`: 新签名（可选）
    /// - `location`: 新所在地（可选）
    ///
    /// ## 错误
    /// - 会员不存在
    /// - 仓储层错误
    pub fn updateProfile(self: *MemberService, member_id: i32, nickname: ?[]const u8, avatar: ?[]const u8, signature: ?[]const u8, location: ?[]const u8) !void {
        // 获取现有会员
        const existing_member = try self.member_repository.findById(member_id) orelse {
            return error.MemberNotFound;
        };

        // 复制会员进行修改（避免直接修改）
        const member = existing_member;
        member.updateProfile(nickname, avatar, signature, location);

        // 保存更新
        try self.member_repository.update(member);
    }

    /// 更新会员联系信息
    ///
    /// ## 参数
    /// - `member_id`: 会员ID
    /// - `email`: 新邮箱（可选）
    /// - `mobile`: 新手机号（可选）
    ///
    /// ## 错误
    /// - 会员不存在
    /// - 邮箱/手机号格式无效
    /// - 仓储层错误
    pub fn updateContact(self: *MemberService, member_id: i32, email: ?[]const u8, mobile: ?[]const u8) !void {
        // 获取现有会员
        const existing_member = try self.member_repository.findById(member_id) orelse {
            return error.MemberNotFound;
        };

        // 验证邮箱格式
        if (email) |em| {
            if (!Member.isValidEmail(Member{}, em)) {
                return error.InvalidEmail;
            }
        }

        // 验证手机号格式
        if (mobile) |mob| {
            if (!Member.isValidMobile(Member{}, mob)) {
                return error.InvalidMobile;
            }
        }

        var member = existing_member;
        member.updateContact(email, mobile);

        // 保存更新
        try self.member_repository.update(member);
    }

    /// 会员消费记录
    ///
    /// ## 参数
    /// - `member_id`: 会员ID
    /// - `amount`: 消费金额
    ///
    /// ## 错误
    /// - 会员不存在
    /// - 消费金额无效
    /// - 仓储层错误
    pub fn recordConsumption(self: *MemberService, member_id: i32, amount: f64) !void {
        if (amount <= 0) {
            return error.InvalidAmount;
        }

        // 获取现有会员
        const existing_member = try self.member_repository.findById(member_id) orelse {
            return error.MemberNotFound;
        };

        var member = existing_member;
        member.recordConsumption(amount);

        // 保存更新
        try self.member_repository.update(member);
    }

    /// 会员积分操作
    ///
    /// ## 参数
    /// - `member_id`: 会员ID
    /// - `points`: 积分数量（正数表示增加，负数表示减少）
    ///
    /// ## 错误
    /// - 会员不存在
    /// - 积分不足
    /// - 仓储层错误
    pub fn adjustPoints(self: *MemberService, member_id: i32, points: i32) !void {
        // 获取现有会员
        const existing_member = try self.member_repository.findById(member_id) orelse {
            return error.MemberNotFound;
        };

        var member = existing_member;
        if (points > 0) {
            member.addPoints(@as(u32, @intCast(points)));
        } else if (points < 0) {
            try member.deductPoints(@as(u32, @intCast(-points)));
        }

        // 保存更新
        try self.member_repository.update(member);
    }

    /// 记录会员登录
    ///
    /// ## 参数
    /// - `member_id`: 会员ID
    /// - `ip`: 登录IP地址
    ///
    /// ## 错误
    /// - 会员不存在
    /// - 仓储层错误
    pub fn recordLogin(self: *MemberService, member_id: i32, ip: []const u8) !void {
        // 获取现有会员
        const existing_member = try self.member_repository.findById(member_id) orelse {
            return error.MemberNotFound;
        };

        var member = existing_member;
        member.recordLogin(ip);

        // 保存更新
        try self.member_repository.update(member);
    }

    /// 启用会员
    ///
    /// ## 参数
    /// - `member_id`: 会员ID
    ///
    /// ## 错误
    /// - 会员不存在
    /// - 仓储层错误
    pub fn enableMember(self: *MemberService, member_id: i32) !void {
        const member = try self.member_repository.findById(member_id) orelse {
            return error.MemberNotFound;
        };

        var updated_member = member;
        updated_member.enable();
        try self.member_repository.update(updated_member);
    }

    /// 禁用会员
    ///
    /// ## 参数
    /// - `member_id`: 会员ID
    ///
    /// ## 错误
    /// - 会员不存在
    /// - 仓储层错误
    pub fn disableMember(self: *MemberService, member_id: i32) !void {
        const member = try self.member_repository.findById(member_id) orelse {
            return error.MemberNotFound;
        };

        var updated_member = member;
        updated_member.disable();
        try self.member_repository.update(updated_member);
    }

    /// 删除会员
    ///
    /// ## 参数
    /// - `member_id`: 会员ID
    ///
    /// ## 错误
    /// - 会员不存在
    /// - 仓储层错误
    pub fn deleteMember(self: *MemberService, member_id: i32) !void {
        // 验证会员存在
        _ = try self.member_repository.findById(member_id) orelse {
            return error.MemberNotFound;
        };

        // 删除会员
        try self.member_repository.delete(member_id);
    }

    /// 获取会员统计信息
    ///
    /// ## 返回
    /// 会员总数
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getMemberCount(self: *MemberService) !usize {
        return try self.member_repository.count();
    }

    /// 获取所有会员
    ///
    /// ## 返回
    /// 会员列表
    ///
    /// ## 注意
    /// 这个方法可能返回大量数据，生产环境中应该分页
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getAllMembers(self: *MemberService) ![]Member {
        return try self.member_repository.findAll();
    }

    /// 分页查询会员
    ///
    /// ## 参数
    /// - `page`: 页码（从1开始）
    /// - `page_size`: 每页大小
    /// - `filters`: 筛选条件（可选）
    ///
    /// ## 返回
    /// 包含分页结果和数据的结构体
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getMembersWithPagination(
        self: *MemberService,
        page: u32,
        page_size: u32,
        filters: ?MemberFilters,
    ) !MemberPageResult {
        // 验证分页参数
        if (page == 0 or page_size == 0 or page_size > 1000) {
            return error.InvalidPaginationParams;
        }

        // 获取所有会员（暂时不支持仓储层的复杂筛选）
        const all_members = try self.member_repository.findAll();
        defer self.allocator.free(all_members);

        // 应用内存级别的筛选
        var filtered_members = std.ArrayList(Member).init(self.allocator);
        defer filtered_members.deinit();

        for (all_members) |member| {
            if (self.applyFilters(self.allocator, member, filters)) {
                try filtered_members.append(member);
            }
        }

        // 计算分页
        const total_count = filtered_members.items.len;
        const total_pages = (total_count + page_size - 1) / page_size;
        const start_index = (page - 1) * page_size;
        const end_index = @min(start_index + page_size, total_count);

        // 提取当前页数据
        var page_data = std.ArrayList(Member).init(self.allocator);
        defer page_data.deinit();

        var i: usize = start_index;
        while (i < end_index) : (i += 1) {
            try page_data.append(filtered_members.items[i]);
        }

        return MemberPageResult{
            .data = page_data.toOwnedSlice(),
            .page = page,
            .page_size = page_size,
            .total_count = total_count,
            .total_pages = total_pages,
        };
    }

    /// 应用筛选条件
    fn applyFilters(allocator: std.mem.Allocator, member: Member, filters: ?MemberFilters) bool {
        if (filters == null) {
            return true;
        }

        const f = filters.?;

        // 组筛选
        if (f.group_id) |group_id| {
            if (member.group_id != group_id) {
                return false;
            }
        }

        // 状态筛选
        if (f.status) |status| {
            if (member.status != status) {
                return false;
            }
        }

        // 等级筛选
        if (f.level) |level| {
            if (member.level != level) {
                return false;
            }
        }

        // 关键词搜索
        if (f.keyword.len > 0) {
            const keyword_lower = std.ascii.allocLowerString(allocator, f.keyword) catch return true;
            defer allocator.free(keyword_lower);

            const username_lower = std.ascii.allocLowerString(allocator, member.username) catch return true;
            defer allocator.free(username_lower);

            const nickname_lower = std.ascii.allocLowerString(allocator, member.nickname) catch return true;
            defer allocator.free(nickname_lower);

            const email_lower = std.ascii.allocLowerString(allocator, member.email) catch return true;
            defer allocator.free(email_lower);

            const mobile_lower = std.ascii.allocLowerString(allocator, member.mobile) catch return true;
            defer allocator.free(mobile_lower);

            if (!std.mem.containsAtLeast(u8, username_lower, 1, keyword_lower) and
                !std.mem.containsAtLeast(u8, nickname_lower, 1, keyword_lower) and
                !std.mem.containsAtLeast(u8, email_lower, 1, keyword_lower) and
                !std.mem.containsAtLeast(u8, mobile_lower, 1, keyword_lower))
            {
                return false;
            }
        }

        // 注册时间筛选
        if (f.start_date) |start_time| {
            if (member.register_time) |reg_time| {
                if (reg_time < start_time) {
                    return false;
                }
            } else {
                return false;
            }
        }

        if (f.end_date) |end_time| {
            if (member.register_time) |reg_time| {
                if (reg_time > end_time) {
                    return false;
                }
            } else {
                return false;
            }
        }

        return true;
    }
};

/// 会员筛选条件
pub const MemberFilters = struct {
    group_id: ?i32 = null,
    status: ?i32 = null,
    level: ?i32 = null,
    keyword: []const u8 = "",
    start_date: ?i64 = null,
    end_date: ?i64 = null,
};

/// 分页结果
pub const MemberPageResult = struct {
    data: []Member,
    page: u32,
    page_size: u32,
    total_count: usize,
    total_pages: usize,
};
