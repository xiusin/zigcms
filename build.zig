const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{ .name = "vendor", .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize });
    b.installArtifact(lib);

    const exe = b.addExecutable(.{ .name = "vendor", .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize });

    const zap = b.dependency("zap", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("zap", zap.module("zap"));

    const zig_webui = b.dependency("zig-webui", .{ .target = target, .optimize = optimize, .enable_tls = false, .is_static = true });
    exe.root_module.addImport("webui", zig_webui.module("webui"));

    const regex = b.dependency("regex", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("regex", regex.module("regex"));

    const pg = b.dependency("pg", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("pg", pg.module("pg"));

    const pretty = b.dependency("pretty", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("pretty", pretty.module("pretty"));

    const json = b.dependency("json", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("json", json.module("json"));

    const jwt = b.dependency("jwt", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("jwt", jwt.module("jwt"));

    const sqlite = b.dependency("sqlite", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("sqlite", sqlite.module("sqlite"));
    exe.linkLibrary(sqlite.artifact("sqlite"));

    const curl = b.dependency("curl", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("curl", curl.module("curl"));
    exe.linkLibC();

    const smtp_client = b.dependency("smtp_client", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("smtp_client", smtp_client.module("smtp_client"));

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
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    // ========================================================================
    // MySQL 集成测试
    // ========================================================================
    const mysql_test_exe = b.addExecutable(.{
        .name = "mysql-test",
        .root_source_file = b.path("src/services/mysql/integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 链接 MySQL C 库
    mysql_test_exe.linkLibC();
    mysql_test_exe.linkSystemLibrary("mysqlclient");

    // macOS: Homebrew 安装路径
    if (target.result.os.tag == .macos) {
        // 通用路径（符号链接）
        mysql_test_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
        mysql_test_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
        // mysql-client@8.0 路径
        mysql_test_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/Cellar/mysql-client@8.0/8.0.42/lib" });
        mysql_test_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/Cellar/mysql-client@8.0/8.0.42/include" });
        // Intel Mac
        mysql_test_exe.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/mysql-client/lib" });
        mysql_test_exe.addIncludePath(.{ .cwd_relative = "/usr/local/opt/mysql-client/include" });
    }

    b.installArtifact(mysql_test_exe);

    const run_mysql_test = b.addRunArtifact(mysql_test_exe);
    run_mysql_test.step.dependOn(b.getInstallStep());

    const mysql_test_step = b.step("test-mysql", "Run MySQL integration tests");
    mysql_test_step.dependOn(&run_mysql_test.step);
}
