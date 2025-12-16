const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_module = b.createModule(.{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .name = "vendor",
        .root_module = lib_module,
        .linkage = .static,
    });
    b.installArtifact(lib);

    const exe_module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{ .name = "vendor", .root_module = exe_module });

    const zap = b.dependency("zap", .{ .target = target, .optimize = optimize });
    exe_module.addImport("zap", zap.module("zap"));

    // const zig_webui = b.dependency("zig-webui", .{ .target = target, .optimize = optimize, .enable_tls = false, .is_static = true });
    // exe.root_module.addImport("webui", zig_webui.module("webui"));

    const regex = b.dependency("regex", .{ .target = target, .optimize = optimize });
    exe_module.addImport("regex", regex.module("regex"));

    const pg = b.dependency("pg", .{ .target = target, .optimize = optimize });
    exe_module.addImport("pg", pg.module("pg"));

    const pretty = b.dependency("pretty", .{ .target = target, .optimize = optimize });
    exe_module.addImport("pretty", pretty.module("pretty"));

    const sqlite = b.dependency("sqlite", .{ .target = target, .optimize = optimize });
    exe_module.addImport("sqlite", sqlite.module("sqlite"));
    exe.linkLibrary(sqlite.artifact("sqlite"));

    const curl = b.dependency("curl", .{ .target = target, .optimize = optimize });
    exe_module.addImport("curl", curl.module("curl"));
    exe.linkLibC();

    const smtp_client = b.dependency("smtp_client", .{ .target = target, .optimize = optimize });
    exe_module.addImport("smtp_client", smtp_client.module("smtp_client"));

    // MySQL 客户端库链接
    exe.linkSystemLibrary("mysqlclient");

    // macOS: Homebrew 安装路径
    if (target.result.os.tag == .macos) {
        // Apple Silicon (M1/M2/M3)
        // exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
        // exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
        // exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/lib" });
        // exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/include" });
        // Intel Mac
        exe.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/mysql-client/lib" });
        exe.addIncludePath(.{ .cwd_relative = "/usr/local/opt/mysql-client/include" });
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

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
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

    const lib_unit_tests = b.addTest(.{
        .name = "vendor-lib-tests",
        .root_module = lib_unit_tests_module,
    });
    lib_unit_tests.linkSystemLibrary("mysqlclient");
    lib_unit_tests.linkLibC();

    if (target.result.os.tag == .macos) {
        lib_unit_tests.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/mysql-client/lib" });
        lib_unit_tests.addIncludePath(.{ .cwd_relative = "/usr/local/opt/mysql-client/include" });
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
        .name = "vendor-exe-tests",
        .root_module = exe_unit_tests_module,
    });
    exe_unit_tests.linkSystemLibrary("mysqlclient");
    exe_unit_tests.linkLibC();

    if (target.result.os.tag == .macos) {
        exe_unit_tests.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/mysql-client/lib" });
        exe_unit_tests.addIncludePath(.{ .cwd_relative = "/usr/local/opt/mysql-client/include" });
    }

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // 集成测试
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

    // 添加项目内部模块引用
    integration_tests_module.addImport("zigcms", lib_module);

    const integration_tests = b.addTest(.{
        .name = "integration-tests",
        .root_module = integration_tests_module,
    });
    integration_tests.linkSystemLibrary("mysqlclient");
    integration_tests.linkLibC();

    if (target.result.os.tag == .macos) {
        // Apple Silicon
        integration_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/lib" });
        integration_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/include" });
        // Intel Mac (可选，如果不存在也不会报错，只会警告)
        // integration_tests.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/mysql-client/lib" });
        // integration_tests.addIncludePath(.{ .cwd_relative = "/usr/local/opt/mysql-client/include" });
    }

    const run_integration_tests = b.addRunArtifact(integration_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_integration_tests.step);

    // ========================================================================
    // Code Generation Tool
    // ========================================================================
    const codegen_module = b.createModule(.{
        .root_source_file = b.path("tools/codegen.zig"),
        .target = target,
        .optimize = optimize,
    });
    const codegen_exe = b.addExecutable(.{ .name = "codegen", .root_module = codegen_module });

    // Add the same dependencies as the main executable
    codegen_exe.root_module.addImport("zap", zap.module("zap"));
    codegen_exe.root_module.addImport("regex", regex.module("regex"));
    codegen_exe.root_module.addImport("pg", pg.module("pg"));
    codegen_exe.root_module.addImport("pretty", pretty.module("pretty"));
    codegen_exe.root_module.addImport("sqlite", sqlite.module("sqlite"));
    codegen_exe.root_module.addImport("curl", curl.module("curl"));
    codegen_exe.root_module.addImport("smtp_client", smtp_client.module("smtp_client"));

    codegen_exe.linkLibrary(sqlite.artifact("sqlite"));
    codegen_exe.linkLibC();

    b.installArtifact(codegen_exe);

    const run_codegen_cmd = b.addRunArtifact(codegen_exe);
    run_codegen_cmd.step.dependOn(b.getInstallStep());

    const codegen_step = b.step("codegen", "Run the code generation tool");
    codegen_step.dependOn(&run_codegen_cmd.step);

    if (b.args) |args| {
        for (args) |arg| {
            run_codegen_cmd.addArg(arg);
        }
    }

    // ========================================================================
    // Database Migration Tool
    // ========================================================================
    const migrate_module = b.createModule(.{
        .root_source_file = b.path("tools/migrate.zig"),
        .target = target,
        .optimize = optimize,
    });
    const migrate_exe = b.addExecutable(.{ .name = "migrate", .root_module = migrate_module });

    // Add the same dependencies as the main executable for migrations
    migrate_exe.root_module.addImport("zap", zap.module("zap"));
    migrate_exe.root_module.addImport("regex", regex.module("regex"));
    migrate_exe.root_module.addImport("pg", pg.module("pg"));
    migrate_exe.root_module.addImport("pretty", pretty.module("pretty"));
    migrate_exe.root_module.addImport("sqlite", sqlite.module("sqlite"));
    migrate_exe.root_module.addImport("curl", curl.module("curl"));
    migrate_exe.root_module.addImport("smtp_client", smtp_client.module("smtp_client"));

    migrate_exe.linkLibrary(sqlite.artifact("sqlite"));
    migrate_exe.linkLibC();

    b.installArtifact(migrate_exe);

    const run_migrate_cmd = b.addRunArtifact(migrate_exe);
    run_migrate_cmd.step.dependOn(b.getInstallStep());

    const migrate_step = b.step("migrate", "Run database migrations");
    migrate_step.dependOn(&run_migrate_cmd.step);

    if (b.args) |args| {
        for (args) |arg| {
            run_migrate_cmd.addArg(arg);
        }
    }

    // ========================================================================
    // Plugin Code Generator
    // ========================================================================
    const plugin_gen_module = b.createModule(.{
        .root_source_file = b.path("tools/plugin_gen.zig"),
        .target = target,
        .optimize = optimize,
    });
    const plugin_gen_exe = b.addExecutable(.{ .name = "plugin-gen", .root_module = plugin_gen_module });

    b.installArtifact(plugin_gen_exe);

    const run_plugin_gen_cmd = b.addRunArtifact(plugin_gen_exe);
    run_plugin_gen_cmd.step.dependOn(b.getInstallStep());

    const plugin_gen_step = b.step("plugin-gen", "Generate plugin code from template");
    plugin_gen_step.dependOn(&run_plugin_gen_cmd.step);

    if (b.args) |args| {
        for (args) |arg| {
            run_plugin_gen_cmd.addArg(arg);
        }
    }

    // ========================================================================
    // Configuration Generator
    // ========================================================================
    const config_gen_module = b.createModule(.{
        .root_source_file = b.path("tools/config_gen.zig"),
        .target = target,
        .optimize = optimize,
    });
    const config_gen_exe = b.addExecutable(.{ .name = "config-gen", .root_module = config_gen_module });

    b.installArtifact(config_gen_exe);

    const run_config_gen_cmd = b.addRunArtifact(config_gen_exe);
    run_config_gen_cmd.step.dependOn(b.getInstallStep());

    const config_gen_step = b.step("config-gen", "Generate configuration structure from .env file");
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
    //     mysql_test_exe.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/mysql-client/lib" });
    //     mysql_test_exe.addIncludePath(.{ .cwd_relative = "/usr/local/opt/mysql-client/include" });
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
