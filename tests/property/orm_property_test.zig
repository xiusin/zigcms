//! ORM 属性测试
//!
//! 本文件包含 ORM 模块的属性测试，验证以下正确性属性：
//! - Property 3: QueryBuilder Fluent Chaining
//! - Property 4: Model CRUD Operations
//! - Property 5: Model Memory Cleanup
//!
//! **Validates: Requirements 4.1, 4.5, 4.6, 4.8**

const std = @import("std");
const testing = std.testing;

// 通过 zigcms 库导入 ORM 模块
const zigcms = @import("zigcms");
const sql = zigcms.sql;
const QueryBuilder = sql.core.QueryBuilder;
const OrderDir = sql.core.OrderDir;
const orm = sql.orm;

// ============================================================================
// 测试辅助：简单的伪随机数生成器
// ============================================================================

const SimpleRng = struct {
    state: u64,

    pub fn init(seed: u64) SimpleRng {
        return .{ .state = seed };
    }

    pub fn next(self: *SimpleRng) u64 {
        self.state = self.state *% 6364136223846793005 +% 1442695040888963407;
        return self.state;
    }

    pub fn intRange(self: *SimpleRng, min: u64, max: u64) u64 {
        if (min >= max) return min;
        return min + (self.next() % (max - min));
    }

    pub fn boolean(self: *SimpleRng) bool {
        return (self.next() & 1) == 1;
    }

    pub fn choice(self: *SimpleRng, comptime T: type, items: []const T) T {
        const idx = self.next() % items.len;
        return items[idx];
    }
};

// ============================================================================
// 测试数据生成器
// ============================================================================

const TestFields = [_][]const u8{ "id", "name", "email", "age", "status", "created_at", "price", "category" };
const TestTables = [_][]const u8{ "users", "products", "orders", "categories", "posts" };

fn generateRandomField(rng: *SimpleRng) []const u8 {
    return rng.choice([]const u8, &TestFields);
}

fn generateRandomTable(rng: *SimpleRng) []const u8 {
    return rng.choice([]const u8, &TestTables);
}


// ============================================================================
// SQL 语法验证辅助函数
// ============================================================================

fn isValidSelectSql(sql_str: []const u8) bool {
    if (!std.mem.startsWith(u8, sql_str, "SELECT")) return false;
    if (std.mem.indexOf(u8, sql_str, "FROM") == null) return false;
    var paren_count: i32 = 0;
    for (sql_str) |c| {
        if (c == '(') paren_count += 1;
        if (c == ')') paren_count -= 1;
        if (paren_count < 0) return false;
    }
    if (paren_count != 0) return false;
    return true;
}

fn isValidDeleteSql(sql_str: []const u8) bool {
    if (!std.mem.startsWith(u8, sql_str, "DELETE FROM")) return false;
    return true;
}

fn isValidCountSql(sql_str: []const u8) bool {
    if (!std.mem.startsWith(u8, sql_str, "SELECT COUNT(*)")) return false;
    if (std.mem.indexOf(u8, sql_str, "FROM") == null) return false;
    return true;
}

// ============================================================================
// Property 3: QueryBuilder Fluent Chaining
// **Feature: zigcms-refactoring, Property 3: QueryBuilder Fluent Chaining**
// **Validates: Requirements 4.1**
// ============================================================================

test "Property 3: QueryBuilder fluent chaining produces valid SELECT SQL" {
    const allocator = testing.allocator;
    var rng = SimpleRng.init(12345);

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const table = generateRandomTable(&rng);
        var builder = QueryBuilder(struct {}).init(allocator, table);
        defer builder.deinit();

        const where_count = rng.intRange(0, 4);
        var j: usize = 0;
        while (j < where_count) : (j += 1) {
            const int_val = @as(i64, @intCast(rng.intRange(1, 1000)));
            // 使用固定的 WHERE 条件格式，避免运行时字符串拼接
            _ = builder.where("id = ?", .{int_val});
        }

        if (rng.boolean()) {
            const order_field = generateRandomField(&rng);
            const dir: OrderDir = if (rng.boolean()) .asc else .desc;
            _ = builder.orderBy(order_field, dir);
        }

        if (rng.boolean()) {
            _ = builder.limit(rng.intRange(1, 100));
        }

        if (rng.intRange(0, 10) < 3) {
            _ = builder.offset(rng.intRange(0, 1000));
        }

        if (rng.intRange(0, 10) < 2) {
            _ = builder.distinct();
        }

        const sql_str = try builder.toSql();
        defer allocator.free(sql_str);

        try testing.expect(isValidSelectSql(sql_str));
        try testing.expect(std.mem.indexOf(u8, sql_str, table) != null);
    }
}

test "Property 3: QueryBuilder fluent chaining produces valid DELETE SQL" {
    const allocator = testing.allocator;
    var rng = SimpleRng.init(67890);

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const table = generateRandomTable(&rng);
        var builder = QueryBuilder(struct {}).init(allocator, table);
        defer builder.deinit();

        const where_count = rng.intRange(1, 4);
        var j: usize = 0;
        while (j < where_count) : (j += 1) {
            const int_val = @as(i64, @intCast(rng.intRange(1, 1000)));
            // 使用固定的 WHERE 条件格式
            _ = builder.where("id = ?", .{int_val});
        }

        if (rng.intRange(0, 10) < 3) {
            _ = builder.limit(rng.intRange(1, 100));
        }

        const sql_str = try builder.buildDelete();
        defer allocator.free(sql_str);

        try testing.expect(isValidDeleteSql(sql_str));
        try testing.expect(std.mem.indexOf(u8, sql_str, table) != null);
    }
}

test "Property 3: QueryBuilder fluent chaining produces valid COUNT SQL" {
    const allocator = testing.allocator;
    var rng = SimpleRng.init(11111);

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const table = generateRandomTable(&rng);
        var builder = QueryBuilder(struct {}).init(allocator, table);
        defer builder.deinit();

        const where_count = rng.intRange(0, 3);
        var j: usize = 0;
        while (j < where_count) : (j += 1) {
            const int_val = @as(i64, @intCast(rng.intRange(1, 1000)));
            // 使用固定的 WHERE 条件格式，避免运行时字符串拼接
            _ = builder.where("id = ?", .{int_val});
        }

        const sql_str = try builder.buildCount();
        defer allocator.free(sql_str);

        try testing.expect(isValidCountSql(sql_str));
        try testing.expect(std.mem.indexOf(u8, sql_str, table) != null);
    }
}


// ============================================================================
// Property 4: Model CRUD Operations
// **Feature: zigcms-refactoring, Property 4: Model CRUD Operations**
// **Validates: Requirements 4.5, 4.6**
// ============================================================================

const TestProduct = struct {
    pub const table_name = "test_products";
    pub const primary_key = "id";

    id: u64,
    name: []const u8,
    price: i64,
    category: []const u8,
};

const Product = orm.define(TestProduct);

test "Property 4: Model CRUD operations with memory database" {
    const allocator = testing.allocator;

    // 使用 SQLite 内存数据库而不是 mock memory driver
    var db = try orm.Database.sqlite(allocator, ":memory:");
    defer db.deinit();

    db.enable_logging = false;
    db.debug = false;

    try Product.createTable(&db);

    var rng = SimpleRng.init(22222);

    var i: usize = 0;
    while (i < 50) : (i += 1) {
        const price = @as(i64, @intCast(rng.intRange(100, 10000)));

        const created = try Product.create(&db, .{
            .name = "TestProduct",
            .price = price,
            .category = "Electronics",
        });

        try testing.expect(created.id > 0);
        try testing.expectEqualStrings("TestProduct", created.name);
        try testing.expectEqual(price, created.price);

        var created_copy = created;
        Product.freeModel(allocator, &created_copy);

        if (try Product.find(&db, created.id)) |found| {
            try testing.expectEqual(created.id, found.id);
            try testing.expectEqualStrings("TestProduct", found.name);
            try testing.expectEqual(price, found.price);

            var found_copy = found;
            Product.freeModel(allocator, &found_copy);
        } else {
            return error.RecordNotFound;
        }

        const new_price = @as(i64, @intCast(rng.intRange(100, 10000)));
        const affected = try Product.update(&db, created.id, .{ .price = new_price });
        try testing.expect(affected > 0);

        if (try Product.find(&db, created.id)) |updated| {
            try testing.expectEqual(new_price, updated.price);
            var updated_copy = updated;
            Product.freeModel(allocator, &updated_copy);
        }

        const deleted = try Product.destroy(&db, created.id);
        try testing.expect(deleted > 0);

        const not_found = try Product.find(&db, created.id);
        try testing.expect(not_found == null);
    }
}

test "Property 4: Model.all() returns all records" {
    const allocator = testing.allocator;

    // 使用 SQLite 内存数据库
    var db = try orm.Database.sqlite(allocator, ":memory:");
    defer db.deinit();

    db.enable_logging = false;
    db.debug = false;

    try Product.createTable(&db);

    const record_count: usize = 10;
    var i: usize = 0;
    while (i < record_count) : (i += 1) {
        const created = try Product.create(&db, .{
            .name = "Product",
            .price = @as(i64, @intCast(i * 100)),
            .category = "Test",
        });
        var created_copy = created;
        Product.freeModel(allocator, &created_copy);
    }

    const all_products = try Product.all(&db);
    defer Product.freeModels(allocator, all_products);

    try testing.expectEqual(record_count, all_products.len);
}


// ============================================================================
// Property 5: Model Memory Cleanup
// **Feature: zigcms-refactoring, Property 5: Model Memory Cleanup**
// **Validates: Requirements 4.8**
// ============================================================================

test "Property 5: freeModels releases all string memory without leaks" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            @panic("Memory leak detected in freeModels!");
        }
    }
    const allocator = gpa.allocator();

    // 使用 SQLite 内存数据库
    var db = try orm.Database.sqlite(allocator, ":memory:");
    defer db.deinit();

    db.enable_logging = false;
    db.debug = false;

    try Product.createTable(&db);

    var rng = SimpleRng.init(33333);

    var i: usize = 0;
    while (i < 50) : (i += 1) {
        const price = @as(i64, @intCast(rng.intRange(100, 10000)));
        const created = try Product.create(&db, .{
            .name = "MemoryTestProduct",
            .price = price,
            .category = "MemoryTest",
        });

        var created_copy = created;
        Product.freeModel(allocator, &created_copy);

        const all = try Product.all(&db);
        Product.freeModels(allocator, all);
    }
}

test "Property 5: Model.List auto-cleanup with deinit" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            @panic("Memory leak detected in Model.List!");
        }
    }
    const allocator = gpa.allocator();

    // 使用 SQLite 内存数据库
    var db = try orm.Database.sqlite(allocator, ":memory:");
    defer db.deinit();

    db.enable_logging = false;
    db.debug = false;

    try Product.createTable(&db);

    var i: usize = 0;
    while (i < 5) : (i += 1) {
        const created = try Product.create(&db, .{
            .name = "ListTestProduct",
            .price = @as(i64, @intCast(i * 100)),
            .category = "ListTest",
        });
        var created_copy = created;
        Product.freeModel(allocator, &created_copy);
    }

    var list = try Product.collect(&db);
    defer list.deinit();

    try testing.expectEqual(@as(usize, 5), list.count());
    try testing.expect(!list.isEmpty());
    try testing.expect(list.isNotEmpty());

    if (list.first()) |first_item| {
        try testing.expectEqualStrings("ListTestProduct", first_item.name);
    }
}

test "Property 5: Multiple query results can be freed independently" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            @panic("Memory leak detected!");
        }
    }
    const allocator = gpa.allocator();

    // 使用 SQLite 内存数据库
    var db = try orm.Database.sqlite(allocator, ":memory:");
    defer db.deinit();

    db.enable_logging = false;
    db.debug = false;

    try Product.createTable(&db);

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        const created = try Product.create(&db, .{
            .name = "IndependentTest",
            .price = @as(i64, @intCast(i * 50)),
            .category = "Independent",
        });
        var created_copy = created;
        Product.freeModel(allocator, &created_copy);
    }

    const query1 = try Product.all(&db);
    const query2 = try Product.all(&db);
    const query3 = try Product.all(&db);

    Product.freeModels(allocator, query2);
    Product.freeModels(allocator, query1);
    Product.freeModels(allocator, query3);
}
