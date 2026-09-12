const std = @import("std");
const sokol = @import("sokol");
const sapp = sokol.app;
const sg = sokol.gfx;
const sglue = sokol.glue;
const slog = sokol.log;
const sgl = sokol.gl;

const libs = @import("libs");
const gl = libs.gl;
const ecs = libs.ecs;
const mui = libs.mui;

const game = @import("game");
const types = game.types;
const components = game.components;
const beasts = game.beasts;
const battle = game.battle;
const dungeon = game.dungeon;
const renderer = game.renderer;
const audio = game.audio;
const TextureId = renderer.TextureId;

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

// Sokol GL & MicroUI State
var sgl_ctx: sgl.Context = .{};
var mui_ctx: mui.Context = undefined;
var mui_renderer: mui.sokol.Renderer = undefined;

// WebGL Quad Resources
var quad_prog: gl.Program = .{};
var quad_vbo: gl.Buffer = .{};
var quad_pos_loc: gl.AttribLocation = -1;
var u_rect_loc: gl.UniformLocation = .{};
var u_color_loc: gl.UniformLocation = .{};
var u_border_color_loc: gl.UniformLocation = .{};

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
    \\uniform vec4 u_rect;
    \\uniform vec4 u_color;
    \\uniform vec4 u_border_color;
    \\out vec4 frag_color;
    \\void main() {
    \\    vec2 border_px = (vec2(1.0) - abs(v_uv)) * vec2(u_rect.z * 480.0, u_rect.w * 380.0);
    \\    if (border_px.x < 1.5 || border_px.y < 1.5) {
    \\        frag_color = u_border_color;
    \\    } else {
    \\        frag_color = u_color;
    \\    }
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

fn drawRect(x: f32, y: f32, w: f32, h: f32, color: [4]f32, border: [4]f32) void {
    gl.useProgram(quad_prog);
    gl.bindBuffer(gl.ARRAY_BUFFER, quad_vbo);
    gl.enableVertexAttribArray(@intCast(quad_pos_loc));
    gl.vertexAttribPointer(@intCast(quad_pos_loc), 2, gl.FLOAT, false, 0, 0);

    const shake_x = if (state.screen_shake > 0.001) @sin(state.pulse_timer * 35.0) * state.screen_shake else 0.0;
    const shake_y = if (state.screen_shake > 0.001) @cos(state.pulse_timer * 30.0) * state.screen_shake else 0.0;

    gl.uniform4f(u_rect_loc, x + shake_x, y + shake_y, w, h);
    gl.uniform4f(u_color_loc, color[0], color[1], color[2], color[3]);
    gl.uniform4f(u_border_color_loc, border[0], border[1], border[2], border[3]);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
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

    // 2. Khởi tạo 3 Linh Thú Xuất Chiến Mẫu
    // Slot 0: Tiền phong - Bích Thủy Quy (Hệ Thủy)
    const e0 = state.registry.create() catch unreachable;
    var b0 = beasts.createBeast(.bich_thuy_quy, false);
    b0.slot_idx = 0;
    state.registry.add(e0, b0) catch {};
    state.party_entities[0] = e0;

    // Slot 1: Trung quân - Hỏa Diễm Hồ (Hệ Hỏa)
    const e1 = state.registry.create() catch unreachable;
    var b1 = beasts.createBeast(.hoa_diem_ho, false);
    b1.slot_idx = 1;
    state.registry.add(e1, b1) catch {};
    state.party_entities[1] = e1;

    // Slot 2: Hậu vệ - Linh Mộc Điểu (Hệ Mộc)
    const e2 = state.registry.create() catch unreachable;
    var b2 = beasts.createBeast(.linh_moc_dieu, false);
    b2.slot_idx = 2;
    state.registry.add(e2, b2) catch {};
    state.party_entities[2] = e2;

    // 3. Khởi tạo Bản đồ Bí Cảnh tầng 1 (8x10 ô) với Fog of War
    state.dungeon_world = Dungeon.init(1);
    state.mode = .dungeon_map;

    state.setMessage("Tien vao Dai Hoang Co Tran (8x10). Di chuyen [W,A,S,D] de pha suong mu!");
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

    var buf: [96]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Dung do {s} [{s}]! [1,2,3] Ky nang, [SPACE] Danh, [T] Bat.", .{
        wild_beast.getName(),
        wild_beast.element.asciiName(),
    }) catch "Vao tran chien!";
    state.setCombatLog(msg);
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
}

fn triggerFeedBeast(slot_idx: usize) void {
    const master = state.registry.get(state.master_entity, CultivatorMaster) orelse return;
    if (master.herbs >= 1) {
        master.herbs -= 1;
        if (slot_idx < state.party_entities.len) {
            if (state.party_entities[slot_idx]) |p_ent| {
                if (state.registry.get(p_ent, Beast)) |b| {
                    b.hp = @min(b.max_hp, b.hp + 50);
                    b.atk += 2;
                    audio.play(.heal);
                    state.spawnPopup("+50 HP / +2 CONG", 0.0, 0.0, 80, 255, 120);
                    var buf: [96]u8 = undefined;
                    const msg = std.fmt.bufPrint(&buf, "Dung Linh Thao boi bo cho {s}: Hoi 50 HP, tang 2 Cong!", .{b.getName()}) catch "Boi duong!";
                    state.setMessage(msg);
                    return;
                }
            }
        }
    } else {
        audio.play(.tame_fail);
        state.setMessage("Can co Linh Thao de boi bo cho linh thu!");
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
    mui.sokol.handleEvent(&mui_ctx, ev);

    if (ev.type != .KEY_DOWN) return;

    switch (ev.key_code) {
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
                executeBattleRound(1);
            }
        },
        ._2 => {
            if (state.mode == .battle) {
                executeBattleRound(2);
            }
        },
        ._3 => {
            if (state.mode == .battle) {
                executeBattleRound(3);
            }
        },

        .SPACE => {
            if (state.mode == .battle) {
                executeBattleRound(0);
            }
        },

        .T => {
            if (state.mode == .battle) {
                executeTamingAttempt();
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

    // Quái phản kích Tiền Phong
    if (state.party_entities[0]) |tank_ent| {
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

        var placed_slot: ?usize = null;
        for (0..5) |i| {
            if (state.party_entities[i] == null) {
                state.party_entities[i] = wild_ent;
                wild_beast.slot_idx = @intCast(i);
                placed_slot = i;
                break;
            }
        }

        var buf: [96]u8 = undefined;
        if (placed_slot) |s| {
            const msg = std.fmt.bufPrint(&buf, "THU PHUC DAI THANH! {s} da khe uoc tai Slot {}!", .{
                wild_beast.getName(),
                s + 1,
            }) catch "Thu phuc thanh cong!";
            state.setMessage(msg);
        } else {
            const msg = std.fmt.bufPrint(&buf, "Thu phuc thanh cong {s}! (Chuyen vao Linh Thu Uyen).", .{
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

fn setupXianxiaStyle(ctx: *mui.Context) void {
    const rgba = struct {
        fn f(r: u8, g: u8, b: u8, a: u8) mui.Color {
            return .{ .r = r, .g = g, .b = b, .a = a };
        }
    }.f;

    ctx.style.colors[@intFromEnum(mui.StyleColor.text)] = rgba(235, 248, 242, 255);
    ctx.style.colors[@intFromEnum(mui.StyleColor.border)] = rgba(195, 160, 65, 255);
    ctx.style.colors[@intFromEnum(mui.StyleColor.windowbg)] = rgba(12, 24, 22, 248);
    ctx.style.colors[@intFromEnum(mui.StyleColor.titlebg)] = rgba(18, 48, 40, 255);
    ctx.style.colors[@intFromEnum(mui.StyleColor.titletext)] = rgba(255, 215, 60, 255);
    ctx.style.colors[@intFromEnum(mui.StyleColor.panelbg)] = rgba(8, 18, 16, 240);
    ctx.style.colors[@intFromEnum(mui.StyleColor.button)] = rgba(24, 52, 44, 255);
    ctx.style.colors[@intFromEnum(mui.StyleColor.buttonhover)] = rgba(38, 85, 70, 255);
    ctx.style.colors[@intFromEnum(mui.StyleColor.buttonfocus)] = rgba(60, 120, 100, 255);
    ctx.style.colors[@intFromEnum(mui.StyleColor.base)] = rgba(14, 30, 26, 255);
    ctx.style.colors[@intFromEnum(mui.StyleColor.basehover)] = rgba(26, 48, 42, 255);
    ctx.style.colors[@intFromEnum(mui.StyleColor.basefocus)] = rgba(38, 68, 58, 255);
    ctx.style.colors[@intFromEnum(mui.StyleColor.scrollbase)] = rgba(14, 26, 24, 255);
    ctx.style.colors[@intFromEnum(mui.StyleColor.scrollthumb)] = rgba(55, 105, 90, 255);

    ctx.style.title_height = 24;
    ctx.style.padding = 6;
    ctx.style.spacing = 5;
}

export fn init() void {
    state.registry = ecs.Registry.init(std.heap.page_allocator);

    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    sgl.setup(.{
        .logger = .{ .func = slog.func },
    });
    sgl_ctx = sgl.makeContext(.{ .max_vertices = 64 * 1024 });
    mui_renderer = mui.sokol.initBackend(&mui_ctx, sgl_ctx);
    setupXianxiaStyle(&mui_ctx);

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

    // Khởi tạo Texture Renderer, DebugText và Audio Synth
    renderer.init();
    audio.init();

    initGameWorld();
}

fn drawMicrouiHpBar(ctx: *mui.Context, current_hp: i32, max_hp: i32, is_red: bool) void {
    const r = ctx.layoutNext();
    ctx.drawRect(r, .{ .r = 16, .g = 26, .b = 24, .a = 255 });
    ctx.drawBox(r, .{ .r = 60, .g = 90, .b = 80, .a = 255 });

    if (current_hp <= 0 or max_hp <= 0) return;
    const ratio = std.math.clamp(@as(f32, @floatFromInt(current_hp)) / @as(f32, @floatFromInt(max_hp)), 0.0, 1.0);
    const fill_w = @as(i32, @intFromFloat(@as(f32, @floatFromInt(r.w - 2)) * ratio));
    const fill_color: mui.Color = if (is_red)
        .{ .r = 240, .g = 40, .b = 40, .a = 255 }
    else if (ratio < 0.35)
        .{ .r = 240, .g = 180, .b = 40, .a = 255 }
    else
        .{ .r = 50, .g = 210, .b = 100, .a = 255 };

    ctx.drawRect(mui.Rect.init(r.x + 1, r.y + 1, fill_w, r.h - 2), fill_color);

    var buf: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, "{}/{} HP", .{ current_hp, max_hp }) catch "HP";
    ctx.drawText(0, text, .{ .x = r.x + 8, .y = r.y + @divTrunc(r.h - 14, 2) }, .{ .r = 255, .g = 255, .b = 255, .a = 255 });
}

fn buildMicrouiDungeon() void {
    const master = state.registry.get(state.master_entity, CultivatorMaster);

    // 1. Header Window
    if (mui_ctx.beginWindow("HeaderDungeon", mui.Rect.init(10, 8, 940, 64), .{
        .notitle = true,
        .noresize = true,
        .noscroll = true,
    }).active) {
        defer mui_ctx.endWindow();

        mui_ctx.layoutRow(&[_]i32{-1}, 18);
        var t_buf: [80]u8 = undefined;
        const title = std.fmt.bufPrint(&t_buf, "[NGU THU TIEN DO] -- BI CANH CO TRAN (TANG {})", .{state.dungeon_world.floor}) catch "NGU THU TIEN DO";
        mui_ctx.textLabel(title);

        if (master) |m| {
            mui_ctx.layoutRow(&[_]i32{ 280, 180, 240, -1 }, 22);
            var m_buf: [80]u8 = undefined;
            const m_str = std.fmt.bufPrint(&m_buf, "TU SI: {s} | {s}", .{ m.name[0..m.name_len], m.realm.asciiName() }) catch "TU SI";
            mui_ctx.textLabel(m_str);

            var exp_buf: [40]u8 = undefined;
            const exp_str = std.fmt.bufPrint(&exp_buf, "EXP: {} / {}", .{ m.exp, m.exp_to_breakthrough }) catch "EXP";
            mui_ctx.textLabel(exp_str);

            var it_buf: [60]u8 = undefined;
            const it_str = std.fmt.bufPrint(&it_buf, "Linh Thao: {} | Dan: {}", .{ m.herbs, m.pills }) catch "ITEMS";
            mui_ctx.textLabel(it_str);

            var to_buf: [40]u8 = undefined;
            const to_str = std.fmt.bufPrint(&to_buf, "Ngu Thu Lenh: {}", .{ m.taming_orders }) catch "TAMING";
            mui_ctx.textLabel(to_str);
        }
    }

    // 2. Left Window: Party Summary
    if (mui_ctx.beginWindow("Doi Hinh Chien Thu", mui.Rect.init(10, 78, 220, 512), .{
        .noresize = true,
        .noclose = true,
    }).active) {
        defer mui_ctx.endWindow();

        const slot_names = [_][]const u8{ "[1] TIEN PHONG", "[2] TRUNG QUAN", "[3] HAU VE" };
        for (0..3) |i| {
            mui_ctx.layoutRow(&[_]i32{-1}, 18);
            mui_ctx.textLabel(slot_names[i]);

            if (state.party_entities[i]) |p_ent| {
                if (state.registry.get(p_ent, Beast)) |b| {
                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    var nb: [40]u8 = undefined;
                    const ns = std.fmt.bufPrint(&nb, "{s} [{s}]", .{ b.getName(), b.element.asciiName() }) catch "THU";
                    mui_ctx.textLabel(ns);

                    mui_ctx.layoutRow(&[_]i32{-1}, 16);
                    drawMicrouiHpBar(&mui_ctx, b.hp, b.max_hp, false);

                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    var st_buf: [40]u8 = undefined;
                    const st_str = std.fmt.bufPrint(&st_buf, "Cong: {} | Phong: {}", .{ b.atk, b.def }) catch "STATS";
                    mui_ctx.textLabel(st_str);
                }
            } else {
                mui_ctx.layoutRow(&[_]i32{-1}, 20);
                mui_ctx.textLabel("(Chua xuat chien)");
            }
            mui_ctx.layoutRow(&[_]i32{-1}, 8);
            mui_ctx.textLabel("");
        }

        mui_ctx.layoutRow(&[_]i32{-1}, 32);
        if (mui_ctx.button("[C] Linh Thu Uyen").submit) {
            state.mode = .party_collection;
        }
    }

    // 3. Center Window: 8x10 Dungeon Map Grid
    if (mui_ctx.beginWindow("Dai Hoang Co Tran (8x10)", mui.Rect.init(236, 78, 488, 512), .{
        .noresize = true,
        .noclose = true,
        .noscroll = true,
    }).active) {
        defer mui_ctx.endWindow();

        const col_widths = [_]i32{ 44, 44, 44, 44, 44, 44, 44, 44, 44, 44 };

        var r_idx: usize = GRID_ROWS;
        while (r_idx > 0) {
            r_idx -= 1;
            const r = r_idx;
            mui_ctx.layoutRow(&col_widths, 46);

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

                var id_buf: [16]u8 = undefined;
                const id_str = std.fmt.bufPrint(&id_buf, "t_{}_{}", .{ r, c }) catch "t";
                mui_ctx.pushId(id_str);

                if (mui_ctx.button(label).submit) {
                    const p_c = state.dungeon_world.player_col;
                    const p_r = state.dungeon_world.player_row;
                    const dc = @as(i32, @intCast(c)) - p_c;
                    const dr = @as(i32, @intCast(r)) - p_r;
                    if (@abs(dc) + @abs(dr) == 1) {
                        handleMovePlayer(dc, dr);
                    } else if (dc != 0 or dr != 0) {
                        const step_c = std.math.sign(dc);
                        const step_r = if (step_c == 0) std.math.sign(dr) else 0;
                        handleMovePlayer(step_c, step_r);
                    }
                }
                mui_ctx.popId();
            }
        }
    }

    // 4. Right Window: Actions & Legend
    if (mui_ctx.beginWindow("Bi Canh Bi Kip", mui.Rect.init(730, 78, 220, 512), .{
        .noresize = true,
        .noclose = true,
    }).active) {
        defer mui_ctx.endWindow();

        mui_ctx.layoutRow(&[_]i32{-1}, 18);
        mui_ctx.textLabel("--- KY HIEU O CO ---");
        mui_ctx.textLabel("[?]    Suong mu bi an");
        mui_ctx.textLabel("[THAO] Thu hai Tien Thao");
        mui_ctx.textLabel("[YEU]  Yeu Thu hoang da");
        mui_ctx.textLabel("[BAO]  Ruong co co duyen");
        mui_ctx.textLabel("[BOSS] Yeu Vuong Co Tran");

        mui_ctx.layoutRow(&[_]i32{-1}, 10);
        mui_ctx.textLabel("");

        mui_ctx.layoutRow(&[_]i32{-1}, 18);
        mui_ctx.textLabel("--- THAO TAC TU SI ---");

        mui_ctx.layoutRow(&[_]i32{-1}, 32);
        if (mui_ctx.button("[P] Luyen Dan Duoc").submit) {
            triggerPillCraft();
        }

        mui_ctx.layoutRow(&[_]i32{-1}, 32);
        if (mui_ctx.button("[B] Dot Pha Canh Gioi").submit) {
            triggerBreakthrough();
        }

        mui_ctx.layoutRow(&[_]i32{-1}, 32);
        if (mui_ctx.button("[C] Linh Thu Uyen").submit) {
            state.mode = .party_collection;
        }

        mui_ctx.layoutRow(&[_]i32{-1}, 32);
        if (mui_ctx.button("[R] Sang Tang Moi").submit) {
            triggerNextFloor();
        }

        mui_ctx.layoutRow(&[_]i32{-1}, 32);
        if (mui_ctx.button("[ESC] Thoat Game").submit) {
            sapp.requestQuit();
        }
    }

    // 5. Bottom Log Window
    if (mui_ctx.beginWindow("Nhat Ky Bi Canh", mui.Rect.init(10, 596, 940, 154), .{
        .noresize = true,
        .noclose = true,
    }).active) {
        defer mui_ctx.endWindow();

        mui_ctx.layoutRow(&[_]i32{-1}, 24);
        mui_ctx.textBlock(state.message[0..state.message_len]);

        mui_ctx.layoutRow(&[_]i32{-1}, 20);
        mui_ctx.textLabel("TU LUYEN: 3 Linh Thao -> 1 Truc Co Dan [P]  |  Du Exp bam [B] de Dot Pha.");

        mui_ctx.layoutRow(&[_]i32{-1}, 20);
        mui_ctx.textLabel("DIEU KHIEN: Phim [W,A,S,D] hoac click chuot truc tiep vao cac o ban do.");
    }
}

fn buildMicrouiBattle() void {
    const master = state.registry.get(state.master_entity, CultivatorMaster);

    // 1. Header Window
    if (mui_ctx.beginWindow("HeaderBattle", mui.Rect.init(10, 8, 940, 64), .{
        .notitle = true,
        .noresize = true,
        .noscroll = true,
    }).active) {
        defer mui_ctx.endWindow();

        mui_ctx.layoutRow(&[_]i32{-1}, 18);
        mui_ctx.textLabel("[CHIEN DAU] -- TIEN HOAN CHIEN TRUONG");

        if (master) |m| {
            mui_ctx.layoutRow(&[_]i32{ 380, 240, -1 }, 22);
            var m_buf: [80]u8 = undefined;
            const m_str = std.fmt.bufPrint(&m_buf, "Tu Si: {s} | Ngu Thu Tran", .{ m.name[0..m.name_len] }) catch "TU SI";
            mui_ctx.textLabel(m_str);

            var to_buf: [40]u8 = undefined;
            const to_str = std.fmt.bufPrint(&to_buf, "Ngu Thu Lenh: {} cai", .{ m.taming_orders }) catch "TAMING";
            mui_ctx.textLabel(to_str);

            mui_ctx.textLabel("[HOP KICH PHAN VIEM] Hoa +30% DMG");
        }
    }

    // 2. Left Window: Ally Party
    if (mui_ctx.beginWindow("Phe Ta: Tu Si & Chien Thu", mui.Rect.init(10, 78, 460, 480), .{
        .noresize = true,
        .noclose = true,
    }).active) {
        defer mui_ctx.endWindow();

        const skill_names = [_][]const u8{
            "[1] Ho The Thuan (Bich Thuy Quy: -50% DMG)",
            "[2] Liet Hoa Diem (Hoa Diem Ho: 60 DMG)",
            "[3] Hoi Xuan Thuat (Linh Moc Dieu: +40 HP)",
        };

        for (0..3) |i| {
            if (state.party_entities[i]) |p_ent| {
                if (state.registry.get(p_ent, Beast)) |b| {
                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    var name_buf: [60]u8 = undefined;
                    const name_str = std.fmt.bufPrint(&name_buf, "[Slot {}] {s} [{s} - {s}]", .{
                        i + 1,
                        b.getName(),
                        b.element.asciiName(),
                        b.rarity.asciiName(),
                    }) catch "THU";
                    mui_ctx.textLabel(name_str);

                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    drawMicrouiHpBar(&mui_ctx, b.hp, b.max_hp, false);

                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    var st_buf: [60]u8 = undefined;
                    const st_str = std.fmt.bufPrint(&st_buf, "Cong: {} | Phong: {} | Than: {}", .{ b.atk, b.def, b.speed }) catch "STATS";
                    mui_ctx.textLabel(st_str);

                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    mui_ctx.textLabel(skill_names[i]);

                    mui_ctx.layoutRow(&[_]i32{-1}, 6);
                    mui_ctx.textLabel("");
                }
            }
        }
    }

    // 3. Right Window: Wild Beast
    if (mui_ctx.beginWindow("Doi Phuong: Yeu Thu Hoang Da", mui.Rect.init(480, 78, 470, 480), .{
        .noresize = true,
        .noclose = true,
    }).active) {
        defer mui_ctx.endWindow();

        if (state.wild_beast_entity) |w_ent| {
            if (state.registry.get(w_ent, Beast)) |w| {
                mui_ctx.layoutRow(&[_]i32{-1}, 22);
                var wb_buf: [60]u8 = undefined;
                const wb_str = std.fmt.bufPrint(&wb_buf, "YEU THU: {s} [{s} - {s}]", .{
                    w.getName(),
                    w.element.asciiName(),
                    w.rarity.asciiName(),
                }) catch "YEU THU";
                mui_ctx.textLabel(wb_str);

                mui_ctx.layoutRow(&[_]i32{-1}, 24);
                drawMicrouiHpBar(&mui_ctx, w.hp, w.max_hp, w.isRedHp());

                mui_ctx.layoutRow(&[_]i32{-1}, 20);
                var st_buf: [60]u8 = undefined;
                const st_str = std.fmt.bufPrint(&st_buf, "Cong: {} | Phong: {} | Than: {}", .{ w.atk, w.def, w.speed }) catch "STATS";
                mui_ctx.textLabel(st_str);

                mui_ctx.layoutRow(&[_]i32{-1}, 12);
                mui_ctx.textLabel("");

                if (w.isRedHp()) {
                    mui_ctx.layoutRow(&[_]i32{-1}, 22);
                    mui_ctx.textLabel("*** YEU THU MAU DO (<30% HP)! CO THE PHONG AN! ***");
                    mui_ctx.layoutRow(&[_]i32{-1}, 20);
                    mui_ctx.textLabel("Ty le thu phuc: 78%! Bam [T] de tung Ngu Thu Lenh!");
                    mui_ctx.layoutRow(&[_]i32{-1}, 20);
                    mui_ctx.textLabel("Niem chu [S] Thu Phuc Thuat de tang them 25% ty le!");
                } else {
                    mui_ctx.layoutRow(&[_]i32{-1}, 22);
                    mui_ctx.textLabel("Yeu thu dang sung man khi huyet!");
                    mui_ctx.layoutRow(&[_]i32{-1}, 20);
                    mui_ctx.textLabel("Dung don danh & ky nang lam suy yeu yeu thu ve MAU DO.");
                }

                mui_ctx.layoutRow(&[_]i32{-1}, 16);
                mui_ctx.textLabel("");
                mui_ctx.layoutRow(&[_]i32{-1}, 18);
                mui_ctx.textLabel("--- TUONG KHAC NGU HANH ---");
                mui_ctx.textLabel("Hoa khac Kim (+50%), Thuy khac Hoa, Moc khac Tho.");
                mui_ctx.textLabel("Am - Duong khac nhau: x2.0 Sat thuong Chi Mang!");
            }
        }
    }

    // 4. Bottom Left Window: Combat Action Buttons
    if (mui_ctx.beginWindow("Menh Lenh Tac Chien", mui.Rect.init(10, 566, 530, 184), .{
        .noresize = true,
        .noclose = true,
    }).active) {
        defer mui_ctx.endWindow();

        mui_ctx.layoutRow(&[_]i32{ 250, -1 }, 32);
        if (mui_ctx.button("[SPACE] Hop Kich 3 Thu").submit) {
            executeBattleRound(0);
        }
        if (mui_ctx.button("[1] Ho The Thuan").submit) {
            executeBattleRound(1);
        }

        mui_ctx.layoutRow(&[_]i32{ 250, -1 }, 32);
        if (mui_ctx.button("[2] Liet Hoa Diem").submit) {
            executeBattleRound(2);
        }
        if (mui_ctx.button("[3] Hoi Xuan Thuat").submit) {
            executeBattleRound(3);
        }

        mui_ctx.layoutRow(&[_]i32{ 250, -1 }, 32);
        if (mui_ctx.button("[S] Niem Chu (+25% Bat)").submit) {
            triggerTamingBuff();
        }
        if (mui_ctx.button("[T] Tung Ngu Thu Lenh").submit) {
            executeTamingAttempt();
        }

        mui_ctx.layoutRow(&[_]i32{-1}, 30);
        if (mui_ctx.button("[ESC] Don Thuat Rut Lui").submit) {
            state.mode = .dungeon_map;
            state.setMessage("Thi trien Don Thuat, rut lui an toan ve Bi Canh.");
        }
    }

    // 5. Bottom Right Window: Combat Log
    if (mui_ctx.beginWindow("Dien Bien Giao Tranh", mui.Rect.init(550, 566, 400, 184), .{
        .noresize = true,
        .noclose = true,
    }).active) {
        defer mui_ctx.endWindow();

        mui_ctx.layoutRow(&[_]i32{-1}, 40);
        mui_ctx.textBlock(state.combat_log[0..state.combat_log_len]);

        if (master) |m| {
            mui_ctx.layoutRow(&[_]i32{-1}, 20);
            var b: [40]u8 = undefined;
            const s = std.fmt.bufPrint(&b, "Ngu Thu Lenh con lai: {} cai", .{ m.taming_orders }) catch "0";
            mui_ctx.textLabel(s);
        }

        mui_ctx.layoutRow(&[_]i32{-1}, 20);
        mui_ctx.textLabel("Click nut lenh hoac bam phim tuong ung tren ban phim.");
    }
}

fn buildMicrouiParty() void {
    const master = state.registry.get(state.master_entity, CultivatorMaster);

    // 1. Header Window
    if (mui_ctx.beginWindow("HeaderParty", mui.Rect.init(10, 8, 940, 64), .{
        .notitle = true,
        .noresize = true,
        .noscroll = true,
    }).active) {
        defer mui_ctx.endWindow();

        mui_ctx.layoutRow(&[_]i32{-1}, 18);
        mui_ctx.textLabel("[LINH THU UYEN] -- BOI DUONG & QUAN LY KHE UOC");

        if (master) |m| {
            mui_ctx.layoutRow(&[_]i32{ 320, 240, -1 }, 22);
            var m_buf: [80]u8 = undefined;
            const m_str = std.fmt.bufPrint(&m_buf, "Chu Nhan: {s} | Canh Gioi: {s}", .{ m.name[0..m.name_len], m.realm.asciiName() }) catch "CHU NHAN";
            mui_ctx.textLabel(m_str);

            var it_buf: [60]u8 = undefined;
            const it_str = std.fmt.bufPrint(&it_buf, "Tien Thao: {} | Truc Co Dan: {}", .{ m.herbs, m.pills }) catch "ITEMS";
            mui_ctx.textLabel(it_str);

            var to_buf: [40]u8 = undefined;
            const to_str = std.fmt.bufPrint(&to_buf, "Ngu Thu Lenh: {} cai", .{ m.taming_orders }) catch "TAMING";
            mui_ctx.textLabel(to_str);
        }
    }

    // 2. Center Window: 5 Party Beasts
    if (mui_ctx.beginWindow("5 Linh Thu Khe Uoc", mui.Rect.init(10, 78, 940, 480), .{
        .noresize = true,
        .noclose = true,
    }).active) {
        defer mui_ctx.endWindow();

        const slot_titles = [_][]const u8{
            "[TIEN PHONG]",
            "[TRUNG QUAN]",
            "[HAU VE]",
            "[DU BI 1]",
            "[DU BI 2]",
        };

        const col_widths = [_]i32{ 174, 174, 174, 174, 174 };
        mui_ctx.layoutRow(&col_widths, 430);

        for (0..5) |i| {
            mui_ctx.layoutBeginColumn();

            mui_ctx.layoutRow(&[_]i32{-1}, 20);
            mui_ctx.textLabel(slot_titles[i]);

            if (state.party_entities[i]) |p_ent| {
                if (state.registry.get(p_ent, Beast)) |b| {
                    mui_ctx.layoutRow(&[_]i32{-1}, 20);
                    mui_ctx.textLabel(b.getName());
        // Draw beast icon
        renderer.drawIcon(beastIconId(b.*), renderer.charToNdcX(5.0), renderer.charToNdcY(20.0), 0.07);

                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    var eb: [40]u8 = undefined;
                    const es = std.fmt.bufPrint(&eb, "He: {s}", .{ b.element.asciiName() }) catch "HE";
                    mui_ctx.textLabel(es);

                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    var rb: [40]u8 = undefined;
                    const rs = std.fmt.bufPrint(&rb, "Pham: {s}", .{ b.rarity.asciiName() }) catch "PHAM";
                    mui_ctx.textLabel(rs);

                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    drawMicrouiHpBar(&mui_ctx, b.hp, b.max_hp, false);

                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    var ab: [40]u8 = undefined;
                    const as = std.fmt.bufPrint(&ab, "Cong:  {}", .{ b.atk }) catch "CONG";
                    mui_ctx.textLabel(as);

                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    var db: [40]u8 = undefined;
                    const ds = std.fmt.bufPrint(&db, "Phong: {}", .{ b.def }) catch "PHONG";
                    mui_ctx.textLabel(ds);

                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    var sb: [40]u8 = undefined;
                    const ss = std.fmt.bufPrint(&sb, "Than:  {}", .{ b.speed }) catch "THAN";
                    mui_ctx.textLabel(ss);

                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    // Remove beast from party
                    if (mui_ctx.button("Gỡ").submit) {
                        state.party_entities[i] = null;
                    }
                    mui_ctx.layoutRow(&[_]i32{-1}, 18);
                    if (mui_ctx.button("Ra Trận").submit) {
                        triggerNextFloor();
                    }
                    var mb: [40]u8 = undefined;
                    const ms = std.fmt.bufPrint(&mb, "Mana:  {}", .{ b.mana }) catch "MANA";
                    mui_ctx.textLabel(ms);

                    mui_ctx.layoutRow(&[_]i32{-1}, 12);
                    mui_ctx.textLabel("");

                    var feed_id_buf: [16]u8 = undefined;
                    const feed_id = std.fmt.bufPrint(&feed_id_buf, "feed_{}", .{ i }) catch "feed";
                    mui_ctx.pushId(feed_id);
                    mui_ctx.layoutRow(&[_]i32{-1}, 32);
                    if (mui_ctx.button("[F] Cho An Thao").submit) {
                        triggerFeedBeast(i);
                    }
                    mui_ctx.popId();
                }
            } else {
                mui_ctx.layoutRow(&[_]i32{-1}, 24);
                mui_ctx.textLabel("(O TRONG)");
                mui_ctx.layoutRow(&[_]i32{-1}, 20);
                mui_ctx.textLabel("Chua co linh thu");
                mui_ctx.layoutRow(&[_]i32{-1}, 20);
                mui_ctx.textLabel("Hay vao Bi Canh");
                mui_ctx.layoutRow(&[_]i32{-1}, 20);
                mui_ctx.textLabel("dung Ngu Thu Lenh [T]");
                mui_ctx.layoutRow(&[_]i32{-1}, 20);
                mui_ctx.textLabel("de thu phuc!");
            }

            mui_ctx.layoutEndColumn();
        }
    }

    // 3. Bottom Window: Guidance & Action Buttons
    if (mui_ctx.beginWindow("Huong Dan Boi Duong", mui.Rect.init(10, 566, 940, 184), .{
        .noresize = true,
        .noclose = true,
    }).active) {
        defer mui_ctx.endWindow();

        mui_ctx.layoutRow(&[_]i32{ 280, 280, -1 }, 32);
        if (mui_ctx.button("[C] Tro Ve Bi Canh").submit) {
            state.mode = .dungeon_map;
        }
        if (mui_ctx.button("[P] Luyen Truc Co Dan").submit) {
            triggerPillCraft();
        }
        if (mui_ctx.button("[B] Dot Pha Canh Gioi").submit) {
            triggerBreakthrough();
        }

        mui_ctx.layoutRow(&[_]i32{-1}, 20);
        mui_ctx.textLabel("BOI DUONG: Tieu hao 1 Linh Thao de hoi 50 HP va tang vinh vien 2 diem Cong Kich cho Chien Thu.");

        mui_ctx.layoutRow(&[_]i32{-1}, 20);
        mui_ctx.textLabel("LUYEN DAN & DOT PHA: 3 Linh Thao -> 1 Truc Co Dan. Khi du Exp can dan de vuot Dai Canh Gioi.");
    }
}

fn renderFloatingTexts() void {
    if (mui_ctx.beginWindow("!popups", mui.Rect.init(0, 0, 960, 760), .{
        .notitle = true,
        .noframe = true,
        .noresize = true,
        .noscroll = true,
        .nointeract = true,
    }).active) {
        defer mui_ctx.endWindow();
        for (&state.floating_texts) |*ft| {
            if (ft.active) {
                const sx = @as(i32, @intFromFloat((ft.x + 1.0) * 0.5 * 960.0));
                const sy = @as(i32, @intFromFloat((1.0 - ft.y) * 0.5 * 760.0));
                const len = std.mem.indexOfScalar(u8, &ft.text, 0) orelse ft.text.len;
                mui_ctx.drawText(0, ft.text[0..len], .{ .x = sx, .y = sy }, .{ .r = ft.r, .g = ft.g, .b = ft.b, .a = 255 });
            }
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

    // 2. Xây dựng giao diện MicroUI
    mui_ctx.begin();
    switch (state.mode) {
        .dungeon_map => buildMicrouiDungeon(),
        .battle => buildMicrouiBattle(),
        .party_collection => buildMicrouiParty(),
    }
    renderFloatingTexts();
    mui_ctx.end();

    // 3. Kết xuất toàn bộ giao diện MicroUI bằng Sokol GL
    mui_renderer.renderCommands(sapp.width(), sapp.height());

    gl.present();
}

export fn cleanup() void {
    audio.cleanup();
    mui_renderer.deinit();
    sgl.destroyContext(sgl_ctx);
    sgl.shutdown();
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
        .window_title = "Ngự Thú Tiên Đồ (Beast Ascendant) — MicroUI & Procedural Audio",
        .logger = .{ .func = slog.func },
    });
}
