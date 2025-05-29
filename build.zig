const std = @import("std");
const Builder = std.Build;
const Target = std.Target;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "sprount",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Liên kết với thư viện GLFW của hệ thống
    // Đảm bảo bạn đã cài đặt GLFW trên hệ thống của mình (ví dụ: `sudo apt install libglfw3-dev` trên Debian/Ubuntu)
    exe.linkSystemLibrary("glfw");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    //import module
    manage_dependiencies(b, exe.root_module, target, optimize);
}

fn manage_dependiencies(b: *Builder, mod: *Builder.Module, target: Builder.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const glfw = b.dependency("glfw", .{}).module("glfw");
    const wgpu_native_dep = b.dependency("wgpu_native_zig", .{});

    mod.addImport("glfw", glfw);
    mod.addImport("wgpu", wgpu_native_dep.module("wgpu"));

    switch (target.result.os.tag) {
        .linux => {
        // exe.linkSystemLibrary("GL"); // Cho OpenGL
        // exe.linkSystemLibrary("X11");
        // exe.linkSystemLibrary("Xrandr");
        // exe.linkSystemLibrary("Xinerama");
        // exe.linkSystemLibrary("Xi"); // Cho Input
        // exe.linkSystemLibrary("Xcursor");
        // exe.linkSystemLibrary("rt"); // Cho clock_gettime
        // exe.linkSystemLibrary("dl"); // Cho dlopen/dlsym
        // exe.linkSystemLibrary("m"); // Cho toán học
        // exe.linkSystemLibrary("pthread"); // Cho luồng
        },
        .windows => {},
        else => {},
    }
    if (optimize == std.builtin.OptimizeMode.Debug) {
        std.debug.print("Not define optimize", .{});
    }
}
