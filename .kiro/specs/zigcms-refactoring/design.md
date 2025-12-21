# Design Document: ZigCMS 全面优化重构

## Overview

本设计文档描述 ZigCMS 项目的全面优化重构方案。ZigCMS 是一个基于 Zig 语言的现代化 CMS 系统，采用整洁架构（Clean Architecture）模式。本次重构涵盖内存安全、代码组织、ORM 优化、缓存契约统一、命令行工具、配置加载等多个方面。

### 设计目标

1. **内存安全**: 确保无内存泄漏、重复释放，所有资源有明确的所有权
2. **代码优雅**: main.zig 干净整洁，职责清晰
3. **工程化**: 目录结构清晰，可复用，支持库发布
4. **ORM 易用性**: Laravel Eloquent 风格的优雅 API
5. **缓存统一**: 所有缓存服务遵循统一契约
6. **工具完善**: 命令行工具独立目录，功能完整
7. **配置灵活**: 文件名对应结构体的配置系统

## Architecture

### 系统分层架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        main.zig (入口)                          │
│  - 初始化 GPA 分配器                                            │
│  - 调用 Bootstrap 模块                                          │
│  - 启动服务器                                                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Bootstrap 模块 (新增)                        │
│  - 系统初始化编排                                               │
│  - 路由注册                                                     │
│  - 服务启动                                                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                        API 层 (api/)                            │
│  Controllers | DTO | Middleware | Router                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                     应用层 (application/)                       │
│  UseCases | Services | ORM | Cache | Logger                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      领域层 (domain/)                           │
│  Entities | Services | Repositories                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  基础设施层 (infrastructure/)                   │
│  Database | Cache | Http | Messaging                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      共享层 (shared/)                           │
│  Utils | Primitives | Types | Errors                            │
└─────────────────────────────────────────────────────────────────┘
```

### 内存管理架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    GPA (GeneralPurposeAllocator)                │
│  - 线程安全模式                                                 │
│  - 内存泄漏检测                                                 │
│  - 双重释放检测                                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    ServiceManager (服务管理器)                  │
│  - 统一管理所有服务生命周期                                     │
│  - 明确的初始化/清理顺序                                        │
│  - 资源所有权追踪                                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    各服务实例                                   │
│  Database | Cache | PluginSystem | ...                          │
│  - 每个服务负责自己的资源清理                                   │
│  - 使用 defer/errdefer 确保清理                                 │
└─────────────────────────────────────────────────────────────────┘
```


## Components and Interfaces

### 1. 内存管理组件

#### MemoryTracker (新增)

```zig
//! 内存追踪器 - 用于调试和检测内存问题
pub const MemoryTracker = struct {
    allocator: Allocator,
    allocations: std.AutoHashMap(usize, AllocationInfo),
    mutex: std.Thread.Mutex,
    
    const AllocationInfo = struct {
        size: usize,
        stack_trace: ?[]const usize,
        timestamp: i64,
    };
    
    /// 包装分配器，追踪所有分配
    pub fn wrap(self: *MemoryTracker, allocator: Allocator) Allocator;
    
    /// 报告当前分配状态
    pub fn report(self: *MemoryTracker) void;
    
    /// 检测泄漏
    pub fn detectLeaks(self: *MemoryTracker) []const AllocationInfo;
};
```

### 2. Bootstrap 模块 (新增)

```zig
//! Bootstrap 模块 - 系统启动编排
//! 
//! 职责：
//! - 按正确顺序初始化各层
//! - 注册路由
//! - 配置服务
pub const Bootstrap = struct {
    allocator: Allocator,
    config: SystemConfig,
    
    /// 初始化整个系统
    pub fn init(allocator: Allocator) !Bootstrap;
    
    /// 注册所有路由
    pub fn registerRoutes(self: *Bootstrap, app: *App) !void;
    
    /// 启动服务
    pub fn start(self: *Bootstrap) !void;
    
    /// 清理系统
    pub fn deinit(self: *Bootstrap) void;
};
```

### 3. 配置加载器 (新增)

```zig
//! 配置加载器 - 从 TOML 文件加载配置
pub const ConfigLoader = struct {
    allocator: Allocator,
    config_dir: []const u8,
    
    /// 加载所有配置文件
    pub fn loadAll(self: *ConfigLoader) !SystemConfig;
    
    /// 加载单个配置文件
    pub fn load(self: *ConfigLoader, comptime T: type, filename: []const u8) !T;
    
    /// 应用环境变量覆盖
    pub fn applyEnvOverrides(self: *ConfigLoader, config: *SystemConfig) !void;
};

/// 系统配置结构体
pub const SystemConfig = struct {
    api: ApiConfig,      // 对应 api.toml
    app: AppConfig,      // 对应 app.toml
    domain: DomainConfig, // 对应 domain.toml
    infra: InfraConfig,  // 对应 infra.toml
};
```

### 4. 缓存契约接口

```zig
//! 缓存契约 - 所有缓存实现必须遵循此接口
pub const CacheInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    
    pub const VTable = struct {
        set: *const fn (*anyopaque, []const u8, []const u8, ?u64) anyerror!void,
        get: *const fn (*anyopaque, []const u8) ?[]const u8,
        del: *const fn (*anyopaque, []const u8) anyerror!void,
        exists: *const fn (*anyopaque, []const u8) bool,
        flush: *const fn (*anyopaque) anyerror!void,
        stats: *const fn (*anyopaque) CacheStats,
        cleanupExpired: *const fn (*anyopaque) anyerror!void,
        delByPrefix: *const fn (*anyopaque, []const u8) anyerror!void,
        deinit: *const fn (*anyopaque) void,
    };
    
    // 便捷方法
    pub fn set(self: CacheInterface, key: []const u8, value: []const u8, ttl: ?u64) !void;
    pub fn get(self: CacheInterface, key: []const u8) ?[]const u8;
    pub fn del(self: CacheInterface, key: []const u8) !void;
    pub fn exists(self: CacheInterface, key: []const u8) bool;
    pub fn flush(self: CacheInterface) !void;
    pub fn stats(self: CacheInterface) CacheStats;
    pub fn cleanupExpired(self: CacheInterface) !void;
    pub fn delByPrefix(self: CacheInterface, prefix: []const u8) !void;
    pub fn deinit(self: CacheInterface) void;
};
```

### 5. ORM 模型增强

```zig
//! ORM 模型定义 - Laravel Eloquent 风格
pub fn define(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Model = T;
        
        // 默认数据库连接
        var default_db: ?*Database = null;
        
        /// 设置默认数据库连接 (Laravel 风格)
        /// 使用: Product.use(&db);
        pub fn use(db: *Database) void;
        
        /// 获取默认数据库
        pub fn getDb() *Database;
        
        /// 创建查询构建器 (无需传 db)
        /// 使用: Product.where("name", "=", "test").get()
        pub fn where(field: []const u8, op: []const u8, value: anytype) QueryBuilder;
        
        /// 查找单条记录
        /// 使用: Product.find(1)
        pub fn find(id: anytype) !?T;
        
        /// 创建记录
        /// 使用: Product.create(.{ .name = "test" })
        pub fn create(data: anytype) !T;
        
        /// 获取所有记录
        /// 使用: Product.all()
        pub fn all() ![]T;
        
        /// 带自动内存管理的查询
        /// 使用: var list = try Product.collect(); defer list.deinit();
        pub fn collect() !List;
        
        /// 模型列表包装器
        pub const List = struct {
            allocator: Allocator,
            data: []T,
            
            pub fn items(self: *const List) []T;
            pub fn first(self: *const List) ?T;
            pub fn count(self: *const List) usize;
            pub fn deinit(self: *List) void;
        };
        
        /// 释放模型内存
        pub fn freeModel(allocator: Allocator, model: *T) void;
        pub fn freeModels(allocator: Allocator, models: []T) void;
    };
}
```


### 6. 命令行工具架构

```
commands/
├── mod.zig              # 命令模块入口
├── base.zig             # 命令基类
├── codegen.zig          # 代码生成命令
├── migrate.zig          # 数据库迁移命令
├── plugin_gen.zig       # 插件生成命令
└── config_gen.zig       # 配置生成命令
```

```zig
//! 命令基类
pub const Command = struct {
    name: []const u8,
    description: []const u8,
    
    /// 执行命令
    pub fn execute(self: *Command, args: []const []const u8) !void;
    
    /// 显示帮助
    pub fn showHelp(self: *Command) void;
    
    /// 解析参数
    pub fn parseArgs(self: *Command, args: []const []const u8) !CommandArgs;
};

//! 代码生成命令
pub const CodegenCommand = struct {
    base: Command,
    
    /// 生成模型
    pub fn generateModel(self: *CodegenCommand, name: []const u8) !void;
    
    /// 生成控制器
    pub fn generateController(self: *CodegenCommand, name: []const u8) !void;
    
    /// 生成 DTO
    pub fn generateDto(self: *CodegenCommand, name: []const u8) !void;
    
    /// 生成全部
    pub fn generateAll(self: *CodegenCommand, name: []const u8) !void;
};
```

## Data Models

### SystemConfig 结构

```zig
/// 系统主配置 - 对应 configs/ 目录下的 TOML 文件
pub const SystemConfig = struct {
    /// API 层配置 (api.toml)
    api: ApiConfig = .{},
    
    /// 应用层配置 (app.toml)
    app: AppConfig = .{},
    
    /// 领域层配置 (domain.toml)
    domain: DomainConfig = .{},
    
    /// 基础设施层配置 (infra.toml)
    infra: InfraConfig = .{},
};

/// API 配置
pub const ApiConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 8080,
    public_folder: []const u8 = "resources",
    max_clients: u32 = 10000,
    timeout: u32 = 30,
};

/// 应用配置
pub const AppConfig = struct {
    enable_cache: bool = true,
    cache_ttl_seconds: u64 = 3600,
    max_concurrent_tasks: u32 = 100,
    enable_plugins: bool = true,
    plugin_directory: []const u8 = "plugins",
};

/// 领域配置
pub const DomainConfig = struct {
    validate_models: bool = true,
    enforce_business_rules: bool = true,
};

/// 基础设施配置
pub const InfraConfig = struct {
    // 数据库配置
    db_driver: []const u8 = "sqlite",
    db_host: []const u8 = "localhost",
    db_port: u16 = 3306,
    db_name: []const u8 = "zigcms",
    db_user: []const u8 = "root",
    db_password: []const u8 = "",
    
    // 缓存配置
    cache_enabled: bool = true,
    cache_backend: []const u8 = "memory",
    cache_ttl: u64 = 3600,
};
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Memory Lifecycle Consistency

*For any* service that is initialized and then deinitialized, the GPA allocator SHALL report no memory leaks and no double-free attempts.

**Validates: Requirements 1.1, 1.2, 1.7**

### Property 2: Connection Pool Lifecycle

*For any* connection acquired from the pool, when released back to the pool, the connection SHALL be either reusable or properly destroyed if broken.

**Validates: Requirements 1.5**

### Property 3: QueryBuilder Fluent Chaining

*For any* sequence of QueryBuilder method calls (where, orderBy, limit, etc.), the generated SQL SHALL be syntactically valid and semantically equivalent to the chained operations.

**Validates: Requirements 4.1**

### Property 4: Model CRUD Operations

*For any* model instance, the operations create, find, update, and delete SHALL correctly persist and retrieve data from the database.

**Validates: Requirements 4.5, 4.6**

### Property 5: Model Memory Cleanup

*For any* model query result, calling freeModels SHALL release all allocated string memory without double-free or use-after-free.

**Validates: Requirements 4.8**

### Property 6: Cache Contract Conformance

*For any* cache implementation that conforms to CacheInterface, all interface methods SHALL behave consistently regardless of the underlying backend.

**Validates: Requirements 5.2**

### Property 7: Cache TTL Behavior

*For any* cached item with a TTL, after the TTL expires, the item SHALL NOT be returned by get() and SHALL be removed on access or cleanup.

**Validates: Requirements 5.3, 5.4**

### Property 8: Cache Typed Operations

*For any* typed value stored in cache via JSON serialization, deserializing the cached value SHALL produce an equivalent value.

**Validates: Requirements 5.5**

### Property 9: Cache Thread Safety

*For any* concurrent cache operations from multiple threads, the cache state SHALL remain consistent without data corruption.

**Validates: Requirements 5.7**

### Property 10: Config TOML Parsing

*For any* valid TOML configuration file, parsing and then serializing back to TOML SHALL produce an equivalent configuration.

**Validates: Requirements 7.1**

### Property 11: Config Environment Override

*For any* configuration field with an environment variable override, the environment variable value SHALL take precedence over the file value.

**Validates: Requirements 7.5**


## Error Handling

### 错误类型层次

```zig
/// 内存错误
pub const MemoryError = error{
    OutOfMemory,
    DoubleFree,
    UseAfterFree,
    LeakDetected,
};

/// 配置错误
pub const ConfigError = error{
    FileNotFound,
    ParseError,
    ValidationError,
    MissingRequiredField,
    InvalidValue,
};

/// 数据库错误
pub const DatabaseError = error{
    ConnectionFailed,
    ConnectionLost,
    QueryFailed,
    TransactionFailed,
    PoolExhausted,
};

/// 缓存错误
pub const CacheError = error{
    SetFailed,
    GetFailed,
    SerializationFailed,
    DeserializationFailed,
};

/// 命令错误
pub const CommandError = error{
    InvalidArgument,
    MissingArgument,
    ExecutionFailed,
    TemplateNotFound,
};
```

### 错误处理策略

1. **内存错误**: 使用 GPA 检测，在测试中断言无泄漏
2. **配置错误**: 提供详细错误信息，包括文件名和行号
3. **数据库错误**: 支持重试机制，记录详细日志
4. **缓存错误**: 降级处理，缓存失败不影响主流程
5. **命令错误**: 显示帮助信息和建议修复方案

## Testing Strategy

### 测试框架

- **单元测试**: Zig 内置测试框架
- **属性测试**: 自定义属性测试框架（基于随机输入）
- **集成测试**: 使用 SQLite 内存数据库

### 测试覆盖要求

| 模块 | 最低覆盖率 | 测试类型 |
|------|-----------|---------|
| ORM | 90% | 单元 + 属性 + 集成 |
| Cache | 85% | 单元 + 属性 |
| Config | 80% | 单元 + 属性 |
| Commands | 75% | 单元 + 集成 |
| Memory | 95% | 属性 |

### 属性测试配置

```zig
const PropertyTestConfig = struct {
    iterations: usize = 100,
    seed: ?u64 = null,
    shrink_attempts: usize = 100,
};
```

### 测试文件组织

```
tests/
├── unit/
│   ├── orm_test.zig
│   ├── cache_test.zig
│   ├── config_test.zig
│   └── memory_test.zig
├── property/
│   ├── orm_property_test.zig
│   ├── cache_property_test.zig
│   └── config_property_test.zig
└── integration/
    ├── system_test.zig
    ├── api_test.zig
    └── database_test.zig
```

### 内存安全测试

```zig
test "memory safety - no leaks after service lifecycle" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        try std.testing.expect(status != .leak);
    }
    
    const allocator = gpa.allocator();
    
    // 初始化服务
    var service = try ServiceManager.init(allocator);
    
    // 执行操作
    try service.doSomething();
    
    // 清理
    service.deinit();
}
```

### ORM 属性测试

```zig
test "property: QueryBuilder fluent chaining produces valid SQL" {
    // Feature: zigcms-refactoring, Property 3: QueryBuilder Fluent Chaining
    // Validates: Requirements 4.1
    
    var prng = std.rand.DefaultPrng.init(0);
    const random = prng.random();
    
    for (0..100) |_| {
        // 生成随机查询参数
        const field = randomField(random);
        const op = randomOp(random);
        const value = randomValue(random);
        const limit = random.intRangeAtMost(u32, 1, 100);
        
        // 构建查询
        var builder = QueryBuilder(TestModel).init(allocator, "test_table");
        defer builder.deinit();
        
        _ = builder.where(field, op, value).limit(limit);
        
        // 验证生成的 SQL 是有效的
        const sql = try builder.toSql();
        defer allocator.free(sql);
        
        try std.testing.expect(isValidSql(sql));
    }
}
```

### 缓存属性测试

```zig
test "property: Cache TTL expiration" {
    // Feature: zigcms-refactoring, Property 7: Cache TTL Behavior
    // Validates: Requirements 5.3, 5.4
    
    var cache = CacheService.init(allocator);
    defer cache.deinit();
    
    for (0..100) |i| {
        const key = try std.fmt.allocPrint(allocator, "key_{d}", .{i});
        defer allocator.free(key);
        
        // 设置 0 秒 TTL（立即过期）
        try cache.set(key, "value", 0);
        
        // 验证过期后无法获取
        const result = cache.get(key);
        try std.testing.expect(result == null);
    }
}
```

## Implementation Notes

### 实现顺序

1. **步骤 1**: 内存安全分析与优化
   - 审查所有 allocator 使用
   - 添加 defer/errdefer 确保清理
   - 使用 GPA 测试检测泄漏

2. **步骤 2**: Main.zig 结构优化
   - 创建 Bootstrap 模块
   - 提取路由注册逻辑
   - 简化 main 函数

3. **步骤 3**: 项目结构工程化
   - 整理目录结构
   - 完善 mod.zig 导出
   - 添加库构建目标

4. **步骤 4**: ORM/QueryBuilder 优化
   - 实现 use() 默认连接
   - 添加 Laravel 风格 API
   - 完善内存管理

5. **步骤 5**: 缓存契约统一
   - 完善 CacheInterface
   - 实现多后端支持
   - 添加类型化缓存

6. **步骤 6**: 命令行工具优化
   - 创建 commands/ 目录
   - 重构现有工具
   - 添加帮助系统

7. **步骤 7**: 配置加载优化
   - 实现 TOML 解析
   - 文件名对应结构体
   - 环境变量覆盖

8. **步骤 8**: 脚本优化
   - 简化脚本逻辑
   - 统一错误处理
   - 添加帮助信息

9. **步骤 9**: 编译测试
   - 运行所有测试
   - 验证覆盖率
   - 修复发现的问题

10. **步骤 10**: 代码注释
    - 添加模块文档
    - 添加函数文档
    - 添加内联注释

11. **步骤 11**: Git 提交
    - 每步完成后提交
    - 中文提交信息
    - 引用需求编号

### 关键技术决策

1. **内存管理**: 使用 GPA 的线程安全模式，所有服务通过 ServiceManager 统一管理生命周期
2. **配置格式**: 使用 TOML 格式，因为它比 JSON 更易读，比 YAML 更简单
3. **缓存接口**: 使用 vtable 模式实现多态，避免运行时类型检查
4. **ORM 风格**: 借鉴 Laravel Eloquent 的 API 设计，但保持 Zig 的显式内存管理
5. **命令行**: 使用简单的参数解析，不引入外部依赖
