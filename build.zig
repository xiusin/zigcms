//! ZigCMS 构建配置
//!
//! 本文件定义了 ZigCMS 项目的构建配置，包括：
//! - 主可执行文件 (zigcms)
//! - 静态库 (libzigcms)
//! - 动态库 (libzigcms.so/dylib)
//! - 命令行工具 (codegen, migrate, plugin-gen)
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

// 辅助函数：添加通用导入
fn addCommonImports(module: *std.Build.Module, deps: anytype) void {
    module.addImport("zap", deps.zap.module("zap"));
    module.addImport("pg", deps.pg.module("pg"));
    module.addImport("pretty", deps.pretty.module("pretty"));
    module.addImport("regex", deps.regex.module("regex"));
    module.addImport("smtp_client", deps.smtp_client.module("smtp_client"));
    module.addImport("sqlite", deps.sqlite.module("sqlite"));
    module.addImport("curl", deps.curl.module("curl"));
}

// 辅助函数：设置 MySQL 路径
fn setupMySQLPaths(artifact: *std.Build.Step.Compile, target: std.Build.ResolvedTarget) void {
    artifact.linkSystemLibrary("mysqlclient");
    if (target.result.os.tag == .macos) {
        // Intel Mac
        artifact.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/mysql-client/lib" });
        artifact.addIncludePath(.{ .cwd_relative = "/usr/local/opt/mysql-client/include" });
        // Apple Silicon
        artifact.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/lib" });
        artifact.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/include" });
    }
    if (target.result.os.tag == .linux) {
        artifact.addLibraryPath(.{ .cwd_relative = "/usr/lib/x86_64-linux-gnu" });
        artifact.addIncludePath(.{ .cwd_relative = "/usr/include/mysql" });
    }
}

// 辅助函数：创建命令行工具
fn createCommandTool(b: *std.Build, name: []const u8, source_file: []const u8, description: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step {
    const commands_base = b.createModule(.{
        .root_source_file = b.path("commands/base.zig"),
    });

    const module = b.createModule(.{
        .root_source_file = b.path(source_file),
        .target = target,
        .optimize = optimize,
    });
    module.addImport("base", commands_base);

    const exe = b.addExecutable(.{ .name = name, .root_module = module });
    exe.linkLibC();
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const step = b.step(name, description);
    step.dependOn(&run_cmd.step);
    if (b.args) |args| {
        for (args) |arg| {
            run_cmd.addArg(arg);
        }
    }
    return step;
}

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
    addCommonImports(lib_module, .{ .zap = zap, .pg = pg, .pretty = pretty, .regex = regex, .smtp_client = smtp_client, .sqlite = sqlite, .curl = curl });

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
    addCommonImports(shared_lib_module, .{ .zap = zap, .pg = pg, .pretty = pretty, .regex = regex, .smtp_client = smtp_client, .sqlite = sqlite, .curl = curl });

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

    addCommonImports(exe_module, .{ .zap = zap, .pg = pg, .pretty = pretty, .regex = regex, .smtp_client = smtp_client, .sqlite = sqlite, .curl = curl });

    exe.linkLibrary(sqlite.artifact("sqlite"));
    exe.linkLibC();

    // MySQL 客户端库链接
    setupMySQLPaths(exe, target);

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
    addCommonImports(lib_unit_tests_module, .{ .zap = zap, .pg = pg, .pretty = pretty, .regex = regex, .smtp_client = smtp_client, .sqlite = sqlite, .curl = curl });

    const lib_unit_tests = b.addTest(.{
        .name = "zigcms-lib-tests",
        .root_module = lib_unit_tests_module,
    });
    lib_unit_tests.linkLibrary(sqlite.artifact("sqlite"));
    lib_unit_tests.linkLibC();
    setupMySQLPaths(lib_unit_tests, target);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests_module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    addCommonImports(exe_unit_tests_module, .{ .zap = zap, .pg = pg, .pretty = pretty, .regex = regex, .smtp_client = smtp_client, .sqlite = sqlite, .curl = curl });

    const exe_unit_tests = b.addTest(.{
        .name = "zigcms-exe-tests",
        .root_module = exe_unit_tests_module,
    });
    exe_unit_tests.linkLibrary(sqlite.artifact("sqlite"));
    exe_unit_tests.linkLibC();
    setupMySQLPaths(exe_unit_tests, target);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // ========================================================================
    // 集成测试
    // ========================================================================
    // const integration_tests_module = b.createModule(.{
    //     .root_source_file = b.path("tests/integration/system_test.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // addCommonImports(integration_tests_module, .{ .zap = zap, .pg = pg, .pretty = pretty, .regex = regex, .smtp_client = smtp_client, .sqlite = sqlite, .curl = curl });

    // // 添加项目内部模块引用
    // integration_tests_module.addImport("zigcms", lib_module);

    // const integration_tests = b.addTest(.{
    //     .name = "zigcms-integration-tests",
    //     .root_module = integration_tests_module,
    // });
    // integration_tests.linkLibrary(sqlite.artifact("sqlite"));
    // integration_tests.linkLibC();
    // setupMySQLPaths(integration_tests, target);

    // const run_integration_tests = b.addRunArtifact(integration_tests);

    // ========================================================================
    // 并发测试
    // ========================================================================
    const concurrent_tests_module = b.createModule(.{
        .root_source_file = b.path("tests/concurrent_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    addCommonImports(concurrent_tests_module, .{ .zap = zap, .pg = pg, .pretty = pretty, .regex = regex, .smtp_client = smtp_client, .sqlite = sqlite, .curl = curl });
    concurrent_tests_module.addImport("zigcms", lib_module);

    const concurrent_tests = b.addTest(.{
        .name = "zigcms-concurrent-tests",
        .root_module = concurrent_tests_module,
    });
    concurrent_tests.linkLibrary(sqlite.artifact("sqlite"));
    concurrent_tests.linkLibC();
    setupMySQLPaths(concurrent_tests, target);

    const run_concurrent_tests = b.addRunArtifact(concurrent_tests);

    const concurrent_test_step = b.step("test-concurrent", "Run concurrent/thread-safety tests");
    concurrent_test_step.dependOn(&run_concurrent_tests.step);

    // ========================================================================
    // 内存泄漏检测测试
    // ========================================================================
    const memory_leak_tests_module = b.createModule(.{
        .root_source_file = b.path("tests/memory_leak_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    addCommonImports(memory_leak_tests_module, .{ .zap = zap, .pg = pg, .pretty = pretty, .regex = regex, .smtp_client = smtp_client, .sqlite = sqlite, .curl = curl });
    memory_leak_tests_module.addImport("zigcms", lib_module);

    const memory_leak_tests = b.addTest(.{
        .name = "zigcms-memory-leak-tests",
        .root_module = memory_leak_tests_module,
    });
    memory_leak_tests.linkLibrary(sqlite.artifact("sqlite"));
    memory_leak_tests.linkLibC();
    setupMySQLPaths(memory_leak_tests, target);

    const run_memory_leak_tests = b.addRunArtifact(memory_leak_tests);

    const memory_leak_test_step = b.step("test-memory", "Run memory leak detection tests");
    memory_leak_test_step.dependOn(&run_memory_leak_tests.step);

    // 测试步骤
    const test_step = b.step("test", "Run all tests (unit + integration)");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_concurrent_tests.step);
    test_step.dependOn(&run_memory_leak_tests.step);

    // 仅单元测试步骤
    const unit_test_step = b.step("test-unit", "Run unit tests only");
    unit_test_step.dependOn(&run_lib_unit_tests.step);
    unit_test_step.dependOn(&run_exe_unit_tests.step);

    // 仅集成测试步骤
    // const integration_test_step = b.step("test-integration", "Run integration tests only");
    // integration_test_step.dependOn(&run_integration_tests.step);

    // ========================================================================
    // 属性测试 (Property-Based Tests)
    // ========================================================================
    const property_tests_module = b.createModule(.{
        .root_source_file = b.path("tests/property/orm_property_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    addCommonImports(property_tests_module, .{ .zap = zap, .pg = pg, .pretty = pretty, .regex = regex, .smtp_client = smtp_client, .sqlite = sqlite, .curl = curl });
    // 添加 zigcms 库模块引用
    property_tests_module.addImport("zigcms", lib_module);

    const property_tests = b.addTest(.{
        .name = "zigcms-property-tests",
        .root_module = property_tests_module,
    });
    property_tests.linkLibrary(sqlite.artifact("sqlite"));
    property_tests.linkLibC();
    setupMySQLPaths(property_tests, target);

    const run_property_tests = b.addRunArtifact(property_tests);

    // 属性测试步骤
    const property_test_step = b.step("test-property", "Run property-based tests (ORM correctness properties)");
    property_test_step.dependOn(&run_property_tests.step);

    // ========================================================================
    // Code Generation Tool (from commands/)
    // ========================================================================
    _ = createCommandTool(b, "codegen", "commands/codegen/main.zig", "Run the code generation tool (model, controller, DTO)", target, optimize);

    // ========================================================================
    // Database Migration Tool (from commands/)
    // ========================================================================
    _ = createCommandTool(b, "migrate", "commands/migrate/main.zig", "Run database migrations (up/down/status/create)", target, optimize);

    // ========================================================================
    // Plugin Code Generator (from commands/)
    // ========================================================================
    _ = createCommandTool(b, "plugin-gen", "commands/plugin_gen/main.zig", "Generate plugin code from template (--help for options)", target, optimize);

}
