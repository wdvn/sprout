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

    // Add NVRHI dependency (C++ project)
    const nvrhi_dep = b.dependency("nvrhi", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(nvrhi_dep.path("include"));
    exe.addIncludePath(nvrhi_dep.path("src/vulkan"));

    const nvrhi_sources = &.{
        "src/common/misc.cpp",
        "src/common/state-tracking.cpp",
        "src/vulkan/vulkan-allocator.cpp",
        "src/vulkan/vulkan-backend.h",
        "src/vulkan/vulkan-buffer.cpp",
        "src/vulkan/vulkan-commandlist.cpp",
        "src/vulkan/vulkan-compute.cpp",
        "src/vulkan/vulkan-constants.cpp",
        "src/vulkan/vulkan-device.cpp",
        "src/vulkan/vulkan-graphics.cpp",
        "src/vulkan/vulkan-meshlets.cpp",
        "src/vulkan/vulkan-queries.cpp",
        "src/vulkan/vulkan-queue.cpp",
        "src/vulkan/vulkan-raytracing.cpp",
        "src/vulkan/vulkan-resource-bindings.cpp",
        "src/vulkan/vulkan-shader.cpp",
        "src/vulkan/vulkan-staging-texture.cpp",
        "src/vulkan/vulkan-state-tracking.cpp",
        "src/vulkan/vulkan-texture.cpp",
        "src/vulkan/vulkan-upload.cpp",
    };

    inline for (nvrhi_sources) |source_file| {
        exe.addCSourceFile(.{
            .file = nvrhi_dep.path(source_file),
            .flags = &.{
                "-std=c++17",
                "-fno-elide-type", // Shows full types
                "-ftemplate-backtrace-limit=5", // Limits C++ template recursion logs
                "-fmax-errors=3",
            },
            .language = .cpp, // Explicitly set language to C++
        });
    }

    // Add the C++ wrapper for NVRHI
    exe.addCSourceFile(.{
        .file = b.path("src/nvrhi_impl.cpp"),
        .flags = &.{
            "-std=c++17",
            "-fno-elide-type", // Shows full types
            "-ftemplate-backtrace-limit=5", // Limits C++ template recursion logs
            "-fmax-errors=3",
        },
        .language = .cpp, // Explicitly set language to C++
    });
    exe.addCSourceFile(.{
        .file = b.path("src/nvrhi_impl.h"),
        .flags = &.{
            "-std=c++17",
            "-fno-elide-type", // Shows full types
            "-ftemplate-backtrace-limit=5", // Limits C++ template recursion logs
            "-fmax-errors=3",
        },
        .language = .cpp, // Explicitly set language to C++
    });
    exe.linkLibCpp();
    exe.linkSystemLibrary("vulkan");

    // Add RGFW dependency (C single-header library)
    const rgfw_dep = b.dependency("rgfw", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(rgfw_dep.path("")); // RGFW.h is at the root
    exe.addCSourceFile(.{ .file = b.path("src/rgfw_impl.c"), .flags = &.{"-std=c99"} });
    exe.linkSystemLibrary("X11"); // RGFW on Linux needs X11
    exe.linkSystemLibrary("Xrandr"); // Fix for XRRGetScreenResourcesCurrent

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
