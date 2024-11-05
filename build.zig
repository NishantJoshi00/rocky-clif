const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "rock-clip",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    attachRocks(b, lib, &target.result);

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "rock-clip",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    attachRocks(b, exe, &target.result);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    attachRocks(b, lib_unit_tests, &target.result);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    attachRocks(b, exe_unit_tests, &target.result);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn attachRocks(b: *std.Build, to: *std.Build.Step.Compile, target: *const std.Target) void {
    to.linkLibC();
    to.linkSystemLibrary("rocksdb");
    to.addLibraryPath(b.path("./rocksdb"));
    to.addIncludePath(b.path("./rocksdb/include"));

    if (target.isDarwin()) {
        b.installFile("./rocksdb/librocksdb.9.9.0.dylib", "../librocksdb.9.9.0.dylib");
        to.addRPath(b.path("."));
    }
}
