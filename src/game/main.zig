const sg = @import("sokol").gfx;
const sapp = @import("sokol").app;
const sglue = @import("sokol").glue;

// Trạng thái game đơn giản
const GameState = struct {
    pass_action: sg.PassAction = .{},
    // Bạn có thể thêm mảng bàn cờ [15][15]u8 ở đây
};

var state = GameState{};

// Hàm khởi tạo (chạy 1 lần)
export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
    });

    // Màu nền "xanh bảng đen" cho hợp với game Caro
    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.1, .g = 0.2, .b = 0.15, .a = 1.0 },
    };
}

// Hàm vẽ (chạy mỗi frame)
export fn frame() void {
    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });

    // TODO: Gọi các lệnh vẽ lưới và quân cờ ở đây

    sg.endPass();
    sg.commit();
}

// Hàm dọn dẹp
export fn cleanup() void {
    sg.shutdown();
}

// Cấu hình ứng dụng
pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = 600,
        .height = 600,
        .window_title = "Zig Caro - Sokol GPU",
        .icon = .{ .sokol_default = true },
    });
}