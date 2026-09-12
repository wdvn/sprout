const std = @import("std");

/// Ngũ Hành và Lưỡng Nghi (Elemental Affinities)
pub const Element = enum(u8) {
    jin = 0,  // Kim (Metal / Gold)
    mu = 1,   // Mộc (Wood / Nature)
    shui = 2, // Thủy (Water)
    huo = 3,  // Hỏa (Fire)
    tu = 4,   // Thổ (Earth)
    yin = 5,  // Âm (Dark / Shadow)
    yang = 6, // Dương (Light / Holy)

    pub fn name(self: Element) []const u8 {
        return switch (self) {
            .jin => "Kim",
            .mu => "Mộc",
            .shui => "Thủy",
            .huo => "Hỏa",
            .tu => "Thổ",
            .yin => "Âm",
            .yang => "Dương",
        };
    }

    /// Trả về màu sắc đại diện RGBA [0..1]
    pub fn color(self: Element) [4]f32 {
        return switch (self) {
            .jin => .{ 0.95, 0.85, 0.35, 1.0 },  // Ánh kim vàng
            .mu => .{ 0.25, 0.80, 0.40, 1.0 },   // Xanh mộc lục
            .shui => .{ 0.25, 0.60, 0.95, 1.0 }, // Xanh lam thủy
            .huo => .{ 0.95, 0.35, 0.20, 1.0 },  // Đỏ rực hỏa
            .tu => .{ 0.75, 0.55, 0.30, 1.0 },   // Nâu hoàng thổ
            .yin => .{ 0.60, 0.30, 0.80, 1.0 },  // Tím u minh
            .yang => .{ 0.98, 0.98, 0.90, 1.0 }, // Trắng quang minh
        };
    }

    /// Tính toán hệ số sát thương dựa trên tương khắc Ngũ Hành & Lưỡng Nghi
    pub fn multiplierAgainst(self: Element, defender: Element) f32 {
        if (self == .yin and defender == .yang) return 2.0;
        if (self == .yang and defender == .yin) return 2.0;

        // Tương khắc: Kim -> Mộc -> Thổ -> Thủy -> Hỏa -> Kim
        const counters = switch (self) {
            .jin => defender == .mu,
            .mu => defender == .tu,
            .tu => defender == .shui,
            .shui => defender == .huo,
            .huo => defender == .jin,
            else => false,
        };
        if (counters) return 1.5;

        // Bị khắc chế: sát thương bị giảm
        const countered_by = switch (defender) {
            .jin => self == .mu,
            .mu => self == .tu,
            .tu => self == .shui,
            .shui => self == .huo,
            .huo => self == .jin,
            else => false,
        };
        if (countered_by) return 0.75;

        return 1.0;
    }
};

/// Phẩm chất & Huyết mạch Linh Thú (Rarity Tiers)
pub const Rarity = enum(u8) {
    mortal = 0,    // Hạ Phẩm (Phàm Thú)
    monster = 1,   // Trung Phẩm (Yêu Thú)
    rare = 2,      // Thượng Phẩm (Dị Chủng)
    legendary = 3, // Cực Phẩm (Thần Thú Thượng Cổ: Thanh Long, Bạch Hổ...)

    pub fn name(self: Rarity) []const u8 {
        return switch (self) {
            .mortal => "Hạ Phẩm (Phàm Thú)",
            .monster => "Trung Phẩm (Yêu Thú)",
            .rare => "Thượng Phẩm (Dị Chủng)",
            .legendary => "Cực Phẩm (Thần Thú)",
        };
    }

    pub fn color(self: Rarity) [4]f32 {
        return switch (self) {
            .mortal => .{ 0.65, 0.65, 0.65, 1.0 },    // Xám trắng
            .monster => .{ 0.20, 0.75, 0.85, 1.0 },   // Lục lam
            .rare => .{ 0.80, 0.35, 0.90, 1.0 },      // Tím dị chủng
            .legendary => .{ 1.0, 0.75, 0.15, 1.0 },  // Hoàng kim thần thú
        };
    }

    pub fn maxSkills(self: Rarity) u8 {
        return switch (self) {
            .mortal => 2,
            .monster => 3,
            .rare => 4,
            .legendary => 5,
        };
    }
};

/// Cảnh giới Tu Tiên của Tu Sĩ (Cultivation Realms)
pub const Realm = enum(u8) {
    qi_refining = 0,    // Luyện Khí
    foundation = 1,      // Trúc Cơ
    golden_core = 2,     // Kim Đan
    nascent_soul = 3,    // Nguyên Anh
    spirit_severing = 4, // Hóa Thần

    pub fn name(self: Realm) []const u8 {
        return switch (self) {
            .qi_refining => "Luyện Khí Kỳ",
            .foundation => "Trúc Cơ Kỳ",
            .golden_core => "Kim Đan Kỳ",
            .nascent_soul => "Nguyên Anh Kỳ",
            .spirit_severing => "Hóa Thần Kỳ",
        };
    }

    pub fn requiredExp(self: Realm) u32 {
        return switch (self) {
            .qi_refining => 100,
            .foundation => 300,
            .golden_core => 800,
            .nascent_soul => 2000,
            .spirit_severing => 5000,
        };
    }
};

/// Pháp Thuật Chủ Nhân (Master Skills)
pub const MasterSkill = enum(u8) {
    shield_array,    // Hộ Thân Trận (-40% sát thương)
    frenzy_talisman, // Cuồng Bạo Phù (+50% Thân Pháp & Công)
    purify_mantra,   // Thanh Tâm Chú (Giải khống chế)
    taming_art,      // Thu Phục Thuật (Tăng tỷ lệ bắt thú máu đỏ)

    pub fn name(self: MasterSkill) []const u8 {
        return switch (self) {
            .shield_array => "Hộ Thân Trận",
            .frenzy_talisman => "Cuồng Bạo Phù",
            .purify_mantra => "Thanh Tâm Chú",
            .taming_art => "Thu Phục Thuật",
        };
    }
};

/// Các loại Ngự Thú Lệnh (Taming Orders / Pokéball Equivalent)
pub const TamingOrderType = enum(u8) {
    mortal, // Hạ Phẩm Ngự Thú Lệnh
    iron,   // Huyền Thiết Ngự Thú Lệnh
    gold,   // Tử Kim Ngự Thú Lệnh
    chaos,  // Hỗn Độn Ngự Thú Lệnh

    pub fn baseCaptureRate(self: TamingOrderType) f32 {
        return switch (self) {
            .mortal => 0.70,
            .iron => 0.45,
            .gold => 0.25,
            .chaos => 0.12,
        };
    }

    pub fn name(self: TamingOrderType) []const u8 {
        return switch (self) {
            .mortal => "Hạ Phẩm Ngự Thú Lệnh",
            .iron => "Huyền Thiết Ngự Thú Lệnh",
            .gold => "Tử Kim Ngự Thú Lệnh",
            .chaos => "Hỗn Độn Ngự Thú Lệnh",
        };
    }
};

test "Elemental combat multiplier" {
    // Hỏa khắc Kim
    try std.testing.expectEqual(@as(f32, 1.5), Element.huo.multiplierAgainst(.jin));
    // Kim bị Hỏa khắc
    try std.testing.expectEqual(@as(f32, 0.75), Element.jin.multiplierAgainst(.huo));
    // Âm Dương khắc nhau x2
    try std.testing.expectEqual(@as(f32, 2.0), Element.yin.multiplierAgainst(.yang));
    try std.testing.expectEqual(@as(f32, 2.0), Element.yang.multiplierAgainst(.yin));
    // Cùng hệ bình thường
    try std.testing.expectEqual(@as(f32, 1.0), Element.huo.multiplierAgainst(.huo));
}
