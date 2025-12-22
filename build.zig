//! ZigCMS 构建配置
//!
//! 本文件定义了 ZigCMS 项目的构建配置，包括：
//! - 主可执行文件 (zigcms)
//! - 静态库 (libzigcms)
//! - 动态库 (libzigcms.so/dylib)
//! - 命令行工具 (codegen, migrate, plugin-gen, config-gen)
//! - 测试套件
//!
//! ## 构建目标
//! - `zig build` - 构建所有目标
//! - `zig build run` - 运行主程序
//! - `zig build test` - 运行测试
//! - `zig build lib` - 仅构建库
//! - `zig build codegen` - 运行代码生成工具
//! - `zig build migrate` - 运行数据库迁移工具

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ========================================================================
    // 依赖项
    // ========================================================================
    const zap = b.dependency("zap", .{ .target = target, .optimize = optimize });
    const regex = b.dependency("regex", .{ .target = target, .optimize = optimize });
    const pg = b.dependency("pg", .{ .target = target, .optimize = optimize });
    const pretty = b.dependency("pretty", .{ .target = target, .optimize = optimize });
    const sqlite = b.dependency("sqlite", .{ .target = target, .optimize = optimize });
    const curl = b.dependency("curl", .{ .target = target, .optimize = optimize });
    const smtp_client = b.dependency("smtp_client", .{ .target = target, .optimize = optimize });

    // ========================================================================
    // ZigCMS 核心库 (静态库)
    // ========================================================================
    const lib_module = b.createModule(.{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 为库模块添加依赖
    lib_module.addImport("zap", zap.module("zap"));
    lib_module.addImport("regex", regex.module("regex"));
    lib_module.addImport("pg", pg.module("pg"));
    lib_module.addImport("pretty", pretty.module("pretty"));
    lib_module.addImport("sqlite", sqlite.module("sqlite"));
    lib_module.addImport("curl", curl.module("curl"));
    lib_module.addImport("smtp_client", smtp_client.module("smtp_client"));

    const static_lib = b.addLibrary(.{
        .name = "zigcms",
        .root_module = lib_module,
        .linkage = .static,
    });
    static_lib.linkLibrary(sqlite.artifact("sqlite"));
    static_lib.linkLibC();
    b.installArtifact(static_lib);

    // ========================================================================
    // ZigCMS 核心库 (动态库)
    // ========================================================================
    const shared_lib_module = b.createModule(.{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 为动态库模块添加依赖
    shared_lib_module.addImport("zap", zap.module("zap"));
    shared_lib_module.addImport("regex", regex.module("regex"));
    shared_lib_module.addImport("pg", pg.module("pg"));
    shared_lib_module.addImport("pretty", pretty.module("pretty"));
    shared_lib_module.addImport("sqlite", sqlite.module("sqlite"));
    shared_lib_module.addImport("curl", curl.module("curl"));
    shared_lib_module.addImport("smtp_client", smtp_client.module("smtp_client"));

    const shared_lib = b.addLibrary(.{
        .name = "zigcms",
        .root_module = shared_lib_module,
        .linkage = .dynamic,
    });
    shared_lib.linkLibrary(sqlite.artifact("sqlite"));
    shared_lib.linkLibC();
    b.installArtifact(shared_lib);

    // 库构建步骤
    const lib_step = b.step("lib", "Build ZigCMS as a library (static and dynamic)");
    lib_step.dependOn(&static_lib.step);
    lib_step.dependOn(&shared_lib.step);

    // ========================================================================
    // 主可执行文件
    // ========================================================================
    const exe_module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{ .name = "zigcms", .root_module = exe_module });

    exe_module.addImport("zap", zap.module("zap"));
    exe_module.addImport("regex", regex.module("regex"));
    exe_module.addImport("pg", pg.module("pg"));
    exe_module.addImport("pretty", pretty.module("pretty"));
    exe_module.addImport("sqlite", sqlite.module("sqlite"));
    exe_module.addImport("curl", curl.module("curl"));
    exe_module.addImport("smtp_client", smtp_client.module("smtp_client"));

    exe.linkLibrary(sqlite.artifact("sqlite"));
    exe.linkLibC();

    // MySQL 客户端库链接
    exe.linkSystemLibrary("mysqlclient");

    // macOS: Homebrew 安装路径
    if (target.result.os.tag == .macos) {
        // 尝试多个可能的 Homebrew MySQL 安装路径
        exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/lib" });
        exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/include" });
        exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/lib" });
        exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/include" });
        exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/lib" });
        exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/include" });
    }
    // Linux: 标准路径
    if (target.result.os.tag == .linux) {
        exe.addLibraryPath(.{ .cwd_relative = "/usr/lib/x86_64-linux-gnu" });
        exe.addIncludePath(.{ .cwd_relative = "/usr/include/mysql" });
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the ZigCMS server");
    run_step.dependOn(&run_cmd.step);

    // ========================================================================
    // 单元测试
    // ========================================================================
    const lib_unit_tests_module = b.createModule(.{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
    });
    // 添加测试所需的依赖
    lib_unit_tests_module.addImport("zap", zap.module("zap"));
    lib_unit_tests_module.addImport("pg", pg.module("pg"));
    lib_unit_tests_module.addImport("pretty", pretty.module("pretty"));
    lib_unit_tests_module.addImport("regex", regex.module("regex"));
    lib_unit_tests_module.addImport("smtp_client", smtp_client.module("smtp_client"));
    lib_unit_tests_module.addImport("sqlite", sqlite.module("sqlite"));
    lib_unit_tests_module.addImport("curl", curl.module("curl"));

    const lib_unit_tests = b.addTest(.{
        .name = "zigcms-lib-tests",
        .root_module = lib_unit_tests_module,
    });
    lib_unit_tests.linkLibrary(sqlite.artifact("sqlite"));
    lib_unit_tests.linkSystemLibrary("mysqlclient");
    lib_unit_tests.linkLibC();

    if (target.result.os.tag == .macos) {
        lib_unit_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/lib" });
        lib_unit_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/include" });
    }

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests_module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // 添加测试所需的依赖
    exe_unit_tests_module.addImport("zap", zap.module("zap"));
    exe_unit_tests_module.addImport("pg", pg.module("pg"));
    exe_unit_tests_module.addImport("pretty", pretty.module("pretty"));
    exe_unit_tests_module.addImport("regex", regex.module("regex"));
    exe_unit_tests_module.addImport("smtp_client", smtp_client.module("smtp_client"));
    exe_unit_tests_module.addImport("sqlite", sqlite.module("sqlite"));
    exe_unit_tests_module.addImport("curl", curl.module("curl"));

    const exe_unit_tests = b.addTest(.{
        .name = "zigcms-exe-tests",
        .root_module = exe_unit_tests_module,
    });
    exe_unit_tests.linkLibrary(sqlite.artifact("sqlite"));
    exe_unit_tests.linkSystemLibrary("mysqlclient");
    exe_unit_tests.linkLibC();

    if (target.result.os.tag == .macos) {
        exe_unit_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/lib" });
        exe_unit_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/include" });
    }

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // ========================================================================
    // 集成测试
    // ========================================================================
    const integration_tests_module = b.createModule(.{
        .root_source_file = b.path("tests/integration/system_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_tests_module.addImport("zap", zap.module("zap"));
    integration_tests_module.addImport("pg", pg.module("pg"));
    integration_tests_module.addImport("pretty", pretty.module("pretty"));
    integration_tests_module.addImport("regex", regex.module("regex"));
    integration_tests_module.addImport("smtp_client", smtp_client.module("smtp_client"));
    integration_tests_module.addImport("sqlite", sqlite.module("sqlite"));
    integration_tests_module.addImport("curl", curl.module("curl"));

    // 添加项目内部模块引用
    integration_tests_module.addImport("zigcms", lib_module);

    const integration_tests = b.addTest(.{
        .name = "zigcms-integration-tests",
        .root_module = integration_tests_module,
    });
    integration_tests.linkLibrary(sqlite.artifact("sqlite"));
    integration_tests.linkSystemLibrary("mysqlclient");
    integration_tests.linkLibC();

    if (target.result.os.tag == .macos) {
        // Intel Mac (Homebrew)
        integration_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/lib" });
        integration_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/include" });
        // Apple Silicon Mac (Homebrew)
        integration_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/lib" });
        integration_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/include" });
    }

    const run_integration_tests = b.addRunArtifact(integration_tests);

    // 测试步骤
    const test_step = b.step("test", "Run all tests (unit + integration)");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_integration_tests.step);

    // 仅单元测试步骤
    const unit_test_step = b.step("test-unit", "Run unit tests only");
    unit_test_step.dependOn(&run_lib_unit_tests.step);
    unit_test_step.dependOn(&run_exe_unit_tests.step);

    // 仅集成测试步骤
    const integration_test_step = b.step("test-integration", "Run integration tests only");
    integration_test_step.dependOn(&run_integration_tests.step);

    // ========================================================================
    // 属性测试 (Property-Based Tests)
    // ========================================================================
    const property_tests_module = b.createModule(.{
        .root_source_file = b.path("tests/property/orm_property_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    property_tests_module.addImport("zap", zap.module("zap"));
    property_tests_module.addImport("pg", pg.module("pg"));
    property_tests_module.addImport("pretty", pretty.module("pretty"));
    property_tests_module.addImport("regex", regex.module("regex"));
    property_tests_module.addImport("smtp_client", smtp_client.module("smtp_client"));
    property_tests_module.addImport("sqlite", sqlite.module("sqlite"));
    property_tests_module.addImport("curl", curl.module("curl"));
    // 添加 zigcms 库模块引用
    property_tests_module.addImport("zigcms", lib_module);

    const property_tests = b.addTest(.{
        .name = "zigcms-property-tests",
        .root_module = property_tests_module,
    });
    property_tests.linkLibrary(sqlite.artifact("sqlite"));
    property_tests.linkSystemLibrary("mysqlclient");
    property_tests.linkLibC();

    if (target.result.os.tag == .macos) {
        property_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/lib" });
        property_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/include" });
        property_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/lib" });
        property_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/include" });
    }

    const run_property_tests = b.addRunArtifact(property_tests);

    // 属性测试步骤
    const property_test_step = b.step("test-property", "Run property-based tests (ORM correctness properties)");
    property_test_step.dependOn(&run_property_tests.step);

    // ========================================================================
    // Code Generation Tool (from commands/)
    // ========================================================================
    const codegen_module = b.createModule(.{
        .root_source_file = b.path("commands/codegen.zig"),
        .target = target,
        .optimize = optimize,
    });
    const codegen_exe = b.addExecutable(.{ .name = "codegen", .root_module = codegen_module });

    codegen_exe.linkLibC();

    b.installArtifact(codegen_exe);

    const run_codegen_cmd = b.addRunArtifact(codegen_exe);
    run_codegen_cmd.step.dependOn(b.getInstallStep());

    const codegen_step = b.step("codegen", "Run the code generation tool (model, controller, DTO)");
    codegen_step.dependOn(&run_codegen_cmd.step);

    if (b.args) |args| {
        for (args) |arg| {
            run_codegen_cmd.addArg(arg);
        }
    }

    // ========================================================================
    // Database Migration Tool (from commands/)
    // ========================================================================
    const migrate_module = b.createModule(.{
        .root_source_file = b.path("commands/migrate.zig"),
        .target = target,
        .optimize = optimize,
    });
    const migrate_exe = b.addExecutable(.{ .name = "migrate", .root_module = migrate_module });

    migrate_exe.linkLibC();

    b.installArtifact(migrate_exe);

    const run_migrate_cmd = b.addRunArtifact(migrate_exe);
    run_migrate_cmd.step.dependOn(b.getInstallStep());

    const migrate_step = b.step("migrate", "Run database migrations (up/down/status/create)");
    migrate_step.dependOn(&run_migrate_cmd.step);

    if (b.args) |args| {
        for (args) |arg| {
            run_migrate_cmd.addArg(arg);
        }
    }

    // ========================================================================
    // Plugin Code Generator (from commands/)
    // ========================================================================
    const plugin_gen_module = b.createModule(.{
        .root_source_file = b.path("commands/plugin_gen.zig"),
        .target = target,
        .optimize = optimize,
    });
    const plugin_gen_exe = b.addExecutable(.{ .name = "plugin-gen", .root_module = plugin_gen_module });

    plugin_gen_exe.linkLibC();

    b.installArtifact(plugin_gen_exe);

    const run_plugin_gen_cmd = b.addRunArtifact(plugin_gen_exe);
    run_plugin_gen_cmd.step.dependOn(b.getInstallStep());

    const plugin_gen_step = b.step("plugin-gen", "Generate plugin code from template (--help for options)");
    plugin_gen_step.dependOn(&run_plugin_gen_cmd.step);

    if (b.args) |args| {
        for (args) |arg| {
            run_plugin_gen_cmd.addArg(arg);
        }
    }

    // ========================================================================
    // Configuration Generator (from commands/)
    // ========================================================================
    const config_gen_module = b.createModule(.{
        .root_source_file = b.path("commands/config_gen.zig"),
        .target = target,
        .optimize = optimize,
    });
    const config_gen_exe = b.addExecutable(.{ .name = "config-gen", .root_module = config_gen_module });

    config_gen_exe.linkLibC();

    b.installArtifact(config_gen_exe);

    const run_config_gen_cmd = b.addRunArtifact(config_gen_exe);
    run_config_gen_cmd.step.dependOn(b.getInstallStep());

    const config_gen_step = b.step("config-gen", "Generate configuration structure from .env file (--help for options)");
    config_gen_step.dependOn(&run_config_gen_cmd.step);

    if (b.args) |args| {
        for (args) |arg| {
            run_config_gen_cmd.addArg(arg);
        }
    }

    // // ========================================================================
    // // MySQL 集成测试
    // // ========================================================================
    // const mysql_test_module = b.createModule(.{
    //     .root_source_file = b.path("src/services/sql/integration_test.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const mysql_test_exe = b.addExecutable(.{ .name = "mysql-test", .root_module = mysql_test_module });

    // // 链接 MySQL C 库
    // mysql_test_exe.linkLibC();
    // mysql_test_exe.linkSystemLibrary("mysqlclient");

    // // macOS: Homebrew 安装路径
    // if (target.result.os.tag == .macos) {
    //     // 通用路径（符号链接）
    //     mysql_test_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    //     mysql_test_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    //     // mysql-client@8.0 路径
    //     mysql_test_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/Cellar/mysql-client@8.0/8.0.42/lib" });
    //     mysql_test_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/Cellar/mysql-client@8.0/8.0.42/include" });
    //     // Intel Mac
    //     mysql_test_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/lib" });
    //     mysql_test_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client@8.0/include" });
    // }

    // b.installArtifact(mysql_test_exe);

    // const run_mysql_test = b.addRunArtifact(mysql_test_exe);
    // run_mysql_test.step.dependOn(b.getInstallStep());

    // const mysql_test_step = b.step("test-mysql", "Run MySQL integration tests");
    // mysql_test_step.dependOn(&run_mysql_test.step);

    // // ========================================================================
    // // SQLite 集成测试
    // // ========================================================================
    // const sqlite_test_module = b.createModule(.{
    //     .root_source_file = b.path("src/services/sql/sqlite_test.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const sqlite_test_exe = b.addExecutable(.{ .name = "sqlite-test", .root_module = sqlite_test_module });

    // // 链接 SQLite3 库
    // sqlite_test_exe.linkLibC();
    // sqlite_test_exe.linkSystemLibrary("sqlite3");

    // b.installArtifact(sqlite_test_exe);

    // const run_sqlite_test = b.addRunArtifact(sqlite_test_exe);
    // run_sqlite_test.step.dependOn(b.getInstallStep());

    // const sqlite_test_step = b.step("test-sqlite", "Run SQLite integration tests (no external DB needed)");
    // sqlite_test_step.dependOn(&run_sqlite_test.step);

    // // ========================================================================
    // // ORM 集成测试（SQLite）
    // // ========================================================================
    // const orm_test_module = b.createModule(.{
    //     .root_source_file = b.path("src/services/sql/orm_test.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const orm_test_exe = b.addExecutable(.{ .name = "orm-test", .root_module = orm_test_module });

    // orm_test_exe.linkLibC();
    // orm_test_exe.linkSystemLibrary("sqlite3");

    // b.installArtifact(orm_test_exe);

    // const run_orm_test = b.addRunArtifact(orm_test_exe);
    // run_orm_test.step.dependOn(b.getInstallStep());

    // const orm_test_step = b.step("test-orm", "Run ORM + QueryBuilder integration tests");
    // orm_test_step.dependOn(&run_orm_test.step);
}
