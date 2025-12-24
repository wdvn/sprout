const std = @import("std");
const libs = @import("libs/mod.zig");

fn lessThan(a: i32, b: i32) bool {
    return a < b;
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a Min-Heap for i32
    var min_heap = libs.heap.Heap(i32, lessThan).init(allocator);
    defer min_heap.deinit();

    // Insert unsorted numbers
    try min_heap.insert(10);
    try min_heap.insert(5);
    try min_heap.insert(30);
    try min_heap.insert(2);

    std.debug.print("Top is: {?}\n", .{min_heap.peek()}); // Should be 2

    // Extract them (Should come out sorted: 2, 5, 10, 30)
    std.debug.print("Extracting: ", .{});
    while (min_heap.extract()) |val| {
        std.debug.print("{d} ", .{val});
    }
    std.debug.print("\n", .{});
}
