const std = @import("std");

pub const Color = [4]f32;

pub fn parseColor(str: []const u8) Color {
    if (str.len == 0) return .{ 1.0, 1.0, 1.0, 1.0 };
    if (str[0] == '#') {
        const hex = str[1..];
        if (hex.len == 6) {
            const r = std.fmt.parseInt(u8, hex[0..2], 16) catch 255;
            const g = std.fmt.parseInt(u8, hex[2..4], 16) catch 255;
            const b = std.fmt.parseInt(u8, hex[4..6], 16) catch 255;
            return .{
                @as(f32, @floatFromInt(r)) / 255.0,
                @as(f32, @floatFromInt(g)) / 255.0,
                @as(f32, @floatFromInt(b)) / 255.0,
                1.0,
            };
        } else if (hex.len == 8) {
            const r = std.fmt.parseInt(u8, hex[0..2], 16) catch 255;
            const g = std.fmt.parseInt(u8, hex[2..4], 16) catch 255;
            const b = std.fmt.parseInt(u8, hex[4..6], 16) catch 255;
            const a = std.fmt.parseInt(u8, hex[6..8], 16) catch 255;
            return .{
                @as(f32, @floatFromInt(r)) / 255.0,
                @as(f32, @floatFromInt(g)) / 255.0,
                @as(f32, @floatFromInt(b)) / 255.0,
                @as(f32, @floatFromInt(a)) / 255.0,
            };
        }
    }
    if (std.mem.eql(u8, str, "gold")) return .{ 0.95, 0.78, 0.25, 1.0 };
    if (std.mem.eql(u8, str, "green")) return .{ 0.20, 0.85, 0.40, 1.0 };
    if (std.mem.eql(u8, str, "red")) return .{ 0.95, 0.20, 0.20, 1.0 };
    if (std.mem.eql(u8, str, "blue")) return .{ 0.20, 0.60, 0.95, 1.0 };
    if (std.mem.eql(u8, str, "cyan")) return .{ 0.25, 0.85, 0.85, 1.0 };
    if (std.mem.eql(u8, str, "white")) return .{ 1.0, 1.0, 1.0, 1.0 };
    if (std.mem.eql(u8, str, "black")) return .{ 0.0, 0.0, 0.0, 1.0 };
    if (std.mem.eql(u8, str, "gray")) return .{ 0.5, 0.5, 0.5, 1.0 };
    if (std.mem.eql(u8, str, "dark")) return .{ 0.05, 0.09, 0.08, 0.97 };
    if (std.mem.eql(u8, str, "darkgreen")) return .{ 0.08, 0.18, 0.15, 1.0 };
    if (std.mem.eql(u8, str, "transparent")) return .{ 0.0, 0.0, 0.0, 0.0 };
    return .{ 1.0, 1.0, 1.0, 1.0 };
}

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn contains(self: Rect, px: f32, py: f32) bool {
        return px >= self.x and px <= (self.x + self.w) and py >= self.y and py <= (self.y + self.h);
    }
};

pub const ImageNode = struct {
    id: [32]u8 = [_]u8{0} ** 32,
    id_len: usize = 0,
    src: [32]u8 = [_]u8{0} ** 32,
    src_len: usize = 0,
    rect: Rect = .{ .x = 0, .y = 0, .w = 48, .h = 48 },
    radius: f32 = 8.0,
    border: Color = .{ 0.76, 0.62, 0.25, 1.0 },
    border_w: f32 = 1.5,
    bg: Color = .{ 0.04, 0.08, 0.07, 0.95 },
};

pub const ButtonNode = struct {
    id: [32]u8 = [_]u8{0} ** 32,
    id_len: usize = 0,
    text: [64]u8 = [_]u8{0} ** 64,
    text_len: usize = 0,
    action: [32]u8 = [_]u8{0} ** 32,
    action_len: usize = 0,
    rect: Rect = .{ .x = 0, .y = 0, .w = 100, .h = 30 },
    bg: Color = .{ 0.1, 0.2, 0.18, 1.0 },
    bg2: ?Color = null,
    hover_bg: Color = .{ 0.16, 0.35, 0.30, 1.0 },
    hover_bg2: ?Color = null,
    border: Color = .{ 0.76, 0.62, 0.25, 1.0 },
    text_color: Color = .{ 0.95, 0.98, 0.95, 1.0 },
    radius: f32 = 6.0,
    glow: bool = false,
};

pub const TextNode = struct {
    id: [32]u8 = [_]u8{0} ** 32,
    id_len: usize = 0,
    text: [128]u8 = [_]u8{0} ** 128,
    text_len: usize = 0,
    x: f32 = 0,
    y: f32 = 0,
    color: Color = .{ 0.95, 0.98, 0.95, 1.0 },
    size: f32 = 14.0,
};

pub const ProgressBarNode = struct {
    id: [32]u8 = [_]u8{0} ** 32,
    id_len: usize = 0,
    rect: Rect = .{ .x = 0, .y = 0, .w = 100, .h = 16 },
    current: i32 = 100,
    max: i32 = 100,
    fill_color: Color = .{ 0.20, 0.85, 0.40, 1.0 },
    fill2: ?Color = null,
    bg_color: Color = .{ 0.06, 0.10, 0.09, 1.0 },
    border_color: Color = .{ 0.24, 0.35, 0.32, 1.0 },
    label: [48]u8 = [_]u8{0} ** 48,
    label_len: usize = 0,
    radius: f32 = 5.0,
    glow: bool = false,
};

pub const PanelNode = struct {
    id: [32]u8 = [_]u8{0} ** 32,
    id_len: usize = 0,
    rect: Rect = .{ .x = 0, .y = 0, .w = 100, .h = 100 },
    bg: Color = .{ 0.05, 0.10, 0.09, 0.95 },
    bg2: ?Color = null,
    border: Color = .{ 0.22, 0.41, 0.35, 1.0 },
    title: [64]u8 = [_]u8{0} ** 64,
    title_len: usize = 0,
    radius: f32 = 8.0,
    shadow: bool = false,
};

pub const WindowNode = struct {
    id: [32]u8 = [_]u8{0} ** 32,
    id_len: usize = 0,
    title: [80]u8 = [_]u8{0} ** 80,
    title_len: usize = 0,
    rect: Rect = .{ .x = 0, .y = 0, .w = 100, .h = 100 },
    bg: Color = .{ 0.05, 0.09, 0.08, 0.97 },
    bg2: ?Color = null,
    border: Color = .{ 0.76, 0.62, 0.25, 1.0 },
    radius: f32 = 10.0,
    shadow: bool = true,
};

pub const UIState = struct {
    windows: [16]WindowNode = [_]WindowNode{.{}} ** 16,
    window_count: usize = 0,

    panels: [32]PanelNode = [_]PanelNode{.{}} ** 32,
    panel_count: usize = 0,

    buttons: [128]ButtonNode = [_]ButtonNode{.{}} ** 128,
    button_count: usize = 0,

    texts: [160]TextNode = [_]TextNode{.{}} ** 160,
    text_count: usize = 0,

    bars: [32]ProgressBarNode = [_]ProgressBarNode{.{}} ** 32,
    bar_count: usize = 0,

    images: [32]ImageNode = [_]ImageNode{.{}} ** 32,
    image_count: usize = 0,

    mouse_x: f32 = 0,
    mouse_y: f32 = 0,
    mouse_down: bool = false,
    hovered_button: ?usize = null,

    pub fn clear(self: *UIState) void {
        self.window_count = 0;
        self.panel_count = 0;
        self.button_count = 0;
        self.text_count = 0;
        self.bar_count = 0;
        self.image_count = 0;
        self.hovered_button = null;
    }

    pub fn handleMouseMove(self: *UIState, mx: f32, my: f32) void {
        self.mouse_x = mx;
        self.mouse_y = my;

        self.hovered_button = null;
        for (0..self.button_count) |i| {
            if (self.buttons[i].rect.contains(mx, my)) {
                self.hovered_button = i;
                break;
            }
        }
    }

    pub fn handleMouseDown(self: *UIState, mx: f32, my: f32) ?[]const u8 {
        self.mouse_x = mx;
        self.mouse_y = my;
        self.mouse_down = true;

        for (0..self.button_count) |i| {
            if (self.buttons[i].rect.contains(mx, my)) {
                const btn = &self.buttons[i];
                if (btn.action_len > 0) {
                    return btn.action[0..btn.action_len];
                } else if (btn.id_len > 0) {
                    return btn.id[0..btn.id_len];
                }
            }
        }
        return null;
    }

    pub fn handleMouseUp(self: *UIState, mx: f32, my: f32) void {
        self.mouse_x = mx;
        self.mouse_y = my;
        self.mouse_down = false;
    }

    pub fn addImage(self: *UIState, id: []const u8, src: []const u8, rect: Rect, radius: f32, border: Color, border_w: f32, bg: Color) void {
        if (self.image_count >= self.images.len) return;
        var im = &self.images[self.image_count];
        self.image_count += 1;

        const id_l = @min(id.len, im.id.len);
        @memcpy(im.id[0..id_l], id[0..id_l]);
        im.id_len = id_l;

        const src_l = @min(src.len, im.src.len);
        @memcpy(im.src[0..src_l], src[0..src_l]);
        im.src_len = src_l;

        im.rect = rect;
        im.radius = radius;
        im.border = border;
        im.border_w = border_w;
        im.bg = bg;
    }

    pub fn addWindowEx(self: *UIState, id: []const u8, title: []const u8, rect: Rect, bg: Color, bg2: ?Color, border: Color, radius: f32, shadow: bool) void {
        if (self.window_count >= self.windows.len) return;
        var w = &self.windows[self.window_count];
        self.window_count += 1;

        const id_l = @min(id.len, w.id.len);
        @memcpy(w.id[0..id_l], id[0..id_l]);
        w.id_len = id_l;

        const t_l = @min(title.len, w.title.len);
        @memcpy(w.title[0..t_l], title[0..t_l]);
        w.title_len = t_l;

        w.rect = rect;
        w.bg = bg;
        w.bg2 = bg2;
        w.border = border;
        w.radius = radius;
        w.shadow = shadow;
    }

    pub fn addWindow(self: *UIState, id: []const u8, title: []const u8, rect: Rect, bg: Color, border: Color) void {
        self.addWindowEx(id, title, rect, bg, null, border, 10.0, true);
    }

    pub fn addPanelEx(self: *UIState, id: []const u8, title: []const u8, rect: Rect, bg: Color, bg2: ?Color, border: Color, radius: f32, shadow: bool) void {
        if (self.panel_count >= self.panels.len) return;
        var p = &self.panels[self.panel_count];
        self.panel_count += 1;

        const id_l = @min(id.len, p.id.len);
        @memcpy(p.id[0..id_l], id[0..id_l]);
        p.id_len = id_l;

        const t_l = @min(title.len, p.title.len);
        @memcpy(p.title[0..t_l], title[0..t_l]);
        p.title_len = t_l;

        p.rect = rect;
        p.bg = bg;
        p.bg2 = bg2;
        p.border = border;
        p.radius = radius;
        p.shadow = shadow;
    }

    pub fn addPanel(self: *UIState, id: []const u8, title: []const u8, rect: Rect, bg: Color, border: Color) void {
        self.addPanelEx(id, title, rect, bg, null, border, 8.0, false);
    }

    pub fn addButtonEx(
        self: *UIState,
        id: []const u8,
        text: []const u8,
        action: []const u8,
        rect: Rect,
        bg: Color,
        bg2: ?Color,
        hover_bg: Color,
        hover_bg2: ?Color,
        border: Color,
        text_color: Color,
        radius: f32,
        glow: bool,
    ) void {
        if (self.button_count >= self.buttons.len) return;
        var b = &self.buttons[self.button_count];
        self.button_count += 1;

        const id_l = @min(id.len, b.id.len);
        @memcpy(b.id[0..id_l], id[0..id_l]);
        b.id_len = id_l;

        const t_l = @min(text.len, b.text.len);
        @memcpy(b.text[0..t_l], text[0..t_l]);
        b.text_len = t_l;

        const a_l = @min(action.len, b.action.len);
        @memcpy(b.action[0..a_l], action[0..a_l]);
        b.action_len = a_l;

        b.rect = rect;
        b.bg = bg;
        b.bg2 = bg2;
        b.hover_bg = hover_bg;
        b.hover_bg2 = hover_bg2;
        b.border = border;
        b.text_color = text_color;
        b.radius = radius;
        b.glow = glow;
    }

    pub fn addButton(
        self: *UIState,
        id: []const u8,
        text: []const u8,
        action: []const u8,
        rect: Rect,
        bg: Color,
        hover_bg: Color,
        border: Color,
        text_color: Color,
    ) void {
        self.addButtonEx(id, text, action, rect, bg, null, hover_bg, null, border, text_color, 6.0, false);
    }

    pub fn addText(self: *UIState, id: []const u8, text: []const u8, x: f32, y: f32, color: Color, size: f32) void {
        if (self.text_count >= self.texts.len) return;
        var t = &self.texts[self.text_count];
        self.text_count += 1;

        const id_l = @min(id.len, t.id.len);
        @memcpy(t.id[0..id_l], id[0..id_l]);
        t.id_len = id_l;

        const t_l = @min(text.len, t.text.len);
        @memcpy(t.text[0..t_l], text[0..t_l]);
        t.text_len = t_l;

        t.x = x;
        t.y = y;
        t.color = color;
        t.size = size;
    }

    pub fn addProgressBarEx(
        self: *UIState,
        id: []const u8,
        current: i32,
        max: i32,
        rect: Rect,
        fill_color: Color,
        fill2: ?Color,
        bg_color: Color,
        border_color: Color,
        label: []const u8,
        radius: f32,
        glow: bool,
    ) void {
        if (self.bar_count >= self.bars.len) return;
        var b = &self.bars[self.bar_count];
        self.bar_count += 1;

        const id_l = @min(id.len, b.id.len);
        @memcpy(b.id[0..id_l], id[0..id_l]);
        b.id_len = id_l;

        b.rect = rect;
        b.current = current;
        b.max = max;
        b.fill_color = fill_color;
        b.fill2 = fill2;
        b.bg_color = bg_color;
        b.border_color = border_color;
        b.radius = radius;
        b.glow = glow;

        const l_l = @min(label.len, b.label.len);
        @memcpy(b.label[0..l_l], label[0..l_l]);
        b.label_len = l_l;
    }

    pub fn addProgressBar(
        self: *UIState,
        id: []const u8,
        rect: Rect,
        current: i32,
        max: i32,
        fill_color: Color,
        bg_color: Color,
        border_color: Color,
        label: []const u8,
    ) void {
        self.addProgressBarEx(id, current, max, rect, fill_color, null, bg_color, border_color, label, 5.0, false);
    }

    /// Chuyển đổi tọa độ pixel (960 x 760) sang WebGL NDC [-1, 1] và kích thước half-extent
    pub fn pxToNdc(x: f32, y: f32, w: f32, h: f32) struct { ndc_x: f32, ndc_y: f32, ndc_hw: f32, ndc_hh: f32 } {
        const center_x = x + w * 0.5;
        const center_y = y + h * 0.5;
        return .{
            .ndc_x = (center_x / 960.0) * 2.0 - 1.0,
            .ndc_y = 1.0 - (center_y / 760.0) * 2.0,
            .ndc_hw = w / 960.0,
            .ndc_hh = h / 760.0,
        };
    }

    /// Render drop shadows mềm dưới các khung Window và Card nổi
    pub fn renderShadows(self: *UIState, draw_rect_modern: anytype) void {
        for (0..self.window_count) |i| {
            const w = &self.windows[i];
            if (!w.shadow) continue;
            const ndc = pxToNdc(w.rect.x, w.rect.y + 6.0, w.rect.w, w.rect.h);
            draw_rect_modern(ndc.ndc_x, ndc.ndc_y, ndc.ndc_hw, ndc.ndc_hh, .{ 0.0, 0.0, 0.0, 0.5 }, .{ 0.0, 0.0, 0.0, 0.5 }, .{ 0, 0, 0, 0 }, w.radius + 4.0, 0.0, true, false);
        }
        for (0..self.panel_count) |i| {
            const p = &self.panels[i];
            if (!p.shadow) continue;
            const ndc = pxToNdc(p.rect.x, p.rect.y + 4.0, p.rect.w, p.rect.h);
            draw_rect_modern(ndc.ndc_x, ndc.ndc_y, ndc.ndc_hw, ndc.ndc_hh, .{ 0.0, 0.0, 0.0, 0.4 }, .{ 0.0, 0.0, 0.0, 0.4 }, .{ 0, 0, 0, 0 }, p.radius + 2.0, 0.0, true, false);
        }
    }

    /// Render tất cả hình chữ nhật, khung cửa sổ bo góc, thanh máu gradient và nút bấm phát sáng
    pub fn renderQuads(self: *UIState, draw_rect_modern: anytype) void {
        // 1. Windows
        for (0..self.window_count) |i| {
            const w = &self.windows[i];
            const ndc = pxToNdc(w.rect.x, w.rect.y, w.rect.w, w.rect.h);
            const bg_bot = w.bg2 orelse w.bg;
            draw_rect_modern(ndc.ndc_x, ndc.ndc_y, ndc.ndc_hw, ndc.ndc_hh, w.bg, bg_bot, w.border, w.radius, 1.5, false, false);

            if (w.title_len > 0) {
                const bar_h: f32 = 24.0;
                const t_ndc = pxToNdc(w.rect.x + 2.0, w.rect.y + 2.0, w.rect.w - 4.0, bar_h);
                draw_rect_modern(t_ndc.ndc_x, t_ndc.ndc_y, t_ndc.ndc_hw, t_ndc.ndc_hh, .{ 0.08, 0.18, 0.15, 0.95 }, .{ 0.04, 0.10, 0.08, 0.95 }, .{ 0.18, 0.38, 0.30, 0.8 }, @max(0.0, w.radius - 2.0), 1.0, false, false);
            }
        }

        // 2. Panels & Slots
        for (0..self.panel_count) |i| {
            const p = &self.panels[i];
            const ndc = pxToNdc(p.rect.x, p.rect.y, p.rect.w, p.rect.h);
            const bg_bot = p.bg2 orelse p.bg;
            draw_rect_modern(ndc.ndc_x, ndc.ndc_y, ndc.ndc_hw, ndc.ndc_hh, p.bg, bg_bot, p.border, p.radius, 1.2, false, false);
        }

        // 3. ProgressBars
        for (0..self.bar_count) |i| {
            const bar = &self.bars[i];
            const bg_ndc = pxToNdc(bar.rect.x, bar.rect.y, bar.rect.w, bar.rect.h);
            draw_rect_modern(bg_ndc.ndc_x, bg_ndc.ndc_y, bg_ndc.ndc_hw, bg_ndc.ndc_hh, bar.bg_color, bar.bg_color, bar.border_color, bar.radius, 1.2, false, false);

            if (bar.current > 0 and bar.max > 0) {
                const ratio = std.math.clamp(@as(f32, @floatFromInt(bar.current)) / @as(f32, @floatFromInt(bar.max)), 0.0, 1.0);
                const fill_w = (bar.rect.w - 2.0) * ratio;
                if (fill_w > 1.0) {
                    const fill_ndc = pxToNdc(bar.rect.x + 1.0, bar.rect.y + 1.0, fill_w, bar.rect.h - 2.0);
                    const fill_bot = bar.fill2 orelse bar.fill_color;
                    const is_critical = (bar.current * 4 <= bar.max);
                    draw_rect_modern(fill_ndc.ndc_x, fill_ndc.ndc_y, fill_ndc.ndc_hw, fill_ndc.ndc_hh, bar.fill_color, fill_bot, bar.fill_color, @max(0.0, bar.radius - 1.0), 0.0, false, bar.glow or is_critical);
                }
            }
        }

        // 4. Buttons (Hover highlight + Glow)
        for (0..self.button_count) |i| {
            const b = &self.buttons[i];
            const is_hovered = (self.hovered_button != null and self.hovered_button.? == i);
            const bg_top = if (is_hovered) b.hover_bg else b.bg;
            const bg_bot = if (is_hovered) (b.hover_bg2 orelse b.hover_bg) else (b.bg2 orelse b.bg);
            const border = if (is_hovered) parseColor("#ffe57f") else b.border;

            const ndc = pxToNdc(b.rect.x, b.rect.y, b.rect.w, b.rect.h);
            draw_rect_modern(ndc.ndc_x, ndc.ndc_y, ndc.ndc_hw, ndc.ndc_hh, bg_top, bg_bot, border, b.radius, 1.2, false, is_hovered or b.glow);
        }
    }

    /// Render tất cả ảnh chân dung Linh thú và Tu sĩ
    pub fn renderImages(self: *UIState, draw_rect_modern: anytype, draw_texture: anytype) void {
        for (0..self.image_count) |i| {
            const img = &self.images[i];
            const ndc = pxToNdc(img.rect.x, img.rect.y, img.rect.w, img.rect.h);

            // 1. Viền và nền bo góc của khung ảnh
            draw_rect_modern(ndc.ndc_x, ndc.ndc_y, ndc.ndc_hw, ndc.ndc_hh, img.bg, img.bg, img.border, img.radius, img.border_w, false, false);

            // 2. Texture avatar lồng bên trong
            if (img.src_len > 0) {
                const margin: f32 = 3.0;
                const inner_ndc = pxToNdc(img.rect.x + margin, img.rect.y + margin, img.rect.w - margin * 2.0, img.rect.h - margin * 2.0);
                draw_texture(img.src[0..img.src_len], inner_ndc.ndc_x, inner_ndc.ndc_y, inner_ndc.ndc_hw, inner_ndc.ndc_hh);
            }
        }
    }


    /// Render tất cả tiêu đề, nhãn text, chỉ số HP và chữ trên nút bằng Sokol debugtext
    pub fn renderTexts(self: *UIState, draw_text: anytype) void {
        // 1. Window Titles
        for (0..self.window_count) |i| {
            const w = &self.windows[i];
            if (w.title_len > 0) {
                const col = (w.rect.x + 8.0) / 8.0;
                const row = (w.rect.y + 6.0) / 8.0;
                draw_text(col, row, w.title[0..w.title_len], 255, 215, 60);
            }
        }

        // 2. Panel Titles
        for (0..self.panel_count) |i| {
            const p = &self.panels[i];
            if (p.title_len > 0) {
                const col = (p.rect.x + 6.0) / 8.0;
                const row = (p.rect.y + 6.0) / 8.0;
                draw_text(col, row, p.title[0..p.title_len], 240, 210, 80);
            }
        }

        // 3. ProgressBar Labels
        for (0..self.bar_count) |i| {
            const bar = &self.bars[i];
            if (bar.label_len > 0) {
                const lbl = bar.label[0..bar.label_len];
                const lbl_len_f = @as(f32, @floatFromInt(lbl.len));
                const cols_w = bar.rect.w / 8.0;
                const pad_c = if (cols_w > lbl_len_f) (cols_w - lbl_len_f) * 0.5 else 0.5;
                const pad_r = if (bar.rect.h > 8.0) (bar.rect.h - 8.0) * 0.5 / 8.0 else 0.0;
                const col = (bar.rect.x / 8.0) + pad_c;
                const row = (bar.rect.y / 8.0) + pad_r;
                draw_text(col, row, lbl, 255, 255, 255);
            }
        }

        // 4. Button Texts
        for (0..self.button_count) |i| {
            const b = &self.buttons[i];
            const is_hovered = (self.hovered_button != null and self.hovered_button.? == i);
            const txt = b.text[0..b.text_len];
            if (txt.len > 0) {
                const btn_cols_w = b.rect.w / 8.0;
                const btn_rows_h = b.rect.h / 8.0;
                const txt_len_f = @as(f32, @floatFromInt(txt.len));
                const pad_col = if (btn_cols_w > txt_len_f) (btn_cols_w - txt_len_f) * 0.5 else 0.5;
                const pad_row = if (btn_rows_h > 1.0) (btn_rows_h - 1.0) * 0.5 else 0.0;

                const tc = if (is_hovered) parseColor("#ffffff") else b.text_color;
                const cr: u8 = @intFromFloat(std.math.clamp(tc[0] * 255.0, 0.0, 255.0));
                const cg: u8 = @intFromFloat(std.math.clamp(tc[1] * 255.0, 0.0, 255.0));
                const cb: u8 = @intFromFloat(std.math.clamp(tc[2] * 255.0, 0.0, 255.0));
                draw_text((b.rect.x / 8.0) + pad_col, (b.rect.y / 8.0) + pad_row, txt, cr, cg, cb);
            }
        }

        // 5. Texts
        for (0..self.text_count) |i| {
            const t = &self.texts[i];
            const txt = t.text[0..t.text_len];
            if (txt.len == 0) continue;

            const cr: u8 = @intFromFloat(std.math.clamp(t.color[0] * 255.0, 0.0, 255.0));
            const cg: u8 = @intFromFloat(std.math.clamp(t.color[1] * 255.0, 0.0, 255.0));
            const cb: u8 = @intFromFloat(std.math.clamp(t.color[2] * 255.0, 0.0, 255.0));
            draw_text(t.x / 8.0, t.y / 8.0, txt, cr, cg, cb);
        }
    }


    pub fn render(self: *UIState, draw_rect: anytype, draw_text: anytype) void {
        self.renderQuads(draw_rect);
        self.renderTexts(draw_text);
    }

};

pub var ui_state = UIState{};

/// Simple XML Parser cho Ngôn ngữ UI Mockup
pub fn parseXmlUI(xml_content: []const u8, state: *UIState, data_resolver: anytype) void {
    state.clear();

    var i: usize = 0;
    while (i < xml_content.len) {
        // Tìm thẻ bắt đầu '<'
        while (i < xml_content.len and xml_content[i] != '<') i += 1;
        if (i >= xml_content.len) break;
        i += 1; // bỏ qua '<'

        // Bỏ qua thẻ đóng </... > hoặc comment <!-- ... -->
        if (i < xml_content.len and xml_content[i] == '/') {
            while (i < xml_content.len and xml_content[i] != '>') i += 1;
            if (i < xml_content.len) i += 1;
            continue;
        }
        if (i + 2 < xml_content.len and xml_content[i] == '!' and xml_content[i + 1] == '-' and xml_content[i + 2] == '-') {
            i += 3;
            while (i + 2 < xml_content.len and !(xml_content[i] == '-' and xml_content[i + 1] == '-' and xml_content[i + 2] == '>')) i += 1;
            i += 3;
            continue;
        }

        // Đọc tên thẻ (Tag Name)
        const tag_start = i;
        while (i < xml_content.len and xml_content[i] != ' ' and xml_content[i] != '>' and xml_content[i] != '/' and xml_content[i] != '\n' and xml_content[i] != '\r' and xml_content[i] != '\t') i += 1;
        const tag_name = xml_content[tag_start..i];

        // Khởi tạo các thuộc tính mặc định
        var id_buf: [32]u8 = undefined;
        var id_len: usize = 0;
        var title_buf: [80]u8 = undefined;
        var title_len: usize = 0;
        var text_buf: [128]u8 = undefined;
        var text_len: usize = 0;
        var action_buf: [32]u8 = undefined;
        var action_len: usize = 0;
        var label_buf: [48]u8 = undefined;
        var label_len: usize = 0;
        var src_buf: [32]u8 = undefined;
        var src_len: usize = 0;

        var x: f32 = 0;
        var y: f32 = 0;
        var w: f32 = 100;
        var h: f32 = 30;
        var radius: f32 = 6.0;
        var border_w: f32 = 1.2;
        var current: i32 = 100;
        var max_val: i32 = 100;
        var size: f32 = 14;

        var bg_color = parseColor("#0c1816f8");
        var bg2_color: ?Color = null;
        var hover_bg_color = parseColor("#265546");
        var hover_bg2_color: ?Color = null;
        var border_color = parseColor("#c3a041");
        var text_color = parseColor("#ebf8f2");
        var fill_color = parseColor("#32d264");
        var fill2_color: ?Color = null;
        var shadow_enabled: bool = false;
        var glow_enabled: bool = false;

        // Parse danh sách thuộc tính
        while (i < xml_content.len and xml_content[i] != '>' and xml_content[i] != '/') {
            while (i < xml_content.len and (xml_content[i] == ' ' or xml_content[i] == '\t' or xml_content[i] == '\n' or xml_content[i] == '\r')) i += 1;
            if (i >= xml_content.len or xml_content[i] == '>' or xml_content[i] == '/') break;

            const attr_start = i;
            while (i < xml_content.len and xml_content[i] != '=' and xml_content[i] != ' ' and xml_content[i] != '>') i += 1;
            const attr_name = xml_content[attr_start..i];

            while (i < xml_content.len and xml_content[i] != '"' and xml_content[i] != '\'') i += 1;
            if (i >= xml_content.len) break;
            const quote = xml_content[i];
            i += 1;
            const val_start = i;
            while (i < xml_content.len and xml_content[i] != quote) i += 1;
            const attr_val = xml_content[val_start..i];
            if (i < xml_content.len) i += 1;

            // Xử lý các thuộc tính hỗ trợ
            if (std.mem.eql(u8, attr_name, "id")) {
                const l = @min(attr_val.len, id_buf.len);
                @memcpy(id_buf[0..l], attr_val[0..l]);
                id_len = l;
            } else if (std.mem.eql(u8, attr_name, "title")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                const l = @min(resolved.len, title_buf.len);
                @memcpy(title_buf[0..l], resolved[0..l]);
                title_len = l;
            } else if (std.mem.eql(u8, attr_name, "text")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                const l = @min(resolved.len, text_buf.len);
                @memcpy(text_buf[0..l], resolved[0..l]);
                text_len = l;
            } else if (std.mem.eql(u8, attr_name, "action")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                const l = @min(resolved.len, action_buf.len);
                @memcpy(action_buf[0..l], resolved[0..l]);
                action_len = l;
            } else if (std.mem.eql(u8, attr_name, "label")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                const l = @min(resolved.len, label_buf.len);
                @memcpy(label_buf[0..l], resolved[0..l]);
                label_len = l;
            } else if (std.mem.eql(u8, attr_name, "src")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                const l = @min(resolved.len, src_buf.len);
                @memcpy(src_buf[0..l], resolved[0..l]);
                src_len = l;
            } else if (std.mem.eql(u8, attr_name, "x")) {
                x = std.fmt.parseFloat(f32, attr_val) catch x;
            } else if (std.mem.eql(u8, attr_name, "y")) {
                y = std.fmt.parseFloat(f32, attr_val) catch y;
            } else if (std.mem.eql(u8, attr_name, "w") or std.mem.eql(u8, attr_name, "width")) {
                w = std.fmt.parseFloat(f32, attr_val) catch w;
            } else if (std.mem.eql(u8, attr_name, "h") or std.mem.eql(u8, attr_name, "height")) {
                h = std.fmt.parseFloat(f32, attr_val) catch h;
            } else if (std.mem.eql(u8, attr_name, "radius") or std.mem.eql(u8, attr_name, "corner_radius")) {
                radius = std.fmt.parseFloat(f32, attr_val) catch radius;
            } else if (std.mem.eql(u8, attr_name, "border_w")) {
                border_w = std.fmt.parseFloat(f32, attr_val) catch border_w;
            } else if (std.mem.eql(u8, attr_name, "current")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                current = std.fmt.parseInt(i32, resolved, 10) catch current;
            } else if (std.mem.eql(u8, attr_name, "max")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                max_val = std.fmt.parseInt(i32, resolved, 10) catch max_val;
            } else if (std.mem.eql(u8, attr_name, "size")) {
                size = std.fmt.parseFloat(f32, attr_val) catch size;
            } else if (std.mem.eql(u8, attr_name, "bg")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                bg_color = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "bg2") or std.mem.eql(u8, attr_name, "gradient_bottom")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                bg2_color = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "hover_bg")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                hover_bg_color = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "hover_bg2")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                hover_bg2_color = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "border")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                border_color = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "color")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                text_color = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "fill")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                fill_color = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "fill2")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                fill2_color = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "shadow")) {
                shadow_enabled = std.mem.eql(u8, attr_val, "true") or std.mem.eql(u8, attr_val, "1");
            } else if (std.mem.eql(u8, attr_name, "glow")) {
                glow_enabled = std.mem.eql(u8, attr_val, "true") or std.mem.eql(u8, attr_val, "1");
            }
        }

        // Di chuyển qua dấu đóng thẻ '>'
        while (i < xml_content.len and xml_content[i] != '>') i += 1;
        if (i < xml_content.len) i += 1;

        // Thêm node vào UI State tùy theo thẻ
        const rect = Rect{ .x = x, .y = y, .w = w, .h = h };
        if (std.mem.eql(u8, tag_name, "Window")) {
            state.addWindowEx(id_buf[0..id_len], title_buf[0..title_len], rect, bg_color, bg2_color, border_color, radius, shadow_enabled);
        } else if (std.mem.eql(u8, tag_name, "Panel") or std.mem.eql(u8, tag_name, "Slot")) {
            state.addPanelEx(id_buf[0..id_len], title_buf[0..title_len], rect, bg_color, bg2_color, border_color, radius, shadow_enabled);
        } else if (std.mem.eql(u8, tag_name, "Button")) {
            state.addButtonEx(
                id_buf[0..id_len],
                text_buf[0..text_len],
                action_buf[0..action_len],
                rect,
                bg_color,
                bg2_color,
                hover_bg_color,
                hover_bg2_color,
                border_color,
                text_color,
                radius,
                glow_enabled,
            );
        } else if (std.mem.eql(u8, tag_name, "Text")) {
            state.addText(id_buf[0..id_len], text_buf[0..text_len], x, y, text_color, size);
        } else if (std.mem.eql(u8, tag_name, "ProgressBar")) {
            var final_label: []const u8 = label_buf[0..label_len];
            var def_lbl_buf: [32]u8 = undefined;
            if (final_label.len == 0) {
                final_label = std.fmt.bufPrint(&def_lbl_buf, "{}/{}", .{ current, max_val }) catch "HP";
            }
            state.addProgressBarEx(
                id_buf[0..id_len],
                current,
                max_val,
                rect,
                fill_color,
                fill2_color,
                bg_color,
                border_color,
                final_label,
                radius,
                glow_enabled,
            );
        } else if (std.mem.eql(u8, tag_name, "Image") or std.mem.eql(u8, tag_name, "Avatar")) {
            state.addImage(
                id_buf[0..id_len],
                src_buf[0..src_len],
                rect,
                radius,
                border_color,
                border_w,
                bg_color,
            );
        }
    }
}

var temp_resolved_buf: [256]u8 = undefined;

/// Hỗ trợ cả {key} đơn thuần lẫn nội suy chuỗi và giải mã thực thể XML (&amp;, &lt;, &gt;, &quot;)
pub fn resolveDataBinding(val: []const u8, resolver: anytype) []const u8 {
    // Nếu không chứa '{' và cũng không chứa '&', trả về nguyên vẹn
    if (std.mem.indexOfScalar(u8, val, '{') == null and std.mem.indexOfScalar(u8, val, '&') == null) {
        return val;
    }

    var out_idx: usize = 0;
    var i: usize = 0;

    while (i < val.len and out_idx < temp_resolved_buf.len) {
        if (std.mem.startsWith(u8, val[i..], "&amp;")) {
            temp_resolved_buf[out_idx] = '&';
            out_idx += 1;
            i += 5;
            continue;
        } else if (std.mem.startsWith(u8, val[i..], "&lt;")) {
            temp_resolved_buf[out_idx] = '<';
            out_idx += 1;
            i += 4;
            continue;
        } else if (std.mem.startsWith(u8, val[i..], "&gt;")) {
            temp_resolved_buf[out_idx] = '>';
            out_idx += 1;
            i += 4;
            continue;
        } else if (std.mem.startsWith(u8, val[i..], "&quot;")) {
            temp_resolved_buf[out_idx] = '"';
            out_idx += 1;
            i += 6;
            continue;
        }

        if (val[i] == '{') {
            const start = i + 1;
            const end_opt = std.mem.indexOfScalarPos(u8, val, start, '}');
            if (end_opt) |end| {
                const key = val[start..end];
                var single_buf: [96]u8 = undefined;
                if (resolver(key, &single_buf)) |res| {
                    const c_len = @min(res.len, temp_resolved_buf.len - out_idx);
                    @memcpy(temp_resolved_buf[out_idx .. out_idx + c_len], res[0..c_len]);
                    out_idx += c_len;
                } else {
                    // Nếu không tìm thấy, giữ nguyên {key}
                    const full_placeholder = val[i .. end + 1];
                    const c_len = @min(full_placeholder.len, temp_resolved_buf.len - out_idx);
                    @memcpy(temp_resolved_buf[out_idx .. out_idx + c_len], full_placeholder[0..c_len]);
                    out_idx += c_len;
                }
                i = end + 1;
                continue;
            }
        }
        temp_resolved_buf[out_idx] = val[i];
        out_idx += 1;
        i += 1;
    }

    return temp_resolved_buf[0..out_idx];
}

test "parse xml color and attributes" {
    const c1 = parseColor("#ff0000");
    try std.testing.expectEqual(@as(f32, 1.0), c1[0]);
    try std.testing.expectEqual(@as(f32, 0.0), c1[1]);

    const rect = Rect{ .x = 10, .y = 20, .w = 100, .h = 50 };
    try std.testing.expect(rect.contains(50, 40));
    try std.testing.expect(!rect.contains(5, 5));
}

test "resolve data binding with interpolation" {
    const dummy_resolver = struct {
        fn resolve(key: []const u8, buf: []u8) ?[]const u8 {
            if (std.mem.eql(u8, key, "name")) {
                return std.fmt.bufPrint(buf, "Bach Tieu Thuan", .{}) catch null;
            }
            if (std.mem.eql(u8, key, "realm")) {
                return std.fmt.bufPrint(buf, "Luyen Khi", .{}) catch null;
            }
            return null;
        }
    }.resolve;

    const res = resolveDataBinding("Tu Si: {name} [{realm}]", dummy_resolver);
    try std.testing.expectEqualStrings("Tu Si: Bach Tieu Thuan [Luyen Khi]", res);
}
