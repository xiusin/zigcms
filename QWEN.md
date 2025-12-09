# ZigCMS Project Context

## Overview
ZigCMS is a high-performance Content Management System built with Zig language. It features a modular architecture with built-in HTTP server, ORM, caching services, and supports PostgreSQL, MySQL, and SQLite databases. The system includes a complete admin panel based on LayUI framework and automatically generates RESTful CRUD APIs.

## Key Components
- **Language**: Zig (requires 0.15.0+)
- **HTTP Framework**: Zap
- **Database Support**: PostgreSQL, MySQL, SQLite via custom ORM
- **Architecture**: Model-View-Controller with service container and dependency injection
- **Frontend**: LayUI-based admin interface in `resources/` directory

## Project Structure
```
zigcms/
├── build.zig          # Build configuration with dependencies
├── build.zig.zon      # Dependency manifest
├── src/               # Source code
│   ├── app.zig        # Application framework core
│   ├── main.zig       # Entry point with route registration
│   ├── controllers/   # MVC controllers
│   ├── models/        # Data models (e.g., admin, article, category)
│   └── ...            # Other modules (middleware, services, etc.)
├── resources/         # Frontend assets (HTML, CSS, JS)
├── docs/              # Documentation
└── ...
```

## Building and Running
- **Development**: `zig build run`
- **Production**: `zig build -Doptimize=ReleaseSafe run`
- **Tests**: `zig build test`

## Core Features
- Automatic CRUD controller generation for models via `app.crud()` in `src/main.zig`
- Service container with dependency injection
- Multi-database support with connection pooling
- Built-in authentication and admin panel
- Modular architecture with clear separation of concerns

## Development Notes
- Models are defined in `src/models/` with corresponding auto-generated routes
- Controllers handle business logic and register custom routes in `src/main.zig`
- Frontend resources are in `resources/` directory with LayUI-based templates
- Configuration can be managed via `.env` file
- Tests for different database drivers are available in `src/services/sql/`