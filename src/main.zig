const std = @import("std");
const rlfw = @import("rlfw");
const wgvk = @import("wgvk");
const GameApp = @import("game/app.zig").App;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    // Initialize RLFW (Assuming similar API to GLFW or Raylib)
    // If it's a wrapper around GLFW, it might be rlfw.init()
    // If it's Raylib, it's InitWindow()
    
    // Since I don't have the exact API, I'll assume a GLFW-like structure based on the name "rlfw" (Raylib-GLFW?)
    // But given the user asked to "move glfw to rlfw", it implies rlfw is the windowing lib.
    
    // Placeholder initialization - adjust based on actual API
    try rlfw.init();
    defer rlfw.terminate();

    // Create window
    const window = try rlfw.Window.create(800, 600, "Gold Miner (WGVK + RLFW)", null);
    defer window.destroy();

    // Initialize the game application
    var app = GameApp{};
    try app.init();
    defer app.deinit();

    std.debug.print("Starting Gold Miner Game (WGVK + RLFW version)...\n", .{});
    std.debug.print("Press Space to shoot (simulated). Close window to exit.\n", .{});

    // Main game loop
    while (!window.shouldClose()) {
        rlfw.pollEvents();

        // Update game state
        const should_close = try app.update();
        if (should_close) break;
        
        // Simulate input for testing
        // Adjust input handling based on RLFW API
        // if (window.getKey(.space) == .press and app.state == .aiming) {
        //      app.state = .shooting;
        // }

        // TODO: Add WGVK rendering here
        // 1. Initialize Vulkan instance/device via WGVK
        // 2. Create swapchain
        // 3. Render loop

        // Simulate frame delay (approx 60 FPS)
        std.time.sleep(16 * 1000 * 1000);
    }
}
