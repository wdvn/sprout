const std = @import("std");
const types = @import("types.zig");
const components = @import("components.zig");

pub const Beast = components.Beast;
pub const Element = types.Element;
pub const Rarity = types.Rarity;

pub const Preset = enum {
    bich_thuy_quy,   // Bích Thủy Quy (Thủy - Tiền phong)
    hoa_diem_ho,     // Hỏa Diễm Hồ (Hỏa - Trung quân)
    linh_moc_dieu,   // Linh Mộc Điểu (Mộc - Hậu vệ)
    kim_giap_ho,     // Kim Giáp Hổ (Kim - Dự bị 1)
    u_minh_xa,       // U Minh Xà (Âm - Dự bị 2)
    xich_hoa_lang,   // Xích Hỏa Lang (Hỏa - Hoang dã)
    hoang_tho_hung,  // Hoàng Thổ Hùng (Thổ - Hoang dã)
    loi_dien_dieu,   // Lôi Điện Điêu (Kim/Lôi - Hoang dã)
    thanh_long,      // Thanh Long Thượng Cổ (Mộc/Dương - Boss Thiên Kiếp)
};

pub fn createBeast(preset: Preset, is_wild: bool) Beast {
    var b = Beast{
        .is_wild = is_wild,
    };
    switch (preset) {
        .bich_thuy_quy => {
            b.setName("Bích Thủy Quy");
            b.element = .shui;
            b.rarity = .monster;
            b.hp = 180;
            b.max_hp = 180;
            b.mana = 40;
            b.max_mana = 40;
            b.atk = 22;
            b.def = 28;
            b.speed = 35;
        },
        .hoa_diem_ho => {
            b.setName("Hỏa Diễm Hồ");
            b.element = .huo;
            b.rarity = .monster;
            b.hp = 110;
            b.max_hp = 110;
            b.mana = 80;
            b.max_mana = 80;
            b.atk = 38;
            b.def = 14;
            b.speed = 58;
        },
        .linh_moc_dieu => {
            b.setName("Linh Mộc Điểu");
            b.element = .mu;
            b.rarity = .monster;
            b.hp = 95;
            b.max_hp = 95;
            b.mana = 100;
            b.max_mana = 100;
            b.atk = 24;
            b.def = 16;
            b.speed = 65;
        },
        .kim_giap_ho => {
            b.setName("Kim Giáp Hổ");
            b.element = .jin;
            b.rarity = .rare;
            b.hp = 150;
            b.max_hp = 150;
            b.mana = 50;
            b.max_mana = 50;
            b.atk = 34;
            b.def = 22;
            b.speed = 48;
        },
        .u_minh_xa => {
            b.setName("U Minh Xà");
            b.element = .yin;
            b.rarity = .rare;
            b.hp = 105;
            b.max_hp = 105;
            b.mana = 70;
            b.max_mana = 70;
            b.atk = 36;
            b.def = 15;
            b.speed = 62;
        },
        .xich_hoa_lang => {
            b.setName("Xích Hỏa Lang");
            b.element = .huo;
            b.rarity = .mortal;
            b.hp = 70;
            b.max_hp = 70;
            b.mana = 30;
            b.max_mana = 30;
            b.atk = 20;
            b.def = 8;
            b.speed = 45;
        },
        .hoang_tho_hung => {
            b.setName("Hoàng Thổ Hùng");
            b.element = .tu;
            b.rarity = .monster;
            b.hp = 120;
            b.max_hp = 120;
            b.mana = 30;
            b.max_mana = 30;
            b.atk = 25;
            b.def = 20;
            b.speed = 30;
        },
        .loi_dien_dieu => {
            b.setName("Lôi Điện Điêu");
            b.element = .jin;
            b.rarity = .rare;
            b.hp = 90;
            b.max_hp = 90;
            b.mana = 60;
            b.max_mana = 60;
            b.atk = 32;
            b.def = 12;
            b.speed = 70;
        },
        .thanh_long => {
            b.setName("Thanh Long Cổ Thần");
            b.element = .yang;
            b.rarity = .legendary;
            b.hp = 300;
            b.max_hp = 300;
            b.mana = 200;
            b.max_mana = 200;
            b.atk = 55;
            b.def = 35;
            b.speed = 75;
        },
    }
    return b;
}
