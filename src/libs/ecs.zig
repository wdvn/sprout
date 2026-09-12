const std = @import("std");

/// Generates a globally unique memory address for each distinct type T.
fn TypeHolder(comptime T: type) type {
    return struct {
        pub const ComponentType = T;
        var id: u8 = 0;
    };
}

pub fn typeId(comptime T: type) usize {
    return @intFromPtr(&TypeHolder(T).id);
}

/// Generational Entity identifier preventing use-after-free bugs.
pub const Entity = struct {
    id: u32,
    generation: u32 = 0,

    pub const null_entity: Entity = .{ .id = std.math.maxInt(u32), .generation = 0 };

    pub fn eql(self: Entity, other: Entity) bool {
        return self.id == other.id and self.generation == other.generation;
    }

    pub fn isNull(self: Entity) bool {
        return self.id == null_entity.id;
    }
};

/// High-performance contiguous component pool using the Sparse-Set pattern.
pub fn ComponentPool(comptime T: type) type {
    return struct {
        sparse: std.ArrayList(?u32) = .empty,
        dense: std.ArrayList(Entity) = .empty,
        components: std.ArrayList(T) = .empty,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.sparse.deinit(self.allocator);
            self.dense.deinit(self.allocator);
            self.components.deinit(self.allocator);
        }

        pub fn clear(self: *Self) void {
            self.sparse.clearRetainingCapacity();
            self.dense.clearRetainingCapacity();
            self.components.clearRetainingCapacity();
        }

        pub fn insert(self: *Self, entity: Entity, component: T) !void {
            if (entity.id >= self.sparse.items.len) {
                const old_len = self.sparse.items.len;
                const new_len = entity.id + 1;
                try self.sparse.resize(self.allocator, new_len);
                for (self.sparse.items[old_len..new_len]) |*slot| {
                    slot.* = null;
                }
            }

            if (self.sparse.items[entity.id]) |dense_idx| {
                // Entity already has this component, update in place
                self.dense.items[dense_idx] = entity;
                self.components.items[dense_idx] = component;
            } else {
                // New component insertion
                const dense_idx: u32 = @intCast(self.dense.items.len);
                try self.dense.append(self.allocator, entity);
                try self.components.append(self.allocator, component);
                self.sparse.items[entity.id] = dense_idx;
            }
        }

        pub fn has(self: *const Self, entity: Entity) bool {
            if (entity.id >= self.sparse.items.len) return false;
            const dense_idx = self.sparse.items[entity.id] orelse return false;
            return self.dense.items[dense_idx].eql(entity);
        }

        pub fn get(self: *Self, entity: Entity) ?*T {
            if (entity.id >= self.sparse.items.len) return null;
            const dense_idx = self.sparse.items[entity.id] orelse return null;
            if (!self.dense.items[dense_idx].eql(entity)) return null;
            return &self.components.items[dense_idx];
        }

        pub fn getConst(self: *const Self, entity: Entity) ?*const T {
            if (entity.id >= self.sparse.items.len) return null;
            const dense_idx = self.sparse.items[entity.id] orelse return null;
            if (!self.dense.items[dense_idx].eql(entity)) return null;
            return &self.components.items[dense_idx];
        }

        pub fn remove(self: *Self, entity: Entity) bool {
            if (entity.id >= self.sparse.items.len) return false;
            const dense_idx = self.sparse.items[entity.id] orelse return false;
            if (!self.dense.items[dense_idx].eql(entity)) return false;

            // Swap-remove with last element for O(1) removal
            const last_idx = self.dense.items.len - 1;
            if (dense_idx != last_idx) {
                const last_entity = self.dense.items[last_idx];
                self.dense.items[dense_idx] = last_entity;
                self.components.items[dense_idx] = self.components.items[last_idx];
                self.sparse.items[last_entity.id] = @intCast(dense_idx);
            }

            _ = self.dense.pop();
            _ = self.components.pop();
            self.sparse.items[entity.id] = null;
            return true;
        }

        pub fn count(self: *const Self) usize {
            return self.dense.items.len;
        }
    };
}

/// Type-erased wrapper for generic component pools.
const PoolWrapper = struct {
    ptr: *anyopaque,
    deinitFn: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
    clearFn: *const fn (ptr: *anyopaque) void,
    removeFn: *const fn (ptr: *anyopaque, entity: Entity) bool,

    fn make(comptime T: type, pool: *ComponentPool(T)) PoolWrapper {
        const gen = struct {
            fn deinit(ptr: *anyopaque, allocator: std.mem.Allocator) void {
                const self: *ComponentPool(T) = @ptrCast(@alignCast(ptr));
                self.deinit();
                allocator.destroy(self);
            }

            fn clear(ptr: *anyopaque) void {
                const self: *ComponentPool(T) = @ptrCast(@alignCast(ptr));
                self.clear();
            }

            fn remove(ptr: *anyopaque, entity: Entity) bool {
                const self: *ComponentPool(T) = @ptrCast(@alignCast(ptr));
                return self.remove(entity);
            }
        };

        return .{
            .ptr = pool,
            .deinitFn = gen.deinit,
            .clearFn = gen.clear,
            .removeFn = gen.remove,
        };
    }
};

/// The central ECS Registry (World) managing entities and component pools.
pub const Registry = struct {
    allocator: std.mem.Allocator,
    generations: std.ArrayList(u32) = .empty,
    free_ids: std.ArrayList(u32) = .empty,
    pools: std.AutoHashMap(usize, PoolWrapper),

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{
            .allocator = allocator,
            .pools = std.AutoHashMap(usize, PoolWrapper).init(allocator),
        };
    }

    pub fn deinit(self: *Registry) void {
        var it = self.pools.valueIterator();
        while (it.next()) |wrapper| {
            wrapper.deinitFn(wrapper.ptr, self.allocator);
        }
        self.pools.deinit();
        self.generations.deinit(self.allocator);
        self.free_ids.deinit(self.allocator);
    }

    /// Clears all entities and component pools while retaining memory capacity.
    pub fn clear(self: *Registry) void {
        var it = self.pools.valueIterator();
        while (it.next()) |wrapper| {
            wrapper.clearFn(wrapper.ptr);
        }
        for (self.generations.items) |*gen| {
            gen.* +%= 1;
        }
        self.free_ids.clearRetainingCapacity();
        for (0..self.generations.items.len) |i| {
            self.free_ids.append(self.allocator, @intCast(i)) catch {};
        }
    }

    /// Creates a new entity or recycles an unused ID with an incremented generation.
    pub fn create(self: *Registry) !Entity {
        if (self.free_ids.pop()) |id| {
            const gen = self.generations.items[id];
            return Entity{ .id = id, .generation = gen };
        } else {
            const id: u32 = @intCast(self.generations.items.len);
            try self.generations.append(self.allocator, 0);
            return Entity{ .id = id, .generation = 0 };
        }
    }

    /// Destroys an entity, removing it from all component pools and invalidating handles.
    pub fn destroy(self: *Registry, entity: Entity) void {
        if (!self.isAlive(entity)) return;

        // Remove entity from all component pools
        var it = self.pools.valueIterator();
        while (it.next()) |wrapper| {
            _ = wrapper.removeFn(wrapper.ptr, entity);
        }

        // Increment generation to invalidate existing entity handles
        self.generations.items[entity.id] +%= 1;
        self.free_ids.append(self.allocator, entity.id) catch {};
    }

    /// Checks whether an entity handle is currently valid and alive.
    pub fn isAlive(self: *const Registry, entity: Entity) bool {
        if (entity.id >= self.generations.items.len) return false;
        return self.generations.items[entity.id] == entity.generation;
    }

    /// Returns the component pool for type T, creating it dynamically if not yet allocated.
    pub fn getPool(self: *Registry, comptime T: type) !*ComponentPool(T) {
        const tid = typeId(T);
        if (self.pools.get(tid)) |wrapper| {
            return @ptrCast(@alignCast(wrapper.ptr));
        }

        const pool = try self.allocator.create(ComponentPool(T));
        pool.* = ComponentPool(T).init(self.allocator);
        const wrapper = PoolWrapper.make(T, pool);
        try self.pools.put(tid, wrapper);
        return pool;
    }

    /// Adds or updates a component on the specified entity.
    pub fn add(self: *Registry, entity: Entity, component: anytype) !void {
        const T = @TypeOf(component);
        const pool = try self.getPool(T);
        try pool.insert(entity, component);
    }

    /// Retrieves a mutable pointer to the entity's component of type T.
    pub fn get(self: *Registry, entity: Entity, comptime T: type) ?*T {
        const tid = typeId(T);
        const wrapper = self.pools.get(tid) orelse return null;
        const pool: *ComponentPool(T) = @ptrCast(@alignCast(wrapper.ptr));
        return pool.get(entity);
    }

    /// Retrieves an immutable pointer to the entity's component of type T.
    pub fn getConst(self: *const Registry, entity: Entity, comptime T: type) ?*const T {
        const tid = typeId(T);
        const wrapper = self.pools.get(tid) orelse return null;
        const pool: *const ComponentPool(T) = @ptrCast(@alignCast(wrapper.ptr));
        return pool.getConst(entity);
    }

    /// Checks if an entity possesses a component of type T.
    pub fn has(self: *const Registry, entity: Entity, comptime T: type) bool {
        const tid = typeId(T);
        const wrapper = self.pools.get(tid) orelse return false;
        const pool: *const ComponentPool(T) = @ptrCast(@alignCast(wrapper.ptr));
        return pool.has(entity);
    }

    /// Removes a component of type T from the entity.
    pub fn remove(self: *Registry, entity: Entity, comptime T: type) bool {
        const tid = typeId(T);
        const wrapper = self.pools.get(tid) orelse return false;
        const pool: *ComponentPool(T) = @ptrCast(@alignCast(wrapper.ptr));
        return pool.remove(entity);
    }

    /// Returns a direct view of a single component pool for fast contiguous iteration.
    pub fn view(self: *Registry, comptime T: type) ?*ComponentPool(T) {
        const tid = typeId(T);
        const wrapper = self.pools.get(tid) orelse return null;
        return @ptrCast(@alignCast(wrapper.ptr));
    }

    /// Returns a multi-component view for iterating over entities having all specified components.
    pub fn viewMulti(self: *Registry, comptime Types: anytype) MultiView(Types) {
        return .{ .registry = self };
    }
};

/// Multi-component query iterator.
pub fn MultiView(comptime Types: anytype) type {
    return struct {
        registry: *Registry,
        index: usize = 0,

        const Self = @This();
        const ItemTuple = blk: {
            var fields: [Types.len + 1]type = undefined;
            fields[0] = Entity;
            for (0..Types.len) |i| {
                fields[i + 1] = *Types[i];
            }
            break :blk std.meta.Tuple(&fields);
        };

        pub fn next(self: *Self) ?ItemTuple {
            const primary_pool = self.registry.getPool(Types[0]) catch return null;
            while (self.index < primary_pool.dense.items.len) {
                const entity = primary_pool.dense.items[self.index];
                self.index += 1;

                var match = true;
                inline for (1..Types.len) |i| {
                    const T = Types[i];
                    if (!self.registry.has(entity, T)) {
                        match = false;
                        break;
                    }
                }

                if (match) {
                    var result: ItemTuple = undefined;
                    result[0] = entity;
                    result[1] = &primary_pool.components.items[self.index - 1];
                    inline for (1..Types.len) |i| {
                        const T = Types[i];
                        result[i + 1] = self.registry.get(entity, T).?;
                    }
                    return result;
                }
            }
            return null;
        }
    };
}

// ============================================================================
// Unit Tests
// ============================================================================

test "typeId uniqueness" {
    const Pos = struct { x: f32, y: f32 };
    const Vel = struct { vx: f32, vy: f32 };
    const Acc = struct { ax: f32, ay: f32 };

    const t1 = typeId(Pos);
    const t2 = typeId(Vel);
    const t3 = typeId(Acc);
    const t1_again = typeId(Pos);

    try std.testing.expect(t1 != t2);
    try std.testing.expect(t2 != t3);
    try std.testing.expectEqual(t1, t1_again);
}

test "SparseSet basic operations" {
    const allocator = std.testing.allocator;
    const Position = struct { x: f32, y: f32 };

    var pool = ComponentPool(Position).init(allocator);
    defer pool.deinit();

    const e1 = Entity{ .id = 0, .generation = 0 };
    const e2 = Entity{ .id = 5, .generation = 0 };

    try pool.insert(e1, .{ .x = 10, .y = 20 });
    try pool.insert(e2, .{ .x = 50, .y = 60 });

    try std.testing.expect(pool.has(e1));
    try std.testing.expect(pool.has(e2));
    try std.testing.expect(!pool.has(Entity{ .id = 3, .generation = 0 }));

    const p1 = pool.get(e1).?;
    try std.testing.expectEqual(@as(f32, 10), p1.x);

    try std.testing.expect(pool.remove(e1));
    try std.testing.expect(!pool.has(e1));
    try std.testing.expect(pool.has(e2));
}

test "Registry entity lifecycle and multi-component query" {
    const allocator = std.testing.allocator;
    var reg = Registry.init(allocator);
    defer reg.deinit();

    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { vx: f32, vy: f32 };

    const e1 = try reg.create();
    const e2 = try reg.create();
    const e3 = try reg.create();

    try reg.add(e1, Position{ .x = 10, .y = 20 });
    try reg.add(e1, Velocity{ .vx = 1, .vy = 2 });

    try reg.add(e2, Position{ .x = 100, .y = 200 });

    try reg.add(e3, Position{ .x = 5, .y = 5 });
    try reg.add(e3, Velocity{ .vx = 10, .vy = 10 });

    try std.testing.expect(reg.isAlive(e1));
    try std.testing.expect(reg.isAlive(e2));
    try std.testing.expect(reg.isAlive(e3));

    // Multi-component query
    var query = reg.viewMulti(.{ Position, Velocity });
    var count: usize = 0;
    while (query.next()) |item| {
        const ent = item[0];
        const pos = item[1];
        const vel = item[2];
        pos.x += vel.vx;
        count += 1;
        _ = ent;
    }

    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expectEqual(@as(f32, 11), reg.get(e1, Position).?.x);
    try std.testing.expectEqual(@as(f32, 100), reg.get(e2, Position).?.x); // unchanged
    try std.testing.expectEqual(@as(f32, 15), reg.get(e3, Position).?.x);

    // Destroy e1
    reg.destroy(e1);
    try std.testing.expect(!reg.isAlive(e1));
    try std.testing.expect(reg.get(e1, Position) == null);

    // Recycle ID
    const e4 = try reg.create();
    try std.testing.expectEqual(e1.id, e4.id);
    try std.testing.expect(e4.generation > e1.generation);
    try std.testing.expect(reg.isAlive(e4));
}
