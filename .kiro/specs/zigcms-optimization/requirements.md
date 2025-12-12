# Requirements Document

## Introduction

本文档定义了 ZigCMS 项目的全面优化需求，涵盖内存安全、项目工程化、ORM 优化、服务模块优化以及动态 CRUD 功能增强。ZigCMS 是一个基于 Zig 语言的内容管理系统，采用整洁架构（Clean Architecture）模式，包含 API 层、应用层、领域层、基础设施层和共享层。

## Glossary

- **ZigCMS**: 基于 Zig 语言的内容管理系统
- **ORM**: Object-Relational Mapping，对象关系映射
- **CRUD**: Create, Read, Update, Delete 基本数据操作
- **Allocator**: Zig 语言中的内存分配器
- **Arena Allocator**: 批量分配内存的分配器，一次性释放所有内存
- **Connection Pool**: 数据库连接池
- **ModelQuery**: ORM 中的模型查询构建器
- **errdefer**: Zig 语言中错误发生时执行的延迟释放机制
- **defer**: Zig 语言中的延迟执行机制
- **Dynamic Model**: 运行时动态构建的数据模型

## Requirements

### Requirement 1: Memory Safety Audit and Fix

**User Story:** As a system administrator, I want the system to be free of memory leaks, so that the application can run stably for extended periods without resource exhaustion.

#### Acceptance Criteria

1. WHEN the ORM ModelQuery is used THEN the System SHALL ensure all allocated where_clauses, order_clauses, and join_clauses are properly freed in deinit()
2. WHEN a database query returns results THEN the System SHALL provide clear ownership semantics for result memory and document the caller's responsibility to free it
3. WHEN the CacheService stores a key-value pair THEN the System SHALL properly duplicate and manage both key and value memory independently
4. WHEN the global module deinit() is called THEN the System SHALL release all resources in reverse initialization order (plugins → services → database → logger → config)
5. WHEN an error occurs during initialization THEN the System SHALL use errdefer to clean up partially initialized resources
6. WHEN the App controller registry creates controllers THEN the System SHALL track all controller pointers and free them in deinit()

### Requirement 2: Enterprise Project Structure

**User Story:** As a development team lead, I want the project to follow enterprise-grade organization patterns, so that the codebase is maintainable and scalable.

#### Acceptance Criteria

1. WHEN organizing the project THEN the System SHALL maintain clear separation between api/, application/, domain/, infrastructure/, and shared/ layers
2. WHEN adding new modules THEN the System SHALL use mod.zig as the standard module entry point
3. WHEN defining dependencies THEN the System SHALL ensure outer layers depend on inner layers only (API → Application → Domain)
4. WHEN creating configuration THEN the System SHALL support environment-based configuration (development, production, test)
5. WHEN implementing error handling THEN the System SHALL define layer-specific error types that propagate outward
6. WHEN logging operations THEN the System SHALL use structured logging with consistent format across all modules

### Requirement 3: ORM Functionality Optimization

**User Story:** As a developer, I want the ORM to be easy to use with automatic memory management, so that I can write database code without worrying about memory leaks.

#### Acceptance Criteria

1. WHEN using ModelQuery THEN the System SHALL provide a fluent API that returns *Self for method chaining
2. WHEN a query result is returned THEN the System SHALL provide a List wrapper type with automatic memory cleanup via deinit()
3. WHEN creating a model instance THEN the System SHALL provide freeModel() and freeModels() helper functions for explicit cleanup
4. WHEN building SQL queries THEN the System SHALL escape special characters to prevent SQL injection
5. WHEN using transactions THEN the System SHALL provide automatic rollback on error via transaction() method
6. WHEN the connection pool acquires a connection THEN the System SHALL implement retry logic for transient connection failures
7. WHEN serializing model data to SQL THEN the System SHALL handle all Zig types (strings, integers, floats, booleans, optionals) correctly
8. WHEN deserializing SQL results to models THEN the System SHALL parse all field types and handle NULL values appropriately

### Requirement 4: Services Module Optimization

**User Story:** As a developer, I want the services module to be performant and well-organized, so that business logic executes efficiently.

#### Acceptance Criteria

1. WHEN the CacheService performs operations THEN the System SHALL use mutex locking for thread-safe access
2. WHEN cache items expire THEN the System SHALL provide cleanupExpired() method for batch removal of stale entries
3. WHEN the ServiceManager initializes THEN the System SHALL create services in dependency order (cache → dict → plugins)
4. WHEN the ServiceManager deinitializes THEN the System SHALL shutdown services in reverse order
5. WHEN the DictService queries dictionary data THEN the System SHALL cache results to avoid repeated database queries
6. WHEN the PluginSystem loads plugins THEN the System SHALL validate plugin interfaces before registration

### Requirement 5: Dynamic CRUD with Arbitrary Table Names

**User Story:** As a developer, I want to perform CRUD operations on any database table by name, so that I can build flexible admin interfaces without compile-time model definitions.

#### Acceptance Criteria

1. WHEN a table name is provided at runtime THEN the System SHALL query the database schema to discover column names and types
2. WHEN building a dynamic model THEN the System SHALL create a runtime representation that maps column names to values
3. WHEN performing dynamic SELECT THEN the System SHALL return results as a generic row structure with named fields
4. WHEN performing dynamic INSERT THEN the System SHALL accept a map of field names to values and generate appropriate SQL
5. WHEN performing dynamic UPDATE THEN the System SHALL accept an ID and a map of field names to values
6. WHEN performing dynamic DELETE THEN the System SHALL accept an ID or a list of IDs for batch deletion
7. WHEN validating dynamic field names THEN the System SHALL check against the discovered schema to prevent SQL injection
8. WHEN handling dynamic field types THEN the System SHALL infer types from database metadata and format values accordingly

### Requirement 6: ORM Pretty Printer and Round-Trip Validation

**User Story:** As a developer, I want to serialize and deserialize model data reliably, so that data integrity is maintained across operations.

#### Acceptance Criteria

1. WHEN a model is serialized to SQL INSERT THEN the System SHALL generate valid SQL syntax for all field types
2. WHEN a model is serialized to SQL UPDATE THEN the System SHALL generate valid SET clauses with proper escaping
3. WHEN SQL results are parsed into models THEN the System SHALL correctly map column values to struct fields
4. WHEN a model is serialized and then deserialized THEN the System SHALL produce an equivalent model (round-trip consistency)
5. WHEN NULL values are encountered THEN the System SHALL map them to Zig optional types correctly
