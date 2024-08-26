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

    const zmpl = b.dependency("zmpl", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("zmpl", zmpl.module("zmpl"));

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
}
