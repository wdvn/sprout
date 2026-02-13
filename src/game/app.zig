const std = @import("std");

// Game constants
const ROTATION_SPEED = 1.5; // Radians per second
const SHOOT_SPEED = 400.0;  // Pixels per second
const PULL_SPEED = 150.0;   // Pixels per second
const MAX_LENGTH = 700.0;
const MIN_LENGTH = 60.0;

const GameState = enum {
    aiming,
    shooting,
    pulling,
};

const Gold = struct {
    x: f32,
    y: f32,
    radius: f32,
    value: i32,
    active: bool,
    caught: bool,
};

pub const App = @This();

// Engine state
timer: std.time.Timer,
// rng: std.rand.DefaultPrng,

// Game state
state: GameState = .aiming,
hook_angle: f32 = 0.0,
hook_length: f32 = MIN_LENGTH,
hook_origin_x: f32 = 400.0, // Screen center X
hook_origin_y: f32 = 50.0,  // Top of screen
hook_dir: f32 = 1.0,        // 1 or -1 for rotation direction

score: i32 = 0,
golds: std.ArrayList(Gold),
caught_gold_index: ?usize = null,

pub fn init(app: *App) !void {
    app.timer = try std.time.Timer.start();
    // app.rng = std.rand.DefaultPrng.init(0);
    app.golds = std.ArrayList(Gold).init(std.heap.page_allocator);

    // Initialize some gold chunks
    try app.golds.append(.{ .x = 200, .y = 400, .radius = 30, .value = 500, .active = true, .caught = false });
    try app.golds.append(.{ .x = 600, .y = 500, .radius = 50, .value = 1000, .active = true, .caught = false });
    try app.golds.append(.{ .x = 400, .y = 300, .radius = 20, .value = 200, .active = true, .caught = false });
    try app.golds.append(.{ .x = 100, .y = 550, .radius = 40, .value = 800, .active = true, .caught = false });
    try app.golds.append(.{ .x = 700, .y = 450, .radius = 25, .value = 300, .active = true, .caught = false });
}

pub fn deinit(app: *App) void {
    app.golds.deinit();
}

pub fn update(app: *App) !bool {
    // Delta time in seconds
    const dt_ns = app.timer.lap();
    const dt = @as(f32, @floatFromInt(dt_ns)) / 1_000_000_000.0;

    // Handle Input (Placeholder: Space to shoot)
    // In a real app, you would check input state passed from main loop
    // if (input.isKeyPressed(.space) and app.state == .aiming) {
    //     app.state = .shooting;
    // }

    switch (app.state) {
        .aiming => {
            app.hook_angle += app.hook_dir * ROTATION_SPEED * dt;
            // Swing back and forth between -70 and 70 degrees (approx 1.2 radians)
            if (app.hook_angle > 1.2) {
                app.hook_angle = 1.2;
                app.hook_dir = -1.0;
            } else if (app.hook_angle < -1.2) {
                app.hook_angle = -1.2;
                app.hook_dir = 1.0;
            }
        },
        .shooting => {
            app.hook_length += SHOOT_SPEED * dt;
            
            // Calculate hook tip position
            const tip_x = app.hook_origin_x + std.math.sin(app.hook_angle) * app.hook_length;
            const tip_y = app.hook_origin_y + std.math.cos(app.hook_angle) * app.hook_length;

            // Check collisions with gold
            for (app.golds.items, 0..) |*gold, i| {
                if (!gold.active) continue;
                
                const dx = tip_x - gold.x;
                const dy = tip_y - gold.y;
                const dist_sq = dx*dx + dy*dy;
                
                if (dist_sq < gold.radius * gold.radius) {
                    // Hit gold!
                    app.state = .pulling;
                    gold.caught = true;
                    app.caught_gold_index = i;
                    break;
                }
            }

            // Check bounds (miss)
            if (app.hook_length >= MAX_LENGTH or tip_x < 0 or tip_x > 800 or tip_y > 600) {
                app.state = .pulling;
                app.caught_gold_index = null;
            }
        },
        .pulling => {
            var speed = PULL_SPEED;
            // Heavy gold pulls slower
            if (app.caught_gold_index) |idx| {
                const gold = app.golds.items[idx];
                if (gold.radius > 40) {
                    speed *= 0.5;
                }
            }

            app.hook_length -= speed * dt;

            // Update caught gold position
            if (app.caught_gold_index) |idx| {
                var gold = &app.golds.items[idx];
                gold.x = app.hook_origin_x + std.math.sin(app.hook_angle) * app.hook_length;
                gold.y = app.hook_origin_y + std.math.cos(app.hook_angle) * app.hook_length;
            }

            if (app.hook_length <= MIN_LENGTH) {
                app.hook_length = MIN_LENGTH;
                app.state = .aiming;
                
                if (app.caught_gold_index) |idx| {
                    const gold = &app.golds.items[idx];
                    app.score += gold.value;
                    gold.active = false; // Remove gold
                    gold.caught = false;
                    app.caught_gold_index = null;
                    std.debug.print("Score: {}\n", .{app.score});
                }
            }
        },
    }

    return false;
}
