const std = @import("std");
const wgvk = @import("wgvk");
// const GameApp = @import("game/app.zig").App;

const c = @cImport({
    @cInclude("RGFW.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Initialize RGFW Window
    // RGFW_createWindow(const char* name, RGFW_rect rect, u16 args);
    const window = c.RGFW_createWindow("Gold Miner (WGVK + RGFW)",
        0, 0, 800, 600, 0);
    if (window == null) {
        std.debug.print("Failed to create RGFW window\n", .{});
        return;
    }
    defer c.RGFW_window_close(window);

    // Initialize the game application
    // var app = GameApp{};
    // try app.init();
    // defer app.deinit();

    std.debug.print("Starting Gold Miner Game (WGVK + RGFW version)...\n", .{});
    std.debug.print("Press Space to shoot (simulated). Close window to exit.\n", .{});

    // Main game loop
    while (c.RGFW_window_shouldClose(window) == 0) {
        // while (c.RGFW_window_checkEvent(window) != null) {
        //     // Handle events if needed
        // }

        // Update game state
        const should_close = false;
        if (should_close) break;

        // Simulate input for testing
        // if (c.RGFW_isPressed(window, c.RGFW_Space)) {
        //     // if (app.state == .aiming) {
        //     //     app.state = .shooting;
        //     // }
        // }

        // TODO: Add WGVK rendering here
        // 1. Initialize Vulkan instance/device via WGVK
        // 2. Create swapchain for the RGFW window
        // 3. Render triangle

        // Note: To render a triangle with WGVK, you would typically:
        // var ctx = wgvk.Context.init(...);
        // var pipeline = ctx.createPipeline(...);
        // ctx.beginFrame();
        // ctx.draw(pipeline, ...);
        // ctx.endFrame();

        // Simulate frame delay (approx 60 FPS)
        // std.time.sleep(16 * 1000 * 1000);
    }
}
