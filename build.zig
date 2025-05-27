const std = @import("std");
const Builder = std.Build;
const Target = std.Target;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "glfw_example",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Liên kết với thư viện GLFW của hệ thống
    // Đảm bảo bạn đã cài đặt GLFW trên hệ thống của mình (ví dụ: `sudo apt install libglfw3-dev` trên Debian/Ubuntu)
    exe.linkSystemLibrary("glfw");

    // Một số hệ thống có thể yêu cầu thêm các thư viện sau (cho X11):
    if (target.result.os.tag == .linux) {
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
    }


    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    const glfw = b.dependency("glfw", .{}).module("glfw");
    const root = exe.root_module;
    root.addImport("glfw", glfw);
}