const std = @import("std");
const types = @import("types.zig");
pub const Element = types.Element;
pub const Rarity = types.Rarity;
pub const Realm = types.Realm;
pub const MasterSkill = types.MasterSkill;
pub const TamingOrderType = types.TamingOrderType;

/// Vị trí trên bản đồ lưới 8x10
pub const GridPos = struct {
    col: i32,
    row: i32,
};

/// Dữ liệu tọa độ màn hình và kích thước cho WebGL render
pub const Transform = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

/// Thuộc tính đồ họa
pub const Renderable = struct {
    color: [4]f32,
    border_color: [4]f32,
};

/// Nhân vật Chủ Nhân (Ngự Thú Sư)
pub const CultivatorMaster = struct {
    name: [24]u8 = [_]u8{0} ** 24,
    name_len: usize = 0,
    realm: Realm = .qi_refining,
    exp: u32 = 0,
    exp_to_breakthrough: u32 = 100,
    herbs: u32 = 0,          // Thảo dược thu hái trong Bí Cảnh
    pills: u32 = 2,          // Đan dược đột phá / hồi phục
    taming_orders: u32 = 5,  // Ngự Thú Lệnh
    master_skill: MasterSkill = .taming_art,
    skill_cooldown: u8 = 0,

    pub fn canBreakthrough(self: *const CultivatorMaster) bool {
        return self.exp >= self.exp_to_breakthrough and self.pills >= 1;
    }

    pub fn breakthrough(self: *CultivatorMaster) bool {
        if (!self.canBreakthrough()) return false;
        const current_realm_int = @intFromEnum(self.realm);
        if (current_realm_int < 4) {
            self.realm = @enumFromInt(current_realm_int + 1);
            self.exp -= self.exp_to_breakthrough;
            self.exp_to_breakthrough = self.realm.requiredExp();
            self.pills -= 1;
            return true;
        }
        return false;
    }
};

/// Linh Thú (Chiến thú trong đội hình hoặc Yêu thú hoang dã)
pub const Beast = struct {
    name: [24]u8 = [_]u8{0} ** 24,
    name_len: usize = 0,
    element: Element = .huo,
    rarity: Rarity = .mortal,
    hp: i32 = 100,
    max_hp: i32 = 100,
    mana: i32 = 50,
    max_mana: i32 = 50,
    atk: i32 = 25,
    def: i32 = 10,
    speed: i32 = 50,          // Thân pháp
    action_gauge: i32 = 0,     // Điểm tích lũy hành động (ngưỡng 1000)
    is_wild: bool = false,     // Quái hoang dã hay Linh thú đã thuần phục
    is_caught: bool = false,
    slot_idx: ?u8 = null,      // 0: Tiền phong, 1: Trung quân, 2: Hậu vệ, 3: Dự bị 1, 4: Dự bị 2

    pub fn isDeployed(self: *const Beast) bool {
        if (self.slot_idx) |s| {
            return s < 3;
        }
        return false;
    }

    pub fn getName(self: *const Beast) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn setName(self: *Beast, slice: []const u8) void {
        const len = @min(slice.len, self.name.len);
        @memcpy(self.name[0..len], slice[0..len]);
        self.name_len = len;
    }

    /// Kiểm tra quái đã rơi vào trạng thái Máu Đỏ (HP <= 15%) chưa
    pub fn isRedHp(self: *const Beast) bool {
        if (self.hp <= 0 or self.max_hp <= 0) return false;
        return @divTrunc(self.hp * 100, self.max_hp) <= 15;
    }

    /// Tính toán sát thương gây ra cho mục tiêu có xét Ngũ Hành
    pub fn calcDamageAgainst(self: *const Beast, target: *const Beast) i32 {
        const mult = self.element.multiplierAgainst(target.element);
        const def_reduction = @as(f32, @floatFromInt(@divTrunc(target.def * 2, 3)));
        const raw_damage = @as(f32, @floatFromInt(self.atk)) * mult - def_reduction;
        const final_dmg = @max(5, @as(i32, @intFromFloat(raw_damage)));
        return final_dmg;
    }
};

/// Vị trí trong Trận Pháp 3+2
pub const FormationSlot = enum(u8) {
    frontline = 0, // Tiền phong (Chống chịu)
    midline = 1,   // Trung quân (Sát thương chủ lực)
    backline = 2,  // Hậu vệ (Hỗ trợ / Trị liệu)
    reserve1 = 3,  // Dự bị 1
    reserve2 = 4,  // Dự bị 2

    pub fn name(self: FormationSlot) []const u8 {
        return switch (self) {
            .frontline => "Tiền Phong (Tank)",
            .midline => "Trung Quân (DPS)",
            .backline => "Hậu Vệ (Hỗ Trợ)",
            .reserve1 => "Dự Bị 1",
            .reserve2 => "Dự Bị 2",
        };
    }
};

/// Ô trên Bản đồ Bí Cảnh 8x10 Roguelite
pub const DungeonTile = struct {
    pub const Kind = enum(u8) {
        empty = 0,      // Đường đi an toàn
        herb = 1,       // Thu hái Linh Thảo
        wild_beast = 2, // Yêu thú hoang dã
        event = 3,      // Kỳ ngộ
        boss = 4,       // Thủ lĩnh Thiên Kiếp
    };

    kind: Kind = .empty,
    cleared: bool = false,
    revealed: bool = false, // Sương mù che phủ (Fog of War)
    element: Element = .tu, // Hệ nguyên tố chi phối ô này
};
