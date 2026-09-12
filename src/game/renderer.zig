const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sdtx = sokol.debugtext;
const slog = sokol.log;
const sapp = sokol.app;

const libs = @import("libs");
const gl = libs.gl;
pub const font_data = @import("font_data.zig");
pub const typography = @import("typography.zig");

// Nhúng trực tiếp các file ảnh raw RGBA đã sinh và crop
const battle_bg_bytes = @embedFile("assets/battle_bg.raw");
const dungeon_bg_bytes = @embedFile("assets/dungeon_bg.raw");
const player_bytes = @embedFile("assets/player.raw");
const dragon_bytes = @embedFile("assets/dragon.raw");
const fox_bytes = @embedFile("assets/fox.raw");
const turtle_bytes = @embedFile("assets/turtle.raw");
const bird_bytes = @embedFile("assets/bird.raw");
const font_atlas_bytes = @embedFile("assets/font_atlas.raw");

pub const TextureId = enum(u8) {
    battle_bg,
    dungeon_bg,
    player,
    dragon,
    fox,
    turtle,
    bird,
    font_atlas,
};

pub const TexUniformBlock = extern struct {
    rect: [4]f32,
    color: [4]f32,
};

pub const TextUniformBlock = extern struct {
    rect: [4]f32,
    uv_rect: [4]f32,
    color: [4]f32,
};

var tex_pip: sg.Pipeline = .{};
var text_pip: sg.Pipeline = .{};
var tex_vbo: sg.Buffer = .{};
var shared_sampler: sg.Sampler = .{};
var texture_views: [8]sg.View = [_]sg.View{.{}} ** 8;

const unit_quad_vertices = [_]f32{
    -1.0, -1.0,
     1.0, -1.0,
     1.0,  1.0,
    -1.0, -1.0,
     1.0,  1.0,
    -1.0,  1.0,
};

const tex_vs_src =
    \\#version 330
    \\in vec2 position;
    \\uniform vec4 u_rect;
    \\uniform vec4 u_color;
    \\out vec2 v_uv;
    \\void main() {
    \\    v_uv = position * 0.5 + 0.5;
    \\    v_uv.y = 1.0 - v_uv.y;
    \\    vec2 pos = position * vec2(u_rect.z, u_rect.w) + vec2(u_rect.x, u_rect.y);
    \\    gl_Position = vec4(pos, 0.0, 1.0);
    \\}
;

const tex_fs_src =
    \\#version 330
    \\uniform sampler2D u_tex;
    \\uniform vec4 u_rect;
    \\uniform vec4 u_color;
    \\in vec2 v_uv;
    \\out vec4 frag_color;
    \\void main() {
    \\    vec4 tex = texture(u_tex, v_uv);
    \\    vec2 half_px = u_rect.zw * vec2(480.0, 380.0);
    \\    vec2 p = (v_uv * 2.0 - 1.0) * half_px;
    \\    float r = min(8.0, min(half_px.x, half_px.y) - 1.0);
    \\    if (r < 0.0) r = 0.0;
    \\    vec2 q = abs(p) - half_px + vec2(r);
    \\    float dist = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
    \\    float clip_a = 1.0 - smoothstep(0.0, 1.2, dist);
    \\    if (clip_a <= 0.002) discard;
    \\    frag_color = vec4(tex.rgb * u_color.rgb, tex.a * u_color.a * clip_a);
    \\}
;

const text_vs_src =
    \\#version 330
    \\in vec2 position;
    \\uniform vec4 u_rect;
    \\uniform vec4 u_uv;
    \\uniform vec4 u_color;
    \\out vec2 v_uv;
    \\out vec4 v_color;
    \\void main() {
    \\    float tx = position.x * 0.5 + 0.5;
    \\    float ty = 0.5 - position.y * 0.5;
    \\    v_uv = vec2(mix(u_uv.x, u_uv.z, tx), mix(u_uv.y, u_uv.w, ty));
    \\    vec2 pos = position * vec2(u_rect.z, u_rect.w) + vec2(u_rect.x, u_rect.y);
    \\    gl_Position = vec4(pos, 0.0, 1.0);
    \\    v_color = u_color;
    \\}
;

const text_fs_src =
    \\#version 330
    \\uniform sampler2D u_tex;
    \\in vec2 v_uv;
    \\in vec4 v_color;
    \\out vec4 frag_color;
    \\void main() {
    \\    vec4 tex = texture(u_tex, v_uv);
    \\    float alpha = tex.a * v_color.a;
    \\    if (alpha <= 0.005) discard;
    \\    frag_color = vec4(v_color.rgb, alpha);
    \\}
;

fn makeTextureView(w: i32, h: i32, bytes: []const u8) sg.View {
    var img_data: sg.ImageData = .{};
    img_data.mip_levels[0] = .{
        .ptr = bytes.ptr,
        .size = bytes.len,
    };
    const img = sg.makeImage(.{
        .width = w,
        .height = h,
        .pixel_format = .RGBA8,
        .data = img_data,
    });
    return sg.makeView(.{
        .texture = .{ .image = img },
    });
}

pub fn init() void {
    // 1. Tạo VBO cho Quad có texture
    tex_vbo = sg.makeBuffer(.{
        .data = .{
            .ptr = &unit_quad_vertices,
            .size = @sizeOf(@TypeOf(unit_quad_vertices)),
        },
        .usage = .{ .vertex_buffer = true },
    });

    // 2. Tạo Shared Sampler
    shared_sampler = sg.makeSampler(.{
        .min_filter = .LINEAR,
        .mag_filter = .LINEAR,
    });

    // 3. Khởi tạo các Texture Views từ raw bytes
    texture_views[@intFromEnum(TextureId.battle_bg)] = makeTextureView(512, 288, battle_bg_bytes);
    texture_views[@intFromEnum(TextureId.dungeon_bg)] = makeTextureView(512, 288, dungeon_bg_bytes);
    texture_views[@intFromEnum(TextureId.player)] = makeTextureView(128, 128, player_bytes);
    texture_views[@intFromEnum(TextureId.dragon)] = makeTextureView(256, 256, dragon_bytes);
    texture_views[@intFromEnum(TextureId.fox)] = makeTextureView(128, 128, fox_bytes);
    texture_views[@intFromEnum(TextureId.turtle)] = makeTextureView(128, 128, turtle_bytes);
    texture_views[@intFromEnum(TextureId.bird)] = makeTextureView(128, 128, bird_bytes);
    texture_views[@intFromEnum(TextureId.font_atlas)] = makeTextureView(512, 512, font_atlas_bytes);

    // 4. Tạo Texture Shader
    var shd_desc: sg.ShaderDesc = .{};
    shd_desc.vertex_func.source = tex_vs_src.ptr;
    shd_desc.fragment_func.source = tex_fs_src.ptr;
    shd_desc.attrs[0].glsl_name = "position";

    shd_desc.uniform_blocks[0].stage = .VERTEX;
    shd_desc.uniform_blocks[0].size = @sizeOf(TexUniformBlock);
    shd_desc.uniform_blocks[0].layout = .STD140;
    shd_desc.uniform_blocks[0].glsl_uniforms[0] = .{
        .type = .FLOAT4,
        .glsl_name = "u_rect",
    };
    shd_desc.uniform_blocks[0].glsl_uniforms[1] = .{
        .type = .FLOAT4,
        .glsl_name = "u_color",
    };

    shd_desc.views[0] = .{ .texture = .{ .stage = .FRAGMENT } };
    shd_desc.samplers[0] = .{ .stage = .FRAGMENT };
    shd_desc.texture_sampler_pairs[0] = .{
        .stage = .FRAGMENT,
        .view_slot = 0,
        .sampler_slot = 0,
        .glsl_name = "u_tex",
    };

    const shd = sg.makeShader(shd_desc);

    // 5. Tạo Texture Render Pipeline
    var pip_desc: sg.PipelineDesc = .{};
    pip_desc.shader = shd;
    pip_desc.layout.attrs[0].format = .FLOAT2;
    pip_desc.colors[0].blend = .{
        .enabled = true,
        .src_factor_rgb = .SRC_ALPHA,
        .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
        .src_factor_alpha = .ONE,
        .dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
    };
    tex_pip = sg.makePipeline(pip_desc);

    // 6. Tạo Text Shader & Pipeline
    var text_shd_desc: sg.ShaderDesc = .{};
    text_shd_desc.vertex_func.source = text_vs_src.ptr;
    text_shd_desc.fragment_func.source = text_fs_src.ptr;
    text_shd_desc.attrs[0].glsl_name = "position";

    text_shd_desc.uniform_blocks[0].stage = .VERTEX;
    text_shd_desc.uniform_blocks[0].size = @sizeOf(TextUniformBlock);
    text_shd_desc.uniform_blocks[0].layout = .STD140;
    text_shd_desc.uniform_blocks[0].glsl_uniforms[0] = .{
        .type = .FLOAT4,
        .glsl_name = "u_rect",
    };
    text_shd_desc.uniform_blocks[0].glsl_uniforms[1] = .{
        .type = .FLOAT4,
        .glsl_name = "u_uv",
    };
    text_shd_desc.uniform_blocks[0].glsl_uniforms[2] = .{
        .type = .FLOAT4,
        .glsl_name = "u_color",
    };

    text_shd_desc.views[0] = .{ .texture = .{ .stage = .FRAGMENT } };
    text_shd_desc.samplers[0] = .{ .stage = .FRAGMENT };
    text_shd_desc.texture_sampler_pairs[0] = .{
        .stage = .FRAGMENT,
        .view_slot = 0,
        .sampler_slot = 0,
        .glsl_name = "u_tex",
    };

    const text_shd = sg.makeShader(text_shd_desc);

    var text_pip_desc: sg.PipelineDesc = .{};
    text_pip_desc.shader = text_shd;
    text_pip_desc.layout.attrs[0].format = .FLOAT2;
    text_pip_desc.colors[0].blend = .{
        .enabled = true,
        .src_factor_rgb = .SRC_ALPHA,
        .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
        .src_factor_alpha = .ONE,
        .dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
    };
    text_pip = sg.makePipeline(text_pip_desc);

    // 7. Cấu hình sokol-debugtext dự phòng
    var sdtx_desc: sdtx.Desc = .{};
    sdtx_desc.fonts[0] = sdtx.fontCpc();
    sdtx_desc.fonts[1] = sdtx.fontKc853();
    sdtx_desc.fonts[2] = sdtx.fontZ1013();
    sdtx_desc.logger.func = slog.func;
    sdtx.setup(sdtx_desc);

    // 8. Khởi tạo FreeType và HarfBuzz Typography Engine
    _ = typography.engine.init("/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf");

    std.debug.print(">> [Renderer]: Realistic Xianxia Texture, Font Atlas & UI System Initialized!\n", .{});
}

/// Vẽ một hình chữ nhật có kết cấu hình ảnh (Texture Quad)
pub fn drawTexturedQuad(tex_id: TextureId, x: f32, y: f32, w: f32, h: f32, color: [4]f32) void {
    gl.ensurePass();

    var bind: sg.Bindings = .{};
    bind.vertex_buffers[0] = tex_vbo;
    bind.views[0] = texture_views[@intFromEnum(tex_id)];
    bind.samplers[0] = shared_sampler;

    const u = TexUniformBlock{
        .rect = .{ x, y, w, h },
        .color = color,
    };

    sg.applyPipeline(tex_pip);
    sg.applyBindings(bind);
    sg.applyUniforms(0, .{
        .ptr = &u,
        .size = @sizeOf(TexUniformBlock),
    });
    sg.draw(0, 6, 1);
}

/// Helper to draw a square icon (size x size) at given NDC coordinates
pub fn drawIcon(tex_id: TextureId, x: f32, y: f32, size: f32) void {
    // Assuming square icon, width and height = size
    drawTexturedQuad(tex_id, x, y, size, size, .{1.0, 1.0, 1.0, 1.0});
}


/// Bắt đầu vẽ Text UI trên màn hình với canvas chuẩn 960x760
pub const UI_CANVAS_W: f32 = 960.0;
pub const UI_CANVAS_H: f32 = 760.0;
pub const CHAR_W: f32 = 8.0;
pub const CHAR_H: f32 = 8.0;
pub const UI_COLS: f32 = UI_CANVAS_W / CHAR_W; // 120.0 columns
pub const UI_ROWS: f32 = UI_CANVAS_H / CHAR_H; // 95.0 rows


/// Chuyển đổi tọa độ cột ký tự (0..UI_COLS) sang tọa độ WebGL NDC [-1.0, 1.0]
pub fn charToNdcX(col: f32) f32 {
    return (col / UI_COLS) * 2.0 - 1.0;
}

/// Chuyển đổi tọa độ dòng ký tự (0..UI_ROWS) sang tọa độ WebGL NDC [1.0, -1.0]
pub fn charToNdcY(row: f32) f32 {
    return 1.0 - (row / UI_ROWS) * 2.0;
}

/// Tính nửa chiều rộng (half-width) của quad NDC tương ứng với số cột
pub fn charSpanToNdcHalfW(cols: f32) f32 {
    return (cols / UI_COLS);
}

/// Tính nửa chiều cao (half-height) của quad NDC tương ứng với số dòng
pub fn charSpanToNdcHalfH(rows: f32) f32 {
    return (rows / UI_ROWS);
}

/// Chuyển đổi tọa độ WebGL NDC X sang cột ký tự
pub fn ndcToCharCol(x: f32) f32 {
    return ((x + 1.0) * 0.5) * UI_COLS;
}

/// Chuyển đổi tọa độ WebGL NDC Y sang dòng ký tự
pub fn ndcToCharRow(y: f32) f32 {
    return ((1.0 - y) * 0.5) * UI_ROWS;
}

fn codepointToAscii(cp: u21) ?u8 {
    return switch (cp) {
        // Ký tự in ASCII chuẩn (32 .. 126)
        ' '...'~' => @intCast(cp),
        // Chữ A / a có dấu tiếng Việt
        0x00E0...0x00E3, 0x0103, 0x1EA1, 0x1EA3, 0x1EA5, 0x1EA7, 0x1EA9, 0x1EAB, 0x1EAD, 0x1EAF, 0x1EB1, 0x1EB3, 0x1EB5, 0x1EB7 => 'a',
        0x00C0...0x00C3, 0x0102, 0x1EA0, 0x1EA2, 0x1EA4, 0x1EA6, 0x1EA8, 0x1EAA, 0x1EAC, 0x1EAE, 0x1EB0, 0x1EB2, 0x1EB4, 0x1EB6 => 'A',
        // Chữ E / e có dấu tiếng Việt
        0x00E8, 0x00E9, 0x00EA, 0x1EB9, 0x1EBB, 0x1EBD, 0x1EBF, 0x1EC1, 0x1EC3, 0x1EC5, 0x1EC7 => 'e',
        0x00C8, 0x00C9, 0x00CA, 0x1EB8, 0x1EBA, 0x1EBC, 0x1EBE, 0x1EC0, 0x1EC2, 0x1EC4, 0x1EC6 => 'E',
        // Chữ I / i có dấu tiếng Việt
        0x00EC, 0x00ED, 0x0129, 0x1EC9, 0x1ECB => 'i',
        0x00CC, 0x00CD, 0x0128, 0x1EC8, 0x1ECA => 'I',
        // Chữ O / o có dấu tiếng Việt
        0x00F2, 0x00F3, 0x00F4, 0x00F5, 0x01A1, 0x1ECD, 0x1ECF, 0x1ED1, 0x1ED3, 0x1ED5, 0x1ED7, 0x1ED9, 0x1EDB, 0x1EDD, 0x1EDF, 0x1EE1, 0x1EE3 => 'o',
        0x00D2, 0x00D3, 0x00D4, 0x00D5, 0x01A0, 0x1ECC, 0x1ECE, 0x1ED0, 0x1ED2, 0x1ED4, 0x1ED6, 0x1ED8, 0x1EDA, 0x1EDC, 0x1EDE, 0x1EE0, 0x1EE2 => 'O',
        // Chữ U / u có dấu tiếng Việt
        0x00F9, 0x00FA, 0x0169, 0x01B0, 0x1EE5, 0x1EE7, 0x1EE9, 0x1EEB, 0x1EED, 0x1EEF, 0x1EF1 => 'u',
        0x00D9, 0x00DA, 0x0168, 0x01AF, 0x1EE4, 0x1EE6, 0x1EE8, 0x1EEA, 0x1EEC, 0x1EEE, 0x1EF0 => 'U',
        // Chữ Y / y có dấu tiếng Việt
        0x00FD, 0x1EF3, 0x1EF5, 0x1EF7, 0x1EF9 => 'y',
        0x00DD, 0x1EF2, 0x1EF4, 0x1EF6, 0x1EF8 => 'Y',
        // Chữ Đ / đ
        0x0111 => 'd',
        0x0110 => 'D',
        else => ' ',
    };
}

/// Khử dấu tiếng Việt và chuyển đổi chuỗi UTF-8 bất kỳ thành ASCII null-terminated an toàn cho sdtx
pub fn sanitizeToAscii(dest: []u8, src: []const u8) [:0]const u8 {
    if (dest.len == 0) return "";
    var d_idx: usize = 0;
    var i: usize = 0;
    while (i < src.len and d_idx + 1 < dest.len) {
        const len = std.unicode.utf8ByteSequenceLength(src[i]) catch {
            dest[d_idx] = ' ';
            d_idx += 1;
            i += 1;
            continue;
        };
        if (i + len > src.len) break;
        const cp = std.unicode.utf8Decode(src[i .. i + len]) catch {
            dest[d_idx] = ' ';
            d_idx += 1;
            i += len;
            continue;
        };
        if (codepointToAscii(cp)) |ascii_char| {
            dest[d_idx] = ascii_char;
            d_idx += 1;
        }
        i += len;
    }
    dest[d_idx] = 0;
    return dest[0..d_idx :0];
}

/// Chuyển đổi tọa độ pixel sang tọa độ NDC (center_x, center_y, half_w, half_h)
pub fn pxToNdc(x: f32, y: f32, w: f32, h: f32) struct { ndc_x: f32, ndc_y: f32, ndc_hw: f32, ndc_hh: f32 } {
    const ndc_hw = (w / UI_CANVAS_W);
    const ndc_hh = (h / UI_CANVAS_H);
    const ndc_x = (x / UI_CANVAS_W) * 2.0 - 1.0 + ndc_hw;
    const ndc_y = 1.0 - (y / UI_CANVAS_H) * 2.0 - ndc_hh;
    return .{
        .ndc_x = ndc_x,
        .ndc_y = ndc_y,
        .ndc_hw = ndc_hw,
        .ndc_hh = ndc_hh,
    };
}

/// Vẽ một ký tự glyph từ Font Atlas với tọa độ pixel thực và tỉ lệ co dãn
pub fn drawGlyph(glyph: *const font_data.GlyphInfo, x_px: f32, y_px: f32, scale: f32, color: [4]f32) void {
    if (glyph.w <= 0.0 or glyph.h <= 0.0) return;

    const w_px = glyph.w * scale;
    const h_px = glyph.h * scale;

    const ndc = pxToNdc(x_px, y_px, w_px, h_px);

    gl.ensurePass();

    var bind: sg.Bindings = .{};
    bind.vertex_buffers[0] = tex_vbo;
    bind.views[0] = texture_views[@intFromEnum(TextureId.font_atlas)];
    bind.samplers[0] = shared_sampler;

    const u = TextUniformBlock{
        .rect = .{ ndc.ndc_x, ndc.ndc_y, ndc.ndc_hw, ndc.ndc_hh },
        .uv_rect = .{ glyph.u0, glyph.v0, glyph.u1, glyph.v1 },
        .color = color,
    };

    sg.applyPipeline(text_pip);
    sg.applyBindings(bind);
    sg.applyUniforms(0, .{
        .ptr = &u,
        .size = @sizeOf(TextUniformBlock),
    });
    sg.draw(0, 6, 1);
}

/// Vẽ chuỗi văn bản UTF-8 chuẩn (định hình bằng HarfBuzz và vẽ bằng Font Atlas) tại tọa độ pixel (x, y)
pub fn drawUtf8Text(text: []const u8, x_px: f32, y_px: f32, font_size: f32, color: [4]f32) void {
    const scale = font_size / font_data.BASE_FONT_SIZE;
    var pen_x = x_px;
    const pen_y = y_px;

    if (typography.engine.is_initialized) {
        var shaped: [128]typography.ShapedGlyph = undefined;
        const count = typography.engine.shapeText(text, &shaped);
        if (count > 0) {
            var utf8 = std.unicode.Utf8View.init(text) catch return;
            var iter = utf8.iterator();
            var i: usize = 0;
            while (iter.nextCodepoint()) |cp| {
                if (i >= count) break;
                if (font_data.findGlyph(cp)) |glyph| {
                    if (glyph.w > 0.0 and glyph.h > 0.0) {
                        const gx = pen_x + (glyph.x_off + shaped[i].offset_x) * scale;
                        const gy = pen_y + (glyph.y_off + shaped[i].offset_y) * scale;
                        drawGlyph(glyph, gx, gy, scale, color);
                    }
                }
                pen_x += shaped[i].advance * scale;
                i += 1;
            }
            return;
        }
    }

    var utf8 = std.unicode.Utf8View.init(text) catch return;
    var iter = utf8.iterator();
    while (iter.nextCodepoint()) |cp| {
        if (font_data.findGlyph(cp)) |glyph| {
            if (glyph.w > 0.0 and glyph.h > 0.0) {
                const gx = pen_x + glyph.x_off * scale;
                const gy = pen_y + glyph.y_off * scale;
                drawGlyph(glyph, gx, gy, scale, color);
            }
            pen_x += glyph.advance * scale;
        } else {
            pen_x += 8.0 * scale;
        }
    }
}

/// Đo lường chiều rộng chuỗi UTF-8 bằng HarfBuzz hoặc fallback font_data
pub fn measureText(text: []const u8, font_size: f32) f32 {
    if (typography.engine.is_initialized) {
        return typography.engine.measureText(text, font_size);
    }
    return font_data.measureTextWidth(text, font_size);
}

/// Bắt đầu vẽ Text UI trên màn hình với canvas chuẩn
pub fn beginTextUi() void {
    sdtx.canvas(UI_CANVAS_W, UI_CANVAS_H);
}

/// Chọn font chữ sdtx: 0 = CPC (mặc định), 1 = KC853, 2 = Z1013
pub fn setFont(font_idx: usize) void {
    sdtx.font(font_idx);
}

/// Vẽ văn bản màu tại tọa độ cột/dòng (character coordinates)
pub fn drawTextAt(col: f32, row: f32, text: [:0]const u8, r: u8, g: u8, b: u8) void {
    sdtx.pos(col, row);
    sdtx.color3b(r, g, b);
    sdtx.puts(text);
}

/// Vẽ văn bản UTF-8 bất kỳ an toàn tại tọa độ cột/dòng (tự động lọc dấu sang ASCII)
pub fn drawTextClean(col: f32, row: f32, text: []const u8, r: u8, g: u8, b: u8) void {
    var buf: [128]u8 = undefined;
    const clean_str = sanitizeToAscii(&buf, text);
    drawTextAt(col, row, clean_str, r, g, b);
}

/// Kết thúc và vẽ toàn bộ văn bản UI trong render pass hiện tại
pub fn endTextUi() void {
    gl.ensurePass();
    sdtx.draw();
}
