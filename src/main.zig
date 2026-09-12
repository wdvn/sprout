const std = @import("std");
const sokol = @import("sokol");
const sapp = sokol.app;
const sg = sokol.gfx;
const sglue = sokol.glue;
const slog = sokol.log;

const libs = @import("libs");
const gl = libs.gl;
const ecs = libs.ecs;

// ============================================================================
// Sprout Game Specifications (From Readme.md)
// - Map grid: 8 * 10 cells (8 rows, 10 columns)
// - Party: Up to 6 members
// ============================================================================

pub const GRID_COLS: usize = 10;
pub const GRID_ROWS: usize = 8;
pub const MAX_PARTY_MEMBERS: usize = 6;

// Screen layout
const GRID_LEFT: f32 = -0.85;
const GRID_RIGHT: f32 = 0.85;
const GRID_BOTTOM: f32 = -0.75;
const GRID_TOP: f32 = 0.75;

const CELL_W: f32 = (GRID_RIGHT - GRID_LEFT) / @as(f32, @floatFromInt(GRID_COLS));
const CELL_H: f32 = (GRID_TOP - GRID_BOTTOM) / @as(f32, @floatFromInt(GRID_ROWS));

// ============================================================================
// ECS Components
// ============================================================================

pub const GridPos = struct {
    col: i32,
    row: i32,
};

pub const Transform = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

pub const Renderable = struct {
    color: [4]f32,
    border_color: [4]f32,
};

pub const Tile = struct {
    walkable: bool = true,
    selected: bool = false,
};

pub const Cultivator = struct {
    slot: u8,
    name: [16]u8 = [_]u8{0} ** 16,
    name_len: usize = 0,
    hp: i32 = 100,
    max_hp: i32 = 100,
    mana: i32 = 50,
    max_mana: i32 = 50,
};

// ============================================================================
// Engine & Game State
// ============================================================================

pub const EngineState = struct {
    registry: ecs.Registry = undefined,
    selected_col: ?i32 = null,
    selected_row: ?i32 = null,
    active_member: u8 = 0,
    party_count: u8 = 0,
};

var state = EngineState{};

// WebGL Resources
var quad_prog: gl.Program = .{};
var quad_vbo: gl.Buffer = .{};
var quad_pos_loc: gl.AttribLocation = -1;
var u_rect_loc: gl.UniformLocation = .{};
var u_color_loc: gl.UniformLocation = .{};
var u_border_color_loc: gl.UniformLocation = .{};

// GLSL Shaders for Tile & Entity Rendering
const quad_vs_source =
    \\#version 330
    \\in vec2 position;
    \\uniform vec4 u_rect;
    \\out vec2 v_uv;
    \\void main() {
    \\    v_uv = position;
    \\    vec2 pos = position * vec2(u_rect.z, u_rect.w) + vec2(u_rect.x, u_rect.y);
    \\    gl_Position = vec4(pos, 0.0, 1.0);
    \\}
;

const quad_fs_source =
    \\#version 330
    \\in vec2 v_uv;
    \\uniform vec4 u_color;
    \\uniform vec4 u_border_color;
    \\out vec4 frag_color;
    \\void main() {
    \\    vec2 d = abs(v_uv);
    \\    if (d.x > 0.88 || d.y > 0.88) {
    \\        frag_color = u_border_color;
    \\    } else {
    \\        frag_color = u_color;
    \\    }
    \\}
;

// Unit quad vertices [-1, 1]
const unit_quad_vertices = [_]f32{
    -1.0, -1.0,
     1.0, -1.0,
     1.0,  1.0,
    -1.0, -1.0,
     1.0,  1.0,
    -1.0,  1.0,
};

// Cultivator preset party palette
const party_colors = [_][4]f32{
    .{ 0.20, 0.75, 0.50, 1.0 }, // Jade Cultivator (Slot 1)
    .{ 0.85, 0.70, 0.25, 1.0 }, // Golden Core (Slot 2)
    .{ 0.30, 0.60, 0.90, 1.0 }, // Azure Mist (Slot 3)
    .{ 0.85, 0.35, 0.40, 1.0 }, // Crimson Flame (Slot 4)
    .{ 0.70, 0.45, 0.85, 1.0 }, // Violet Thunder (Slot 5)
    .{ 0.90, 0.55, 0.20, 1.0 }, // Amber Earth (Slot 6)
};

const party_names = [_][]const u8{
    "Linh Phong",
    "Bach Van",
    "Thanh Thao",
    "Loi Chan",
    "Tieu Diep",
    "Ha Vu",
};

// ============================================================================
// Sprout Logic & Systems
// ============================================================================

fn initGridMap() void {
    for (0..GRID_ROWS) |r| {
        for (0..GRID_COLS) |c| {
            const col: i32 = @intCast(c);
            const row: i32 = @intCast(r);

            const x = GRID_LEFT + (@as(f32, @floatFromInt(col)) + 0.5) * CELL_W;
            const y = GRID_BOTTOM + (@as(f32, @floatFromInt(row)) + 0.5) * CELL_H;
            const hw = CELL_W * 0.46;
            const hh = CELL_H * 0.46;

            const entity = state.registry.create() catch continue;
            state.registry.add(entity, GridPos{ .col = col, .row = row }) catch {};
            state.registry.add(entity, Transform{ .x = x, .y = y, .w = hw, .h = hh }) catch {};

            // Checkerboard subtle terrain shading
            const is_alt = (c + r) % 2 == 1;
            const bg_color: [4]f32 = if (is_alt)
                .{ 0.08, 0.14, 0.11, 1.0 }
            else
                .{ 0.06, 0.11, 0.09, 1.0 };

            state.registry.add(entity, Renderable{
                .color = bg_color,
                .border_color = .{ 0.12, 0.22, 0.17, 1.0 },
            }) catch {};

            state.registry.add(entity, Tile{
                .walkable = true,
                .selected = false,
            }) catch {};
        }
    }
}

fn spawnCultivator(col: i32, row: i32, slot: u8) !void {
    if (slot >= MAX_PARTY_MEMBERS) return;

    const x = GRID_LEFT + (@as(f32, @floatFromInt(col)) + 0.5) * CELL_W;
    const y = GRID_BOTTOM + (@as(f32, @floatFromInt(row)) + 0.5) * CELL_H;
    const hw = CELL_W * 0.36;
    const hh = CELL_H * 0.36;

    const entity = try state.registry.create();
    try state.registry.add(entity, GridPos{ .col = col, .row = row });
    try state.registry.add(entity, Transform{ .x = x, .y = y, .w = hw, .h = hh });

    var cult = Cultivator{
        .slot = slot,
        .hp = 100,
        .max_hp = 100,
        .mana = 50,
        .max_mana = 50,
    };
    const name = party_names[slot];
    @memcpy(cult.name[0..name.len], name);
    cult.name_len = name.len;

    try state.registry.add(entity, cult);
    try state.registry.add(entity, Renderable{
        .color = party_colors[slot],
        .border_color = .{ 1.0, 1.0, 1.0, 1.0 },
    });

    state.party_count = @max(state.party_count, slot + 1);
    std.debug.print("Spawned Cultivator #{d} [{s}] at cell ({d}, {d})\n", .{ slot + 1, name, col, row });
}

// ============================================================================
// Sokol Application Callbacks
// ============================================================================

export fn input(event: ?*const sapp.Event) void {
    const ev = event orelse return;

    // Keyboard controls
    if (ev.type == .KEY_DOWN) {
        switch (ev.key_code) {
            .ESCAPE => sapp.requestQuit(),
            ._1, ._2, ._3, ._4, ._5, ._6 => {
                const key_idx = @intFromEnum(ev.key_code) - @intFromEnum(sapp.Keycode._1);
                state.active_member = @intCast(key_idx);
                std.debug.print("Selected Party Member Slot #{d}\n", .{state.active_member + 1});
            },
            .R => {
                state.registry.clear();
                initGridMap();
                state.party_count = 0;
                // Spawn default cultivator
                spawnCultivator(1, 1, 0) catch {};
                spawnCultivator(2, 2, 1) catch {};
                std.debug.print("Reset Sprout World (8x10 Grid).\n", .{});
            },
            else => {},
        }
        return;
    }

    // Mouse click: Select tile or move active party member
    if (ev.type == .MOUSE_DOWN and ev.mouse_button == .LEFT) {
        const norm_x = (ev.mouse_x / sapp.widthf()) * 2.0 - 1.0;
        const norm_y = 1.0 - (ev.mouse_y / sapp.heightf()) * 2.0;

        if (norm_x >= GRID_LEFT and norm_x <= GRID_RIGHT and norm_y >= GRID_BOTTOM and norm_y <= GRID_TOP) {
            const col = @as(i32, @intFromFloat(@floor((norm_x - GRID_LEFT) / CELL_W)));
            const row = @as(i32, @intFromFloat(@floor((norm_y - GRID_BOTTOM) / CELL_H)));

            if (col >= 0 and col < GRID_COLS and row >= 0 and row < GRID_ROWS) {
                state.selected_col = col;
                state.selected_row = row;

                // Move active cultivator or spawn
                spawnCultivator(col, row, state.active_member) catch {};
            }
        }
    }
}

export fn init() void {
    // 1. Initialize ECS Registry (World)
    state.registry = ecs.Registry.init(std.heap.page_allocator);

    // 2. Initialize low-level Sokol environment
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    // 3. Setup WebGL Shaders & Quad Buffer
    quad_vbo = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, quad_vbo);
    gl.bufferDataSlice(gl.ARRAY_BUFFER, f32, &unit_quad_vertices, gl.STATIC_DRAW);

    const vs = gl.createShader(gl.VERTEX_SHADER).?;
    gl.shaderSource(vs, quad_vs_source);
    gl.compileShader(vs);

    const fs = gl.createShader(gl.FRAGMENT_SHADER).?;
    gl.shaderSource(fs, quad_fs_source);
    gl.compileShader(fs);

    quad_prog = gl.createProgram().?;
    gl.attachShader(quad_prog, vs);
    gl.attachShader(quad_prog, fs);
    gl.linkProgram(quad_prog);

    quad_pos_loc = gl.getAttribLocation(quad_prog, "position");
    u_rect_loc = gl.getUniformLocation(quad_prog, "u_rect");
    u_color_loc = gl.getUniformLocation(quad_prog, "u_color");
    u_border_color_loc = gl.getUniformLocation(quad_prog, "u_border_color");

    // 4. Initialize Sprout 8x10 Grid Map
    initGridMap();

    // 5. Spawn starting party members (Slots 1 & 2)
    spawnCultivator(1, 2, 0) catch {};
    spawnCultivator(1, 4, 1) catch {};

    std.debug.print("Sprout Engine Started. Map: 8x10 cells. Press 1-6 to choose member, Click tile to move/spawn.\n", .{});
}

export fn frame() void {
    // 1. Viewport & Clear
    gl.viewport(0, 0, sapp.width(), sapp.height());
    gl.clearColor(0.04, 0.07, 0.06, 1.0); // Deep jade-black night atmosphere
    gl.clear(gl.COLOR_BUFFER_BIT);

    // 2. Setup WebGL Program and Buffers for rendering
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.useProgram(quad_prog);
    gl.bindBuffer(gl.ARRAY_BUFFER, quad_vbo);
    gl.enableVertexAttribArray(@intCast(quad_pos_loc));
    gl.vertexAttribPointer(@intCast(quad_pos_loc), 2, gl.FLOAT, false, 0, 0);

    // 3. Render Grid Tiles via ECS Query
    var tile_query = state.registry.viewMulti(.{ Transform, Renderable, Tile, GridPos });
    while (tile_query.next()) |item| {
        const trans = item[1];
        const rend = item[2];
        const gpos = item[4];

        var border_col = rend.border_color;
        var fill_col = rend.color;

        // Highlight selected cell
        if (state.selected_col == gpos.col and state.selected_row == gpos.row) {
            border_col = .{ 0.95, 0.85, 0.35, 1.0 }; // Luminous gold border
            fill_col = .{ 0.12, 0.24, 0.18, 1.0 };
        }

        gl.uniform4f(u_rect_loc, trans.x, trans.y, trans.w, trans.h);
        gl.uniform4f(u_color_loc, fill_col[0], fill_col[1], fill_col[2], fill_col[3]);
        gl.uniform4f(u_border_color_loc, border_col[0], border_col[1], border_col[2], border_col[3]);
        gl.drawArrays(gl.TRIANGLES, 0, 6);
    }

    // 4. Render Cultivator Party Members via ECS Query
    var cult_query = state.registry.viewMulti(.{ Transform, Renderable, Cultivator });
    while (cult_query.next()) |item| {
        const trans = item[1];
        const rend = item[2];
        const cult = item[3];

        var border = rend.border_color;
        if (cult.slot == state.active_member) {
            border = .{ 1.0, 1.0, 0.3, 1.0 }; // Active member halo
        }

        gl.uniform4f(u_rect_loc, trans.x, trans.y, trans.w, trans.h);
        gl.uniform4f(u_color_loc, rend.color[0], rend.color[1], rend.color[2], rend.color[3]);
        gl.uniform4f(u_border_color_loc, border[0], border[1], border[2], border[3]);
        gl.drawArrays(gl.TRIANGLES, 0, 6);
    }

    // 5. Present Frame
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
        .width = 860,
        .height = 700,
        .window_title = "Sprout — Cultivator Party RPG (WebGL on Sokol + ECS)",
        .logger = .{ .func = slog.func },
    });
}
