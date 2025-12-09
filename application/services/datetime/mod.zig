//! 日期时间模块
//!
//! 提供类似 PHP date() 和 Go time 包的日期时间处理功能。
//!
//! ## 功能特性
//!
//! - **时区支持**：内置常用时区，支持自定义时区
//! - **PHP 风格格式化**：Y-m-d H:i:s 等
//! - **Go 风格格式化**：2006-01-02 15:04:05 等
//! - **日期运算**：加减年/月/日/时/分/秒
//! - **日期比较**：before/after/equal/between
//! - **便捷方法**：today/tomorrow/yesterday/startOfDay 等
//!
//! ## 快速开始
//!
//! ```zig
//! const datetime = @import("services/datetime/mod.zig");
//!
//! // 获取当前时间
//! var now = datetime.now();
//!
//! // 北京时间
//! var beijing = datetime.nowBeijing();
//!
//! // 格式化
//! var buf: [64]u8 = undefined;
//! const str = now.formatPhp("Y-m-d H:i:s", &buf);
//!
//! // 解析
//! const dt = try datetime.parse("2025-12-06 09:00:00", "Y-m-d H:i:s");
//!
//! // 日期运算
//! const tomorrow = now.addDays(1);
//! const next_month = now.addMonths(1);
//! ```
//!
//! ## PHP 格式符号
//!
//! | 符号 | 说明 | 示例 |
//! |------|------|------|
//! | Y | 4 位年份 | 2025 |
//! | y | 2 位年份 | 25 |
//! | m | 月份(01-12) | 12 |
//! | n | 月份(1-12) | 12 |
//! | d | 日期(01-31) | 06 |
//! | j | 日期(1-31) | 6 |
//! | H | 小时(00-23) | 09 |
//! | G | 小时(0-23) | 9 |
//! | i | 分钟(00-59) | 05 |
//! | s | 秒(00-59) | 03 |
//! | A | AM/PM | AM |
//! | a | am/pm | am |
//! | D | 星期缩写 | Sat |
//! | l | 星期全称 | Saturday |
//! | M | 月份缩写 | Dec |
//! | F | 月份全称 | December |
//!
//! ## Go 格式符号
//!
//! | 符号 | 说明 | 示例 |
//! |------|------|------|
//! | 2006 | 4 位年份 | 2025 |
//! | 01 | 月份(01-12) | 12 |
//! | 1 | 月份(1-12) | 12 |
//! | 02 | 日期(01-31) | 06 |
//! | 2 | 日期(1-31) | 6 |
//! | 15 | 小时(00-23) | 09 |
//! | 3 | 小时(1-12) | 9 |
//! | 04 | 分钟(00-59) | 05 |
//! | 05 | 秒(00-59) | 03 |
//! | PM | AM/PM | AM |
//! | Mon | 星期缩写 | Sat |
//! | Monday | 星期全称 | Saturday |
//! | Jan | 月份缩写 | Dec |
//! | January | 月份全称 | December |

const dt = @import("datetime.zig");

// 核心类型
pub const DateTime = dt.DateTime;
pub const Timezone = dt.Timezone;
pub const Duration = dt.Duration;
pub const Month = dt.Month;
pub const Weekday = dt.Weekday;

// 便捷函数
pub const now = dt.now;
pub const nowBeijing = dt.nowBeijing;
pub const today = dt.today;
pub const create = dt.create;
pub const fromTimestamp = dt.fromTimestamp;
pub const parse = dt.parse;
pub const isLeapYear = dt.isLeapYear;

test {
    _ = dt;
}
