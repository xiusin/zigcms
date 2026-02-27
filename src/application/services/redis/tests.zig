//! Redis 客户端集成测试
//!
//! 运行测试前需要确保 Redis 服务器正在运行：
//! ```bash
//! redis-server
//! ```
//!
//! 运行测试：
//! ```bash
//! zig test src/services/redis/tests.zig
//! ```
//!
//! ## 测试说明
//!
//! 这些测试会连接到本地 Redis 服务器
//! 测试会创建和删除测试 key，以 "zig_test:" 为前缀
//! 测试完成后会清理测试数据

const std = @import("std");
const redis = @import("redis.zig");

const testing = std.testing;

/// 测试用的 key 前缀
const TEST_PREFIX = "zig_test:";

/// 获取测试用的 key
fn testKey(comptime suffix: []const u8) []const u8 {
    return TEST_PREFIX ++ suffix;
}

// ========================================
// 连接测试
// ========================================

test "connect to redis" {
    const allocator = testing.allocator;

    var conn = redis.connect(.{}, allocator) catch |err| {
        // 如果连接失败，可能是 Redis 没有运行
        // 跳过测试而不是失败
        std.debug.print("Skipping test: Redis not available ({any})\n", .{err});
        return;
    };
    defer conn.close();

    // 测试 PING
    const pong = try conn.ping();
    try testing.expect(pong);
}

// ========================================
// 类型化结果测试（StringResult, IntResult 等）
// ========================================

test "typed result: StringResult" {
    const allocator = testing.allocator;

    var conn = redis.connect(.{}, allocator) catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer conn.close();

    const key = testKey("typed_string");

    // 清理
    var del_result = try conn.del(key);
    defer del_result.deinit();

    // SET 返回 StatusResult
    var set_result = try conn.set(key, "hello world");
    defer set_result.deinit();
    try testing.expect(set_result.isOk());

    // GET 返回 StringResult
    var get_result = try conn.get(key);
    defer get_result.deinit();

    // val() 返回 ?[]const u8
    try testing.expectEqualStrings("hello world", get_result.val().?);

    // valOr() 提供默认值
    try testing.expectEqualStrings("hello world", get_result.valOr("default"));

    // isNil() 检查是否为空
    try testing.expect(!get_result.isNil());

    // 测试不存在的 key
    var nil_result = try conn.get(testKey("nonexistent_key"));
    defer nil_result.deinit();
    try testing.expect(nil_result.isNil());
    try testing.expect(nil_result.val() == null);
    try testing.expectEqualStrings("default", nil_result.valOr("default"));

    // 清理
    var cleanup = try conn.del(key);
    defer cleanup.deinit();
}

test "typed result: IntResult" {
    const allocator = testing.allocator;

    var conn = redis.connect(.{}, allocator) catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer conn.close();

    const key = testKey("typed_int");

    // 清理
    var del_result = try conn.del(key);
    defer del_result.deinit();

    // INCR 返回 IntResult
    var incr_result = try conn.incr(key);
    defer incr_result.deinit();
    try testing.expectEqual(@as(i64, 1), incr_result.val());

    // INCRBY 返回 IntResult
    var incrby_result = try conn.incrBy(key, 10);
    defer incrby_result.deinit();
    try testing.expectEqual(@as(i64, 11), incrby_result.val());

    // DECR 返回 IntResult
    var decr_result = try conn.decr(key);
    defer decr_result.deinit();
    try testing.expectEqual(@as(i64, 10), decr_result.val());

    // 清理
    var cleanup = try conn.del(key);
    defer cleanup.deinit();
}

test "typed result: BoolResult" {
    const allocator = testing.allocator;

    var conn = redis.connect(.{}, allocator) catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer conn.close();

    const key = testKey("typed_bool");

    // 清理并设置
    var del_result = try conn.del(key);
    defer del_result.deinit();

    var set_result = try conn.set(key, "test");
    defer set_result.deinit();

    // EXISTS 返回 BoolResult
    var exists_result = try conn.exists(key);
    defer exists_result.deinit();
    try testing.expect(exists_result.val());

    // EXPIRE 返回 BoolResult
    var expire_result = try conn.expire(key, 60);
    defer expire_result.deinit();
    try testing.expect(expire_result.val());

    // 不存在的 key
    var not_exists = try conn.exists(testKey("nonexistent_bool"));
    defer not_exists.deinit();
    try testing.expect(!not_exists.val());

    // 清理
    var cleanup = try conn.del(key);
    defer cleanup.deinit();
}

test "string commands module" {
    const allocator = testing.allocator;

    var conn = redis.connect(.{}, allocator) catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer conn.close();

    const key = testKey("strings_mod");
    _ = try conn.del(key);

    // 使用 strings 模块
    const strings = redis.strings(conn);

    // SETEX
    const ok = try strings.setEx(key, 60, "expires in 60s");
    try testing.expect(ok);

    // STRLEN
    const len = try strings.strlen(key);
    try testing.expectEqual(@as(i64, 14), len);

    // APPEND
    const new_len = try strings.append(key, "!");
    try testing.expectEqual(@as(i64, 15), new_len);

    // 清理
    _ = try conn.del(key);
}

// ========================================
// Hash 命令测试
// ========================================

test "hash commands" {
    const allocator = testing.allocator;

    var conn = redis.connect(.{}, allocator) catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer conn.close();

    const key = testKey("hash1");
    _ = try conn.del(key);

    const h = redis.hash(conn);

    // HSET
    const is_new = try h.hset(key, "field1", "value1");
    try testing.expect(is_new);

    // HGET
    var reply = try h.hget(key, "field1");
    defer reply.deinit();
    try testing.expectEqualStrings("value1", reply.string().?);

    // HEXISTS
    try testing.expect(try h.hexists(key, "field1"));
    try testing.expect(!try h.hexists(key, "nonexistent"));

    // HINCRBY
    _ = try h.hset(key, "counter", "10");
    const new_val = try h.hincrBy(key, "counter", 5);
    try testing.expectEqual(@as(i64, 15), new_val);

    // HLEN
    const hlen = try h.hlen(key);
    try testing.expectEqual(@as(i64, 2), hlen);

    // 清理
    _ = try conn.del(key);
}

// ========================================
// List 命令测试
// ========================================

test "list commands" {
    const allocator = testing.allocator;

    var conn = redis.connect(.{}, allocator) catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer conn.close();

    const key = testKey("list1");
    _ = try conn.del(key);

    const l = redis.list(conn);

    // RPUSH
    const len1 = try l.rpush(key, &.{ "a", "b", "c" });
    try testing.expectEqual(@as(i64, 3), len1);

    // LPUSH
    const len2 = try l.lpush(key, &.{"z"});
    try testing.expectEqual(@as(i64, 4), len2);

    // LLEN
    const llen = try l.llen(key);
    try testing.expectEqual(@as(i64, 4), llen);

    // LRANGE
    var range_reply = try l.lrange(key, 0, -1);
    defer range_reply.deinit();

    const arr = range_reply.array().?;
    try testing.expectEqual(@as(usize, 4), arr.len);
    try testing.expectEqualStrings("z", arr[0].asString().?);
    try testing.expectEqualStrings("a", arr[1].asString().?);

    // LPOP
    var pop_reply = try l.lpop(key);
    defer pop_reply.deinit();
    try testing.expectEqualStrings("z", pop_reply.string().?);

    // 清理
    _ = try conn.del(key);
}

// ========================================
// Set 命令测试
// ========================================

test "set commands" {
    const allocator = testing.allocator;

    var conn = redis.connect(.{}, allocator) catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer conn.close();

    const key = testKey("set1");
    const key2 = testKey("set2");
    _ = try conn.del(key);
    _ = try conn.del(key2);

    const s = redis.set(conn);

    // SADD
    const added = try s.sadd(key, &.{ "a", "b", "c" });
    try testing.expectEqual(@as(i64, 3), added);

    // SADD 重复元素
    const added2 = try s.sadd(key, &.{ "a", "d" });
    try testing.expectEqual(@as(i64, 1), added2); // 只有 d 是新的

    // SCARD
    const card = try s.scard(key);
    try testing.expectEqual(@as(i64, 4), card);

    // SISMEMBER
    try testing.expect(try s.sismember(key, "a"));
    try testing.expect(!try s.sismember(key, "x"));

    // SREM
    const removed = try s.srem(key, &.{ "a", "b" });
    try testing.expectEqual(@as(i64, 2), removed);

    // 集合运算
    _ = try s.sadd(key2, &.{ "c", "d", "e" });

    var inter_reply = try s.sinter(&.{ key, key2 });
    defer inter_reply.deinit();

    // 清理
    _ = try conn.del(key);
    _ = try conn.del(key2);
}

// ========================================
// Sorted Set 命令测试
// ========================================

test "zset commands" {
    const allocator = testing.allocator;

    var conn = redis.connect(.{}, allocator) catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer conn.close();

    const key = testKey("zset1");
    _ = try conn.del(key);

    const z = redis.zset(conn);

    // ZADD
    const added = try z.zaddOne(key, 100, "player1");
    try testing.expectEqual(@as(i64, 1), added);

    _ = try z.zaddOne(key, 200, "player2");
    _ = try z.zaddOne(key, 150, "player3");

    // ZCARD
    const card = try z.zcard(key);
    try testing.expectEqual(@as(i64, 3), card);

    // ZSCORE
    const score = try z.zscore(key, "player1");
    try testing.expectEqual(@as(f64, 100), score.?);

    // ZRANK
    const rank = try z.zrank(key, "player1");
    try testing.expectEqual(@as(i64, 0), rank.?); // 最低分排第一

    // ZINCRBY
    const new_score = try z.zincrBy(key, 50, "player1");
    try testing.expectEqual(@as(f64, 150), new_score);

    // ZRANGE
    var range_reply = try z.zrange(key, 0, -1, .{ .with_scores = true });
    defer range_reply.deinit();

    // 清理
    _ = try conn.del(key);
}

// ========================================
// 连接池测试
// ========================================

test "connection pool" {
    const allocator = testing.allocator;

    var pool_inst = redis.createPool(.{
        .max_connections = 3,
    }, allocator) catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer pool_inst.deinit();

    // 获取连接
    var conn1 = pool_inst.acquire() catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer conn1.release();

    // 执行命令
    const pong = try conn1.ping();
    try testing.expect(pong);

    // 获取第二个连接
    var conn2 = pool_inst.acquire() catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer conn2.release();

    // 检查统计
    const stats = pool_inst.stats();
    try testing.expectEqual(@as(u32, 2), stats.total_connections);
}

// ========================================
// 命令构建器测试
// ========================================

test "command builder" {
    const allocator = testing.allocator;

    var builder = redis.command.CommandBuilder.init(allocator);
    defer builder.deinit();

    _ = try builder.add("SET");
    _ = try builder.add("mykey");
    _ = try builder.add("myvalue");
    _ = try builder.add(@as(i64, 123));

    const args_list = builder.getArgs();
    try testing.expectEqual(@as(usize, 4), args_list.len);
    try testing.expectEqualStrings("SET", args_list[0]);
    try testing.expectEqualStrings("mykey", args_list[1]);
    try testing.expectEqualStrings("myvalue", args_list[2]);
    try testing.expectEqualStrings("123", args_list[3]);
}

// ========================================
// Args 动态参数构建测试
// ========================================

test "args builder: basic usage" {
    const allocator = testing.allocator;

    var a = redis.Args.init(allocator);
    defer a.deinit();

    // 添加基础参数
    _ = try a.add("SET");
    _ = try a.add("mykey");
    _ = try a.add("myvalue");

    try testing.expectEqual(@as(usize, 3), a.len());
    try testing.expectEqualStrings("SET", a.getArgs()[0]);
    try testing.expectEqualStrings("mykey", a.getArgs()[1]);
    try testing.expectEqualStrings("myvalue", a.getArgs()[2]);
}

test "args builder: conditional add (like Go []any)" {
    const allocator = testing.allocator;

    // 模拟 SET 命令选项
    const SetOptions = struct {
        ex: ?i64 = null,
        px: ?i64 = null,
        nx: bool = false,
        xx: bool = false,
        keepttl: bool = false,
        get: bool = false,
    };

    const opts = SetOptions{
        .ex = 3600,
        .nx = true,
        .get = true,
    };

    var a = redis.Args.init(allocator);
    defer a.deinit();

    // 构建命令（类似 Go 的动态 append）
    _ = try a.add("SET");
    _ = try a.add("mykey");
    _ = try a.add("myvalue");

    // 条件添加 EX
    if (opts.ex) |ex| {
        _ = try a.add("EX");
        _ = try a.add(ex);
    }

    // 条件添加 PX
    if (opts.px) |px| {
        _ = try a.add("PX");
        _ = try a.add(px);
    }

    // 使用 flag 方法添加布尔标志
    _ = try a.flag(opts.nx, "NX");
    _ = try a.flag(opts.xx, "XX");
    _ = try a.flag(opts.keepttl, "KEEPTTL");
    _ = try a.flag(opts.get, "GET");

    // 验证结果: SET mykey myvalue EX 3600 NX GET (7 个参数)
    // ex=3600, nx=true, get=true -> EX, 3600, NX, GET (4 个额外参数)
    // 3 + 4 = 7
    try testing.expectEqual(@as(usize, 7), a.len());
    try testing.expectEqualStrings("SET", a.getArgs()[0]);
    try testing.expectEqualStrings("EX", a.getArgs()[3]);
    try testing.expectEqualStrings("3600", a.getArgs()[4]);
    try testing.expectEqualStrings("NX", a.getArgs()[5]);
    try testing.expectEqualStrings("GET", a.getArgs()[6]);
}

test "args builder: addIf method" {
    const allocator = testing.allocator;

    var a = redis.Args.init(allocator);
    defer a.deinit();

    const ttl: i64 = 3600;
    const nx = true;
    const xx = false;

    _ = try a.add("SET");
    _ = try a.add("key");
    _ = try a.add("value");

    // addIf: 条件为 true 时添加
    _ = try a.addIf(ttl > 0, "EX");
    _ = try a.addIf(ttl > 0, ttl);

    // flag: 条件为 true 时添加字符串
    _ = try a.flag(nx, "NX");
    _ = try a.flag(xx, "XX"); // xx 为 false，不会添加

    try testing.expectEqual(@as(usize, 6), a.len());
}

test "args builder: optional parameters" {
    const allocator = testing.allocator;

    var a = redis.Args.init(allocator);
    defer a.deinit();

    const pattern: ?[]const u8 = "user:*";
    const count: ?u64 = 100;
    const type_filter: ?[]const u8 = null;

    // 模拟 SCAN cursor [MATCH pattern] [COUNT count] [TYPE type]
    _ = try a.add("SCAN");
    _ = try a.add("0");

    // optional: 有值时添加前缀和值，null 时不添加
    _ = try a.optional("MATCH", pattern);
    _ = try a.optional("COUNT", count);
    _ = try a.optional("TYPE", type_filter); // null，不会添加

    // 结果: SCAN 0 MATCH user:* COUNT 100
    try testing.expectEqual(@as(usize, 6), a.len());
    try testing.expectEqualStrings("MATCH", a.getArgs()[2]);
    try testing.expectEqualStrings("user:*", a.getArgs()[3]);
    try testing.expectEqualStrings("COUNT", a.getArgs()[4]);
    try testing.expectEqualStrings("100", a.getArgs()[5]);
}

test "args builder: many parameters" {
    const allocator = testing.allocator;

    var a = redis.Args.init(allocator);
    defer a.deinit();

    // many: 一次添加多个参数（元组）
    _ = try a.many(.{ "ZADD", "leaderboard" });
    _ = try a.many(.{ @as(i64, 1000), "player1" });
    _ = try a.many(.{ @as(i64, 2000), "player2" });

    // 结果: ZADD leaderboard 1000 player1 2000 player2
    try testing.expectEqual(@as(usize, 6), a.len());
    try testing.expectEqualStrings("ZADD", a.getArgs()[0]);
    try testing.expectEqualStrings("1000", a.getArgs()[2]);
}

test "args builder: when/endWhen chain" {
    const allocator = testing.allocator;

    var a = redis.Args.init(allocator);
    defer a.deinit();

    const has_limit = true;
    const has_offset = false;

    _ = try a.add("ZRANGE");
    _ = try a.add("myset");
    _ = try a.add("0");
    _ = try a.add("-1");

    // when: 条件控制后续添加
    _ = a.when(has_limit);
    _ = try a.add("LIMIT");
    _ = try a.add(@as(i64, 0));
    _ = try a.add(@as(i64, 10));
    _ = a.endWhen();

    // has_offset 为 false，不会添加
    _ = a.when(has_offset);
    _ = try a.add("OFFSET");
    _ = try a.add(@as(i64, 5));
    _ = a.endWhen();

    // 结果: ZRANGE myset 0 -1 LIMIT 0 10
    try testing.expectEqual(@as(usize, 7), a.len());
}

test "args builder: manyIf conditional batch" {
    const allocator = testing.allocator;

    var a = redis.Args.init(allocator);
    defer a.deinit();

    const with_scores = true;
    const reversed = false;

    _ = try a.add("ZRANGE");
    _ = try a.add("myset");
    _ = try a.add("0");
    _ = try a.add("-1");

    // manyIf: 条件批量添加
    _ = try a.manyIf(with_scores, .{"WITHSCORES"});
    _ = try a.manyIf(reversed, .{"REV"});

    // 结果: ZRANGE myset 0 -1 WITHSCORES
    try testing.expectEqual(@as(usize, 5), a.len());
}

test "args builder: reset and reuse" {
    const allocator = testing.allocator;

    var a = redis.Args.init(allocator);
    defer a.deinit();

    // 第一次使用
    _ = try a.add("GET");
    _ = try a.add("key1");
    try testing.expectEqual(@as(usize, 2), a.len());

    // 重置
    a.reset();
    try testing.expectEqual(@as(usize, 0), a.len());

    // 第二次使用
    _ = try a.add("SET");
    _ = try a.add("key2");
    _ = try a.add("value2");
    try testing.expectEqual(@as(usize, 3), a.len());
}

// ========================================
// Args 与 Connection 集成测试
// ========================================

test "args builder: doArgs with connection" {
    const allocator = testing.allocator;

    var conn = redis.connect(.{}, allocator) catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer conn.close();

    const key = testKey("args_doargs");

    // 使用 Args 构建 DEL 命令
    var del_args = redis.Args.init(allocator);
    defer del_args.deinit();
    _ = try del_args.add("DEL");
    _ = try del_args.add(key);

    var del_reply = try conn.doArgs(&del_args);
    defer del_reply.deinit();

    // 使用 Args 构建 SET 命令
    var set_args = redis.Args.init(allocator);
    defer set_args.deinit();

    _ = try set_args.add("SET");
    _ = try set_args.add(key);
    _ = try set_args.add("hello from args");
    _ = try set_args.add("EX");
    _ = try set_args.add(@as(i64, 60));

    var set_reply = try conn.doArgs(&set_args);
    defer set_reply.deinit();
    try testing.expect(set_reply.isOk());

    // 使用 Args 构建 GET 命令
    var get_args = redis.Args.init(allocator);
    defer get_args.deinit();
    _ = try get_args.add("GET");
    _ = try get_args.add(key);

    var get_reply = try conn.doArgs(&get_args);
    defer get_reply.deinit();
    try testing.expectEqualStrings("hello from args", get_reply.string().?);

    // 清理
    del_args.reset();
    _ = try del_args.add("DEL");
    _ = try del_args.add(key);
    var cleanup = try conn.doArgs(&del_args);
    defer cleanup.deinit();
}

test "args builder: complex command with options" {
    const allocator = testing.allocator;

    var conn = redis.connect(.{}, allocator) catch {
        std.debug.print("Skipping test: Redis not available\n", .{});
        return;
    };
    defer conn.close();

    const key = testKey("args_complex");

    // 清理
    var del_result = try conn.del(key);
    defer del_result.deinit();

    // 构建复杂的 SET 命令: SET key value EX 60 NX
    const SetOpts = struct {
        ex: ?i64 = null,
        px: ?i64 = null,
        nx: bool = false,
        xx: bool = false,
    };

    const opts = SetOpts{ .ex = 60, .nx = true };

    var a = redis.Args.init(allocator);
    defer a.deinit();

    _ = try a.add("SET");
    _ = try a.add(key);
    _ = try a.add("complex_value");

    // 使用 optional 添加可选参数
    if (opts.ex) |ex| {
        _ = try a.add("EX");
        _ = try a.add(ex);
    }

    // 使用 flag 添加布尔标志
    _ = try a.flag(opts.nx, "NX");
    _ = try a.flag(opts.xx, "XX");

    var reply = try conn.doArgs(&a);
    defer reply.deinit();

    // NX 标志：key 不存在时才设置，应该成功
    try testing.expect(reply.isOk());

    // 再次执行相同命令，应该失败（key 已存在）
    a.reset();
    _ = try a.add("SET");
    _ = try a.add(key);
    _ = try a.add("new_value");
    _ = try a.add("NX");

    var reply2 = try conn.doArgs(&a);
    defer reply2.deinit();

    // NX 失败返回 nil
    try testing.expect(reply2.isNil());

    // 清理
    var cleanup = try conn.del(key);
    defer cleanup.deinit();
}

// ========================================
// 运行所有测试
// ========================================

test {
    // 引用所有子模块测试
    _ = @import("types.zig");
    _ = @import("protocol.zig");
    _ = @import("command.zig");
    _ = @import("reply.zig");
    _ = @import("result.zig");
    _ = @import("args.zig");
}
