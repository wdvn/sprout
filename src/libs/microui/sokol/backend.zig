const std = @import("std");
const mui = @import("../root.zig");
const Context = mui.Context;
const Font = mui.Font;
const Rect = mui.Rect;
const Vec2 = mui.Vec2;
const Color = mui.Color;
const Icon = mui.Icon;

const sokol = @import("sokol");
const sg = sokol.gfx;
const sapp = sokol.app;
const sgl = sokol.gl;

const atlas = @import("atlas.zig");
const ATLAS_WIDTH = atlas.ATLAS_WIDTH;
const ATLAS_HEIGHT = atlas.ATLAS_HEIGHT;

fn textWidthCB(font: Font, text: []const u8) i32 {
    _ = font;
    var res: i32 = 0;
    for (text) |c| {
        const glyph_idx = @as(usize, atlas.ATLAS_FONT) + (c & 127);
        if (glyph_idx < atlas.atlas.len) {
            res += atlas.atlas[glyph_idx].w;
        }
    }
    return res;
}

fn textHeightCB(font: Font) i32 {
    _ = font;
    return 18;
}

fn float(v: anytype) f32 {
    const f: f32 = @floatFromInt(v);
    return f;
}

pub const Renderer = struct {
    mui_ctx: *mui.Context,
    sgl_ctx: sgl.Context,
    atlas_img: sg.Image,
    atlas_view: sg.View,
    atlas_smp: sg.Sampler,
    pip: sgl.Pipeline,

    pub fn init(mui_ctx: *mui.Context, sgl_ctx: sgl.Context) Renderer {
        var rgba8_pixels: [ATLAS_WIDTH * ATLAS_HEIGHT]u32 = undefined;

        for (0..ATLAS_HEIGHT) |y| {
            for (0..ATLAS_WIDTH) |x| {
                const idx = y * ATLAS_WIDTH + x;
                const px: u32 = if (idx < atlas.atlas_texture.len) atlas.atlas_texture[idx] else 0;
                rgba8_pixels[idx] = 0x00FFFFFF | (px << 24);
            }
        }

        var img_desc: sg.ImageDesc = .{
            .width = ATLAS_WIDTH,
            .height = ATLAS_HEIGHT,
            .label = "microui-atlas-image",
        };
        img_desc.data.mip_levels[0] = sg.asRange(&rgba8_pixels);
        const atlas_img = sg.makeImage(img_desc);

        var pip_desc: sg.PipelineDesc = .{ .label = "microui-pipeline" };
        pip_desc.colors[0].blend = .{
            .enabled = true,
            .src_factor_rgb = sg.BlendFactor.SRC_ALPHA,
            .dst_factor_rgb = sg.BlendFactor.ONE_MINUS_SRC_ALPHA,
        };

        return .{
            .mui_ctx = mui_ctx,
            .sgl_ctx = sgl_ctx,
            .atlas_img = atlas_img,
            .atlas_view = sg.makeView(.{ .texture = .{ .image = atlas_img }, .label = "microui-atlas-view" }),
            .atlas_smp = sg.makeSampler(.{ .min_filter = sg.Filter.NEAREST, .mag_filter = sg.Filter.NEAREST, .label = "microui-atlas-sampler" }),
            .pip = sgl.contextMakePipeline(sgl_ctx, pip_desc),
        };
    }

    pub fn deinit(self: *Renderer) void {
        sg.destroyImage(self.atlas_img);
        sg.destroyView(self.atlas_view);
        sg.destroySampler(self.atlas_smp);
        sgl.destroyPipeline(self.pip);
    }

    fn pushQuad(dst: Rect, src: Rect, color: Color) void {
        const tu0 = float(src.x) / float(ATLAS_WIDTH);
        const tv0 = float(src.y) / float(ATLAS_HEIGHT);
        const tu1 = float(src.x + src.w) / float(ATLAS_WIDTH);
        const tv1 = float(src.y + src.h) / float(ATLAS_HEIGHT);

        const x0 = float(dst.x);
        const y0 = float(dst.y);
        const x1 = float(dst.x + dst.w);
        const y1 = float(dst.y + dst.h);

        sgl.c4b(color.r, color.g, color.b, color.a);
        sgl.v2fT2f(x0, y0, tu0, tv0);
        sgl.v2fT2f(x1, y0, tu1, tv0);
        sgl.v2fT2f(x1, y1, tu1, tv1);
        sgl.v2fT2f(x0, y1, tu0, tv1);
    }

    fn renderRect(rect: Rect, color: Color) void {
        pushQuad(rect, atlas.atlas[atlas.ATLAS_WHITE], color);
    }

    fn renderText(text: []const u8, pos: Vec2, color: Color) void {
        var dst: Rect = Rect.init(pos.x, pos.y, 0, 0);
        for (text[0..]) |c| {
            const src = atlas.atlas[atlas.ATLAS_FONT + (c & 127)];
            dst.w = src.w;
            dst.h = src.h;
            pushQuad(dst, src, color);
            dst.x += dst.w;
        }
    }

    fn renderIcon(id: Icon, rect: Rect, color: Color) void {
        const src = atlas.atlas[@intFromEnum(id)];
        const x = rect.x + @divTrunc(rect.w - src.w, 2);
        const y = rect.y + @divTrunc(rect.h - src.h, 2);
        pushQuad(Rect.init(x, y, src.w, src.h), src, color);
    }

    fn renderImage(self: *const Renderer, id: u64, dst: Rect, uv0: mui.Vec2f, uv1: mui.Vec2f, color: Color) void {
        sgl.end();

        const x0 = float(dst.x);
        const y0 = float(dst.y);
        const x1 = float(dst.x + dst.w);
        const y1 = float(dst.y + dst.h);
        sgl.texture(sg.View{ .id = @intCast(id) }, self.atlas_smp);
        sgl.beginQuads();
        sgl.c4b(color.r, color.g, color.b, color.a);
        sgl.v2fT2f(x0, y0, uv0.x, uv0.y);
        sgl.v2fT2f(x1, y0, uv1.x, uv0.y);
        sgl.v2fT2f(x1, y1, uv1.x, uv1.y);
        sgl.v2fT2f(x0, y1, uv0.x, uv1.y);
        sgl.end();

        // back to atlas texture
        sgl.texture(self.atlas_view, self.atlas_smp);
        sgl.beginQuads();
    }

    fn renderSetClipRect(rect: Rect) void {
        sgl.end();
        sgl.scissorRect(rect.x, rect.y, rect.w, rect.h, true);
        sgl.beginQuads();
    }

    fn renderBegin(self: *const Renderer, disp_width: i32, disp_height: i32) void {
        sgl.defaults();
        sgl.pushPipeline();
        sgl.loadPipeline(self.pip);
        sgl.enableTexture();
        sgl.texture(self.atlas_view, self.atlas_smp);
        sgl.matrixModeProjection();
        sgl.pushMatrix();
        sgl.ortho(0, @floatFromInt(disp_width), @floatFromInt(disp_height), 0, -1, 1);
        sgl.beginQuads();
    }

    fn renderEnd() void {
        sgl.end();
        sgl.popMatrix();
        sgl.popPipeline();
    }

    pub fn renderCommands(self: *Renderer, width: i32, height: i32) void {
        const ctx = self.mui_ctx;
        sgl.setContext(self.sgl_ctx);

        self.renderBegin(width, height);

        var cmd_it = ctx.commandIterator();
        while (cmd_it.next()) |cmd| {
            switch (cmd.*) {
                .rect => |data| renderRect(data.rect, data.color),
                .clip => |data| renderSetClipRect(data.rect),
                .text => |data| renderText(data.str(ctx), data.pos, data.color),
                .icon => |data| renderIcon(data.id, data.rect, data.color),
                .image => |data| self.renderImage(data.tex_id, data.rect, data.uv_min, data.uv_max, data.color),
                .jump => @panic("should not be seen here"),
            }
        }

        renderEnd();
        sgl.draw();
        sgl.setContext(sgl.defaultContext());
    }
};

pub fn handleEvent(ctx: *Context, ev: *const sapp.Event) void {
    const Local = struct {
        pub fn mapMouse(btn: sapp.Mousebutton) mui.MouseButton {
            const iv: u3 = @intCast(@intFromEnum(btn));
            return @bitCast(@as(u8, 1) << iv);
        }

        pub fn mapKey(key_code: sapp.Keycode) mui.Key {
            return switch (key_code) {
                .BACKSPACE => mui.Key.set(.backspace),
                .ENTER => mui.Key.set(.enter),
                .LEFT_ALT => mui.Key.set(.alt),
                .RIGHT_ALT => mui.Key.set(.alt),
                .LEFT_CONTROL => mui.Key.set(.ctrl),
                .RIGHT_CONTROL => mui.Key.set(.ctrl),
                .LEFT_SHIFT => mui.Key.set(.shift),
                .RIGHT_SHIFT => mui.Key.set(.shift),
                else => .none,
            };
        }

        pub fn charToStr(chr: u32) [2]u8 {
            var chrs: [2]u8 = .{0} ** 2;
            chrs[0] = @intCast(chr);
            return chrs;
        }
    };

    const x: i32 = @intFromFloat(ev.mouse_x);
    const y: i32 = @intFromFloat(ev.mouse_y);
    switch (ev.type) {
        .MOUSE_DOWN => {
            ctx.inputMouseDown(x, y, Local.mapMouse(ev.mouse_button));
        },
        .MOUSE_UP => {
            ctx.inputMouseUp(x, y, Local.mapMouse(ev.mouse_button));
        },
        .MOUSE_MOVE => {
            ctx.inputMouseMove(x, y);
        },
        .MOUSE_SCROLL => {
            const sx: i32 = @intFromFloat(ev.scroll_x);
            const sy: i32 = @intFromFloat(-16 * ev.scroll_y);
            ctx.inputMouseScroll(sx, sy);
        },
        .KEY_DOWN => {
            const zk = Local.mapKey(ev.key_code);
            ctx.inputKeyDown(zk);
        },
        .KEY_UP => {
            const zk = Local.mapKey(ev.key_code);
            ctx.inputKeyUp(zk);
        },
        .CHAR => {
            // don't input Backspace as character (required to make Backspace work in text input fields)
            if (ev.char_code != 127) {
                const str = Local.charToStr(ev.char_code);
                ctx.inputText(str[0..1]);
            }
        },
        else => {},
    }
}

pub fn initBackend(ctx: *Context, sgl_ctx: sgl.Context) Renderer {
    Context.init(ctx, textWidthCB, textHeightCB);
    return .init(ctx, sgl_ctx);
}
