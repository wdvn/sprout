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
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 0,
    h: f32 = 0,

    pub fn contains(self: Rect, px: f32, py: f32) bool {
        return px >= self.x and px <= (self.x + self.w) and py >= self.y and py <= (self.y + self.h);
    }
};

pub const NodeId = u16;
pub const INVALID_NODE: NodeId = 0xFFFF;

/// Đơn vị kích thước CSS (Pixels, Phần trăm %, hoặc Tự động Auto)
pub const Dimension = union(enum) {
    px: f32,
    percent: f32,
    auto,

    pub fn resolve(self: Dimension, parent_size: f32, fallback: f32) f32 {
        return switch (self) {
            .px => |v| v,
            .percent => |pct| parent_size * (pct / 100.0),
            .auto => fallback,
        };
    }
};

pub fn parseDimension(val: []const u8) Dimension {
    const trimmed = std.mem.trim(u8, val, " \t\r\n");
    if (trimmed.len == 0 or std.mem.eql(u8, trimmed, "auto")) {
        return .auto;
    }
    if (std.mem.endsWith(u8, trimmed, "%")) {
        const pct = std.fmt.parseFloat(f32, trimmed[0 .. trimmed.len - 1]) catch 0.0;
        return .{ .percent = pct };
    }
    if (std.mem.endsWith(u8, trimmed, "px")) {
        const px = std.fmt.parseFloat(f32, trimmed[0 .. trimmed.len - 2]) catch 0.0;
        return .{ .px = px };
    }
    const px = std.fmt.parseFloat(f32, trimmed) catch 0.0;
    return .{ .px = px };
}

fn cleanPx(val: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, val, " \t\r\n");
    if (std.mem.endsWith(u8, trimmed, "px")) {
        return trimmed[0 .. trimmed.len - 2];
    }
    return trimmed;
}

/// Mô hình hộp CSS: Khoảng cách lề (Padding, Margin)
pub const RectOffsets = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    pub fn uniform(v: f32) RectOffsets {
        return .{ .top = v, .right = v, .bottom = v, .left = v };
    }

    pub fn axes(x: f32, y: f32) RectOffsets {
        return .{ .top = y, .right = x, .bottom = y, .left = x };
    }
};

pub fn parseOffsets(val: []const u8) RectOffsets {
    const trimmed = std.mem.trim(u8, val, " \t\r\n");
    if (trimmed.len == 0) return .{};

    var parts: [4]f32 = [_]f32{0} ** 4;
    var part_count: usize = 0;

    var it = std.mem.splitAny(u8, trimmed, " \t,");
    while (it.next()) |token| {
        if (token.len == 0) continue;
        const clean = cleanPx(token);
        if (std.fmt.parseFloat(f32, clean)) |v| {
            if (part_count < 4) {
                parts[part_count] = v;
                part_count += 1;
            }
        } else |_| {}
    }

    if (part_count == 1) {
        return RectOffsets.uniform(parts[0]);
    } else if (part_count == 2) {
        return RectOffsets.axes(parts[1], parts[0]);
    } else if (part_count == 4) {
        return .{ .top = parts[0], .right = parts[1], .bottom = parts[2], .left = parts[3] };
    }
    return .{};
}

/// Mô hình dàn trang CSS
pub const LayoutMode = enum {
    none,       // Tọa độ tuyệt đối / thủ công (mặc định cho tương thích ngược)
    row,        // Flexbox Row: Xếp ngang tự động
    column,     // Flexbox Column: Xếp dọc tự động
    grid,       // 2D Grid: Lưới đa cột đa dòng
};

/// Căn chỉnh trên trục chính (Main Axis Alignment)
pub const JustifyContent = enum {
    start,
    center,
    end,
    space_between,
    space_around,
    space_evenly,
};

/// Căn chỉnh trên trục phụ (Cross Axis Alignment)
pub const AlignItems = enum {
    start,
    center,
    end,
    stretch,
};

/// Phân loại phần tử UI
pub const NodeTag = enum {
    window,
    panel,
    slot,
    button,
    text,
    progress_bar,
    image,
    container, // <Div>, <Container>, <Flex>, <Row>, <Col>, <Grid>
};

/// Cấu trúc nút cây phân cấp hoàn chỉnh (Hierarchical Tree Node)
pub const TreeNode = struct {
    id: [32]u8 = [_]u8{0} ** 32,
    id_len: usize = 0,
    tag: NodeTag = .container,

    // Quan hệ cây (Tree Hierarchy Links)
    parent: ?NodeId = null,
    first_child: ?NodeId = null,
    last_child: ?NodeId = null,
    next_sibling: ?NodeId = null,
    prev_sibling: ?NodeId = null,
    child_count: u16 = 0,

    // CSS Sizing & Box Model
    width: Dimension = .auto,
    height: Dimension = .auto,
    min_w: ?f32 = null,
    max_w: ?f32 = null,
    min_h: ?f32 = null,
    max_h: ?f32 = null,
    padding: RectOffsets = .{},
    margin: RectOffsets = .{},
    gap: f32 = 0,

    // CSS Flex / Layout Mode
    layout_mode: LayoutMode = .none,
    justify_content: JustifyContent = .start,
    align_items: AlignItems = .start,
    flex_grow: f32 = 0.0,
    flex_shrink: f32 = 1.0,
    is_absolute: bool = false,

    // Tọa độ thủ công / cố định
    pos_x: ?f32 = null,
    pos_y: ?f32 = null,

    // Dành riêng cho Grid (layout_mode == .grid)
    grid_cols: u16 = 1,
    grid_rows: u16 = 1,

    // Kết quả tính toán dàn trang (Bounding Box trên Canvas 960x760)
    rect: Rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 },

    // Phong cách đồ họa Shader hiện đại
    bg: Color = .{ 0, 0, 0, 0 },
    bg2: ?Color = null,
    hover_bg: Color = .{ 0, 0, 0, 0 },
    hover_bg2: ?Color = null,
    border: Color = .{ 0, 0, 0, 0 },
    border_w: f32 = 1.2,
    radius: f32 = 6.0,
    shadow: bool = false,
    glow: bool = false,

    // Dữ liệu nội dung phần tử
    title: [80]u8 = [_]u8{0} ** 80,
    title_len: usize = 0,
    text: [128]u8 = [_]u8{0} ** 128,
    text_len: usize = 0,
    text_color: Color = .{ 0.95, 0.98, 0.95, 1.0 },
    font_size: f32 = 14.0,

    action: [32]u8 = [_]u8{0} ** 32,
    action_len: usize = 0,

    src: [32]u8 = [_]u8{0} ** 32,
    src_len: usize = 0,

    bar_current: i32 = 100,
    bar_max: i32 = 100,
    fill_color: Color = .{ 0.20, 0.85, 0.40, 1.0 },
    fill2_color: ?Color = null,
    label: [48]u8 = [_]u8{0} ** 48,
    label_len: usize = 0,
};

/// Trình phân tích cú pháp CSS Mini cho chuỗi `style="..."`
pub fn parseCssStyle(node: *TreeNode, style_str: []const u8) void {
    var decl_it = std.mem.splitScalar(u8, style_str, ';');
    while (decl_it.next()) |decl| {
        const trimmed = std.mem.trim(u8, decl, " \t\r\n");
        if (trimmed.len == 0) continue;

        const colon_idx = std.mem.indexOfScalar(u8, trimmed, ':') orelse continue;
        const prop = std.mem.trim(u8, trimmed[0..colon_idx], " \t\r\n");
        const val = std.mem.trim(u8, trimmed[colon_idx + 1 ..], " \t\r\n");

        if (std.mem.eql(u8, prop, "display")) {
            if (std.mem.eql(u8, val, "flex")) {
                if (node.layout_mode == .none) node.layout_mode = .row;
            } else if (std.mem.eql(u8, val, "grid")) {
                node.layout_mode = .grid;
            } else if (std.mem.eql(u8, val, "none")) {
                node.layout_mode = .none;
            }
        } else if (std.mem.eql(u8, prop, "flex-direction")) {
            if (std.mem.eql(u8, val, "row") or std.mem.eql(u8, val, "row-reverse")) {
                node.layout_mode = .row;
            } else if (std.mem.eql(u8, val, "column") or std.mem.eql(u8, val, "column-reverse")) {
                node.layout_mode = .column;
            }
        } else if (std.mem.eql(u8, prop, "gap")) {
            const clean = cleanPx(val);
            node.gap = std.fmt.parseFloat(f32, clean) catch node.gap;
        } else if (std.mem.eql(u8, prop, "padding")) {
            node.padding = parseOffsets(val);
        } else if (std.mem.eql(u8, prop, "padding-left")) {
            const clean = cleanPx(val);
            node.padding.left = std.fmt.parseFloat(f32, clean) catch node.padding.left;
        } else if (std.mem.eql(u8, prop, "padding-right")) {
            const clean = cleanPx(val);
            node.padding.right = std.fmt.parseFloat(f32, clean) catch node.padding.right;
        } else if (std.mem.eql(u8, prop, "padding-top")) {
            const clean = cleanPx(val);
            node.padding.top = std.fmt.parseFloat(f32, clean) catch node.padding.top;
        } else if (std.mem.eql(u8, prop, "padding-bottom")) {
            const clean = cleanPx(val);
            node.padding.bottom = std.fmt.parseFloat(f32, clean) catch node.padding.bottom;
        } else if (std.mem.eql(u8, prop, "margin")) {
            node.margin = parseOffsets(val);
        } else if (std.mem.eql(u8, prop, "justify-content")) {
            if (std.mem.eql(u8, val, "flex-start") or std.mem.eql(u8, val, "start")) {
                node.justify_content = .start;
            } else if (std.mem.eql(u8, val, "center")) {
                node.justify_content = .center;
            } else if (std.mem.eql(u8, val, "flex-end") or std.mem.eql(u8, val, "end")) {
                node.justify_content = .end;
            } else if (std.mem.eql(u8, val, "space-between")) {
                node.justify_content = .space_between;
            } else if (std.mem.eql(u8, val, "space-around")) {
                node.justify_content = .space_around;
            }
        } else if (std.mem.eql(u8, prop, "align-items")) {
            if (std.mem.eql(u8, val, "flex-start") or std.mem.eql(u8, val, "start")) {
                node.align_items = .start;
            } else if (std.mem.eql(u8, val, "center")) {
                node.align_items = .center;
            } else if (std.mem.eql(u8, val, "flex-end") or std.mem.eql(u8, val, "end")) {
                node.align_items = .end;
            } else if (std.mem.eql(u8, val, "stretch")) {
                node.align_items = .stretch;
            }
        } else if (std.mem.eql(u8, prop, "width")) {
            node.width = parseDimension(val);
        } else if (std.mem.eql(u8, prop, "height")) {
            node.height = parseDimension(val);
        } else if (std.mem.eql(u8, prop, "background") or std.mem.eql(u8, prop, "background-color")) {
            node.bg = parseColor(val);
        } else if (std.mem.eql(u8, prop, "border-color")) {
            node.border = parseColor(val);
        } else if (std.mem.eql(u8, prop, "border-width")) {
            const clean = cleanPx(val);
            node.border_w = std.fmt.parseFloat(f32, clean) catch node.border_w;
        } else if (std.mem.eql(u8, prop, "border-radius")) {
            const clean = cleanPx(val);
            node.radius = std.fmt.parseFloat(f32, clean) catch node.radius;
        } else if (std.mem.eql(u8, prop, "color")) {
            node.text_color = parseColor(val);
        }
    }
}

pub const UIState = struct {
    nodes: [512]TreeNode = [_]TreeNode{.{}} ** 512,
    node_count: usize = 0,

    root_nodes: [32]NodeId = [_]NodeId{0} ** 32,
    root_count: usize = 0,

    mouse_x: f32 = 0,
    mouse_y: f32 = 0,
    mouse_down: bool = false,
    hovered_button: ?NodeId = null,

    pub fn clear(self: *UIState) void {
        self.node_count = 0;
        self.root_count = 0;
        self.hovered_button = null;
    }

    pub fn allocNode(self: *UIState, tag: NodeTag) ?NodeId {
        if (self.node_count >= self.nodes.len) return null;
        const id: NodeId = @intCast(self.node_count);
        self.node_count += 1;
        self.nodes[id] = TreeNode{ .tag = tag };
        return id;
    }

    pub fn addChild(self: *UIState, parent_id: NodeId, child_id: NodeId) void {
        var parent = &self.nodes[parent_id];
        var child = &self.nodes[child_id];
        child.parent = parent_id;

        if (parent.first_child == null) {
            parent.first_child = child_id;
            parent.last_child = child_id;
        } else {
            const last_id = parent.last_child.?;
            self.nodes[last_id].next_sibling = child_id;
            child.prev_sibling = last_id;
            parent.last_child = child_id;
        }
        parent.child_count += 1;
    }

    pub fn handleMouseMove(self: *UIState, mx: f32, my: f32) void {
        self.mouse_x = mx;
        self.mouse_y = my;
        self.hovered_button = null;

        var i = self.node_count;
        while (i > 0) {
            i -= 1;
            const node = &self.nodes[i];
            if (node.tag == .button and node.rect.contains(mx, my)) {
                self.hovered_button = @intCast(i);
                break;
            }
        }
    }

    pub fn handleMouseDown(self: *UIState, mx: f32, my: f32) ?[]const u8 {
        self.mouse_x = mx;
        self.mouse_y = my;
        self.mouse_down = true;

        var i = self.node_count;
        while (i > 0) {
            i -= 1;
            const node = &self.nodes[i];
            if (node.tag == .button and node.rect.contains(mx, my)) {
                if (node.action_len > 0) {
                    return node.action[0..node.action_len];
                } else if (node.id_len > 0) {
                    return node.id[0..node.id_len];
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

    // Các hàm phụ trợ tương thích ngược (Backward Compatible APIs)
    pub fn addImage(self: *UIState, id: []const u8, src: []const u8, rect: Rect, radius: f32, border: Color, border_w: f32, bg: Color) void {
        const nid = self.allocNode(.image) orelse return;
        var node = &self.nodes[nid];
        const id_l = @min(id.len, node.id.len);
        @memcpy(node.id[0..id_l], id[0..id_l]);
        node.id_len = id_l;

        const src_l = @min(src.len, node.src.len);
        @memcpy(node.src[0..src_l], src[0..src_l]);
        node.src_len = src_l;

        node.rect = rect;
        node.pos_x = rect.x;
        node.pos_y = rect.y;
        node.width = .{ .px = rect.w };
        node.height = .{ .px = rect.h };
        node.radius = radius;
        node.border = border;
        node.border_w = border_w;
        node.bg = bg;
        node.is_absolute = true;

        if (self.root_count < self.root_nodes.len) {
            self.root_nodes[self.root_count] = nid;
            self.root_count += 1;
        }
    }

    pub fn addWindowEx(self: *UIState, id: []const u8, title: []const u8, rect: Rect, bg: Color, bg2: ?Color, border: Color, radius: f32, shadow: bool) void {
        const nid = self.allocNode(.window) orelse return;
        var node = &self.nodes[nid];
        const id_l = @min(id.len, node.id.len);
        @memcpy(node.id[0..id_l], id[0..id_l]);
        node.id_len = id_l;

        const t_l = @min(title.len, node.title.len);
        @memcpy(node.title[0..t_l], title[0..t_l]);
        node.title_len = t_l;

        node.rect = rect;
        node.pos_x = rect.x;
        node.pos_y = rect.y;
        node.width = .{ .px = rect.w };
        node.height = .{ .px = rect.h };
        node.bg = bg;
        node.bg2 = bg2;
        node.border = border;
        node.radius = radius;
        node.shadow = shadow;
        node.is_absolute = true;

        if (self.root_count < self.root_nodes.len) {
            self.root_nodes[self.root_count] = nid;
            self.root_count += 1;
        }
    }

    pub fn addWindow(self: *UIState, id: []const u8, title: []const u8, rect: Rect, bg: Color, border: Color) void {
        self.addWindowEx(id, title, rect, bg, null, border, 10.0, true);
    }

    pub fn addPanelEx(self: *UIState, id: []const u8, title: []const u8, rect: Rect, bg: Color, bg2: ?Color, border: Color, radius: f32, shadow: bool) void {
        const nid = self.allocNode(.panel) orelse return;
        var node = &self.nodes[nid];
        const id_l = @min(id.len, node.id.len);
        @memcpy(node.id[0..id_l], id[0..id_l]);
        node.id_len = id_l;

        const t_l = @min(title.len, node.title.len);
        @memcpy(node.title[0..t_l], title[0..t_l]);
        node.title_len = t_l;

        node.rect = rect;
        node.pos_x = rect.x;
        node.pos_y = rect.y;
        node.width = .{ .px = rect.w };
        node.height = .{ .px = rect.h };
        node.bg = bg;
        node.bg2 = bg2;
        node.border = border;
        node.radius = radius;
        node.shadow = shadow;
        node.is_absolute = true;

        if (self.root_count < self.root_nodes.len) {
            self.root_nodes[self.root_count] = nid;
            self.root_count += 1;
        }
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
        const nid = self.allocNode(.button) orelse return;
        var node = &self.nodes[nid];
        const id_l = @min(id.len, node.id.len);
        @memcpy(node.id[0..id_l], id[0..id_l]);
        node.id_len = id_l;

        const t_l = @min(text.len, node.text.len);
        @memcpy(node.text[0..t_l], text[0..t_l]);
        node.text_len = t_l;

        const a_l = @min(action.len, node.action.len);
        @memcpy(node.action[0..a_l], action[0..a_l]);
        node.action_len = a_l;

        node.rect = rect;
        node.pos_x = rect.x;
        node.pos_y = rect.y;
        node.width = .{ .px = rect.w };
        node.height = .{ .px = rect.h };
        node.bg = bg;
        node.bg2 = bg2;
        node.hover_bg = hover_bg;
        node.hover_bg2 = hover_bg2;
        node.border = border;
        node.text_color = text_color;
        node.radius = radius;
        node.glow = glow;
        node.is_absolute = true;

        if (self.root_count < self.root_nodes.len) {
            self.root_nodes[self.root_count] = nid;
            self.root_count += 1;
        }
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
        const nid = self.allocNode(.text) orelse return;
        var node = &self.nodes[nid];
        const id_l = @min(id.len, node.id.len);
        @memcpy(node.id[0..id_l], id[0..id_l]);
        node.id_len = id_l;

        const t_l = @min(text.len, node.text.len);
        @memcpy(node.text[0..t_l], text[0..t_l]);
        node.text_len = t_l;

        node.rect = .{ .x = x, .y = y, .w = @as(f32, @floatFromInt(t_l)) * 8.0, .h = size };
        node.pos_x = x;
        node.pos_y = y;
        node.text_color = color;
        node.font_size = size;
        node.is_absolute = true;

        if (self.root_count < self.root_nodes.len) {
            self.root_nodes[self.root_count] = nid;
            self.root_count += 1;
        }
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
        const nid = self.allocNode(.progress_bar) orelse return;
        var node = &self.nodes[nid];
        const id_l = @min(id.len, node.id.len);
        @memcpy(node.id[0..id_l], id[0..id_l]);
        node.id_len = id_l;

        node.rect = rect;
        node.pos_x = rect.x;
        node.pos_y = rect.y;
        node.width = .{ .px = rect.w };
        node.height = .{ .px = rect.h };
        node.bar_current = current;
        node.bar_max = max;
        node.fill_color = fill_color;
        node.fill2_color = fill2;
        node.bg = bg_color;
        node.border = border_color;
        node.radius = radius;
        node.glow = glow;
        node.is_absolute = true;

        const l_l = @min(label.len, node.label.len);
        @memcpy(node.label[0..l_l], label[0..l_l]);
        node.label_len = l_l;

        if (self.root_count < self.root_nodes.len) {
            self.root_nodes[self.root_count] = nid;
            self.root_count += 1;
        }
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

    /// Thuật toán dàn trang cây tự động (Tree-based CSS Layout Solver)
    pub fn computeTreeLayout(self: *UIState) void {
        const canvas_w: f32 = 960.0;
        const canvas_h: f32 = 760.0;
        const canvas_rect = Rect{ .x = 0, .y = 0, .w = canvas_w, .h = canvas_h };

        for (0..self.root_count) |i| {
            const root_id = self.root_nodes[i];
            self.layoutNode(root_id, canvas_rect);
        }
    }

    fn layoutNode(self: *UIState, node_id: NodeId, parent_inner: Rect) void {
        var node = &self.nodes[node_id];

        // 1. Xác định vị trí và kích thước của node
        if (node.pos_x) |px| {
            if (node.is_absolute) {
                node.rect.x = px;
            } else {
                node.rect.x = parent_inner.x + px + node.margin.left;
            }
        }
        if (node.pos_y) |py| {
            if (node.is_absolute) {
                node.rect.y = py;
            } else {
                node.rect.y = parent_inner.y + py + node.margin.top;
            }
        }

        // Giải quyết chiều rộng và chiều cao nếu có phần trăm (%)
        node.rect.w = node.width.resolve(parent_inner.w, node.rect.w);
        node.rect.h = node.height.resolve(parent_inner.h, node.rect.h);

        // Áp dụng giới hạn Min/Max nếu có
        if (node.min_w) |mw| node.rect.w = @max(node.rect.w, mw);
        if (node.max_w) |mw| node.rect.w = @min(node.rect.w, mw);
        if (node.min_h) |mh| node.rect.h = @max(node.rect.h, mh);
        if (node.max_h) |mh| node.rect.h = @min(node.rect.h, mh);

        // Intrinsic size cho Text node nếu chưa có kích thước cố định
        if (node.tag == .text) {
            if (node.rect.w <= 0.0) {
                node.rect.w = @as(f32, @floatFromInt(node.text_len)) * 8.0;
            }
            if (node.rect.h <= 0.0) {
                node.rect.h = node.font_size;
            }
        }

        // 2. Tính toán Hộp nội dung bên trong (Inner Content Rect)
        const inner_x = node.rect.x + node.padding.left;
        var inner_y = node.rect.y + node.padding.top;
        const inner_w = @max(0.0, node.rect.w - node.padding.left - node.padding.right);
        var inner_h = @max(0.0, node.rect.h - node.padding.top - node.padding.bottom);

        // Nếu là Window có thanh tiêu đề, trừ 24px chiều cao tiêu đề
        if (node.tag == .window and node.title_len > 0) {
            const bar_h: f32 = 24.0;
            inner_y += bar_h;
            inner_h = @max(0.0, inner_h - bar_h);
        }

        if (node.child_count == 0) return;

        // 3. Dàn trang các phần tử con tùy theo `layout_mode`
        const inner_rect = Rect{ .x = inner_x, .y = inner_y, .w = inner_w, .h = inner_h };

        switch (node.layout_mode) {
            .row => {
                // FLEX ROW: Xếp ngang
                var total_children_w: f32 = 0;
                var child_opt = node.first_child;
                var flow_child_count: usize = 0;

                while (child_opt) |cid| {
                    const c = &self.nodes[cid];
                    if (!c.is_absolute) {
                        const cw = c.width.resolve(inner_w, c.rect.w);
                        total_children_w += cw + c.margin.left + c.margin.right;
                        flow_child_count += 1;
                    }
                    child_opt = c.next_sibling;
                }

                if (flow_child_count > 1) {
                    total_children_w += node.gap * @as(f32, @floatFromInt(flow_child_count - 1));
                }

                var curr_x: f32 = inner_x;
                var effective_gap: f32 = node.gap;

                switch (node.justify_content) {
                    .start => curr_x = inner_x,
                    .center => curr_x = inner_x + @max(0.0, (inner_w - total_children_w) * 0.5),
                    .end => curr_x = inner_x + inner_w - total_children_w,
                    .space_between => {
                        curr_x = inner_x;
                        if (flow_child_count > 1) {
                            var sum_cw: f32 = 0;
                            var it_c = node.first_child;
                            while (it_c) |cid| {
                                const c = &self.nodes[cid];
                                if (!c.is_absolute) sum_cw += c.width.resolve(inner_w, c.rect.w);
                                it_c = c.next_sibling;
                            }
                            effective_gap = @max(0.0, (inner_w - sum_cw) / @as(f32, @floatFromInt(flow_child_count - 1)));
                        }
                    },
                    .space_around => {
                        if (flow_child_count > 0) {
                            var sum_cw: f32 = 0;
                            var it_c = node.first_child;
                            while (it_c) |cid| {
                                const c = &self.nodes[cid];
                                if (!c.is_absolute) sum_cw += c.width.resolve(inner_w, c.rect.w);
                                it_c = c.next_sibling;
                            }
                            effective_gap = @max(0.0, (inner_w - sum_cw) / @as(f32, @floatFromInt(flow_child_count)));
                            curr_x = inner_x + effective_gap * 0.5;
                        }
                    },
                    .space_evenly => {
                        if (flow_child_count > 0) {
                            var sum_cw: f32 = 0;
                            var it_c = node.first_child;
                            while (it_c) |cid| {
                                const c = &self.nodes[cid];
                                if (!c.is_absolute) sum_cw += c.width.resolve(inner_w, c.rect.w);
                                it_c = c.next_sibling;
                            }
                            effective_gap = @max(0.0, (inner_w - sum_cw) / @as(f32, @floatFromInt(flow_child_count + 1)));
                            curr_x = inner_x + effective_gap;
                        }
                    },
                }

                child_opt = node.first_child;
                while (child_opt) |cid| {
                    var c = &self.nodes[cid];
                    if (!c.is_absolute) {
                        const cw = c.width.resolve(inner_w, c.rect.w);
                        var ch = c.height.resolve(inner_h, c.rect.h);

                        var cy: f32 = inner_y + c.margin.top;
                        switch (node.align_items) {
                            .start => cy = inner_y + c.margin.top,
                            .center => cy = inner_y + @max(0.0, (inner_h - ch) * 0.5),
                            .end => cy = inner_y + inner_h - ch - c.margin.bottom,
                            .stretch => {
                                ch = @max(0.0, inner_h - c.margin.top - c.margin.bottom);
                                cy = inner_y + c.margin.top;
                            },
                        }

                        c.rect = .{
                            .x = curr_x + c.margin.left,
                            .y = cy,
                            .w = cw,
                            .h = ch,
                        };
                        curr_x += cw + c.margin.left + c.margin.right + effective_gap;
                    }
                    self.layoutNode(cid, c.rect);
                    child_opt = c.next_sibling;
                }
            },

            .column => {
                // FLEX COLUMN: Xếp dọc
                var total_children_h: f32 = 0;
                var child_opt = node.first_child;
                var flow_child_count: usize = 0;

                while (child_opt) |cid| {
                    const c = &self.nodes[cid];
                    if (!c.is_absolute) {
                        const ch = c.height.resolve(inner_h, c.rect.h);
                        total_children_h += ch + c.margin.top + c.margin.bottom;
                        flow_child_count += 1;
                    }
                    child_opt = c.next_sibling;
                }

                if (flow_child_count > 1) {
                    total_children_h += node.gap * @as(f32, @floatFromInt(flow_child_count - 1));
                }

                var curr_y: f32 = inner_y;
                var effective_gap: f32 = node.gap;

                switch (node.justify_content) {
                    .start => curr_y = inner_y,
                    .center => curr_y = inner_y + @max(0.0, (inner_h - total_children_h) * 0.5),
                    .end => curr_y = inner_y + inner_h - total_children_h,
                    .space_between => {
                        curr_y = inner_y;
                        if (flow_child_count > 1) {
                            var sum_ch: f32 = 0;
                            var it_c = node.first_child;
                            while (it_c) |cid| {
                                const c = &self.nodes[cid];
                                if (!c.is_absolute) sum_ch += c.height.resolve(inner_h, c.rect.h);
                                it_c = c.next_sibling;
                            }
                            effective_gap = @max(0.0, (inner_h - sum_ch) / @as(f32, @floatFromInt(flow_child_count - 1)));
                        }
                    },
                    else => {},
                }

                child_opt = node.first_child;
                while (child_opt) |cid| {
                    var c = &self.nodes[cid];
                    if (!c.is_absolute) {
                        var cw = c.width.resolve(inner_w, c.rect.w);
                        const ch = c.height.resolve(inner_h, c.rect.h);

                        var cx: f32 = inner_x + c.margin.left;
                        switch (node.align_items) {
                            .start => cx = inner_x + c.margin.left,
                            .center => cx = inner_x + @max(0.0, (inner_w - cw) * 0.5),
                            .end => cx = inner_x + inner_w - cw - c.margin.right,
                            .stretch => {
                                cw = @max(0.0, inner_w - c.margin.left - c.margin.right);
                                cx = inner_x + c.margin.left;
                            },
                        }

                        c.rect = .{
                            .x = cx,
                            .y = curr_y + c.margin.top,
                            .w = cw,
                            .h = ch,
                        };
                        curr_y += ch + c.margin.top + c.margin.bottom + effective_gap;
                    }
                    self.layoutNode(cid, c.rect);
                    child_opt = c.next_sibling;
                }
            },

            .grid => {
                // 2D GRID: Bàn cờ đa cột
                const cols = @max(1, node.grid_cols);
                const col_w = @max(1.0, (inner_w - node.gap * @as(f32, @floatFromInt(cols - 1))) / @as(f32, @floatFromInt(cols)));

                var child_opt = node.first_child;
                var idx: usize = 0;

                while (child_opt) |cid| {
                    var c = &self.nodes[cid];
                    if (!c.is_absolute) {
                        const col_idx = idx % cols;
                        const row_idx = idx / cols;

                        const cw = c.width.resolve(col_w, col_w);
                        var ch = c.height.resolve(inner_h, c.rect.h);
                        if (ch <= 0.0) ch = cw; // Mặc định tỷ lệ vuông 1:1 nếu chưa có chiều cao

                        c.rect = .{
                            .x = inner_x + @as(f32, @floatFromInt(col_idx)) * (col_w + node.gap) + c.margin.left,
                            .y = inner_y + @as(f32, @floatFromInt(row_idx)) * (ch + node.gap) + c.margin.top,
                            .w = cw,
                            .h = ch,
                        };
                        idx += 1;
                    }
                    self.layoutNode(cid, c.rect);
                    child_opt = c.next_sibling;
                }
            },

            .none => {
                // MANUAL / ABSOLUTE: Tọa độ thủ công hoặc tương đối
                var child_opt = node.first_child;
                while (child_opt) |cid| {
                    const c = &self.nodes[cid];
                    self.layoutNode(cid, inner_rect);
                    child_opt = c.next_sibling;
                }
            },
        }
    }

    /// Render drop shadows mềm dưới các khung Window và Card nổi
    pub fn renderShadows(self: *UIState, draw_rect_modern: anytype) void {
        for (0..self.node_count) |i| {
            const n = &self.nodes[i];
            if (!n.shadow or n.rect.w <= 0.0 or n.rect.h <= 0.0) continue;
            const ndc = pxToNdc(n.rect.x, n.rect.y + 6.0, n.rect.w, n.rect.h);
            draw_rect_modern(ndc.ndc_x, ndc.ndc_y, ndc.ndc_hw, ndc.ndc_hh, .{ 0.0, 0.0, 0.0, 0.5 }, .{ 0.0, 0.0, 0.0, 0.5 }, .{ 0, 0, 0, 0 }, n.radius + 4.0, 0.0, true, false);
        }
    }

    /// Render toàn bộ các quad bo góc SDF (Windows, Panels, Slots, ProgressBars, Buttons)
    pub fn renderQuads(self: *UIState, draw_rect_modern: anytype) void {
        for (0..self.node_count) |i| {
            const n = &self.nodes[i];
            if (n.rect.w <= 0.0 or n.rect.h <= 0.0) continue;

            switch (n.tag) {
                .window => {
                    const ndc = pxToNdc(n.rect.x, n.rect.y, n.rect.w, n.rect.h);
                    const bg_bot = n.bg2 orelse n.bg;
                    draw_rect_modern(ndc.ndc_x, ndc.ndc_y, ndc.ndc_hw, ndc.ndc_hh, n.bg, bg_bot, n.border, n.radius, 1.5, false, false);

                    if (n.title_len > 0) {
                        const bar_h: f32 = 24.0;
                        const t_ndc = pxToNdc(n.rect.x + 2.0, n.rect.y + 2.0, n.rect.w - 4.0, bar_h);
                        draw_rect_modern(t_ndc.ndc_x, t_ndc.ndc_y, t_ndc.ndc_hw, t_ndc.ndc_hh, .{ 0.08, 0.18, 0.15, 0.95 }, .{ 0.04, 0.10, 0.08, 0.95 }, .{ 0.18, 0.38, 0.30, 0.8 }, @max(0.0, n.radius - 2.0), 1.0, false, false);
                    }
                },

                .panel, .slot, .container => {
                    if (n.bg[3] > 0.01 or n.border[3] > 0.01) {
                        const ndc = pxToNdc(n.rect.x, n.rect.y, n.rect.w, n.rect.h);
                        const bg_bot = n.bg2 orelse n.bg;
                        draw_rect_modern(ndc.ndc_x, ndc.ndc_y, ndc.ndc_hw, ndc.ndc_hh, n.bg, bg_bot, n.border, n.radius, n.border_w, false, false);
                    }
                },

                .progress_bar => {
                    const bg_ndc = pxToNdc(n.rect.x, n.rect.y, n.rect.w, n.rect.h);
                    draw_rect_modern(bg_ndc.ndc_x, bg_ndc.ndc_y, bg_ndc.ndc_hw, bg_ndc.ndc_hh, n.bg, n.bg, n.border, n.radius, 1.2, false, false);

                    if (n.bar_current > 0 and n.bar_max > 0) {
                        const ratio = std.math.clamp(@as(f32, @floatFromInt(n.bar_current)) / @as(f32, @floatFromInt(n.bar_max)), 0.0, 1.0);
                        const fill_w = (n.rect.w - 2.0) * ratio;
                        if (fill_w > 1.0) {
                            const fill_ndc = pxToNdc(n.rect.x + 1.0, n.rect.y + 1.0, fill_w, n.rect.h - 2.0);
                            const fill_bot = n.fill2_color orelse n.fill_color;
                            const is_critical = (n.bar_current * 4 <= n.bar_max);
                            draw_rect_modern(fill_ndc.ndc_x, fill_ndc.ndc_y, fill_ndc.ndc_hw, fill_ndc.ndc_hh, n.fill_color, fill_bot, n.fill_color, @max(0.0, n.radius - 1.0), 0.0, false, n.glow or is_critical);
                        }
                    }
                },

                .button => {
                    const is_hovered = (self.hovered_button != null and self.hovered_button.? == @as(NodeId, @intCast(i)));
                    const bg_top = if (is_hovered) n.hover_bg else n.bg;
                    const bg_bot = if (is_hovered) (n.hover_bg2 orelse n.hover_bg) else (n.bg2 orelse n.bg);
                    const border = if (is_hovered) parseColor("#ffe57f") else n.border;

                    const ndc = pxToNdc(n.rect.x, n.rect.y, n.rect.w, n.rect.h);
                    draw_rect_modern(ndc.ndc_x, ndc.ndc_y, ndc.ndc_hw, ndc.ndc_hh, bg_top, bg_bot, border, n.radius, n.border_w, false, is_hovered or n.glow);
                },

                else => {},
            }
        }
    }

    /// Render tất cả ảnh chân dung Linh thú và Tu sĩ
    pub fn renderImages(self: *UIState, draw_rect_modern: anytype, draw_texture: anytype) void {
        for (0..self.node_count) |i| {
            const n = &self.nodes[i];
            if ((n.tag == .image or n.src_len > 0) and n.rect.w > 0.0 and n.rect.h > 0.0) {
                const ndc = pxToNdc(n.rect.x, n.rect.y, n.rect.w, n.rect.h);
                draw_rect_modern(ndc.ndc_x, ndc.ndc_y, ndc.ndc_hw, ndc.ndc_hh, n.bg, n.bg, n.border, n.radius, n.border_w, false, false);

                if (n.src_len > 0) {
                    const margin: f32 = 3.0;
                    const inner_ndc = pxToNdc(n.rect.x + margin, n.rect.y + margin, n.rect.w - margin * 2.0, n.rect.h - margin * 2.0);
                    draw_texture(n.src[0..n.src_len], inner_ndc.ndc_x, inner_ndc.ndc_y, inner_ndc.ndc_hw, inner_ndc.ndc_hh);
                }
            }
        }
    }

    /// Render tất cả tiêu đề, nhãn text, chỉ số HP và chữ trên nút bằng Font Atlas UTF-8 sắc nét
    pub fn renderTexts(self: *UIState, draw_utf8: anytype) void {
        for (0..self.node_count) |i| {
            const n = &self.nodes[i];
            if (n.tag != .text and (n.rect.w <= 0.0 or n.rect.h <= 0.0)) continue;

            switch (n.tag) {
                .window, .panel, .slot => {
                    if (n.title_len > 0) {
                        const font_sz: f32 = 14.0;
                        const tx = n.rect.x + 10.0;
                        const ty = n.rect.y + 5.0;
                        draw_utf8(n.title[0..n.title_len], tx, ty, font_sz, .{ 1.0, 0.85, 0.25, 1.0 });
                    }
                },

                .button => {
                    if (n.text_len > 0) {
                        const font_sz = if (n.font_size > 0.0) n.font_size else 14.0;
                        const approx_w = @as(f32, @floatFromInt(n.text_len)) * (font_sz * 0.52);
                        const tx = n.rect.x + @max(4.0, (n.rect.w - approx_w) * 0.5);
                        const ty = n.rect.y + @max(0.0, (n.rect.h - font_sz) * 0.5) - 2.0;
                        draw_utf8(n.text[0..n.text_len], tx, ty, font_sz, n.text_color);
                    }
                },

                .text => {
                    if (n.text_len > 0) {
                        const font_sz = if (n.font_size > 0.0) n.font_size else 14.0;
                        draw_utf8(n.text[0..n.text_len], n.rect.x, n.rect.y, font_sz, n.text_color);
                    }
                },

                .progress_bar => {
                    if (n.label_len > 0) {
                        const font_sz: f32 = 12.0;
                        const approx_w = @as(f32, @floatFromInt(n.label_len)) * (font_sz * 0.52);
                        const tx = n.rect.x + @max(2.0, (n.rect.w - approx_w) * 0.5);
                        const ty = n.rect.y + @max(0.0, (n.rect.h - font_sz) * 0.5) - 2.0;
                        draw_utf8(n.label[0..n.label_len], tx, ty, font_sz, .{ 1.0, 1.0, 1.0, 1.0 });
                    }
                },

                else => {},
            }
        }
    }
};

pub var ui_state = UIState{};

/// Simple XML Parser cho Ngôn ngữ UI Mockup hỗ trợ Tree Node & CSS
pub fn parseXmlUI(xml_content: []const u8, state: *UIState, data_resolver: anytype) void {
    state.clear();

    var parent_stack: [32]NodeId = undefined;
    var parent_stack_len: usize = 0;

    var i: usize = 0;
    while (i < xml_content.len) {
        // Tìm thẻ bắt đầu '<'
        while (i < xml_content.len and xml_content[i] != '<') i += 1;
        if (i >= xml_content.len) break;
        i += 1; // bỏ qua '<'

        // Xử lý thẻ đóng </... > -> Pop parent stack
        if (i < xml_content.len and xml_content[i] == '/') {
            while (i < xml_content.len and xml_content[i] != '>') i += 1;
            if (i < xml_content.len) i += 1;
            if (parent_stack_len > 0) {
                parent_stack_len -= 1;
            }
            continue;
        }

        // Bỏ qua comment <!-- ... -->
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

        // Xác định loại node tag
        var tag_kind: NodeTag = .container;
        var is_container: bool = false;
        var default_layout: LayoutMode = .none;

        if (std.mem.eql(u8, tag_name, "Window")) {
            tag_kind = .window;
            is_container = true;
        } else if (std.mem.eql(u8, tag_name, "Panel")) {
            tag_kind = .panel;
            is_container = true;
        } else if (std.mem.eql(u8, tag_name, "Slot")) {
            tag_kind = .slot;
            is_container = true;
        } else if (std.mem.eql(u8, tag_name, "Button")) {
            tag_kind = .button;
        } else if (std.mem.eql(u8, tag_name, "Text")) {
            tag_kind = .text;
        } else if (std.mem.eql(u8, tag_name, "ProgressBar")) {
            tag_kind = .progress_bar;
        } else if (std.mem.eql(u8, tag_name, "Image") or std.mem.eql(u8, tag_name, "Avatar")) {
            tag_kind = .image;
        } else if (std.mem.eql(u8, tag_name, "Row")) {
            tag_kind = .container;
            is_container = true;
            default_layout = .row;
        } else if (std.mem.eql(u8, tag_name, "Col") or std.mem.eql(u8, tag_name, "Column")) {
            tag_kind = .container;
            is_container = true;
            default_layout = .column;
        } else if (std.mem.eql(u8, tag_name, "Grid")) {
            tag_kind = .container;
            is_container = true;
            default_layout = .grid;
        } else if (std.mem.eql(u8, tag_name, "Div") or std.mem.eql(u8, tag_name, "Container") or std.mem.eql(u8, tag_name, "Flex")) {
            tag_kind = .container;
            is_container = true;
        } else {
            // Thẻ không xác định (như <PartyUI>, <BattleUI>), coi như root wrapper
            is_container = true;
        }

        const node_id_opt = state.allocNode(tag_kind);
        if (node_id_opt == null) {
            // Hết dung lượng pool node, bỏ qua thẻ
            while (i < xml_content.len and xml_content[i] != '>') i += 1;
            if (i < xml_content.len) i += 1;
            continue;
        }
        const node_id = node_id_opt.?;
        var node = &state.nodes[node_id];
        node.layout_mode = default_layout;

        // Thiết lập giá trị mặc định theo loại tag
        switch (tag_kind) {
            .window => {
                node.bg = parseColor("#0c1816f8");
                node.border = parseColor("#c3a041");
                node.radius = 10.0;
                node.shadow = true;
            },
            .panel, .slot => {
                node.bg = parseColor("#0c1816f8");
                node.border = parseColor("#265546");
                node.radius = 8.0;
            },
            .button => {
                node.bg = parseColor("#18342c");
                node.hover_bg = parseColor("#265546");
                node.border = parseColor("#c3a041");
                node.text_color = parseColor("#ebf8f2");
                node.radius = 6.0;
                node.rect.w = 100;
                node.rect.h = 30;
            },
            .text => {
                node.text_color = parseColor("#ebf8f2");
                node.font_size = 14;
            },
            .progress_bar => {
                node.fill_color = parseColor("#32d264");
                node.bg = parseColor("#101a18");
                node.border = parseColor("#3c5a50");
                node.radius = 4.0;
                node.rect.w = 100;
                node.rect.h = 16;
            },
            .image => {
                node.bg = parseColor("#040e0c");
                node.border = parseColor("#c3a041");
                node.radius = 6.0;
                node.rect.w = 48;
                node.rect.h = 48;
            },
            .container => {},
        }

        var is_self_closing: bool = false;
        var has_pos_x: bool = false;
        var has_pos_y: bool = false;

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

            // Xử lý các thuộc tính
            if (std.mem.eql(u8, attr_name, "id")) {
                const l = @min(attr_val.len, node.id.len);
                @memcpy(node.id[0..l], attr_val[0..l]);
                node.id_len = l;
            } else if (std.mem.eql(u8, attr_name, "title")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                const l = @min(resolved.len, node.title.len);
                @memcpy(node.title[0..l], resolved[0..l]);
                node.title_len = l;
            } else if (std.mem.eql(u8, attr_name, "text")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                const l = @min(resolved.len, node.text.len);
                @memcpy(node.text[0..l], resolved[0..l]);
                node.text_len = l;
            } else if (std.mem.eql(u8, attr_name, "action")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                const l = @min(resolved.len, node.action.len);
                @memcpy(node.action[0..l], resolved[0..l]);
                node.action_len = l;
            } else if (std.mem.eql(u8, attr_name, "label")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                const l = @min(resolved.len, node.label.len);
                @memcpy(node.label[0..l], resolved[0..l]);
                node.label_len = l;
            } else if (std.mem.eql(u8, attr_name, "src")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                const l = @min(resolved.len, node.src.len);
                @memcpy(node.src[0..l], resolved[0..l]);
                node.src_len = l;
            } else if (std.mem.eql(u8, attr_name, "x")) {
                const val_f = std.fmt.parseFloat(f32, attr_val) catch 0.0;
                node.pos_x = val_f;
                node.rect.x = val_f;
                has_pos_x = true;
            } else if (std.mem.eql(u8, attr_name, "y")) {
                const val_f = std.fmt.parseFloat(f32, attr_val) catch 0.0;
                node.pos_y = val_f;
                node.rect.y = val_f;
                has_pos_y = true;
            } else if (std.mem.eql(u8, attr_name, "w") or std.mem.eql(u8, attr_name, "width")) {
                node.width = parseDimension(attr_val);
                if (node.width == .px) node.rect.w = node.width.px;
            } else if (std.mem.eql(u8, attr_name, "h") or std.mem.eql(u8, attr_name, "height")) {
                node.height = parseDimension(attr_val);
                if (node.height == .px) node.rect.h = node.height.px;
            } else if (std.mem.eql(u8, attr_name, "radius") or std.mem.eql(u8, attr_name, "corner_radius")) {
                node.radius = std.fmt.parseFloat(f32, attr_val) catch node.radius;
            } else if (std.mem.eql(u8, attr_name, "border_w")) {
                node.border_w = std.fmt.parseFloat(f32, attr_val) catch node.border_w;
            } else if (std.mem.eql(u8, attr_name, "current")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                node.bar_current = std.fmt.parseInt(i32, resolved, 10) catch node.bar_current;
            } else if (std.mem.eql(u8, attr_name, "max")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                node.bar_max = std.fmt.parseInt(i32, resolved, 10) catch node.bar_max;
            } else if (std.mem.eql(u8, attr_name, "size")) {
                node.font_size = std.fmt.parseFloat(f32, attr_val) catch node.font_size;
            } else if (std.mem.eql(u8, attr_name, "bg")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                node.bg = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "bg2") or std.mem.eql(u8, attr_name, "gradient_bottom")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                node.bg2 = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "hover_bg")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                node.hover_bg = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "hover_bg2")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                node.hover_bg2 = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "border")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                node.border = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "color")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                node.text_color = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "fill")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                node.fill_color = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "fill2")) {
                const resolved = resolveDataBinding(attr_val, data_resolver);
                node.fill2_color = parseColor(resolved);
            } else if (std.mem.eql(u8, attr_name, "shadow")) {
                node.shadow = std.mem.eql(u8, attr_val, "true") or std.mem.eql(u8, attr_val, "1");
            } else if (std.mem.eql(u8, attr_name, "glow")) {
                node.glow = std.mem.eql(u8, attr_val, "true") or std.mem.eql(u8, attr_val, "1");
            } else if (std.mem.eql(u8, attr_name, "gap")) {
                node.gap = std.fmt.parseFloat(f32, attr_val) catch node.gap;
            } else if (std.mem.eql(u8, attr_name, "padding")) {
                node.padding = parseOffsets(attr_val);
            } else if (std.mem.eql(u8, attr_name, "margin")) {
                node.margin = parseOffsets(attr_val);
            } else if (std.mem.eql(u8, attr_name, "layout") or std.mem.eql(u8, attr_name, "direction")) {
                if (std.mem.eql(u8, attr_val, "row")) {
                    node.layout_mode = .row;
                } else if (std.mem.eql(u8, attr_val, "column") or std.mem.eql(u8, attr_val, "col")) {
                    node.layout_mode = .column;
                } else if (std.mem.eql(u8, attr_val, "grid")) {
                    node.layout_mode = .grid;
                }
            } else if (std.mem.eql(u8, attr_name, "justify")) {
                if (std.mem.eql(u8, attr_val, "start")) node.justify_content = .start;
                if (std.mem.eql(u8, attr_val, "center")) node.justify_content = .center;
                if (std.mem.eql(u8, attr_val, "end")) node.justify_content = .end;
                if (std.mem.eql(u8, attr_val, "space-between")) node.justify_content = .space_between;
                if (std.mem.eql(u8, attr_val, "space-around")) node.justify_content = .space_around;
            } else if (std.mem.eql(u8, attr_name, "align")) {
                if (std.mem.eql(u8, attr_val, "start")) node.align_items = .start;
                if (std.mem.eql(u8, attr_val, "center")) node.align_items = .center;
                if (std.mem.eql(u8, attr_val, "end")) node.align_items = .end;
                if (std.mem.eql(u8, attr_val, "stretch")) node.align_items = .stretch;
            } else if (std.mem.eql(u8, attr_name, "cols")) {
                node.grid_cols = std.fmt.parseInt(u16, attr_val, 10) catch node.grid_cols;
            } else if (std.mem.eql(u8, attr_name, "rows")) {
                node.grid_rows = std.fmt.parseInt(u16, attr_val, 10) catch node.grid_rows;
            } else if (std.mem.eql(u8, attr_name, "position")) {
                node.is_absolute = std.mem.eql(u8, attr_val, "absolute");
            } else if (std.mem.eql(u8, attr_name, "style")) {
                parseCssStyle(node, attr_val);
            }
        }

        // Tự động đánh dấu absolute nếu có tọa độ x, y cứng (tương thích ngược hoàn toàn)
        if (has_pos_x and has_pos_y) {
            node.is_absolute = true;
        }

        // Kiểm tra xem thẻ có tự đóng `/>` không
        while (i < xml_content.len and xml_content[i] != '>' and xml_content[i] != '/') i += 1;
        if (i < xml_content.len and xml_content[i] == '/') {
            is_self_closing = true;
            i += 1;
        }
        while (i < xml_content.len and xml_content[i] != '>') i += 1;
        if (i < xml_content.len) i += 1;

        // Liên kết vào Cây Node
        if (parent_stack_len > 0) {
            state.addChild(parent_stack[parent_stack_len - 1], node_id);
        } else {
            if (state.root_count < state.root_nodes.len) {
                state.root_nodes[state.root_count] = node_id;
                state.root_count += 1;
            }
        }

        // Nếu là container và không tự đóng -> đẩy vào parent stack
        if (is_container and !is_self_closing) {
            if (parent_stack_len < parent_stack.len) {
                parent_stack[parent_stack_len] = node_id;
                parent_stack_len += 1;
            }
        }
    }

    // Tính toán toàn bộ dàn trang cây (Box Model, Flexbox, Grid, Percentages)
    state.computeTreeLayout();
}

var temp_resolved_buf: [256]u8 = undefined;

/// Hỗ trợ cả {key} đơn thuần lẫn nội suy chuỗi và giải mã thực thể XML (&amp;, &lt;, &gt;, &quot;)
pub fn resolveDataBinding(val: []const u8, resolver: anytype) []const u8 {
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

// -------------------------------------------------------------
// Unit Tests Cho Hệ Thống Cây Node & Dàn Trang CSS
// -------------------------------------------------------------

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

test "css dimension and offsets parsing" {
    const d1 = parseDimension("120px");
    try std.testing.expectEqual(Dimension{ .px = 120.0 }, d1);

    const d2 = parseDimension("50%");
    try std.testing.expectEqual(Dimension{ .percent = 50.0 }, d2);

    const off1 = parseOffsets("10");
    try std.testing.expectEqual(@as(f32, 10.0), off1.top);
    try std.testing.expectEqual(@as(f32, 10.0), off1.left);

    const off2 = parseOffsets("5 15");
    try std.testing.expectEqual(@as(f32, 5.0), off2.top);
    try std.testing.expectEqual(@as(f32, 15.0), off2.left);
}

test "css style string parser" {
    var node = TreeNode{};
    parseCssStyle(&node, "display: flex; flex-direction: column; gap: 12px; padding: 10px; width: 50%;");

    try std.testing.expectEqual(LayoutMode.column, node.layout_mode);
    try std.testing.expectEqual(@as(f32, 12.0), node.gap);
    try std.testing.expectEqual(@as(f32, 10.0), node.padding.top);
    try std.testing.expectEqual(Dimension{ .percent = 50.0 }, node.width);
}

test "tree node hierarchy and flex row layout" {
    var test_ui = UIState{};

    // Tạo parent container rộng 400px, padding=10, gap=10, layout=row
    const parent_id = test_ui.allocNode(.container).?;
    var parent = &test_ui.nodes[parent_id];
    parent.width = .{ .px = 400.0 };
    parent.height = .{ .px = 100.0 };
    parent.padding = RectOffsets.uniform(10.0);
    parent.gap = 10.0;
    parent.layout_mode = .row;
    parent.justify_content = .start;
    parent.is_absolute = true;
    parent.pos_x = 0;
    parent.pos_y = 0;

    test_ui.root_nodes[0] = parent_id;
    test_ui.root_count = 1;

    // Tạo 2 nút con, mỗi nút rộng 100px
    const c1_id = test_ui.allocNode(.button).?;
    test_ui.nodes[c1_id].width = .{ .px = 100.0 };
    test_ui.nodes[c1_id].height = .{ .px = 30.0 };
    test_ui.addChild(parent_id, c1_id);

    const c2_id = test_ui.allocNode(.button).?;
    test_ui.nodes[c2_id].width = .{ .px = 100.0 };
    test_ui.nodes[c2_id].height = .{ .px = 30.0 };
    test_ui.addChild(parent_id, c2_id);

    // Tính toán bố cục
    test_ui.computeTreeLayout();

    // Kiểm tra parent inner_x = 10
    // c1 đặt tại x = 10
    try std.testing.expectEqual(@as(f32, 10.0), test_ui.nodes[c1_id].rect.x);
    // c2 đặt tại x = 10 + 100 + gap(10) = 120
    try std.testing.expectEqual(@as(f32, 120.0), test_ui.nodes[c2_id].rect.x);
    try std.testing.expectEqual(@as(f32, 100.0), test_ui.nodes[c1_id].rect.w);
}

test "xml tree parsing with nesting and auto layout" {
    var test_ui = UIState{};
    const dummy_resolver = struct {
        fn resolve(_: []const u8, _: []u8) ?[]const u8 {
            return null;
        }
    }.resolve;

    const xml_str =
        \\<Row w="300" h="60" gap="8" padding="10">
        \\    <Button text="Nut 1" w="80" h="28"/>
        \\    <Button text="Nut 2" w="80" h="28"/>
        \\</Row>
    ;

    parseXmlUI(xml_str, &test_ui, dummy_resolver);

    try std.testing.expectEqual(@as(usize, 3), test_ui.node_count);
    try std.testing.expectEqual(@as(usize, 1), test_ui.root_count);

    const root = &test_ui.nodes[test_ui.root_nodes[0]];
    try std.testing.expectEqual(LayoutMode.row, root.layout_mode);
    try std.testing.expectEqual(@as(u16, 2), root.child_count);

    const btn1 = &test_ui.nodes[root.first_child.?];
    const btn2 = &test_ui.nodes[root.last_child.?];

    // inner_x = 10 (padding)
    try std.testing.expectEqual(@as(f32, 10.0), btn1.rect.x);
    // btn2.x = 10 + 80 + gap(8) = 98
    try std.testing.expectEqual(@as(f32, 98.0), btn2.rect.x);
}
