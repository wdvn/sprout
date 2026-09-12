// src/ui/vfs.zig
const std = @import("std");

/// Virtual file system abstraction for asset:// paths.
/// Currently just forwards to std.fs.cwd().openFile for demonstration.
pub const VFS = struct {
    pub fn open(path: []const u8) !std.fs.File {
        // Expect paths like "assets://textures/foo.png".
        const prefix = "assets://";
        if (std.mem.startsWith(u8, path, prefix)) {
            const rel = path[prefix.len..];
            return std.fs.cwd().openFile(rel, .{ .read = true });
        } else {
            return std.fs.cwd().openFile(path, .{ .read = true });
        }
    }
};
