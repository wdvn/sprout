const std = @import("std");
const zglfw = @import("zglfw");
const wgvk = @import("wgvk");
const GameApp = @import("game/app.zig").App;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    // Initialize GLFW
    try zglfw.init();
    defer zglfw.terminate();

    // Create window
    zglfw.windowHint(.client_api, .no_api);
    const window = try zglfw.Window.create(800, 600, "Gold Miner (WGVK)", null);
    defer window.destroy();

    // Initialize the game application
    var app = GameApp{};
    try app.init();
    defer app.deinit();

    std.debug.print("Starting Gold Miner Game (WGVK version)...\n", .{});
    std.debug.print("Press Space to shoot (simulated). Close window to exit.\n", .{});

    // Main game loop
    while (!window.shouldClose()) {
        zglfw.pollEvents();

        // Update game state
        const should_close = try app.update();
        if (should_close) break;
        
        // Simulate input for testing (auto-shoot every few seconds could be added here)
        if (window.getKey(.space) == .press and app.state == .aiming) {
             app.state = .shooting;
        }

        // TODO: Add WGVK rendering here
        // 1. Initialize Vulkan instance/device via WGVK
        // 2. Create swapchain
        // 3. Render loop

        // Simulate frame delay (approx 60 FPS)
        std.time.sleep(16 * 1000 * 1000);
    }
}
