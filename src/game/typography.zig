// src/game/typography.zig
// High-End Typography Engine combining FreeType (rasterization) and HarfBuzz (OpenType shaping)

const std = @import("std");

pub const ft = @cImport({
    @cInclude("ft2build.h");
    @cInclude("freetype/freetype.h");
});

// HarfBuzz C ABI
pub const hb_buffer_t = anyopaque;
pub const hb_font_t = anyopaque;

pub const hb_glyph_info_t = extern struct {
    codepoint: u32, // Glyph index in font
    mask: u32,
    cluster: u32,
    var1: u32,
    var2: u32,
};

pub const hb_glyph_position_t = extern struct {
    x_advance: i32, // 26.6 fractional pixels (divide by 64.0)
    y_advance: i32,
    x_offset: i32,
    y_offset: i32,
    var_u: u32,
};

extern "c" fn hb_buffer_create() ?*hb_buffer_t;
extern "c" fn hb_buffer_destroy(buffer: *hb_buffer_t) void;
extern "c" fn hb_buffer_add_utf8(buffer: *hb_buffer_t, text: [*]const u8, text_length: c_int, item_offset: c_uint, item_length: c_int) void;
extern "c" fn hb_buffer_guess_segment_properties(buffer: *hb_buffer_t) void;
extern "c" fn hb_ft_font_create(ft_face: ft.FT_Face, destroy: ?*const fn (?*anyopaque) callconv(.c) void) ?*hb_font_t;
extern "c" fn hb_font_destroy(font: *hb_font_t) void;
extern "c" fn hb_shape(font: *hb_font_t, buffer: *hb_buffer_t, features: ?*anyopaque, num_features: c_uint) void;
extern "c" fn hb_buffer_get_glyph_infos(buffer: *hb_buffer_t, length: *c_uint) [*]const hb_glyph_info_t;
extern "c" fn hb_buffer_get_glyph_positions(buffer: *hb_buffer_t, length: *c_uint) [*]const hb_glyph_position_t;

pub const BASE_PIXEL_SIZE: u32 = 26;

pub const ShapedGlyph = struct {
    glyph_id: u32,
    codepoint: u21,
    advance: f32,
    offset_x: f32,
    offset_y: f32,
};

pub const Typography = struct {
    ft_lib: ft.FT_Library = null,
    ft_face: ft.FT_Face = null,
    hb_font: ?*hb_font_t = null,
    is_initialized: bool = false,

    pub fn init(self: *Typography, font_path: [:0]const u8) bool {
        if (ft.FT_Init_FreeType(&self.ft_lib) != 0) {
            std.debug.print(">> [Typography]: FT_Init_FreeType failed\n", .{});
            return false;
        }

        if (ft.FT_New_Face(self.ft_lib, font_path.ptr, 0, &self.ft_face) != 0) {
            std.debug.print(">> [Typography]: FT_New_Face failed for {s}\n", .{font_path});
            _ = ft.FT_Done_FreeType(self.ft_lib);
            self.ft_lib = null;
            return false;
        }

        _ = ft.FT_Set_Pixel_Sizes(self.ft_face, 0, BASE_PIXEL_SIZE);

        self.hb_font = hb_ft_font_create(self.ft_face, null);
        if (self.hb_font == null) {
            std.debug.print(">> [Typography]: hb_ft_font_create failed\n", .{});
            _ = ft.FT_Done_Face(self.ft_face);
            _ = ft.FT_Done_FreeType(self.ft_lib);
            self.ft_face = null;
            self.ft_lib = null;
            return false;
        }

        self.is_initialized = true;
        std.debug.print(">> [Typography]: FreeType & HarfBuzz Engine Initialized! Font: {s}\n", .{font_path});
        return true;
    }

    pub fn deinit(self: *Typography) void {
        if (self.hb_font) |hbf| {
            hb_font_destroy(hbf);
            self.hb_font = null;
        }
        if (self.ft_face) |face| {
            _ = ft.FT_Done_Face(face);
            self.ft_face = null;
        }
        if (self.ft_lib) |lib| {
            _ = ft.FT_Done_FreeType(lib);
            self.ft_lib = null;
        }
        self.is_initialized = false;
    }

    /// Định hình chuỗi UTF-8 bằng HarfBuzz và đo lường kích thước chính xác
    pub fn measureText(self: *Typography, text: []const u8, font_size: f32) f32 {
        if (!self.is_initialized or self.hb_font == null or text.len == 0) {
            return @as(f32, @floatFromInt(text.len)) * (font_size * 0.52);
        }

        const buf = hb_buffer_create() orelse return @as(f32, @floatFromInt(text.len)) * (font_size * 0.52);
        defer hb_buffer_destroy(buf);

        hb_buffer_add_utf8(buf, text.ptr, @intCast(text.len), 0, @intCast(text.len));
        hb_buffer_guess_segment_properties(buf);

        hb_shape(self.hb_font.?, buf, null, 0);

        var len: c_uint = 0;
        const positions = hb_buffer_get_glyph_positions(buf, &len);

        var total_advance_26_6: i64 = 0;
        for (0..len) |i| {
            total_advance_26_6 += positions[i].x_advance;
        }

        const scale = font_size / @as(f32, @floatFromInt(BASE_PIXEL_SIZE));
        return (@as(f32, @floatFromInt(total_advance_26_6)) / 64.0) * scale;
    }

    /// Định hình chuỗi văn bản bằng HarfBuzz và xuất ra mảng glyphs định vị
    pub fn shapeText(
        self: *Typography,
        text: []const u8,
        out_glyphs: []ShapedGlyph,
    ) usize {
        if (!self.is_initialized or self.hb_font == null or text.len == 0 or out_glyphs.len == 0) {
            return 0;
        }

        const buf = hb_buffer_create() orelse return 0;
        defer hb_buffer_destroy(buf);

        hb_buffer_add_utf8(buf, text.ptr, @intCast(text.len), 0, @intCast(text.len));
        hb_buffer_guess_segment_properties(buf);

        hb_shape(self.hb_font.?, buf, null, 0);

        var len: c_uint = 0;
        const infos = hb_buffer_get_glyph_infos(buf, &len);
        const positions = hb_buffer_get_glyph_positions(buf, &len);

        const count = @min(@as(usize, len), out_glyphs.len);
        for (0..count) |i| {
            out_glyphs[i] = .{
                .glyph_id = infos[i].codepoint,
                .codepoint = 0,
                .advance = @as(f32, @floatFromInt(positions[i].x_advance)) / 64.0,
                .offset_x = @as(f32, @floatFromInt(positions[i].x_offset)) / 64.0,
                .offset_y = @as(f32, @floatFromInt(positions[i].y_offset)) / 64.0,
            };
        }
        return count;
    }
};

pub var engine: Typography = .{};

test "typography: freetype and harfbuzz initialization and text shaping" {
    var typo: Typography = .{};
    const ok = typo.init("/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf");
    try std.testing.expect(ok);
    defer typo.deinit();

    const sample = "Linh Thú Uyển - Tiêu Phàm [Trúc Cơ]";
    const width = typo.measureText(sample, 16.0);
    try std.testing.expect(width > 50.0);

    var glyphs: [64]ShapedGlyph = undefined;
    const count = typo.shapeText(sample, &glyphs);
    try std.testing.expect(count > 0);
    try std.testing.expectEqual(count, 35);
}
