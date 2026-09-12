// src/ui/gfx.zig
const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;

/// Wrapper exposing two command queues: 3D and UI.
pub const Gfx = struct {
    pub fn init() void {
        // Placeholder: initialize sokol_gfx if needed.
        std.debug.print("[UI] Gfx.init called\n", .{});
    }
};
