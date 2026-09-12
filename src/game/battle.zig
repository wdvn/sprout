const std = @import("std");
const types = @import("types.zig");
const components = @import("components.zig");

pub const Beast = components.Beast;
pub const CultivatorMaster = components.CultivatorMaster;
pub const TamingOrderType = types.TamingOrderType;

pub const BattleResult = enum {
    ongoing,
    player_victory,
    player_defeat,
    beast_tamed,
};

/// Tính xác suất bắt thành công quái hoang dã
pub fn calcTamingChance(
    master: *const CultivatorMaster,
    target: *const Beast,
    order: TamingOrderType,
) f32 {
    if (!target.is_wild or target.hp <= 0) return 0.0;

    const base_rate = order.baseCaptureRate();
    const hp_ratio = @as(f32, @floatFromInt(target.hp)) / @as(f32, @floatFromInt(target.max_hp));

    // Thưởng khi máu càng thấp (máu đỏ < 15%)
    const hp_factor: f32 = if (hp_ratio <= 0.15)
        1.8 - hp_ratio * 4.0
    else if (hp_ratio <= 0.30)
        1.0
    else
        0.3;

    // Chênh lệch cảnh giới tu sĩ so với phẩm chất thú
    const realm_val = @as(f32, @floatFromInt(@intFromEnum(master.realm)));
    const rarity_val = @as(f32, @floatFromInt(@intFromEnum(target.rarity)));
    const realm_bonus = 1.0 + (realm_val - rarity_val) * 0.15;

    // Kỹ năng Thu Phục Thuật của Tu Sĩ
    const skill_bonus: f32 = if (master.master_skill == .taming_art) 0.25 else 0.0;

    var chance = (base_rate * realm_bonus * hp_factor) + skill_bonus;
    chance = std.math.clamp(chance, 0.05, 0.95);
    return chance;
}

/// Thực hiện ném Ngự Thú Lệnh bắt thú
pub fn tryTame(
    master: *CultivatorMaster,
    target: *Beast,
    order: TamingOrderType,
    rand_val: f32,
) bool {
    if (master.taming_orders == 0) return false;
    master.taming_orders -= 1;

    const chance = calcTamingChance(master, target, order);
    if (rand_val <= chance) {
        target.is_caught = true;
        target.is_wild = false;
        return true;
    }
    return false;
}

test "Taming calculation" {
    var master = CultivatorMaster{
        .realm = .foundation,
        .master_skill = .taming_art,
    };
    var beast = Beast{
        .is_wild = true,
        .hp = 10,
        .max_hp = 100, // 10% HP -> Máu đỏ!
        .rarity = .monster,
    };

    const chance = calcTamingChance(&master, &beast, .mortal);
    try std.testing.expect(chance > 0.5); // Tỷ lệ bắt thú máu đỏ phải rất cao
}
