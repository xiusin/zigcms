# ZigCMS Context

## Project Overview
**ZigCMS** is a high-performance, memory-safe, and extensible Content Management System built with the Zig programming language (v0.15.0+).

It is designed using **Clean Architecture** (Hexagonal/Ports & Adapters) principles to ensure scalability and maintainability.

## Architecture
The project follows a strict layered architecture:

*   **API Layer** (`api/`): Handles HTTP requests/responses, Controllers, DTOs, and Middleware. Depends only on Application.
*   **Application Layer** (`application/`): Business logic orchestration, Use Cases, and Application Services. Depends only on Domain.
*   **Domain Layer** (`domain/`): Core business logic, Entities, Value Objects, and Repository Interfaces. **Inner-most layer, no external dependencies.**
*   **Infrastructure Layer** (`infrastructure/`): Implementations of external interfaces (Database, Cache, HTTP Clients). Depends on Domain.
*   **Shared Layer** (`shared/`): Common utilities, primitives, and types used across layers.

## Key Technologies & Dependencies
*   **Language**: Zig (>= 0.15.0)
*   **Web Server**: `zap` (based on Facil.io)
*   **Database**: SQLite (embedded), MySQL/PostgreSQL (optional via drivers)
*   **ORM/Query Builder**: Custom implementation in `infrastructure/database`
*   **Build System**: `zig build`
*   **Dependencies**: Defined in `build.zig.zon` (zap, pg, sqlite, regex, pretty, curl, smtp_client, dotenv)

## Development Workflow

### Build & Run
*   **Build Project**: `zig build`
*   **Run Dev Server**: `zig build run` (or `make dev`)
*   **Run Production**: `zig build -Doptimize=ReleaseSafe run`
*   **Clean Build**: `zig build clean` (or `make clean`)

### Testing
*   **Run All Tests**: `zig build test`
*   **Unit Tests Only**: `zig build test-unit`
*   **Integration Tests**: `zig build test-integration`
*   **Property Tests**: `zig build test-property`

### Database Management
*   **Run Migrations**: `zig build migrate -- up`
*   **Rollback**: `zig build migrate -- down`
*   **Status**: `zig build migrate -- status`

### Code Generation
*   **Generate Code**: `zig build codegen` (Models, Controllers, DTOs)
*   **Generate Plugin**: `zig build plugin-gen`
*   **Generate Config**: `zig build config-gen`

## Coding Conventions & Guidelines
**Strictly adhere to `DEVELOPMENT_SPEC.md`.**

*   **File Naming**: `snake_case.zig`.
    *   Controllers: `user.controller.zig`
    *   DTOs: `user_create.dto.zig`
*   **Type Naming**: `PascalCase` (e.g., `UserController`, `UserError`).
*   **Variable/Function Naming**: `camelCase` (e.g., `createUser`, `userId`).
*   **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `MAX_RETRY_COUNT`).
*   **Modules**: Use `mod.zig` for folder-level exports.
*   **Memory Management**:
    *   Prefer **Arena Allocators** for request-scoped data.
    *   Use **RAII** patterns (`init`/`deinit`) for resources.
*   **Error Handling**:
    *   Define explicit error sets (e.g., `UserError`).
    *   Map domain errors to HTTP status codes in the API layer.

## Directory Structure
```
/Users/tuoke/products/zigcms/
├── api/                # Controllers, DTOs, Middleware
├── application/        # Use Cases, Services
├── domain/             # Entities, Repositories (Interfaces)
├── infrastructure/     # DB Implementations, Cache, External APIs
├── shared/             # Utilities, Common Types
├── commands/           # CLI Tools (codegen, migrate)
├── build.zig           # Build configuration
├── build.zig.zon       # Dependency configuration
└── Makefile            # Convenience commands
```

## Current Objectives (Refactoring & Improvements)
The following tasks are prioritized for improvement:
1.  **Memory Safety Analysis**: Audit services for leaks/double-frees.
2.  **MVC Refactoring**: Ensure `main.zig` is clean; strict separation of duties.
3.  **Module Organization**: Ensure "clean architecture" is respected and folders are organized for reusability.
4.  **ORM/QueryBuilder Polish**: Enhance syntax sugar to resemble Laravel's Eloquent.
5.  **Caching Strategy**: Unify caching contracts across service layers.
6.  **CLI Tooling**: Organize commands into a dedicated `commands/` directory structure (Already mostly done, verify implementation).
7.  **Configuration**: Implement file-based config loading mapping to `SystemConfig` structs.
8.  **Script Optimization**: Simplify `scripts/` folder.
9.  **Compilation & Testing**: Ensure comprehensive test coverage and unified compilation.
10. **Documentation**: Add rich comments for maintainability.
