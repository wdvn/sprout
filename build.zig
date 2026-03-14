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

    gomoku_exe.root_module.addImport("sokol", sokol.module("sokol"));
    gomoku_exe.addIncludePath(b.path("src/game/shader"));
    gomoku_exe.linkSystemLibrary("GL");
    gomoku_exe.linkSystemLibrary("X11");

    const gomoku_run_cmd = b.addRunArtifact(gomoku_exe);
    gomoku_run_cmd.step.dependOn(b.getInstallStep());

    const gomoku_run_step = b.step("run-gomoku", "Run the Gomoku game");
    gomoku_run_step.dependOn(&gomoku_run_cmd.step);
}
