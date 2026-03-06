const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const cpp_flags = &.{ "-std=c++17", "-DNVRHI_SHARED_LIBRARY_BUILD" };

    const main_module = b.createModule(.{
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("./src/main.zig"),
    });
    const libs_mod = b.addModule("libs", .{ .root_source_file = b.path("./src/libs/mod.zig") });
    const exe = b.addExecutable(.{ .name = "luynt", .root_module = main_module });

    exe.addIncludePath(b.path("src/cpp"));

    const string = b.dependency("string", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("string", string.module("string"));
    exe.root_module.addImport("libs", libs_mod);

    const rgfw_dep = b.dependency("rgfw", .{
        .target = target,
        .optimize = optimize,
    });

    const nvrhi_dep = b.dependency("nvrhi", .{
        .target = target,
        .optimize = optimize,
    });

    const vma_dep = b.dependency("vma", .{
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(rgfw_dep.path(""));
    exe.addIncludePath(nvrhi_dep.path("include"));
    exe.addIncludePath(nvrhi_dep.path("src"));
    exe.addIncludePath(nvrhi_dep.path("src/common"));
    exe.addIncludePath(nvrhi_dep.path("src/vulkan"));
    exe.addIncludePath(nvrhi_dep.path("thirdparty/Vulkan-Headers/include"));
    exe.addIncludePath(vma_dep.path("include"));

    // Vulkan-Hpp global dynamic dispatch storage definition.
    exe.addCSourceFile(.{
        .file = b.path("src/cpp/vulkan_dispatch_loader.cpp"),
        .flags = cpp_flags,
        .language = .cpp,
    });

    // VMA implementation TU.
    exe.addCSourceFile(.{
        .file = b.path("src/cpp/vma_impl.cpp"),
        .flags = cpp_flags,
        .language = .cpp,
    });

    // RGFW implementation TU (window + Vulkan surface helpers).
    exe.addCSourceFile(.{ .file = b.path("src/cpp/rgfw_impl.c"), .flags = &.{"-std=c99"} });

    // Local C ABI wrapper used by Zig.
    exe.addCSourceFile(.{
        .file = b.path("src/cpp/nvrhi_impl.cpp"),
        .flags = cpp_flags,
        .language = .cpp,
    });

    // NVRHI common sources required by Vulkan backend.
    inline for ([_][]const u8{
        "src/common/misc.cpp",
        "src/common/state-tracking.cpp",
        "src/common/utils.cpp",
        "src/common/format-info.cpp",
        "src/common/aftermath.cpp",
    }) |rel| {
        exe.addCSourceFile(.{
            .file = nvrhi_dep.path(rel),
            .flags = cpp_flags,
            .language = .cpp,
        });
    }

    // NVRHI Vulkan backend sources.
    inline for ([_][]const u8{
        "src/vulkan/vulkan-allocator.cpp",
        "src/vulkan/vulkan-buffer.cpp",
        "src/vulkan/vulkan-commandlist.cpp",
        "src/vulkan/vulkan-compute.cpp",
        "src/vulkan/vulkan-constants.cpp",
        "src/vulkan/vulkan-device.cpp",
        "src/vulkan/vulkan-graphics.cpp",
        "src/vulkan/vulkan-meshlets.cpp",
        "src/vulkan/vulkan-queries.cpp",
        "src/vulkan/vulkan-raytracing.cpp",
        "src/vulkan/vulkan-queue.cpp",
        "src/vulkan/vulkan-resource-bindings.cpp",
        "src/vulkan/vulkan-shader.cpp",
        "src/vulkan/vulkan-staging-texture.cpp",
        "src/vulkan/vulkan-state-tracking.cpp",
        "src/vulkan/vulkan-texture.cpp",
        "src/vulkan/vulkan-upload.cpp",
    }) |rel| {
        exe.addCSourceFile(.{
            .file = nvrhi_dep.path(rel),
            .flags = cpp_flags,
            .language = .cpp,
        });
    }

    exe.linkLibCpp();
    exe.linkSystemLibrary("vulkan");

    // RGFW Linux deps.
    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("Xrandr");
    exe.linkSystemLibrary("Xcursor");

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{ .root_module = main_module });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_tests.step);
}
