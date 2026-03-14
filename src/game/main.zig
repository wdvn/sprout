const std = @import("std");
const game = @import("gomoku.zig");
const sokol = @import("sokol");
const gfx = sokol.gfx;
const app = sokol.app;
const glue = sokol.glue;

var g: game.Gomoku = undefined;

var line_pip: gfx.Pipeline = undefined;
var line_bind: gfx.Bindings = undefined;
var stone_pip: gfx.Pipeline = undefined;
var stone_bind: gfx.Bindings = undefined;

const line_vertices = [_]f32{
    // vertical lines
    -0.9, -0.9, -0.9, 0.9, -0.8, -0.9, -0.8, 0.9, -0.7, -0.9, -0.7, 0.9, -0.6, -0.9, -0.6, 0.9, -0.5, -0.9, -0.5, 0.9, -0.4, -0.9, -0.4, 0.9, -0.3, -0.9, -0.3, 0.9, -0.2, -0.9, -0.2, 0.9, -0.1, -0.9, -0.1, 0.9, 0.0, -0.9, 0.0, 0.9, 0.1, -0.9, 0.1, 0.9, 0.2, -0.9, 0.2, 0.9, 0.3, -0.9, 0.3, 0.9, 0.4, -0.9, 0.4, 0.9, 0.5, -0.9, 0.5, 0.9,
    // horizontal lines
    -0.9, -0.9, 0.9, -0.9, -0.9, -0.8, 0.9, -0.8, -0.9, -0.7, 0.9, -0.7, -0.9, -0.6, 0.9, -0.6, -0.9, -0.5, 0.9, -0.5, -0.9, -0.4, 0.9, -0.4, -0.9, -0.3, 0.9, -0.3, -0.9, -0.2, 0.9, -0.2, -0.9, -0.1, 0.9, -0.1, -0.9, 0.0, 0.9, 0.0, -0.9, 0.1, 0.9, 0.1, -0.9, 0.2, 0.9, 0.2, -0.9, 0.3, 0.9, 0.3, -0.9, 0.4, 0.9, 0.4, -0.9, 0.5, 0.9, 0.5,
};

const stone_vertices = [_]f32{
    0.0, 0.0,
};

fn event(e: [*c]const app.Event) callconv(.c) void {
    if (g.winner != null) {
        if (e.*.type == .KEY_DOWN and e.*.key_code == .SPACE) {
            g = game.Gomoku.init();
        }
        return;
    }

    if (e.*.type == .MOUSE_DOWN) {
        const x = e.*.mouse_x;
        const y = e.*.mouse_y;
        const width = app.widthf();
        const height = app.heightf();
        const col = @floor((x / width) * 15);
        const row = @floor((y / height) * 15);
        if (col >= 0 and col < 15 and row >= 0 and row < 15) {
            if (g.board[@intFromFloat(row)][@intFromFloat(col)] == .empty) {
                g.board[@intFromFloat(row)][@intFromFloat(col)] = g.current_player;
                g.check_win(@intFromFloat(row), @intFromFloat(col));
                if (g.winner == null) {
                    g.current_player = if (g.current_player == .black) .white else .black;
                }
            }
        }
    }
}

fn init() callconv(.c) void {
    g = game.Gomoku.init();
    var desc = std.mem.zeroes(gfx.Desc);
    desc.environment = glue.environment();
    gfx.setup(desc);

    // line pipeline
    var line_vbuf_desc = std.mem.zeroes(gfx.BufferDesc);
    line_vbuf_desc.data = gfx.asRange(&line_vertices);
    line_vbuf_desc.label = "lines-vertices";
    line_bind.vertex_buffers[0] = gfx.makeBuffer(line_vbuf_desc);

    var line_shd_desc = std.mem.zeroes(gfx.ShaderDesc);
    line_shd_desc.vertex_func.source = 
        \\#version 330
        \\in vec2 position;
        \\void main() {
        \\    gl_Position = vec4(position, 0.0, 1.0);
        \\}
    ;
    line_shd_desc.fragment_func.source = 
        \\#version 330
        \\out vec4 frag_color;
        \\void main() {
        \\    frag_color = vec4(0.0, 0.0, 0.0, 1.0);
        \\}
    ;
    line_shd_desc.attrs[0].glsl_name = "position";
    const line_shd = gfx.makeShader(line_shd_desc);

    var line_pip_desc = std.mem.zeroes(gfx.PipelineDesc);
    line_pip_desc.shader = line_shd;
    line_pip_desc.layout.attrs[0].format = .FLOAT2;
    line_pip_desc.primitive_type = .LINES;
    line_pip = gfx.makePipeline(line_pip_desc);

    // stone pipeline
    var stone_vbuf_desc = std.mem.zeroes(gfx.BufferDesc);
    stone_vbuf_desc.data = gfx.asRange(&stone_vertices);
    stone_vbuf_desc.label = "stone-vertices";
    stone_bind.vertex_buffers[0] = gfx.makeBuffer(stone_vbuf_desc);

    var stone_shd_desc = std.mem.zeroes(gfx.ShaderDesc);
    stone_shd_desc.vertex_func.source = 
        \\#version 330
        \\in vec2 position;
        \\uniform vec2 center;
        \\uniform vec4 color;
        \\out vec4 v_color;
        \\void main() {
        \\    gl_Position = vec4(position + center, 0.0, 1.0);
        \\    v_color = color;
        \\    gl_PointSize = 10.0;
        \\}
    ;
    stone_shd_desc.fragment_func.source = 
        \\#version 330
        \\in vec4 v_color;
        \\out vec4 frag_color;
        \\void main() {
        \\    vec2 coord = gl_PointCoord - vec2(0.5);
        \\    if(length(coord) > 0.5) discard;
        \\    frag_color = v_color;
        \\}
    ;
    stone_shd_desc.attrs[0].glsl_name = "position";
    
    // Define uniforms
    stone_shd_desc.uniform_blocks[0] = .{
        .stage = .VERTEX,
        .size = @sizeOf(f32) * 6,
    };
    const stone_shd = gfx.makeShader(stone_shd_desc);

    var stone_pip_desc = std.mem.zeroes(gfx.PipelineDesc);
    stone_pip_desc.shader = stone_shd;
    stone_pip_desc.layout.attrs[0].format = .FLOAT2;
    stone_pip_desc.primitive_type = .POINTS;
    stone_pip = gfx.makePipeline(stone_pip_desc);
}

fn frame() callconv(.c) void {
    const pass_action = std.mem.zeroes(gfx.PassAction);
    gfx.beginPass(.{ .action = pass_action, .swapchain = glue.swapchain() });
    
    // draw lines
    gfx.applyPipeline(line_pip);
    gfx.applyBindings(line_bind);
    gfx.draw(0, line_vertices.len / 2, 1);

    // draw stones
    gfx.applyPipeline(stone_pip);
    gfx.applyBindings(stone_bind);
    for (g.board, 0..) |row, r| {
        for (row, 0..) |cell, c| {
            if (cell != .empty) {
                const x = @as(f32, @floatFromInt(c)) / 15.0 * 1.8 - 0.9;
                const y = @as(f32, @floatFromInt(r)) / 15.0 * 1.8 - 0.9;
                const color = if (cell == .black) [4]f32{0.0, 0.0, 0.0, 1.0} else [4]f32{1.0, 1.0, 1.0, 1.0};
                
                const vs_params = struct {
                    center: [2]f32,
                    color: [4]f32,
                }{
                    .center = .{x, y},
                    .color = color,
                };
                
                gfx.applyUniforms(0, gfx.asRange(&vs_params));
                gfx.draw(0, 1, 1);
            }
        }
    }

    gfx.endPass();
    gfx.commit();
}

fn cleanup() callconv(.c) void {
    gfx.shutdown();
}

pub fn main() !void {
    var desc = std.mem.zeroes(app.Desc);
    desc.init_cb = init;
    desc.frame_cb = frame;
    desc.cleanup_cb = cleanup;
    desc.event_cb = event;
    desc.width = 800;
    desc.height = 600;
    desc.window_title = "Gomoku";
    app.run(desc);
}
