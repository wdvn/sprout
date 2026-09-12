const std = @import("std");

pub const max_widths: usize = 16;

pub const default_slider_fmt: std.fmt.float.Options = .{ .mode = .decimal, .precision = 2 };

pub const Clip = enum(u8) {
    none = 0,
    part,
    all,
};

pub const StyleColor = enum(u8) {
    text,
    border,
    windowbg,
    titlebg,
    titletext,
    panelbg,
    button,
    buttonhover,
    buttonfocus,
    base,
    basehover,
    basefocus,
    scrollbase,
    scrollthumb,

    pub fn max() usize {
        const values = std.meta.tags(@This());
        return @intFromEnum(values[values.len - 1]) + 1;
    }
};

pub const Icon = enum(u8) {
    none = 0,
    close,
    check,
    collapsed,
    expanded,

    pub fn max() usize {
        const values = std.meta.tags(@This());
        return @intFromEnum(values[values.len - 1]) + 1;
    }
};

pub const Result = packed struct(u8) {
    active: bool = false,
    submit: bool = false,
    change: bool = false,
    _: u5 = 0,

    const zero: Result = @bitCast(@as(u8, 0));

    pub fn none(r: Result) bool {
        return r == zero;
    }

    pub fn any(r: Result) bool {
        return r != zero;
    }
};

pub const Option = packed struct(u16) {
    aligncenter: bool = false,
    alignright: bool = false,
    nointeract: bool = false,
    noframe: bool = false,
    noresize: bool = false,
    noscroll: bool = false,
    noclose: bool = false,
    notitle: bool = false,
    holdfocus: bool = false,
    autosize: bool = false,
    popup: bool = false,
    closed: bool = false,
    expanded: bool = false,
    _: u3 = 0,
};

pub const MouseButton = packed struct(u8) {
    left: bool = false,
    right: bool = false,
    middle: bool = false,
    _: u5 = 0,

    // Any left/mid/right set?
    pub fn any(self: MouseButton) bool {
        return self.int() != 0;
    }

    // None of left/mid/right are set?
    pub fn none(self: MouseButton) bool {
        return self.int() == 0;
    }

    pub fn int(self: MouseButton) u8 {
        return @bitCast(self);
    }
};

pub const Key = packed struct(u8) {
    shift: bool,
    ctrl: bool,
    alt: bool,
    backspace: bool,
    enter: bool,
    _: u3,

    pub const none: Key = @bitCast(@as(u8, 0));

    pub fn set(field: anytype) Key {
        var opts = Key.none;
        @field(opts, @tagName(field)) = true;
        return opts;
    }

    pub fn int(self: Key) u8 {
        return @bitCast(self);
    }
};

pub const Id = u32;
pub const Font = u32; // TODO

pub const Vec2 = struct {
    x: i32,
    y: i32,

    pub fn get(self: Vec2, idx: usize) i32 {
        return if (idx == 0) self.x else self.y;
    }
    pub fn set(self: *Vec2, idx: usize, v: i32) void {
        if (idx == 0) self.x = v else self.y = v;
    }
    pub const zero: @This() = .{ .x = 0, .y = 0 };
};

pub const Vec2f = struct { x: f32, y: f32 };

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn init(x: i32, y: i32, w: i32, h: i32) Rect {
        return .{ .x = x, .y = y, .w = w, .h = h };
    }

    pub fn expand(rect: Rect, n: i32) Rect {
        return Rect.init(rect.x - n, rect.y - n, rect.w + n * 2, rect.h + n * 2);
    }

    pub fn intersect(r1: Rect, r2: Rect) Rect {
        const x1 = @max(r1.x, r2.x);
        const y1 = @max(r1.y, r2.y);
        var x2 = @min(r1.x + r1.w, r2.x + r2.w);
        var y2 = @min(r1.y + r1.h, r2.y + r2.h);
        if (x2 < x1) x2 = x1;
        if (y2 < y1) y2 = y1;
        return Rect.init(x1, y1, x2 - x1, y2 - y1);
    }

    pub fn overlapsVec2(r: Rect, p: Vec2) bool {
        return p.x >= r.x and p.x < r.x + r.w and p.y >= r.y and p.y < r.y + r.h;
    }

    pub const zero: @This() = .{ .x = 0, .y = 0, .w = 0, .h = 0 };
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub const white: Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 };
};

pub const PoolItem = struct {
    id: Id,
    last_update: u32,
    pub const zero: @This() = .{ .id = 0, .last_update = 0 };
};

const CommandTag = enum(u8) { jump = 1, clip, rect, text, icon, image };

pub const Command = union(CommandTag) {
    jump: usize,
    clip: struct { rect: Rect },
    rect: struct { rect: Rect, color: Color },
    text: struct {
        font: Font,
        str_idx: u32,
        str_len: u32,
        pos: Vec2,
        color: Color,

        pub fn str(self: @This(), ctx: *Context) [:0]const u8 {
            return ctx.command_strings.slice()[self.str_idx .. self.str_idx + self.str_len :0];
        }
    },
    icon: struct { rect: Rect, id: Icon, color: Color },
    image: struct { rect: Rect, uv_min: Vec2f, uv_max: Vec2f, tex_id: u64, color: Color },
};

pub const Layout = struct {
    pub const Type = enum(u8) { none = 0, relative = 1, absolute = 2 };

    body: Rect,
    next: Rect,
    position: Vec2,
    size: Vec2,
    max: Vec2,
    _widths: [max_widths]i32,
    _items: usize,
    item_index: usize,
    next_row: i32,
    next_type: Type,
    indent: i32,

    pub const init: Layout = .{
        .body = .zero,
        .next = .zero,
        .position = .zero,
        .size = .zero,
        .max = .zero,
        ._widths = @splat(0),
        ._items = 0,
        .item_index = 0,
        .next_row = 0,
        .next_type = .none,
        .indent = 0,
    };

    pub fn widths(self: *const @This()) []i32 {
        std.debug.assert(self._items < self._items.len);
        return self._widths[0..self._items];
    }
};

pub const Container = struct {
    head: ?usize,
    tail: ?usize,
    rect: Rect,
    body: Rect,
    content_size: Vec2,
    scroll: Vec2,
    zindex: i32,
    open: bool,

    pub const empty: @This() = .{
        .head = null,
        .tail = null,
        .rect = .zero,
        .body = .zero,
        .content_size = .zero,
        .scroll = .zero,
        .zindex = 0,
        .open = false,
    };
};

pub const Style = struct {
    font: Font,
    size: Vec2,
    padding: i32,
    spacing: i32,
    indent: i32,
    title_height: i32,
    scrollbar_size: i32,
    thumb_size: i32,
    colors: [StyleColor.max()]Color,

    pub fn getColor(self: *@This(), idx: StyleColor) Color {
        return self.colors[@intFromEnum(idx)];
    }
};

pub const Context = @import("Context.zig");
pub const sokol = @import("sokol/backend.zig");
