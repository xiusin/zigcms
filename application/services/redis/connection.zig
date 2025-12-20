//! Redis 连接管理模块
//!
//! 本模块实现了与 Redis 服务器的 TCP 连接管理。
//! 包括连接建立、认证、命令发送和响应接收。
//!
//! ## 核心设计
//!
//! 1. **线程安全**: 使用 Mutex 保护并发访问
//! 2. **资源管理**: 明确的生命周期，避免泄漏
//! 3. **错误处理**: 详细的错误类型，便于诊断
//!
//! ## Zig vs Go: 并发模型对比
//!
//! Go 使用 goroutine 和 channel：
//! ```go
//! func (c *Conn) Send(cmd string) error {
//!     c.mu.Lock()
//!     defer c.mu.Unlock()
//!     // ...
//! }
//! ```
//!
//! Zig 使用更底层的线程原语：
//! - std.Thread.Mutex 对应 sync.Mutex
//! - 没有 GC，需要手动管理内存
//! - 更精细的控制，但也需要更多注意

const std = @import("std");
const net = std.net;
const types = @import("types.zig");
const protocol = @import("protocol.zig");
const command = @import("command.zig");
const reply_mod = @import("reply.zig");
const result_mod = @import("result.zig");
const args_mod = @import("args.zig");

const ConnectOptions = types.ConnectOptions;
const RedisError = types.RedisError;
const Reply = reply_mod.Reply;
const CommandBuilder = command.CommandBuilder;

/// 动态参数构建器
pub const Args = args_mod.Args;

// 导出类型化的结果类型（类似 go-redis 的 StringCmd, IntCmd 等）
pub const StringResult = result_mod.StringResult;
pub const IntResult = result_mod.IntResult;
pub const BoolResult = result_mod.BoolResult;
pub const FloatResult = result_mod.FloatResult;
pub const StatusResult = result_mod.StatusResult;
pub const SliceResult = result_mod.SliceResult;
pub const MapResult = result_mod.MapResult;
pub const ScanResult = result_mod.ScanResult;

/// Redis 连接
///
/// ## 结构体设计
///
/// 在 Go 中，你可能这样设计：
/// ```go
/// type Conn struct {
///     conn     net.Conn
///     reader   *bufio.Reader
///     mu       sync.Mutex
///     options  ConnOpts
/// }
/// ```
///
/// Zig 版本的主要区别：
/// 1. 没有 bufio，我们在 Protocol 中实现缓冲
/// 2. 使用泛型 Protocol 支持不同的流类型
/// 3. 显式的分配器参数
pub const Connection = struct {
    const Self = @This();

    /// TCP 连接流
    stream: net.Stream,
    /// RESP 协议处理器
    proto: protocol.Protocol(net.Stream),
    /// 互斥锁，保护并发访问
    ///
    /// ## 为什么需要锁？
    ///
    /// Redis 连接是有状态的（TCP 流），同时只能处理一个请求。
    /// 如果多个线程同时发送命令，会导致：
    /// 1. 请求数据混乱
    /// 2. 响应对应不上请求
    ///
    /// 虽然 Zig 是单线程友好的，但库应该支持多线程使用场景。
    mutex: std.Thread.Mutex,
    /// 连接是否活跃
    is_active: bool,
    /// 内存分配器
    allocator: std.mem.Allocator,
    /// 连接选项
    options: ConnectOptions,
    /// 命令构建器（复用以减少内存分配）
    cmd_builder: CommandBuilder,

    /// 创建新连接
    ///
    /// ## 连接流程
    ///
    /// 1. 建立 TCP 连接
    /// 2. 如果设置了密码，发送 AUTH 命令
    /// 3. 如果设置了客户端名称，发送 CLIENT SETNAME
    /// 4. 选择数据库
    ///
    /// ## 错误处理
    ///
    /// Go 中你可能习惯：
    /// ```go
    /// conn, err := Connect(opts)
    /// if err != nil {
    ///     return nil, err
    /// }
    /// ```
    ///
    /// Zig 使用 `try` 简化错误传播：
    /// ```zig
    /// const conn = try Connection.connect(opts, allocator);
    /// // 如果出错，错误自动向上传播
    /// ```
    pub fn connect(options: ConnectOptions, allocator: std.mem.Allocator) !*Self {
        // 解析地址
        const address = net.Address.resolveIp(options.host, options.port) catch {
            return RedisError.ConnectionTimeout;
        };

        // 建立 TCP 连接
        var stream = net.tcpConnectToAddress(address) catch {
            return RedisError.ConnectionTimeout;
        };
        errdefer stream.close();

        // 注意：Zig 0.15.x 中 std.net.Stream 不再支持 setReadTimeout/setWriteTimeout
        // 超时功能可以通过其他方式实现（如使用 async/await 或 epoll）
        // 当前版本暂不实现超时，options.read_timeout_ns 和 write_timeout_ns 保留备用
        _ = options.read_timeout_ns;
        _ = options.write_timeout_ns;

        // 分配连接结构体
        //
        // ## 为什么用指针？
        //
        // 返回指针而非值的原因：
        // 1. Connection 包含 Mutex，不应该被复制
        // 2. 便于在连接池中管理
        // 3. 允许在其他地方持有引用
        var self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = Self{
            .stream = stream,
            .proto = protocol.Protocol(net.Stream).init(stream, allocator),
            .mutex = .{},
            .is_active = true,
            .allocator = allocator,
            .options = options,
            .cmd_builder = CommandBuilder.init(allocator),
        };

        // 认证（如果需要）
        if (options.password) |password| {
            if (options.username) |username| {
                // Redis 6.0+ ACL 认证
                _ = try self.sendCommand(&.{ "AUTH", username, password });
            } else {
                // 传统密码认证
                var auth_reply = try self.sendCommand(&.{ "AUTH", password });
                defer auth_reply.deinit();

                if (!auth_reply.isOk()) {
                    return RedisError.AuthenticationFailed;
                }
            }
        }

        // 设置客户端名称（如果需要）
        if (options.client_name) |name| {
            var name_reply = try self.sendCommand(&.{ "CLIENT", "SETNAME", name });
            defer name_reply.deinit();
        }

        // 选择数据库
        if (options.database > 0) {
            var db_reply = try self.sendCommandWithInt("SELECT", @intCast(options.database));
            defer db_reply.deinit();

            if (!db_reply.isOk()) {
                return RedisError.SelectDatabaseFailed;
            }
        }

        return self;
    }

    /// 关闭连接
    ///
    /// ## 资源清理顺序
    ///
    /// 1. 发送 QUIT 命令（优雅关闭）
    /// 2. 关闭 TCP 连接
    /// 3. 释放内存
    ///
    /// 即使 QUIT 失败，也要确保后续清理执行
    pub fn close(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.is_active) {
            return;
        }

        // 尝试发送 QUIT（忽略错误）
        _ = self.sendCommandUnlocked(&.{"QUIT"}) catch {};

        self.is_active = false;
        self.stream.close();
        self.cmd_builder.deinit();
        self.allocator.destroy(self);
    }

    /// 发送命令并获取响应
    ///
    /// ## 线程安全版本
    ///
    /// 这个方法会获取锁，适合多线程环境
    pub fn sendCommand(self: *Self, args: []const []const u8) !Reply {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.sendCommandUnlocked(args);
    }

    /// 发送命令（内部使用，不加锁）
    pub fn sendCommandUnlocked(self: *Self, args: []const []const u8) !Reply {
        const value = try self.sendCommandRawUnlocked(args);
        return Reply.init(value, self.allocator);
    }

    /// 发送命令并返回原始 RedisValue（带锁）
    ///
    /// 这个方法用于新的类型化结果系统
    fn sendCommandRaw(self: *Self, args: []const []const u8) !types.RedisValue {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.sendCommandRawUnlocked(args);
    }

    /// 发送命令并返回原始 RedisValue（不加锁）
    fn sendCommandRawUnlocked(self: *Self, args: []const []const u8) !types.RedisValue {
        if (!self.is_active) {
            return RedisError.ConnectionNotActive;
        }

        // 发送命令
        try self.proto.sendCommand(args);

        // 读取响应
        return try self.proto.readReply();
    }

    /// 发送带整数参数的命令
    pub fn sendCommandWithInt(self: *Self, cmd: []const u8, value: i64) !Reply {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.cmd_builder.reset();
        _ = try self.cmd_builder.addStr(cmd);
        _ = try self.cmd_builder.addInt(value);

        return self.sendCommandUnlocked(self.cmd_builder.getArgs());
    }

    /// 执行命令并返回响应（泛型版本）
    ///
    /// ## 可变参数泛型
    ///
    /// 这个方法允许这样调用：
    /// ```zig
    /// const reply = try conn.exec("SET", .{ "key", "value" });
    /// const reply2 = try conn.exec("EXPIRE", .{ "key", 3600 });
    /// ```
    ///
    /// 编译时展开参数，类型安全且无运行时开销
    pub fn exec(self: *Self, cmd: []const u8, args: anytype) !Reply {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.cmd_builder.reset();
        _ = try self.cmd_builder.addStr(cmd);

        // 使用 inline for 在编译时展开参数
        const ArgsType = @TypeOf(args);
        const args_info = @typeInfo(ArgsType);

        if (args_info == .@"struct") {
            inline for (args_info.@"struct".fields) |field| {
                _ = try self.cmd_builder.add(@field(args, field.name));
            }
        }

        return self.sendCommandUnlocked(self.cmd_builder.getArgs());
    }

    /// 执行动态构造的命令
    ///
    /// ## 动态参数构造（类似 Go 的 []any）
    ///
    /// Go 中动态构造参数：
    /// ```go
    /// args := []interface{}{"SET", key, value}
    /// if opts.EX > 0 {
    ///     args = append(args, "EX", opts.EX)
    /// }
    /// if opts.NX {
    ///     args = append(args, "NX")
    /// }
    /// client.Do(ctx, args...)
    /// ```
    ///
    /// Zig 版本：
    /// ```zig
    /// var args = Args.init(allocator);
    /// defer args.deinit();
    ///
    /// _ = try args.add("SET");
    /// _ = try args.add(key);
    /// _ = try args.add(value);
    /// _ = try args.addIf(opts.ex > 0, "EX");
    /// _ = try args.addIf(opts.ex > 0, opts.ex);
    /// _ = try args.flag(opts.nx, "NX");
    ///
    /// var reply = try conn.doArgs(&args);
    /// defer reply.deinit();
    /// ```
    pub fn doArgs(self: *Self, args: *const Args) !Reply {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.is_active) {
            return RedisError.ConnectionNotActive;
        }

        try self.proto.sendCommand(args.getArgs());
        const value = try self.proto.readReply();
        return Reply.init(value, self.allocator);
    }

    /// 执行动态构造的命令，返回原始 RedisValue
    pub fn doArgsRaw(self: *Self, args: *const Args) !types.RedisValue {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.is_active) {
            return RedisError.ConnectionNotActive;
        }

        try self.proto.sendCommand(args.getArgs());
        return try self.proto.readReply();
    }

    /// 检查连接是否活跃
    pub fn isActive(self: *Self) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.is_active;
    }

    /// 发送 PING 命令检查连接
    pub fn ping(self: *Self) !bool {
        var reply = try self.sendCommand(&.{"PING"});
        defer reply.deinit();

        if (reply.string()) |s| {
            return std.mem.eql(u8, s, "PONG");
        }
        return false;
    }

    // ========================================
    // 便捷 Redis 命令方法
    //
    // 设计参考 go-redis：
    // - 每个命令返回类型化的结果（StringResult, IntResult 等）
    // - 调用者需要调用 result.deinit() 释放内存
    // - 可以使用 result.val() 获取值，result.result() 获取值或错误
    // ========================================

    /// GET - 获取 key 的值
    ///
    /// 返回 StringResult，类似 go-redis 的 StringCmd
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// // 方式 1: 使用 val()，类似 go-redis 的 Val()
    /// var result = try conn.get("user:name");
    /// defer result.deinit();
    /// const name = result.val() orelse "Guest";
    ///
    /// // 方式 2: 使用 valOr() 提供默认值
    /// const name = result.valOr("Guest");
    ///
    /// // 方式 3: 使用 result() 获取错误
    /// if (result.result()) |name| {
    ///     std.debug.print("Name: {s}\n", .{name});
    /// } else |err| {
    ///     if (err == RedisError.KeyNotFound) {
    ///         std.debug.print("Key not found\n", .{});
    ///     }
    /// }
    ///
    /// // 方式 4: 检查 nil（类似 go-redis 的 redis.Nil）
    /// if (result.isNil()) {
    ///     std.debug.print("Key does not exist\n", .{});
    /// }
    /// ```
    ///
    /// ## 对比 go-redis
    ///
    /// ```go
    /// // go-redis
    /// val, err := client.Get(ctx, "user:name").Result()
    /// if err == redis.Nil {
    ///     fmt.Println("Key not found")
    /// }
    /// ```
    pub fn get(self: *Self, key: []const u8) !StringResult {
        const value = try self.sendCommandRaw(&.{ "GET", key });
        return result_mod.newStringResult(value, self.allocator);
    }

    /// SET - 设置 key 的值
    ///
    /// 返回 StatusResult，可以用 isOk() 检查是否成功
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var result = try conn.set("user:name", "Alice");
    /// defer result.deinit();
    ///
    /// if (result.isOk()) {
    ///     std.debug.print("SET succeeded\n", .{});
    /// }
    /// ```
    ///
    /// ## 对比 go-redis
    ///
    /// ```go
    /// err := client.Set(ctx, "user:name", "Alice", 0).Err()
    /// if err != nil {
    ///     log.Fatal(err)
    /// }
    /// ```
    pub fn set(self: *Self, key: []const u8, value: []const u8) !StatusResult {
        const v = try self.sendCommandRaw(&.{ "SET", key, value });
        return result_mod.newStatusResult(v, self.allocator);
    }

    /// SETEX - 设置带过期时间的 key
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// // 设置 1 小时后过期
    /// var result = try conn.setex("session:abc", 3600, "user_data");
    /// defer result.deinit();
    /// ```
    pub fn setex(self: *Self, key: []const u8, seconds: i64, value: []const u8) !StatusResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.cmd_builder.reset();
        _ = try self.cmd_builder.addStr("SETEX");
        _ = try self.cmd_builder.addStr(key);
        _ = try self.cmd_builder.addInt(seconds);
        _ = try self.cmd_builder.addStr(value);

        const v = try self.sendCommandRawUnlocked(self.cmd_builder.getArgs());
        return result_mod.newStatusResult(v, self.allocator);
    }

    /// DEL - 删除 key
    ///
    /// 返回 IntResult，值为删除的 key 数量
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var result = try conn.del("user:temp");
    /// defer result.deinit();
    ///
    /// const count = result.val();
    /// std.debug.print("Deleted {} keys\n", .{count});
    /// ```
    pub fn del(self: *Self, key: []const u8) !IntResult {
        const value = try self.sendCommandRaw(&.{ "DEL", key });
        return result_mod.newIntResult(value, self.allocator);
    }

    /// EXISTS - 检查 key 是否存在
    ///
    /// 返回 BoolResult
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var result = try conn.exists("user:1");
    /// defer result.deinit();
    ///
    /// if (result.val()) {
    ///     std.debug.print("User exists\n", .{});
    /// }
    /// ```
    pub fn exists(self: *Self, key: []const u8) !BoolResult {
        const value = try self.sendCommandRaw(&.{ "EXISTS", key });
        return result_mod.newBoolResult(value, self.allocator);
    }

    /// EXPIRE - 设置过期时间
    ///
    /// 返回 BoolResult，true 表示设置成功
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var result = try conn.expire("session:abc", 3600);
    /// defer result.deinit();
    ///
    /// if (result.val()) {
    ///     std.debug.print("Expire set successfully\n", .{});
    /// }
    /// ```
    pub fn expire(self: *Self, key: []const u8, seconds: i64) !BoolResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.cmd_builder.reset();
        _ = try self.cmd_builder.addStr("EXPIRE");
        _ = try self.cmd_builder.addStr(key);
        _ = try self.cmd_builder.addInt(seconds);

        const value = try self.sendCommandRawUnlocked(self.cmd_builder.getArgs());
        return result_mod.newBoolResult(value, self.allocator);
    }

    /// TTL - 获取剩余生存时间（秒）
    ///
    /// 返回 IntResult
    /// - 正数：剩余秒数
    /// - -1：key 存在但没有过期时间
    /// - -2：key 不存在
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var result = try conn.ttl("session:abc");
    /// defer result.deinit();
    ///
    /// const ttl = result.val();
    /// if (ttl == -2) {
    ///     std.debug.print("Key not found\n", .{});
    /// } else if (ttl == -1) {
    ///     std.debug.print("Key has no expiration\n", .{});
    /// } else {
    ///     std.debug.print("Expires in {} seconds\n", .{ttl});
    /// }
    /// ```
    pub fn ttl(self: *Self, key: []const u8) !IntResult {
        const value = try self.sendCommandRaw(&.{ "TTL", key });
        return result_mod.newIntResult(value, self.allocator);
    }

    /// PTTL - 获取剩余生存时间（毫秒）
    pub fn pttl(self: *Self, key: []const u8) !IntResult {
        const value = try self.sendCommandRaw(&.{ "PTTL", key });
        return result_mod.newIntResult(value, self.allocator);
    }

    /// SELECT - 选择数据库
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var result = try conn.selectDb(1);
    /// defer result.deinit();
    ///
    /// if (result.isOk()) {
    ///     std.debug.print("Switched to DB 1\n", .{});
    /// }
    /// ```
    pub fn selectDb(self: *Self, db: u32) !StatusResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.cmd_builder.reset();
        _ = try self.cmd_builder.addStr("SELECT");
        _ = try self.cmd_builder.addInt(@intCast(db));

        const value = try self.sendCommandRawUnlocked(self.cmd_builder.getArgs());
        return result_mod.newStatusResult(value, self.allocator);
    }

    /// KEYS - 获取所有匹配的 keys
    ///
    /// 返回 SliceResult，包含匹配的 key 列表
    ///
    /// ## 警告
    ///
    /// 在生产环境中慎用！对于大数据集，KEYS 可能阻塞服务器。
    /// 推荐使用 SCAN 命令进行迭代。
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var result = try conn.keys("user:*");
    /// defer result.deinit();
    ///
    /// for (result.val()) |item| {
    ///     if (item.asString()) |key| {
    ///         std.debug.print("Key: {s}\n", .{key});
    ///     }
    /// }
    /// ```
    pub fn keys(self: *Self, pattern: []const u8) !SliceResult {
        const value = try self.sendCommandRaw(&.{ "KEYS", pattern });
        return result_mod.newSliceResult(value, self.allocator);
    }

    /// FLUSHDB - 清空当前数据库
    ///
    /// ## 危险操作！
    ///
    /// 此操作会删除当前数据库的所有数据，无法恢复。
    pub fn flushDb(self: *Self) !StatusResult {
        const value = try self.sendCommandRaw(&.{"FLUSHDB"});
        return result_mod.newStatusResult(value, self.allocator);
    }

    /// FLUSHALL - 清空所有数据库
    ///
    /// ## 危险操作！
    ///
    /// 此操作会删除所有数据库的所有数据，无法恢复。
    pub fn flushAll(self: *Self) !StatusResult {
        const value = try self.sendCommandRaw(&.{"FLUSHALL"});
        return result_mod.newStatusResult(value, self.allocator);
    }

    /// DBSIZE - 获取当前数据库 key 数量
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var result = try conn.dbSize();
    /// defer result.deinit();
    ///
    /// std.debug.print("DB has {} keys\n", .{result.val()});
    /// ```
    pub fn dbSize(self: *Self) !IntResult {
        const value = try self.sendCommandRaw(&.{"DBSIZE"});
        return result_mod.newIntResult(value, self.allocator);
    }

    /// TYPE - 获取 key 的类型
    ///
    /// 返回 StringResult，值为：
    /// - "string"
    /// - "list"
    /// - "set"
    /// - "zset"
    /// - "hash"
    /// - "stream"
    /// - "none"（key 不存在）
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var result = try conn.typeOf("mykey");
    /// defer result.deinit();
    ///
    /// if (result.val()) |t| {
    ///     std.debug.print("Key type: {s}\n", .{t});
    /// }
    /// ```
    pub fn typeOf(self: *Self, key: []const u8) !StringResult {
        const value = try self.sendCommandRaw(&.{ "TYPE", key });
        return result_mod.newStringResult(value, self.allocator);
    }

    /// RENAME - 重命名 key
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var result = try conn.rename("old_key", "new_key");
    /// defer result.deinit();
    ///
    /// if (result.isOk()) {
    ///     std.debug.print("Key renamed\n", .{});
    /// }
    /// ```
    pub fn rename(self: *Self, key: []const u8, new_key: []const u8) !StatusResult {
        const value = try self.sendCommandRaw(&.{ "RENAME", key, new_key });
        return result_mod.newStatusResult(value, self.allocator);
    }

    /// INCR - 将 key 中存储的数字加 1
    ///
    /// 返回 IntResult，值为增加后的数字
    /// 如果 key 不存在，先初始化为 0 再加 1
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var result = try conn.incr("counter");
    /// defer result.deinit();
    ///
    /// std.debug.print("Counter: {d}\n", .{result.val()});
    /// ```
    ///
    /// ## 对比 go-redis
    ///
    /// ```go
    /// n, err := client.Incr(ctx, "counter").Result()
    /// ```
    pub fn incr(self: *Self, key: []const u8) !IntResult {
        const value = try self.sendCommandRaw(&.{ "INCR", key });
        return result_mod.newIntResult(value, self.allocator);
    }

    /// DECR - 将 key 中存储的数字减 1
    pub fn decr(self: *Self, key: []const u8) !IntResult {
        const value = try self.sendCommandRaw(&.{ "DECR", key });
        return result_mod.newIntResult(value, self.allocator);
    }

    /// INCRBY - 将 key 中存储的数字加上指定增量
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var result = try conn.incrBy("counter", 10);
    /// defer result.deinit();
    ///
    /// std.debug.print("Counter: {d}\n", .{result.val()});
    /// ```
    pub fn incrBy(self: *Self, key: []const u8, increment: i64) !IntResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.cmd_builder.reset();
        _ = try self.cmd_builder.addStr("INCRBY");
        _ = try self.cmd_builder.addStr(key);
        _ = try self.cmd_builder.addInt(increment);

        const value = try self.sendCommandRawUnlocked(self.cmd_builder.getArgs());
        return result_mod.newIntResult(value, self.allocator);
    }

    /// DECRBY - 将 key 中存储的数字减去指定值
    pub fn decrBy(self: *Self, key: []const u8, decrement: i64) !IntResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.cmd_builder.reset();
        _ = try self.cmd_builder.addStr("DECRBY");
        _ = try self.cmd_builder.addStr(key);
        _ = try self.cmd_builder.addInt(decrement);

        const value = try self.sendCommandRawUnlocked(self.cmd_builder.getArgs());
        return result_mod.newIntResult(value, self.allocator);
    }

    /// INCRBYFLOAT - 将 key 中存储的浮点数加上指定增量
    pub fn incrByFloat(self: *Self, key: []const u8, increment: f64) !FloatResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.cmd_builder.reset();
        _ = try self.cmd_builder.addStr("INCRBYFLOAT");
        _ = try self.cmd_builder.addStr(key);
        _ = try self.cmd_builder.addFloat(increment);

        const value = try self.sendCommandRawUnlocked(self.cmd_builder.getArgs());
        return result_mod.newFloatResult(value, self.allocator);
    }

    /// SCAN - 增量迭代 key
    ///
    /// 返回 ScanResult，可以获取游标和 keys
    ///
    /// ## 使用示例
    ///
    /// ```zig
    /// var cursor: u64 = 0;
    /// while (true) {
    ///     var result = try conn.scan(cursor, "user:*", 100);
    ///     defer result.deinit();
    ///
    ///     cursor = result.cursor();
    ///     for (result.keys()) |item| {
    ///         if (item.asString()) |key| {
    ///             std.debug.print("Key: {s}\n", .{key});
    ///         }
    ///     }
    ///
    ///     if (result.isFinished()) break;
    /// }
    /// ```
    pub fn scan(self: *Self, cursor: u64, pattern: ?[]const u8, count: ?u64) !ScanResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.cmd_builder.reset();
        _ = try self.cmd_builder.addStr("SCAN");
        _ = try self.cmd_builder.addUint(cursor);

        if (pattern) |p| {
            _ = try self.cmd_builder.addStr("MATCH");
            _ = try self.cmd_builder.addStr(p);
        }
        if (count) |c| {
            _ = try self.cmd_builder.addStr("COUNT");
            _ = try self.cmd_builder.addUint(c);
        }

        const value = try self.sendCommandRawUnlocked(self.cmd_builder.getArgs());
        return result_mod.newScanResult(value, self.allocator);
    }
};

/// 创建连接的便捷函数
///
/// ## 使用示例
/// ```zig
/// const conn = try redis.connect(.{
///     .host = "localhost",
///     .port = 6379,
///     .password = "secret",
/// }, allocator);
/// defer conn.close();
///
/// const reply = try conn.get("mykey");
/// defer reply.deinit();
/// ```
pub fn connect(options: ConnectOptions, allocator: std.mem.Allocator) !*Connection {
    return Connection.connect(options, allocator);
}

/// 使用默认选项创建连接
pub fn connectDefault(allocator: std.mem.Allocator) !*Connection {
    return Connection.connect(.{}, allocator);
}
