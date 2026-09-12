const std = @import("std");
const arrays = @import("arrays.zig");
const Fnv1a_32 = @import("fnv1a.zig").Fnv1a_32;

const commandlist_size: usize = (256 * 1024) / 32;
const commandlist_text_size: usize = 65536; // max sum of string lengths per frame
const rootlist_size: usize = 32;
const containerstack_size: usize = 32;
const clipstack_size: usize = 32;
const idstack_size: usize = 32;
const layoutstack_size: usize = 16;
const containerpool_size: usize = 48;
const treenodepool_size: usize = 48;
const max_fmt: usize = 127;

const slider_fmt: []const u8 = "{d:.2}"; // TODO

const mui = @import("root.zig");
const Clip = mui.Clip;
const StyleColor = mui.StyleColor;
const Icon = mui.Icon;
const Result = mui.Result;
const Option = mui.Option;
const MouseButton = mui.MouseButton;
const Key = mui.Key;
const Id = mui.Id;
const Font = mui.Font;
const Vec2 = mui.Vec2;
const Vec2f = mui.Vec2f;
const Rect = mui.Rect;
const Color = mui.Color;
const PoolItem = mui.PoolItem;
const Command = mui.Command;
const Layout = mui.Layout;
const Container = mui.Container;
const Style = mui.Style;

const Context = @This();

// callbacks
pub const TextWidthCB = *const fn (font: Font, str: []const u8) i32;
pub const TextHeightCB = *const fn (font: Font) i32;

text_width: TextWidthCB,
text_height: TextHeightCB,
draw_frame: *const fn (context: *Context, rect: Rect, colorid: StyleColor) void,

// core state
_style: Style,
style: *Style,
hover: Id,
focus: Id,
last_id: Id,
last_rect: Rect,
last_zindex: i32,
updated_focus: bool,
frame: u32,
hover_root: ?*Container,
next_hover_root: ?*Container,
scroll_target: ?*Container,
number_edit_buf: arrays.BoundedArray(u8, max_fmt),
number_edit: Id,

// stacks
command_idx: usize,
command_list: [commandlist_size]Command,
command_strings: arrays.BoundedArray(u8, commandlist_text_size),
root_list: arrays.BoundedArray(*Container, rootlist_size),
container_stack: arrays.BoundedStack(*Container, containerstack_size),
clip_stack: arrays.BoundedStack(Rect, clipstack_size),
id_stack: arrays.BoundedStack(Id, idstack_size),
layout_stack: arrays.BoundedStack(Layout, layoutstack_size),

// retained state pools
container_pool: [containerpool_size]PoolItem,
containers: [containerpool_size]Container,
treenode_pool: [treenodepool_size]PoolItem,

// input state
mouse_pos: Vec2,
last_mouse_pos: Vec2,
mouse_delta: Vec2,
scroll_delta: Vec2,
mouse_down: MouseButton, // MouseButton mask
mouse_pressed: MouseButton, // MouseButton mask
key_down: Key,
key_pressed: Key,
input_text: arrays.BoundedArray(u8, 32),

fn vec2(x: i32, y: i32) Vec2 {
    return .{ .x = x, .y = y };
}

fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
    return .{ .r = r, .g = g, .b = b, .a = a };
}

const default_style: Style = .{
    .font = 0, // TODO
    .size = vec2(68, 10),
    .padding = 5,
    .spacing = 4,
    .indent = 24,
    .title_height = 24,
    .scrollbar_size = 12,
    .thumb_size = 8,
    .colors = .{
        rgba(230, 230, 230, 255), // MU_COLOR_TEXT */
        rgba(25, 25, 25, 255), // MU_COLOR_BORDER */
        rgba(50, 50, 50, 255), // MU_COLOR_WINDOWBG */
        rgba(25, 25, 25, 255), // MU_COLOR_TITLEBG */
        rgba(240, 240, 240, 255), // MU_COLOR_TITLETEXT */
        rgba(0, 0, 0, 0), // MU_COLOR_PANELBG */
        rgba(75, 75, 75, 255), // MU_COLOR_BUTTON */
        rgba(95, 95, 95, 255), // MU_COLOR_BUTTONHOVER */
        rgba(115, 115, 115, 255), // MU_COLOR_BUTTONFOCUS */
        rgba(30, 30, 30, 255), // MU_COLOR_BASE */
        rgba(35, 35, 35, 255), // MU_COLOR_BASEHOVER */
        rgba(40, 40, 40, 255), // MU_COLOR_BASEFOCUS */
        rgba(43, 43, 43, 255), // MU_COLOR_SCROLLBASE */
        rgba(30, 30, 30, 255), // MU_COLOR_SCROLLTHUMB */
    },
};

const unclipped_rect = Rect.init(0, 0, 0x1000000, 0x1000000);

fn drawFrameCB(self: *Context, rect: Rect, colorid: StyleColor) void {
    self.drawRect(rect, self.style.getColor(colorid));
    if (colorid == .scrollbase or colorid == .scrollthumb or colorid == .titlebg) {
        return;
    }
    if (self.style.getColor(.border).a != 0) {
        self.drawBox(rect.expand(1), self.style.getColor(.border));
    }
}

fn drawFrame(self: *Context, rect: Rect, colorid: StyleColor) void {
    self.draw_frame(self, rect, colorid);
}

pub fn init(self: *Context, text_width_cb: TextWidthCB, text_height_cb: TextHeightCB) void {
    self.* = .{
        .text_width = text_width_cb,
        .text_height = text_height_cb,
        .draw_frame = drawFrameCB,
        ._style = default_style,
        .style = undefined,
        .hover = 0,
        .focus = 0,
        .last_id = 0,
        .last_rect = .zero,
        .last_zindex = 0,
        .updated_focus = false,
        .frame = 0,
        .hover_root = null,
        .next_hover_root = null,
        .scroll_target = null,
        .number_edit_buf = .{},
        .number_edit = 0,

        .command_idx = 0,
        .command_list = undefined,
        .command_strings = .{},
        .root_list = .{},
        .container_stack = .{},
        .clip_stack = .{},
        .id_stack = .{},
        .layout_stack = .{},
        .container_pool = @splat(.zero),
        .containers = @splat(.empty),
        .treenode_pool = @splat(.zero),

        .mouse_pos = .zero,
        .last_mouse_pos = .zero,
        .mouse_delta = .zero,
        .scroll_delta = .zero,
        .mouse_down = .{},
        .mouse_pressed = .{},
        .key_down = .none,
        .key_pressed = .none,
        .input_text = .{},
    };
    self.style = &self._style;
}

pub fn begin(self: *Context) void {
    self.command_idx = 0;
    self.command_strings.reset();
    self.root_list.reset();
    self.scroll_target = null;
    self.hover_root = self.next_hover_root;
    self.next_hover_root = null;
    self.mouse_delta.x = self.mouse_pos.x - self.last_mouse_pos.x;
    self.mouse_delta.y = self.mouse_pos.y - self.last_mouse_pos.y;
    self.frame += 1;
}

fn compareZindex(_: void, a: *const Container, b: *const Container) bool {
    return a.zindex < b.zindex;
}

pub fn end(self: *Context) void {
    std.debug.assert(self.container_stack.size() == 0);
    std.debug.assert(self.clip_stack.size() == 0);
    std.debug.assert(self.id_stack.size() == 0);
    std.debug.assert(self.layout_stack.size() == 0);

    // handle scroll input
    if (self.scroll_target) |target| {
        target.scroll.x += self.scroll_delta.x;
        target.scroll.y += self.scroll_delta.y;
    }

    // unset focus if focus id was not touched this frame
    if (!self.updated_focus) self.focus = 0;
    self.updated_focus = false;

    // bring hover root to front if mouse was pressed */
    if (self.next_hover_root) |next_hover_root| {
        if (self.mouse_pressed.any() and next_hover_root.zindex < self.last_zindex and next_hover_root.zindex >= 0) {
            self.bringToFront(next_hover_root);
        }
    }

    self.key_pressed = .none;
    self.input_text.reset();
    self.mouse_pressed = .{};
    self.scroll_delta = .zero;
    self.last_mouse_pos = self.mouse_pos;

    const root_list: []*Container = self.root_list.slice();
    std.mem.sort(*Container, root_list, {}, compareZindex);

    // set root container jump commands
    for (root_list, 0..) |cnt, i| {
        // if this is the first container then make the first command jump to it.
        // otherwise set the previous container's tail to jump to this one
        const dst_idx = cnt.head.? + 1;
        if (i == 0) {
            self.command_list[0] = .{ .jump = dst_idx };
        } else {
            const prev = root_list[i - 1];
            if (prev.tail) |tail| self.command_list[tail] = .{ .jump = dst_idx };
        }
        // make the last container's tail jump to the end of command list
        if (i == root_list.len - 1) {
            if (cnt.tail) |tail| self.command_list[tail] = .{ .jump = self.command_idx };
        }
    }
}

pub fn bringToFront(self: *Context, cnt: *Container) void {
    self.last_zindex += 1;
    cnt.zindex = self.last_zindex;
}

//============================================================================
// pools
//============================================================================

pub fn initPoolItem(self: *Context, items: []PoolItem, id: Id) usize {
    var found_idx: ?usize = null;
    var f = self.frame;
    for (items, 0..) |item, i| {
        if (item.last_update < f) {
            f = item.last_update;
            found_idx = i;
        }
    }
    const n = found_idx orelse @panic("pool full");
    items[n].id = id;
    self.updatePoolItem(items, n);
    return n;
}

pub fn getPoolItem(self: *Context, items: []const PoolItem, id: Id) ?usize {
    _ = self;
    for (items, 0..) |item, i| {
        if (item.id == id) return i;
    }
    return null;
}

pub fn updatePoolItem(self: *Context, items: []PoolItem, idx: usize) void {
    items[idx].last_update = self.frame;
}

//============================================================================
// input handlers
//============================================================================

pub fn inputMouseMove(self: *Context, x: i32, y: i32) void {
    self.mouse_pos = vec2(x, y);
}

pub fn inputMouseDown(self: *Context, x: i32, y: i32, btn: MouseButton) void {
    self.inputMouseMove(x, y);
    self.mouse_down = @bitCast(self.mouse_down.int() | btn.int());
    self.mouse_pressed = @bitCast(self.mouse_pressed.int() | btn.int());
}

pub fn inputMouseUp(self: *Context, x: i32, y: i32, btn: MouseButton) void {
    self.inputMouseMove(x, y);
    self.mouse_down = @bitCast(self.mouse_down.int() & ~btn.int());
}

pub fn inputMouseScroll(self: *Context, x: i32, y: i32) void {
    self.scroll_delta.x += x;
    self.scroll_delta.y += y;
}

pub fn inputKeyDown(self: *Context, key: Key) void {
    self.key_pressed = @bitCast(self.key_pressed.int() | key.int());
    self.key_down = @bitCast(self.key_down.int() | key.int());
}

pub fn inputKeyUp(self: *Context, key: Key) void {
    self.key_down = @bitCast(self.key_pressed.int() & ~Key.int(key));
}

pub fn inputText(self: *Context, text: []const u8) void {
    self.input_text.appendSlice(text) catch unreachable;
}

pub fn setFocus(self: *Context, id: Id) void {
    self.focus = id;
    self.updated_focus = true;
}

pub fn getId(self: *Context, input: []const u8) Id {
    const hash_initial: u32 = 0x811c9dc5;
    var h = Fnv1a_32.init(if (self.id_stack.top()) |top_id| top_id else hash_initial);
    const res = h.hash(input);
    self.last_id = res;
    return res;
}

pub fn pushId(self: *Context, input: []const u8) void {
    self.id_stack.push(self.getId(input));
}

pub fn popId(self: *Context) void {
    _ = self.id_stack.pop();
}

pub fn pushClipRect(self: *Context, rect: Rect) void {
    const last = self.getClipRect();
    self.clip_stack.push(rect.intersect(last));
}

pub fn popClipRect(self: *Context) void {
    _ = self.clip_stack.pop();
}

pub fn getClipRect(self: *Context) Rect {
    return self.clip_stack.top() orelse @panic("stack shouldn't be empty");
}

pub fn checkClip(self: *Context, r: Rect) Clip {
    const cr = self.getClipRect();
    if (r.x > cr.x + cr.w or r.x + r.w < cr.x or
        r.y > cr.y + cr.h or r.y + r.h < cr.y)
    {
        return .all;
    }
    if (r.x >= cr.x and r.x + r.w <= cr.x + cr.w and
        r.y >= cr.y and r.y + r.h <= cr.y + cr.h)
    {
        return .none;
    }
    return .part;
}

fn pushLayout(self: *Context, body: Rect, scroll: Vec2) void {
    var layout: Layout = .init;
    layout.body = Rect.init(body.x - scroll.x, body.y - scroll.y, body.w, body.h);
    layout.max = vec2(-0x1000000, -0x1000000);
    self.layout_stack.push(layout);
    self.layoutRow(&[_]i32{0}, 0);
}

fn getLayout(self: *Context) *Layout {
    return self.layout_stack.topPtr() orelse @panic("empty layout stack");
}

fn popLayout(self: *Context) Layout {
    return self.layout_stack.pop();
}

fn popContainer(self: *Context) void {
    const cnt = self.getCurrentContainer();
    const layout = self.popLayout();
    cnt.content_size = vec2(layout.max.x - layout.body.x, layout.max.y - layout.body.y);
    // pop container and id
    _ = self.container_stack.pop();
    self.popId();
}

pub fn getCurrentContainer(self: *Context) *Container {
    return self.container_stack.top() orelse @panic("empty container stack");
}

fn getContainerOrInit(self: *Context, id: Id, opt: Option) ?*Container {
    // try to get existing container from pool
    if (self.getPoolItem(&self.container_pool, id)) |idx| {
        const cnt = &self.containers[idx];
        if (cnt.open or !opt.closed) {
            self.updatePoolItem(&self.container_pool, idx);
        }
        return cnt;
    }

    if (opt.closed) return null;

    // container not found in pool: init new container
    const idx = self.initPoolItem(&self.container_pool, id);
    const cnt = &self.containers[idx];
    cnt.* = .empty;
    cnt.open = true;
    self.bringToFront(cnt);
    return cnt;
}

pub fn getContainer(self: *Context, name: []const u8) *Container {
    const id = self.getId(name);
    return self.getContainerOrInit(id, .{}) orelse @panic("getContainerOrInit should not fail with 0 opts");
}

//============================================================================
// commandlist
//============================================================================

pub const CommandIter = struct {
    ctx: *Context,
    cmd_idx: isize,

    pub fn next(it: *CommandIter) ?*Command {
        it.cmd_idx += 1;

        const end_idx = it.ctx.command_idx;
        while (it.cmd_idx != end_idx) {
            const cmd_idx: usize = @intCast(it.cmd_idx);
            switch (it.ctx.command_list[cmd_idx]) {
                .jump => |data| it.cmd_idx = @intCast(data),
                else => return &it.ctx.command_list[cmd_idx],
            }
        }
        return null;
    }
};

pub fn commandIterator(self: *Context) CommandIter {
    return .{
        .cmd_idx = -1,
        .ctx = self,
    };
}

pub fn pushCommand(self: *Context, cmd: Command) void {
    const ptr = &self.command_list[self.command_idx];
    self.command_idx += 1;
    ptr.* = cmd;
}

pub fn reserveJump(self: *Context) usize {
    const idx = self.command_idx;
    self.command_idx += 1;
    self.command_list[idx] = undefined; // jump destination gets patched in later
    return idx;
}

pub fn drawRect(self: *Context, rect: Rect, color: Color) void {
    const r = rect.intersect(self.getClipRect());
    if (r.w > 0 and r.h > 0) {
        self.pushCommand(.{ .rect = .{ .rect = r, .color = color } });
    }
}

pub fn drawImage(self: *Context, tex_id: u64, rect: Rect, uv_min: mui.Vec2f, uv_max: mui.Vec2f, color: Color) void {
    const r = rect.intersect(self.getClipRect());
    if (r.w <= 0 or r.h <= 0) return;

    const L = struct {
        pub fn fdiv(a: i32, b: i32) f32 {
            const af: f32 = @floatFromInt(a);
            const bf: f32 = @floatFromInt(b);
            return af / bf;
        }
        pub fn vlerp(a: Vec2f, b: Vec2f, t: Vec2f) Vec2f {
            const x = a.x + (b.x - a.x) * t.x;
            const y = a.y + (b.y - a.y) * t.y;
            return .{ .x = x, .y = y };
        }
    };

    // Note: setClip could also be used to clip..  Doing manual UV clipping here.
    const tx0 = L.fdiv(r.x - rect.x, rect.w);
    const ty0 = L.fdiv(r.y - rect.y, rect.h);
    const tx1 = L.fdiv(r.x + r.w - rect.x, rect.w);
    const ty1 = L.fdiv(r.y + r.h - rect.y, rect.h);
    const c_uv_min = L.vlerp(uv_min, uv_max, .{ .x = tx0, .y = ty0 });
    const c_uv_max = L.vlerp(uv_min, uv_max, .{ .x = tx1, .y = ty1 });
    self.pushCommand(.{
        .image = .{
            .rect = r,
            .uv_min = c_uv_min,
            .uv_max = c_uv_max,
            .tex_id = tex_id,
            .color = color,
        },
    });
}

pub fn drawBox(self: *Context, rect: Rect, color: Color) void {
    self.drawRect(Rect.init(rect.x + 1, rect.y, rect.w - 2, 1), color);
    self.drawRect(Rect.init(rect.x + 1, rect.y + rect.h - 1, rect.w - 2, 1), color);
    self.drawRect(Rect.init(rect.x, rect.y, 1, rect.h), color);
    self.drawRect(Rect.init(rect.x + rect.w - 1, rect.y, 1, rect.h), color);
}

pub fn drawText(self: *Context, font: Font, str: []const u8, pos: Vec2, color: Color) void {
    const rect = Rect.init(pos.x, pos.y, self.text_width(font, str), self.text_height(font));

    const clipped = self.checkClip(rect);
    if (clipped == .all) return;
    if (clipped == .part) self.setClip(self.getClipRect());

    const cur_offset = self.command_strings.len;
    self.command_strings.appendSlice(str) catch unreachable;
    self.command_strings.append(0) catch unreachable; // zero terminate
    self.pushCommand(.{ .text = .{
        .str_idx = @intCast(cur_offset),
        .str_len = @intCast(str.len),
        .pos = pos,
        .color = color,
        .font = font,
    } });

    // reset clipping if it was set */
    if (clipped != .none) self.setClip(unclipped_rect);
}

pub fn setClip(self: *Context, rect: Rect) void {
    self.pushCommand(.{ .clip = .{ .rect = rect } });
}

pub fn drawIcon(self: *Context, icon: Icon, rect: Rect, color: Color) void {
    // do clip command if the rect isn't fully contained within the cliprect
    const clipped = self.checkClip(rect);
    if (clipped == .all) return;
    if (clipped == .part) self.setClip(self.getClipRect());
    self.pushCommand(.{ .icon = .{
        .id = icon,
        .rect = rect,
        .color = color,
    } });
    // reset clipping if it was set */
    if (clipped != .none) self.setClip(unclipped_rect);
}

/// Extract the "text part" from an imgui style label string where you can control IDs with a "##some_text" postfix.
pub fn stripLabelId(text: []const u8) []const u8 {
    if (std.mem.indexOf(u8, text, "##")) |offs| {
        return text[0..offs];
    }
    return text;
}

pub fn drawControlText(self: *Context, str: []const u8, rect: Rect, colorid: StyleColor, opt: Option) void {
    const font = self.style.font;
    const text = stripLabelId(str);
    const tw = self.text_width(font, text);
    self.pushClipRect(rect);

    var pos: Vec2 = .{
        .x = rect.x + self.style.padding,
        .y = rect.y + @divTrunc(rect.h - self.text_height(font), 2),
    };
    if (opt.aligncenter) {
        pos.x = rect.x + @divTrunc(rect.w - tw, 2);
    } else if (opt.alignright) {
        pos.x = rect.x + rect.w - tw - self.style.padding;
    }
    self.drawText(font, text, pos, self.style.getColor(colorid));
    self.popClipRect();
}

pub fn drawControlFrame(self: *Context, id: Id, rect: Rect, colorid: StyleColor, opt: Option) void {
    if (opt.noframe) return;
    var colr: u32 = @intFromEnum(colorid);
    colr += if (self.focus == id) 2 else (if (self.hover == id) 1 else 0);
    self.drawFrame(rect, @enumFromInt(colr));
}

//============================================================================
// layout
//============================================================================

pub fn layoutBeginColumn(self: *Context) void {
    self.pushLayout(self.layoutNext(), Vec2.zero);
}

pub fn layoutEndColumn(self: *Context) void {
    const b = self.popLayout();
    const a = self.getLayout();
    a.position.x = @max(a.position.x, b.position.x + b.body.x - a.body.x);
    a.next_row = @max(a.next_row, b.next_row + b.body.y - a.body.y);
    a.max.x = @max(a.max.x, b.max.x);
    a.max.y = @max(a.max.y, b.max.y);
}

fn layoutRowInternal(self: *Context, n_items: usize, widths: ?[]const i32, height: i32) void {
    const layout = self.getLayout();
    if (widths) |ws| {
        std.debug.assert(n_items == ws.len);
        @memcpy(layout._widths[0..n_items], ws);
    }
    layout._items = n_items;
    layout.position = vec2(layout.indent, layout.next_row);
    layout.size.y = height;
    layout.item_index = 0;
}

pub fn layoutRow(self: *Context, widths: []const i32, height: i32) void {
    self.layoutRowInternal(widths.len, widths, height);
}

pub fn layoutWidth(self: *Context, width: i32) void {
    self.getLayout().size.x = width;
}

pub fn layoutHeight(self: *Context, height: i32) void {
    self.getLayout().size.y = height;
}

pub fn layoutSetNext(self: *Context, r: Rect, relative: bool) void {
    const layout = self.getLayout();
    layout.next = r;
    layout.next_type = if (relative) .relative else .absolute;
}

pub fn layoutNext(self: *Context) Rect {
    const layout = self.getLayout();
    const style = self.style;
    var res: Rect = undefined;

    if (layout.next_type != .none) {
        const prev_type = layout.next_type;
        layout.next_type = .none;
        res = layout.next;
        if (prev_type == .absolute) {
            self.last_rect = res;
            return res;
        }
    } else {
        // handle next row
        if (layout.item_index == layout._items) {
            self.layoutRowInternal(layout._items, null, layout.size.y);
        }

        // position
        res.x = layout.position.x;
        res.y = layout.position.y;

        // size
        res.w = if (layout._items > 0) layout._widths[layout.item_index] else layout.size.x;
        res.h = layout.size.y;

        if (res.w == 0) res.w = style.size.x + style.padding * 2;
        if (res.h == 0) res.h = style.size.y + style.padding * 2;
        if (res.w < 0) res.w += layout.body.w - res.x + 1;
        if (res.h < 0) res.h += layout.body.h - res.y + 1;

        layout.item_index += 1;
    }

    layout.position.x += res.w + style.spacing;
    layout.next_row = @max(layout.next_row, res.y + res.h + style.spacing);

    res.x += layout.body.x;
    res.y += layout.body.y;

    layout.max.x = @max(layout.max.x, res.x + res.w);
    layout.max.y = @max(layout.max.y, res.y + res.h);

    self.last_rect = res;
    return res;
}

const XYSwap = enum { xy, yx };

fn swap(comptime T: type, v: T, swiz: XYSwap) T {
    return switch (T) {
        Vec2 => if (swiz == .xy) v else .{ .x = v.y, .y = v.x },
        Rect => if (swiz == .xy) v else .{ .x = v.y, .y = v.x, .w = v.h, .h = v.w },
        else => @compileError("unsupported input type"),
    };
}

// Compute the scrollbar thumb rect for the given track. Args along scroll axis (ie., after XY swap)
// - visible: size of the visible viewport (e.g. b.h)
// - content: total content size (e.g. cs.y)
// - scroll:  current scroll offset in [0, content - visible]
// - min_size: minimum thumb size in pixels
inline fn calcThumbRect(track: Rect, visible: i32, content: i32, scroll: i32, min_size: i32) Rect {
    var t = track;
    t.h = @max(min_size, @divTrunc(track.h * visible, content));
    const denom = @max(1, content - visible); // avoid div-by-zero when content==visible
    t.y = track.y + @divTrunc(scroll * (track.h - t.h), denom);
    return t;
}

// To create a horizontal or vertical scrollbar almost-identical code is
// used; only the references to `x|y` `w|h` need to be switched.  This is
// what the 'swap' argument is doing to inputs and outputs.
fn scrollbar(self: *Context, cnt: *Container, b_: Rect, cs_: Vec2, comptime xy: XYSwap) void {
    const y = switch (xy) {
        .xy => 1, // xywh
        .yx => 0, // yxhw
    };

    // Swap inputs (args and container fields) to either xywh or yxhw format.
    // This swap is reversed when writing the values back to the container.
    const cs = swap(Vec2, cs_, xy);
    const b = swap(Rect, b_, xy);
    var scroll = cnt.scroll.get(y);
    const mouse_delta = self.mouse_delta.get(y);

    const maxscroll = cs.y - b.h;

    // only add scrollbar if content size is larger than body
    if (maxscroll > 0 and b.h > 0) {
        const id = self.getId("!scrollbar_" ++ @tagName(xy));

        // get sizing / positioning
        var track = b;
        track.x = b.x + b.w;
        track.w = self.style.scrollbar_size;

        // precompute thumb from *current* scroll for hit testing
        const cur_thumb = calcThumbRect(track, b.h, cs.y, scroll, self.style.thumb_size);

        // handle hover/focus & clicks
        self.updateControl(id, swap(Rect, track, xy), .{});
        if (self.focus == id) {
            // click on the track outside the thumb
            if (self.mouse_pressed.left and !self.mouseOver(swap(Rect, cur_thumb, xy))) {
                const jump_to_click = self.key_down.alt;
                if (jump_to_click) {
                    const click_rel = self.mouse_pos.get(y) - track.y - @divTrunc(cur_thumb.h, 2);
                    const denom = @max(1, track.h - cur_thumb.h);
                    const target = @divTrunc(click_rel * maxscroll, denom);
                    scroll = std.math.clamp(target, 0, maxscroll);
                } else {
                    // page jump (roughly one visible page)
                    const page = @max(1, b.h - self.style.padding * 2);
                    if (self.mouse_pos.get(y) < cur_thumb.y) {
                        scroll = std.math.clamp(scroll - page, 0, maxscroll);
                    } else if (self.mouse_pos.get(y) > cur_thumb.y + cur_thumb.h) {
                        scroll = std.math.clamp(scroll + page, 0, maxscroll);
                    }
                }
            }

            // dragging
            if (self.mouse_down.left) {
                scroll += @divTrunc(mouse_delta * cs.y, track.h);
                scroll = std.math.clamp(scroll, 0, maxscroll);
            }
        }

        // draw base and (recompute) thumb from updated scroll
        self.drawFrame(swap(Rect, track, xy), .scrollbase);
        const thumb = calcThumbRect(track, b.h, cs.y, scroll, self.style.thumb_size);
        self.drawFrame(swap(Rect, thumb, xy), .scrollthumb);

        // set this as the scroll_target (will get scrolled on mousewheel)
        // if the mouse is over it
        if (self.mouseOver(b_)) self.scroll_target = cnt;
    } else {
        scroll = 0;
    }
    cnt.scroll.set(y, scroll);
}

fn pushContainerBody(self: *Context, cnt: *Container, body_: Rect, opt: Option) void {
    var body = body_;
    if (!opt.noscroll) {
        self.pushClipRect(body);

        // resize body to make room for scrollbars
        var cs = cnt.content_size;
        cs.x += self.style.padding * 2;
        cs.y += self.style.padding * 2;
        const sz = self.style.scrollbar_size;
        if (cs.y > cnt.body.h) body.w -= sz;
        if (cs.x > cnt.body.w) body.h -= sz;

        self.scrollbar(cnt, body, cs, .xy);
        self.scrollbar(cnt, body, cs, .yx);

        self.popClipRect();
    }
    self.pushLayout(body.expand(-self.style.padding), cnt.scroll);
    cnt.body = body;
}

fn beginRootContainer(self: *Context, cnt: *Container) void {
    self.container_stack.push(cnt);
    // push container to roots list and push head command
    self.root_list.append(cnt) catch unreachable;
    cnt.head = self.reserveJump();

    // set as hover root if the mouse is overlapping this container and it has a
    // higher zindex than the current hover root
    if (cnt.rect.overlapsVec2(self.mouse_pos)) {
        if (self.next_hover_root) |nhr| {
            if (cnt.zindex > nhr.zindex) {
                self.next_hover_root = cnt;
            }
        } else {
            self.next_hover_root = cnt;
        }
    }

    // clipping is reset here in case a root-container is made within
    // another root-containers's begin/end block; this prevents the inner
    // root-container being clipped to the outer
    self.clip_stack.push(unclipped_rect);
}

fn endRootContainer(self: *Context) void {
    // push tail 'goto' jump command and set head 'jump' command. the final steps
    // on initing these are done in Context.end()
    const cnt = self.getCurrentContainer();
    cnt.tail = self.reserveJump();
    if (cnt.head) |head| {
        self.command_list[head] = .{ .jump = self.command_idx };
    } else {
        @panic("root container must have head set");
    }
    // pop base clip rect and container
    self.popClipRect();
    self.popContainer();
}

fn inHoverRoot(self: *Context) bool {
    var it = self.container_stack.topdown();
    while (it.next()) |cnt| {
        if (cnt == self.hover_root) {
            return true;
        }
        if (cnt.head != null) break;
    }
    return false;
}

pub fn mouseOver(self: *Context, rect: Rect) bool {
    const clip = self.getClipRect();
    return rect.overlapsVec2(self.mouse_pos) and clip.overlapsVec2(self.mouse_pos) and inHoverRoot(self);
}

pub fn updateControl(self: *Context, id: Id, rect: Rect, opt: Option) void {
    const mouseover = self.mouseOver(rect);

    if (self.focus == id) {
        self.updated_focus = true;
    }
    if (opt.nointeract) {
        return;
    }
    if (mouseover and self.mouse_down.none()) {
        self.hover = id;
    }

    if (self.focus == id) {
        if (self.mouse_pressed.any() and !mouseover) {
            self.setFocus(0);
        }
        if (self.mouse_down.none() and !opt.holdfocus) {
            self.setFocus(0);
        }
    }

    if (self.hover == id) {
        if (self.mouse_pressed.any()) {
            self.setFocus(id);
        } else if (!mouseover) {
            self.hover = 0;
        }
    }
}

const TokIter = struct {
    const Kind = enum { word, space, newline };
    const Token = struct { kind: Kind, slice: []const u8 };

    s: []const u8,
    i: usize = 0,

    fn next(self: *TokIter) ?Token {
        if (self.i >= self.s.len) return null;
        const c = self.s[self.i];

        if (c == '\n') {
            const tok = Token{ .kind = .newline, .slice = self.s[self.i .. self.i + 1] };
            self.i += 1;
            return tok;
        }
        if (c == ' ') {
            var j = self.i;
            while (j < self.s.len and self.s[j] == ' ') j += 1;
            const tok = Token{ .kind = .space, .slice = self.s[self.i..j] };
            self.i = j;
            return tok;
        }
        var j = self.i;
        while (j < self.s.len and self.s[j] != ' ' and self.s[j] != '\n') j += 1;
        const tok = Token{ .kind = .word, .slice = self.s[self.i..j] };
        self.i = j;
        return tok;
    }
};

/// Draw multiline text with simple word wrapping.
pub fn textBlock(self: *Context, text: []const u8) void {
    if (text.len == 0) return;

    const font = self.style.font;
    const color = self.style.getColor(.text);

    self.layoutBeginColumn();
    self.layoutRow(&.{-1}, self.text_height(font));

    const space_w = self.text_width(font, " ");
    var r = self.layoutNext();
    var x = r.x;

    var it = TokIter{ .s = text };
    while (it.next()) |tok| {
        switch (tok.kind) {
            .newline => {
                r = self.layoutNext();
                x = r.x;
            },
            .space => {
                var w: i32 = @intCast(tok.slice.len);
                w *= space_w;
                if (x != r.x and x + w > r.x + r.w) {
                    r = self.layoutNext();
                    x = r.x;
                } else {
                    x += w;
                }
            },
            .word => {
                const w = self.text_width(font, tok.slice);
                if (x != r.x and x + w > r.x + r.w) {
                    r = self.layoutNext();
                    x = r.x;
                }
                self.drawText(font, tok.slice, .{ .x = x, .y = r.y }, color);
                x += w;
            },
        }
    }

    self.layoutEndColumn();
}

pub fn textLabel(self: *Context, text: []const u8) void {
    self.drawControlText(text, self.layoutNext(), StyleColor.text, .{});
}

pub fn buttonEx(self: *Context, label: ?[]const u8, icon: Icon, opt: Option) Result {
    var res: Result = .{};
    const icon_bytes = std.mem.toBytes(icon);
    const id = if (label) |lbl| self.getId(lbl) else self.getId(&icon_bytes);
    const r = self.layoutNext();
    self.updateControl(id, r, opt);

    // handle click
    if (self.mouse_pressed == MouseButton{ .left = true } and self.focus == id) {
        res.submit = true;
    }

    // draw
    self.drawControlFrame(id, r, .button, opt);
    if (label) |lbl| self.drawControlText(lbl, r, .text, opt);
    if (icon != .none) self.drawIcon(icon, r, self.style.getColor(.text));

    return res;
}

pub fn button(self: *Context, label: []const u8) Result {
    return self.buttonEx(label, .none, .{ .aligncenter = true });
}

pub fn checkbox(self: *Context, label: []const u8, prevValue: bool) struct { Result, bool } {
    var res: Result = .{};
    var value = prevValue;
    const id = self.getId(label);
    const r = self.layoutNext();
    const box = Rect.init(r.x, r.y, r.h, r.h);
    self.updateControl(id, r, .{});
    // handle click
    if (self.mouse_pressed == MouseButton{ .left = true } and self.focus == id) {
        res.change = true;
        value = !value;
    }
    // draw
    self.drawControlFrame(id, box, .base, .{});
    if (value) {
        self.drawIcon(.check, box, self.style.getColor(.text));
    }
    self.drawControlText(label, Rect.init(r.x + box.w, r.y, r.w - box.w, r.h), .text, .{});
    return .{ res, value };
}

pub fn textboxRaw(self: *Context, text_buf: []u8, text_capacity: usize, id: Id, r: Rect, opt: Option) struct { Result, []u8 } {
    var res: Result = .{};
    var new_len = text_buf.len;

    var opt_hold = opt;
    opt_hold.holdfocus = true;
    self.updateControl(id, r, opt_hold);

    if (self.focus == id) {
        const ibufsz: isize = @intCast(text_capacity);
        const ilen: isize = @intCast(text_buf.len);

        // handle text input
        const input_text = self.input_text.slice();
        const n = @min(ibufsz - ilen, @as(isize, @intCast(input_text.len)));
        if (n > 0) {
            std.debug.assert(new_len + input_text.len <= text_capacity);
            const dst: []u8 = text_buf.ptr[new_len .. new_len + input_text.len];
            @memcpy(dst, input_text);
            new_len += @intCast(n);
            res.change = true;
        }

        // handle backspace
        if (self.key_pressed.backspace and new_len != 0) {
            // skip utf-8 continuation bytes
            while (new_len != 0 and text_buf[new_len - 1] & 0xc0 == 0x80) : (new_len -= 1) {}
            new_len -|= 1;
            res.change = true;
        }

        // handle return key
        if (self.key_pressed.enter) {
            self.setFocus(0);
            res.submit = true;
        }
    }

    // draw
    const new_text = text_buf.ptr[0..new_len];
    self.drawControlFrame(id, r, .base, opt);
    if (self.focus == id) {
        const color = self.style.getColor(.text);
        const font = self.style.font;
        const textw = self.text_width(font, new_text);
        const texth = self.text_height(font);
        const ofx = r.w - self.style.padding - textw - 1;
        const textx = r.x + @min(ofx, self.style.padding);
        const texty = r.y + @divTrunc(r.h - texth, 2);
        self.pushClipRect(r);
        self.drawText(font, new_text, .{ .x = textx, .y = texty }, color);
        self.drawRect(Rect.init(textx + textw, texty, 1, texth), color);
        self.popClipRect();
    } else {
        self.drawControlText(new_text, r, .text, opt);
    }
    return .{ res, new_text };
}

fn numberTextbox(self: *Context, initValue: f64, r: Rect, id: Id, fmt_opts: std.fmt.float.Options) struct { Result, f64 } {
    var value = initValue;
    if (self.mouse_pressed == MouseButton{ .left = true } and self.key_down.shift and self.hover == id) {
        self.number_edit = id;
        const slice = std.fmt.float.render(self.number_edit_buf.buffer[0..], value, fmt_opts) catch unreachable;
        std.debug.assert(slice.len < self.number_edit_buf.buffer.len);
        self.number_edit_buf.len = slice.len;
    }
    if (self.number_edit == id) {
        const res, const edit_buf = self.textboxRaw(self.number_edit_buf.slice(), self.number_edit_buf.buffer.len, id, r, .{});
        self.number_edit_buf.len = edit_buf.len; // update string length
        if (res.submit or self.focus != id) {
            const trimmed = std.mem.trimRight(u8, edit_buf, "\r\n");
            value = std.fmt.parseFloat(f64, trimmed) catch value;
            self.number_edit = 0;
        } else {
            return .{ .{ .active = true }, value };
        }
    }
    return .{ .{}, value };
}

pub fn textbox(self: *Context, str_id: []const u8, text_buf: []u8, text_capacity: usize, opt: Option) struct { Result, []u8 } {
    const id = self.getId(str_id);
    const r = self.layoutNext();
    return self.textboxRaw(text_buf, text_capacity, id, r, opt);
}

pub fn sliderEx(self: *Context, str_id: []const u8, initValue: f64, lo: f64, hi: f64, step: f64, fmt_opts: std.fmt.float.Options, opt: Option) struct { Result, f64 } {
    const id = self.getId(str_id);
    const base = self.layoutNext();

    // handle text input mode
    var value = initValue;
    const r, value = self.numberTextbox(value, base, id, fmt_opts);
    if (r.any()) {
        return .{ r, value };
    }

    // handle normal mode
    self.updateControl(id, base, opt);

    // handle input
    const button_state: MouseButton = @bitCast(self.mouse_down.int() | self.mouse_pressed.int());
    if (self.focus == id and button_state == MouseButton{ .left = true }) {
        const base_w: f64 = @floatFromInt(base.w);
        value = lo + @as(f64, @floatFromInt(self.mouse_pos.x - base.x)) * (hi - lo) / base_w;
        if (step != 0) {
            value = std.math.floor((value + step / 2) / step) * step;
        }
    }
    var res = Result{};
    value = std.math.clamp(value, lo, hi);
    if (initValue != value) {
        res.change = true;
    }

    // draw base
    self.drawControlFrame(id, base, .base, opt);

    // draw thumb
    const w = self.style.thumb_size;
    const x = (value - lo) * @as(f64, @floatFromInt(base.w - w)) / (hi - lo);
    const thumb = Rect.init(base.x + @as(i32, @intFromFloat(x)), base.y, w, base.h);
    self.drawControlFrame(id, thumb, .button, opt);

    // draw text
    var buf: [max_fmt + 1]u8 = undefined;
    const str = std.fmt.float.render(&buf, value, fmt_opts) catch "";
    self.drawControlText(str, base, .text, opt);
    return .{ res, value };
}

pub fn numberInputEx(self: *Context, str_id: []const u8, initValue: f64, step: f64, fmt_opts: std.fmt.float.Options, opt: Option) struct { Result, f64 } {
    var res: Result = .{};
    const id = self.getId(str_id);
    const base = self.layoutNext();
    var value = initValue;

    // handle text input mode
    const r, value = self.numberTextbox(value, base, id, fmt_opts);
    if (r.any()) {
        return .{ r, value };
    }

    self.updateControl(id, base, opt);

    // handle input
    if (self.focus == id and self.mouse_down == MouseButton{ .left = true }) {
        const delta: f64 = @floatFromInt(self.mouse_delta.x);
        value += delta * step;
    }

    // set flag if value changed
    if (value != initValue) {
        res.change = true;
    }

    // draw base
    self.drawControlFrame(id, base, .base, opt);
    // draw text
    var buf: [max_fmt + 1]u8 = undefined;
    const str = std.fmt.float.render(&buf, value, fmt_opts) catch "";
    self.drawControlText(str, base, .text, opt);
    return .{ res, value };
}

fn header(self: *Context, label: []const u8, istreenode: bool, opt: Option) Result {
    const id = self.getId(label);
    const idx = self.getPoolItem(&self.treenode_pool, id);
    const ws: [1]i32 = .{-1};
    self.layoutRow(&ws, 0);

    var active = idx != null;
    const expanded = if (opt.expanded) !active else active;
    var r = self.layoutNext();
    self.updateControl(id, r, .{});

    // handle click
    active ^= self.mouse_pressed == MouseButton{ .left = true } and self.focus == id;

    // update pool ref
    if (idx) |i| {
        if (active) {
            self.updatePoolItem(&self.treenode_pool, i);
        } else {
            self.treenode_pool[i] = .zero;
        }
    } else if (active) {
        _ = self.initPoolItem(&self.treenode_pool, id);
    }

    //  draw
    if (istreenode) {
        if (self.hover == id) self.drawFrame(r, .buttonhover);
    } else {
        self.drawControlFrame(id, r, .button, .{});
    }
    self.drawIcon(if (expanded) .expanded else .collapsed, Rect.init(r.x, r.y, r.h, r.h), self.style.getColor(.text));
    r.x += r.h - self.style.padding;
    r.w -= r.h - self.style.padding;
    self.drawControlText(label, r, .text, .{});
    return if (expanded) return .{ .active = true } else .{};
}

pub fn headerEx(self: *Context, label: []const u8, opt: Option) Result {
    return self.header(label, false, opt);
}

pub fn beginTreenode(self: *Context, label: []const u8) Result {
    return self.beginTreenodeEx(label, .{});
}

pub fn beginTreenodeEx(self: *Context, label: []const u8, opt: Option) Result {
    const res = self.header(label, true, opt);
    if (res.active) {
        self.getLayout().indent += self.style.indent;
        self.id_stack.push(self.last_id);
    }
    return res;
}

pub fn endTreenode(self: *Context) void {
    self.getLayout().indent -= self.style.indent;
    self.popId();
}

pub fn beginWindow(self: *Context, title: []const u8, init_rect: Rect, opt: Option) Result {
    const windowId = self.getId(title);
    const cnt = if (self.getContainerOrInit(windowId, opt)) |cnt| cnt else return .{};
    if (!cnt.open) return .{};
    self.id_stack.push(windowId);

    if (cnt.rect.w == 0) cnt.rect = init_rect;

    self.beginRootContainer(cnt);

    // handle window move
    // note: this is done differently from the original microui.c
    // to get rid of one frame of UI latency.
    var tr = cnt.rect;
    var th: i32 = 0;
    if (!opt.notitle) {
        th = self.style.title_height;
        tr.h = th;

        const titleId = self.getId("!title");
        self.updateControl(titleId, tr, opt);
        if (titleId == self.focus and self.mouse_down == MouseButton{ .left = true }) {
            cnt.rect.x += self.mouse_delta.x;
            cnt.rect.y += self.mouse_delta.y;
        }
        tr.x = cnt.rect.x;
        tr.y = cnt.rect.y;
    }

    const rect = cnt.rect;

    // draw frame
    if (!opt.noframe) {
        self.drawFrame(rect, .windowbg);
    }

    // do title bar
    if (!opt.notitle) {
        self.drawFrame(tr, .titlebg);

        // do title text
        self.drawControlText(title, tr, .titletext, opt);

        // do `close` button
        if (!opt.noclose) {
            const closeId = self.getId("!close");
            const r = Rect.init(tr.x + tr.w - tr.h, tr.y, tr.h, tr.h);
            tr.w -= r.w;
            self.drawIcon(Icon.close, r, self.style.getColor(.titletext));
            self.updateControl(closeId, r, opt);
            if (self.mouse_pressed == MouseButton{ .left = true } and closeId == self.focus) {
                cnt.open = false;
            }
        }
    }

    var body = cnt.rect;
    body.y += th;
    body.h -= th;
    self.pushContainerBody(cnt, body, opt);

    // do `resize` handle
    if (!opt.noresize) {
        const sz = self.style.title_height;
        const id = self.getId("!resize");
        const r = Rect.init(rect.x + rect.w - sz, rect.y + rect.h - sz, sz, sz);
        self.updateControl(id, r, opt);
        if (id == self.focus and self.mouse_down == MouseButton{ .left = true }) {
            cnt.rect.w = @max(96, cnt.rect.w + self.mouse_delta.x);
            cnt.rect.h = @max(64, cnt.rect.h + self.mouse_delta.y);
        }
    }

    // resize to content size
    if (opt.autosize) {
        const r = self.getLayout().body;
        cnt.rect.w = cnt.content_size.x + (cnt.rect.w - r.w);
        cnt.rect.h = cnt.content_size.y + (cnt.rect.h - r.h);
    }

    // close if this is a popup window and elsewhere was clicked
    if (opt.popup and self.mouse_pressed.any() and self.hover_root != cnt) {
        cnt.open = false;
    }
    self.pushClipRect(cnt.body);
    return .{ .active = true };
}

pub fn endWindow(self: *Context) void {
    self.popClipRect();
    self.endRootContainer();
}

pub fn openPopup(self: *Context, name: []const u8) void {
    const cnt = self.getContainer(name);
    // set as hover root so popup isn't closed in begin_window_ex()
    self.hover_root = cnt;
    self.next_hover_root = cnt;
    // position at mouse cursor, open and bring-to-front
    cnt.rect = Rect.init(self.mouse_pos.x, self.mouse_pos.y, 1, 1);
    cnt.open = true;
    self.bringToFront(cnt);
}

pub fn beginPopup(self: *Context, name: []const u8) Result {
    const opt: Option = .{
        .popup = true,
        .autosize = true,
        .noresize = true,
        .noscroll = true,
        .notitle = true,
        .closed = true,
    };
    return self.beginWindow(name, Rect.init(0, 0, 0, 0), opt);
}

pub fn endPopup(self: *Context) void {
    self.endWindow();
}

pub fn beginPanel(self: *Context, name: []const u8) void {
    self.beginPanelEx(name, .{});
}

pub fn beginPanelEx(self: *Context, name: []const u8, opt: Option) void {
    self.pushId(name);
    const cnt = self.getContainerOrInit(self.last_id, opt) orelse @panic("getContainerOrInit should not fail with 0 opts");
    cnt.rect = self.layoutNext();
    if (!opt.noframe) {
        self.drawFrame(cnt.rect, .panelbg);
    }
    self.container_stack.push(cnt);
    self.pushContainerBody(cnt, cnt.rect, opt);
    self.pushClipRect(cnt.body);
}

pub fn endPanel(self: *Context) void {
    self.popClipRect();
    self.popContainer();
}

//============================================================================
// tests
//============================================================================

fn testContext(allocator: std.mem.Allocator) *Context {
    const builtin = @import("builtin");
    if (builtin.is_test) {
        const Local = struct {
            fn textWidthCB(font: Font, text: []const u8) i32 {
                _ = font;
                return 8 * @as(i32, @intCast(text.len));
            }

            fn textHeightCB(font: Font) i32 {
                _ = font;
                return 10;
            }
        };
        const ctx = allocator.create(Context) catch unreachable;
        Context.init(ctx, Local.textWidthCB, Local.textHeightCB);
        return ctx;
    } else {
        @compileError("only implemented for testing");
    }
}

const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

test {
    std.debug.print("max color {d}\n", .{StyleColor.max()});
}

test Rect {
    const rect = Rect.init;
    var a = rect(4, 4, 16, 16);
    var b = rect(0, 0, 16, 16);
    try expectEqual(rect(4, 4, 16 - 4, 16 - 4), a.intersect(b));

    a = rect(10, 10, 2, 2);
    b = rect(10, 10, 1, 1);
    try expectEqual(rect(10, 10, 1, 1), a.intersect(b));

    a = rect(10, 10, 2, 2);
    b = rect(100, 100, 1, 1);
    try expectEqual(rect(100, 100, 0, 0), a.intersect(b));

    a = rect(0, 0, 200, 200);
    b = rect(100, 100, 1, 1);
    try expectEqual(rect(100, 100, 1, 1), a.intersect(b));
}

test "stacks" {
    const BoundedStack = arrays.BoundedStack;
    var idstack: BoundedStack(Id, idstack_size) = .{};
    idstack.push(13);
    try expectEqual(13, idstack.top().?);
    idstack.push(42);
    const v = idstack.pop();
    try expectEqual(42, v);
    const v2 = idstack.pop();
    try expectEqual(13, v2);
    try expect(idstack.size() == 0);

    var stk: BoundedStack(i32, 16) = .{};
    const elts: []const i32 = &[_]i32{ 3, 4, 5 };
    for (elts) |elt| {
        stk.push(elt);
    }
    var it = stk.topdown();
    var idx: isize = @intCast(elts.len - 1);
    while (it.next()) |elt| {
        try expectEqual(elts[@intCast(idx)], elt);
        idx -= 1;
    }
}

test "get ids" {
    var ctx = testContext(std.testing.allocator);
    defer std.testing.allocator.destroy(ctx);

    const base_id = ctx.getId("foobar123");
    ctx.pushId("test");
    try expect(base_id != ctx.getId("foobar123"));
    const mid_id = ctx.getId("test12");
    ctx.popId();

    try expectEqual(base_id, ctx.getId("foobar123")); // id from empty stack

    ctx.pushId("test");
    try expectEqual(mid_id, ctx.getId("test12"));
    ctx.popId();
}

test "clips" {
    const rect = Rect.init;

    var ctx = testContext(std.testing.allocator);
    defer std.testing.allocator.destroy(ctx);

    ctx.clip_stack.push(unclipped_rect);
    ctx.pushClipRect(rect(10, 10, 40, 40));
    try expect(ctx.checkClip(rect(0, 0, 2, 2)) == .all);
    try expect(ctx.checkClip(rect(20, 20, 10, 10)) == .none);
    try expect(ctx.checkClip(rect(5, 10, 15, 10)) == .part);
}

test "layout sanity" {
    var ctx = testContext(std.testing.allocator);
    defer std.testing.allocator.destroy(ctx);

    ctx.begin();
    const cnt = ctx.getContainer("!test");
    const cnt2 = ctx.getContainer("!test");
    try expectEqual(cnt, cnt2);
    ctx.end();
}

test "begin window" {
    const rect = Rect.init;
    var ctx = testContext(std.testing.allocator);
    defer std.testing.allocator.destroy(ctx);

    ctx.begin();
    const res = ctx.beginWindow("test window", rect(0, 0, 320, 240), .{ .noscroll = true });
    _ = res;
    // const cnt = ctx.getContainer("!test");
    // const cnt2 = ctx.getContainer("!test");
    // try expectEqual(cnt, cnt2);
    ctx.endWindow();
    ctx.end();
}
