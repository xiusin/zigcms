# Requirements Document

## Introduction

本文档定义了 ZigCMS 项目全面优化重构的需求规范。ZigCMS 是一个基于 Zig 语言开发的现代化 CMS 系统，采用整洁架构（Clean Architecture）模式。本次重构旨在解决内存安全、代码组织、缓存契约统一、命令行工具优化、配置加载等多个方面的问题，确保系统更加健壮、优雅和可维护。

## Glossary

- **ZigCMS**: 基于 Zig 语言的内容管理系统
- **Allocator**: Zig 语言中的内存分配器，负责内存的分配和释放
- **GPA**: GeneralPurposeAllocator，Zig 的通用内存分配器，支持内存泄漏检测
- **ORM**: Object-Relational Mapping，对象关系映射
- **QueryBuilder**: SQL 查询构建器，用于构建类型安全的 SQL 查询
- **Cache_Contract**: 缓存服务的统一接口契约
- **Service_Manager**: 服务管理器，负责管理应用程序中的各种服务实例
- **Clean_Architecture**: 整洁架构，一种软件架构模式，强调关注点分离
- **Memory_Safety**: 内存安全，确保程序不会出现内存泄漏、重复释放等问题
- **Command_Module**: 命令行工具模块，包含代码生成、数据库迁移等工具
- **System_Config**: 系统配置结构体，用于加载和管理配置文件

## Requirements

### Requirement 1: 内存安全分析与优化

**User Story:** As a developer, I want to ensure the system has no memory leaks, double-free issues, or memory safety problems, so that the application runs reliably in production.

#### Acceptance Criteria

1. WHEN the system initializes services THEN the Memory_Manager SHALL track all allocated resources with clear ownership
2. WHEN a service is deinitialized THEN the Memory_Manager SHALL release all owned resources exactly once
3. WHEN the GPA detects memory leaks on shutdown THEN the System SHALL log detailed leak information for debugging
4. IF a double-free attempt occurs THEN the Memory_Manager SHALL prevent the operation and log a warning
5. WHEN using connection pools THEN the Pool_Manager SHALL properly track connection lifecycle and cleanup
6. WHEN database queries return results THEN the ORM SHALL clearly document memory ownership for returned data
7. FOR ALL allocated strings in model results THEN the Model SHALL provide a freeModel/freeModels helper function

### Requirement 2: Main.zig 结构优化

**User Story:** As a developer, I want main.zig to be clean, elegant, and have clear responsibilities, so that the application entry point is easy to understand and maintain.

#### Acceptance Criteria

1. THE main.zig SHALL contain only high-level initialization and startup logic
2. WHEN registering routes THEN the Router_Registry SHALL use a declarative configuration approach
3. THE main.zig SHALL delegate detailed initialization to dedicated bootstrap modules
4. WHEN initializing the system THEN the Bootstrap_Module SHALL handle layer initialization in correct dependency order
5. THE main.zig SHALL NOT contain inline controller instantiation code exceeding 5 lines per controller
6. WHEN the server starts THEN the main.zig SHALL log a clear startup summary with configuration details

### Requirement 3: 项目结构工程化

**User Story:** As a developer, I want the project structure to be well-organized, reusable, and suitable for external distribution, so that the codebase is maintainable and can be used as a library.

#### Acceptance Criteria

1. THE Project_Structure SHALL follow the established Clean Architecture layers (api, application, domain, infrastructure, shared)
2. WHEN a module is imported THEN the Module SHALL expose a clear public API through mod.zig
3. THE shared layer SHALL NOT depend on any business layer
4. WHEN building the project THEN the Build_System SHALL produce both executable and library artifacts
5. THE Project SHALL provide clear documentation for each layer's responsibilities
6. WHEN adding new features THEN the Developer SHALL be able to locate the correct directory within 30 seconds

### Requirement 4: ORM/QueryBuilder 语法糖优化

**User Story:** As a developer, I want the ORM to be as elegant and easy to use as Laravel's Eloquent, so that database operations are intuitive and productive.

#### Acceptance Criteria

1. WHEN querying models THEN the QueryBuilder SHALL support fluent chaining syntax like `.where().orderBy().limit().get()`
2. THE Model SHALL support a static `use(db)` method to set default database connection
3. WHEN using default connection THEN the Model SHALL allow queries without passing db parameter
4. THE QueryBuilder SHALL support Laravel-style scope methods for common query patterns
5. WHEN creating records THEN the Model SHALL support `Model.create(db, data)` syntax
6. WHEN finding by ID THEN the Model SHALL support `Model.find(db, id)` syntax
7. THE ORM SHALL provide clear memory ownership documentation for all returned data
8. FOR ALL query results THEN the Model SHALL provide automatic memory cleanup helpers

### Requirement 5: 缓存服务统一契约

**User Story:** As a developer, I want all cache services to follow a unified contract, so that cache usage is consistent and interchangeable across the system.

#### Acceptance Criteria

1. THE Cache_Contract SHALL define standard methods: set, get, del, exists, flush, stats, cleanupExpired, delByPrefix
2. WHEN implementing a cache backend THEN the Implementation SHALL conform to Cache_Contract interface
3. THE Cache_Service SHALL support TTL (time-to-live) for all cached items
4. WHEN cache items expire THEN the Cache_Service SHALL automatically remove them on access
5. THE Cache_Contract SHALL support typed cache operations with JSON serialization
6. WHEN switching cache backends THEN the Application SHALL NOT require code changes beyond configuration
7. THE Cache_Service SHALL provide thread-safe operations using mutex protection

### Requirement 6: 命令行工具优化

**User Story:** As a developer, I want command-line tools to be well-organized in a dedicated directory with clear responsibilities, so that tooling is discoverable and maintainable.

#### Acceptance Criteria

1. THE Command_Module SHALL be located in a dedicated `commands/` directory
2. WHEN running a command THEN the Command SHALL provide clear usage help with `--help` flag
3. THE codegen command SHALL generate model, controller, and DTO files from templates
4. THE migrate command SHALL support up, down, status, and create operations
5. THE plugin-gen command SHALL generate plugin scaffolding from templates
6. THE config-gen command SHALL generate configuration structures from .env files
7. WHEN a command fails THEN the Command SHALL provide clear error messages with suggested fixes
8. THE Build_System SHALL register all commands as separate build targets

### Requirement 7: 配置加载优化

**User Story:** As a developer, I want configuration loading to be file-based with each config file mapping to a corresponding struct, so that configuration is type-safe and organized.

#### Acceptance Criteria

1. WHEN loading configuration THEN the Config_Loader SHALL parse TOML files from the configs/ directory
2. THE System_Config SHALL contain nested structs matching config file names (api.toml → ApiConfig, app.toml → AppConfig)
3. WHEN a config file is missing THEN the Config_Loader SHALL use default values
4. WHEN a config value is invalid THEN the Config_Loader SHALL return a descriptive error
5. THE Config_Loader SHALL support environment variable overrides for sensitive values
6. WHEN the system starts THEN the Config_Loader SHALL validate all required configuration fields

### Requirement 8: 脚本优化

**User Story:** As a developer, I want build and development scripts to be simplified while maintaining full functionality, so that the development workflow is efficient.

#### Acceptance Criteria

1. THE scripts/ directory SHALL contain: build.sh, dev.sh, test.sh, setup.sh, clean.sh
2. WHEN running scripts THEN the Script SHALL source common.sh for shared utilities
3. THE build.sh SHALL support modes: debug, release, fast, small, clean, cross
4. THE dev.sh SHALL support hot-reload with file watching (when fswatch is available)
5. THE test.sh SHALL run unit tests, integration tests, and report coverage
6. WHEN a script fails THEN the Script SHALL provide clear error messages and exit codes
7. THE scripts SHALL be POSIX-compliant and work on macOS and Linux

### Requirement 9: 编译测试与覆盖

**User Story:** As a developer, I want comprehensive test coverage with automated testing, so that all functionality is verified and regressions are caught.

#### Acceptance Criteria

1. WHEN running `zig build test` THEN the Test_Suite SHALL execute all unit tests
2. THE Test_Suite SHALL include integration tests for database operations
3. WHEN tests complete THEN the Test_Runner SHALL report pass/fail counts and duration
4. THE ORM tests SHALL cover CRUD operations, transactions, and edge cases
5. THE Cache tests SHALL verify TTL expiration, cleanup, and thread safety
6. WHEN memory leaks are detected THEN the Test SHALL fail with detailed leak information
7. THE Test_Suite SHALL achieve minimum 80% code coverage for core modules

### Requirement 10: 代码注释规范

**User Story:** As a developer, I want comprehensive code comments, so that the codebase is easy to understand and maintain.

#### Acceptance Criteria

1. THE Source_File SHALL begin with a module-level doc comment explaining its purpose
2. WHEN defining a public function THEN the Function SHALL have a doc comment describing its behavior
3. THE doc comment SHALL include parameter descriptions for complex functions
4. WHEN a function can return errors THEN the Comment SHALL document possible error conditions
5. THE Comment SHALL use Chinese for user-facing documentation and English for technical details
6. WHEN implementing complex algorithms THEN the Code SHALL include inline comments explaining the logic
7. THE Comment SHALL follow Zig's `///` doc comment convention for public APIs

### Requirement 11: Git 提交规范

**User Story:** As a developer, I want each optimization step to be committed separately with clear Chinese descriptions, so that the change history is traceable.

#### Acceptance Criteria

1. WHEN completing a requirement THEN the Developer SHALL create a git commit
2. THE commit message SHALL be in Chinese describing the completed step
3. THE commit message SHALL reference the requirement number (e.g., "步骤1: 内存安全分析与优化")
4. THE commit SHALL NOT include push or reset operations
5. WHEN multiple files are changed THEN the Commit SHALL group related changes together
6. THE commit history SHALL show clear progression through the optimization steps
