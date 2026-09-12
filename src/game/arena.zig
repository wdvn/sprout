const std = @import("std");
const types = @import("types.zig");
const components = @import("components.zig");
const libs = @import("libs");
const ecs = libs.ecs;
const renderer = @import("renderer.zig");

pub const Element = types.Element;
pub const TextureId = renderer.TextureId;

pub const ARENA_COLS: usize = 8;
pub const ARENA_ROWS: usize = 5;

pub const Facing = enum(u8) {
    right = 0,
    left = 1,
    up = 2,
    down = 3,

    pub fn asString(self: Facing) []const u8 {
        return switch (self) {
            .right => "Phải [>]",
            .left => "Trái [<]",
            .up => "Lên [^]",
            .down => "Xuống [v]",
        };
    }
};

pub const PositionalHit = enum(u8) {
    frontal = 0,
    flank = 1,
    back = 2,

    pub fn damageMultiplier(self: PositionalHit) f32 {
        return switch (self) {
            .frontal => 1.0,
            .flank => 1.25, // +25% Sát thương Trắc Kích
            .back => 1.50,  // +50% Sát thương Hậu Kích
        };
    }

    pub fn label(self: PositionalHit) []const u8 {
        return switch (self) {
            .frontal => "Chính Diện",
            .flank => "TRẮC KÍCH! +25%",
            .back => "HẬU KÍCH! +50%",
        };
    }
};

pub const SkillShape = enum(u8) {
    melee_single,   // Cận chiến 1 ô liền kề (4 hướng)
    line_pierce,    // Đâm thẳng 2-3 ô theo hướng nhìn
    ranged_single,  // Đánh xa 1 mục tiêu trong bán kính 3 ô
    ranged_aoe,     // Đánh xa 3 ô, bộc phá lan 1 ô xung quanh
    self_shield,    // Hộ thể cương khí tự thân + đồng minh liền kề
    heal_target,    // Trị liệu đồng đội trong tầm 3 ô
    tame_beast,     // Tung Ngự Thú Lệnh bắt yêu thú máu đỏ (<15%) trong tầm 2 ô
};

pub const TacticalSkill = struct {
    name: [28]u8 = [_]u8{0} ** 28,
    name_len: usize = 0,
    shape: SkillShape = .melee_single,
    range: i32 = 1,
    base_damage: i32 = 25,
    heal_power: i32 = 0,
    shield_power: i32 = 0,
    element: Element = .huo,

    pub fn init(
        name_slice: []const u8,
        shape: SkillShape,
        range: i32,
        damage: i32,
        heal: i32,
        shield: i32,
        element: Element,
    ) TacticalSkill {
        var s = TacticalSkill{
            .shape = shape,
            .range = range,
            .base_damage = damage,
            .heal_power = heal,
            .shield_power = shield,
            .element = element,
        };
        const len = @min(name_slice.len, s.name.len);
        @memcpy(s.name[0..len], name_slice[0..len]);
        s.name_len = len;
        return s;
    }

    pub fn getName(self: *const TacticalSkill) []const u8 {
        return self.name[0..self.name_len];
    }
};

pub const ArenaUnit = struct {
    id: u8 = 0,
    entity: ?ecs.Entity = null,
    name: [28]u8 = [_]u8{0} ** 28,
    name_len: usize = 0,
    is_player_side: bool = true,
    icon_id: TextureId = .player,
    col: i32 = 0,
    row: i32 = 0,
    facing: Facing = .right,
    move_range: i32 = 3,
    speed: i32 = 50,
    action_gauge: i32 = 0,
    hp: i32 = 100,
    max_hp: i32 = 100,
    atk: i32 = 25,
    def: i32 = 10,
    shield: i32 = 0,
    element: Element = .huo,
    skills: [4]TacticalSkill = undefined,
    skill_count: u8 = 0,
    has_moved: bool = false,
    has_acted: bool = false,
    alive: bool = true,

    pub fn getName(self: *const ArenaUnit) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn setName(self: *ArenaUnit, slice: []const u8) void {
        const len = @min(slice.len, self.name.len);
        @memcpy(self.name[0..len], slice[0..len]);
        self.name_len = len;
    }

    pub fn addSkill(self: *ArenaUnit, skill: TacticalSkill) void {
        if (self.skill_count < 4) {
            self.skills[self.skill_count] = skill;
            self.skill_count += 1;
        }
    }
};

pub const ArenaPhase = enum {
    player_turn,
    animating,
    enemy_turn,
    victory,
    defeat,
    tamed,
};

pub const ArenaMode = enum {
    select_action,
    targeting_move,
    targeting_skill,
};

pub const GridPos = struct {
    col: i32,
    row: i32,

    pub fn eql(self: GridPos, other: GridPos) bool {
        return self.col == other.col and self.row == other.row;
    }
};

pub const ArenaState = struct {
    units: [8]?ArenaUnit = [_]?ArenaUnit{null} ** 8,
    unit_count: u8 = 0,
    active_unit_idx: ?u8 = null,
    selected_skill_idx: ?u8 = null,
    hover_tile: ?GridPos = null,
    mode: ArenaMode = .select_action,
    phase: ArenaPhase = .player_turn,
    round_number: u32 = 1,

    timeline: [8]u8 = [_]u8{0} ** 8,
    timeline_count: u8 = 0,

    combat_log: [160]u8 = [_]u8{0} ** 160,
    log_len: usize = 0,

    last_hit: struct {
        damage: i32 = 0,
        heal: i32 = 0,
        positional: PositionalHit = .frontal,
        is_crit: bool = false,
        msg: [48]u8 = [_]u8{0} ** 48,
        msg_len: usize = 0,
        target_col: i32 = 0,
        target_row: i32 = 0,
        active: bool = false,
    } = .{},

    pub fn init() ArenaState {
        return ArenaState{};
    }

    pub fn setCombatLog(self: *ArenaState, text: []const u8) void {
        const len = @min(text.len, self.combat_log.len);
        @memcpy(self.combat_log[0..len], text[0..len]);
        self.log_len = len;
    }

    pub fn getCombatLog(self: *const ArenaState) []const u8 {
        return self.combat_log[0..self.log_len];
    }

    pub fn addUnit(self: *ArenaState, unit: ArenaUnit) ?u8 {
        for (&self.units, 0..) |*slot, i| {
            if (slot.* == null) {
                var u = unit;
                u.id = @as(u8, @intCast(i));
                slot.* = u;
                self.unit_count += 1;
                self.rebuildTimeline();
                return @as(u8, @intCast(i));
            }
        }
        return null;
    }

    pub fn getUnit(self: *ArenaState, idx: u8) ?*ArenaUnit {
        if (idx >= 8) return null;
        if (self.units[idx]) |*u| {
            if (u.alive) return u;
        }
        return null;
    }

    pub fn getUnitConst(self: *const ArenaState, idx: u8) ?*const ArenaUnit {
        if (idx >= 8) return null;
        if (self.units[idx]) |*u| {
            if (u.alive) return u;
        }
        return null;
    }

    pub fn getUnitAt(self: *const ArenaState, col: i32, row: i32) ?u8 {
        for (self.units, 0..) |slot, i| {
            if (slot) |u| {
                if (u.alive and u.col == col and u.row == row) {
                    return @as(u8, @intCast(i));
                }
            }
        }
        return null;
    }

    /// Tái tạo thứ tự xuất chiêu trên Timeline dựa theo chỉ số Thân pháp (Speed)
    pub fn rebuildTimeline(self: *ArenaState) void {
        var count: u8 = 0;
        for (self.units, 0..) |slot, i| {
            if (slot) |u| {
                if (u.alive) {
                    self.timeline[count] = @as(u8, @intCast(i));
                    count += 1;
                }
            }
        }
        self.timeline_count = count;

        // Sắp xếp đơn vị theo speed giảm dần
        if (count > 1) {
            var i: usize = 0;
            while (i < count - 1) : (i += 1) {
                var j: usize = i + 1;
                while (j < count) : (j += 1) {
                    const idx_a = self.timeline[i];
                    const idx_b = self.timeline[j];
                    const speed_a = if (self.units[idx_a]) |u| u.speed else 0;
                    const speed_b = if (self.units[idx_b]) |u| u.speed else 0;
                    if (speed_b > speed_a) {
                        self.timeline[i] = idx_b;
                        self.timeline[j] = idx_a;
                    }
                }
            }
        }

        if (self.active_unit_idx == null and count > 0) {
            self.active_unit_idx = self.timeline[0];
            self.onTurnStart();
        }
    }

    pub fn onTurnStart(self: *ArenaState) void {
        const act_idx = self.active_unit_idx orelse return;
        const u = self.getUnit(act_idx) orelse return;
        u.has_moved = false;
        u.has_acted = false;
        self.mode = .select_action;
        self.selected_skill_idx = null;

        if (u.is_player_side) {
            self.phase = .player_turn;
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Lượt của {s}! Chọn di chuyển hoặc xuất chiêu.", .{u.getName()}) catch "Lượt phe ta!";
            self.setCombatLog(msg);
        } else {
            self.phase = .enemy_turn;
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "{s} đang quan sát trận địa chuẩn bị ra tay!", .{u.getName()}) catch "Lượt phe địch!";
            self.setCombatLog(msg);
        }
    }

    pub fn nextTurn(self: *ArenaState) void {
        self.checkBattleOutcome();
        if (self.phase == .victory or self.phase == .defeat or self.phase == .tamed) return;

        if (self.timeline_count == 0) {
            self.rebuildTimeline();
            return;
        }

        // Tìm vị trí của active_unit hiện tại trong timeline
        var current_pos: usize = 0;
        if (self.active_unit_idx) |cur| {
            for (0..self.timeline_count) |i| {
                if (self.timeline[i] == cur) {
                    current_pos = i;
                    break;
                }
            }
            current_pos = (current_pos + 1) % self.timeline_count;
        } else {
            current_pos = 0;
        }

        self.active_unit_idx = self.timeline[current_pos];
        self.onTurnStart();
    }

    /// Tính toán ô có thể bước tới (Manhattan distance, không vượt chướng ngại vật)
    pub fn isTileReachable(self: *const ArenaState, unit: *const ArenaUnit, target_col: i32, target_row: i32) bool {
        if (target_col < 0 or target_col >= @as(i32, @intCast(ARENA_COLS))) return false;
        if (target_row < 0 or target_row >= @as(i32, @intCast(ARENA_ROWS))) return false;

        // Nếu ô đã có đơn vị đứng (trừ chính mình)
        if (self.getUnitAt(target_col, target_row)) |occ_id| {
            if (occ_id != unit.id) return false;
        }

        const dist = @abs(target_col - unit.col) + @abs(target_row - unit.row);
        return dist <= @as(u32, @intCast(unit.move_range)) and dist > 0;
    }

    /// Di chuyển đơn vị đến ô mục tiêu và cập nhật hướng nhìn (Facing)
    pub fn moveUnit(self: *ArenaState, unit_idx: u8, target_col: i32, target_row: i32) bool {
        const u = self.getUnit(unit_idx) orelse return false;
        if (u.has_moved) return false;
        if (!self.isTileReachable(u, target_col, target_row)) return false;

        // Cập nhật hướng nhìn theo hướng bước đi
        if (target_col > u.col) {
            u.facing = .right;
        } else if (target_col < u.col) {
            u.facing = .left;
        } else if (target_row > u.row) {
            u.facing = .down;
        } else if (target_row < u.row) {
            u.facing = .up;
        }

        u.col = target_col;
        u.row = target_row;
        u.has_moved = true;
        self.mode = .select_action;
        return true;
    }

    /// Xác định đòn tấn công là Chính diện, Trắc kích (Flank), hay Hậu kích (Back Attack)
    pub fn calcPositionalHit(
        attacker_col: i32,
        attacker_row: i32,
        defender_col: i32,
        defender_row: i32,
        defender_facing: Facing,
    ) PositionalHit {
        _ = attacker_row;
        _ = defender_row;
        return switch (defender_facing) {
            .right => if (attacker_col < defender_col)
                .back // Kẻ tấn công ở bên trái khi mục tiêu nhìn sang phải -> Đánh lén sau lưng!
            else if (attacker_col > defender_col)
                .frontal
            else
                .flank,

            .left => if (attacker_col > defender_col)
                .back // Kẻ tấn công ở bên phải khi mục tiêu nhìn sang trái -> Đánh lén sau lưng!
            else if (attacker_col < defender_col)
                .frontal
            else
                .flank,

            .up => if (attacker_col != defender_col) .flank else .frontal,
            .down => if (attacker_col != defender_col) .flank else .frontal,
        };
    }

    /// Kiểm tra ô mục tiêu có nằm trong tầm thi triển của kỹ năng không
    pub fn isTileInSkillRange(
        unit: *const ArenaUnit,
        skill: *const TacticalSkill,
        target_col: i32,
        target_row: i32,
    ) bool {
        if (target_col < 0 or target_col >= @as(i32, @intCast(ARENA_COLS))) return false;
        if (target_row < 0 or target_row >= @as(i32, @intCast(ARENA_ROWS))) return false;

        const d_col = target_col - unit.col;
        const d_row = target_row - unit.row;
        const manhattan = @abs(d_col) + @abs(d_row);

        switch (skill.shape) {
            .melee_single => {
                return manhattan == 1;
            },
            .line_pierce => {
                // Đâm thẳng theo trục X hoặc Y tối đa range ô
                if (d_col == 0 and d_row != 0) {
                    return @abs(d_row) <= @as(u32, @intCast(skill.range));
                } else if (d_row == 0 and d_col != 0) {
                    return @abs(d_col) <= @as(u32, @intCast(skill.range));
                }
                return false;
            },
            .ranged_single, .ranged_aoe => {
                return manhattan > 0 and manhattan <= @as(u32, @intCast(skill.range));
            },
            .self_shield => {
                return manhattan <= 1;
            },
            .heal_target => {
                return manhattan <= @as(u32, @intCast(skill.range));
            },
            .tame_beast => {
                return manhattan > 0 and manhattan <= @as(u32, @intCast(skill.range));
            },
        }
    }

    /// Thi triển kỹ năng lên tọa độ ô mục tiêu
    pub fn executeSkill(
        self: *ArenaState,
        caster_idx: u8,
        skill_idx: usize,
        target_col: i32,
        target_row: i32,
    ) bool {
        const caster = self.getUnit(caster_idx) orelse return false;
        if (caster.has_acted) return false;
        if (skill_idx >= caster.skill_count) return false;
        const skill = &caster.skills[skill_idx];

        if (!isTileInSkillRange(caster, skill, target_col, target_row)) return false;

        // Cập nhật hướng nhìn của caster về phía mục tiêu
        if (target_col > caster.col) {
            caster.facing = .right;
        } else if (target_col < caster.col) {
            caster.facing = .left;
        }

        switch (skill.shape) {
            .self_shield => {
                // Buff khiên cho bản thân và đồng đội lân cận
                caster.shield += skill.shield_power;
                for (self.units) |slot| {
                    if (slot) |u| {
                        if (u.alive and u.is_player_side == caster.is_player_side) {
                            const dist = @abs(u.col - caster.col) + @abs(u.row - caster.row);
                            if (dist == 1) {
                                if (self.getUnit(u.id)) |ally| {
                                    ally.shield += skill.shield_power;
                                }
                            }
                        }
                    }
                }
                caster.has_acted = true;
                self.last_hit.active = true;
                self.last_hit.damage = 0;
                self.last_hit.heal = skill.shield_power;
                self.last_hit.positional = .frontal;
                self.last_hit.target_col = target_col;
                self.last_hit.target_row = target_row;
                self.setCombatLog("Kích hoạt Hộ Thể Thuẫn! Hộ giáp gia tăng vững như bàn thạch.");
                return true;
            },

            .heal_target => {
                const target_id = self.getUnitAt(target_col, target_row) orelse return false;
                const target = self.getUnit(target_id) orelse return false;
                if (target.is_player_side != caster.is_player_side) return false;

                target.hp = @min(target.max_hp, target.hp + skill.heal_power);
                caster.has_acted = true;
                self.last_hit.active = true;
                self.last_hit.damage = 0;
                self.last_hit.heal = skill.heal_power;
                self.last_hit.positional = .frontal;
                self.last_hit.target_col = target_col;
                self.last_hit.target_row = target_row;

                var buf: [64]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "Hồi Xuân Thuật hồi phục +{} HP cho {s}!", .{ skill.heal_power, target.getName() }) catch "Hồi phục HP!";
                self.setCombatLog(msg);
                return true;
            },

            .melee_single, .line_pierce, .ranged_single, .ranged_aoe => {
                const target_id = self.getUnitAt(target_col, target_row) orelse return false;
                const target = self.getUnit(target_id) orelse return false;
                if (target.is_player_side == caster.is_player_side) return false;

                // Tính toán đòn đánh vị trí: Hậu kích / Trắc kích / Chính diện
                const pos_hit = calcPositionalHit(caster.col, caster.row, target.col, target.row, target.facing);
                const pos_mult = pos_hit.damageMultiplier();

                // Tính hệ số Ngũ Hành
                const elem_mult = caster.element.multiplierAgainst(target.element);

                // Tính sát thương
                const raw_dmg = (@as(f32, @floatFromInt(caster.atk + skill.base_damage)) * elem_mult * pos_mult) - @as(f32, @floatFromInt(target.def));
                var dmg: i32 = @max(@as(i32, 10), @as(i32, @intFromFloat(raw_dmg)));

                // Giảm trừ qua khiên trước
                if (target.shield > 0) {
                    if (target.shield >= dmg) {
                        target.shield -= dmg;
                        dmg = 0;
                    } else {
                        dmg -= target.shield;
                        target.shield = 0;
                    }
                }

                target.hp -= dmg;
                if (target.hp <= 0) {
                    target.hp = 0;
                    target.alive = false;
                }

                caster.has_acted = true;
                self.last_hit.active = true;
                self.last_hit.damage = dmg;
                self.last_hit.heal = 0;
                self.last_hit.positional = pos_hit;
                self.last_hit.target_col = target_col;
                self.last_hit.target_row = target_row;

                var buf: [96]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "{s} dùng {s}! [{s}] Gây {} ST lên {s}.", .{
                    caster.getName(),
                    skill.getName(),
                    pos_hit.label(),
                    dmg,
                    target.getName(),
                }) catch "Tấn công mục tiêu!";
                self.setCombatLog(msg);

                // Nếu là AoE, gây sát thương lan 50% cho các ô xung quanh
                if (skill.shape == .ranged_aoe) {
                    const splash_cols = [_]i32{ target_col - 1, target_col + 1, target_col, target_col };
                    const splash_rows = [_]i32{ target_row, target_row, target_row - 1, target_row + 1 };
                    for (0..4) |s_idx| {
                        if (self.getUnitAt(splash_cols[s_idx], splash_rows[s_idx])) |sp_id| {
                            if (self.getUnit(sp_id)) |sp_unit| {
                                if (sp_unit.is_player_side != caster.is_player_side and sp_unit.alive) {
                                    const sp_dmg = @max(5, @divTrunc(dmg, 2));
                                    sp_unit.hp = @max(0, sp_unit.hp - sp_dmg);
                                    if (sp_unit.hp == 0) sp_unit.alive = false;
                                }
                            }
                        }
                    }
                }

                return true;
            },

            .tame_beast => {
                const target_id = self.getUnitAt(target_col, target_row) orelse return false;
                const target = self.getUnit(target_id) orelse return false;
                if (target.is_player_side or !target.alive) return false;

                // Chỉ bắt được khi máu đỏ (<= 15%)
                const is_red = @divTrunc(target.hp * 100, target.max_hp) <= 20;
                if (is_red) {
                    self.phase = .tamed;
                    caster.has_acted = true;
                    self.setCombatLog("Tung Ngự Thú Lệnh thành công! Đã thu phục Yêu thú vào Khế Ước!");
                    return true;
                } else {
                    caster.has_acted = true;
                    self.setCombatLog("Yêu thú khí huyết còn dồi dào, Ngự Thú Lệnh bị đánh bật!");
                    return false;
                }
            },
        }
    }

    /// Trí tuệ nhân tạo (AI) cho quái hoang dã tự động di chuyển và xuất chiêu
    pub fn stepEnemyAI(self: *ArenaState, enemy_idx: u8) void {
        const enemy = self.getUnit(enemy_idx) orelse return;
        if (enemy.is_player_side or !enemy.alive) return;

        // 1. Tìm đồng đội phe ta còn sống gần nhất
        var nearest_player: ?u8 = null;
        var min_dist: i32 = 999;
        for (self.units) |slot| {
            if (slot) |p| {
                if (p.alive and p.is_player_side) {
                    const dist = @abs(p.col - enemy.col) + @abs(p.row - enemy.row);
                    if (dist < min_dist) {
                        min_dist = @as(i32, @intCast(dist));
                        nearest_player = p.id;
                    }
                }
            }
        }

        const target_id = nearest_player orelse {
            self.nextTurn();
            return;
        };
        const target = self.getUnit(target_id) orelse return;

        // 2. Nếu chưa đứng cạnh mục tiêu và chưa di chuyển, bước tới ô gần mục tiêu nhất
        if (min_dist > 1 and !enemy.has_moved) {
            var best_col = enemy.col;
            var best_row = enemy.row;
            var best_step_dist = min_dist;

            var r: i32 = 0;
            while (r < @as(i32, @intCast(ARENA_ROWS))) : (r += 1) {
                var c: i32 = 0;
                while (c < @as(i32, @intCast(ARENA_COLS))) : (c += 1) {
                    if (self.isTileReachable(enemy, c, r)) {
                        const d = @as(i32, @intCast(@abs(c - target.col) + @abs(r - target.row)));
                        if (d < best_step_dist) {
                            best_step_dist = d;
                            best_col = c;
                            best_row = r;
                        }
                    }
                }
            }

            if (best_col != enemy.col or best_row != enemy.row) {
                _ = self.moveUnit(enemy_idx, best_col, best_row);
            }
        }

        // 3. Tấn công nếu trong tầm chiêu thức
        if (enemy.skill_count > 0 and !enemy.has_acted) {
            const skill = &enemy.skills[0];
            if (isTileInSkillRange(enemy, skill, target.col, target.row)) {
                _ = self.executeSkill(enemy_idx, 0, target.col, target.row);
            }
        }

        enemy.has_acted = true;
        self.checkBattleOutcome();
    }

    pub fn checkBattleOutcome(self: *ArenaState) void {
        var player_alive_count: u8 = 0;
        var enemy_alive_count: u8 = 0;

        for (self.units) |slot| {
            if (slot) |u| {
                if (u.alive) {
                    if (u.is_player_side) {
                        player_alive_count += 1;
                    } else {
                        enemy_alive_count += 1;
                    }
                }
            }
        }

        if (enemy_alive_count == 0) {
            self.phase = .victory;
            self.setCombatLog("Chiến Thắng! Toàn bộ yêu thú đã bị tiêu diệt.");
        } else if (player_alive_count == 0) {
            self.phase = .defeat;
            self.setCombatLog("Thất bại! Đội hình ngự thú đã cạn kiệt chân khí.");
        }
    }
};

// ==========================================
// UNIT TESTS
// ==========================================

test "arena: positional hit calculation (Back and Flank attack)" {
    // Defender at (4, 2) facing RIGHT
    const back_hit = ArenaState.calcPositionalHit(2, 2, 4, 2, .right);
    try std.testing.expectEqual(PositionalHit.back, back_hit);
    try std.testing.expectEqual(@as(f32, 1.50), back_hit.damageMultiplier());

    const frontal_hit = ArenaState.calcPositionalHit(5, 2, 4, 2, .right);
    try std.testing.expectEqual(PositionalHit.frontal, frontal_hit);

    const flank_hit = ArenaState.calcPositionalHit(4, 3, 4, 2, .right);
    try std.testing.expectEqual(PositionalHit.flank, flank_hit);
    try std.testing.expectEqual(@as(f32, 1.25), flank_hit.damageMultiplier());

    // Defender at (4, 2) facing LEFT
    const back_left = ArenaState.calcPositionalHit(6, 2, 4, 2, .left);
    try std.testing.expectEqual(PositionalHit.back, back_left);
}

test "arena: reachability and movement on 8x5 grid" {
    var state = ArenaState.init();
    var unit = ArenaUnit{
        .col = 2,
        .row = 2,
        .move_range = 2,
        .speed = 40,
    };
    unit.setName("Tiểu Phàm");
    const u_id = state.addUnit(unit).?;

    // (3, 2) is 1 tile away -> reachable
    try std.testing.expect(state.isTileReachable(&state.units[u_id].?, 3, 2));
    // (4, 2) is 2 tiles away -> reachable
    try std.testing.expect(state.isTileReachable(&state.units[u_id].?, 4, 2));
    // (5, 2) is 3 tiles away -> NOT reachable
    try std.testing.expect(!state.isTileReachable(&state.units[u_id].?, 5, 2));

    // Move to (3, 2)
    const moved = state.moveUnit(u_id, 3, 2);
    try std.testing.expect(moved);
    try std.testing.expectEqual(@as(i32, 3), state.units[u_id].?.col);
    try std.testing.expectEqual(Facing.right, state.units[u_id].?.facing);
}

test "arena: timeline ordering by speed" {
    var state = ArenaState.init();

    var slow_unit = ArenaUnit{ .speed = 30 };
    slow_unit.setName("Quy Giáp");
    _ = state.addUnit(slow_unit);

    var fast_unit = ArenaUnit{ .speed = 70 };
    fast_unit.setName("Linh Điểu");
    _ = state.addUnit(fast_unit);

    var mid_unit = ArenaUnit{ .speed = 50 };
    mid_unit.setName("Hỏa Hồ");
    _ = state.addUnit(mid_unit);

    try std.testing.expectEqual(@as(u8, 3), state.timeline_count);
    // Fast unit (speed 70) should be first on timeline
    const first_unit = state.getUnit(state.timeline[0]).?;
    try std.testing.expectEqualStrings("Linh Điểu", first_unit.getName());
}
