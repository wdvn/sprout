const std = @import("std");
const sokol = @import("sokol");
const sapp = sokol.app;
const sg = sokol.gfx;
const sglue = sokol.glue;
const slog = sokol.log;

const libs = @import("libs");
const gl = libs.gl;
const ecs = libs.ecs;
const game = @import("game");
const types = game.types;
const components = game.components;
const beasts = game.beasts;
const battle = game.battle;
const dungeon = game.dungeon;
const renderer = game.renderer;
const audio = game.audio;
const db = game.db;
const xml_ui = game.xml_ui;
const arena = game.arena;
const TextureId = renderer.TextureId;

const party_xml_bytes = @embedFile("assets/ui/party.xml");
const dungeon_xml_bytes = @embedFile("assets/ui/dungeon.xml");
const battle_xml_bytes = @embedFile("assets/ui/battle.xml");



pub const Element = types.Element;
pub const Rarity = types.Rarity;
pub const Realm = types.Realm;
pub const MasterSkill = types.MasterSkill;
pub const TamingOrderType = types.TamingOrderType;


// Helper to map Beast to its icon TextureId
fn beastIconId(b: Beast) renderer.TextureId {
    const name = b.getName();
    if (std.mem.eql(u8, name, "BICH THUY QUY")) return renderer.TextureId.fox;
    if (std.mem.eql(u8, name, "HOA DIEM HO")) return renderer.TextureId.turtle;
    if (std.mem.eql(u8, name, "LINH MOC DIEU")) return renderer.TextureId.bird;
    if (std.mem.eql(u8, name, "KIM GIAP HO")) return renderer.TextureId.dragon;
    if (std.mem.eql(u8, name, "U MINH XA")) return renderer.TextureId.player;
    if (std.mem.eql(u8, name, "XICH HOA LANG")) return renderer.TextureId.fox;
    if (std.mem.eql(u8, name, "HOANG THO HUNG")) return renderer.TextureId.turtle;
    if (std.mem.eql(u8, name, "LOI DIEN DIEU")) return renderer.TextureId.bird;
    if (std.mem.eql(u8, name, "THANH LONG")) return renderer.TextureId.dragon;
    // fallback
    return renderer.TextureId.player;
}

pub const CultivatorMaster = components.CultivatorMaster;
pub const Beast = components.Beast;
pub const FormationSlot = components.FormationSlot;
pub const DungeonTile = components.DungeonTile;
pub const Dungeon = dungeon.Dungeon;

pub const GRID_COLS = dungeon.GRID_COLS;
pub const GRID_ROWS = dungeon.GRID_ROWS;

// Tọa độ hiển thị bản đồ Bí Cảnh 8x10
const MAP_LEFT: f32 = -0.84;
const MAP_RIGHT: f32 = 0.84;
const MAP_BOTTOM: f32 = -0.66;
const MAP_TOP: f32 = 0.66;

const CELL_W: f32 = (MAP_RIGHT - MAP_LEFT) / @as(f32, @floatFromInt(GRID_COLS));
const CELL_H: f32 = (MAP_TOP - MAP_BOTTOM) / @as(f32, @floatFromInt(GRID_ROWS));

pub const GameMode = enum {
    dungeon_map,       // Khám phá Bí Cảnh 8x10 (Fog of War)
    battle,            // Chiến đấu & Thu phục Linh Thú
    party_collection,  // Linh Thú Uyển (Quản lý & Bồi dưỡng)
};

pub const FloatingText = struct {
    text: [32:0]u8 = [_:0]u8{0} ** 32,
    x: f32 = 0.0,
    y: f32 = 0.0,
    r: u8 = 255,
    g: u8 = 255,
    b: u8 = 255,
    life: f32 = 0.0,
    max_life: f32 = 1.0,
    active: bool = false,
};

pub const GameState = struct {
    registry: ecs.Registry = undefined,
    master_entity: ecs.Entity = .{ .id = 0, .generation = 0 },
    party_entities: [5]?ecs.Entity = [_]?ecs.Entity{null} ** 5,
    wild_beast_entity: ?ecs.Entity = null,

    dungeon_world: Dungeon = undefined,
    arena_state: arena.ArenaState = arena.ArenaState.init(),
    arena_target_idx: ?u8 = null,
    mode: GameMode = .dungeon_map,

    prng: std.Random.DefaultPrng = undefined,
    pulse_timer: f32 = 0.0,
    screen_shake: f32 = 0.0,
    tame_anim_timer: f32 = 0.0,

    message: [96]u8 = [_]u8{0} ** 96,
    message_len: usize = 0,

    combat_log: [96]u8 = [_]u8{0} ** 96,
    combat_log_len: usize = 0,

    floating_texts: [12]FloatingText = [_]FloatingText{.{}} ** 12,

    pub fn setMessage(self: *GameState, text: []const u8) void {
        const len = @min(text.len, self.message.len);
        @memcpy(self.message[0..len], text[0..len]);
        self.message_len = len;
        std.debug.print(">> [Bí Cảnh]: {s}\n", .{self.message[0..len]});
    }

    pub fn setCombatLog(self: *GameState, text: []const u8) void {
        const len = @min(text.len, self.combat_log.len);
        @memcpy(self.combat_log[0..len], text[0..len]);
        self.combat_log_len = len;
        std.debug.print(">> [Chiến Đấu]: {s}\n", .{self.combat_log[0..len]});
    }

    pub fn spawnPopup(self: *GameState, text: []const u8, x: f32, y: f32, r: u8, g: u8, b: u8) void {
        for (&self.floating_texts) |*ft| {
            if (!ft.active) {
                const len = @min(text.len, ft.text.len - 1);
                @memcpy(ft.text[0..len], text[0..len]);
                ft.text[len] = 0;
                ft.x = x;
                ft.y = y;
                ft.r = r;
                ft.g = g;
                ft.b = b;
                ft.life = 0.0;
                ft.max_life = 1.0;
                ft.active = true;
                break;
            }
        }
    }
};

var state = GameState{};

// WebGL Quad Resources
var quad_prog: gl.Program = .{};
var quad_vbo: gl.Buffer = .{};
var quad_pos_loc: gl.AttribLocation = -1;
var u_rect_loc: gl.UniformLocation = .{};
var u_color_loc: gl.UniformLocation = .{};
var u_color2_loc: gl.UniformLocation = .{};
var u_border_color_loc: gl.UniformLocation = .{};
var u_params_loc: gl.UniformLocation = .{};
var u_extra_loc: gl.UniformLocation = .{};

const quad_vs_source =
    \\#version 330
    \\in vec2 position;
    \\uniform vec4 u_rect;
    \\uniform vec4 u_color;
    \\uniform vec4 u_color2;
    \\uniform vec4 u_border_color;
    \\uniform vec4 u_params;
    \\uniform vec4 u_extra;
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
    \\uniform vec4 u_rect;
    \\uniform vec4 u_color;
    \\uniform vec4 u_color2;
    \\uniform vec4 u_border_color;
    \\uniform vec4 u_params;
    \\uniform vec4 u_extra;
    \\out vec4 frag_color;
    \\
    \\float sdRoundBox(vec2 p, vec2 b, float r) {
    \\    vec2 q = abs(p) - b + vec2(r);
    \\    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
    \\}
    \\
    \\void main() {
    \\    vec2 half_size = u_params.xy;
    \\    float radius = u_params.z;
    \\    float border_w = u_params.w;
    \\    float is_shadow = u_extra.x;
    \\    float glow = u_extra.y;
    \\    float time = u_extra.z;
    \\
    \\    vec2 p = v_uv * half_size;
    \\
    \\    // 1. Chế độ đổ bóng mờ đa tầng (Tailwind Soft Drop Shadow)
    \\    if (is_shadow > 0.5) {
    \\        // Key shadow (lệch trục Y tạo chiều sâu nổi khối)
    \\        vec2 p1 = p - vec2(0.0, 8.0);
    \\        float dist1 = sdRoundBox(p1, half_size - vec2(2.0), radius + 2.0);
    \\        float a1 = smoothstep(18.0, -2.0, dist1) * 0.45;
    \\
    \\        // Ambient shadow (đổ bóng sát chân viền tạo độ tương phản cao)
    \\        vec2 p2 = p - vec2(0.0, 2.0);
    \\        float dist2 = sdRoundBox(p2, half_size, radius);
    \\        float a2 = smoothstep(6.0, -1.0, dist2) * 0.35;
    \\
    \\        float total_alpha = clamp(a1 + a2, 0.0, 1.0) * u_color.a;
    \\        if (total_alpha <= 0.002) discard;
    \\        frag_color = vec4(0.0, 0.0, 0.0, total_alpha);
    \\        return;
    \\    }
    \\
    \\    // 2. Chế độ vẽ Box bo góc (SDF Round Box)
    \\    float r = min(radius, min(half_size.x, half_size.y) - 1.0);
    \\    if (r < 0.0) r = 0.0;
    \\    float dist = sdRoundBox(p, half_size, r);
    \\
    \\    // Khử răng cưa viền ngoài (Anti-aliasing)
    \\    float edge_alpha = 1.0 - smoothstep(0.0, 1.2, dist);
    \\    if (edge_alpha <= 0.001) discard;
    \\
    \\    // Dải màu gradient từ đỉnh xuống đáy
    \\    float t = clamp((v_uv.y + 1.0) * 0.5, 0.0, 1.0);
    \\    vec4 fill = mix(u_color2, u_color, t);
    \\
    \\    // Hiệu ứng kính mờ (Specular Sheen) ở mép trên
    \\    if (t > 0.82 && dist < -border_w) {
    \\        float sheen = smoothstep(0.82, 1.0, t) * 0.12;
    \\        fill.rgb += vec3(sheen);
    \\    }
    \\
    \\    // Viền khung sắc nét sub-pixel
    \\    float border_dist = abs(dist + border_w * 0.5) - border_w * 0.5;
    \\    float border_factor = 1.0 - smoothstep(0.0, 1.2, border_dist);
    \\
    \\    vec4 border_col = u_border_color;
    \\    if (glow > 0.0) {
    \\        float pulse = 0.5 + 0.5 * sin(time * 5.0);
    \\        border_col.rgb += vec3(0.25 * pulse, 0.22 * pulse, 0.08 * pulse);
    \\        border_col.a = min(1.0, border_col.a + 0.25 * pulse);
    \\    }
    \\
    \\    vec4 final_col = mix(fill, border_col, border_factor);
    \\    frag_color = vec4(final_col.rgb, final_col.a * edge_alpha);
    \\}
;

const unit_quad_vertices = [_]f32{
    -1.0, -1.0,
     1.0, -1.0,
     1.0,  1.0,
    -1.0, -1.0,
     1.0,  1.0,
    -1.0,  1.0,
};

fn drawModernRect(
    x: f32, y: f32, w: f32, h: f32,
    color_top: [4]f32, color_bottom: [4]f32,
    border: [4]f32,
    radius: f32, border_w: f32,
    is_shadow: bool, is_glow: bool,
) void {
    gl.useProgram(quad_prog);
    gl.bindBuffer(gl.ARRAY_BUFFER, quad_vbo);
    gl.enableVertexAttribArray(@intCast(quad_pos_loc));
    gl.vertexAttribPointer(@intCast(quad_pos_loc), 2, gl.FLOAT, false, 0, 0);

    const shake_x = if (state.screen_shake > 0.001) @sin(state.pulse_timer * 35.0) * state.screen_shake else 0.0;
    const shake_y = if (state.screen_shake > 0.001) @cos(state.pulse_timer * 30.0) * state.screen_shake else 0.0;

    gl.uniform4f(u_rect_loc, x + shake_x, y + shake_y, w, h);
    gl.uniform4f(u_color_loc, color_top[0], color_top[1], color_top[2], color_top[3]);
    gl.uniform4f(u_color2_loc, color_bottom[0], color_bottom[1], color_bottom[2], color_bottom[3]);
    gl.uniform4f(u_border_color_loc, border[0], border[1], border[2], border[3]);

    const half_w_px = w * 480.0;
    const half_h_px = h * 380.0;
    gl.uniform4f(u_params_loc, half_w_px, half_h_px, radius, border_w);

    const shadow_val: f32 = if (is_shadow) 1.0 else 0.0;
    const glow_val: f32 = if (is_glow) 1.0 else 0.0;
    gl.uniform4f(u_extra_loc, shadow_val, glow_val, state.pulse_timer, 0.0);

    gl.drawArrays(gl.TRIANGLES, 0, 6);
}

fn drawRect(x: f32, y: f32, w: f32, h: f32, color: [4]f32, border: [4]f32) void {
    drawModernRect(x, y, w, h, color, color, border, 6.0, 1.2, false, false);
}

fn drawUiTexture(src_name: []const u8, x: f32, y: f32, hw: f32, hh: f32) void {
    const tex_id: ?renderer.TextureId = if (std.mem.eql(u8, src_name, "player"))
        .player
    else if (std.mem.eql(u8, src_name, "turtle"))
        .turtle
    else if (std.mem.eql(u8, src_name, "fox"))
        .fox
    else if (std.mem.eql(u8, src_name, "bird"))
        .bird
    else if (std.mem.eql(u8, src_name, "dragon"))
        .dragon
    else
        null;

    if (tex_id) |id| {
        renderer.drawTexturedQuad(id, x, y, hw, hh, .{ 1.0, 1.0, 1.0, 1.0 });
    }
}

fn getBeastIcon(beast: *const Beast) []const u8 {
    const name = beast.getName();
    if (std.mem.indexOf(u8, name, "QUY") != null or std.mem.indexOf(u8, name, "XA") != null) {
        return "turtle";
    } else if (std.mem.indexOf(u8, name, "HO") != null or std.mem.indexOf(u8, name, "LANG") != null or std.mem.indexOf(u8, name, "HUNG") != null) {
        return "fox";
    } else if (std.mem.indexOf(u8, name, "DIEU") != null) {
        return "bird";
    } else if (std.mem.indexOf(u8, name, "LONG") != null) {
        return "dragon";
    }
    return switch (beast.element) {
        .shui => "turtle",
        .huo, .jin => "fox",
        .mu => "bird",
        .tu => "fox",
        .yin, .yang => "dragon",
    };
}

fn getBeastTextureId(b: *const Beast) TextureId {
    const icon_str = getBeastIcon(b);
    if (std.mem.eql(u8, icon_str, "turtle")) return .turtle;
    if (std.mem.eql(u8, icon_str, "fox")) return .fox;
    if (std.mem.eql(u8, icon_str, "bird")) return .bird;
    if (std.mem.eql(u8, icon_str, "dragon")) return .dragon;
    return .fox;
}


/// Vẽ một panel UI chữ nhật theo tọa độ cột và dòng của sdtx
fn drawPanel(c_start: f32, c_end: f32, r_start: f32, r_end: f32, bg: [4]f32, border: [4]f32) void {
    const mid_c = (c_start + c_end) * 0.5;
    const mid_r = (r_start + r_end) * 0.5;
    const span_c = c_end - c_start;
    const span_r = r_end - r_start;
    const x = renderer.charToNdcX(mid_c);
    const y = renderer.charToNdcY(mid_r);
    const hw = renderer.charSpanToNdcHalfW(span_c * 0.5);
    const hh = renderer.charSpanToNdcHalfH(span_r * 0.5);
    drawRect(x, y, hw, hh, bg, border);
}

fn drawHpBar(x: f32, y: f32, w: f32, h: f32, current_hp: i32, max_hp: i32, is_red: bool) void {
    drawRect(x, y, w, h, .{ 0.04, 0.06, 0.06, 0.95 }, .{ 0.35, 0.45, 0.40, 1.0 });

    if (current_hp <= 0 or max_hp <= 0) return;
    const ratio = std.math.clamp(@as(f32, @floatFromInt(current_hp)) / @as(f32, @floatFromInt(max_hp)), 0.0, 1.0);
    const fill_w = w * ratio;
    const fill_x = x - (w - fill_w);

    const fill_color: [4]f32 = if (is_red)
        .{ 0.95, 0.15, 0.15, 1.0 }
    else if (ratio < 0.35)
        .{ 0.95, 0.70, 0.15, 1.0 }
    else
        .{ 0.20, 0.85, 0.40, 1.0 };

    drawRect(fill_x, y, fill_w * 0.98, h * 0.72, fill_color, fill_color);
}

fn initGameWorld() void {
    state.prng = std.Random.DefaultPrng.init(0x9E3779B97F4A7C15);

    // Khoi tao SQLite Database
    db.initDb("sprout.db") catch |err| {
        std.debug.print(">> [SQLite Error]: Khong the mo sprout.db ({}), thu dung :memory:\n", .{err});
        db.initDb(":memory:") catch {};
    };

    const loaded = db.loadAll(&state.registry, &state.party_entities, &state.master_entity, &state.dungeon_world) catch false;
    if (!loaded) {
        // 1. Tạo Tu Sĩ Chủ Nhân (Ngự Thú Sư)
        state.master_entity = state.registry.create() catch unreachable;
        var master = CultivatorMaster{
            .realm = .qi_refining,
            .exp = 30,
            .exp_to_breakthrough = 100,
            .herbs = 4,
            .pills = 2,
            .taming_orders = 5,
            .master_skill = .taming_art,
        };
        const master_name = "TIEU PHAM";
        @memcpy(master.name[0..master_name.len], master_name);
        master.name_len = master_name.len;
        state.registry.add(state.master_entity, master) catch {};

        // 2. Khởi tạo 3 Linh Thú Xuất Chiến Mẫu (Ra trận)
        // Slot 0: Tiền phong - Bích Thủy Quy (Hệ Thủy)
        const e0 = state.registry.create() catch unreachable;
        var b0 = beasts.createBeast(.bich_thuy_quy, false);
        b0.slot_idx = 0;
        b0.is_caught = true;
        b0.is_wild = false;
        state.registry.add(e0, b0) catch {};
        state.party_entities[0] = e0;

        // Slot 1: Trung quân - Hỏa Diễm Hồ (Hệ Hỏa)
        const e1 = state.registry.create() catch unreachable;
        var b1 = beasts.createBeast(.hoa_diem_ho, false);
        b1.slot_idx = 1;
        b1.is_caught = true;
        b1.is_wild = false;
        state.registry.add(e1, b1) catch {};
        state.party_entities[1] = e1;

        // Slot 2: Hậu vệ - Linh Mộc Điểu (Hệ Mộc)
        const e2 = state.registry.create() catch unreachable;
        var b2 = beasts.createBeast(.linh_moc_dieu, false);
        b2.slot_idx = 2;
        b2.is_caught = true;
        b2.is_wild = false;
        state.registry.add(e2, b2) catch {};
        state.party_entities[2] = e2;

        // 3. Khởi tạo thêm 2 Linh Thú trong Linh Thú Uyển (Trong kho, chưa ra trận)
        const e3 = state.registry.create() catch unreachable;
        var b3 = beasts.createBeast(.kim_giap_ho, false);
        b3.slot_idx = null;
        b3.is_caught = true;
        b3.is_wild = false;
        state.registry.add(e3, b3) catch {};

        const e4 = state.registry.create() catch unreachable;
        var b4 = beasts.createBeast(.u_minh_xa, false);
        b4.slot_idx = null;
        b4.is_caught = true;
        b4.is_wild = false;
        state.registry.add(e4, b4) catch {};

        // 4. Khởi tạo Bản đồ Bí Cảnh tầng 1 (8x10 ô) với Fog of War
        state.dungeon_world = Dungeon.init(1);

        // Lưu dữ liệu khởi tạo vào SQLite
        db.saveAll(&state.registry, &state.party_entities, state.master_entity, &state.dungeon_world) catch {};
    }

    state.mode = .dungeon_map;
    state.setMessage("Tien vao Dai Hoang Co Tran (8x10). Di chuyen [W,A,S,D] de pha suong mu!");

    const c_getenv = struct {
        extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;
    }.getenv;

    if (c_getenv("SPROUT_START_MODE")) |val| {
        const env_mode = std.mem.span(val);
        if (std.mem.eql(u8, env_mode, "party")) {
            state.mode = .party_collection;
        } else if (std.mem.eql(u8, env_mode, "battle")) {
            enterBattle(false);
        }
    }
}

fn enterBattle(is_boss: bool) void {
    state.mode = .battle;
    state.screen_shake = 0.05;
    audio.play(.hit);

    if (state.wild_beast_entity) |ent| {
        state.registry.destroy(ent);
        state.wild_beast_entity = null;
    }

    const wild_ent = state.registry.create() catch return;
    const random = state.prng.random();

    const wild_beast = if (is_boss)
        beasts.createBeast(.thanh_long, true)
    else blk: {
        const roll = random.intRangeAtMost(u8, 0, 2);
        break :blk switch (roll) {
            0 => beasts.createBeast(.xich_hoa_lang, true),
            1 => beasts.createBeast(.hoang_tho_hung, true),
            else => beasts.createBeast(.loi_dien_dieu, true),
        };
    };

    state.registry.add(wild_ent, wild_beast) catch {};
    state.wild_beast_entity = wild_ent;

    // Khởi tạo sàn đấu Wandering Sword 8x5
    state.arena_state = arena.ArenaState.init();

    // 1. Thêm Tu Sĩ (Tiểu Phàm) vào vị trí (1, 2)
    const master = state.registry.get(state.master_entity, CultivatorMaster);
    var master_unit = arena.ArenaUnit{
        .entity = state.master_entity,
        .is_player_side = true,
        .icon_id = .player,
        .col = 1,
        .row = 2,
        .facing = .right,
        .move_range = 3,
        .speed = 50,
        .hp = 120,
        .max_hp = 120,
        .atk = 28,
        .def = 14,
        .element = .tu,
    };
    if (master) |m| {
        master_unit.setName(m.name[0..m.name_len]);
    } else {
        master_unit.setName("Tiểu Phàm");
    }
    master_unit.addSkill(arena.TacticalSkill.init("Thương Long Kiếm", .melee_single, 1, 35, 0, 0, .tu));
    master_unit.addSkill(arena.TacticalSkill.init("Ngự Kiếm Xuyên", .line_pierce, 3, 45, 0, 0, .jin));
    master_unit.addSkill(arena.TacticalSkill.init("Vạn Kiếm Quy", .ranged_aoe, 2, 40, 0, 0, .jin));
    master_unit.addSkill(arena.TacticalSkill.init("Ngự Thú Quyết", .tame_beast, 2, 0, 0, 0, .tu));
    _ = state.arena_state.addUnit(master_unit);

    // 2. Thêm các Linh thú xuất trận (Tiền Phong, Trung Quân, Hậu Vệ)
    // Slot 0 (Tiền Phong / Tank) -> (2, 2)
    if (state.party_entities[0]) |p_ent| {
        if (state.registry.get(p_ent, Beast)) |b| {
            var beast_unit = arena.ArenaUnit{
                .entity = p_ent,
                .is_player_side = true,
                .icon_id = getBeastTextureId(b),
                .col = 2,
                .row = 2,
                .facing = .right,
                .move_range = 2,
                .speed = b.speed,
                .hp = b.hp,
                .max_hp = b.max_hp,
                .atk = b.atk,
                .def = b.def,
                .element = b.element,
            };
            beast_unit.setName(b.getName());
            beast_unit.addSkill(arena.TacticalSkill.init("Quy Giáp Chấn", .melee_single, 1, 25, 0, 0, b.element));
            beast_unit.addSkill(arena.TacticalSkill.init("Hộ Thể Thuẫn", .self_shield, 1, 0, 0, 40, b.element));
            _ = state.arena_state.addUnit(beast_unit);
        }
    }

    // Slot 1 (Trung Quân / DPS) -> (1, 1)
    if (state.party_entities[1]) |p_ent| {
        if (state.registry.get(p_ent, Beast)) |b| {
            var beast_unit = arena.ArenaUnit{
                .entity = p_ent,
                .is_player_side = true,
                .icon_id = getBeastTextureId(b),
                .col = 1,
                .row = 1,
                .facing = .right,
                .move_range = 3,
                .speed = b.speed,
                .hp = b.hp,
                .max_hp = b.max_hp,
                .atk = b.atk,
                .def = b.def,
                .element = b.element,
            };
            beast_unit.setName(b.getName());
            beast_unit.addSkill(arena.TacticalSkill.init("Trảo Kích", .melee_single, 1, 35, 0, 0, b.element));
            beast_unit.addSkill(arena.TacticalSkill.init("Liệt Hỏa Diễm", .ranged_aoe, 3, 60, 0, 0, b.element));
            _ = state.arena_state.addUnit(beast_unit);
        }
    }

    // Slot 2 (Hậu Vệ / Support) -> (1, 3)
    if (state.party_entities[2]) |p_ent| {
        if (state.registry.get(p_ent, Beast)) |b| {
            var beast_unit = arena.ArenaUnit{
                .entity = p_ent,
                .is_player_side = true,
                .icon_id = getBeastTextureId(b),
                .col = 1,
                .row = 3,
                .facing = .right,
                .move_range = 4,
                .speed = b.speed,
                .hp = b.hp,
                .max_hp = b.max_hp,
                .atk = b.atk,
                .def = b.def,
                .element = b.element,
            };
            beast_unit.setName(b.getName());
            beast_unit.addSkill(arena.TacticalSkill.init("Phong Nhận", .ranged_single, 2, 22, 0, 0, b.element));
            beast_unit.addSkill(arena.TacticalSkill.init("Hồi Xuân Pháp", .heal_target, 3, 0, 45, 0, b.element));
            _ = state.arena_state.addUnit(beast_unit);
        }
    }

    // 3. Thêm Yêu thú hoang dã / Boss -> (6, 2)
    var wild_unit = arena.ArenaUnit{
        .entity = wild_ent,
        .is_player_side = false,
        .icon_id = getBeastTextureId(&wild_beast),
        .col = 6,
        .row = 2,
        .facing = .left,
        .move_range = 3,
        .speed = 45,
        .hp = wild_beast.hp,
        .max_hp = wild_beast.max_hp,
        .atk = wild_beast.atk,
        .def = wild_beast.def,
        .element = wild_beast.element,
    };
    wild_unit.setName(wild_beast.getName());
    wild_unit.addSkill(arena.TacticalSkill.init("Cuồng Bạo Trảo", .melee_single, 1, 35, 0, 0, wild_beast.element));
    wild_unit.addSkill(arena.TacticalSkill.init("Liệt Ba Chấn", .ranged_single, 2, 40, 0, 0, wild_beast.element));
    const wild_id = state.arena_state.addUnit(wild_unit);
    state.arena_target_idx = wild_id;

    state.arena_state.rebuildTimeline();
    state.arena_state.mode = .targeting_move;

    var buf: [96]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Vào Lôi Đài! {s} [{s}] xuất hiện. Thứ tự: {s} đi đầu.", .{
        wild_unit.getName(),
        wild_unit.element.asciiName(),
        state.arena_state.getUnit(state.arena_state.timeline[0]).?.getName(),
    }) catch "Vào lôi đài chiến đấu!";
    state.setCombatLog(msg);
}

fn handleArenaTileClick(col: i32, row: i32) void {
    if (state.mode != .battle) return;

    const act_idx = state.arena_state.active_unit_idx orelse return;
    const active_unit = state.arena_state.getUnit(act_idx) orelse return;

    if (!active_unit.is_player_side) return;

    // Case 1: Player is targeting Move
    if (state.arena_state.mode == .targeting_move) {
        if (state.arena_state.moveUnit(act_idx, col, row)) {
            audio.play(.step);
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "{s} tiến bước tới ô ({}, {}).", .{ active_unit.getName(), col, row }) catch "Di chuyển!";
            state.setCombatLog(msg);
            state.arena_state.mode = .select_action;
        }
        return;
    }

    // Case 2: Player is targeting a Skill
    if (state.arena_state.mode == .targeting_skill) {
        if (state.arena_state.selected_skill_idx) |sk_idx| {
            if (state.arena_state.executeSkill(act_idx, sk_idx, col, row)) {
                audio.play(.attack);
                state.screen_shake = 0.04;

                const tile_px_x = 26.0 + @as(f32, @floatFromInt(col)) * 74.0 + 35.0;
                const tile_px_y = 146.0 + @as(f32, @floatFromInt(row)) * 76.0 + 20.0;
                const ndc_x = (tile_px_x / 960.0) * 2.0 - 1.0;
                const ndc_y = 1.0 - (tile_px_y / 760.0) * 2.0;

                const last_hit = state.arena_state.last_hit;
                if (last_hit.damage > 0) {
                    var dmg_buf: [24]u8 = undefined;
                    const dmg_str = std.fmt.bufPrint(&dmg_buf, "-{}", .{last_hit.damage}) catch "-30";
                    state.spawnPopup(dmg_str, ndc_x, ndc_y, 255, 220, 80);

                    if (last_hit.positional == .back) {
                        state.spawnPopup("HAU KICH! +50%", ndc_x, ndc_y + 0.08, 255, 80, 80);
                    } else if (last_hit.positional == .flank) {
                        state.spawnPopup("TRAC KICH! +25%", ndc_x, ndc_y + 0.08, 255, 180, 60);
                    }
                } else if (last_hit.heal > 0) {
                    var heal_buf: [24]u8 = undefined;
                    const heal_str = std.fmt.bufPrint(&heal_buf, "+{}", .{last_hit.heal}) catch "+40";
                    state.spawnPopup(heal_str, ndc_x, ndc_y, 80, 255, 120);
                }

                state.arena_state.checkBattleOutcome();
                checkArenaOutcome();
                state.arena_state.mode = .select_action;
            }
        }
        return;
    }

    // Case 3: Select Action mode -> Click on a unit inspects it
    if (state.arena_state.getUnitAt(col, row)) |u_id| {
        state.arena_target_idx = u_id;
    } else {
        if (!active_unit.has_moved and state.arena_state.isTileReachable(active_unit, col, row)) {
            if (state.arena_state.moveUnit(act_idx, col, row)) {
                audio.play(.step);
                var buf: [64]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "{s} tiến bước tới ô ({}, {}).", .{ active_unit.getName(), col, row }) catch "Di chuyển!";
                state.setCombatLog(msg);
            }
        }
    }
}

fn handleArenaEndTurn() void {
    if (state.mode != .battle) return;
    state.arena_state.nextTurn();

    while (state.arena_state.phase == .enemy_turn) {
        const enemy_idx = state.arena_state.active_unit_idx orelse break;
        state.arena_state.stepEnemyAI(enemy_idx);
        audio.play(.attack);

        const last_hit = state.arena_state.last_hit;
        if (last_hit.damage > 0) {
            const tile_px_x = 26.0 + @as(f32, @floatFromInt(last_hit.target_col)) * 74.0 + 35.0;
            const tile_px_y = 146.0 + @as(f32, @floatFromInt(last_hit.target_row)) * 76.0 + 20.0;
            const ndc_x = (tile_px_x / 960.0) * 2.0 - 1.0;
            const ndc_y = 1.0 - (tile_px_y / 760.0) * 2.0;

            var dmg_buf: [24]u8 = undefined;
            const dmg_str = std.fmt.bufPrint(&dmg_buf, "-{}", .{last_hit.damage}) catch "-25";
            state.spawnPopup(dmg_str, ndc_x, ndc_y, 255, 80, 80);
        }

        checkArenaOutcome();
        if (state.mode != .battle) break;

        state.arena_state.nextTurn();
    }
}

fn checkArenaOutcome() void {
    if (state.arena_state.phase == .victory) {
        audio.play(.breakthrough);
        state.setMessage("Thắng trận lôi đài! Thu hoạch 80 Exp & 2 Linh Thảo. Trở về Bí Cảnh.");
        if (state.registry.get(state.master_entity, CultivatorMaster)) |master| {
            master.exp += 80;
            master.herbs += 2;
        }
        for (state.arena_state.units) |slot| {
            if (slot) |u| {
                if (u.is_player_side and u.entity != null) {
                    if (state.registry.get(u.entity.?, Beast)) |b| {
                        b.hp = u.hp;
                    }
                }
            }
        }
        db.saveAll(&state.registry, &state.party_entities, state.master_entity, &state.dungeon_world) catch {};
        state.mode = .dungeon_map;
    } else if (state.arena_state.phase == .tamed) {
        audio.play(.breakthrough);
        state.setMessage("Ngự Thú thành công! Yêu thú đã ký kết Khế Ước. Trở về Bí Cảnh.");
        if (state.wild_beast_entity) |w_ent| {
            if (state.registry.get(w_ent, Beast)) |w| {
                w.is_caught = true;
                w.is_wild = false;
                for (0..3) |slot_idx| {
                    if (state.party_entities[slot_idx] == null) {
                        state.party_entities[slot_idx] = w_ent;
                        w.slot_idx = @as(u8, @intCast(slot_idx));
                        break;
                    }
                }
            }
        }
        db.saveAll(&state.registry, &state.party_entities, state.master_entity, &state.dungeon_world) catch {};
        state.mode = .dungeon_map;
    } else if (state.arena_state.phase == .defeat) {
        state.setMessage("Thất bại tại lôi đài! Tạm thời rút lui dưỡng thương.");
        state.mode = .dungeon_map;
    }
}

fn renderArenaBoard() void {
    const start_x: f32 = 26.0;
    const start_y: f32 = 146.0;
    const tile_w: f32 = 70.0;
    const tile_h: f32 = 72.0;
    const spacing_x: f32 = 4.0;
    const spacing_y: f32 = 4.0;

    const act_idx = state.arena_state.active_unit_idx;
    const active_unit = if (act_idx) |idx| state.arena_state.getUnit(idx) else null;

    var r: i32 = 0;
    while (r < @as(i32, @intCast(arena.ARENA_ROWS))) : (r += 1) {
        var c: i32 = 0;
        while (c < @as(i32, @intCast(arena.ARENA_COLS))) : (c += 1) {
            const tx = start_x + @as(f32, @floatFromInt(c)) * (tile_w + spacing_x);
            const ty = start_y + @as(f32, @floatFromInt(r)) * (tile_h + spacing_y);

            const is_occupied = state.arena_state.getUnitAt(c, r);

            var is_reachable = false;
            var is_in_skill_range = false;

            if (active_unit) |au| {
                if (state.arena_state.mode == .targeting_move and !au.has_moved) {
                    is_reachable = state.arena_state.isTileReachable(au, c, r);
                } else if (state.arena_state.mode == .targeting_skill and !au.has_acted) {
                    if (state.arena_state.selected_skill_idx) |sk_idx| {
                        if (sk_idx < au.skill_count) {
                            is_in_skill_range = arena.ArenaState.isTileInSkillRange(au, &au.skills[sk_idx], c, r);
                        }
                    }
                }
            }

            const is_active_tile = if (active_unit) |au| (au.col == c and au.row == r) else false;

            const tile_bg = if (is_active_tile)
                xml_ui.parseColor("#1c4234")
            else if (is_reachable)
                xml_ui.parseColor("#164e63")
            else if (is_in_skill_range)
                xml_ui.parseColor("#7f1d1d")
            else
                xml_ui.parseColor("#091815");

            const tile_border = if (is_active_tile)
                xml_ui.parseColor("#ffd740")
            else if (is_reachable)
                xml_ui.parseColor("#38bdf8")
            else if (is_in_skill_range)
                xml_ui.parseColor("#ef4444")
            else
                xml_ui.parseColor("#1b3f34");

            var act_buf: [24]u8 = undefined;
            const act_str = std.fmt.bufPrint(&act_buf, "arena_tile_{}_{}", .{ c, r }) catch "arena_tile";

            const tile_label = if (is_reachable)
                "[BƯỚC]"
            else if (is_in_skill_range)
                (if (is_occupied != null) "[KÍCH!]" else "[TẦM]")
            else
                "";

            xml_ui.ui_state.addButtonEx(
                "",
                tile_label,
                act_str,
                .{ .x = tx, .y = ty, .w = tile_w, .h = tile_h },
                tile_bg,
                null,
                tile_bg,
                null,
                tile_border,
                if (is_reachable) xml_ui.parseColor("#38bdf8") else xml_ui.parseColor("#ffd740"),
                8.0,
                is_active_tile or is_reachable or is_in_skill_range,
            );

            if (is_occupied) |u_id| {
                if (state.arena_state.getUnit(u_id)) |unit| {
                    const icon_str = switch (unit.icon_id) {
                        .player => "player",
                        .turtle => "turtle",
                        .fox => "fox",
                        .bird => "bird",
                        .dragon => "dragon",
                        else => "player",
                    };

                    const p_border = if (unit.is_player_side) xml_ui.parseColor("#ffd740") else xml_ui.parseColor("#f87171");
                    xml_ui.ui_state.addImage(
                        "",
                        icon_str,
                        .{ .x = tx + 14.0, .y = ty + 6.0, .w = 42.0, .h = 42.0 },
                        6.0,
                        p_border,
                        1.5,
                        xml_ui.parseColor("#061210"),
                    );

                    const fill_color = if (unit.is_player_side) xml_ui.parseColor("#32d264") else xml_ui.parseColor("#f87171");
                    xml_ui.ui_state.addProgressBarEx(
                        "",
                        unit.hp,
                        unit.max_hp,
                        .{ .x = tx + 5.0, .y = ty + 52.0, .w = tile_w - 10.0, .h = 6.0 },
                        fill_color,
                        null,
                        xml_ui.parseColor("#060e0c"),
                        xml_ui.parseColor("#1a3830"),
                        "",
                        3.0,
                        false,
                    );

                    const facing_symbol = switch (unit.facing) {
                        .right => ">",
                        .left => "<",
                        .up => "^",
                        .down => "v",
                    };
                    xml_ui.ui_state.addText("", facing_symbol, tx + 6.0, ty + 12.0, if (unit.is_player_side) xml_ui.parseColor("#ffd740") else xml_ui.parseColor("#f87171"), 12.0);
                }
            }
        }
    }
}

fn handleMovePlayer(d_col: i32, d_row: i32) void {
    if (state.mode != .dungeon_map) return;

    const new_col = state.dungeon_world.player_col + d_col;
    const new_row = state.dungeon_world.player_row + d_row;

    if (state.dungeon_world.movePlayer(new_col, new_row)) |tile_kind| {
        audio.play(.step);
        const master = state.registry.get(state.master_entity, CultivatorMaster) orelse return;

        const tile_c = 15.5 + (@as(f32, @floatFromInt(new_col)) + 0.5) * 3.75;
        const tile_r = 6.0 + (9.5 - @as(f32, @floatFromInt(new_row))) * 3.10;
        const p_x = renderer.charToNdcX(tile_c);
        const p_y = renderer.charToNdcY(tile_r);

        switch (tile_kind) {
            .empty => {
                state.setMessage("Tien buoc an toan qua thung lung tien canh.");
            },
            .herb => {
                master.herbs += 1;
                master.exp += 30;
                audio.play(.heal);
                state.spawnPopup("+1 LINH THAO", p_x, p_y + 0.05, 80, 255, 120);
                var buf: [96]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "Thu hai duoc 1 Cuu Diep Linh Thao! (Co: {} thao, {} exp).", .{
                    master.herbs,
                    master.exp,
                }) catch "Thu hai Linh Thao!";
                state.setMessage(msg);
            },
            .event => {
                const roll = state.prng.random().boolean();
                audio.play(.breakthrough);
                if (roll) {
                    master.taming_orders += 1;
                    state.spawnPopup("+1 NGU THU LENH", p_x, p_y + 0.05, 255, 215, 0);
                    state.setMessage("Mo Ruong Co Tran: Nhan duoc 1 Tu Kim Ngu Thu Lenh!");
                } else {
                    master.pills += 1;
                    state.spawnPopup("+1 TRUC CO DAN", p_x, p_y + 0.05, 255, 180, 80);
                    state.setMessage("Ky ngo Dan Lo: Thu hoach duoc 1 vien Truc Co Dan!");
                }
            },
            .wild_beast => {
                enterBattle(false);
            },
            .boss => {
                enterBattle(true);
            },
        }
    }
}

fn triggerBreakthrough() void {
    const master = state.registry.get(state.master_entity, CultivatorMaster) orelse return;
    if (master.breakthrough()) {
        audio.play(.breakthrough);
        state.screen_shake = 0.08;
        state.spawnPopup("DOT PHA THANH CONG!", 0.0, 0.1, 255, 215, 0);
        var buf: [96]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "DO KIEP THANH CONG! Dot pha dai canh gioi: {s}!", .{master.realm.asciiName()}) catch "Dot pha!";
        state.setMessage(msg);
        db.saveMaster(&state.registry, state.master_entity) catch {};
    } else {
        audio.play(.tame_fail);
        var buf: [96]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Linh khi chua du hoac thieu Dan Duoc! Can {}/{} exp, {} vien dan.", .{
            master.exp,
            master.exp_to_breakthrough,
            master.pills,
        }) catch "Chua du dieu kien!";
        state.setMessage(msg);
    }
}

fn triggerPillCraft() void {
    const master = state.registry.get(state.master_entity, CultivatorMaster) orelse return;
    if (master.herbs >= 3) {
        master.herbs -= 3;
        master.pills += 1;
        audio.play(.heal);
        state.spawnPopup("+1 TRUC CO DAN", 0.0, 0.0, 255, 180, 80);
        state.setMessage("Luyen dan vien man! Tieu hao 3 Linh Thao luyen thanh 1 Truc Co Dan.");
        db.saveMaster(&state.registry, state.master_entity) catch {};
    } else {
        audio.play(.tame_fail);
        state.setMessage("Thieu duoc lieu! Can it nhat 3 Linh Thao de mo lo luyen dan.");
    }
}

fn triggerNextFloor() void {
    state.dungeon_world = Dungeon.init(state.dungeon_world.floor + 1);
    state.mode = .dungeon_map;
    audio.play(.breakthrough);
    state.setMessage("Buoc qua Cong Dich Chuyen sang Tang Bi Canh Moi!");
    db.saveDungeon(&state.dungeon_world) catch {};
    db.saveMaster(&state.registry, state.master_entity) catch {};
}

fn deployBeast(ent: ecs.Entity) void {
    const beast = state.registry.get(ent, Beast) orelse return;
    if (beast.isDeployed()) {
        state.spawnPopup("Linh thu da xuat chien!", 0.0, 0.05, 255, 200, 50);
        return;
    }
    // Tìm slot trống trong 0..3 (Tiền Phong, Trung Quân, Hậu Vệ)
    var target_slot: ?usize = null;
    for (0..3) |s| {
        if (state.party_entities[s] == null) {
            target_slot = s;
            break;
        }
    }
    if (target_slot == null) {
        audio.play(.tame_fail);
        state.spawnPopup("Doi hinh da du 3 vi tri!", 0.0, 0.05, 255, 80, 80);
        state.setMessage("Doi hinh ra tran da day (3/3). Hay Thu Hoi bot linh thu truoc khi dua thu khac vao!");
        return;
    }
    const slot = target_slot.?;
    beast.slot_idx = @intCast(slot);
    state.party_entities[slot] = ent;
    audio.play(.breakthrough);

    db.saveBeast(&state.registry, ent) catch {};

    const slot_names = [_][]const u8{ "Tien Phong", "Trung Quan", "Hau Ve" };
    var buf: [96]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "{s} da RA TRAN tai vi tri [{s}]!", .{ beast.getName(), slot_names[slot] }) catch "Ra tran!";
    state.setMessage(msg);
    state.spawnPopup("RA TRAN THANH CONG!", 0.0, 0.08, 80, 255, 120);
}

fn recallBeast(slot_idx: usize) void {
    if (slot_idx >= 3) return;
    const ent = state.party_entities[slot_idx] orelse return;
    const beast = state.registry.get(ent, Beast) orelse return;

    var active_count: usize = 0;
    for (0..3) |s| {
        if (state.party_entities[s] != null) active_count += 1;
    }
    if (active_count <= 1) {
        audio.play(.tame_fail);
        state.spawnPopup("Can it nhat 1 Linh Thu!", 0.0, 0.05, 255, 80, 80);
        state.setMessage("Doi hinh can it nhat 1 Linh Thu xuat chien de ho than!");
        return;
    }

    beast.slot_idx = null;
    state.party_entities[slot_idx] = null;
    audio.play(.step);

    db.saveBeast(&state.registry, ent) catch {};

    var buf: [96]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Da THU HOI {s} ve Linh Thu Uyen!", .{ beast.getName() }) catch "Thu hoi!";
    state.setMessage(msg);
    state.spawnPopup("DA THU HOI VE UYEN!", 0.0, 0.08, 255, 215, 80);
}

fn releaseBeast(ent: ecs.Entity) void {
    const beast = state.registry.get(ent, Beast) orelse return;

    // 1. Kiểm tra số lượng linh thú hiện có
    const b_view = state.registry.view(Beast) orelse return;
    var total_caught: usize = 0;
    for (b_view.dense.items) |e| {
        if (state.registry.get(e, Beast)) |b| {
            if (b.is_caught and !b.is_wild) total_caught += 1;
        }
    }
    if (total_caught <= 1) {
        audio.play(.tame_fail);
        state.spawnPopup("Can it nhat 1 Linh Thu!", 0.0, 0.05, 255, 80, 80);
        state.setMessage("Khong the phong sinh toan bo! Tu si can it nhat 1 Linh Thu dong hanh.");
        return;
    }

    // 2. Nếu thú đang xuất chiến trong đội hình
    if (beast.slot_idx) |s| {
        var active_count: usize = 0;
        for (0..3) |slot| {
            if (state.party_entities[slot] != null) active_count += 1;
        }
        if (active_count <= 1) {
            audio.play(.tame_fail);
            state.spawnPopup("Linh Thu xuat chien duy nhat!", 0.0, 0.05, 255, 80, 80);
            state.setMessage("Khong the tha Linh Thu xuat chien duy nhat! Hay cho Linh Thu khac ra tran truoc.");
            return;
        }
        state.party_entities[s] = null;
    }

    // 3. Tích lũy công đức / phần thưởng phóng sinh (+1 Ngự Thú Lệnh, +2 Linh Thảo)
    var name_buf: [64]u8 = undefined;
    const b_name = std.fmt.bufPrint(&name_buf, "{s}", .{beast.getName()}) catch "Linh Thu";

    if (state.registry.get(state.master_entity, CultivatorMaster)) |master| {
        master.taming_orders += 1;
        master.herbs += 2;
    }

    // 4. Xóa khỏi SQLite Database
    db.deleteBeast(ent) catch {};
    db.saveMaster(&state.registry, state.master_entity) catch {};

    // 5. Xóa khỏi ECS Registry
    state.registry.destroy(ent);

    // 6. Hiệu ứng âm thanh & thông báo
    audio.play(.heal);
    state.spawnPopup("DA THA LINH THU!", 0.0, 0.08, 255, 200, 80);

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Da phong sinh {s} ve tu nhien! Tich cong duc: +1 Ngu Thu Lenh, +2 Linh Thao.", .{b_name}) catch "Da tha linh thu!";
    state.setMessage(msg);
}

fn feedBeastEntity(ent: ecs.Entity) void {
    const master = state.registry.get(state.master_entity, CultivatorMaster) orelse return;
    if (master.herbs >= 1) {
        master.herbs -= 1;
        if (state.registry.get(ent, Beast)) |b| {
            b.hp = @min(b.max_hp, b.hp + 50);
            b.atk += 2;
            audio.play(.heal);
            state.spawnPopup("+50 HP / +2 CONG", 0.0, 0.05, 80, 255, 120);
            var buf: [96]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Dung 1 Linh Thao boi bo cho {s}: Hoi 50 HP, tang 2 Cong!", .{b.getName()}) catch "Boi duong!";
            state.setMessage(msg);

            db.saveBeast(&state.registry, ent) catch {};
            db.saveMaster(&state.registry, state.master_entity) catch {};
            return;
        }
    } else {
        audio.play(.tame_fail);
        state.setMessage("Can co Linh Thao de boi bo cho linh thu!");
    }
}

fn triggerFeedBeast(slot_idx: usize) void {
    if (slot_idx < state.party_entities.len) {
        if (state.party_entities[slot_idx]) |p_ent| {
            feedBeastEntity(p_ent);
        }
    }
}

fn triggerTamingBuff() void {
    audio.play(.heal);
    state.spawnPopup("+25% TY LE BAT", 0.0, 0.0, 255, 220, 80);
    state.setCombatLog("Tu Si niem chu [Thu Phuc Thuat]! Gia tri +25% ty le bat!");
}

// ============================================================================
// Sokol Callbacks & Input
// ============================================================================

export fn input(event: ?*const sapp.Event) void {
    const ev = event orelse return;

    const screen_w = sapp.widthf();
    const screen_h = sapp.heightf();
    const scale_x = if (screen_w > 0.0) 960.0 / screen_w else 1.0;
    const scale_y = if (screen_h > 0.0) 760.0 / screen_h else 1.0;
    const mx = ev.mouse_x * scale_x;
    const my = ev.mouse_y * scale_y;

    if (ev.type == .MOUSE_MOVE) {
        xml_ui.ui_state.handleMouseMove(mx, my);
        return;
    } else if (ev.type == .MOUSE_DOWN and ev.mouse_button == .LEFT) {
        if (xml_ui.ui_state.handleMouseDown(mx, my)) |action| {
            handleUiAction(action);
        }
        return;
    } else if (ev.type == .MOUSE_UP) {
        xml_ui.ui_state.handleMouseUp(mx, my);
        return;
    }

    if (ev.type != .KEY_DOWN) return;

    switch (ev.key_code) {
        .F11 => {
            sapp.toggleFullscreen();
        },
        .ESCAPE => {
            if (state.mode == .battle) {
                state.mode = .dungeon_map;
                state.setMessage("Thi trien Don Thuat, rut lui an toan ve Bi Canh.");
            } else if (state.mode == .party_collection) {
                state.mode = .dungeon_map;
            } else {
                sapp.requestQuit();
            }
        },

        .C => {
            if (state.mode == .dungeon_map) {
                state.mode = .party_collection;
            } else if (state.mode == .party_collection) {
                state.mode = .dungeon_map;
            }
        },

        .UP, .W => handleMovePlayer(0, 1),
        .DOWN, .S => {
            if (state.mode == .dungeon_map) {
                handleMovePlayer(0, -1);
            } else if (state.mode == .battle) {
                triggerTamingBuff();
            }
        },
        .LEFT, .A => {
            if (state.mode == .dungeon_map) {
                handleMovePlayer(-1, 0);
            } else if (state.mode == .battle) {
                executeBattleRound(0);
            }
        },
        .RIGHT, .D => handleMovePlayer(1, 0),

        ._1 => {
            if (state.mode == .battle) {
                state.arena_state.selected_skill_idx = 0;
                state.arena_state.mode = .targeting_skill;
                state.setCombatLog("Đã chọn Chiêu 1! Nhấp vào mục tiêu trong tầm đỏ để xuất chiêu.");
            }
        },
        ._2 => {
            if (state.mode == .battle) {
                state.arena_state.selected_skill_idx = 1;
                state.arena_state.mode = .targeting_skill;
                state.setCombatLog("Đã chọn Chiêu 2! Nhấp vào mục tiêu trong tầm đỏ để xuất chiêu.");
            }
        },
        ._3 => {
            if (state.mode == .battle) {
                state.arena_state.selected_skill_idx = 2;
                state.arena_state.mode = .targeting_skill;
                state.setCombatLog("Đã chọn Chiêu 3! Nhấp vào mục tiêu trong tầm đỏ để xuất chiêu.");
            }
        },

        .SPACE => {
            if (state.mode == .battle) {
                handleArenaEndTurn();
            }
        },

        .T => {
            if (state.mode == .battle) {
                state.arena_state.selected_skill_idx = 3;
                state.arena_state.mode = .targeting_skill;
                state.setCombatLog("Đã chọn Bắt Thú! Nhấp vào Yêu thú máu đỏ để tung Ngự Thú Lệnh.");
            }
        },

        .M => {
            if (state.mode == .battle) {
                if (state.arena_state.mode == .targeting_move) {
                    state.arena_state.mode = .select_action;
                } else {
                    state.arena_state.mode = .targeting_move;
                    state.setCombatLog("Chế độ Di Chuyển! Nhấp vào ô xanh lam để bước tới.");
                }
            }
        },

        .B => triggerBreakthrough(),
        .P => triggerPillCraft(),
        .F => {
            if (state.mode == .party_collection) {
                triggerFeedBeast(0);
            }
        },
        .R => triggerNextFloor(),

        else => {},
    }
}

fn executeBattleRound(skill_id: u8) void {
    const wild_ent = state.wild_beast_entity orelse return;
    const wild_beast = state.registry.get(wild_ent, Beast) orelse return;

    var total_damage: i32 = 0;
    var heal_amount: i32 = 0;
    var shield_active = false;

    audio.play(.attack);
    state.screen_shake = 0.03;

    const enemy_x = renderer.charToNdcX(46.0);
    const enemy_y = renderer.charToNdcY(18.0) + 0.12;

    if (skill_id == 1) {
        // Skill 1: Hộ Thể Thuẫn của Bích Thủy Quy
        shield_active = true;
        total_damage += 15;
        state.spawnPopup("HO THE THUAN", renderer.charToNdcX(18.0), renderer.charToNdcY(10.0) + 0.08, 100, 200, 255);
    } else if (skill_id == 2) {
        // Skill 2: Liệt Hỏa Diễm của Hỏa Diễm Hồ
        total_damage += 60;
        state.screen_shake = 0.06;
        state.spawnPopup("LIET HOA DIEM! -60", enemy_x, enemy_y, 255, 80, 40);
    } else if (skill_id == 3) {
        // Skill 3: Hồi Xuân Thuật của Linh Mộc Điểu
        heal_amount = 40;
        total_damage += 12;
        audio.play(.heal);
        state.spawnPopup("+40 HOI XUAN", renderer.charToNdcX(18.0), renderer.charToNdcY(30.0) + 0.08, 80, 255, 120);
        for (0..3) |i| {
            if (state.party_entities[i]) |p_ent| {
                if (state.registry.get(p_ent, Beast)) |ally| {
                    ally.hp = @min(ally.max_hp, ally.hp + heal_amount);
                }
            }
        }
    } else {
        // Đòn đánh phối hợp 3 thú
        for (0..3) |i| {
            if (state.party_entities[i]) |p_ent| {
                if (state.registry.get(p_ent, Beast)) |ally| {
                    if (ally.hp > 0) {
                        const dmg = ally.calcDamageAgainst(wild_beast);
                        total_damage += dmg;
                    }
                }
            }
        }
        var dmg_buf: [16]u8 = undefined;
        const dmg_str = std.fmt.bufPrint(&dmg_buf, "-{}", .{total_damage}) catch "-30";
        state.spawnPopup(dmg_str, enemy_x, enemy_y, 255, 220, 80);
    }

    wild_beast.hp -= total_damage;
    if (wild_beast.hp <= 0) {
        wild_beast.hp = 0;
        audio.play(.breakthrough);
        state.setMessage("Yeu thu van lac! Thu hoach 75 Linh Khi. Tro ve Bi Canh.");
        if (state.registry.get(state.master_entity, CultivatorMaster)) |master| {
            master.exp += 75;
        }
        db.saveAll(&state.registry, &state.party_entities, state.master_entity, &state.dungeon_world) catch {};
        state.mode = .dungeon_map;
        return;
    }

    if (wild_beast.isRedHp()) {
        audio.play(.heal);
        var buf: [96]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Yeu thu MAU DO ({}/{} HP)! Mau nhan [T] de tung Ngu Thu Lenh!", .{
            wild_beast.hp,
            wild_beast.max_hp,
        }) catch "Mau do!";
        state.setCombatLog(msg);
    } else {
        var buf: [96]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Sat thuong: {}! Yeu thu con {}/{} HP.", .{
            total_damage,
            wild_beast.hp,
            wild_beast.max_hp,
        }) catch "Tan cong!";
        state.setCombatLog(msg);
    }

    // Quái phản kích chiến thú hàng đầu đang xuất chiến (Tiền Phong -> Trung Quân -> Hậu Vệ)
    var attacked_ent: ?ecs.Entity = null;
    for (0..3) |i| {
        if (state.party_entities[i]) |ent| {
            attacked_ent = ent;
            break;
        }
    }
    if (attacked_ent) |tank_ent| {
        if (state.registry.get(tank_ent, Beast)) |tank| {
            var counter_dmg = wild_beast.calcDamageAgainst(tank);
            if (shield_active) counter_dmg = @divTrunc(counter_dmg, 2);
            tank.hp -= counter_dmg;
            if (tank.hp < 0) tank.hp = 0;

            var hit_buf: [16]u8 = undefined;
            const hit_str = std.fmt.bufPrint(&hit_buf, "-{}", .{counter_dmg}) catch "-15";
            state.spawnPopup(hit_str, renderer.charToNdcX(18.0), renderer.charToNdcY(10.0) + 0.08, 255, 60, 60);
        }
    }
}

fn executeTamingAttempt() void {
    const wild_ent = state.wild_beast_entity orelse return;
    const wild_beast = state.registry.get(wild_ent, Beast) orelse return;
    const master = state.registry.get(state.master_entity, CultivatorMaster) orelse return;

    if (master.taming_orders == 0) {
        audio.play(.tame_fail);
        state.setCombatLog("Da het Ngu Thu Lenh! Khong the phong an linh thu.");
        return;
    }

    state.tame_anim_timer = 1.0;
    const rand_val = state.prng.random().float(f32);
    const success = battle.tryTame(master, wild_beast, .mortal, rand_val);

    if (success) {
        audio.play(.tame_success);
        state.spawnPopup("THU PHUC THANH CONG!", 0.0, 0.1, 255, 215, 0);

        wild_beast.is_caught = true;
        wild_beast.is_wild = false;

        var placed_slot: ?usize = null;
        for (0..3) |i| {
            if (state.party_entities[i] == null) {
                state.party_entities[i] = wild_ent;
                wild_beast.slot_idx = @intCast(i);
                placed_slot = i;
                break;
            }
        }
        if (placed_slot == null) {
            wild_beast.slot_idx = null;
        }

        db.saveBeast(&state.registry, wild_ent) catch {};
        db.saveMaster(&state.registry, state.master_entity) catch {};

        var buf: [96]u8 = undefined;
        if (placed_slot) |s| {
            const msg = std.fmt.bufPrint(&buf, "THU PHUC DAI THANH! {s} da xuat chien tai Slot {}!", .{
                wild_beast.getName(),
                s + 1,
            }) catch "Thu phuc thanh cong!";
            state.setMessage(msg);
        } else {
            const msg = std.fmt.bufPrint(&buf, "Thu phuc thanh cong {s}! (Luu vao Linh Thu Uyen).", .{
                wild_beast.getName(),
            }) catch "Thu phuc thanh cong!";
            state.setMessage(msg);
        }

        state.wild_beast_entity = null;
        state.mode = .dungeon_map;
    } else {
        audio.play(.tame_fail);
        state.spawnPopup("BAT THAT BAI!", renderer.charToNdcX(46.0), renderer.charToNdcY(18.0) + 0.12, 255, 60, 60);
        var buf: [96]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Thu phuc bat thanh! Yeu thu giay giua thoat tran (Con {} Lenh).", .{
            master.taming_orders,
        }) catch "That bai!";
        state.setCombatLog(msg);
    }
}

export fn init() void {
    state.registry = ecs.Registry.init(std.heap.page_allocator);

    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

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
    u_color2_loc = gl.getUniformLocation(quad_prog, "u_color2");
    u_border_color_loc = gl.getUniformLocation(quad_prog, "u_border_color");
    u_params_loc = gl.getUniformLocation(quad_prog, "u_params");
    u_extra_loc = gl.getUniformLocation(quad_prog, "u_extra");

    // Khởi tạo Texture Renderer, DebugText và Audio Synth
    renderer.init();
    audio.init();

    initGameWorld();
}

fn handleUiAction(action: []const u8) void {
    if (std.mem.eql(u8, action, "close_party")) {
        state.mode = .dungeon_map;
    } else if (std.mem.eql(u8, action, "open_party")) {
        state.mode = .party_collection;
    } else if (std.mem.eql(u8, action, "craft_pill")) {
        triggerPillCraft();
    } else if (std.mem.eql(u8, action, "breakthrough")) {
        triggerBreakthrough();
    } else if (std.mem.eql(u8, action, "next_floor")) {
        triggerNextFloor();
    } else if (std.mem.eql(u8, action, "quit_game")) {
        sapp.requestQuit();
    } else if (std.mem.eql(u8, action, "save_db")) {
        db.saveAll(&state.registry, &state.party_entities, state.master_entity, &state.dungeon_world) catch {};
        state.spawnPopup("DA DONG BO SQLITE!", 0.0, 0.08, 80, 255, 120);
        state.setMessage("Toan bo du lieu Tu Si va Linh Thu da duoc dong bo vao sprout.db.");
    } else if (std.mem.eql(u8, action, "recall_0")) {
        recallBeast(0);
    } else if (std.mem.eql(u8, action, "recall_1")) {
        recallBeast(1);
    } else if (std.mem.eql(u8, action, "recall_2")) {
        recallBeast(2);
    } else if (std.mem.startsWith(u8, action, "recall_slot_")) {
        const slot_s = action["recall_slot_".len..];
        const s = std.fmt.parseInt(usize, slot_s, 10) catch 0;
        recallBeast(s);
    } else if (std.mem.eql(u8, action, "feed_0")) {
        if (state.party_entities[0]) |ent| feedBeastEntity(ent);
    } else if (std.mem.eql(u8, action, "feed_1")) {
        if (state.party_entities[1]) |ent| feedBeastEntity(ent);
    } else if (std.mem.eql(u8, action, "feed_2")) {
        if (state.party_entities[2]) |ent| feedBeastEntity(ent);
    } else if (std.mem.startsWith(u8, action, "deploy_beast_")) {
        const id_s = action["deploy_beast_".len..];
        const id = std.fmt.parseInt(u32, id_s, 10) catch 0;
        const b_view = state.registry.view(Beast);
        if (b_view) |pool| {
            for (pool.dense.items) |ent| {
                if (ent.id == id) {
                    deployBeast(ent);
                    break;
                }
            }
        }
    } else if (std.mem.startsWith(u8, action, "feed_beast_")) {
        const id_s = action["feed_beast_".len..];
        const id = std.fmt.parseInt(u32, id_s, 10) catch 0;
        const b_view = state.registry.view(Beast);
        if (b_view) |pool| {
            for (pool.dense.items) |ent| {
                if (ent.id == id) {
                    feedBeastEntity(ent);
                    break;
                }
            }
        }
    } else if (std.mem.startsWith(u8, action, "release_beast_")) {
        const id_s = action["release_beast_".len..];
        const id = std.fmt.parseInt(u32, id_s, 10) catch 0;
        const b_view = state.registry.view(Beast);
        if (b_view) |pool| {
            for (pool.dense.items) |ent| {
                if (ent.id == id) {
                    releaseBeast(ent);
                    break;
                }
            }
        }
    } else if (std.mem.startsWith(u8, action, "tile_")) {
        var it = std.mem.splitScalar(u8, action["tile_".len..], '_');
        if (it.next()) |r_s| {
            if (it.next()) |c_s| {
                const r = std.fmt.parseInt(i32, r_s, 10) catch 0;
                const c = std.fmt.parseInt(i32, c_s, 10) catch 0;
                const p_c = state.dungeon_world.player_col;
                const p_r = state.dungeon_world.player_row;
                const dc = c - p_c;
                const dr = r - p_r;
                if (@abs(dc) + @abs(dr) == 1) {
                    handleMovePlayer(dc, dr);
                } else if (dc != 0 or dr != 0) {
                    const step_c = std.math.sign(dc);
                    const step_r = if (step_c == 0) std.math.sign(dr) else 0;
                    handleMovePlayer(step_c, step_r);
                }
            }
        }
    } else if (std.mem.eql(u8, action, "arena_skill_0") or std.mem.eql(u8, action, "battle_skill_0")) {
        state.arena_state.selected_skill_idx = 0;
        state.arena_state.mode = .targeting_skill;
        state.setCombatLog("Đã chọn Chiêu 1! Nhấp vào mục tiêu trong tầm đỏ để xuất chiêu.");
    } else if (std.mem.eql(u8, action, "arena_skill_1") or std.mem.eql(u8, action, "battle_skill_1")) {
        state.arena_state.selected_skill_idx = 1;
        state.arena_state.mode = .targeting_skill;
        state.setCombatLog("Đã chọn Chiêu 2! Nhấp vào mục tiêu trong tầm đỏ để xuất chiêu.");
    } else if (std.mem.eql(u8, action, "arena_skill_2") or std.mem.eql(u8, action, "battle_skill_2")) {
        state.arena_state.selected_skill_idx = 2;
        state.arena_state.mode = .targeting_skill;
        state.setCombatLog("Đã chọn Chiêu 3! Nhấp vào mục tiêu trong tầm đỏ để xuất chiêu.");
    } else if (std.mem.eql(u8, action, "arena_skill_3") or std.mem.eql(u8, action, "battle_skill_3")) {
        state.arena_state.selected_skill_idx = 3;
        state.arena_state.mode = .targeting_skill;
        state.setCombatLog("Đã chọn Bắt Thú! Nhấp vào Yêu thú máu đỏ để tung Ngự Thú Lệnh.");
    } else if (std.mem.eql(u8, action, "arena_toggle_move")) {
        if (state.arena_state.mode == .targeting_move) {
            state.arena_state.mode = .select_action;
        } else {
            state.arena_state.mode = .targeting_move;
            state.setCombatLog("Chế độ Di Chuyển: Nhấp vào ô xanh lam trên lôi đài.");
        }
    } else if (std.mem.eql(u8, action, "arena_end_turn")) {
        handleArenaEndTurn();
    } else if (std.mem.startsWith(u8, action, "arena_tile_")) {
        var it = std.mem.splitScalar(u8, action["arena_tile_".len..], '_');
        if (it.next()) |c_s| {
            if (it.next()) |r_s| {
                const c = std.fmt.parseInt(i32, c_s, 10) catch -1;
                const r = std.fmt.parseInt(i32, r_s, 10) catch -1;
                if (c >= 0 and r >= 0) {
                    handleArenaTileClick(c, r);
                }
            }
        }
    } else if (std.mem.eql(u8, action, "taming_buff")) {
        triggerTamingBuff();
    } else if (std.mem.eql(u8, action, "taming_order")) {
        executeTamingAttempt();
    } else if (std.mem.eql(u8, action, "flee_battle")) {
        state.mode = .dungeon_map;
        state.setMessage("Thi triển Độn Thuật, rút lui an toàn về Bí Cảnh.");
    }
}

fn dataResolver(key: []const u8, buf: []u8) ?[]const u8 {
    const master = state.registry.get(state.master_entity, CultivatorMaster);

    if (std.mem.eql(u8, key, "master_name")) {
        if (master) |m| return m.name[0..m.name_len];
        return "Vo Danh Tu Si";
    }
    if (std.mem.eql(u8, key, "master_realm")) {
        if (master) |m| return m.realm.asciiName();
        return "Pham Nhan";
    }
    if (std.mem.eql(u8, key, "master_exp")) {
        if (master) |m| return std.fmt.bufPrint(buf, "{}", .{m.exp}) catch null;
        return "0";
    }
    if (std.mem.eql(u8, key, "master_exp_max")) {
        if (master) |m| return std.fmt.bufPrint(buf, "{}", .{m.exp_to_breakthrough}) catch null;
        return "100";
    }
    if (std.mem.eql(u8, key, "master_herbs")) {
        if (master) |m| return std.fmt.bufPrint(buf, "{}", .{m.herbs}) catch null;
        return "0";
    }
    if (std.mem.eql(u8, key, "master_pills")) {
        if (master) |m| return std.fmt.bufPrint(buf, "{}", .{m.pills}) catch null;
        return "0";
    }
    if (std.mem.eql(u8, key, "master_orders")) {
        if (master) |m| return std.fmt.bufPrint(buf, "{}", .{m.taming_orders}) catch null;
        return "0";
    }
    if (std.mem.eql(u8, key, "dungeon_floor")) {
        return std.fmt.bufPrint(buf, "{}", .{state.dungeon_world.floor}) catch null;
    }
    if (std.mem.eql(u8, key, "dungeon_message")) {
        return state.message[0..state.message_len];
    }
    if (std.mem.eql(u8, key, "combat_log")) {
        return state.combat_log[0..state.combat_log_len];
    }
    if (std.mem.eql(u8, key, "master_icon")) {
        return "player";
    }
    if (std.mem.eql(u8, key, "wild_icon")) {
        if (state.wild_beast_entity) |ent| {
            if (state.registry.get(ent, Beast)) |b| return getBeastIcon(b);
        }
        return "dragon";
    }

    // Party slots (0, 1, 2)
    for (0..3) |i| {
        var s_name_k: [20]u8 = undefined;
        const sn = std.fmt.bufPrint(&s_name_k, "slot_{}_name", .{i}) catch continue;
        if (std.mem.eql(u8, key, sn)) {
            if (state.party_entities[i]) |ent| {
                if (state.registry.get(ent, Beast)) |b| {
                    return std.fmt.bufPrint(buf, "{s} [{s}]", .{ b.getName(), b.element.asciiName() }) catch null;
                }
            }
            return "(Chua xuat chien)";
        }

        var s_icon_k: [20]u8 = undefined;
        const si = std.fmt.bufPrint(&s_icon_k, "slot_{}_icon", .{i}) catch continue;
        if (std.mem.eql(u8, key, si)) {
            if (state.party_entities[i]) |ent| {
                if (state.registry.get(ent, Beast)) |b| {
                    return getBeastIcon(b);
                }
            }
            return "";
        }

        var s_hp_k: [20]u8 = undefined;
        const sh = std.fmt.bufPrint(&s_hp_k, "slot_{}_hp", .{i}) catch continue;
        if (std.mem.eql(u8, key, sh)) {
            if (state.party_entities[i]) |ent| {
                if (state.registry.get(ent, Beast)) |b| {
                    return std.fmt.bufPrint(buf, "{}", .{b.hp}) catch null;
                }
            }
            return "0";
        }

        var s_mhp_k: [20]u8 = undefined;
        const smh = std.fmt.bufPrint(&s_mhp_k, "slot_{}_max_hp", .{i}) catch continue;
        if (std.mem.eql(u8, key, smh)) {
            if (state.party_entities[i]) |ent| {
                if (state.registry.get(ent, Beast)) |b| {
                    return std.fmt.bufPrint(buf, "{}", .{b.max_hp}) catch null;
                }
            }
            return "100";
        }

        var s_hps_k: [20]u8 = undefined;
        const shs = std.fmt.bufPrint(&s_hps_k, "slot_{}_hp_str", .{i}) catch continue;
        if (std.mem.eql(u8, key, shs)) {
            if (state.party_entities[i]) |ent| {
                if (state.registry.get(ent, Beast)) |b| {
                    return std.fmt.bufPrint(buf, "{}/{} HP", .{ b.hp, b.max_hp }) catch null;
                }
            }
            return "-";
        }

        var s_st_k: [20]u8 = undefined;
        const sst = std.fmt.bufPrint(&s_st_k, "slot_{}_stats", .{i}) catch continue;
        if (std.mem.eql(u8, key, sst)) {
            if (state.party_entities[i]) |ent| {
                if (state.registry.get(ent, Beast)) |b| {
                    return std.fmt.bufPrint(buf, "Cong: {} | Phong: {} | Toc: {}", .{ b.atk, b.def, b.speed }) catch null;
                }
            }
            return "Chon Linh Thu ben duoi";
        }

        var s_st_short_k: [24]u8 = undefined;
        const sst_short = std.fmt.bufPrint(&s_st_short_k, "slot_{}_stats_short", .{i}) catch continue;
        if (std.mem.eql(u8, key, sst_short)) {
            if (state.party_entities[i]) |ent| {
                if (state.registry.get(ent, Beast)) |b| {
                    return std.fmt.bufPrint(buf, "Cong: {} | Phong: {}", .{ b.atk, b.def }) catch null;
                }
            }
            return "Chua xuat chien";
        }
    }


    // Wild beast
    if (std.mem.eql(u8, key, "wild_name")) {
        if (state.wild_beast_entity) |w_ent| {
            if (state.registry.get(w_ent, Beast)) |w| {
                return std.fmt.bufPrint(buf, "{s} [{s} - {s}]", .{ w.getName(), w.element.asciiName(), w.rarity.asciiName() }) catch null;
            }
        }
        return "YEU THU";
    }
    if (std.mem.eql(u8, key, "wild_hp")) {
        if (state.wild_beast_entity) |w_ent| {
            if (state.registry.get(w_ent, Beast)) |w| {
                return std.fmt.bufPrint(buf, "{}", .{w.hp}) catch null;
            }
        }
        return "0";
    }
    if (std.mem.eql(u8, key, "wild_max_hp")) {
        if (state.wild_beast_entity) |w_ent| {
            if (state.registry.get(w_ent, Beast)) |w| {
                return std.fmt.bufPrint(buf, "{}", .{w.max_hp}) catch null;
            }
        }
        return "100";
    }
    if (std.mem.eql(u8, key, "wild_hp_str")) {
        if (state.wild_beast_entity) |w_ent| {
            if (state.registry.get(w_ent, Beast)) |w| {
                return std.fmt.bufPrint(buf, "{}/{} HP", .{ w.hp, w.max_hp }) catch null;
            }
        }
        return "0/0 HP";
    }
    if (std.mem.eql(u8, key, "wild_hp_color")) {
        if (state.wild_beast_entity) |w_ent| {
            if (state.registry.get(w_ent, Beast)) |w| {
                if (w.isRedHp()) return "#f02828";
            }
        }
        return "#f0a020";
    }
    if (std.mem.eql(u8, key, "wild_stats")) {
        if (state.wild_beast_entity) |w_ent| {
            if (state.registry.get(w_ent, Beast)) |w| {
                return std.fmt.bufPrint(buf, "Cong: {} | Phong: {} | Than: {}", .{ w.atk, w.def, w.speed }) catch null;
            }
        }
        return "";
    }
    if (std.mem.eql(u8, key, "wild_tip_1")) {
        if (state.wild_beast_entity) |w_ent| {
            if (state.registry.get(w_ent, Beast)) |w| {
                if (w.isRedHp()) return "*** YEU THU MAU DO (<30% HP)! CO THE PHONG AN! ***";
            }
        }
        return "Yeu thu dang sung man khi huyet!";
    }
    if (std.mem.eql(u8, key, "wild_tip_2")) {
        if (state.wild_beast_entity) |w_ent| {
            if (state.registry.get(w_ent, Beast)) |w| {
                if (w.isRedHp()) return "Ty le thu phuc: 78%! Bam [T] de tung Ngu Thu Lenh!";
            }
        }
        return "Dung don danh & ky nang lam suy yeu yeu thu ve MAU DO.";
    }
    if (std.mem.eql(u8, key, "wild_tip_3")) {
        if (state.wild_beast_entity) |w_ent| {
            if (state.registry.get(w_ent, Beast)) |w| {
                if (w.isRedHp()) return "Niem chu [S] Thu Phuc Thuat de tang them 25% ty le!";
            }
        }
        return "";
    }

    // ==========================================
    // WANDERING SWORD ARENA RESOLVERS
    // ==========================================
    if (std.mem.eql(u8, key, "timeline_display")) {
        var t_buf: [240]u8 = undefined;
        var cur_len: usize = 0;
        for (0..state.arena_state.timeline_count) |i| {
            const u_idx = state.arena_state.timeline[i];
            if (state.arena_state.getUnit(u_idx)) |u| {
                const is_act = (state.arena_state.active_unit_idx != null and state.arena_state.active_unit_idx.? == u_idx);
                const prefix = if (is_act) "*[" else "[";
                const suffix = if (is_act) "]" else "]";
                const arrow = if (i + 1 < state.arena_state.timeline_count) " > " else "";
                const piece = std.fmt.bufPrint(t_buf[cur_len..], "{s}{s}: {}{s}{s}", .{
                    prefix,
                    u.getName(),
                    u.speed,
                    suffix,
                    arrow,
                }) catch break;
                cur_len += piece.len;
            }
        }
        return std.fmt.bufPrint(buf, "{s}", .{t_buf[0..cur_len]}) catch null;
    }

    if (std.mem.eql(u8, key, "active_unit_name")) {
        if (state.arena_state.active_unit_idx) |act_id| {
            if (state.arena_state.getUnit(act_id)) |au| return au.getName();
        }
        return "Chờ lệnh...";
    }

    for (0..4) |sk_i| {
        var sk_key_buf: [20]u8 = undefined;
        const sk_k = std.fmt.bufPrint(&sk_key_buf, "skill_{}_name", .{sk_i}) catch continue;
        if (std.mem.eql(u8, key, sk_k)) {
            if (state.arena_state.active_unit_idx) |act_id| {
                if (state.arena_state.getUnit(act_id)) |au| {
                    if (sk_i < au.skill_count) {
                        return au.skills[sk_i].getName();
                    }
                }
            }
            return "-";
        }
    }

    // Target / Inspector resolver
    const target_unit: ?*const arena.ArenaUnit = blk: {
        if (state.arena_target_idx) |t_id| {
            if (state.arena_state.getUnitConst(t_id)) |tu| break :blk tu;
        }
        for (state.arena_state.units) |slot| {
            if (slot) |*u| {
                if (u.alive and !u.is_player_side) {
                    break :blk u;
                }
            }
        }
        break :blk null;
    };

    if (std.mem.eql(u8, key, "target_name")) {
        if (target_unit) |tu| return tu.getName();
        return "Không có mục tiêu";
    }
    if (std.mem.eql(u8, key, "target_icon")) {
        if (target_unit) |tu| {
            return switch (tu.icon_id) {
                .player => "player",
                .turtle => "turtle",
                .fox => "fox",
                .bird => "bird",
                .dragon => "dragon",
                else => "player",
            };
        }
        return "dragon";
    }
    if (std.mem.eql(u8, key, "target_role")) {
        if (target_unit) |tu| {
            return if (tu.is_player_side) "Đồng Minh Phe Ta" else "Yêu Thú Đối Phương";
        }
        return "";
    }
    if (std.mem.eql(u8, key, "target_element_str")) {
        if (target_unit) |tu| {
            return std.fmt.bufPrint(buf, "Hệ: {s} | Công: {} | Thủ: {}", .{ tu.element.asciiName(), tu.atk, tu.def }) catch null;
        }
        return "";
    }
    if (std.mem.eql(u8, key, "target_hp")) {
        if (target_unit) |tu| return std.fmt.bufPrint(buf, "{}", .{tu.hp}) catch null;
        return "0";
    }
    if (std.mem.eql(u8, key, "target_max_hp")) {
        if (target_unit) |tu| return std.fmt.bufPrint(buf, "{}", .{tu.max_hp}) catch null;
        return "100";
    }
    if (std.mem.eql(u8, key, "target_hp_str")) {
        if (target_unit) |tu| return std.fmt.bufPrint(buf, "{}/{} HP", .{ tu.hp, tu.max_hp }) catch null;
        return "0/0 HP";
    }
    if (std.mem.eql(u8, key, "target_hp_color")) {
        if (target_unit) |tu| {
            if (tu.is_player_side) return "#32d264";
            if (tu.hp * 5 <= tu.max_hp) return "#ff3030";
            return "#f59e0b";
        }
        return "#ffd740";
    }
    if (std.mem.eql(u8, key, "target_facing_str")) {
        if (target_unit) |tu| {
            return std.fmt.bufPrint(buf, "Hướng nhìn: {s}", .{tu.facing.asString()}) catch null;
        }
        return "Hướng nhìn: -";
    }
    if (std.mem.eql(u8, key, "target_shield_str")) {
        if (target_unit) |tu| {
            return std.fmt.bufPrint(buf, "Hộ Thể Cương Khí: +{} Giáp", .{tu.shield}) catch null;
        }
        return "Hộ Thể: 0";
    }

    return null;
}

fn buildAndRenderXmlUI() void {
    switch (state.mode) {
        .party_collection => {
            xml_ui.parseXmlUI(party_xml_bytes, &xml_ui.ui_state, dataResolver);

            const b_view = state.registry.view(Beast);
            if (b_view) |pool| {
                var row_y: f32 = 330.0;
                for (pool.dense.items) |ent| {
                    const beast = state.registry.get(ent, Beast) orelse continue;
                    if (beast.is_wild or !beast.is_caught) continue;
                    if (row_y > 540.0) break;

                    var name_buf: [48]u8 = undefined;
                    const name_str = std.fmt.bufPrint(&name_buf, "{s} [{s}-{s}]", .{
                        beast.getName(),
                        beast.element.asciiName(),
                        beast.rarity.asciiName(),
                    }) catch "Linh Thu";
                    xml_ui.ui_state.addText("", name_str, 20, row_y + 4, xml_ui.parseColor("#ebf8f2"), 14);

                    var hp_buf: [24]u8 = undefined;
                    const hp_str = std.fmt.bufPrint(&hp_buf, "{}/{} HP", .{ beast.hp, beast.max_hp }) catch "-";
                    xml_ui.ui_state.addText("", hp_str, 250, row_y + 4, xml_ui.parseColor("#32d264"), 14);

                    var st_buf: [32]u8 = undefined;
                    const st_str = std.fmt.bufPrint(&st_buf, "C:{}|P:{}|T:{}", .{ beast.atk, beast.def, beast.speed }) catch "-";
                    xml_ui.ui_state.addText("", st_str, 360, row_y + 4, xml_ui.parseColor("#a0b8b0"), 14);

                    if (beast.isDeployed()) {
                        const slot_str = switch (beast.slot_idx.?) {
                            0 => "[RA TRAN: Tien Phong]",
                            1 => "[RA TRAN: Trung Quan]",
                            2 => "[RA TRAN: Hau Ve]",
                            else => "[RA TRAN: Du Bi]",
                        };
                        xml_ui.ui_state.addText("", slot_str, 505, row_y + 4, xml_ui.parseColor("#ffd740"), 14);

                        var act_buf: [24]u8 = undefined;
                        const act_str = std.fmt.bufPrint(&act_buf, "recall_slot_{}", .{beast.slot_idx.?}) catch "recall";
                        xml_ui.ui_state.addButtonEx("", "[Thu Hoi]", act_str, .{ .x = 675, .y = row_y, .w = 82, .h = 24 },
                            xml_ui.parseColor("#18362b"), xml_ui.parseColor("#0e221b"),
                            xml_ui.parseColor("#306852"), xml_ui.parseColor("#1c4836"),
                            xml_ui.parseColor("#c3a041"), xml_ui.parseColor("#ebf8f2"), 4.0, false);
                    } else {
                        xml_ui.ui_state.addText("", "[Trong Uyen / Kho]", 505, row_y + 4, xml_ui.parseColor("#708078"), 14);

                        var act_buf: [24]u8 = undefined;
                        const act_str = std.fmt.bufPrint(&act_buf, "deploy_beast_{}", .{ent.id}) catch "deploy";
                        xml_ui.ui_state.addButtonEx("", "[Ra Tran]", act_str, .{ .x = 675, .y = row_y, .w = 82, .h = 24 },
                            xml_ui.parseColor("#18362b"), xml_ui.parseColor("#0e221b"),
                            xml_ui.parseColor("#306852"), xml_ui.parseColor("#1c4836"),
                            xml_ui.parseColor("#c3a041"), xml_ui.parseColor("#ffd740"), 4.0, false);
                    }

                    var feed_act: [24]u8 = undefined;
                    const feed_act_str = std.fmt.bufPrint(&feed_act, "feed_beast_{}", .{ent.id}) catch "feed";
                    xml_ui.ui_state.addButtonEx("", "[Boi Duong]", feed_act_str, .{ .x = 762, .y = row_y, .w = 88, .h = 24 },
                        xml_ui.parseColor("#204632"), xml_ui.parseColor("#10261a"),
                        xml_ui.parseColor("#3c8258"), xml_ui.parseColor("#205034"),
                        xml_ui.parseColor("#c3a041"), xml_ui.parseColor("#ffd740"), 4.0, false);

                    var rel_act: [24]u8 = undefined;
                    const rel_act_str = std.fmt.bufPrint(&rel_act, "release_beast_{}", .{ent.id}) catch "release";
                    xml_ui.ui_state.addButtonEx("", "[Tha Pet]", rel_act_str, .{ .x = 855, .y = row_y, .w = 85, .h = 24 },
                        xml_ui.parseColor("#341818"), xml_ui.parseColor("#1e0c0c"),
                        xml_ui.parseColor("#542424"), xml_ui.parseColor("#301414"),
                        xml_ui.parseColor("#a04040"), xml_ui.parseColor("#f08080"), 4.0, false);

                    row_y += 28.0;
                }
            }
        },

        .dungeon_map => {
            xml_ui.parseXmlUI(dungeon_xml_bytes, &xml_ui.ui_state, dataResolver);

            const tile_w: f32 = 42.0;
            const tile_h: f32 = 46.0;
            const grid_start_x: f32 = 252.0;
            const grid_start_y: f32 = 141.0;

            var r_idx: usize = GRID_ROWS;
            while (r_idx > 0) {
                r_idx -= 1;
                const r = r_idx;
                for (0..GRID_COLS) |c| {
                    const tile = state.dungeon_world.tiles[r][c];
                    const is_player = (@as(i32, @intCast(c)) == state.dungeon_world.player_col and @as(i32, @intCast(r)) == state.dungeon_world.player_row);

                    const label = if (is_player)
                        "[TA]"
                    else if (!tile.revealed)
                        "?"
                    else if (tile.cleared)
                        "."
                    else switch (tile.kind) {
                        .empty => ".",
                        .herb => "THAO",
                        .wild_beast => "YEU",
                        .event => "BAO",
                        .boss => "BOSS",
                    };

                    var act_buf: [20]u8 = undefined;
                    const act_str = std.fmt.bufPrint(&act_buf, "tile_{}_{}", .{ r, c }) catch "tile";

                    const tx = grid_start_x + @as(f32, @floatFromInt(c)) * 46.0;
                    const ty = grid_start_y + @as(f32, @floatFromInt(GRID_ROWS - 1 - r)) * 52.0;

                    const btn_bg = if (is_player)
                        xml_ui.parseColor("#265546")
                    else if (!tile.revealed)
                        xml_ui.parseColor("#0d1a18")
                    else switch (tile.kind) {
                        .empty => xml_ui.parseColor("#081210"),
                        .herb => xml_ui.parseColor("#143820"),
                        .wild_beast => xml_ui.parseColor("#381414"),
                        .event => xml_ui.parseColor("#382c14"),
                        .boss => xml_ui.parseColor("#501010"),
                    };

                    xml_ui.ui_state.addButtonEx(
                        "",
                        label,
                        act_str,
                        .{ .x = tx, .y = ty, .w = tile_w, .h = tile_h },
                        btn_bg,
                        null,
                        xml_ui.parseColor("#3a705e"),
                        null,
                        if (is_player) xml_ui.parseColor("#ffe57f") else xml_ui.parseColor("#c3a041"),
                        if (is_player) xml_ui.parseColor("#ffffff") else xml_ui.parseColor("#ebf8f2"),
                        6.0,
                        is_player,
                    );
                }
            }
        },

        .battle => {
            xml_ui.parseXmlUI(battle_xml_bytes, &xml_ui.ui_state, dataResolver);
            renderArenaBoard();
        },
    }

    // 1. Render Drop Shadows mềm
    xml_ui.ui_state.renderShadows(drawModernRect);

    // 2. Render quads bo góc SDF (nền gradient, viền, thanh máu, nút bấm)
    xml_ui.ui_state.renderQuads(drawModernRect);

    // 3. Render Avatars/Images chân dung Linh Thú & Tu Sĩ
    xml_ui.ui_state.renderImages(drawModernRect, drawUiTexture);

    // 4. Render texts bằng Font Atlas UTF-8 sắc nét
    xml_ui.ui_state.renderTexts(renderer.drawUtf8Text);
    renderFloatingTexts();
}

fn renderFloatingTexts() void {
    for (&state.floating_texts) |*ft| {
        if (ft.active) {
            const len = std.mem.indexOfScalar(u8, &ft.text, 0) orelse ft.text.len;
            const px_x = ((ft.x + 1.0) * 0.5) * 960.0;
            const px_y = ((1.0 - ft.y) * 0.5) * 760.0;
            const color = [4]f32{
                @as(f32, @floatFromInt(ft.r)) / 255.0,
                @as(f32, @floatFromInt(ft.g)) / 255.0,
                @as(f32, @floatFromInt(ft.b)) / 255.0,
                1.0,
            };
            renderer.drawUtf8Text(ft.text[0..len], px_x, px_y, 16.0, color);
        }
    }
}

fn updateFloatingTexts(dt: f32) void {
    for (&state.floating_texts) |*ft| {
        if (ft.active) {
            ft.life += dt;
            ft.y += dt * 0.12;
            if (ft.life >= ft.max_life) {
                ft.active = false;
            }
        }
    }
}

export fn frame() void {
    state.pulse_timer += 0.05;
    state.screen_shake *= 0.85;
    if (state.screen_shake < 0.001) state.screen_shake = 0.0;

    audio.update();
    updateFloatingTexts(0.016);

    gl.viewport(0, 0, sapp.width(), sapp.height());
    gl.clearColor(0.02, 0.04, 0.05, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    // 1. Vẽ Ảnh Nền Bí Cảnh / Chiến Trường Tiên Hiệp
    const bg_tex: TextureId = switch (state.mode) {
        .battle => .battle_bg,
        else => .dungeon_bg,
    };
    renderer.drawTexturedQuad(bg_tex, 0.0, 0.0, 1.0, 1.0, .{ 0.38, 0.42, 0.46, 0.88 });

    // 2. Xây dựng và Render giao diện XML UI
    buildAndRenderXmlUI();

    gl.present();
}

export fn cleanup() void {
    audio.cleanup();
    db.saveAll(&state.registry, &state.party_entities, state.master_entity, &state.dungeon_world) catch {};
    db.closeDb();
    state.registry.deinit();
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = input,
        .width = 960,
        .height = 760,
        .fullscreen = true,
        .window_title = "Ngự Thú Tiên Đồ (Beast Ascendant) — XML Mockup UI & Procedural Audio",
        .logger = .{ .func = slog.func },
    });
}

