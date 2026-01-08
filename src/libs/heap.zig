const std = @import("std");
const Allocator = std.mem.Allocator;

/// A Generic Binary Heap.
/// T: The type of data to store.
/// compareFn: A function returning true if 'a' has higher priority than 'b'.
///            (e.g., for MinHeap use a < b, for MaxHeap use a > b).
pub fn Heap(comptime T: type, comptime compareFn: fn (T, T) bool) type {
    return struct {
        items: std.ArrayList(T),
        const Self = @This();

        /// Initialize the heap with an allocator
        pub fn init(allocator: Allocator) Self {
            return Self{
                .items = std.ArrayList(T).init(allocator),
            };
        }

        /// Release all memory
        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }

        /// Returns the number of elements in the heap
        pub fn len(self: Self) usize {
            return self.items.items.len;
        }

        /// Add an element to the heap
        pub fn insert(self: *Self, item: T) !void {
            // 1. Add element to the end of the array
            try self.items.append(item);
            // 2. Fix the heap property by bubbling up
            self.siftUp(self.items.items.len - 1);
        }

        /// Remove and return the top element (Min or Max)
        pub fn pop(self: *Self) ?T {
            const list = &self.items;
            if (list.items.len == 0) return null;

            // 1. Capture the root (result)
            const root = list.items[0];

            // 2. Move the last element to the root
            const last = list.pop().?;
            if (list.items.len > 0) {
                list.items[0] = last;
                // 3. Fix the heap property by bubbling down
                self.siftDown(0);
            }

            return root;
        }

        /// Look at the top element without removing it
        pub fn peek(self: Self) ?T {
            if (self.items.items.len == 0) return null;
            return self.items.items[0];
        }

        // --- Internal Helper Functions ---

        fn siftUp(self: *Self, start_index: usize) void {
            var index = start_index;
            while (index > 0) {
                const parent_idx = (index - 1) / 2;
                const child = self.items.items[index];
                const parent = self.items.items[parent_idx];

                // If child has higher priority than parent, swap
                if (compareFn(child, parent)) {
                    std.mem.swap(T, &self.items.items[index], &self.items.items[parent_idx]);
                    index = parent_idx;
                } else {
                    break;
                }
            }
        }

        fn siftDown(self: *Self, start_index: usize) void {
            var index = start_index;
            const count = self.items.items.len;

            while (true) {
                const left_idx = 2 * index + 1;
                const right_idx = 2 * index + 2;
                var swap_idx = index;

                // Check Left Child
                if (left_idx < count) {
                    if (compareFn(self.items.items[left_idx], self.items.items[swap_idx])) {
                        swap_idx = left_idx;
                    }
                }

                // Check Right Child
                if (right_idx < count) {
                    if (compareFn(self.items.items[right_idx], self.items.items[swap_idx])) {
                        swap_idx = right_idx;
                    }
                }

                if (swap_idx != index) {
                    std.mem.swap(T, &self.items.items[index], &self.items.items[swap_idx]);
                    index = swap_idx;
                } else {
                    break;
                }
            }
        }
    };
}

// --- Usage Example / Test ---
//
// fn lessThan( a: i32, b: i32) bool {
//     return a < b;
// }
//
// pub fn main() !void {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer _ = gpa.deinit();
//     const allocator = gpa.allocator();
//
//     // Create a Min-Heap for i32
//     var min_heap = Heap(i32, lessThan).init(allocator);
//     defer min_heap.deinit();
//
//     // Insert unsorted numbers
//     try min_heap.insert(10);
//     try min_heap.insert(5);
//     try min_heap.insert(30);
//     try min_heap.insert(2);
//
//     std.debug.print("Top is: {?}\n", .{min_heap.peek()}); // Should be 2
//
//     // Extract them (Should come out sorted: 2, 5, 10, 30)
//     std.debug.print("Extracting: ", .{});
//     while (min_heap.extract()) |val| {
//         std.debug.print("{d} ", .{val});
//     }
//     std.debug.print("\n", .{});
// }
