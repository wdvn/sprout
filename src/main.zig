const std = @import("std");

const c = @cImport({
    @cInclude("RGFW.h");
});

// C-style interface from nvrhi_impl.h
const nvrhi_wrapper = @cImport({
    @cInclude("nvrhi_impl.h");
});

// Manual definitions for RGFW constants if not picked up by cImport
const RGFW_FULLSCREEN: u16 = (1 << 8);
const RGFW_CENTER: u16 = (1 << 11);

pub fn main() !void {
    // 1. Initialize RGFW Window
    const window_width: u32 = 800;
    const window_height: u32 = 600;

    const window = c.RGFW_createWindow("NVRHI Triangle (RGFW)", 0, 0, @intCast(window_width), @intCast(window_height), RGFW_CENTER);
    if (window == null) {
        std.debug.print("Failed to create RGFW window\n", .{});
        return;
    }
    defer c.RGFW_window_close(window);

    // 2. Initialize NVRHI via C++ wrapper
    const nvrhi_state = nvrhi_wrapper.nvrhi_init(@ptrCast(window));
    if (nvrhi_state == null) {
        std.debug.print("Failed to initialize NVRHI\n", .{});
        return;
    }
    defer nvrhi_wrapper.nvrhi_shutdown(nvrhi_state);

    std.debug.print("Starting NVRHI Triangle Render...\n", .{});

    while (c.RGFW_window_shouldClose(window) == 0) {
        while (c.RGFW_window_checkEvent(window) != null) {}

        nvrhi_wrapper.nvrhi_render(nvrhi_state);

        std.time.sleep(16 * 1000 * 1000);
    }
}
