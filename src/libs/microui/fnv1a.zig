// Cut down version of FNV1a adapted from the Zig std library.
//
// https://tools.ietf.org/html/draft-eastlake-fnv-14

const std = @import("std");
const testing = std.testing;

pub fn Fnv1a(comptime T: type, comptime prime: T) type {
    return struct {
        const Self = @This();

        value: T,

        pub fn init(offset: T) Self {
            return Self{ .value = offset };
        }

        pub fn update(self: *Self, input: []const u8) void {
            for (input) |b| {
                self.value ^= b;
                self.value *%= prime;
            }
        }

        pub fn hash(self: *@This(), input: []const u8) T {
            self.update(input);
            return self.value;
        }
    };
}

pub const Fnv1a_32 = Fnv1a(u32, 0x01000193);

test "fnv1a-32" {
    var h0 = Fnv1a_32.init(0x811c9dc5);
    try testing.expect(h0.hash("") == 0x811c9dc5);
    var h1 = Fnv1a_32.init(0x811c9dc5);
    try testing.expect(h1.hash("a") == 0xe40c292c);
    var h2 = Fnv1a_32.init(0x811c9dc5);
    try testing.expect(h2.hash("foobar") == 0xbf9cf968);
}
