// src/ui/components/ui_components.zig
const std = @import("std");

/// UI component definitions used by the XML UI loader and renderer.
pub const Position = struct {
    x: f32,
    y: f32,
};

pub const Size = struct {
    w: f32,
    h: f32,
};

pub const Button = struct {
    id: []const u8,
    text: []const u8,
    pos: Position,
    size: Size,
};
