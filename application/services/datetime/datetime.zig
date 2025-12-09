//! 日期时间库
//!
//! 提供类似 PHP date() 和 Go time 包的日期时间处理功能。
//!
//! ## 使用示例
//!
//! ```zig
//! const datetime = @import("services/datetime/datetime.zig");
//!
//! // 获取当前时间
//! var now = datetime.DateTime.now();
//!
//! // 格式化（PHP 风格）
//! var buf: [64]u8 = undefined;
//! const str = now.formatPhp("Y-m-d H:i:s", &buf);  // "2025-12-06 09:00:00"
//!
//! // 格式化（Go 风格）
//! const str2 = now.formatGo("2006-01-02 15:04:05", &buf);
//!
//! // 解析时间
//! const dt = try datetime.DateTime.parsePhp("2025-12-06 09:00:00", "Y-m-d H:i:s");
//!
//! // 时区转换
//! const beijing = now.inTimezone(datetime.Timezone.beijing);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 时区偏移（秒）
pub const Timezone = struct {
    offset_seconds: i32,
    name: []const u8,

    /// UTC 时区
    pub const utc = Timezone{ .offset_seconds = 0, .name = "UTC" };
    /// 北京时间 (UTC+8)
    pub const beijing = Timezone{ .offset_seconds = 8 * 3600, .name = "Asia/Shanghai" };
    /// 东京时间 (UTC+9)
    pub const tokyo = Timezone{ .offset_seconds = 9 * 3600, .name = "Asia/Tokyo" };
    /// 纽约时间 (UTC-5)
    pub const new_york = Timezone{ .offset_seconds = -5 * 3600, .name = "America/New_York" };
    /// 伦敦时间 (UTC+0)
    pub const london = Timezone{ .offset_seconds = 0, .name = "Europe/London" };
    /// 洛杉矶时间 (UTC-8)
    pub const los_angeles = Timezone{ .offset_seconds = -8 * 3600, .name = "America/Los_Angeles" };

    /// 创建自定义时区
    pub fn custom(offset_hours: i32, name: []const u8) Timezone {
        return .{ .offset_seconds = offset_hours * 3600, .name = name };
    }

    /// 从偏移秒数创建
    pub fn fromSeconds(offset: i32) Timezone {
        return .{ .offset_seconds = offset, .name = "Custom" };
    }
};

/// 月份
pub const Month = enum(u4) {
    january = 1,
    february = 2,
    march = 3,
    april = 4,
    may = 5,
    june = 6,
    july = 7,
    august = 8,
    september = 9,
    october = 10,
    november = 11,
    december = 12,

    /// 获取月份天数
    pub fn days(self: Month, year: i32) u8 {
        return switch (self) {
            .january, .march, .may, .july, .august, .october, .december => 31,
            .april, .june, .september, .november => 30,
            .february => if (isLeapYear(year)) 29 else 28,
        };
    }

    /// 月份名称
    pub fn name(self: Month) []const u8 {
        return switch (self) {
            .january => "January",
            .february => "February",
            .march => "March",
            .april => "April",
            .may => "May",
            .june => "June",
            .july => "July",
            .august => "August",
            .september => "September",
            .october => "October",
            .november => "November",
            .december => "December",
        };
    }

    /// 月份缩写
    pub fn shortName(self: Month) []const u8 {
        return switch (self) {
            .january => "Jan",
            .february => "Feb",
            .march => "Mar",
            .april => "Apr",
            .may => "May",
            .june => "Jun",
            .july => "Jul",
            .august => "Aug",
            .september => "Sep",
            .october => "Oct",
            .november => "Nov",
            .december => "Dec",
        };
    }
};

/// 星期
pub const Weekday = enum(u3) {
    sunday = 0,
    monday = 1,
    tuesday = 2,
    wednesday = 3,
    thursday = 4,
    friday = 5,
    saturday = 6,

    /// 星期名称
    pub fn name(self: Weekday) []const u8 {
        return switch (self) {
            .sunday => "Sunday",
            .monday => "Monday",
            .tuesday => "Tuesday",
            .wednesday => "Wednesday",
            .thursday => "Thursday",
            .friday => "Friday",
            .saturday => "Saturday",
        };
    }

    /// 星期缩写
    pub fn shortName(self: Weekday) []const u8 {
        return switch (self) {
            .sunday => "Sun",
            .monday => "Mon",
            .tuesday => "Tue",
            .wednesday => "Wed",
            .thursday => "Thu",
            .friday => "Fri",
            .saturday => "Sat",
        };
    }
};

/// 时间单位
pub const Duration = struct {
    nanoseconds: i64,

    pub const zero = Duration{ .nanoseconds = 0 };
    pub const nanosecond = Duration{ .nanoseconds = 1 };
    pub const microsecond = Duration{ .nanoseconds = 1000 };
    pub const millisecond = Duration{ .nanoseconds = 1000_000 };
    pub const second = Duration{ .nanoseconds = 1000_000_000 };
    pub const minute = Duration{ .nanoseconds = 60 * 1000_000_000 };
    pub const hour = Duration{ .nanoseconds = 3600 * 1000_000_000 };
    pub const day = Duration{ .nanoseconds = 86400 * 1000_000_000 };
    pub const week = Duration{ .nanoseconds = 7 * 86400 * 1000_000_000 };

    /// 从秒创建
    pub fn seconds(s: i64) Duration {
        return .{ .nanoseconds = s * 1000_000_000 };
    }

    /// 从分钟创建
    pub fn minutes(m: i64) Duration {
        return .{ .nanoseconds = m * 60 * 1000_000_000 };
    }

    /// 从小时创建
    pub fn hours(h: i64) Duration {
        return .{ .nanoseconds = h * 3600 * 1000_000_000 };
    }

    /// 从天数创建
    pub fn days(d: i64) Duration {
        return .{ .nanoseconds = d * 86400 * 1000_000_000 };
    }

    /// 转换为纳秒
    pub fn inNanoseconds(self: Duration) i64 {
        return self.nanoseconds;
    }

    /// 转换为微秒
    pub fn inMicroseconds(self: Duration) i64 {
        return @divTrunc(self.nanoseconds, 1000);
    }

    /// 转换为毫秒
    pub fn inMilliseconds(self: Duration) i64 {
        return @divTrunc(self.nanoseconds, 1000_000);
    }

    /// 转换为秒
    pub fn inSeconds(self: Duration) i64 {
        return @divTrunc(self.nanoseconds, 1000_000_000);
    }

    /// 转换为分钟
    pub fn inMinutes(self: Duration) i64 {
        return @divTrunc(self.nanoseconds, 60 * 1000_000_000);
    }

    /// 转换为小时
    pub fn inHours(self: Duration) i64 {
        return @divTrunc(self.nanoseconds, 3600 * 1000_000_000);
    }

    /// 转换为天数
    pub fn inDays(self: Duration) i64 {
        return @divTrunc(self.nanoseconds, 86400 * 1000_000_000);
    }

    /// 绝对值
    pub fn abs(self: Duration) Duration {
        return .{ .nanoseconds = if (self.nanoseconds < 0) -self.nanoseconds else self.nanoseconds };
    }

    /// 是否为负数
    pub fn isNegative(self: Duration) bool {
        return self.nanoseconds < 0;
    }

    /// 加法
    pub fn add(self: Duration, other: Duration) Duration {
        return .{ .nanoseconds = self.nanoseconds + other.nanoseconds };
    }

    /// 减法
    pub fn sub(self: Duration, other: Duration) Duration {
        return .{ .nanoseconds = self.nanoseconds - other.nanoseconds };
    }

    /// 乘法
    pub fn mul(self: Duration, n: i64) Duration {
        return .{ .nanoseconds = self.nanoseconds * n };
    }
};

/// 日期时间
pub const DateTime = struct {
    const Self = @This();

    /// Unix 时间戳（纳秒）
    timestamp_ns: i128,
    /// 时区
    timezone: Timezone,

    // ========================================================================
    // std.fmt 格式化支持
    // ========================================================================

    /// 实现 std.fmt.Formatter 接口
    ///
    /// 支持的格式说明符：
    /// - `{}` 或 `{s}`: 默认格式 "2025-12-06 09:18:00"
    /// - `{iso}`: ISO 8601 格式 "2025-12-06T09:18:00"
    /// - `{rfc}`: RFC 3339 格式 "2025-12-06T09:18:00+08:00"
    /// - `{date}`: 仅日期 "2025-12-06"
    /// - `{time}`: 仅时间 "09:18:00"
    ///
    /// ## 使用示例
    /// ```zig
    /// const dt = DateTime.now();
    /// std.debug.print("当前时间: {}\n", .{dt});
    /// std.debug.print("ISO格式: {iso}\n", .{dt});
    /// ```
    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        const p = self.parts();

        if (fmt.len == 0 or comptime std.mem.eql(u8, fmt, "s")) {
            // 默认格式: "2025-12-06 09:18:00"
            try writer.print("{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
                @as(u32, @intCast(p.year)), p.month, p.day, p.hour, p.minute, p.second,
            });
        } else if (comptime std.mem.eql(u8, fmt, "iso")) {
            // ISO 8601: "2025-12-06T09:18:00"
            try writer.print("{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}", .{
                @as(u32, @intCast(p.year)), p.month, p.day, p.hour, p.minute, p.second,
            });
        } else if (comptime std.mem.eql(u8, fmt, "rfc")) {
            // RFC 3339: "2025-12-06T09:18:00+08:00"
            const offset_h = @divTrunc(self.timezone.offset_seconds, 3600);
            const offset_m = @mod(@divTrunc(self.timezone.offset_seconds, 60), 60);
            try writer.print("{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}", .{
                @as(u32, @intCast(p.year)), p.month, p.day, p.hour, p.minute, p.second,
            });
            if (self.timezone.offset_seconds == 0) {
                try writer.writeAll("Z");
            } else {
                const sign: u8 = if (offset_h >= 0) '+' else '-';
                const abs_h: u32 = @intCast(if (offset_h < 0) -offset_h else offset_h);
                const abs_m: u32 = @intCast(if (offset_m < 0) -offset_m else offset_m);
                try writer.print("{c}{d:0>2}:{d:0>2}", .{ sign, abs_h, abs_m });
            }
        } else if (comptime std.mem.eql(u8, fmt, "date")) {
            // 仅日期: "2025-12-06"
            try writer.print("{d:0>4}-{d:0>2}-{d:0>2}", .{
                @as(u32, @intCast(p.year)), p.month, p.day,
            });
        } else if (comptime std.mem.eql(u8, fmt, "time")) {
            // 仅时间: "09:18:00"
            try writer.print("{d:0>2}:{d:0>2}:{d:0>2}", .{ p.hour, p.minute, p.second });
        } else {
            // 未知格式，使用默认
            try writer.print("{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
                @as(u32, @intCast(p.year)), p.month, p.day, p.hour, p.minute, p.second,
            });
        }
    }

    /// 转换为字符串（使用默认格式）
    pub fn string(self: Self, buf: []u8) []const u8 {
        return self.formatPhp("Y-m-d H:i:s", buf);
    }

    // ========================================================================
    // 构造函数
    // ========================================================================

    /// 获取当前时间（UTC）
    pub fn now() Self {
        const ns = std.time.nanoTimestamp();
        return .{
            .timestamp_ns = ns,
            .timezone = Timezone.utc,
        };
    }

    /// 获取当前时间（指定时区）
    pub fn nowIn(tz: Timezone) Self {
        return Self.now().inTimezone(tz);
    }

    /// 从 Unix 时间戳创建（秒）
    pub fn fromTimestamp(ts: i64) Self {
        return .{
            .timestamp_ns = @as(i128, ts) * 1000_000_000,
            .timezone = Timezone.utc,
        };
    }

    /// 从 Unix 时间戳创建（毫秒）
    pub fn fromTimestampMs(ts: i64) Self {
        return .{
            .timestamp_ns = @as(i128, ts) * 1000_000,
            .timezone = Timezone.utc,
        };
    }

    /// 从日期时间组件创建
    pub fn create(y: i32, m: u4, d: u8, h: u8, min: u8, sec: u8) Self {
        const ts = dateToTimestamp(y, m, d, h, min, sec);
        return .{
            .timestamp_ns = @as(i128, ts) * 1000_000_000,
            .timezone = Timezone.utc,
        };
    }

    /// 从日期时间组件创建（指定时区）
    pub fn createIn(y: i32, m: u4, d: u8, h: u8, min: u8, sec: u8, tz: Timezone) Self {
        const local_ts = dateToTimestamp(y, m, d, h, min, sec);
        const utc_ts = local_ts - tz.offset_seconds;
        return .{
            .timestamp_ns = @as(i128, utc_ts) * 1000_000_000,
            .timezone = tz,
        };
    }

    /// 今天的开始时间（00:00:00）
    pub fn today() Self {
        var dt = Self.now();
        const p = dt.parts();
        return Self.create(p.year, p.month, p.day, 0, 0, 0);
    }

    /// 明天的开始时间
    pub fn tomorrow() Self {
        return Self.today().addDuration(Duration.day);
    }

    /// 昨天的开始时间
    pub fn yesterday() Self {
        return Self.today().subDuration(Duration.day);
    }

    // ========================================================================
    // 时间组件
    // ========================================================================

    /// 时间组件
    pub const Parts = struct {
        year: i32,
        month: u4,
        day: u8,
        hour: u8,
        minute: u8,
        second: u8,
        nanosecond: u32,
        weekday: Weekday,
        year_day: u16,
    };

    /// 获取时间组件
    pub fn parts(self: Self) Parts {
        const local_ns = self.timestamp_ns + @as(i128, self.timezone.offset_seconds) * 1000_000_000;
        const local_s = @as(i64, @intCast(@divTrunc(local_ns, 1000_000_000)));
        const nano: u32 = @intCast(@mod(local_ns, 1000_000_000));

        var y: i32 = undefined;
        var m: u4 = undefined;
        var d: u8 = undefined;
        var h: u8 = undefined;
        var min: u8 = undefined;
        var sec: u8 = undefined;
        var yday: u16 = undefined;

        timestampToDate(local_s, &y, &m, &d, &h, &min, &sec, &yday);

        return .{
            .year = y,
            .month = m,
            .day = d,
            .hour = h,
            .minute = min,
            .second = sec,
            .nanosecond = nano,
            .weekday = self.weekday(),
            .year_day = yday,
        };
    }

    /// 获取年份
    pub fn year(self: Self) i32 {
        return self.parts().year;
    }

    /// 获取月份
    pub fn month(self: Self) Month {
        return @enumFromInt(self.parts().month);
    }

    /// 获取日期
    pub fn day(self: Self) u8 {
        return self.parts().day;
    }

    /// 获取小时
    pub fn hour(self: Self) u8 {
        return self.parts().hour;
    }

    /// 获取分钟
    pub fn minute(self: Self) u8 {
        return self.parts().minute;
    }

    /// 获取秒
    pub fn second(self: Self) u8 {
        return self.parts().second;
    }

    /// 获取星期几
    pub fn weekday(self: Self) Weekday {
        const local_s = @as(i64, @intCast(@divTrunc(self.timestamp_ns, 1000_000_000))) + self.timezone.offset_seconds;
        const days_since_epoch = @divFloor(local_s, 86400);
        // 1970-01-01 是星期四
        const wd = @mod(days_since_epoch + 4, 7);
        return @enumFromInt(@as(u3, @intCast(if (wd < 0) wd + 7 else wd)));
    }

    /// 获取一年中的第几天
    pub fn yearDay(self: Self) u16 {
        return self.parts().year_day;
    }

    /// 获取 Unix 时间戳（秒）
    pub fn timestamp(self: Self) i64 {
        return @intCast(@divTrunc(self.timestamp_ns, 1000_000_000));
    }

    /// 获取 Unix 时间戳（毫秒）
    pub fn timestampMs(self: Self) i64 {
        return @intCast(@divTrunc(self.timestamp_ns, 1000_000));
    }

    // ========================================================================
    // 时区操作
    // ========================================================================

    /// 转换到指定时区
    pub fn inTimezone(self: Self, tz: Timezone) Self {
        return .{
            .timestamp_ns = self.timestamp_ns,
            .timezone = tz,
        };
    }

    /// 转换到 UTC
    pub fn utc(self: Self) Self {
        return self.inTimezone(Timezone.utc);
    }

    /// 转换到本地时区（北京时间）
    pub fn local(self: Self) Self {
        return self.inTimezone(Timezone.beijing);
    }

    // ========================================================================
    // 时间运算
    // ========================================================================

    /// 添加时间段
    pub fn addDuration(self: Self, d: Duration) Self {
        return .{
            .timestamp_ns = self.timestamp_ns + d.nanoseconds,
            .timezone = self.timezone,
        };
    }

    /// 减去时间段
    pub fn subDuration(self: Self, d: Duration) Self {
        return .{
            .timestamp_ns = self.timestamp_ns - d.nanoseconds,
            .timezone = self.timezone,
        };
    }

    /// 添加年份
    pub fn addYears(self: Self, years: i32) Self {
        const p = self.parts();
        const new_year = p.year + years;
        const max_day = Month.days(@enumFromInt(p.month), new_year);
        const new_day = if (p.day > max_day) max_day else p.day;
        return createIn(new_year, p.month, new_day, p.hour, p.minute, p.second, self.timezone);
    }

    /// 添加月份
    pub fn addMonths(self: Self, months: i32) Self {
        const p = self.parts();
        var new_month = @as(i32, p.month) + months;
        var new_year = p.year;

        while (new_month > 12) {
            new_month -= 12;
            new_year += 1;
        }
        while (new_month < 1) {
            new_month += 12;
            new_year -= 1;
        }

        const max_day = Month.days(@enumFromInt(@as(u4, @intCast(new_month))), new_year);
        const new_day = if (p.day > max_day) max_day else p.day;
        return createIn(new_year, @intCast(new_month), new_day, p.hour, p.minute, p.second, self.timezone);
    }

    /// 添加天数
    pub fn addDays(self: Self, days_count: i64) Self {
        return self.addDuration(Duration.days(days_count));
    }

    /// 添加小时
    pub fn addHours(self: Self, hours_count: i64) Self {
        return self.addDuration(Duration.hours(hours_count));
    }

    /// 添加分钟
    pub fn addMinutes(self: Self, minutes_count: i64) Self {
        return self.addDuration(Duration.minutes(minutes_count));
    }

    /// 添加秒
    pub fn addSeconds(self: Self, seconds_count: i64) Self {
        return self.addDuration(Duration.seconds(seconds_count));
    }

    /// 添加时间段（Go 风格）
    ///
    /// 等同于 addDuration，提供更简洁的命名
    pub fn add(self: Self, d: Duration) Self {
        return self.addDuration(d);
    }

    /// 减去时间段（Go 风格）
    ///
    /// 等同于 subDuration，提供更简洁的命名
    pub fn sub(self: Self, d: Duration) Self {
        return self.subDuration(d);
    }

    /// 添加日期（Go 风格 AddDate）
    ///
    /// 同时添加年、月、日，正确处理月份边界：
    /// - 1月31日 + 1个月 = 2月28日（非闰年）或2月29日（闰年）
    /// - 不会像 PHP 那样溢出到下个月
    ///
    /// ## 使用示例
    /// ```zig
    /// const dt = DateTime.create(2025, 1, 31, 12, 0, 0);
    /// const next = dt.addDate(1, 1, 1);  // +1年 +1月 +1日
    /// ```
    pub fn addDate(self: Self, years: i32, months: i32, days_count: i32) Self {
        // 先处理年份
        var result = self.addYears(years);
        // 再处理月份（会正确处理日期溢出）
        result = result.addMonths(months);
        // 最后处理天数
        result = result.addDays(days_count);
        return result;
    }

    /// 减去日期
    pub fn subDate(self: Self, years: i32, months: i32, days_count: i32) Self {
        return self.addDate(-years, -months, -days_count);
    }

    /// 计算从某个时间到现在的时间差（Go 风格 Since）
    ///
    /// 返回从 t 到现在经过的时间。等同于 `now().diff(t)`
    ///
    /// ## 使用示例
    /// ```zig
    /// const start = DateTime.now();
    /// // ... 执行一些操作 ...
    /// const elapsed = DateTime.since(start);
    /// std.debug.print("耗时: {}ms\n", .{elapsed.inMilliseconds()});
    /// ```
    pub fn since(t: Self) Duration {
        return Self.now().diff(t);
    }

    /// 计算从现在到某个时间的时间差（Go 风格 Until）
    ///
    /// 返回从现在到 t 的时间。等同于 `t.diff(now())`
    pub fn until(t: Self) Duration {
        return t.diff(Self.now());
    }

    /// 获取从自身到另一个时间的差值（年、月、日）
    ///
    /// 返回详细的日期差异，而不是单纯的时间戳差
    pub fn diffDate(self: Self, other: Self) DateDiff {
        const p1 = self.parts();
        const p2 = other.parts();

        var years = p2.year - p1.year;
        var months = @as(i32, p2.month) - @as(i32, p1.month);
        var days_diff = @as(i32, p2.day) - @as(i32, p1.day);

        // 处理日期借位
        if (days_diff < 0) {
            months -= 1;
            const prev_month: Month = if (p2.month == 1) .december else @enumFromInt(p2.month - 1);
            const prev_year = if (p2.month == 1) p2.year - 1 else p2.year;
            days_diff += @as(i32, prev_month.days(prev_year));
        }

        // 处理月份借位
        if (months < 0) {
            years -= 1;
            months += 12;
        }

        return .{
            .years = years,
            .months = @intCast(months),
            .days = @intCast(days_diff),
            .negative = self.after(other),
        };
    }

    /// 日期差异结构
    pub const DateDiff = struct {
        years: i32,
        months: u8,
        days: u8,
        negative: bool,

        /// 格式化为人类可读字符串
        pub fn format(self: DateDiff, buf: []u8) []const u8 {
            var parts_list: [3][]const u8 = undefined;
            var count: usize = 0;

            var tmp_buf: [64]u8 = undefined;
            var tmp_pos: usize = 0;

            if (self.years != 0) {
                const abs_years: u32 = @intCast(if (self.years < 0) -self.years else self.years);
                const written = std.fmt.bufPrint(tmp_buf[tmp_pos..], "{d}年", .{abs_years}) catch return "";
                parts_list[count] = tmp_buf[tmp_pos .. tmp_pos + written.len];
                tmp_pos += written.len;
                count += 1;
            }
            if (self.months != 0) {
                const written = std.fmt.bufPrint(tmp_buf[tmp_pos..], "{d}月", .{self.months}) catch return "";
                parts_list[count] = tmp_buf[tmp_pos .. tmp_pos + written.len];
                tmp_pos += written.len;
                count += 1;
            }
            if (self.days != 0 or count == 0) {
                const written = std.fmt.bufPrint(tmp_buf[tmp_pos..], "{d}天", .{self.days}) catch return "";
                parts_list[count] = tmp_buf[tmp_pos .. tmp_pos + written.len];
                tmp_pos += written.len;
                count += 1;
            }

            var pos: usize = 0;
            if (self.negative) {
                const neg = std.fmt.bufPrint(buf[pos..], "-", .{}) catch return "";
                pos += neg.len;
            }
            for (parts_list[0..count]) |part| {
                @memcpy(buf[pos .. pos + part.len], part);
                pos += part.len;
            }

            return buf[0..pos];
        }
    };

    /// 计算两个时间之间的差值
    pub fn diff(self: Self, other: Self) Duration {
        return .{
            .nanoseconds = @intCast(self.timestamp_ns - other.timestamp_ns),
        };
    }

    /// 获取当天的开始时间
    pub fn startOfDay(self: Self) Self {
        const p = self.parts();
        return createIn(p.year, p.month, p.day, 0, 0, 0, self.timezone);
    }

    /// 获取当天的结束时间
    pub fn endOfDay(self: Self) Self {
        const p = self.parts();
        return createIn(p.year, p.month, p.day, 23, 59, 59, self.timezone);
    }

    /// 获取当月的开始时间
    pub fn startOfMonth(self: Self) Self {
        const p = self.parts();
        return createIn(p.year, p.month, 1, 0, 0, 0, self.timezone);
    }

    /// 获取当月的结束时间
    pub fn endOfMonth(self: Self) Self {
        const p = self.parts();
        const m: Month = @enumFromInt(p.month);
        return createIn(p.year, p.month, m.days(p.year), 23, 59, 59, self.timezone);
    }

    /// 获取当年的开始时间
    pub fn startOfYear(self: Self) Self {
        const p = self.parts();
        return createIn(p.year, 1, 1, 0, 0, 0, self.timezone);
    }

    /// 获取当年的结束时间
    pub fn endOfYear(self: Self) Self {
        const p = self.parts();
        return createIn(p.year, 12, 31, 23, 59, 59, self.timezone);
    }

    // ========================================================================
    // 比较操作
    // ========================================================================

    /// 是否早于另一个时间
    pub fn before(self: Self, other: Self) bool {
        return self.timestamp_ns < other.timestamp_ns;
    }

    /// 是否晚于另一个时间
    pub fn after(self: Self, other: Self) bool {
        return self.timestamp_ns > other.timestamp_ns;
    }

    /// 是否相等
    pub fn equal(self: Self, other: Self) bool {
        return self.timestamp_ns == other.timestamp_ns;
    }

    /// 是否在两个时间之间
    pub fn between(self: Self, start: Self, end: Self) bool {
        return !self.before(start) and !self.after(end);
    }

    /// 是否是闰年
    pub fn isLeap(self: Self) bool {
        return isLeapYear(self.year());
    }

    /// 是否是今天
    pub fn isToday(self: Self) bool {
        const t = Self.today().inTimezone(self.timezone);
        const p1 = self.parts();
        const p2 = t.parts();
        return p1.year == p2.year and p1.month == p2.month and p1.day == p2.day;
    }

    /// 是否是过去的时间
    pub fn isPast(self: Self) bool {
        return self.before(Self.now());
    }

    /// 是否是未来的时间
    pub fn isFuture(self: Self) bool {
        return self.after(Self.now());
    }

    // ========================================================================
    // 格式化
    // ========================================================================

    /// PHP 风格格式化
    ///
    /// 支持的格式符：
    /// - Y: 4 位年份
    /// - y: 2 位年份
    /// - m: 月份（01-12）
    /// - n: 月份（1-12）
    /// - d: 日期（01-31）
    /// - j: 日期（1-31）
    /// - H: 小时（00-23）
    /// - G: 小时（0-23）
    /// - i: 分钟（00-59）
    /// - s: 秒（00-59）
    /// - A: AM/PM
    /// - a: am/pm
    /// - D: 星期缩写
    /// - l: 星期全称
    /// - M: 月份缩写
    /// - F: 月份全称
    /// - w: 星期数字（0-6）
    /// - N: ISO 星期数字（1-7）
    /// - z: 一年中的第几天
    /// - W: ISO 周数
    /// - U: Unix 时间戳
    pub fn formatPhp(self: Self, fmt: []const u8, buf: []u8) []const u8 {
        const p = self.parts();
        var pos: usize = 0;

        for (fmt) |c| {
            if (pos >= buf.len) break;

            const written = switch (c) {
                'Y' => std.fmt.bufPrint(buf[pos..], "{d:0>4}", .{@as(u32, @intCast(p.year))}) catch break,
                'y' => std.fmt.bufPrint(buf[pos..], "{d:0>2}", .{@as(u32, @intCast(@mod(p.year, 100)))}) catch break,
                'm' => std.fmt.bufPrint(buf[pos..], "{d:0>2}", .{p.month}) catch break,
                'n' => std.fmt.bufPrint(buf[pos..], "{d}", .{p.month}) catch break,
                'd' => std.fmt.bufPrint(buf[pos..], "{d:0>2}", .{p.day}) catch break,
                'j' => std.fmt.bufPrint(buf[pos..], "{d}", .{p.day}) catch break,
                'H' => std.fmt.bufPrint(buf[pos..], "{d:0>2}", .{p.hour}) catch break,
                'G' => std.fmt.bufPrint(buf[pos..], "{d}", .{p.hour}) catch break,
                'i' => std.fmt.bufPrint(buf[pos..], "{d:0>2}", .{p.minute}) catch break,
                's' => std.fmt.bufPrint(buf[pos..], "{d:0>2}", .{p.second}) catch break,
                'A' => blk: {
                    const s = if (p.hour < 12) "AM" else "PM";
                    break :blk std.fmt.bufPrint(buf[pos..], "{s}", .{s}) catch break;
                },
                'a' => blk: {
                    const s = if (p.hour < 12) "am" else "pm";
                    break :blk std.fmt.bufPrint(buf[pos..], "{s}", .{s}) catch break;
                },
                'D' => std.fmt.bufPrint(buf[pos..], "{s}", .{p.weekday.shortName()}) catch break,
                'l' => std.fmt.bufPrint(buf[pos..], "{s}", .{p.weekday.name()}) catch break,
                'M' => blk: {
                    const m: Month = @enumFromInt(p.month);
                    break :blk std.fmt.bufPrint(buf[pos..], "{s}", .{m.shortName()}) catch break;
                },
                'F' => blk: {
                    const m: Month = @enumFromInt(p.month);
                    break :blk std.fmt.bufPrint(buf[pos..], "{s}", .{m.name()}) catch break;
                },
                'w' => std.fmt.bufPrint(buf[pos..], "{d}", .{@intFromEnum(p.weekday)}) catch break,
                'N' => blk: {
                    const n = if (@intFromEnum(p.weekday) == 0) @as(u8, 7) else @intFromEnum(p.weekday);
                    break :blk std.fmt.bufPrint(buf[pos..], "{d}", .{n}) catch break;
                },
                'z' => std.fmt.bufPrint(buf[pos..], "{d}", .{p.year_day}) catch break,
                'U' => std.fmt.bufPrint(buf[pos..], "{d}", .{self.timestamp()}) catch break,
                else => blk: {
                    buf[pos] = c;
                    break :blk buf[pos .. pos + 1];
                },
            };
            pos += written.len;
        }

        return buf[0..pos];
    }

    /// Go 风格格式化
    ///
    /// 参考时间：Mon Jan 2 15:04:05 MST 2006
    /// - 2006: 年份
    /// - 01: 月份（01-12）
    /// - 1: 月份（1-12）
    /// - 02: 日期（01-31）
    /// - 2: 日期（1-31）
    /// - 15: 小时（00-23）
    /// - 3: 小时（1-12）
    /// - 04: 分钟（00-59）
    /// - 4: 分钟（0-59）
    /// - 05: 秒（00-59）
    /// - 5: 秒（0-59）
    /// - PM/AM: 上下午
    /// - Mon: 星期缩写
    /// - Monday: 星期全称
    /// - Jan: 月份缩写
    /// - January: 月份全称
    pub fn formatGo(self: Self, fmt: []const u8, buf: []u8) []const u8 {
        const p = self.parts();
        var pos: usize = 0;
        var i: usize = 0;

        while (i < fmt.len and pos < buf.len) {
            const remaining = fmt[i..];

            // 尝试匹配 Go 格式符号
            if (matchPrefix(remaining, "2006")) {
                const w = std.fmt.bufPrint(buf[pos..], "{d:0>4}", .{@as(u32, @intCast(p.year))}) catch break;
                pos += w.len;
                i += 4;
            } else if (matchPrefix(remaining, "01")) {
                const w = std.fmt.bufPrint(buf[pos..], "{d:0>2}", .{p.month}) catch break;
                pos += w.len;
                i += 2;
            } else if (matchPrefix(remaining, "02")) {
                const w = std.fmt.bufPrint(buf[pos..], "{d:0>2}", .{p.day}) catch break;
                pos += w.len;
                i += 2;
            } else if (matchPrefix(remaining, "15")) {
                const w = std.fmt.bufPrint(buf[pos..], "{d:0>2}", .{p.hour}) catch break;
                pos += w.len;
                i += 2;
            } else if (matchPrefix(remaining, "04")) {
                const w = std.fmt.bufPrint(buf[pos..], "{d:0>2}", .{p.minute}) catch break;
                pos += w.len;
                i += 2;
            } else if (matchPrefix(remaining, "05")) {
                const w = std.fmt.bufPrint(buf[pos..], "{d:0>2}", .{p.second}) catch break;
                pos += w.len;
                i += 2;
            } else if (matchPrefix(remaining, "1")) {
                const w = std.fmt.bufPrint(buf[pos..], "{d}", .{p.month}) catch break;
                pos += w.len;
                i += 1;
            } else if (matchPrefix(remaining, "2")) {
                const w = std.fmt.bufPrint(buf[pos..], "{d}", .{p.day}) catch break;
                pos += w.len;
                i += 1;
            } else if (matchPrefix(remaining, "3")) {
                const h12 = if (p.hour == 0) @as(u8, 12) else if (p.hour > 12) p.hour - 12 else p.hour;
                const w = std.fmt.bufPrint(buf[pos..], "{d}", .{h12}) catch break;
                pos += w.len;
                i += 1;
            } else if (matchPrefix(remaining, "4")) {
                const w = std.fmt.bufPrint(buf[pos..], "{d}", .{p.minute}) catch break;
                pos += w.len;
                i += 1;
            } else if (matchPrefix(remaining, "5")) {
                const w = std.fmt.bufPrint(buf[pos..], "{d}", .{p.second}) catch break;
                pos += w.len;
                i += 1;
            } else if (matchPrefix(remaining, "PM")) {
                const s = if (p.hour < 12) "AM" else "PM";
                const w = std.fmt.bufPrint(buf[pos..], "{s}", .{s}) catch break;
                pos += w.len;
                i += 2;
            } else if (matchPrefix(remaining, "pm")) {
                const s = if (p.hour < 12) "am" else "pm";
                const w = std.fmt.bufPrint(buf[pos..], "{s}", .{s}) catch break;
                pos += w.len;
                i += 2;
            } else if (matchPrefix(remaining, "Monday")) {
                const w = std.fmt.bufPrint(buf[pos..], "{s}", .{p.weekday.name()}) catch break;
                pos += w.len;
                i += 6;
            } else if (matchPrefix(remaining, "Mon")) {
                const w = std.fmt.bufPrint(buf[pos..], "{s}", .{p.weekday.shortName()}) catch break;
                pos += w.len;
                i += 3;
            } else if (matchPrefix(remaining, "January")) {
                const m: Month = @enumFromInt(p.month);
                const w = std.fmt.bufPrint(buf[pos..], "{s}", .{m.name()}) catch break;
                pos += w.len;
                i += 7;
            } else if (matchPrefix(remaining, "Jan")) {
                const m: Month = @enumFromInt(p.month);
                const w = std.fmt.bufPrint(buf[pos..], "{s}", .{m.shortName()}) catch break;
                pos += w.len;
                i += 3;
            } else if (matchPrefix(remaining, "MST")) {
                const w = std.fmt.bufPrint(buf[pos..], "{s}", .{self.timezone.name}) catch break;
                pos += w.len;
                i += 3;
            } else {
                buf[pos] = fmt[i];
                pos += 1;
                i += 1;
            }
        }

        return buf[0..pos];
    }

    /// ISO 8601 格式
    pub fn toIso8601(self: Self, buf: []u8) []const u8 {
        return self.formatPhp("Y-m-dTH:i:s", buf);
    }

    /// RFC 3339 格式
    pub fn toRfc3339(self: Self, buf: []u8) []const u8 {
        const p = self.parts();
        const offset_h = @divTrunc(self.timezone.offset_seconds, 3600);
        const offset_m = @mod(@divTrunc(self.timezone.offset_seconds, 60), 60);

        if (self.timezone.offset_seconds == 0) {
            const written = std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
                p.year, p.month, p.day, p.hour, p.minute, p.second,
            }) catch return "";
            return written;
        } else {
            const sign: u8 = if (offset_h >= 0) '+' else '-';
            const abs_h: u32 = @intCast(if (offset_h < 0) -offset_h else offset_h);
            const abs_m: u32 = @intCast(if (offset_m < 0) -offset_m else offset_m);
            const written = std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}{c}{d:0>2}:{d:0>2}", .{
                p.year, p.month, p.day, p.hour, p.minute, p.second, sign, abs_h, abs_m,
            }) catch return "";
            return written;
        }
    }

    // ========================================================================
    // 解析
    // ========================================================================

    /// 从 PHP 格式解析
    pub fn parsePhp(str: []const u8, fmt: []const u8) !Self {
        var year_val: i32 = 1970;
        var month_val: u4 = 1;
        var day_val: u8 = 1;
        var hour_val: u8 = 0;
        var minute_val: u8 = 0;
        var second_val: u8 = 0;

        var str_pos: usize = 0;

        for (fmt) |c| {
            if (str_pos >= str.len) break;

            switch (c) {
                'Y' => {
                    if (str_pos + 4 > str.len) return error.InvalidFormat;
                    year_val = std.fmt.parseInt(i32, str[str_pos .. str_pos + 4], 10) catch return error.InvalidFormat;
                    str_pos += 4;
                },
                'y' => {
                    if (str_pos + 2 > str.len) return error.InvalidFormat;
                    const y = std.fmt.parseInt(i32, str[str_pos .. str_pos + 2], 10) catch return error.InvalidFormat;
                    year_val = if (y >= 70) 1900 + y else 2000 + y;
                    str_pos += 2;
                },
                'm', 'n' => {
                    const len = if (c == 'm') @as(usize, 2) else findDigitLen(str[str_pos..]);
                    if (str_pos + len > str.len) return error.InvalidFormat;
                    month_val = std.fmt.parseInt(u4, str[str_pos .. str_pos + len], 10) catch return error.InvalidFormat;
                    str_pos += len;
                },
                'd', 'j' => {
                    const len = if (c == 'd') @as(usize, 2) else findDigitLen(str[str_pos..]);
                    if (str_pos + len > str.len) return error.InvalidFormat;
                    day_val = std.fmt.parseInt(u8, str[str_pos .. str_pos + len], 10) catch return error.InvalidFormat;
                    str_pos += len;
                },
                'H', 'G' => {
                    const len = if (c == 'H') @as(usize, 2) else findDigitLen(str[str_pos..]);
                    if (str_pos + len > str.len) return error.InvalidFormat;
                    hour_val = std.fmt.parseInt(u8, str[str_pos .. str_pos + len], 10) catch return error.InvalidFormat;
                    str_pos += len;
                },
                'i' => {
                    if (str_pos + 2 > str.len) return error.InvalidFormat;
                    minute_val = std.fmt.parseInt(u8, str[str_pos .. str_pos + 2], 10) catch return error.InvalidFormat;
                    str_pos += 2;
                },
                's' => {
                    if (str_pos + 2 > str.len) return error.InvalidFormat;
                    second_val = std.fmt.parseInt(u8, str[str_pos .. str_pos + 2], 10) catch return error.InvalidFormat;
                    str_pos += 2;
                },
                else => {
                    str_pos += 1;
                },
            }
        }

        return Self.create(year_val, month_val, day_val, hour_val, minute_val, second_val);
    }

    /// 从 ISO 8601 格式解析
    pub fn parseIso8601(str: []const u8) !Self {
        return Self.parsePhp(str, "Y-m-dTH:i:s");
    }
};

// ============================================================================
// 辅助函数
// ============================================================================

/// 是否是闰年
pub fn isLeapYear(year: i32) bool {
    return (@mod(year, 4) == 0 and @mod(year, 100) != 0) or @mod(year, 400) == 0;
}

/// 日期转时间戳
fn dateToTimestamp(year: i32, month: u4, day: u8, hour: u8, minute: u8, second: u8) i64 {
    // 计算从 1970 年到指定年份的天数
    var days: i64 = 0;
    var y: i32 = 1970;

    if (year >= 1970) {
        while (y < year) : (y += 1) {
            days += if (isLeapYear(y)) 366 else 365;
        }
    } else {
        while (y > year) : (y -= 1) {
            days -= if (isLeapYear(y - 1)) 366 else 365;
        }
    }

    // 加上当年的月份天数
    const month_days = [_]u8{ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    var m: u4 = 1;
    while (m < month) : (m += 1) {
        days += month_days[m];
        if (m == 2 and isLeapYear(year)) {
            days += 1;
        }
    }

    days += day - 1;

    return days * 86400 + @as(i64, hour) * 3600 + @as(i64, minute) * 60 + second;
}

/// 时间戳转日期
fn timestampToDate(ts: i64, year: *i32, month: *u4, day: *u8, hour: *u8, minute: *u8, second: *u8, yday: *u16) void {
    var rem = ts;

    // 计算时分秒
    second.* = @intCast(@mod(rem, 60));
    rem = @divTrunc(rem, 60);
    minute.* = @intCast(@mod(rem, 60));
    rem = @divTrunc(rem, 60);
    hour.* = @intCast(@mod(rem, 24));
    var days = @divFloor(rem, 24);

    // 计算年份
    var y: i32 = 1970;
    if (days >= 0) {
        while (true) {
            const year_days: i64 = if (isLeapYear(y)) 366 else 365;
            if (days < year_days) break;
            days -= year_days;
            y += 1;
        }
    } else {
        while (days < 0) {
            y -= 1;
            days += if (isLeapYear(y)) 366 else 365;
        }
    }
    year.* = y;
    yday.* = @intCast(days);

    // 计算月份和日期
    const month_days = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    var m: u4 = 1;
    while (m <= 12) : (m += 1) {
        var md: i64 = month_days[m - 1];
        if (m == 2 and isLeapYear(y)) {
            md = 29;
        }
        if (days < md) break;
        days -= md;
    }

    month.* = m;
    day.* = @intCast(days + 1);
}

/// 检查前缀匹配
fn matchPrefix(str: []const u8, prefix: []const u8) bool {
    if (str.len < prefix.len) return false;
    return std.mem.eql(u8, str[0..prefix.len], prefix);
}

/// 查找连续数字长度
fn findDigitLen(str: []const u8) usize {
    var len: usize = 0;
    for (str) |c| {
        if (c >= '0' and c <= '9') {
            len += 1;
        } else {
            break;
        }
    }
    return if (len == 0) 1 else len;
}

// ============================================================================
// 便捷函数
// ============================================================================

/// 获取当前时间（UTC）
pub fn now() DateTime {
    return DateTime.now();
}

/// 获取当前时间（北京时间）
pub fn nowBeijing() DateTime {
    return DateTime.nowIn(Timezone.beijing);
}

/// 获取今天的开始
pub fn today() DateTime {
    return DateTime.today();
}

/// 创建日期时间
pub fn create(year: i32, month: u4, day: u8, hour: u8, minute: u8, second: u8) DateTime {
    return DateTime.create(year, month, day, hour, minute, second);
}

/// 从时间戳创建
pub fn fromTimestamp(ts: i64) DateTime {
    return DateTime.fromTimestamp(ts);
}

/// 解析日期时间字符串
pub fn parse(str: []const u8, fmt: []const u8) !DateTime {
    return DateTime.parsePhp(str, fmt);
}

// ============================================================================
// 测试
// ============================================================================

test "DateTime: now" {
    const dt = DateTime.now();
    try std.testing.expect(dt.timestamp() > 0);
}

test "DateTime: create" {
    const dt = DateTime.create(2025, 12, 6, 9, 30, 0);
    const p = dt.parts();
    try std.testing.expectEqual(@as(i32, 2025), p.year);
    try std.testing.expectEqual(@as(u4, 12), p.month);
    try std.testing.expectEqual(@as(u8, 6), p.day);
    try std.testing.expectEqual(@as(u8, 9), p.hour);
    try std.testing.expectEqual(@as(u8, 30), p.minute);
    try std.testing.expectEqual(@as(u8, 0), p.second);
}

test "DateTime: formatPhp" {
    const dt = DateTime.create(2025, 12, 6, 9, 5, 3);
    var buf: [64]u8 = undefined;

    const s1 = dt.formatPhp("Y-m-d H:i:s", &buf);
    try std.testing.expectEqualStrings("2025-12-06 09:05:03", s1);

    const s2 = dt.formatPhp("Y/n/j", &buf);
    try std.testing.expectEqualStrings("2025/12/6", s2);

    const s3 = dt.formatPhp("D, d M Y", &buf);
    try std.testing.expect(s3.len > 0);
}

test "DateTime: formatGo" {
    const dt = DateTime.create(2025, 12, 6, 9, 5, 3);
    var buf: [64]u8 = undefined;

    const s1 = dt.formatGo("2006-01-02 15:04:05", &buf);
    try std.testing.expectEqualStrings("2025-12-06 09:05:03", s1);

    const s2 = dt.formatGo("2006/1/2", &buf);
    try std.testing.expectEqualStrings("2025/12/6", s2);
}

test "DateTime: parsePhp" {
    const dt = try DateTime.parsePhp("2025-12-06 09:30:00", "Y-m-d H:i:s");
    const p = dt.parts();
    try std.testing.expectEqual(@as(i32, 2025), p.year);
    try std.testing.expectEqual(@as(u4, 12), p.month);
    try std.testing.expectEqual(@as(u8, 6), p.day);
    try std.testing.expectEqual(@as(u8, 9), p.hour);
    try std.testing.expectEqual(@as(u8, 30), p.minute);
}

test "DateTime: timezone" {
    const utc = DateTime.create(2025, 12, 6, 0, 0, 0);
    const beijing = utc.inTimezone(Timezone.beijing);

    try std.testing.expectEqual(utc.timestamp(), beijing.timestamp()); // 时间戳相同

    const utc_p = utc.parts();
    const bj_p = beijing.parts();
    try std.testing.expectEqual(@as(u8, 0), utc_p.hour);
    try std.testing.expectEqual(@as(u8, 8), bj_p.hour); // 北京时间 +8 小时
}

test "DateTime: addDuration" {
    const dt = DateTime.create(2025, 12, 6, 9, 0, 0);

    const dt2 = dt.addDuration(Duration.hours(2));
    try std.testing.expectEqual(@as(u8, 11), dt2.hour());

    const dt3 = dt.addDays(1);
    try std.testing.expectEqual(@as(u8, 7), dt3.day());
}

test "DateTime: addMonths" {
    const dt = DateTime.create(2025, 1, 31, 0, 0, 0);
    const dt2 = dt.addMonths(1);
    try std.testing.expectEqual(@as(u4, 2), dt2.parts().month);
    try std.testing.expectEqual(@as(u8, 28), dt2.parts().day); // 2 月没有 31 号
}

test "DateTime: diff" {
    const dt1 = DateTime.create(2025, 12, 6, 10, 0, 0);
    const dt2 = DateTime.create(2025, 12, 6, 9, 0, 0);
    const d = dt1.diff(dt2);
    try std.testing.expectEqual(@as(i64, 1), d.inHours());
}

test "DateTime: compare" {
    const dt1 = DateTime.create(2025, 12, 6, 10, 0, 0);
    const dt2 = DateTime.create(2025, 12, 6, 9, 0, 0);

    try std.testing.expect(dt1.after(dt2));
    try std.testing.expect(dt2.before(dt1));
    try std.testing.expect(!dt1.equal(dt2));
}

test "isLeapYear" {
    try std.testing.expect(isLeapYear(2000));
    try std.testing.expect(isLeapYear(2024));
    try std.testing.expect(!isLeapYear(2023));
    try std.testing.expect(!isLeapYear(1900));
}

test "Month: days" {
    try std.testing.expectEqual(@as(u8, 31), Month.january.days(2025));
    try std.testing.expectEqual(@as(u8, 28), Month.february.days(2025));
    try std.testing.expectEqual(@as(u8, 29), Month.february.days(2024));
    try std.testing.expectEqual(@as(u8, 30), Month.april.days(2025));
}

test "Duration: operations" {
    const d1 = Duration.hours(2);
    const d2 = Duration.minutes(30);
    const d3 = d1.add(d2);

    try std.testing.expectEqual(@as(i64, 150), d3.inMinutes());
}

test "DateTime: addDate 正确处理月份边界" {
    // PHP 的 BUG：1月31日 + 1个月 = 3月3日
    // 正确行为：1月31日 + 1个月 = 2月28日（非闰年）
    const dt1 = DateTime.create(2025, 1, 31, 12, 0, 0);
    const dt2 = dt1.addDate(0, 1, 0); // +1个月
    try std.testing.expectEqual(@as(u4, 2), dt2.parts().month);
    try std.testing.expectEqual(@as(u8, 28), dt2.parts().day); // 2月28日，不是3月3日

    // 闰年测试
    const dt3 = DateTime.create(2024, 1, 31, 12, 0, 0);
    const dt4 = dt3.addDate(0, 1, 0);
    try std.testing.expectEqual(@as(u4, 2), dt4.parts().month);
    try std.testing.expectEqual(@as(u8, 29), dt4.parts().day); // 2024是闰年，2月29日

    // 组合添加
    const dt5 = DateTime.create(2025, 1, 15, 12, 0, 0);
    const dt6 = dt5.addDate(1, 2, 5); // +1年 +2月 +5日
    try std.testing.expectEqual(@as(i32, 2026), dt6.parts().year);
    try std.testing.expectEqual(@as(u4, 3), dt6.parts().month);
    try std.testing.expectEqual(@as(u8, 20), dt6.parts().day);
}

test "DateTime: add/sub 简洁方法" {
    const dt = DateTime.create(2025, 12, 6, 9, 0, 0);

    const dt2 = dt.add(Duration.hours(3));
    try std.testing.expectEqual(@as(u8, 12), dt2.hour());

    const dt3 = dt.sub(Duration.hours(2));
    try std.testing.expectEqual(@as(u8, 7), dt3.hour());
}

test "DateTime: diffDate 日期差异" {
    const dt1 = DateTime.create(2025, 1, 15, 0, 0, 0);
    const dt2 = DateTime.create(2026, 3, 20, 0, 0, 0);

    const diff_result = dt1.diffDate(dt2);
    try std.testing.expectEqual(@as(i32, 1), diff_result.years);
    try std.testing.expectEqual(@as(u8, 2), diff_result.months);
    try std.testing.expectEqual(@as(u8, 5), diff_result.days);
    try std.testing.expect(!diff_result.negative);
}

test "Duration: 更多转换方法" {
    const d = Duration.seconds(90061); // 1天1小时1分1秒

    try std.testing.expectEqual(@as(i64, 1), d.inDays());
    try std.testing.expectEqual(@as(i64, 25), d.inHours());
    try std.testing.expectEqual(@as(i64, 1501), d.inMinutes());
    try std.testing.expectEqual(@as(i64, 90061), d.inSeconds());
    try std.testing.expectEqual(@as(i64, 90061000), d.inMilliseconds());

    // 绝对值
    const neg = Duration.seconds(-100);
    try std.testing.expect(neg.isNegative());
    try std.testing.expectEqual(@as(i64, 100), neg.abs().inSeconds());
}
