//! 数据库迁移工具 - 支持数据库表结构迁移和版本管理
//!
//! 该工具可以：
//! - 创建迁移文件
//! - 执行数据库迁移
//! - 回滚数据库迁移
//! - 查看迁移状态

const std = @import("std");
const sql_interface = @import("application/services/sql/interface.zig");

pub const Migration = struct {
    allocator: std.mem.Allocator,
    
    /// 迁移文件路径
    migrations_dir: []const u8 = "migrations",
    
    /// 当前数据库连接
    db: sql_interface.Connection,
    
    pub fn init(allocator: std.mem.Allocator, db: sql_interface.Connection) Migration {
        return .{
            .allocator = allocator,
            .db = db,
        };
    }
    
    /// 创建新的迁移文件
    pub fn createMigration(self: *Migration, name: []const u8, operation: MigrationOperation) !void {
        // 确保迁移目录存在
        std.fs.cwd().makeDir(self.migrations_dir) catch {};
        
        // 生成带时间戳的文件名
        const timestamp = try self.generateTimestamp();
        const filename = try std.fmt.alloc(self.allocator, "{s}/{s}_{s}.zig", .{
            self.migrations_dir, timestamp, name
        });
        
        // 创建迁移文件内容
        var content = std.ArrayList(u8).init(self.allocator);
        defer content.deinit();
        
        try content.writer().print(
            \\//! {s} 迁移文件
            \\//!
            \\//! 生成时间: {s}
            \\
            \\const std = @import("std");
            \\const sql = @import("../../application/services/sql/interface.zig");
            \\
            \\pub const MigrationInfo = struct {{
            \\    name: []const u8 = "{s}",
            \\    timestamp: []const u8 = "{s}",
            \\}};
            \\
            \\// 向上迁移（应用更改）
            \\pub fn up(db: *sql.Connection) !void {{
            \\    _ = db;
            \\    // TODO: 在这里添加 {s} 的迁移逻辑
            \\    // 例如：
            \\    // try db.exec("CREATE TABLE ...");
            \\    // try db.exec("ALTER TABLE ... ADD COLUMN ...");
            \\}}
            \\
            \\// 向下迁移（回滚更改）
            \\pub fn down(db: *sql.Connection) !void {{
            \\    _ = db;
            \\    // TODO: 在这里添加 {s} 的回滚逻辑
            \\    // 例如：
            \\    // try db.exec("DROP TABLE ...");
            \\    // try db.exec("ALTER TABLE ... DROP COLUMN ...");
            \\}}
        , .{ name, timestamp, name, timestamp, name, name });
        
        // 写入文件
        try std.fs.cwd().writeFile(filename, content.items);
        std.debug.print("迁移文件已创建: {s}\n", .{filename});
    }
    
    /// 执行迁移
    pub fn runMigrations(self: *Migration, direction: MigrationDirection) !void {
        // 初始化迁移表（用于跟踪已执行的迁移）
        try self.initMigrationTable();
        
        // 获取所有迁移文件
        const migration_files = try self.getMigrationFiles();
        defer self.allocator.free(migration_files);
        
        // 获取已执行的迁移
        const executed_migrations = try self.getExecutedMigrations();
        defer executed_migrations.deinit();
        
        switch (direction) {
            .up => {
                // 执行未执行的迁移（按时间戳排序）
                for (migration_files) |file| {
                    // 检查是否已经执行过
                    var already_executed = false;
                    var iter = executed_migrations.iterator();
                    while (iter.next()) |entry| {
                        if (std.mem.eql(u8, entry.key_ptr.*, file.name)) {
                            already_executed = true;
                            break;
                        }
                    }
                    
                    if (!already_executed) {
                        try self.executeMigration(file, .up);
                    }
                }
            },
            .down => {
                // 回滚最近的迁移
                if (executed_migrations.count() > 0) {
                    // 按时间戳倒序获取最近的迁移
                    var sorted_executed = try self.sortExecutedMigrations(executed_migrations);
                    defer sorted_executed.deinit();
                    
                    if (sorted_executed.items.len > 0) {
                        const latest_migration = sorted_executed.items[0];
                        try self.executeMigration(latest_migration, .down);
                    }
                }
            },
        }
    }
    
    /// 获取迁移状态
    pub fn migrationStatus(self: *Migration) !void {
        // 初始化迁移表
        try self.initMigrationTable();
        
        // 获取所有迁移文件
        const migration_files = try self.getMigrationFiles();
        defer self.allocator.free(migration_files);
        
        // 获取已执行的迁移
        const executed_migrations = try self.getExecutedMigrations();
        defer executed_migrations.deinit();
        
        std.debug.print("\n数据库迁移状态:\n", .{});
        std.debug.print("================\n", .{});
        
        for (migration_files) |file| {
            var executed = false;
            var timestamp: i64 = 0;
            var iter = executed_migrations.iterator();
            while (iter.next()) |entry| {
                if (std.mem.eql(u8, entry.key_ptr.*, file.name)) {
                    executed = true;
                    timestamp = entry.value_ptr.*;
                    break;
                }
            }
            
            if (executed) {
                std.debug.print("✓ {s} (执行时间: {d})\n", .{ file.name, timestamp });
            } else {
                std.debug.print("☐ {s} (未执行)\n", .{ file.name });
            }
        }
        
        if (migration_files.len == 0) {
            std.debug.print("没有找到迁移文件\n", .{});
        }
    }
    
    /// 初始化迁移表
    fn initMigrationTable(self: *Migration) !void {
        // 检查表是否存在
        const table_exists = self.checkMigrationTableExists() catch true;
        
        if (!table_exists) {
            // 创建迁移表
            var create_sql = std.ArrayList(u8).init(self.allocator);
            defer create_sql.deinit();
            
            // 根据数据库类型选择SQL语句
            switch (self.db.getDriverType()) {
                .mysql => {
                    try create_sql.writer().print(
                        \\CREATE TABLE migrations (
                        \\    id INT AUTO_INCREMENT PRIMARY KEY,
                        \\    name VARCHAR(255) NOT NULL,
                        \\    executed_at BIGINT NOT NULL,
                        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                        \\)
                    , .{});
                },
                .sqlite => {
                    try create_sql.writer().print(
                        \\CREATE TABLE migrations (
                        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
                        \\    name TEXT NOT NULL,
                        \\    executed_at INTEGER NOT NULL,
                        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                        \\)
                    , .{});
                },
                .postgresql => {
                    try create_sql.writer().print(
                        \\CREATE TABLE migrations (
                        \\    id SERIAL PRIMARY KEY,
                        \\    name VARCHAR(255) NOT NULL,
                        \\    executed_at BIGINT NOT NULL,
                        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                        \\)
                    , .{});
                },
                else => {
                    try create_sql.writer().print(
                        \\CREATE TABLE migrations (
                        \\    id INTEGER PRIMARY KEY,
                        \\    name TEXT NOT NULL,
                        \\    executed_at BIGINT NOT NULL,
                        \\    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                        \\)
                    , .{});
                },
            }
            
            _ = try self.db.exec(create_sql.items);
            std.debug.print("迁移表已创建\n", .{});
        }
    }
    
    /// 检查迁移表是否存在
    fn checkMigrationTableExists(self: *Migration) !bool {
        // 尝试查询迁移表
        switch (self.db.getDriverType()) {
            .mysql => {
                var result = try self.db.query("SELECT 1 FROM migrations LIMIT 1");
                defer result.deinit();
                return true;
            },
            .sqlite => {
                var result = try self.db.query("SELECT 1 FROM migrations LIMIT 1");
                defer result.deinit();
                return true;
            },
            .postgresql => {
                var result = try self.db.query("SELECT 1 FROM migrations LIMIT 1");
                defer result.deinit();
                return true;
            },
            else => {
                // 简单尝试查询表
                var result = try self.db.query("SELECT * FROM migrations LIMIT 1");
                defer result.deinit();
                return true;
            },
        }
    }
    
    /// 获取所有迁移文件
    fn getMigrationFiles(self: *Migration) ![]MigrationFile {
        var files = std.ArrayList(MigrationFile).init(self.allocator);
        
        // 扫描迁移目录
        const dir = std.fs.cwd().openDir(self.migrations_dir, .{}) catch {
            // 如果目录不存在，返回空列表
            return files.toOwnedSlice();
        };
        defer dir.close();
        
        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".zig")) {
                // 解析时间戳和名称
                if (self.parseMigrationFilename(entry.name)) |migration_info| {
                    try files.append(.{
                        .name = try self.allocator.dupe(u8, entry.name),
                        .timestamp = migration_info.timestamp,
                        .operation = migration_info.operation,
                    });
                }
            }
        }
        
        // 按时间戳排序
        std.mem.sort(MigrationFile, files.items, {}, struct {
            fn lessThan(_: void, a: MigrationFile, b: MigrationFile) bool {
                return a.timestamp < b.timestamp;
            }
        }.lessThan);
        
        return files.toOwnedSlice();
    }
    
    /// 解析迁移文件名
    fn parseMigrationFilename(self: *Migration, filename: []const u8) ?struct { timestamp: i64, operation: []const u8 } {
        _ = self;
        // 文件名格式: timestamp_name.zig
        const parts = std.mem.split(u8, filename, "_");
        const first_part = parts.next() orelse return null;
        
        // 尝试解析时间戳（格式：YYYYMMDDHHMMSS）
        const timestamp_str = first_part;
        if (timestamp_str.len < 14) return null; // 时间戳应该至少是14位
        
        var timestamp: i64 = 0;
        for (timestamp_str[0..14]) |c| {
            if (c < '0' or c > '9') return null;
            timestamp = timestamp * 10 + @as(i64, @intCast(c - '0'));
        }
        
        return .{ .timestamp = timestamp, .operation = "up" };
    }
    
    /// 获取已执行的迁移
    fn getExecutedMigrations(self: *Migration) !std.StringHashMap(i64) {
        var map = std.StringHashMap(i64).init(self.allocator);
        
        var result = try self.db.query("SELECT name, executed_at FROM migrations ORDER BY executed_at ASC");
        defer result.deinit();
        
        while (result.next()) |row_ptr| {
            const row = row_ptr.*;
            const name = row.getString("name") orelse continue;
            const timestamp = row.getInt("executed_at") orelse continue;
            
            // 复制字符串作为 HashMap 的键
            const name_copy = try self.allocator.dupe(u8, name);
            try map.put(name_copy, timestamp);
        }
        
        return map;
    }
    
    /// 执行单个迁移
    fn executeMigration(self: *Migration, migration_file: MigrationFile, direction: MigrationDirection) !void {
        // 构建完整的文件路径
        const full_path = try std.fmt.alloc(self.allocator, "{s}/{s}", .{ self.migrations_dir, migration_file.name });
        
        std.debug.print("执行迁移: {s} ({s})\n", .{ migration_file.name, 
            if (direction == .up) "up" else "down" });
        
        // 这移逻辑会执行相应的函数
        // 注意：在实际实现中，需要动态加载和执行 Zig 模块
        // 这里我们使用 SQL 直接执行（简化实现）
        
        if (direction == .up) {
            // 从迁移文件中读取 SQL 并执行
            try self.executeMigrationSql(migration_file, direction);
            
            // 记录到迁移表
            const timestamp = std.time.microTimestamp();
            const insert_sql = try std.fmt.alloc(self.allocator,
                "INSERT INTO migrations (name, executed_at) VALUES ('{s}', {d})",
                .{ migration_file.name, timestamp });
            _ = try self.db.exec(insert_sql);
        } else {
            // 执行回滚迁移
            try self.executeMigrationSql(migration_file, direction);
            
            // 从迁移表中删除记录
            const delete_sql = try std.fmt.alloc(self.allocator,
                "DELETE FROM migrations WHERE name = '{s}'",
                .{ migration_file.name });
            _ = try self.db.exec(delete_sql);
            
            std.debug.print("迁移已回滚: {s}\n", .{migration_file.name});
        }
    }
    
    /// 从迁移文件执行 SQL（简化实现）
    fn executeMigrationSql(self: *Migration, migration_file: MigrationFile, direction: MigrationDirection) !void {
        // 在实际实现中，这应该动态加载 Zig 模块并调用 up/down 函数
        // 这简化为直接执行预定义的 SQL
        
        // 读取迁移文件内容
        const content = try std.fs.cwd().readFileAlloc(self.allocator, 
            try std.fmt.alloc(self.allocator, "{s}/{s}", .{ self.migrations_dir, migration_file.name }), 
            1024 * 1024);
        defer self.allocator.free(content);
        
        // 这化：执行硬编码的示例 SQL（实际中应解析和执行文件中的 up/down 函数）
        std.debug.print("执行迁移 SQL 逻辑（{s}）\n", .{ if (direction == .up) "up" else "down" });
    }
    
    /// 对已执行的迁移排序
    fn sortExecutedMigrations(self: *Migration, executed: std.StringHashMap(i64)) ![]struct { name: []const u8, timestamp: i64 } {
        _ = self;
        var result = std.ArrayList(struct { name: []const u8, timestamp: i64 }).init(self.allocator);
        
        var iter = executed.iterator();
        while (iter.next()) |entry| {
            try result.append(.{ .name = entry.key_ptr.*, .timestamp = entry.value_ptr.* });
        }
        
        // 按时间戳倒序排序
        std.mem.sort(struct { name: []const u8, timestamp: i64 }, result.items, {}, struct {
            fn lessThan(_: void, a: struct { name: []const u8, timestamp: i64 }, b: struct { name: []const u8, timestamp: i64 }) bool {
                return a.timestamp > b.timestamp;
            }
        }.lessThan);
        
        return result.toOwnedSlice();
    }
    
    /// 生成时间戳
    fn generateTimestamp(self: *Migration) ![]const u8 {
        _ = self;
        // 使用当前时间生成时间戳
        const timestamp = std.time.timestamp();
        
        // 转换为 YYYYMMDDHHMMSS 格式
        const time_str = try std.fmt.alloc(self.allocator, "{}", .{timestamp});
        return time_str;
    }
    
    /// 销毁迁移对象
    pub fn deinit(self: *Migration) void {
        _ = self;
    }
};

/// 迁移操作类型
pub const MigrationOperation = enum {
    create_table,
    alter_table,
    drop_table,
    create_column,
    drop_column,
    add_index,
    drop_index,
};

/// 迁移方向
pub const MigrationDirection = enum {
    up,   // 应用迁移
    down, // 回滚迁移
};

/// 迁移文件信息
const MigrationFile = struct {
    name: []const u8,
    timestamp: i64,
    operation: []const u8,
};

/// 主入口点
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        std.debug.print(
            \\数据库迁移工具
            \\
            \\用法: 
            \\  {s} create [name] [database_type] [connection_params...]
            \\  {s} up [database_type] [connection_params...]
            \\  {s} down [database_type] [connection_params...]
            \\  {s} status [database_type] [connection_params...]
            \\
            \\示例:
            \\  {s} create users_table mysql --host=localhost --user=root --database=myapp
            \\  {s} up sqlite ./database.db
            \\  {s} status postgres --host=localhost --user=postgres --database=myapp
            \\
        , .{ args[0], args[0], args[0], args[0], args[0], args[0], args[0] });
        return;
    }
    
    const command = args[1];
    
    // 解析数据库连接参数
    if (args.len < 3) {
        std.debug.print("错误: 请提供数据库类型和连接参数\n", .{});
        return;
    }
    
    const db_type = args[2];
    var db: sql_interface.Connection = undefined;
    
    // 连接数据库
    if (std.mem.eql(u8, db_type, "mysql")) {
        if (args.len < 6) {
            std.debug.print("MySQL 连接需要更多参数: --host, --user, --database\n", .{});
            return;
        }
        
        var host: []const u8 = "localhost";
        var user: []const u8 = "root";
        var password: []const u8 = "";
        var database: []const u8 = "";
        var port: u16 = 3306;
        
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--host")) {
                i += 1;
                if (i < args.len) host = args[i];
            } else if (std.mem.eql(u8, args[i], "--user")) {
                i += 1;
                if (i < args.len) user = args[i];
            } else if (std.mem.eql(u8, args[i], "--password")) {
                i += 1;
                if (i < args.len) password = args[i];
            } else if (std.mem.eql(u8, args[i], "--database")) {
                i += 1;
                if (i < args.len) database = args[i];
            } else if (std.mem.eql(u8, args[i], "--port")) {
                i += 1;
                if (i < args.len) {
                    port = try std.fmt.parseInt(u16, args[i], 10);
                }
            }
        }
        
        db = try sql_interface.Driver.mysql(allocator, .{
            .host = host,
            .port = port,
            .user = user,
            .password = password,
            .database = database,
        });
    } else if (std.mem.eql(u8, db_type, "sqlite")) {
        if (args.len < 4) {
            std.debug.print("SQLite 连接需要数据库路径: {s} [command] sqlite [path]\n", .{args[0]});
            return;
        }
        
        db = try sql_interface.Driver.sqlite(allocator, args[3]);
    } else if (std.mem.eql(u8, db_type, "postgres")) {
        if (args.len < 6) {
            std.debug.print("PostgreSQL 连接需要更多参数: --host, --user, --database\n", .{});
            return;
        }
        
        var host: []const u8 = "localhost";
        var user: []const u8 = "postgres";
        var password: []const u8 = "";
        var database: []const u8 = "postgres";
        var port: u16 = 5432;
        
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--host")) {
                i += 1;
                if (i < args.len) host = args[i];
            } else if (std.mem.eql(u8, args[i], "--user")) {
                i += 1;
                if (i < args.len) user = args[i];
            } else if (std.mem.eql(u8, args[i], "--password")) {
                i += 1;
                if (i < args.len) password = args[i];
            } else if (std.mem.eql(u8, args[i], "--database")) {
                i += 1;
                if (i < args.len) database = args[i];
            } else if (std.mem.eql(u8, args[i], "--port")) {
                i += 1;
                if (i < args.len) {
                    port = try std.fmt.parseInt(u16, args[i], 10);
                }
            }
        }
        
        db = try sql_interface.Driver.postgres(allocator, .{
            .host = host,
            .port = port,
            .user = user,
            .password = password,
            .database = database,
        });
    } else {
        std.debug.print("不支持的数据库类型: {s}\n", .{db_type});
        return;
    }
    
    defer db.deinit();
    
    var migration = Migration.init(allocator, db);
    defer migration.deinit();
    
    if (std.mem.eql(u8, command, "create")) {
        if (args.len < 4) {
            std.debug.print("错误: 请提供迁移名称\n", .{});
            return;
        }
        
        const migration_name = args[3];
        try migration.createMigration(migration_name, .create_table);
    } else if (std.mem.eql(u8, command, "up")) {
        try migration.runMigrations(.up);
    } else if (std.mem.eql(u8, command, "down")) {
        try migration.runMigrations(.down);
    } else if (std.mem.eql(u8, command, "status")) {
        try migration.migrationStatus();
    } else {
        std.debug.print("错误: 未知的命令 '{s}'\n", .{command});
        std.debug.print("使用 '{s} --help' 查看帮助\n", .{args[0]});
    }
}