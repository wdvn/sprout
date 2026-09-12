const std = @import("std");
const sokol = @import("sokol");
const sapp = sokol.app;
const sg = sokol.gfx;
const sglue = sokol.glue;
const slog = sokol.log;

const libs = @import("libs");
const gl = libs.gl;
const ecs = libs.ecs;

const BOARD_SIZE = 15;
const EMPTY = 0;
const PLAYER = 1; // White stone
const BOT = 2;    // Black stone

const BOARD_MIN: f32 = -0.84;
const BOARD_MAX: f32 = 0.84;
const BOARD_STEP: f32 = (BOARD_MAX - BOARD_MIN) / (BOARD_SIZE - 1);

// ============================================================================
// ECS Components
// ============================================================================

const BoardCoord = struct {
    row: usize,
    col: usize,
};

const StonePiece = struct {
    piece: u8,
};

const Transform = struct {
    x: f32,
    y: f32,
    radius: f32,
};

const Renderable = struct {
    color: [4]f32,
};

// ============================================================================
// Game State with ECS Registry
// ============================================================================

const GameState = struct {
    board: [BOARD_SIZE][BOARD_SIZE]u8 = [_][BOARD_SIZE]u8{[_]u8{0} ** BOARD_SIZE} ** BOARD_SIZE,
    move_count: u32 = 0,
    game_over: bool = false,
    winner: u8 = 0,
    registry: ecs.Registry = undefined,
};

var state = GameState{};

// WebGL resources
var line_prog: gl.Program = .{};
var line_vbo: gl.Buffer = .{};
var line_pos_loc: gl.AttribLocation = -1;
var line_color_loc: gl.UniformLocation = .{};
var line_vertex_count: i32 = 0;

var stone_prog: gl.Program = .{};
var stone_vbo: gl.Buffer = .{};
var stone_pos_loc: gl.AttribLocation = -1;
var stone_center_loc: gl.UniformLocation = .{};
var stone_radius_loc: gl.UniformLocation = .{};
var stone_color_loc: gl.UniformLocation = .{};

// GLSL Shaders for WebGL
const line_vs_source =
    \\#version 330
    \\in vec2 position;
    \\void main() {
    \\    gl_Position = vec4(position, 0.0, 1.0);
    \\}
;

const line_fs_source =
    \\#version 330
    \\uniform vec4 u_color;
    \\out vec4 frag_color;
    \\void main() {
    \\    frag_color = u_color;
    \\}
;

const stone_vs_source =
    \\#version 330
    \\in vec2 position;
    \\uniform vec2 u_center;
    \\uniform float u_radius;
    \\out vec2 v_pos;
    \\void main() {
    \\    v_pos = position;
    \\    gl_Position = vec4(position * u_radius + u_center, 0.0, 1.0);
    \\}
;

const stone_fs_source =
    \\#version 330
    \\in vec2 v_pos;
    \\uniform vec4 u_color;
    \\out vec4 frag_color;
    \\void main() {
    \\    float d = length(v_pos);
    \\    if (d > 1.0) discard;
    \\    float a = smoothstep(1.0, 0.82, d);
    \\    vec3 shaded = u_color.rgb * (1.18 - d * 0.35);
    \\    frag_color = vec4(shaded, u_color.a * a);
    \\}
;

const stone_quad_vertices = [_]f32{
    -1.0, -1.0,
     1.0, -1.0,
     1.0,  1.0,
    -1.0, -1.0,
     1.0,  1.0,
    -1.0,  1.0,
};

fn spawnPieceEntity(row: usize, col: usize, piece: u8) void {
    const cx = BOARD_MIN + @as(f32, @floatFromInt(col)) * BOARD_STEP;
    const cy = BOARD_MIN + @as(f32, @floatFromInt(row)) * BOARD_STEP;
    const color: [4]f32 = if (piece == PLAYER)
        .{ 0.94, 0.95, 0.94, 1.0 }
    else
        .{ 0.14, 0.14, 0.15, 1.0 };

    const entity = state.registry.create() catch return;
    state.registry.add(entity, BoardCoord{ .row = row, .col = col }) catch {};
    state.registry.add(entity, StonePiece{ .piece = piece }) catch {};
    state.registry.add(entity, Transform{ .x = cx, .y = cy, .radius = BOARD_STEP * 0.44 }) catch {};
    state.registry.add(entity, Renderable{ .color = color }) catch {};
}

fn resetGame() void {
    state.registry.clear();
    state.board = [_][BOARD_SIZE]u8{[_]u8{0} ** BOARD_SIZE} ** BOARD_SIZE;
    state.move_count = 0;
    state.game_over = false;
    state.winner = 0;
    std.debug.print("Board & ECS entities reset. New game started!\n", .{});
}

fn checkWin(row: usize, col: usize, piece: u8) void {
    const directions = [_][2]i32{
        .{ 1, 0 },  // Horizontal
        .{ 0, 1 },  // Vertical
        .{ 1, 1 },  // Main diagonal
        .{ 1, -1 }, // Anti diagonal
    };

    for (directions) |dir| {
        var count: u32 = 1;

        // Forward
        var step: i32 = 1;
        while (step < 5) : (step += 1) {
            const r = @as(i32, @intCast(row)) + dir[0] * step;
            const c = @as(i32, @intCast(col)) + dir[1] * step;
            if (r >= 0 and r < BOARD_SIZE and c >= 0 and c < BOARD_SIZE) {
                if (state.board[@intCast(r)][@intCast(c)] == piece) {
                    count += 1;
                } else break;
            } else break;
        }

        // Backward
        step = 1;
        while (step < 5) : (step += 1) {
            const r = @as(i32, @intCast(row)) - dir[0] * step;
            const c = @as(i32, @intCast(col)) - dir[1] * step;
            if (r >= 0 and r < BOARD_SIZE and c >= 0 and c < BOARD_SIZE) {
                if (state.board[@intCast(r)][@intCast(c)] == piece) {
                    count += 1;
                } else break;
            } else break;
        }

        if (count >= 5) {
            state.game_over = true;
            state.winner = piece;
            const winner_name = if (piece == PLAYER) "PLAYER (White)" else "BOT (Black)";
            std.debug.print("Game Over! Winner: {s}\nPress SPACE to restart.\n", .{winner_name});
            return;
        }
    }
}

fn botMove(last_r: usize, last_c: usize) void {
    // Intelligent local search: find empty cell neighboring the player's last move
    const offsets = [_][2]i32{
        .{ 0, 1 },  .{ 0, -1 }, .{ 1, 0 },  .{ -1, 0 },
        .{ 1, 1 },  .{ 1, -1 }, .{ -1, 1 }, .{ -1, -1 },
        .{ 0, 2 },  .{ 0, -2 }, .{ 2, 0 },  .{ -2, 0 },
    };

    for (offsets) |off| {
        const nr = @as(i32, @intCast(last_r)) + off[0];
        const nc = @as(i32, @intCast(last_c)) + off[1];
        if (nr >= 0 and nr < BOARD_SIZE and nc >= 0 and nc < BOARD_SIZE) {
            const unr: usize = @intCast(nr);
            const unc: usize = @intCast(nc);
            if (state.board[unr][unc] == EMPTY) {
                state.board[unr][unc] = BOT;
                state.move_count += 1;
                spawnPieceEntity(unr, unc, BOT);
                checkWin(unr, unc, BOT);
                return;
            }
        }
    }

    // Fallback: first empty space
    for (0..BOARD_SIZE) |r| {
        for (0..BOARD_SIZE) |c| {
            if (state.board[r][c] == EMPTY) {
                state.board[r][c] = BOT;
                state.move_count += 1;
                spawnPieceEntity(r, c, BOT);
                checkWin(r, c, BOT);
                return;
            }
        }
    }
}

export fn input(event: ?*const sapp.Event) void {
    const ev = event orelse return;

    if (ev.type == .KEY_DOWN and ev.key_code == .SPACE) {
        resetGame();
        return;
    }

    if (ev.type == .MOUSE_DOWN and ev.mouse_button == .LEFT and !state.game_over) {
        // Convert screen pixel coords (0..width, 0..height) to WebGL clip coords (-1.0..1.0)
        const norm_x = (ev.mouse_x / sapp.widthf()) * 2.0 - 1.0;
        const norm_y = 1.0 - (ev.mouse_y / sapp.heightf()) * 2.0;

        const c_f = (norm_x - BOARD_MIN) / BOARD_STEP;
        const r_f = (norm_y - BOARD_MIN) / BOARD_STEP;
        const col = @as(i32, @intFromFloat(@round(c_f)));
        const row = @as(i32, @intFromFloat(@round(r_f)));

        if (col >= 0 and col < BOARD_SIZE and row >= 0 and row < BOARD_SIZE) {
            const uc: usize = @intCast(col);
            const ur: usize = @intCast(row);
            if (state.board[ur][uc] == EMPTY) {
                state.board[ur][uc] = PLAYER;
                state.move_count += 1;
                spawnPieceEntity(ur, uc, PLAYER);
                checkWin(ur, uc, PLAYER);

                if (!state.game_over) {
                    botMove(ur, uc);
                }
            }
        }
    }
}

export fn init() void {
    // 0. Initialize ECS Registry (World)
    state.registry = ecs.Registry.init(std.heap.page_allocator);

    // 1. Initialize low-level Sokol environment
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    // 2. Build Grid Line Buffer via WebGL API
    var line_verts: [BOARD_SIZE * 4 * 2]f32 = undefined;
    var v_idx: usize = 0;
    for (0..BOARD_SIZE) |i| {
        const p = BOARD_MIN + @as(f32, @floatFromInt(i)) * BOARD_STEP;
        // Horizontal line
        line_verts[v_idx] = BOARD_MIN; v_idx += 1;
        line_verts[v_idx] = p;         v_idx += 1;
        line_verts[v_idx] = BOARD_MAX; v_idx += 1;
        line_verts[v_idx] = p;         v_idx += 1;

        // Vertical line
        line_verts[v_idx] = p;         v_idx += 1;
        line_verts[v_idx] = BOARD_MIN; v_idx += 1;
        line_verts[v_idx] = p;         v_idx += 1;
        line_verts[v_idx] = BOARD_MAX; v_idx += 1;
    }
    line_vertex_count = @intCast(v_idx / 2);

    line_vbo = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, line_vbo);
    gl.bufferDataSlice(gl.ARRAY_BUFFER, f32, line_verts[0..v_idx], gl.STATIC_DRAW);

    // 3. Build Line Shader Program via WebGL API
    const l_vs = gl.createShader(gl.VERTEX_SHADER).?;
    gl.shaderSource(l_vs, line_vs_source);
    gl.compileShader(l_vs);

    const l_fs = gl.createShader(gl.FRAGMENT_SHADER).?;
    gl.shaderSource(l_fs, line_fs_source);
    gl.compileShader(l_fs);

    line_prog = gl.createProgram().?;
    gl.attachShader(line_prog, l_vs);
    gl.attachShader(line_prog, l_fs);
    gl.linkProgram(line_prog);

    line_pos_loc = gl.getAttribLocation(line_prog, "position");
    line_color_loc = gl.getUniformLocation(line_prog, "u_color");

    // 4. Build Stone Quad Buffer via WebGL API
    stone_vbo = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, stone_vbo);
    gl.bufferDataSlice(gl.ARRAY_BUFFER, f32, &stone_quad_vertices, gl.STATIC_DRAW);

    // 5. Build Stone Shader Program via WebGL API
    const s_vs = gl.createShader(gl.VERTEX_SHADER).?;
    gl.shaderSource(s_vs, stone_vs_source);
    gl.compileShader(s_vs);

    const s_fs = gl.createShader(gl.FRAGMENT_SHADER).?;
    gl.shaderSource(s_fs, stone_fs_source);
    gl.compileShader(s_fs);

    stone_prog = gl.createProgram().?;
    gl.attachShader(stone_prog, s_vs);
    gl.attachShader(stone_prog, s_fs);
    gl.linkProgram(stone_prog);

    stone_pos_loc = gl.getAttribLocation(stone_prog, "position");
    stone_center_loc = gl.getUniformLocation(stone_prog, "u_center");
    stone_radius_loc = gl.getUniformLocation(stone_prog, "u_radius");
    stone_color_loc = gl.getUniformLocation(stone_prog, "u_color");
}

export fn frame() void {
    // 1. WebGL Viewport and Clear
    gl.viewport(0, 0, sapp.width(), sapp.height());
    gl.clearColor(0.08, 0.16, 0.12, 1.0); // Chalkboard slate dark-green
    gl.clear(gl.COLOR_BUFFER_BIT);

    // 2. Render Grid Lines via WebGL API
    gl.useProgram(line_prog);
    gl.bindBuffer(gl.ARRAY_BUFFER, line_vbo);
    gl.enableVertexAttribArray(@intCast(line_pos_loc));
    gl.vertexAttribPointer(@intCast(line_pos_loc), 2, gl.FLOAT, false, 0, 0);
    gl.uniform4f(line_color_loc, 0.40, 0.52, 0.46, 1.0);
    gl.drawArrays(gl.LINES, 0, line_vertex_count);

    // 3. Render Pieces via ECS Multi-Component Query (Transform, Renderable, StonePiece) & WebGL API
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.useProgram(stone_prog);
    gl.bindBuffer(gl.ARRAY_BUFFER, stone_vbo);
    gl.enableVertexAttribArray(@intCast(stone_pos_loc));
    gl.vertexAttribPointer(@intCast(stone_pos_loc), 2, gl.FLOAT, false, 0, 0);

    var query = state.registry.viewMulti(.{ Transform, Renderable, StonePiece });
    while (query.next()) |item| {
        const trans = item[1];
        const rend = item[2];

        gl.uniform2f(stone_center_loc, trans.x, trans.y);
        gl.uniform1f(stone_radius_loc, trans.radius);
        gl.uniform4f(stone_color_loc, rend.color[0], rend.color[1], rend.color[2], rend.color[3]);

        gl.drawArrays(gl.TRIANGLES, 0, 6);
    }

    // 4. Present WebGL frame (commits Sokol render pass)
    gl.present();
}

export fn cleanup() void {
    state.registry.deinit();
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = input,
        .width = 720,
        .height = 720,
        .window_title = "Caro Gomoku (ECS + WebGL on Sokol)",
        .logger = .{ .func = slog.func },
    });
}