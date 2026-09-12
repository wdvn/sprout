const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    const gomoku_exe = b.addExecutable(.{
        .name = "gomoku",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/game/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const libs = b.createModule(.{
        .root_source_file = b.path("src/libs/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    libs.addImport("sokol", sokol.module("sokol"));
    gomoku_exe.root_module.addImport("libs", libs);

    gomoku_exe.root_module.addImport("sokol", sokol.module("sokol"));
    gomoku_exe.root_module.addIncludePath(b.path("src/game/shader"));
    gomoku_exe.root_module.linkSystemLibrary("GL", .{});
    gomoku_exe.root_module.linkSystemLibrary("X11", .{});

    b.installArtifact(gomoku_exe);

    const gomoku_run_cmd = b.addRunArtifact(gomoku_exe);
    gomoku_run_cmd.step.dependOn(b.getInstallStep());

    const gomoku_run_step = b.step("run-gomoku", "Run the Gomoku game");
    gomoku_run_step.dependOn(&gomoku_run_cmd.step);

    const run_step = b.step("run", "Run the Gomoku game");
    run_step.dependOn(&gomoku_run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = libs,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
