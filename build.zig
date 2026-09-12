const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    const libs = b.createModule(.{
        .root_source_file = b.path("src/libs/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    libs.addImport("sokol", sokol.module("sokol"));

    const game = b.createModule(.{
        .root_source_file = b.path("src/game/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    game.addImport("libs", libs);
    game.addImport("sokol", sokol.module("sokol"));
    game.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
    game.addLibraryPath(b.path("deps/lib"));
    game.linkSystemLibrary("sqlite3", .{});
    game.linkSystemLibrary("freetype", .{});
    game.linkSystemLibrary("harfbuzz", .{});

    const sprout_exe = b.addExecutable(.{
        .name = "sprout",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    sprout_exe.root_module.addImport("libs", libs);
    sprout_exe.root_module.addImport("game", game);
    sprout_exe.root_module.addImport("sokol", sokol.module("sokol"));
    // Clay layout engine integration deferred (no C linking needed for stub implementation)
    sprout_exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
    sprout_exe.root_module.addLibraryPath(b.path("deps/lib"));
    sprout_exe.root_module.linkSystemLibrary("GL", .{});
    sprout_exe.root_module.linkSystemLibrary("X11", .{});
    sprout_exe.root_module.linkSystemLibrary("sqlite3", .{});
    sprout_exe.root_module.linkSystemLibrary("freetype", .{});
    sprout_exe.root_module.linkSystemLibrary("harfbuzz", .{});

    b.installArtifact(sprout_exe);

    const sprout_run_cmd = b.addRunArtifact(sprout_exe);
    sprout_run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run Sprout");
    run_step.dependOn(&sprout_run_cmd.step);

    const sprout_run_step = b.step("run-sprout", "Run Sprout");
    sprout_run_step.dependOn(&sprout_run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = libs,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const game_unit_tests = b.addTest(.{
        .root_module = game,
    });
    game_unit_tests.root_module.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
    game_unit_tests.root_module.addLibraryPath(b.path("deps/lib"));
    game_unit_tests.root_module.linkSystemLibrary("sqlite3", .{});
    game_unit_tests.root_module.linkSystemLibrary("freetype", .{});
    game_unit_tests.root_module.linkSystemLibrary("harfbuzz", .{});
    const run_game_unit_tests = b.addRunArtifact(game_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_game_unit_tests.step);
}
