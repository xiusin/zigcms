# Implementation Plan

## 1. Memory Safety Fixes

- [x] 1.1 Fix ModelQuery memory management
  - Review and fix deinit() to properly free all allocated clause strings
  - Ensure where_clauses, order_clauses, join_clauses are all freed
  - Add errdefer for partial initialization cleanup
  - _Requirements: 1.1, 1.5_

- [ ]* 1.2 Write property test for ModelQuery memory safety
  - **Property 1: ModelQuery Memory Safety**
  - **Validates: Requirements 1.1**

- [x] 1.3 Fix CacheService key-value memory management
  - Ensure both key and value are duplicated on set()
  - Fix deinit() to free both keys and values
  - Add proper cleanup in del() and delByPrefix()
  - _Requirements: 1.3_

- [ ]* 1.4 Write property test for Cache key-value independence
  - **Property 3: Cache Key-Value Independence**
  - **Validates: Requirements 1.3**

- [x] 1.5 Fix App controller registry cleanup
  - Ensure all controller pointers are tracked
  - Implement proper deinit() to free all controllers
  - _Requirements: 1.6_

- [ ]* 1.6 Write property test for controller registry cleanup
  - **Property 4: Controller Registry Cleanup**
  - **Validates: Requirements 1.6**

- [x] 1.7 Verify global module cleanup order
  - Review deinit() order: plugins → services → database → logger → config
  - Add null checks before cleanup
  - _Requirements: 1.4_

- [x] 2. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## 2. ORM Functionality Optimization

- [x] 2.1 Implement Model List wrapper with automatic cleanup
  - Create List struct with items(), first(), last(), count() methods
  - Implement deinit() for automatic memory cleanup
  - Add collect() method to return List instead of raw slice
  - _Requirements: 3.2, 3.3_

- [ ]* 2.2 Write property test for Model List memory management
  - **Property 2: Model List Memory Management**
  - **Validates: Requirements 1.2, 3.2, 3.3**

- [x] 2.3 Enhance SQL escaping for injection prevention
  - Review appendValue() function for proper escaping
  - Escape single quotes, backslashes, and other special characters
  - _Requirements: 3.4_

- [ ]* 2.4 Write property test for SQL injection prevention
  - **Property 5: SQL Injection Prevention**
  - **Validates: Requirements 3.4**

- [x] 2.5 Implement transaction auto-rollback
  - Review transaction() method for proper error handling
  - Ensure rollback is called on any error within transaction
  - _Requirements: 3.5_

- [ ]* 2.6 Write property test for transaction rollback
  - **Property 6: Transaction Rollback on Error**
  - **Validates: Requirements 3.5**

- [x] 2.7 Implement connection pool retry logic
  - Add retry mechanism for transient connection failures
  - Configure max retry count and backoff strategy
  - _Requirements: 3.6_

- [ ]* 2.8 Write property test for connection pool retry
  - **Property 7: Connection Pool Retry**
  - **Validates: Requirements 3.6**

- [x] 2.9 Verify model serialization/deserialization
  - Review buildInsertSql() and buildUpdateSql() for all types
  - Review mapResults() for proper type parsing
  - Handle NULL values correctly
  - _Requirements: 3.7, 3.8, 6.1, 6.2, 6.3, 6.5_

- [ ]* 2.10 Write property test for serialization round-trip
  - **Property 8: Model Serialization Round-Trip**
  - **Validates: Requirements 3.7, 3.8, 6.1, 6.2, 6.3, 6.4**

- [ ] 3. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## 3. Services Module Optimization

- [x] 3.1 Verify CacheService thread safety
  - Review mutex usage in all public methods
  - Ensure lock is held during entire operation
  - _Requirements: 4.1_

- [ ]* 3.2 Write property test for cache thread safety
  - **Property 9: Cache Thread Safety**
  - **Validates: Requirements 4.1**

- [x] 3.3 Implement cache expiration cleanup
  - Review cleanupExpired() implementation
  - Ensure proper memory cleanup for expired items
  - _Requirements: 4.2_

- [ ]* 3.4 Write property test for cache expiration
  - **Property 10: Cache Expiration Cleanup**
  - **Validates: Requirements 4.2**

- [x] 3.5 Verify ServiceManager initialization order
  - Review init() for correct dependency order
  - Review deinit() for reverse order cleanup
  - _Requirements: 4.3, 4.4_

- [x] 3.6 Optimize DictService caching
  - Implement query result caching
  - Add cache invalidation on data changes
  - _Requirements: 4.5_

- [ ] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## 4. Dynamic CRUD Implementation

- [x] 4.1 Create DynamicModel data structure
  - Implement FieldValue union type
  - Implement ColumnInfo and TableSchema structs
  - Implement init(), deinit(), set(), get() methods
  - _Requirements: 5.2_

- [x] 4.2 Implement schema discovery
  - Query INFORMATION_SCHEMA for MySQL
  - Query sqlite_master for SQLite
  - Cache discovered schemas
  - _Requirements: 5.1_

- [ ]* 4.3 Write property test for schema discovery
  - **Property 11: Dynamic Schema Discovery**
  - **Validates: Requirements 5.1**

- [x] 4.4 Implement dynamic SELECT operation
  - Build SELECT SQL from table name and schema
  - Return DynamicResultSet with proper memory management
  - Support pagination and ordering
  - _Requirements: 5.3_

- [x] 4.5 Implement dynamic INSERT operation
  - Accept field map and generate INSERT SQL
  - Validate field names against schema
  - Return inserted ID
  - _Requirements: 5.4_

- [x] 4.6 Implement dynamic UPDATE operation
  - Accept ID and field map
  - Generate UPDATE SQL with proper escaping
  - Return affected row count
  - _Requirements: 5.5_

- [x] 4.7 Implement dynamic DELETE operation
  - Accept single ID or array of IDs
  - Generate DELETE SQL
  - Return affected row count
  - _Requirements: 5.6_

- [ ]* 4.8 Write property test for dynamic CRUD operations
  - **Property 12: Dynamic CRUD Operations**
  - **Validates: Requirements 5.3, 5.4, 5.5, 5.6**

- [x] 4.9 Implement field validation
  - Check field names against discovered schema
  - Reject invalid field names
  - _Requirements: 5.7_

- [ ]* 4.10 Write property test for field validation
  - **Property 13: Dynamic Field Validation**
  - **Validates: Requirements 5.7**

- [x] 4.11 Implement type inference from database metadata
  - Map SQL types to Zig types
  - Format values according to inferred types
  - _Requirements: 5.8_

- [ ]* 4.12 Write property test for NULL value handling
  - **Property 14: NULL Value Handling**
  - **Validates: Requirements 6.5**

- [ ] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## 5. Integration and DynamicCrud Controller

- [x] 5.1 Create DynamicCrud controller
  - Implement list(), get(), save(), delete() endpoints
  - Accept table name as URL parameter
  - Use DynamicModel for all operations
  - _Requirements: 5.1-5.8_

- [x] 5.2 Register DynamicCrud routes in App
  - Add /dynamic/:table/list endpoint
  - Add /dynamic/:table/get endpoint
  - Add /dynamic/:table/save endpoint
  - Add /dynamic/:table/delete endpoint
  - _Requirements: 5.1-5.8_

- [x] 5.3 Add table name whitelist for security
  - Configure allowed table names
  - Reject requests for non-whitelisted tables
  - _Requirements: 5.7_

- [ ] 6. Final Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
