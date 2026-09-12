const std = @import("std");
const components = @import("components.zig");
const types = @import("types.zig");

pub const DungeonTile = components.DungeonTile;
pub const Element = types.Element;

pub const GRID_COLS: usize = 10;
pub const GRID_ROWS: usize = 8;

pub const Dungeon = struct {
    floor: u32 = 1,
    tiles: [GRID_ROWS][GRID_COLS]DungeonTile = undefined,
    player_col: i32 = 0,
    player_row: i32 = 0,

    pub fn init(floor: u32) Dungeon {
        var d = Dungeon{
            .floor = floor,
            .player_col = 0,
            .player_row = 0,
        };
        d.generateFloor();
        return d;
    }

    pub fn generateFloor(self: *Dungeon) void {
        var prng = std.Random.DefaultPrng.init(self.floor * 1337 + 42);
        const random = prng.random();

        for (0..GRID_ROWS) |r| {
            for (0..GRID_COLS) |c| {
                const elem_int = random.intRangeAtMost(u8, 0, 4); // Ngũ Hành
                const elem: Element = @enumFromInt(elem_int);

                var kind: DungeonTile.Kind = .empty;
                const roll = random.intRangeAtMost(u8, 0, 100);

                if (r == 0 and c == 0) {
                    kind = .empty; // Điểm xuất phát của Tu Sĩ
                } else if (r == GRID_ROWS - 1 and c == GRID_COLS - 1) {
                    kind = .boss; // Ô Boss Thiên Kiếp ở góc đối diện
                } else if (roll < 25) {
                    kind = .herb; // 25% Thảo Dược
                } else if (roll < 55) {
                    kind = .wild_beast; // 30% Yêu thú hoang dã
                } else if (roll < 70) {
                    kind = .event; // 15% Kỳ ngộ
                } else {
                    kind = .empty; // 30% Đường đi
                }

                self.tiles[r][c] = .{
                    .kind = kind,
                    .cleared = (r == 0 and c == 0),
                    .revealed = false,
                    .element = elem,
                };
            }
        }

        // Mở sương mù khu vực xuất phát và hiển thị vị trí Boss Thiên Kiếp
        self.tiles[GRID_ROWS - 1][GRID_COLS - 1].revealed = true;
        self.revealAround(0, 0, 1);
    }

    pub fn revealAround(self: *Dungeon, center_c: i32, center_r: i32, radius: i32) void {
        const min_r = @max(0, center_r - radius);
        const max_r = @min(@as(i32, @intCast(GRID_ROWS - 1)), center_r + radius);
        const min_c = @max(0, center_c - radius);
        const max_c = @min(@as(i32, @intCast(GRID_COLS - 1)), center_c + radius);

        var r = min_r;
        while (r <= max_r) : (r += 1) {
            var c = min_c;
            while (c <= max_c) : (c += 1) {
                self.tiles[@intCast(r)][@intCast(c)].revealed = true;
            }
        }
    }

    pub fn movePlayer(self: *Dungeon, new_col: i32, new_row: i32) ?DungeonTile.Kind {
        if (new_col < 0 or new_col >= @as(i32, @intCast(GRID_COLS))) return null;
        if (new_row < 0 or new_row >= @as(i32, @intCast(GRID_ROWS))) return null;

        self.player_col = new_col;
        self.player_row = new_row;

        self.revealAround(new_col, new_row, 1);

        const tile = &self.tiles[@intCast(new_row)][@intCast(new_col)];
        const kind = tile.kind;
        tile.cleared = true;
        return kind;
    }
};

test "Dungeon generation" {
    const dung = Dungeon.init(1);
    try std.testing.expectEqual(DungeonTile.Kind.empty, dung.tiles[0][0].kind);
    try std.testing.expectEqual(DungeonTile.Kind.boss, dung.tiles[GRID_ROWS - 1][GRID_COLS - 1].kind);
}
