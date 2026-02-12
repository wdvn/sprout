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
    
    // Since WGVK is a C++ project, we likely need to link its artifact or add include paths
    // Assuming it provides a 'wgvk' artifact or we need to link manually.
    // If it has a build.zig, we can use its artifact.
    if (wgvk_dep.builder.modules.contains("wgvk")) {
        exe.root_module.addImport("wgvk", wgvk_dep.module("wgvk"));
    } else {
        // Fallback: Add include path and link C++ standard library if it's a raw C++ repo
        exe.addIncludePath(wgvk_dep.path("include"));
        exe.addIncludePath(wgvk_dep.path("src"));
        exe.linkLibCpp();
    }

    // Add zglfw dependency
    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.linkLibrary(zglfw.artifact("glfw"));

    // Add zmath dependency
    const zmath = b.dependency("zmath", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zmath", zmath.module("root"));

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
