//! # Zig 字符串安全处理模块
//!
//! ## 核心概念：切片 (Slice) 的内存结构
//!
//! ```
//! []u8 / []const u8 本质是一个胖指针：
//! ┌─────────────────────────┐
//! │ ptr: [*]u8   (8字节)    │ → 指向实际数据
//! │ len: usize   (8字节)    │ → 数据长度
//! └─────────────────────────┘
//! ```
//!
//! ## 四种 const 组合
//!
//! ```
//! []u8             → 切片可改，数据可改
//! []const u8       → 切片可改，数据只读  ← 最常用
//! const []u8       → 切片只读，数据可改
//! const []const u8 → 切片只读，数据只读
//!
//! 记忆：左边 const 锁切片，右边 const 锁数据
//! ```
//!
//! ## ❌ 危险模式：返回栈内存
//!
//! ```zig
//! fn bad() []const u8 {
//!     var buf: [100]u8 = undefined;  // 栈上分配
//!     return buf[0..];                // 函数返回后，栈帧销毁，悬挂指针！
//! }
//! ```
//!
//! ## ✅ 四种安全策略
//!
//! ### 策略1: 原地修改 (In-Place) - 零分配
//! ```zig
//! pub fn toLowerInPlace(str: []u8) []u8;
//!
//! // 使用：
//! var buf = "HELLO".*;
//! _ = toLowerInPlace(&buf);  // buf 变成 "hello"
//! ```
//!
//! ### 策略2: 调用者提供缓冲区 - 调用者控制生命周期
//! ```zig
//! pub fn toLowerBuf(dest: []u8, src: []const u8) []u8;
//!
//! // 使用：
//! var buf: [100]u8 = undefined;
//! const result = toLowerBuf(&buf, "HELLO");  // 写入 buf
//! ```
//!
//! ### 策略3: 堆分配 - 调用者需释放
//! ```zig
//! pub fn toLowerAlloc(allocator: Allocator, str: []const u8) ![]u8;
//!
//! // 使用：
//! const result = try toLowerAlloc(allocator, "HELLO");
//! defer allocator.free(result);  // 必须释放！
//! ```
//!
//! ### 策略4: 静态缓冲区 - 仅临时使用
//! ```zig
//! pub fn toLowerTemp(str: []const u8) []const u8;
//!
//! // 使用：仅用于立即消费，如日志
//! std.log.info("{s}", .{toLowerTemp("HELLO")});
//! // ⚠️ 不要保存返回值！下次调用会覆盖！
//! ```
//!
//! ## 选择指南
//!
//! | 场景                   | 策略   | 函数后缀        |
//! |------------------------|--------|-----------------|
//! | 有可变数据，想原地改    | 策略1  | `InPlace`       |
//! | 栈上有缓冲区可复用      | 策略2  | `Buf`           |
//! | 需要持久保存结果        | 策略3  | `Alloc`         |
//! | 仅日志打印等临时用      | 策略4  | `Temp`          |
//!
//! ## 安全函数 vs 危险函数
//!
//! ```
//! ✅ 安全：返回输入的子切片 (trim/ltrim/rtrim)
//!    → 不创建新内存，生命周期跟随输入
//!
//! ✅ 安全：原地修改 (toLowerInPlace/strrev)
//!    → 修改调用者的内存，无新分配
//!
//! ✅ 安全：堆分配 (toLowerAlloc/repeat)
//!    → 明确所有权转移，调用者负责释放
//!
//! ⚠️ 需注意：静态缓冲区 (sprinf/toLowerTemp)
//!    → 下次调用覆盖，仅临时使用
//! ```
//!
//！ ┌─────────────────────────────────────────────────────────────────────────────┐
//！ │                    Zig 字符串处理的四种安全策略                               │
//！ ├─────────────────────────────────────────────────────────────────────────────┤
//！ │                                                                             │
//！ │  策略1: 原地修改 (In-Place)                                                  │
//！ │  ─────────────────────────                                                  │
//！ │  toLowerInPlace(str: []u8) → []u8                                          │
//！ │                                                                             │
//！ │  调用前:  var buf = "HELLO".*;                                              │
//！ │          ┌───┬───┬───┬───┬───┐                                             │
//！ │          │ H │ E │ L │ L │ O │  ← buf 的内存                                │
//！ │          └───┴───┴───┴───┴───┘                                             │
//！ │                                                                             │
//！ │  调用后:  toLowerInPlace(&buf);                                             │
//！ │          ┌───┬───┬───┬───┬───┐                                             │
//！ │          │ h │ e │ l │ l │ o │  ← 同一块内存，内容被修改                      │
//！ │          └───┴───┴───┴───┴───┘                                             │
//！ │                                                                             │
//！ │  ✅ 优点: 零分配，最快                                                       │
//！ │  ⚠️ 要求: 必须是可变切片 []u8                                                │
//！ │                                                                             │
//！ ├─────────────────────────────────────────────────────────────────────────────┤
//！ │                                                                             │
//！ │  策略2: 调用者提供缓冲区 (Caller Buffer)                                      │
//！ │  ─────────────────────────────────────                                      │
//！ │  toLowerBuf(dest: []u8, src: []const u8) → []u8                            │
//！ │                                                                             │
//！ │  const src = "HELLO";           dest (调用者的)                             │
//！ │  ┌───┬───┬───┬───┬───┐         ┌───┬───┬───┬───┬───┐                       │
//！ │  │ H │ E │ L │ L │ O │   →→→   │ h │ e │ l │ l │ o │                       │
//！ │  └───┴───┴───┴───┴───┘         └───┴───┴───┴───┴───┘                       │
//！ │  (只读，不变)                   (写入调用者的缓冲区)                          │
//！ │                                                                             │
//！ │  ✅ 优点: 高效，调用者控制生命周期                                            │
//！ │  ⚠️ 要求: 调用者准备足够大的缓冲区                                           │
//！ │                                                                             │
//！ ├─────────────────────────────────────────────────────────────────────────────┤
//！ │                                                                             │
//！ │  策略3: 堆分配 (Heap Allocation)                                             │
//！ │  ───────────────────────────────                                            │
//！ │  toLowerAlloc(allocator, src: []const u8) → ![]u8                          │
//！ │                                                                             │
//！ │  const src = "HELLO";                                                       │
//！ │  ┌───┬───┬───┬───┬───┐         堆内存 (新分配)                              │
//！ │  │ H │ E │ L │ L │ O │   →→→   ┌───┬───┬───┬───┬───┐                       │
//！ │  └───┴───┴───┴───┴───┘         │ h │ e │ l │ l │ o │                       │
//！ │                                └───┴───┴───┴───┴───┘                       │
//！ │                                      ↑                                     │
//！ │                                调用者必须 free!                             │
//！ │                                                                             │
//！ │  ✅ 优点: 最灵活，可持久保存                                                  │
//！ │  ⚠️ 要求: 调用者负责 allocator.free(result)                                 │
//！ │                                                                             │
//！ ├─────────────────────────────────────────────────────────────────────────────┤
//！ │                                                                             │
//！ │  策略4: 静态缓冲区 (Static Buffer)                                           │
//！ │  ─────────────────────────────────                                          │
//！ │  toLowerTemp(src: []const u8) → []const u8                                 │
//！ │                                                                             │
//！ │          静态内存 (threadlocal)                                             │
//！ │          ┌───┬───┬───┬───┬───┬───┬───...                                   │
//！ │  调用1:   │ h │ e │ l │ l │ o │   │   │   → 返回 [0..5]                      │
//！ │          └───┴───┴───┴───┴───┴───┴───...                                   │
//！ │          ┌───┬───┬───┬───┬───┬───┬───...                                   │
//！ │  调用2:   │ w │ o │ r │ l │ d │   │   │   → 覆盖了! 之前的结果失效                │
//！ │          └───┴───┴───┴───┴───┴───┴───...                                    │
//！ │                                                                             │
//！ │  ✅ 优点: 简单，无需手动释放                                                    │
//！ │  ⚠️ 警告: 仅用于立即消费！不要保存返回值！                                      │
//！ │                                                       │
//！ │                                                                             │
//！ └─────────────────────────────────────────────────────────────────────────────┘

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 将字符串分割为字符串切片
pub fn split(allocator: Allocator, str: []const u8, delimiter: []const u8) ![][]const u8 {
    var parts = std.ArrayListUnmanaged([]const u8){};
    defer parts.deinit(allocator);
    var iter = std.mem.splitSequence(u8, str, delimiter);
    while (iter.next()) |part| {
        try parts.append(allocator, part);
    }
    return try parts.toOwnedSlice(allocator);
}

/// 将字符串转换为数字类型
pub inline fn to_int(str: []const u8) !usize {
    return try std.fmt.parseInt(usize, str, 10);
}

/// 将字符串转为浮点类型
pub inline fn to_float(comptime T: type, str: []const u8) !T {
    return try std.fmt.parseFloat(T, str);
}

/// 将字符串简单转换为bool值
pub fn to_bool(str: ?[]const u8) bool {
    if (str == null) return false;
    if (str.len == 0 or eql(str, "false") or eql(str, "0") or eql(str, " ")) {
        return false;
    }
    return true;
}

/// 判断字符串是否相等
pub inline fn eql(str1: []const u8, str2: []const u8) bool {
    return std.mem.eql(u8, str1, str2);
}

/// 将字符串切片合并为字符串
pub inline fn join(allocator: Allocator, separator: []const u8, parts: []const []const u8) ![]const u8 {
    return try std.mem.join(allocator, separator, parts);
}

/// 字符串替换
pub inline fn str_replace(allocator: Allocator, search: []const u8, replace: []const u8, subject: []const u8) []const u8 {
    return std.mem.replaceOwned(u8, allocator, subject, search, replace) catch unreachable;
}

/// 单词首字母大写（原地修改版本）
/// 安全说明：需要传入可变切片 []u8，直接在原内存上修改
/// 为什么安全：不创建新内存，调用者控制生命周期
pub fn ucwords(str: []u8) []u8 {
    for (str, 0..) |char, index| {
        if (char >= 97 and char <= 122) {
            if (index == 0 or str[index - 1] == ' ') {
                str[index] = std.ascii.toUpper(char);
            }
        }
    }
    return str;
}

/// 首字母大写（原地修改版本）
/// 安全说明：需要传入可变切片 []u8
pub fn ucfirst(str: []u8) []u8 {
    if (str.len > 0 and str[0] >= 97 and str[0] <= 122) {
        str[0] = std.ascii.toUpper(str[0]);
    }
    return str;
}

/// 首字母小写
pub fn lcfrist(str: []u8) []const u8 {
    if (str.len > 0) {
        str[0] = std.ascii.toLower(str[0]);
    }
    return str;
}

/// 重复字符串（堆分配版本）
/// 安全说明：返回新分配的内存，调用者需要 free
/// 为什么需要 allocator：重复后长度变化，必须新分配
pub fn repeat(allocator: Allocator, str: []const u8, count: usize) ![]u8 {
    const total_len = str.len * count;
    const result = try allocator.alloc(u8, total_len);
    var i: usize = 0;
    while (i < count) : (i += 1) {
        @memcpy(result[i * str.len .. (i + 1) * str.len], str);
    }
    return result;
}

/// 加密字符串md5
pub fn md5(allocator: Allocator, str: []const u8) ![]const u8 {
    const Md5 = std.crypto.hash.Md5;
    var out: [Md5.digest_length]u8 = undefined;
    Md5.hash(str, &out, .{});
    // Zig 0.15: 使用 {x} 格式说明符
    const md5hex = try std.fmt.allocPrint(
        allocator,
        "{x}",
        .{out},
    );
    return md5hex;
}

/// 去除字符串首尾指定字符串
pub inline fn trim(str: []const u8, chars: []const u8) []const u8 {
    return std.mem.trim(u8, str, chars); // inline 函数的不会被返回优化
}

/// 打乱字符串
pub fn shuffle(allocator: Allocator, str: []const u8) ![]const u8 {
    const view = try std.unicode.Utf8View.init(str);
    var iter = view.iterator();

    var arr = std.ArrayList([]u8).init(allocator);
    defer arr.deinit();

    var len: usize = 0;
    while (iter.nextCodepointSlice()) |chars| {
        try arr.append(@constCast(chars));
        len += 1;
    }

    var rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    for (0..len) |value| {
        const seed = rng.random().uintLessThan(usize, len);
        if (value != seed) {
            const tmp = arr.items[value];
            arr.items[value] = arr.items[seed];
            arr.items[seed] = tmp;
        }
    }

    var result = try std.ArrayList(u8).initCapacity(allocator, str.len);
    defer result.deinit();

    for (arr.items) |value| {
        try result.appendSlice(value[0..]);
    }
    arr.clearAndFree();

    return result.toOwnedSlice();
}

/// 去除左边字符
pub inline fn ltrim(str: []const u8, chars: []const u8) []const u8 {
    return std.mem.trimLeft(u8, str, chars);
}

/// 去除右边字符
pub inline fn rtrim(str: []const u8, chars: []const u8) []const u8 {
    return std.mem.trimRight(u8, str, chars);
}

// ============================================================================
// 字符串大小写转换 - 三种安全策略
// ============================================================================

/// 【策略1】原地修改 - 最高效，零分配
/// 使用场景：调用者已有可变缓冲区
/// 安全原因：不创建新内存，直接修改传入的缓冲区
pub fn toLowerInPlace(str: []u8) []u8 {
    for (str) |*c| {
        c.* = std.ascii.toLower(c.*);
    }
    return str;
}

pub fn toUpperInPlace(str: []u8) []u8 {
    for (str) |*c| {
        c.* = std.ascii.toUpper(c.*);
    }
    return str;
}

/// 【策略2】调用者提供缓冲区 - 高效，调用者控制内存
/// 使用场景：调用者有栈上缓冲区可复用
/// 安全原因：输出到调用者的内存，生命周期由调用者管理
pub fn toLowerBuf(dest: []u8, src: []const u8) []u8 {
    const len = @min(dest.len, src.len);
    return std.ascii.lowerString(dest[0..len], src[0..len]);
}

pub fn toUpperBuf(dest: []u8, src: []const u8) []u8 {
    const len = @min(dest.len, src.len);
    return std.ascii.upperString(dest[0..len], src[0..len]);
}

/// 【策略3】堆分配 - 最灵活，调用者需释放
/// 使用场景：需要持久保存结果
/// 安全原因：明确的所有权转移，调用者负责 free
pub fn toLowerAlloc(allocator: Allocator, str: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, str.len);
    _ = std.ascii.lowerString(result, str);
    return result;
}

pub fn toUpperAlloc(allocator: Allocator, str: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, str.len);
    _ = std.ascii.upperString(result, str);
    return result;
}

/// 【策略4】静态缓冲区 - 临时使用，注意覆盖风险
/// 使用场景：仅用于立即消费（如日志打印）
/// 警告：下次调用会覆盖！不要保存返回值
pub fn toLowerTemp(str: []const u8) []const u8 {
    const S = struct {
        threadlocal var buf: [40960]u8 = undefined;
    };
    const len = @min(S.buf.len, str.len);
    return std.ascii.lowerString(S.buf[0..len], str[0..len]);
}

pub fn toUpperTemp(str: []const u8) []const u8 {
    const S = struct {
        threadlocal var buf: [40960]u8 = undefined;
    };
    const len = @min(S.buf.len, str.len);
    return std.ascii.upperString(S.buf[0..len], str[0..len]);
}

/// 判断是否包含某个子串
pub inline fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack[0..], needle[0..]) != null;
}

/// 判断是否以某个字符串开始
pub inline fn starts_with(haystack: []const u8, needle: []const u8) bool {
    return std.mem.startsWith(u8, haystack, needle);
}

/// 判断是否以某个字符串结束
pub fn ends_with(haystack: []const u8, needle: []const u8) bool {
    return std.mem.endsWith(u8, haystack, needle);
}

/// 判断是否包含某个字符串
pub fn includes(haystacks: [][]const u8, needle: []const u8) bool {
    for (haystacks) |haystack| {
        if (std.mem.eql(u8, haystack, needle)) {
            return true;
        }
    }
    return false;
}

/// strpos 判断字符串位置
/// 安全说明：返回可选类型，避免 -1 溢出 usize 的问题
pub inline fn strpos(haystack: []const u8, needle: []const u8) ?usize {
    return std.mem.indexOf(u8, haystack, needle);
}

/// strrev 翻转字符串（原地修改版本）
/// 安全说明：需要可变切片，原地翻转
pub inline fn strrev(str: []u8) void {
    std.mem.reverse(u8, str);
}

/// strrev 翻转字符串（堆分配版本）
/// 安全说明：返回新分配的内存，调用者需要 free
pub fn strrevAlloc(allocator: Allocator, str: []const u8) ![]u8 {
    const result = try allocator.dupe(u8, str);
    std.mem.reverse(u8, result);
    return result;
}

/// strlen 字节长度
pub inline fn strlen(str: []const u8) usize {
    return str.len;
}

/// mb_strlen 多字节字符串长度
pub inline fn mb_strlen(str: []const u8) !usize {
    return try std.unicode.utf8CountCodepoints(str);
}

/// substr_count 判断子串个数
pub inline fn substr_count(str: []const u8, needle: []const u8) usize {
    return std.mem.count(u8, str, needle);
}

/// sprinf 返回格式化字符串（使用静态缓冲区，注意：仅适用于临时使用）
/// 警告：返回的切片指向静态缓冲区，下次调用会覆盖
/// 如需持久保存，请使用 sprinf_alloc
pub inline fn sprinf(format: []const u8, args: anytype) ![]const u8 {
    // 使用 threadlocal 避免多线程问题，静态缓冲区避免悬挂指针
    const S = struct {
        threadlocal var buf: [409600]u8 = undefined;
    };
    return try std.fmt.bufPrint(&S.buf, format, args);
}

/// sprinf_alloc 返回格式化字符串（堆分配，调用者需释放）
pub fn sprinf_alloc(allocator: Allocator, format: []const u8, args: anytype) ![]const u8 {
    return try std.fmt.allocPrint(allocator, format, args);
}

/// 剪切子字符串
pub fn substr(allocator: Allocator, str: []const u8, start: usize, end: usize) ![]const u8 {
    const view = try std.unicode.Utf8View.init(str);
    var iter = view.iterator();

    var arr = std.ArrayList([]u8).init(allocator);
    defer arr.deinit();

    var len: usize = 0;
    var char_len: usize = 0;
    while (iter.nextCodepointSlice()) |chars| {
        if (len >= start and len < end) {
            char_len += chars.len;
            try arr.append(@constCast(chars));
        }
        len += 1;
    }
    var result = try std.ArrayList(u8).initCapacity(allocator, char_len);
    defer result.deinit();

    for (arr.items) |value| {
        try result.appendSlice(value[0..]);
    }
    arr.clearAndFree();

    return result.toOwnedSlice();
}
