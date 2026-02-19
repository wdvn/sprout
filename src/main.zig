const std = @import("std");
const wgvk = @import("wgvk");

const c = @cImport({
    @cInclude("RGFW.h");
});

// Manual definitions for RGFW constants if not picked up by cImport
const RGFW_FULLSCREEN: u16 = (1 << 8);
const RGFW_CENTER: u16 = (1 << 11);

// Placeholder SPIR-V for a simple vertex shader
// In a real project, you would compile GLSL/HLSL to SPIR-V
const vertex_shader_spirv = @embedFile("shaders/triangle.vert.spv"); // Assuming you have this file
const fragment_shader_spirv = @embedFile("shaders/triangle.frag.spv"); // Assuming you have this file

// Vertex data for a simple triangle
const vertices = [_]f32{
    0.0, -0.5, 1.0, 0.0, 0.0, // Top vertex (pos, color)
    0.5, 0.5, 0.0, 1.0, 0.0, // Right vertex
    -0.5, 0.5, 0.0, 0.0, 1.0, // Left vertex
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 1. Initialize RGFW Window
    const window_width: u32 = 800;
    const window_height: u32 = 600;

    // Use the RGFW_RECT macro which should be translated by cImport
    const window = c.RGFW_createWindow("WGVK Triangle (RGFW)", 0, 0, @intCast(window_width), @intCast(window_height), RGFW_CENTER // | RGFW_FULLSCREEN // Uncomment for fullscreen
    );
    if (window == null) {
        std.debug.print("Failed to create RGFW window\n", .{});
        return;
    }
    defer c.RGFW_window_close(window);

    // 2. Initialize WGVK
    // This part assumes a high-level WGVK API. Actual implementation might vary.
    var instance: wgvk.Instance = undefined;
    var surface: wgvk.Surface = undefined;
    var device: wgvk.Device = undefined;
    var swapchain: wgvk.Swapchain = undefined;
    var render_pass: wgvk.RenderPass = undefined;
    var pipeline: wgvk.Pipeline = undefined;
    var command_pool: wgvk.CommandPool = undefined;
    var command_buffers: std.ArrayList(wgvk.CommandBuffer) = undefined;

    errdefer {
        if (command_buffers.items.len > 0) {
            for (command_buffers.items) |buf| buf.deinit();
            command_buffers.deinit();
        }
        if (command_pool.deinit) command_pool.deinit();
        if (pipeline.deinit) pipeline.deinit();
        if (render_pass.deinit) render_pass.deinit();
        if (swapchain.deinit) swapchain.deinit();
        if (device.deinit) device.deinit();
        if (surface.deinit) surface.deinit();
        if (instance.deinit) instance.deinit();
    }

    const window_handle: *anyopaque = @ptrCast(window);

    instance = try wgvk.Instance.init(allocator, "WGVK Triangle App");
    surface = try wgvk.Surface.init(allocator, instance, window_handle);
    device = try wgvk.Device.init(allocator, instance, surface);
    swapchain = try wgvk.Swapchain.init(allocator, device, surface, window_width, window_height);
    render_pass = try wgvk.RenderPass.init(allocator, device, swapchain.format);

    const vertex_input_bindings = [_]wgvk.VertexInputBindingDescription{
        .{
            .binding = 0,
            .stride = 5 * @sizeOf(f32),
            .inputRate = .vertex,
        },
    };
    const vertex_input_attributes = [_]wgvk.VertexInputAttributeDescription{
        .{ .binding = 0, .location = 0, .format = .r32g32_sfloat, .offset = 0 },
        .{ .binding = 0, .location = 1, .format = .r32g32b32_sfloat, .offset = 2 * @sizeOf(f32) },
    };

    pipeline = try wgvk.Pipeline.init(
        allocator,
        device,
        render_pass,
        vertex_shader_spirv,
        fragment_shader_spirv,
        &vertex_input_bindings,
        &vertex_input_attributes,
        window_width,
        window_height,
    );

    command_pool = try wgvk.CommandPool.init(allocator, device);
    command_buffers = std.ArrayList(wgvk.CommandBuffer).init(allocator);
    try command_buffers.resize(swapchain.image_views.len);

    for (command_buffers.items, 0..) |*cmd_buf, i| {
        cmd_buf.* = try wgvk.CommandBuffer.init(allocator, device, command_pool);
        try cmd_buf.begin(.{ .flags = .simultaneous_use });

        const clear_color = wgvk.ClearColorValue{ .float32 = .{ 0.0, 0.0, 0.0, 1.0 } };
        try cmd_buf.beginRenderPass(
            render_pass,
            swapchain.framebuffers[i],
            .{ .x = 0, .y = 0, .width = window_width, .height = window_height },
            &.{.{ .color = clear_color }},
        );

        cmd_buf.bindPipeline(.graphics, pipeline);
        cmd_buf.draw(3, 1, 0, 0);

        try cmd_buf.endRenderPass();
        try cmd_buf.end();
    }

    std.debug.print("Starting WGVK Triangle Render...\n", .{});

    while (c.RGFW_window_shouldClose(window) == 0) {
        while (c.RGFW_window_checkEvent(window) != null) {}

        const image_index = try swapchain.acquireNextImage(std.math.maxInt(u64), wgvk.Semaphore.null());

        const wait_semaphores = [_]wgvk.Semaphore{};
        const signal_semaphores = [_]wgvk.Semaphore{};
        try device.graphics_queue.submit(
            &.{.{
                .command_buffers = &.{command_buffers.items[image_index]},
                .wait_semaphores = &wait_semaphores,
                .signal_semaphores = &signal_semaphores,
                .wait_dst_stage_mask = &.{wgvk.PipelineStageFlags.color_attachment_output},
            }},
            wgvk.Fence.null(),
        );

        try device.present_queue.present(&.{swapchain}, &.{image_index}, &signal_semaphores);

        std.time.sleep(16 * 1000 * 1000);
    }

    try device.waitIdle();
}
