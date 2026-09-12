// src/ui/clay.zig

const std = @import("std");
var party_xml_loaded: bool = false;

// Stub implementation of Clay layout engine integration.
// In a full implementation this would wrap the C library, but for now we provide
// no‑op functions so the rest of the code can compile and run.

pub fn init() void {
    // Initialize Clay if needed. Currently a no‑op.
    std.debug.print("[Clay] init stub called\n", .{});
}

/// Render the Party UI using Clay layout.
/// `state` and `renderer` are opaque pointers to the game's state and renderer.
pub fn renderParty(state: *anyopaque) void {
    // Load XML definition once.
    if (!party_xml_loaded) {
        // Stub: In real implementation, load and parse XML.
        std.debug.print("[Clay] loaded party UI XML (stub)\n", .{});
        party_xml_loaded = true;
    }
    // Future: parse XML and render UI via Clay layout engine.
    _ = state; // placeholder to avoid unused warning
}
