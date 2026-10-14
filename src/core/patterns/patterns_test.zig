//! 核心模式（AggregateRoot / Entity / ValueObject / Repository / DomainEvent）单元测试
//!
//! 重点验证所有权约定（AGENTS.md）：
//! - create/init 处 dupe 的字符串字段由 deinit 释放，借用字段不得释放；
//! - Specification 组合节点由最终结果的 deinit 统一递归释放；
//! - 测试统一使用 std.testing.allocator，泄漏 / 双重释放会被直接检出。

const std = @import("std");
const testing = std.testing;

const aggregate_root = @import("aggregate_root.zig");
const entity_mod = @import("entity.zig");
const value_object = @import("value_object.zig");
const repository = @import("repository.zig");
const domain_event = @import("domain_event.zig");

// ============================================================================
// Entity：标识相等性
// ============================================================================

const UserRow = struct {
    name: []const u8,
    age: i32,
};

test "Entity - equality by identity (table driven)" {
    const UserEntity = entity_mod.Entity(UserRow, i32);

    const cases = [_]struct {
        a_id: i32,
        b_id: i32,
        expect_equal: bool,
    }{
        .{ .a_id = 1, .b_id = 1, .expect_equal = true },
        .{ .a_id = 1, .b_id = 2, .expect_equal = false },
        .{ .a_id = 42, .b_id = 42, .expect_equal = true },
    };

    for (cases) |c| {
        const a = UserEntity.create(c.a_id, .{ .name = "alice", .age = 20 });
        const b = UserEntity.create(c.b_id, .{ .name = "bob", .age = 30 });
        try testing.expectEqual(c.expect_equal, a.equals(b));
    }
}

test "Entity - update refreshes data and updated_at" {
    const UserEntity = entity_mod.Entity(UserRow, i32);

    var user = UserEntity.create(7, .{ .name = "old", .age = 1 });
    try testing.expectEqual(@as(i32, 7), user.getId());
    try testing.expectEqualStrings("old", user.getData().name);

    user.update(.{ .name = "new", .age = 2 });
    try testing.expectEqualStrings("new", user.getData().name);
    try testing.expect(user.updated_at >= user.created_at);
}

// ============================================================================
// ValueObject：值相等性与验证器
// ============================================================================

test "ValueObject - equality by value" {
    const Point = value_object.ValueObject(struct { x: i32, y: i32 });

    const a = Point.create(.{ .x = 1, .y = 2 });
    const b = Point.create(.{ .x = 1, .y = 2 });
    const c = Point.create(.{ .x = 2, .y = 1 });

    try testing.expect(a.equals(b));
    try testing.expect(!a.equals(c));
    try testing.expectEqual(@as(i32, 2), a.get().y);
}

test "Validators - string and numeric rules (table driven)" {
    const V = value_object.Validators;

    const not_empty_cases = [_]struct { s: []const u8, expect: bool }{
        .{ .s = "", .expect = false },
        .{ .s = "a", .expect = true },
    };
    for (not_empty_cases) |c| try testing.expectEqual(c.expect, V.notEmpty(c.s));

    const length_cases = [_]struct { s: []const u8, min: usize, max: usize, expect: bool }{
        .{ .s = "abc", .min = 1, .max = 3, .expect = true },
        .{ .s = "", .min = 1, .max = 3, .expect = false },
        .{ .s = "abcd", .min = 1, .max = 3, .expect = false },
    };
    for (length_cases) |c| try testing.expectEqual(c.expect, V.lengthBetween(c.s, c.min, c.max));

    const int_cases = [_]struct { n: i32, expect_pos: bool, expect_nonneg: bool }{
        .{ .n = 1, .expect_pos = true, .expect_nonneg = true },
        .{ .n = 0, .expect_pos = false, .expect_nonneg = true },
        .{ .n = -1, .expect_pos = false, .expect_nonneg = false },
    };
    for (int_cases) |c| {
        try testing.expectEqual(c.expect_pos, V.positive(i32, c.n));
        try testing.expectEqual(c.expect_nonneg, V.nonNegative(i32, c.n));
    }

    const range_cases = [_]struct { n: i32, min: i32, max: i32, expect: bool }{
        .{ .n = 5, .min = 1, .max = 10, .expect = true },
        .{ .n = 0, .min = 1, .max = 10, .expect = false },
        .{ .n = 11, .min = 1, .max = 10, .expect = false },
    };
    for (range_cases) |c| try testing.expectEqual(c.expect, V.inRange(i32, c.n, c.min, c.max));
}

// ============================================================================
// Repository：vtable 分发 + 分页 + 规约
// ============================================================================

const FakeRepo = struct {
    slots: [8]i32 = undefined,
    len: usize = 0,

    fn findByIdImpl(ptr: *anyopaque, id: i32) anyerror!?i32 {
        const self: *FakeRepo = @ptrCast(@alignCast(ptr));
        for (self.slots[0..self.len]) |v| {
            if (v == id) return v;
        }
        return null;
    }

    fn findAllImpl(ptr: *anyopaque) anyerror![]i32 {
        const self: *FakeRepo = @ptrCast(@alignCast(ptr));
        return self.slots[0..self.len];
    }

    fn saveImpl(ptr: *anyopaque, entity: i32) anyerror!i32 {
        const self: *FakeRepo = @ptrCast(@alignCast(ptr));
        if (self.len >= self.slots.len) return error.RepoFull;
        self.slots[self.len] = entity;
        self.len += 1;
        return entity;
    }

    fn updateImpl(_: *anyopaque, _: i32) anyerror!void {}

    fn deleteImpl(ptr: *anyopaque, id: i32) anyerror!void {
        const self: *FakeRepo = @ptrCast(@alignCast(ptr));
        for (self.slots[0..self.len], 0..) |v, i| {
            if (v == id) {
                var j = i;
                while (j + 1 < self.len) : (j += 1) {
                    self.slots[j] = self.slots[j + 1];
                }
                self.len -= 1;
                return;
            }
        }
        return error.NotFound;
    }

    fn countImpl(ptr: *anyopaque) anyerror!usize {
        const self: *FakeRepo = @ptrCast(@alignCast(ptr));
        return self.len;
    }
};

test "Repository - vtable dispatch CRUD" {
    var fake = FakeRepo{};
    const Repo = repository.Repository(i32, i32);
    const repo = Repo{
        .ptr = &fake,
        .vtable = &.{
            .findById = FakeRepo.findByIdImpl,
            .findAll = FakeRepo.findAllImpl,
            .save = FakeRepo.saveImpl,
            .update = FakeRepo.updateImpl,
            .delete = FakeRepo.deleteImpl,
            .count = FakeRepo.countImpl,
        },
    };

    _ = try repo.save(10);
    _ = try repo.save(20);
    try testing.expectEqual(@as(usize, 2), try repo.count());

    try testing.expectEqual(@as(?i32, 10), try repo.findById(10));
    try testing.expectEqual(@as(?i32, null), try repo.findById(99));

    try repo.delete(10);
    try testing.expectEqual(@as(usize, 1), try repo.count());
    try testing.expectError(error.NotFound, repo.delete(10));

    const all = try repo.findAll();
    try testing.expectEqual(@as(usize, 1), all.len);
    try testing.expectEqual(@as(i32, 20), all[0]);

    try repo.update(20); // 合法空操作路径
}

test "PageResult - pagination math incl. zero page_size guard (table driven)" {
    const PR = repository.PageResult(i32);

    const cases = [_]struct {
        total: usize,
        page: u32,
        page_size: u32,
        pages: u32,
        next: bool,
        prev: bool,
    }{
        .{ .total = 10, .page = 1, .page_size = 3, .pages = 4, .next = true, .prev = false },
        .{ .total = 9, .page = 3, .page_size = 3, .pages = 3, .next = false, .prev = true },
        .{ .total = 0, .page = 1, .page_size = 5, .pages = 0, .next = false, .prev = false },
        .{ .total = 10, .page = 2, .page_size = 0, .pages = 0, .next = false, .prev = true },
    };

    for (cases) |c| {
        const pr = PR{ .items = &[_]i32{}, .total = c.total, .page = c.page, .page_size = c.page_size };
        try testing.expectEqual(c.pages, pr.totalPages());
        try testing.expectEqual(c.next, pr.hasNext());
        try testing.expectEqual(c.prev, pr.hasPrev());
    }
}

const Item = struct { price: i64, qty: i32 };

fn fnPriceGt10(_: ?*const anyopaque, e: *const Item) bool {
    return e.price > 10;
}

fn fnQtyPositive(_: ?*const anyopaque, e: *const Item) bool {
    return e.qty > 0;
}

fn fnPriceGt(ctx: ?*const anyopaque, e: *const Item) bool {
    const min: *const i64 = @ptrCast(@alignCast(ctx.?));
    return e.price > min.*;
}

test "Specification - leaf predicates with and without context" {
    const allocator = testing.allocator;
    const Spec = repository.Specification(Item);

    const items = [_]Item{
        .{ .price = 5, .qty = 1 },
        .{ .price = 20, .qty = 0 },
        .{ .price = 20, .qty = 2 },
    };

    const price_cases = [_]struct { idx: usize, expect: bool }{
        .{ .idx = 0, .expect = false },
        .{ .idx = 1, .expect = true },
        .{ .idx = 2, .expect = true },
    };
    const price = Spec.init(allocator, fnPriceGt10);
    for (price_cases) |c| {
        try testing.expectEqual(c.expect, price.isSatisfiedBy(&items[c.idx]));
    }

    // 带上下文：阈值 15
    const threshold: i64 = 15;
    const gt15 = Spec.initWithCtx(allocator, &threshold, fnPriceGt);
    try testing.expect(!gt15.isSatisfiedBy(&items[0]));
    try testing.expect(gt15.isSatisfiedBy(&items[1]));
}

test "Specification - and/or/not combinators with ownership transfer" {
    const allocator = testing.allocator;
    const Spec = repository.Specification(Item);

    const items = [_]Item{
        .{ .price = 5, .qty = 1 },
        .{ .price = 20, .qty = 0 },
        .{ .price = 20, .qty = 2 },
    };

    // AND：price>10 且 qty>0 仅 items[2] 满足
    {
        const price = Spec.init(allocator, fnPriceGt10);
        const qty = Spec.init(allocator, fnQtyPositive);
        var both = try price.and_(qty);
        defer both.deinit(); // 递归释放组合节点；叶子无 Combo，调用安全

        try testing.expect(!both.isSatisfiedBy(&items[0]));
        try testing.expect(!both.isSatisfiedBy(&items[1]));
        try testing.expect(both.isSatisfiedBy(&items[2]));
    }

    // OR：price>10 或 qty>0 全部满足
    {
        const price = Spec.init(allocator, fnPriceGt10);
        const qty = Spec.init(allocator, fnQtyPositive);
        var any = try price.or_(qty);
        defer any.deinit();

        try testing.expect(any.isSatisfiedBy(&items[0]));
        try testing.expect(any.isSatisfiedBy(&items[1]));
        try testing.expect(any.isSatisfiedBy(&items[2]));
    }

    // NOT：!(qty>0) 仅 items[1] 满足
    {
        const qty = Spec.init(allocator, fnQtyPositive);
        var neg = try qty.not();
        defer neg.deinit();

        try testing.expect(!neg.isSatisfiedBy(&items[0]));
        try testing.expect(neg.isSatisfiedBy(&items[1]));
    }

    // 嵌套：(price>10 且 qty>0) 或 !(price>10) → items[0]/items[2] 满足
    // 所有权约定：both 与 neg_price 的 Combo 所有权转移给 combo，只对最终结果 deinit
    {
        const price = Spec.init(allocator, fnPriceGt10);
        const qty = Spec.init(allocator, fnQtyPositive);
        const both = try price.and_(qty);

        const price2 = Spec.init(allocator, fnPriceGt10);
        const neg_price = try price2.not();

        var combo = try both.or_(neg_price);
        defer combo.deinit();

        try testing.expect(combo.isSatisfiedBy(&items[0]));
        try testing.expect(!combo.isSatisfiedBy(&items[1]));
        try testing.expect(combo.isSatisfiedBy(&items[2]));
    }
}

// ============================================================================
// DomainEvent：所有权与序列化
// ============================================================================

const PingPayload = struct { seq: u32 };
const PingEvent = domain_event.DomainEvent(PingPayload);

test "DomainEvent - create owns event_type, deinit frees it" {
    const allocator = testing.allocator;

    var ev = try PingEvent.create(.{ .seq = 1 }, allocator, "user.ping");
    defer ev.deinit(allocator);

    try testing.expect(ev.metadata.owns_event_type);
    try testing.expectEqualStrings("user.ping", ev.getEventType());
    try testing.expect(ev.getOccurredOn() > 0);
}

test "DomainEvent - createSimple borrows event_type (deinit must not free)" {
    var ev = PingEvent.createSimple(.{ .seq = 2 }, "sys.tick");
    defer ev.deinit(testing.allocator); // 借用字段，deinit 不得释放（否则双重释放）

    try testing.expect(!ev.metadata.owns_event_type);
    try testing.expectEqualStrings("sys.tick", ev.getEventType());
}

test "DomainEvent - createWithAggregate dupes all metadata strings" {
    const allocator = testing.allocator;

    var ev = try PingEvent.createWithAggregate(.{ .seq = 3 }, allocator, "user.moved", "agg-1", "User", 4);
    defer ev.deinit(allocator);

    try testing.expectEqualStrings("agg-1", ev.getAggregateId().?);
    try testing.expectEqual(@as(?u32, 4), ev.getAggregateVersion());
    try testing.expectEqualStrings("User", ev.metadata.aggregate_type.?);
}

test "DomainEvent - toJson contains metadata and payload" {
    const allocator = testing.allocator;

    var ev = try PingEvent.create(.{ .seq = 7 }, allocator, "user.ping");
    defer ev.deinit(allocator);

    const json = try ev.toJson(allocator);
    defer allocator.free(json);

    try testing.expect(std.mem.indexOf(u8, json, "\"event_type\":\"user.ping\"") != null);
    // payload 作为字符串值内嵌，内部引号在 JSON 输出中被转义为 \"
    try testing.expect(std.mem.indexOf(u8, json, "\\\"seq\\\":7") != null);
}

test "DomainEvent - fromJson extracts owned event_type" {
    const allocator = testing.allocator;

    // fromJson 必须复制 event_type：借用 parsed JSON 树内部内存在 deinit 后会悬垂
    var ev = try PingEvent.fromJson("{\"event_type\":\"user.ping\",\"payload\":{\"seq\":1}}", allocator);
    defer ev.deinit(allocator);

    try testing.expect(ev.metadata.owns_event_type);
    try testing.expectEqualStrings("user.ping", ev.getEventType());
}

test "DomainEvent - fromJson rejects malformed input (table driven)" {
    const allocator = testing.allocator;

    const cases = [_]struct { json: []const u8, expect_err: anyerror }{
        .{ .json = "[]", .expect_err = error.InvalidEventJson },
        .{ .json = "\"text\"", .expect_err = error.InvalidEventJson },
        .{ .json = "{}", .expect_err = error.MissingEventType },
        .{ .json = "{\"event_type\":42}", .expect_err = error.InvalidEventType },
    };

    for (cases) |c| {
        try testing.expectError(c.expect_err, PingEvent.fromJson(c.json, allocator));
    }
}

test "EventTypeRegistry - comptime register and lookup" {
    const Registry = domain_event.EventTypeRegistry(.{
        .{ "user.created", PingEvent },
        .{ "user.updated", PingEvent },
    });

    try testing.expect(Registry.get("user.created") == PingEvent);
    try testing.expect(Registry.get("user.updated") == PingEvent);
    try testing.expect(Registry.get("missing") == null);
    try testing.expect(Registry.contains("user.created"));
    try testing.expect(!Registry.contains("user.deleted"));
}

test "DomainEventBase - init fills metadata" {
    const base = domain_event.DomainEventBase.init("audit.log", "agg-9", 2);
    try testing.expectEqualStrings("audit.log", base.getEventType());
    try testing.expectEqualStrings("agg-9", base.aggregate_id.?);
    try testing.expectEqual(@as(?u32, 2), base.aggregate_version);
    try testing.expect(base.getOccurredOn() > 0);
}

// ============================================================================
// AggregateRoot：不变量与事件重放
// ============================================================================

const UserAggData = struct { id: ?i32 = null, name: []const u8 = "" };
const SeqEvent = struct { seq: u32 = 0 };
const UserAgg = aggregate_root.AggregateRoot(UserAggData, SeqEvent);

test "AggregateRoot - hasId with optional id (table driven)" {
    const allocator = testing.allocator;

    const cases = [_]struct { id: ?i32, expect_has: bool }{
        .{ .id = 5, .expect_has = true },
        .{ .id = null, .expect_has = false },
    };

    for (cases) |c| {
        var agg = try UserAgg.create(.{ .id = c.id, .name = "n" }, allocator);
        defer agg.deinit();

        try testing.expectEqual(c.expect_has, agg.hasId());
        try testing.expectEqual(@as(u32, 0), agg.getVersion());
    }
}

test "AggregateRoot - fromEvents replays and bumps version" {
    const allocator = testing.allocator;

    const events = [_]SeqEvent{ .{ .seq = 1 }, .{ .seq = 2 }, .{ .seq = 3 } };
    var agg = try UserAgg.fromEvents(&events, allocator);
    defer agg.deinit();

    try testing.expectEqual(@as(u32, 3), agg.getVersion());
}

test "AggregateRoot - drainEvents returns and resets" {
    const allocator = testing.allocator;

    var agg = try UserAgg.create(.{ .id = 1, .name = "n" }, allocator);
    defer agg.deinit();

    var drained = agg.drainEvents();
    defer drained.deinit(agg.allocator);
    try testing.expectEqual(@as(usize, 0), drained.items.len);
}

test "AggregateRoot - snapshot round trip" {
    const allocator = testing.allocator;

    var agg = try UserAgg.create(.{ .id = 9, .name = "snap" }, allocator);
    defer agg.deinit();

    const Snapshot = aggregate_root.AggregateSnapshot(UserAggData, SeqEvent);
    const snap = Snapshot.fromAggregate(&agg);

    const restored = try snap.toAggregate(allocator);
    defer {
        restored.freeData(allocator);
        restored.deinit();
        allocator.destroy(restored);
    }

    try testing.expectEqual(agg.getVersion(), restored.getVersion());
    try testing.expectEqual(agg.getId(), restored.getId());
    try testing.expectEqualStrings("snap", restored.getData().name);
}

const SnapData = struct {
    id: i32 = 0,
    name: []const u8 = "",
    count: i32 = 0,
};
const SnapEvent = struct {
    delta: i32 = 0,
};
const SnapAgg = aggregate_root.AggregateRoot(SnapData, SnapEvent);
const Snap = aggregate_root.AggregateSnapshot(SnapData, SnapEvent);

test "AggregateSnapshot - JSON roundtrip keeps owned strings" {
    const allocator = testing.allocator;

    var agg = try SnapAgg.create(.{ .id = 1, .name = "alice", .count = 5 }, allocator);
    defer agg.deinit();
    try agg.apply(.{ .delta = 2 });

    const snap = Snap.fromAggregate(&agg);
    const json_bytes = try snap.toJSON(allocator);

    const restored = try Snap.fromJSON(allocator, json_bytes);
    // 先释放原始 bytes 再断言：restored 的字符串已深拷贝、自包含
    allocator.free(json_bytes);
    try testing.expectEqualStrings("alice", restored.data.name);
    try testing.expectEqual(@as(i32, 5), restored.data.count);
    try testing.expectEqual(@as(u32, 1), restored.version);

    const agg2 = try restored.toAggregate(allocator);
    try testing.expectEqualStrings("alice", agg2.getData().name);
    try testing.expectEqual(@as(u32, 1), agg2.getVersion());
    agg2.freeData(allocator);
    agg2.deinit();
    allocator.destroy(agg2);
    restored.deinit(allocator);
}

test "AggregateRootFactory - heap alloc with explicit destroy" {
    const allocator = testing.allocator;

    const agg = try aggregate_root.AggregateRootFactory.new(UserAggData, SeqEvent, allocator, .{ .id = 3, .name = "factory" });
    defer {
        agg.deinit();
        allocator.destroy(agg);
    }

    try testing.expectEqual(@as(?i32, 3), agg.getId());
}

// ============================================================================
// AggregateRoot.apply 事件回填（comptime 探测）
// ============================================================================

/// 计数器聚合数据：聚合侧回填（applyEvent，推荐方式）
const CounterData = struct {
    total: i64 = 0,
    last_seq: u32 = 0,

    pub fn applyEvent(self: *@This(), event: SeqEvent) void {
        self.total += @intCast(event.seq);
        self.last_seq = event.seq;
    }
};
const CounterAgg = aggregate_root.AggregateRoot(CounterData, SeqEvent);

/// 点位聚合数据：事件侧回填（applyTo 备选方式）
const PointData = struct { x: i32 = 0 };
const PointEvent = struct {
    dx: i32 = 0,

    pub fn applyTo(self: @This(), data: *PointData) void {
        data.x += self.dx;
    }
};
const PointAgg = aggregate_root.AggregateRoot(PointData, PointEvent);

test "AggregateRoot - apply backfills state via applyEvent" {
    const allocator = testing.allocator;

    var agg = try CounterAgg.create(.{}, allocator);
    defer agg.deinit();

    try agg.apply(.{ .seq = 2 });
    try agg.apply(.{ .seq = 5 });

    try testing.expectEqual(@as(i64, 7), agg.getData().total);
    try testing.expectEqual(@as(u32, 5), agg.getData().last_seq);
    try testing.expectEqual(@as(u32, 2), agg.getVersion());
    // apply 只回填，不重复发布事件
    try testing.expectEqual(@as(usize, 0), agg.getUncommittedEvents().len);
}

test "AggregateRoot - apply backfills state via event applyTo fallback" {
    const allocator = testing.allocator;

    var agg = try PointAgg.create(.{}, allocator);
    defer agg.deinit();

    try agg.apply(.{ .dx = 3 });
    try agg.apply(.{ .dx = 4 });

    try testing.expectEqual(@as(i32, 7), agg.getData().x);
    try testing.expectEqual(@as(u32, 2), agg.getVersion());
}

test "AggregateRoot - fromEvents replays into state" {
    const allocator = testing.allocator;

    const events = [_]SeqEvent{ .{ .seq = 1 }, .{ .seq = 2 }, .{ .seq = 3 } };
    var agg = try CounterAgg.fromEvents(&events, allocator);
    defer agg.deinit();

    try testing.expectEqual(@as(i64, 6), agg.getData().total);
    try testing.expectEqual(@as(u32, 3), agg.getData().last_seq);
    try testing.expectEqual(@as(u32, 3), agg.getVersion());
}
