// src/ui/app.zig
const std = @import("std");

pub const App = struct {
    pub fn init() void {
        // TODO: Initialize sokol_app, create window, set up main loop.
        std.debug.print("[UI] App.init called\n", .{});
    }
};
