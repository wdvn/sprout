const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_module = b.createModule(.{ .optimize = optimize, .target = target, .root_source_file = b.path("./src/main.zig") });
    const libs_mod = b.addModule("libs", .{ .root_source_file = b.path("./src/libs/mod.zig") });
    const exe = b.addExecutable(.{ .name = "luynt", .root_module = main_module });

    const string = b.dependency("string", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("string", string.module("string"));
    
    exe.root_module.addImport("libs", libs_mod);
    
    // Add WGVK dependency (C++ project)
    const wgvk_dep = b.dependency("wgvk", .{
        .target = target,
        .optimize = optimize,
    });
    
    if (wgvk_dep.builder.modules.contains("wgvk")) {
        exe.root_module.addImport("wgvk", wgvk_dep.module("wgvk"));
    } else {
        exe.addIncludePath(wgvk_dep.path("include"));
        exe.addIncludePath(wgvk_dep.path("src"));
        exe.linkLibCpp();
    }

    // Add RGFW dependency (C single-header library)
    const rgfw_dep = b.dependency("rgfw", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(rgfw_dep.path("")); // RGFW.h is at the root
    exe.addCSourceFile(.{ .file = b.path("src/rgfw_impl.c"), .flags = &.{"-std=c99"} });
    exe.linkSystemLibrary("X11"); // RGFW on Linux needs X11
    exe.linkSystemLibrary("Xrandr"); // Fix for XRRGetScreenResourcesCurrent

    // zmath dependency removed

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // --- Create the Test Step ---
    const tests = b.addTest(.{ .root_module = main_module });

    // 2. Create a Run Step for the compiled tests.
    const run_tests = b.addRunArtifact(tests);

    // This makes 'zig build test' automatically run the tests.
    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_tests.step);
}
