# ZigCMS 深度架构分析与优化技术规格

## 1. 任务难度评估

**难度等级**: **Hard** (复杂)

**理由**:
- 涉及复杂的内存管理、线程安全、架构重构
- 需要深入理解 Zig 的内存模型和所有权语义
- 需要修改核心架构组件，影响范围广
- 需要保持向后兼容性的同时进行大规模重构

---

## 2. 技术环境

### 2.1 编程语言与版本
- **语言**: Zig >= 0.15.0
- **目标**: 高性能、内存安全的 Web 框架

### 2.2 核心依赖
- **zap**: HTTP 服务器 (基于 Facil.io)
- **pg**: PostgreSQL 驱动
- **sqlite**: SQLite 嵌入式数据库
- **mysql-client**: MySQL 客户端库
- **pretty**: 格式化输出
- **regex**: 正则表达式
- **curl**: HTTP 客户端
- **smtp_client**: 邮件发送

### 2.3 架构模式
- **Clean Architecture** (整洁架构/六边形架构)
- **DI/IoC** (依赖注入/控制反转)
- **Repository Pattern** (仓储模式)
- **ORM** (对象关系映射)

---

## 3. 深度问题分析

### 3.1 内存泄露与内存安全问题 [严重]

#### 3.1.1 全局状态内存管理混乱

**位置**: `shared/primitives/global.zig`

**问题描述**:
```zig
// global.zig:44-52
var _allocator: ?Allocator = null;
var _db: ?*sql.Database = null;
var _service_manager: ?*services.ServiceManager = null;
var _plugin_system: ?*PluginSystemService = null;
var config: std.StringHashMap([]const u8) = undefined;
var mu: std.Thread.Mutex = std.Thread.Mutex{};

pub const JwtTokenSecret = "this is a secret";
var is_initialized: bool = false;
```

**具体问题**:
1. **所有权不明确**: `_db` 在两个不同的初始化路径中有不同的所有权:
   - `init()`: global 创建并拥有
   - `initWithDb()`: 外部创建，global 只持有引用
   
2. **清理路径混乱**: 
   - `deinit()` 中不清理 `_db`，依赖调用者清理
   - 但在 `init_some()` 的错误处理中会清理 `_db`
   - 造成双重释放或泄漏风险

3. **重复的插件系统实例**:
   - `_plugin_system`: global 自己的实例
   - `_service_manager.plugin_system`: ServiceManager 的实例
   - 两个独立实例，职责不清，可能双重初始化

**内存泄露场景**:
```zig
// 场景1: initWithDb 后调用 deinit
initWithDb(allocator, db);  // _db 指向外部 db
deinit();                    // 不清理 _db，但外部可能已释放 → 悬空指针

// 场景2: init_some 错误路径
init_some();  // _db 创建
// 如果 initPluginSystem 失败
// _db 被释放
// 但 _db 指针未清空 → 悬空指针

// 场景3: 重复初始化
init(alloc);           // 创建 _plugin_system
// 未调用 deinit
init(alloc);           // is_initialized=true，跳过初始化
                       // 第一次的资源泄漏
```

**修复建议**:
- 明确资源所有权，使用 owned/borrowed 模式
- 统一初始化路径，移除重复逻辑
- 添加资源追踪和断言检查

---

#### 3.1.2 DI容器单例服务泄漏

**位置**: `shared/di/container.zig`, `root.zig:registerApplicationServices`

**问题描述**:
```zig
// shared/di/container.zig:124-129
pub fn deinit(self: *Self) void {
    if (!self.initialized) return;
    self.singletons.deinit();       // 只释放 HashMap
    self.descriptors.deinit();      // 只释放 HashMap
    self.initialized = false;
}
```

**具体问题**:
1. **单例服务未释放**: `singletons` HashMap 只释放了容器本身，未释放指向的服务实例
2. **瞬态服务泄漏**: Transient 服务由调用者管理，但没有追踪机制
3. **工厂闭包泄漏**: Factory 函数中可能捕获的上下文未清理

**泄漏示例**:
```zig
// root.zig:349-376 注册用户服务
fn registerUserServices(container: *DIContainer, db: *sql.Database) !void {
    const sqlite_repo = try createSqliteUserRepository(db);  // 分配
    const user_repo = try std.heap.page_allocator.create(UserRepository);  // 分配
    user_repo.* = domain.repositories.user_repository.create(sqlite_repo, &SqliteUserRepository.vtable());
    
    try container.registerInstance(SqliteUserRepository, sqlite_repo);  // 存入容器
    try container.registerInstance(UserRepository, user_repo);          // 存入容器
    
    // 问题: container.deinit() 时这些实例不会被释放!
}
```

**影响**:
- 每次重启应用，所有单例服务泄漏
- 长期运行导致内存增长

**修复建议**:
- DIContainer 添加 `deinit_fn` 字段存储清理函数
- `deinit()` 时调用所有单例的清理函数
- 添加服务生命周期追踪

---

#### 3.1.3 ConnectionPool 虚假实现

**位置**: `application/services/sql/advanced.zig:808-839`

**问题描述**:
```zig
pub const ConnectionPool = struct {
    // ... 字段

    /// 获取连接
    pub fn acquire(self: *ConnectionPool) !*mysql.DB {
        self.stats.acquires += 1;
        return mysql.open(self.allocator, self.db_config);  // 每次都创建新连接!
    }

    /// 释放连接
    pub fn release(self: *ConnectionPool, conn: *mysql.DB) void {
        self.stats.releases += 1;
        conn.close();  // 直接关闭，未放回池中!
    }
}
```

**具体问题**:
1. **根本没有池化**: 每次 `acquire` 创建新连接，`release` 直接关闭
2. **配置参数无用**: `min_connections`, `max_connections` 等配置完全未使用
3. **性能损失**: 无法复用连接，频繁创建/销毁连接

**正确实现参考** (`application/services/sql/orm.zig:3300+`):
```zig
pub const ConnectionPool = struct {
    // 应该有的字段
    idle_connections: std.ArrayListUnmanaged(PooledConnection),
    active_count: std.atomic.Value(u32),
    idle_mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    
    // 真正的 acquire 逻辑
    pub fn acquire(self: *Self) !*PooledConnection {
        // 1. 尝试从 idle_connections 获取
        // 2. 如果池为空且未达 max，创建新连接
        // 3. 如果达到 max，等待或超时
    }
}
```

**修复建议**:
- 移除虚假实现，使用 `orm.zig` 中的真实 ConnectionPool
- 或者完善 `advanced.zig` 中的实现
- 添加连接健康检查和保活机制

---

#### 3.1.4 ORM 字符串内存泄漏风险

**位置**: `application/services/sql/orm.zig:130-198 mapResults()`

**问题描述**:
```zig
// orm.zig:162-170
if (@typeInfo(field.type) == .optional) {
    if (value) |v| {
        @field(model, field.name) = try allocator.dupe(u8, v);  // 分配
    } else {
        @field(model, field.name) = null;
    }
} else if (field.type == []const u8) {
    if (value) |v| {
        @field(model, field.name) = try allocator.dupe(u8, v);  // 分配
    } else {
        @field(model, field.name) = "";  // 静态字符串
    }
}
```

**具体问题**:
1. **字符串所有权复杂**: 
   - `dupe()` 分配的字符串需要 `freeModel()` 释放
   - 空字符串 `""` 是静态的，不能释放
   - `freeModel()` 通过指针比较区分 (`.ptr != "".ptr`)

2. **容易遗漏清理**:
   ```zig
   // 危险用法
   const users = try User.all(db);
   // 忘记调用 User.freeModels(allocator, users)
   // → 泄漏
   ```

3. **错误路径泄漏**:
   ```zig
   // orm.zig:194
   try models.append(allocator, model);  // 可能失败
   // 如果失败，model 中已分配的字符串会泄漏
   ```

**修复建议**:
- 使用 Arena Allocator 管理查询结果
- 提供 RAII 包装器自动清理
- 添加编译时检查确保清理

---

### 3.2 线程安全问题 [严重]

#### 3.2.1 全局状态竞态条件

**位置**: `shared/primitives/global.zig`

**问题描述**:
```zig
// global.zig:49-52
var config: std.StringHashMap([]const u8) = undefined;
var mu: std.Thread.Mutex = std.Thread.Mutex{};
var is_initialized: bool = false;  // 无保护!

// global.zig:348-354
pub fn get_setting(key: []const u8, def_value: []const u8) []const u8 {
    mu.lock();
    defer mu.unlock();
    return config.get(key) orelse def_value;  // def_value 可能在锁外被修改
}

// global.zig:298-303
pub fn init(allocator: Allocator) void {
    if (is_initialized) return;  // 竞态: TOCTOU 问题
    _allocator = allocator;
    init_some();
}
```

**具体问题**:
1. **TOCTOU 竞态** (Time-of-check to Time-of-use):
   ```
   Thread A: if (is_initialized) → false
   Thread B: if (is_initialized) → false
   Thread A: _allocator = allocator;  init_some();
   Thread B: _allocator = allocator;  init_some();  // 重复初始化!
   ```

2. **无保护的状态检查**: `is_initialized` 读写未加锁
3. **返回值生命周期**: `get_setting()` 返回的切片在锁外可能失效

**危险场景**:
```zig
// 场景: 两个线程同时调用 init
Thread 1: global.init(alloc1);
Thread 2: global.init(alloc2);

// 可能结果:
// - 两个线程都创建数据库连接 (_db 泄漏)
// - _allocator 被覆盖 (使用错误的分配器)
// - 插件系统双重初始化
```

**修复建议**:
- 使用 `std.once.Once` 确保单次初始化
- 所有全局状态访问都需加锁
- 返回值使用 caller-owned 模式

---

#### 3.2.2 ConnectionPool 无线程保护

**位置**: `application/services/sql/orm.zig:3300+`

**问题描述**:
```zig
pub const ConnectionPool = struct {
    idle_connections: std.ArrayListUnmanaged(PooledConnection),  // 无保护
    active_count: std.atomic.Value(u32),                         // 原子，但不够
    idle_mutex: std.Thread.Mutex,                                // 有 mutex
    condition: std.Thread.Condition,                             // 有条件变量
    
    pub fn acquire(self: *Self) !*PooledConnection {
        self.idle_mutex.lock();
        defer self.idle_mutex.unlock();
        
        // 问题: 在等待期间持有锁
        while (self.idle_connections.items.len == 0) {
            const active = self.active_count.load(.monotonic);
            if (active < self.config.max_size) {
                break;  // 创建新连接
            }
            // 阻塞等待，持有 idle_mutex
            try self.condition.timedWait(&self.idle_mutex, ...);  
        }
    }
}
```

**具体问题**:
1. **死锁风险**: `timedWait` 在等待时会暂时释放锁，但实现复杂容易出错
2. **统计信息无保护**: `stats` 字段的修改未加锁
3. **active_count 不一致**: 原子变量与 `idle_connections` 的一致性无保证

**竞态示例**:
```
Thread A: acquire() → idle 为空，active < max
Thread B: acquire() → idle 为空，active < max
Thread A: 创建连接，active_count++
Thread B: 创建连接，active_count++
→ 可能超过 max_size 限制
```

**修复建议**:
- 使用单一 Mutex 保护所有池状态
- 统计信息也需加锁保护
- 添加不变量断言检查

---

#### 3.2.3 缓存服务线程安全不足

**位置**: `infrastructure/cache/mod.zig:66-240 MemoryCache`

**问题描述**:
```zig
const MemoryCache = struct {
    data: std.StringHashMap(CacheEntry),
    mutex: std.Thread.Mutex = .{},
    
    fn get(ptr: *anyopaque, key: []const u8) ?[]const u8 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.data.get(key)) |entry| {
            if (entry.isExpired()) {
                return null;  // 问题: 过期条目未删除
            }
            return entry.value;  // 问题: 返回引用，在锁外可能失效
        }
        return null;
    }
}
```

**具体问题**:
1. **返回值生命周期**: `entry.value` 在锁外可能被其他线程修改/删除
2. **过期条目积累**: 过期检查后未清理，导致内存泄漏
3. **cleanupExpired 不完整**: 迭代中删除 HashMap 元素的实现缺失

**危险场景**:
```zig
Thread A: cache.get("key") → 获取 value 引用，释放锁
Thread B: cache.del("key") → 删除条目，释放 value 内存
Thread A: 使用 value  → 悬空指针！
```

**修复建议**:
- `get()` 返回值需要复制，不能返回内部引用
- 添加自动清理过期条目机制
- 使用 `swap_remove` 安全删除迭代中的元素

---

### 3.3 架构耦合问题 [中等]

#### 3.3.1 全局状态反模式

**问题**:
- `global.zig` 包含大量可变全局状态
- 违反依赖注入原则
- 难以测试和模拟

**示例**:
```zig
// 控制器依赖全局状态
const db = global.get_db();  // 紧耦合到 global
const sm = global.getServiceManager();
```

**影响**:
- 无法并行测试 (共享全局状态)
- 无法注入 mock 对象
- 模块间隐式依赖

**修复方向**:
- 移除全局状态，使用显式依赖注入
- 通过上下文对象传递依赖
- 保留 DI 容器为单一全局入口点

---

#### 3.3.2 层边界模糊

**问题**:
- API 层直接访问 Infrastructure 层
- Domain 层引用 Application 层
- 跨层引用混乱

**示例**:
```zig
// api/bootstrap.zig 直接使用 infrastructure
const db = try infrastructure.init(allocator, config.infra);

// domain/entities/models.zig 可能引用 ORM (application 层)
```

**影响**:
- 违反 Clean Architecture 原则
- 依赖方向错误
- 难以替换实现

**修复方向**:
- 明确依赖规则: Infra → App → Domain
- 使用接口隔离层
- 移除循环依赖

---

#### 3.3.3 ServiceManager 与 Global 职责重叠

**问题**:
```zig
// ServiceManager 管理服务
pub const ServiceManager = struct {
    cache: CacheService,
    plugin_system: PluginSystemService,
};

// Global 也管理服务
var _service_manager: ?*services.ServiceManager = null;
var _plugin_system: ?*PluginSystemService = null;  // 重复!
```

**影响**:
- 两套管理机制
- 资源重复分配
- 清理路径混乱

**修复方向**:
- 统一到 ServiceManager
- Global 只作为启动入口
- 明确所有权传递

---

### 3.4 代码质量与工程化问题 [中等]

#### 3.4.1 错误处理不一致

**问题**:
```zig
// 有些地方使用 errdefer
const db = try allocator.create(sql.Database);
errdefer allocator.destroy(db);

// 有些地方使用 owned 标志
var owned = false;
errdefer if (!owned) allocator.destroy(ctrl_ptr);

// 有些地方什么都没有
const repo = try createSqliteUserRepository(db);  // 泄漏风险
```

**影响**:
- 错误路径泄漏
- 维护困难
- 代码审查负担

---

#### 3.4.2 资源所有权文档缺失

**问题**:
- 函数签名无法表达所有权转移
- 注释不一致或缺失
- 调用者需要阅读实现才能理解

**示例**:
```zig
// 谁拥有返回值？需要调用者释放吗？
pub fn mapResults(comptime T: type, allocator: Allocator, result: *ResultSet) ![]T

// 良好示例（有注释）
/// 返回的 []T 数组由调用者拥有，必须使用 allocator.free() 释放
```

---

#### 3.4.3 测试覆盖不足

**发现**:
- 单元测试主要集中在 ORM 查询构建
- 缺少并发测试
- 缺少内存泄漏检测测试
- 缺少错误路径测试

---

## 4. 优化实施方案

### 4.1 内存管理改进

#### 4.1.1 统一资源所有权模式

**原则**:
1. **Owned vs Borrowed**: 明确区分拥有和借用
2. **RAII 包装器**: 为复杂资源提供自动清理
3. **Arena Allocator**: 批量生命周期使用 Arena

**实现**:
```zig
// shared/primitives/ownership.zig (新文件)

/// 拥有的资源
pub fn Owned(comptime T: type) type {
    return struct {
        value: T,
        allocator: Allocator,
        
        pub fn deinit(self: *@This()) void {
            self.value.deinit();
            self.allocator.destroy(&self.value);
        }
    };
}

/// 借用的资源
pub fn Borrowed(comptime T: type) type {
    return struct {
        value: *T,
        // 不拥有，不清理
    };
}
```

#### 4.1.2 修复 Global 模块

**变更**:
```zig
// shared/primitives/global.zig

pub const GlobalContext = struct {
    allocator: Allocator,
    db: Borrowed(*sql.Database),  // 明确标记为借用
    service_manager: Owned(*ServiceManager),
    config: ConfigManager,
    
    pub fn init(allocator: Allocator, db: *sql.Database) !GlobalContext {
        // 单次初始化保证
        return .{
            .allocator = allocator,
            .db = .{ .value = db },
            .service_manager = try Owned(*ServiceManager).init(allocator),
            .config = ConfigManager.init(allocator),
        };
    }
    
    pub fn deinit(self: *GlobalContext) void {
        self.service_manager.deinit();  // 只清理自己拥有的
        self.config.deinit();
        // db 不清理（借用的）
    }
};

// 使用 std.once.Once 保证单次初始化
var global_once = std.once.Once{};
var global_ctx: ?GlobalContext = null;

pub fn initGlobal(allocator: Allocator, db: *sql.Database) void {
    global_once.call(struct {
        fn init(alloc: Allocator, database: *sql.Database) void {
            global_ctx = GlobalContext.init(alloc, database) catch @panic("Failed to init global");
        }
    }.init, .{allocator, db});
}
```

#### 4.1.3 修复 DI 容器内存管理

**变更**:
```zig
// shared/di/container.zig

pub const ServiceDescriptor = struct {
    service_type_name: []const u8,
    implementation_type_name: []const u8,
    factory: ?*const fn (*DIContainer, std.mem.Allocator) anyerror!*anyopaque,
    deinit_fn: ?*const fn (*anyopaque, std.mem.Allocator) void,  // 新增
    lifetime: ServiceLifetime,
    instance: ?*anyopaque = null,
};

pub fn registerSingleton(
    self: *Self,
    comptime ServiceType: type,
    comptime ImplementationType: type,
    factory: fn (*DIContainer, std.mem.Allocator) anyerror!*ImplementationType,
    deinit_fn: fn (*ImplementationType, std.mem.Allocator) void,  // 新增参数
) !void {
    const service_name = @typeName(ServiceType);
    const descriptor = ServiceDescriptor{
        .service_type_name = service_name,
        .implementation_type_name = @typeName(ImplementationType),
        .factory = @ptrCast(&factory),
        .deinit_fn = @ptrCast(&deinit_fn),  // 存储清理函数
        .lifetime = .Singleton,
    };
    try self.descriptors.put(service_name, descriptor);
}

pub fn deinit(self: *Self) void {
    if (!self.initialized) return;
    
    // 清理所有单例实例
    var it = self.descriptors.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.lifetime == .Singleton and entry.value_ptr.instance != null) {
            if (entry.value_ptr.deinit_fn) |deinit_fn| {
                deinit_fn(entry.value_ptr.instance.?, self.allocator);
            }
        }
    }
    
    self.singletons.deinit();
    self.descriptors.deinit();
    self.initialized = false;
}
```

#### 4.1.4 ORM 使用 Arena Allocator

**变更**:
```zig
// application/services/sql/orm.zig

/// 查询结果集 (RAII 包装器)
pub fn QueryResult(comptime T: type) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        models: []T,
        
        pub fn init(backing_allocator: Allocator, result_set: *ResultSet) !@This() {
            var arena = std.heap.ArenaAllocator.init(backing_allocator);
            errdefer arena.deinit();
            
            const allocator = arena.allocator();
            const models = try mapResults(T, allocator, result_set);
            
            return .{
                .arena = arena,
                .models = models,
            };
        }
        
        pub fn deinit(self: *@This()) void {
            self.arena.deinit();  // 一次性清理所有分配
        }
    };
}

// 使用示例
const result = try QueryResult(User).init(allocator, &result_set);
defer result.deinit();  // 自动清理，无需手动 freeModels

for (result.models) |user| {
    // 使用 user
}
```

---

### 4.2 线程安全改进

#### 4.2.1 使用 std.once.Once 保护初始化

**变更**: 见 4.1.2

#### 4.2.2 修复 ConnectionPool 线程安全

**变更**:
```zig
// application/services/sql/orm.zig

pub const ConnectionPool = struct {
    allocator: Allocator,
    config: PoolConfig,
    db_config: MySQLConfig,
    
    // 所有状态由单一 Mutex 保护
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    
    // 受保护的状态
    idle_connections: std.ArrayListUnmanaged(*PooledConnection),
    active_count: u32,  // 不再使用原子变量
    total_count: u32,
    stats: PoolStats,
    
    pub fn acquire(self: *Self) !*PooledConnection {
        const deadline = std.time.milliTimestamp() + self.config.acquire_timeout_ms;
        
        self.mutex.lock();
        defer self.mutex.unlock();
        
        while (true) {
            // 1. 尝试从池中获取
            if (self.idle_connections.popOrNull()) |conn| {
                if (conn.isHealthy()) {
                    self.active_count += 1;
                    self.stats.hits += 1;
                    return conn;
                } else {
                    conn.destroy();  // 损坏的连接
                    self.total_count -= 1;
                }
            }
            
            // 2. 创建新连接
            if (self.total_count < self.config.max_size) {
                const conn = try self.createConnection();
                self.active_count += 1;
                self.total_count += 1;
                self.stats.creates += 1;
                return conn;
            }
            
            // 3. 等待可用连接
            const now = std.time.milliTimestamp();
            if (now >= deadline) {
                return error.AcquireTimeout;
            }
            
            const wait_ms = @intCast(u64, deadline - now);
            try self.condition.timedWait(&self.mutex, wait_ms * 1000000);
        }
    }
    
    pub fn release(self: *Self, conn: *PooledConnection) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        self.active_count -= 1;
        self.stats.releases += 1;
        
        if (conn.broken or self.total_count > self.config.max_size) {
            conn.destroy();
            self.total_count -= 1;
            self.stats.destroys += 1;
        } else {
            self.idle_connections.append(self.allocator, conn) catch {
                conn.destroy();
                self.total_count -= 1;
            };
        }
        
        self.condition.signal();  // 唤醒等待的线程
    }
    
    // 不变量检查 (Debug 构建)
    fn checkInvariants(self: *Self) void {
        if (std.debug.runtime_safety) {
            std.debug.assert(self.active_count + self.idle_connections.items.len == self.total_count);
            std.debug.assert(self.total_count <= self.config.max_size);
        }
    }
};
```

#### 4.2.3 修复缓存线程安全

**变更**:
```zig
// infrastructure/cache/mod.zig

const MemoryCache = struct {
    data: std.StringHashMap(CacheEntry),
    mutex: std.Thread.Mutex,
    default_ttl: u64,
    
    /// 获取缓存 (返回拷贝，避免生命周期问题)
    fn get(ptr: *anyopaque, key: []const u8) ?[]const u8 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();
        
        const entry = self.data.get(key) orelse return null;
        
        if (entry.isExpired()) {
            // 自动清理过期条目
            self.data.remove(key);
            self.allocator.free(entry.value);
            return null;
        }
        
        // 返回拷贝，避免锁外使用时被其他线程修改
        return self.allocator.dupe(u8, entry.value) catch null;
    }
    
    /// 清理所有过期条目 (线程安全)
    fn cleanupExpired(ptr: *anyopaque) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();
        
        var keys_to_remove = std.ArrayList([]const u8).init(self.allocator);
        defer keys_to_remove.deinit();
        
        // 收集过期的 key
        var it = self.data.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.isExpired()) {
                try keys_to_remove.append(entry.key_ptr.*);
            }
        }
        
        // 删除过期条目
        for (keys_to_remove.items) |key| {
            if (self.data.fetchRemove(key)) |kv| {
                self.allocator.free(kv.key);
                self.allocator.free(kv.value.value);
            }
        }
    }
};
```

---

### 4.3 架构解耦改进

#### 4.3.1 移除全局状态，使用上下文对象

**新设计**:
```zig
// shared/context/app_context.zig (新文件)

/// 应用上下文 - 替代全局状态
pub const AppContext = struct {
    allocator: Allocator,
    config: *const SystemConfig,
    db: *sql.Database,
    service_manager: *ServiceManager,
    di_container: *DIContainer,
    
    pub fn init(allocator: Allocator, config: *const SystemConfig) !*AppContext {
        const ctx = try allocator.create(AppContext);
        errdefer allocator.destroy(ctx);
        
        const db = try sql.Database.mysql(allocator, config.infra.toMySQLConfig());
        errdefer db.deinit();
        
        const sm = try ServiceManager.init(allocator, db, config.*);
        errdefer sm.deinit();
        
        const di = try DIContainer.init(allocator);
        errdefer di.deinit();
        
        ctx.* = .{
            .allocator = allocator,
            .config = config,
            .db = db,
            .service_manager = sm,
            .di_container = di,
        };
        
        return ctx;
    }
    
    pub fn deinit(self: *AppContext) void {
        self.di_container.deinit();
        self.service_manager.deinit();
        self.db.deinit();
        self.allocator.destroy(self);
    }
};
```

**控制器改造**:
```zig
// api/controllers/user.controller.zig (改造后)

pub const UserController = struct {
    ctx: *AppContext,  // 依赖注入上下文
    
    pub fn init(ctx: *AppContext) UserController {
        return .{ .ctx = ctx };
    }
    
    pub fn list(self: *UserController, req: zap.Request) !void {
        // 使用上下文获取依赖
        const user_service = try self.ctx.di_container.resolve(UserService);
        const users = try user_service.listUsers();
        
        // ...
    }
};
```

#### 4.3.2 明确层依赖方向

**依赖规则**:
```
API Layer → Application Layer → Domain Layer
     ↓             ↓
Infrastructure Layer (实现 Domain 接口)
```

**接口隔离**:
```zig
// domain/repositories/user_repository.zig
// 定义接口，不依赖任何实现

pub const IUserRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    
    pub const VTable = struct {
        findById: *const fn (*anyopaque, u64) anyerror!?User,
        save: *const fn (*anyopaque, *User) anyerror!void,
        // ...
    };
};

// infrastructure/database/mysql_user_repository.zig
// 实现接口

pub const MySQLUserRepository = struct {
    db: *sql.Database,
    
    pub fn asInterface(self: *MySQLUserRepository) IUserRepository {
        return .{
            .ptr = self,
            .vtable = &.{
                .findById = findById,
                .save = save,
            },
        };
    }
};
```

---

### 4.4 代码质量改进

#### 4.4.1 统一错误处理模式

**规范**:
```zig
// 所有需要清理的资源使用 errdefer
pub fn createResource(allocator: Allocator) !*Resource {
    const res = try allocator.create(Resource);
    errdefer allocator.destroy(res);  // 强制 errdefer
    
    res.* = try Resource.init();
    errdefer res.deinit();  // 多级 errdefer
    
    try res.setup();
    
    return res;
}

// 禁止使用 owned 标志
// var owned = false;  // ❌ 不使用这种模式
```

#### 4.4.2 添加资源所有权文档

**模板**:
```zig
/// 创建用户仓储
///
/// 内存所有权:
/// - 返回值由调用者拥有
/// - 调用者必须调用 deinit() 清理
/// - db 参数为借用，不会被释放
///
/// 示例:
/// ```zig
/// const repo = try createUserRepository(allocator, db);
/// defer repo.deinit();
/// ```
pub fn createUserRepository(allocator: Allocator, db: *sql.Database) !*UserRepository {
    // ...
}
```

#### 4.4.3 增加测试覆盖

**新增测试类型**:
```zig
// tests/concurrent_test.zig
test "ConnectionPool: 并发 acquire/release" {
    const allocator = std.testing.allocator;
    var pool = try ConnectionPool.init(allocator, config);
    defer pool.deinit();
    
    // 启动 100 个线程同时获取连接
    var threads: [100]std.Thread = undefined;
    for (threads) |*t| {
        t.* = try std.Thread.spawn(.{}, workerThread, .{&pool});
    }
    
    for (threads) |t| {
        t.join();
    }
    
    // 验证池状态一致性
    try std.testing.expectEqual(@as(u32, 0), pool.active_count);
}

// tests/memory_leak_test.zig
test "ORM: QueryResult 无泄漏" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try std.testing.expect(leaked == .ok);  // 检测泄漏
    }
    
    const allocator = gpa.allocator();
    var db = try sql.Database.sqlite(allocator, ":memory:");
    defer db.deinit();
    
    // 执行查询
    const result = try QueryResult(User).init(allocator, &result_set);
    defer result.deinit();
    
    // 使用结果...
}
```

---

## 5. 实施计划

### 5.1 优先级与风险评估

| 问题类别 | 优先级 | 风险等级 | 预计工作量 |
|---------|--------|---------|-----------|
| 全局状态内存泄漏 | P0 (最高) | 高 | 3-5天 |
| DI容器泄漏 | P0 | 高 | 2-3天 |
| ConnectionPool虚假实现 | P0 | 高 | 2-3天 |
| 线程安全 - Global | P0 | 高 | 2-3天 |
| 线程安全 - ConnectionPool | P0 | 高 | 1-2天 |
| 线程安全 - Cache | P1 (高) | 中 | 1-2天 |
| ORM 字符串泄漏 | P1 | 中 | 3-4天 |
| 架构解耦 | P2 (中) | 中 | 5-7天 |
| 代码质量改进 | P3 (低) | 低 | 持续进行 |

### 5.2 分阶段实施

#### 阶段1: 紧急修复 (Week 1-2)
- 修复全局状态内存管理
- 实现真正的 ConnectionPool
- 添加 DI 容器清理机制
- 使用 std.once.Once 保护初始化

**验证**: 运行内存泄漏检测工具

#### 阶段2: 线程安全加固 (Week 3)
- 完善 ConnectionPool 线程安全
- 修复缓存返回值生命周期
- 添加并发测试

**验证**: 压力测试，并发测试通过

#### 阶段3: ORM 内存优化 (Week 4)
- 引入 Arena Allocator
- 实现 QueryResult 包装器
- 重构字符串所有权

**验证**: 长期运行测试无泄漏

#### 阶段4: 架构重构 (Week 5-6)
- 引入 AppContext 替代全局状态
- 明确层依赖边界
- 统一 ServiceManager

**验证**: 架构审查，单元测试通过

#### 阶段5: 代码质量提升 (持续)
- 统一错误处理
- 添加所有权文档
- 增加测试覆盖率

---

## 6. 验证方法

### 6.1 内存泄漏检测

```bash
# 使用 Zig 内置 GPA 检测
zig build test -Dtest-filter="memory_leak_test"

# 使用 Valgrind (Linux)
valgrind --leak-check=full --show-leak-kinds=all ./zig-out/bin/zigcms

# 使用 AddressSanitizer
zig build -Doptimize=Debug -Dsanitize=address
```

### 6.2 并发测试

```bash
# 运行并发测试套件
zig build test -Dtest-filter="concurrent_test"

# 使用 ThreadSanitizer
zig build -Doptimize=Debug -Dsanitize=thread
```

### 6.3 压力测试

```bash
# 使用 wrk 进行压力测试
wrk -t12 -c400 -d30s http://localhost:8080/api/users/list

# 监控内存使用
while true; do
    ps aux | grep zigcms | awk '{print $6}'
    sleep 1
done
```

---

## 7. 向后兼容性

### 7.1 过渡期方案

**保留旧接口**:
```zig
// 标记为废弃，但保留兼容性
pub fn init(allocator: Allocator) void {
    @compileError("global.init() is deprecated, use initGlobal() instead");
}

// 或提供兼容封装
pub fn get_db() *sql.Database {
    return global_ctx.?.db.value;  // 内部转发到新实现
}
```

### 7.2 迁移指南

**为用户提供迁移文档**:
```markdown
## 从 global.init() 迁移到 AppContext

### 旧代码
```zig
global.init(allocator);
defer global.deinit();
const db = global.get_db();
```

### 新代码
```zig
const ctx = try AppContext.init(allocator, &config);
defer ctx.deinit();
const db = ctx.db;
```
```

---

## 8. 成功指标

### 8.1 量化目标

- **内存泄漏**: 0 泄漏 (Valgrind 检测)
- **测试覆盖率**: 提升至 70%+
- **并发测试**: 1000并发无崩溃
- **性能**: 连接池使用后 QPS 提升 50%+

### 8.2 质量目标

- 所有资源有明确所有权文档
- 所有公共 API 有 errdefer 保护
- 无全局可变状态 (除 AppContext)
- 层依赖方向清晰无循环

---

## 9. 风险与挑战

### 9.1 技术风险

- **兼容性破坏**: 大规模重构可能影响现有代码
- **性能回退**: Arena Allocator 可能增加内存峰值
- **复杂度增加**: 上下文传递增加代码量

**缓解措施**:
- 充分测试
- 性能基准对比
- 提供迁移工具

### 9.2 时间风险

- 预计总工作量: 4-6周
- 需要核心开发者全职投入
- 可能影响新功能开发

---

## 10. 后续改进

### 10.1 长期优化

- **异步 I/O**: 引入 async/await 模型
- **零拷贝序列化**: 优化 JSON 处理
- **热重载**: 支持配置和代码热更新

### 10.2 工具建设

- **静态分析工具**: 检测所有权违规
- **性能分析器**: 集成 perf/dtrace
- **文档生成**: 自动生成 API 文档

---

## 附录 A: 关键文件清单

### A.1 需要修改的文件

| 文件路径 | 问题 | 优先级 |
|---------|------|--------|
| `shared/primitives/global.zig` | 全局状态泄漏、线程不安全 | P0 |
| `shared/di/container.zig` | 单例泄漏 | P0 |
| `application/services/sql/orm.zig` | ConnectionPool 真实实现 | P0 |
| `application/services/sql/advanced.zig` | ConnectionPool 虚假实现 | P0 |
| `infrastructure/cache/mod.zig` | 线程安全、生命周期 | P1 |
| `root.zig` | DI 注册、所有权 | P0 |
| `api/Application.zig` | 生命周期管理 | P1 |
| `api/App.zig` | 上下文依赖 | P2 |

### A.2 需要新建的文件

- `shared/primitives/ownership.zig` - 所有权工具
- `shared/context/app_context.zig` - 应用上下文
- `tests/concurrent_test.zig` - 并发测试
- `tests/memory_leak_test.zig` - 泄漏检测测试
- `docs/MIGRATION_GUIDE.md` - 迁移指南

---

## 附录 B: 参考资料

### B.1 Zig 内存管理最佳实践
- [Zig Memory Management](https://ziglang.org/documentation/master/#Memory)
- [Zig Allocators Deep Dive](https://zig.news/kristoff/zig-allocators-101-3k8e)

### B.2 并发编程指南
- [Zig Threading Primitives](https://ziglang.org/documentation/master/#Thread)
- [Lock-Free Programming in Zig](https://zig.news/sobeston/lock-free-programming-in-zig-5eh7)

### B.3 架构设计
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)

---

**文档版本**: v1.0  
**创建日期**: 2026-01-13  
**最后更新**: 2026-01-13  
**作者**: AI Assistant
