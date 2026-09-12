const std = @import("std");
pub const heap = @import("heap.zig");
pub const webgl = @import("webgl.zig");
pub const gl = webgl;
pub const ecs = @import("ecs.zig");
pub const Registry = ecs.Registry;
pub const Entity = ecs.Entity;

pub const microui = @import("microui/root.zig");
pub const mui = microui;

test {
    std.testing.refAllDecls(@This());
}

