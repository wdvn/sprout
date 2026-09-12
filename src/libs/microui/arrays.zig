const std = @import("std");
const assert = std.debug.assert;

pub fn BoundedArray(comptime T: type, comptime buffer_capacity: usize) type {
    return struct {
        const Self = @This();
        buffer: [buffer_capacity]T = undefined,
        len: usize = 0,

        pub fn reset(self: *Self) void {
            self.len = 0;
        }

        pub fn slice(self: anytype) switch (@TypeOf(&self.buffer)) {
            *[buffer_capacity]T => []T,
            *const [buffer_capacity]T => []const T,
            else => unreachable,
        } {
            return self.buffer[0..self.len];
        }

        pub fn append(self: *Self, item: T) error{Overflow}!void {
            const new_item_ptr = try self.addOne();
            new_item_ptr.* = item;
        }

        pub fn appendAssumeCapacity(self: *Self, item: T) void {
            const new_item_ptr = self.addOneAssumeCapacity();
            new_item_ptr.* = item;
        }

        pub fn appendSlice(self: *Self, items: []const T) error{Overflow}!void {
            try self.ensureUnusedCapacity(items.len);
            self.appendSliceAssumeCapacity(items);
        }

        pub fn appendSliceAssumeCapacity(self: *Self, items: []const T) void {
            const old_len = self.len;
            self.len += items.len;
            @memcpy(self.slice()[old_len..][0..items.len], items);
        }

        pub fn ensureUnusedCapacity(self: Self, additional_count: usize) error{Overflow}!void {
            if (self.len + additional_count > buffer_capacity) {
                return error.Overflow;
            }
        }

        pub fn addOne(self: *Self) error{Overflow}!*T {
            try self.ensureUnusedCapacity(1);
            return self.addOneAssumeCapacity();
        }

        pub fn addOneAssumeCapacity(self: *Self) *T {
            assert(self.len < buffer_capacity);
            self.len += 1;
            return &self.slice()[self.len - 1];
        }
    };
}

pub fn BoundedStack(comptime T: type, comptime buffer_capacity: usize) type {
    return struct {
        const Self = @This();
        buf: BoundedArray(T, buffer_capacity) = .{},

        pub const ReverseIter = struct {
            items: []T,
            idx: usize,

            pub fn next(it: *@This()) ?T {
                if (it.idx == 0) {
                    return null;
                }
                it.idx -= 1;
                return it.items[it.idx];
            }
        };

        /// Iterate the stack elements going from the top-most (most recently pushed) down to the bottom-most element.
        pub fn topdown(self: *Self) ReverseIter {
            const items = self.buf.slice();
            return .{
                .items = items,
                .idx = items.len,
            };
        }

        pub fn push(self: *Self, item: T) void {
            self.buf.append(item) catch unreachable;
        }

        pub fn topPtr(self: *Self) ?*T {
            if (self.buf.len == 0) return null;
            return &self.buf.buffer[self.buf.len - 1];
        }

        pub fn top(self: *Self) ?T {
            if (self.topPtr()) |p| return p.*;
            return null;
        }

        pub fn pop(self: *Self) T {
            std.debug.assert(self.buf.len != 0); // can't pop from empty stack
            const idx = self.buf.len - 1;
            self.buf.len -= 1;
            return self.buf.buffer[idx];
        }

        pub fn size(self: *Self) usize {
            return self.buf.len;
        }
    };
}
