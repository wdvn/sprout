const sg = @import("sokol").gfx;
const sapp = @import("sokol").app;
const sglue = @import("sokol").glue;
const slog = @import("sokol").log;
const sgl = @import("sokol").gl;

const BOARD_SIZE = 15;
const EMPTY = 0;
const PLAYER = 1; // Quân Trắng
const BOT = 2;    // Quân Đen (Ví dụ)

const GameState = struct {
    pass_action: sg.PassAction = .{},
    board: [BOARD_SIZE][BOARD_SIZE]u8 = [_][BOARD_SIZE]u8{[_]u8{0} ** BOARD_SIZE} ** BOARD_SIZE,
};

var state = GameState{};

// Hàm xử lý sự kiện (Click chuột)
export fn input(event: ?*const sapp.Event) void {
    const ev = event.?;
    if (ev.type == .MOUSE_DOWN and ev.mouse_button == .LEFT) {
        // Chuyển đổi tọa độ chuột (0 -> Width) sang tọa độ bàn cờ (-1.0 -> 1.0)
        const board_x = (ev.mouse_x / sapp.widthf()) * 2.0 - 1.0;
        const board_y = (ev.mouse_y / sapp.heightf()) * 2.0 - 1.0;

        // Chuyển tiếp sang chỉ số mảng (0 -> 14)
        // Hệ tọa độ y của màn hình ngược với y của OpenGL nên cần đảo lại
        const col = @as(i32, @intFromFloat((board_x + 0.9) / 0.128));
        const row = @as(i32, @intFromFloat((board_y + 0.9) / 0.128));

        if (col >= 0 and col < BOARD_SIZE and row >= 0 and row < BOARD_SIZE) {
            if (state.board[@intCast(row)][@intCast(col)] == EMPTY) {
                state.board[@intCast(row)][@intCast(col)] = PLAYER;
                // Sau khi bạn đánh, có thể gọi hàm bot_move() ở đây
            }
        }
    }
}

export fn init() void {
    sg.setup(.{ .environment = sglue.environment(), .logger = .{ .func = slog.func } });
    sgl.setup(.{ .logger = .{ .func = slog.func } });

    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.05, .g = 0.15, .b = 0.1, .a = 1.0 },
    };
}

export fn frame() void {
    sgl.defaults();
    sgl.ortho(-1.0, 1.0, 1.0, -1.0, -1.0, 1.0); // Đảo y để khớp tọa độ chuột

    // 1. Vẽ lưới bàn cờ
    sgl.beginLines();
    sgl.c4b(100, 100, 100, 255);
    var i: f32 = 0;
    while (i <= BOARD_SIZE) : (i += 1) {
        const pos = -0.9 + (i * 0.128); // Tính toán khoảng cách ô
        sgl.v2f(-0.9, pos); sgl.v2f(0.9, pos);
        sgl.v2f(pos, -0.9); sgl.v2f(pos, 0.9);
    }
    sgl.end();

    // 2. Vẽ các quân cờ dựa trên mảng state.board
    sgl.beginQuads();
    for (0..BOARD_SIZE) |r| {
        for (0..BOARD_SIZE) |c| {
            if (state.board[r][c] == PLAYER) {
                sgl.c4b(255, 255, 255, 255); // Quân trắng
                const x = -0.9 + @as(f32, @floatFromInt(c)) * 0.128;
                const y = -0.9 + @as(f32, @floatFromInt(r)) * 0.128;
                sgl.v2f(x + 0.02, y + 0.02);
                sgl.v2f(x + 0.1, y + 0.02);
                sgl.v2f(x + 0.1, y + 0.1);
                sgl.v2f(x + 0.02, y + 0.1);
            }
        }
    }
    sgl.end();

    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });
    sgl.draw();
    sg.endPass();
    sg.commit();
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = input, // Đăng ký hàm xử lý sự kiện
        // .cleanup_cb = sg.shutdown,
        .width = 640,
        .height = 640,
        .window_title = "Zig Caro: Player vs Bot",
        .logger = .{ .func = slog.func },
    });
}