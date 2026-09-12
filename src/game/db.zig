const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});
const libs = @import("libs");
const ecs = libs.ecs;
const types = @import("types.zig");
const components = @import("components.zig");
const dungeon_mod = @import("dungeon.zig");

const CultivatorMaster = components.CultivatorMaster;
const Beast = components.Beast;
const Dungeon = dungeon_mod.Dungeon;
const DungeonTile = components.DungeonTile;
const Element = types.Element;
const Rarity = types.Rarity;
const Realm = types.Realm;
const MasterSkill = types.MasterSkill;

var db_handle: ?*c.sqlite3 = null;

pub fn initDb(path: [:0]const u8) !void {
    if (db_handle != null) return;

    var handle: ?*c.sqlite3 = null;
    const rc = c.sqlite3_open(path.ptr, &handle);
    if (rc != c.SQLITE_OK) {
        std.debug.print(">> [SQLite Error]: Khong the mo database {s} (code={})\n", .{ path, rc });
        if (handle) |h| _ = c.sqlite3_close(h);
        return error.SqliteOpenFailed;
    }
    db_handle = handle;

    // Enable WAL mode & foreign keys
    _ = c.sqlite3_exec(db_handle, "PRAGMA journal_mode=WAL;", null, null, null);
    _ = c.sqlite3_exec(db_handle, "PRAGMA foreign_keys=ON;", null, null, null);

    // Create DDL Schema
    const schema_sql =
        \\CREATE TABLE IF NOT EXISTS entities (
        \\    id INTEGER PRIMARY KEY,
        \\    generation INTEGER NOT NULL
        \\);
        \\
        \\CREATE TABLE IF NOT EXISTS comp_master (
        \\    entity_id INTEGER PRIMARY KEY,
        \\    name TEXT NOT NULL,
        \\    realm INTEGER NOT NULL,
        \\    exp INTEGER NOT NULL,
        \\    exp_to_breakthrough INTEGER NOT NULL,
        \\    herbs INTEGER NOT NULL,
        \\    pills INTEGER NOT NULL,
        \\    taming_orders INTEGER NOT NULL,
        \\    master_skill INTEGER NOT NULL,
        \\    FOREIGN KEY(entity_id) REFERENCES entities(id) ON DELETE CASCADE
        \\);
        \\
        \\CREATE TABLE IF NOT EXISTS comp_beast (
        \\    entity_id INTEGER PRIMARY KEY,
        \\    name TEXT NOT NULL,
        \\    element INTEGER NOT NULL,
        \\    rarity INTEGER NOT NULL,
        \\    hp INTEGER NOT NULL,
        \\    max_hp INTEGER NOT NULL,
        \\    mana INTEGER NOT NULL,
        \\    max_mana INTEGER NOT NULL,
        \\    atk INTEGER NOT NULL,
        \\    def INTEGER NOT NULL,
        \\    speed INTEGER NOT NULL,
        \\    slot_idx INTEGER,
        \\    is_wild INTEGER NOT NULL,
        \\    is_caught INTEGER NOT NULL,
        \\    FOREIGN KEY(entity_id) REFERENCES entities(id) ON DELETE CASCADE
        \\);
        \\
        \\CREATE TABLE IF NOT EXISTS comp_dungeon (
        \\    id INTEGER PRIMARY KEY CHECK(id = 1),
        \\    floor INTEGER NOT NULL,
        \\    player_col INTEGER NOT NULL,
        \\    player_row INTEGER NOT NULL,
        \\    tiles_blob BLOB NOT NULL
        \\);
    ;

    var err_msg: [*c]u8 = null;
    const schema_rc = c.sqlite3_exec(db_handle, schema_sql, null, null, &err_msg);
    if (schema_rc != c.SQLITE_OK) {
        if (err_msg != null) {
            std.debug.print(">> [SQLite Schema Error]: {s}\n", .{err_msg});
            c.sqlite3_free(err_msg);
        }
        return error.SqliteSchemaFailed;
    }
    std.debug.print(">> [SQLite]: Database khoi tao thanh cong tai '{s}'!\n", .{path});
}

pub fn closeDb() void {
    if (db_handle) |h| {
        _ = c.sqlite3_close(h);
        db_handle = null;
        std.debug.print(">> [SQLite]: Da dong ket noi database an toan.\n", .{});
    }
}

pub fn hasSavedData() bool {
    const db = db_handle orelse return false;
    var stmt: ?*c.sqlite3_stmt = null;
    const sql = "SELECT COUNT(*) FROM comp_master;";
    if (c.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != c.SQLITE_OK) return false;
    defer _ = c.sqlite3_finalize(stmt);

    if (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const count = c.sqlite3_column_int(stmt, 0);
        return count > 0;
    }
    return false;
}

pub fn saveMaster(registry: *ecs.Registry, entity: ecs.Entity) !void {
    const db = db_handle orelse return;
    const master = registry.get(entity, CultivatorMaster) orelse return;

    // Save entity
    {
        var e_stmt: ?*c.sqlite3_stmt = null;
        const e_sql = "INSERT OR REPLACE INTO entities (id, generation) VALUES (?, ?);";
        if (c.sqlite3_prepare_v2(db, e_sql, -1, &e_stmt, null) == c.SQLITE_OK) {
            defer _ = c.sqlite3_finalize(e_stmt);
            _ = c.sqlite3_bind_int(e_stmt, 1, @intCast(entity.id));
            _ = c.sqlite3_bind_int(e_stmt, 2, @intCast(entity.generation));
            _ = c.sqlite3_step(e_stmt);
        }
    }

    var stmt: ?*c.sqlite3_stmt = null;
    const sql =
        \\INSERT OR REPLACE INTO comp_master (
        \\    entity_id, name, realm, exp, exp_to_breakthrough, herbs, pills, taming_orders, master_skill
        \\) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    ;
    if (c.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
    defer _ = c.sqlite3_finalize(stmt);

    _ = c.sqlite3_bind_int(stmt, 1, @intCast(entity.id));
    _ = c.sqlite3_bind_text(stmt, 2, master.name[0..master.name_len].ptr, @intCast(master.name_len), c.SQLITE_TRANSIENT);
    _ = c.sqlite3_bind_int(stmt, 3, @intCast(@intFromEnum(master.realm)));
    _ = c.sqlite3_bind_int(stmt, 4, @intCast(master.exp));
    _ = c.sqlite3_bind_int(stmt, 5, @intCast(master.exp_to_breakthrough));
    _ = c.sqlite3_bind_int(stmt, 6, @intCast(master.herbs));
    _ = c.sqlite3_bind_int(stmt, 7, @intCast(master.pills));
    _ = c.sqlite3_bind_int(stmt, 8, @intCast(master.taming_orders));
    _ = c.sqlite3_bind_int(stmt, 9, @intCast(@intFromEnum(master.master_skill)));

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        return error.SqliteStepFailed;
    }
}

pub fn saveBeast(registry: *ecs.Registry, entity: ecs.Entity) !void {
    const db = db_handle orelse return;
    const beast = registry.get(entity, Beast) orelse return;

    // Save entity
    {
        var e_stmt: ?*c.sqlite3_stmt = null;
        const e_sql = "INSERT OR REPLACE INTO entities (id, generation) VALUES (?, ?);";
        if (c.sqlite3_prepare_v2(db, e_sql, -1, &e_stmt, null) == c.SQLITE_OK) {
            defer _ = c.sqlite3_finalize(e_stmt);
            _ = c.sqlite3_bind_int(e_stmt, 1, @intCast(entity.id));
            _ = c.sqlite3_bind_int(e_stmt, 2, @intCast(entity.generation));
            _ = c.sqlite3_step(e_stmt);
        }
    }

    var stmt: ?*c.sqlite3_stmt = null;
    const sql =
        \\INSERT OR REPLACE INTO comp_beast (
        \\    entity_id, name, element, rarity, hp, max_hp, mana, max_mana, atk, def, speed, slot_idx, is_wild, is_caught
        \\) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ;
    if (c.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
    defer _ = c.sqlite3_finalize(stmt);

    _ = c.sqlite3_bind_int(stmt, 1, @intCast(entity.id));
    const name = beast.getName();
    _ = c.sqlite3_bind_text(stmt, 2, name.ptr, @intCast(name.len), c.SQLITE_TRANSIENT);
    _ = c.sqlite3_bind_int(stmt, 3, @intCast(@intFromEnum(beast.element)));
    _ = c.sqlite3_bind_int(stmt, 4, @intCast(@intFromEnum(beast.rarity)));
    _ = c.sqlite3_bind_int(stmt, 5, beast.hp);
    _ = c.sqlite3_bind_int(stmt, 6, beast.max_hp);
    _ = c.sqlite3_bind_int(stmt, 7, beast.mana);
    _ = c.sqlite3_bind_int(stmt, 8, beast.max_mana);
    _ = c.sqlite3_bind_int(stmt, 9, beast.atk);
    _ = c.sqlite3_bind_int(stmt, 10, beast.def);
    _ = c.sqlite3_bind_int(stmt, 11, beast.speed);

    if (beast.slot_idx) |s| {
        _ = c.sqlite3_bind_int(stmt, 12, @intCast(s));
    } else {
        _ = c.sqlite3_bind_null(stmt, 12);
    }

    _ = c.sqlite3_bind_int(stmt, 13, if (beast.is_wild) 1 else 0);
    _ = c.sqlite3_bind_int(stmt, 14, if (beast.is_caught) 1 else 0);

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        return error.SqliteStepFailed;
    }
}

pub fn deleteBeast(ent: ecs.Entity) !void {
    const db = db_handle orelse return;

    var stmt1: ?*c.sqlite3_stmt = null;
    const sql1 = "DELETE FROM comp_beast WHERE entity_id = ?;";
    if (c.sqlite3_prepare_v2(db, sql1, -1, &stmt1, null) == c.SQLITE_OK) {
        defer _ = c.sqlite3_finalize(stmt1);
        _ = c.sqlite3_bind_int64(stmt1, 1, @intCast(ent.id));
        _ = c.sqlite3_step(stmt1);
    }

    var stmt2: ?*c.sqlite3_stmt = null;
    const sql2 = "DELETE FROM entities WHERE id = ?;";
    if (c.sqlite3_prepare_v2(db, sql2, -1, &stmt2, null) == c.SQLITE_OK) {
        defer _ = c.sqlite3_finalize(stmt2);
        _ = c.sqlite3_bind_int64(stmt2, 1, @intCast(ent.id));
        _ = c.sqlite3_step(stmt2);
    }
}

pub fn saveDungeon(dungeon_world: *const Dungeon) !void {
    const db = db_handle orelse return;
    var stmt: ?*c.sqlite3_stmt = null;
    const sql = "INSERT OR REPLACE INTO comp_dungeon (id, floor, player_col, player_row, tiles_blob) VALUES (1, ?, ?, ?, ?);";
    if (c.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
    defer _ = c.sqlite3_finalize(stmt);

    _ = c.sqlite3_bind_int(stmt, 1, @intCast(dungeon_world.floor));
    _ = c.sqlite3_bind_int(stmt, 2, dungeon_world.player_col);
    _ = c.sqlite3_bind_int(stmt, 3, dungeon_world.player_row);

    const blob_ptr: [*]const u8 = @ptrCast(&dungeon_world.tiles);
    const blob_len: c_int = @intCast(@sizeOf(@TypeOf(dungeon_world.tiles)));
    _ = c.sqlite3_bind_blob(stmt, 4, blob_ptr, blob_len, c.SQLITE_TRANSIENT);

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        return error.SqliteStepFailed;
    }
}

pub fn saveAll(
    registry: *ecs.Registry,
    party_entities: *const [5]?ecs.Entity,
    master_entity: ecs.Entity,
    dungeon_world: *const Dungeon,
) !void {
    const db = db_handle orelse return;
    _ = party_entities;
    _ = c.sqlite3_exec(db, "BEGIN TRANSACTION;", null, null, null);

    // Save master
    try saveMaster(registry, master_entity);

    // Save all beasts
    const b_view = registry.view(Beast);
    if (b_view) |pool| {
        for (pool.dense.items) |ent| {
            try saveBeast(registry, ent);
        }
    }

    // Save dungeon
    try saveDungeon(dungeon_world);

    _ = c.sqlite3_exec(db, "COMMIT;", null, null, null);
    std.debug.print(">> [SQLite]: Da luu toan bo EC thanh cong!\n", .{});
}

pub fn loadAll(
    registry: *ecs.Registry,
    party_entities: *[5]?ecs.Entity,
    master_entity: *ecs.Entity,
    dungeon_world: *Dungeon,
) !bool {
    const db = db_handle orelse return false;
    if (!hasSavedData()) return false;

    // 1. Load entities to reconstruct generational state in registry
    {
        var e_stmt: ?*c.sqlite3_stmt = null;
        const e_sql = "SELECT id, generation FROM entities ORDER BY id ASC;";
        if (c.sqlite3_prepare_v2(db, e_sql, -1, &e_stmt, null) == c.SQLITE_OK) {
            defer _ = c.sqlite3_finalize(e_stmt);
            while (c.sqlite3_step(e_stmt) == c.SQLITE_ROW) {
                const id: u32 = @intCast(c.sqlite3_column_int(e_stmt, 0));
                const gen: u32 = @intCast(c.sqlite3_column_int(e_stmt, 1));
                while (registry.generations.items.len <= id) {
                    try registry.generations.append(registry.allocator, 0);
                }
                registry.generations.items[id] = gen;
            }
        }
    }

    // 2. Load Master
    {
        var m_stmt: ?*c.sqlite3_stmt = null;
        const m_sql = "SELECT entity_id, name, realm, exp, exp_to_breakthrough, herbs, pills, taming_orders, master_skill FROM comp_master LIMIT 1;";
        if (c.sqlite3_prepare_v2(db, m_sql, -1, &m_stmt, null) == c.SQLITE_OK) {
            defer _ = c.sqlite3_finalize(m_stmt);
            if (c.sqlite3_step(m_stmt) == c.SQLITE_ROW) {
                const ent_id: u32 = @intCast(c.sqlite3_column_int(m_stmt, 0));
                const gen = if (ent_id < registry.generations.items.len) registry.generations.items[ent_id] else 0;
                const ent = ecs.Entity{ .id = ent_id, .generation = gen };
                master_entity.* = ent;

                var master = CultivatorMaster{};
                const name_ptr = c.sqlite3_column_text(m_stmt, 1);
                const name_len: usize = @intCast(c.sqlite3_column_bytes(m_stmt, 1));
                const copy_len = @min(name_len, master.name.len);
                if (name_ptr != null) {
                    @memcpy(master.name[0..copy_len], name_ptr[0..copy_len]);
                    master.name_len = copy_len;
                }

                master.realm = @enumFromInt(@as(u8, @intCast(c.sqlite3_column_int(m_stmt, 2))));
                master.exp = @intCast(c.sqlite3_column_int(m_stmt, 3));
                master.exp_to_breakthrough = @intCast(c.sqlite3_column_int(m_stmt, 4));
                master.herbs = @intCast(c.sqlite3_column_int(m_stmt, 5));
                master.pills = @intCast(c.sqlite3_column_int(m_stmt, 6));
                master.taming_orders = @intCast(c.sqlite3_column_int(m_stmt, 7));
                master.master_skill = @enumFromInt(@as(u8, @intCast(c.sqlite3_column_int(m_stmt, 8))));

                try registry.add(ent, master);
            }
        }
    }

    // 3. Reset party slots
    for (party_entities) |*p| {
        p.* = null;
    }

    // 4. Load Beasts
    {
        var b_stmt: ?*c.sqlite3_stmt = null;
        const b_sql =
            \\SELECT entity_id, name, element, rarity, hp, max_hp, mana, max_mana, atk, def, speed, slot_idx, is_wild, is_caught
            \\FROM comp_beast ORDER BY entity_id ASC;
        ;
        if (c.sqlite3_prepare_v2(db, b_sql, -1, &b_stmt, null) == c.SQLITE_OK) {
            defer _ = c.sqlite3_finalize(b_stmt);
            while (c.sqlite3_step(b_stmt) == c.SQLITE_ROW) {
                const ent_id: u32 = @intCast(c.sqlite3_column_int(b_stmt, 0));
                const gen = if (ent_id < registry.generations.items.len) registry.generations.items[ent_id] else 0;
                const ent = ecs.Entity{ .id = ent_id, .generation = gen };

                var beast = Beast{};
                const name_ptr = c.sqlite3_column_text(b_stmt, 1);
                const name_len: usize = @intCast(c.sqlite3_column_bytes(b_stmt, 1));
                const copy_len = @min(name_len, beast.name.len);
                if (name_ptr != null) {
                    @memcpy(beast.name[0..copy_len], name_ptr[0..copy_len]);
                    beast.name_len = copy_len;
                }

                beast.element = @enumFromInt(@as(u8, @intCast(c.sqlite3_column_int(b_stmt, 2))));
                beast.rarity = @enumFromInt(@as(u8, @intCast(c.sqlite3_column_int(b_stmt, 3))));
                beast.hp = c.sqlite3_column_int(b_stmt, 4);
                beast.max_hp = c.sqlite3_column_int(b_stmt, 5);
                beast.mana = c.sqlite3_column_int(b_stmt, 6);
                beast.max_mana = c.sqlite3_column_int(b_stmt, 7);
                beast.atk = c.sqlite3_column_int(b_stmt, 8);
                beast.def = c.sqlite3_column_int(b_stmt, 9);
                beast.speed = c.sqlite3_column_int(b_stmt, 10);

                if (c.sqlite3_column_type(b_stmt, 11) != c.SQLITE_NULL) {
                    const slot = c.sqlite3_column_int(b_stmt, 11);
                    if (slot >= 0 and slot < 5) {
                        beast.slot_idx = @intCast(slot);
                        party_entities[@intCast(slot)] = ent;
                    }
                } else {
                    beast.slot_idx = null;
                }

                beast.is_wild = (c.sqlite3_column_int(b_stmt, 12) == 1);
                beast.is_caught = (c.sqlite3_column_int(b_stmt, 13) == 1);

                try registry.add(ent, beast);
            }
        }
    }

    // 5. Load Dungeon
    {
        var d_stmt: ?*c.sqlite3_stmt = null;
        const d_sql = "SELECT floor, player_col, player_row, tiles_blob FROM comp_dungeon WHERE id = 1;";
        if (c.sqlite3_prepare_v2(db, d_sql, -1, &d_stmt, null) == c.SQLITE_OK) {
            defer _ = c.sqlite3_finalize(d_stmt);
            if (c.sqlite3_step(d_stmt) == c.SQLITE_ROW) {
                dungeon_world.floor = @intCast(c.sqlite3_column_int(d_stmt, 0));
                dungeon_world.player_col = c.sqlite3_column_int(d_stmt, 1);
                dungeon_world.player_row = c.sqlite3_column_int(d_stmt, 2);

                const blob_ptr = c.sqlite3_column_blob(d_stmt, 3);
                const blob_bytes = c.sqlite3_column_bytes(d_stmt, 3);
                const expected_len = @sizeOf(@TypeOf(dungeon_world.tiles));
                if (blob_ptr != null and blob_bytes == expected_len) {
                    const src: [*]const u8 = @ptrCast(blob_ptr);
                    const dst: [*]u8 = @ptrCast(&dungeon_world.tiles);
                    @memcpy(dst[0..expected_len], src[0..expected_len]);
                }
            }
        }
    }

    std.debug.print(">> [SQLite]: Nap du lieu thanh cong tu DB!\n", .{});
    return true;
}

test "sqlite save and load ecs entities" {
    const allocator = std.testing.allocator;
    try initDb(":memory:");
    defer closeDb();

    var reg = ecs.Registry.init(allocator);
    defer reg.deinit();

    var party = [_]?ecs.Entity{null} ** 5;
    const master_ent = try reg.create();
    var m = CultivatorMaster{
        .realm = .foundation,
        .exp = 55,
        .herbs = 8,
        .pills = 3,
        .taming_orders = 10,
    };
    const m_name = "BAC PHONG";
    @memcpy(m.name[0..m_name.len], m_name);
    m.name_len = m_name.len;
    try reg.add(master_ent, m);

    // Beast 1: deployed to slot 0
    const b1_ent = try reg.create();
    var b1 = Beast{
        .element = .shui,
        .hp = 120,
        .max_hp = 150,
        .atk = 40,
        .def = 30,
        .slot_idx = 0,
        .is_caught = true,
    };
    b1.setName("BICH THUY QUY");
    try reg.add(b1_ent, b1);
    party[0] = b1_ent;

    // Beast 2: in collection (slot_idx = null)
    const b2_ent = try reg.create();
    var b2 = Beast{
        .element = .jin,
        .hp = 100,
        .max_hp = 100,
        .atk = 50,
        .def = 20,
        .slot_idx = null,
        .is_caught = true,
    };
    b2.setName("KIM GIAP HO");
    try reg.add(b2_ent, b2);

    var d_world = Dungeon.init(2);
    d_world.player_col = 3;
    d_world.player_row = 4;

    try saveAll(&reg, &party, master_ent, &d_world);

    // Now clear registry and reload from SQLite
    reg.clear();
    var loaded_party = [_]?ecs.Entity{null} ** 5;
    var loaded_master: ecs.Entity = .{ .id = 0, .generation = 0 };
    var loaded_dungeon: Dungeon = undefined;

    const ok = try loadAll(&reg, &loaded_party, &loaded_master, &loaded_dungeon);
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u32, 2), loaded_dungeon.floor);
    try std.testing.expectEqual(@as(i32, 3), loaded_dungeon.player_col);
    try std.testing.expectEqual(@as(i32, 4), loaded_dungeon.player_row);

    const loaded_m = reg.get(loaded_master, CultivatorMaster).?;
    try std.testing.expectEqualStrings("BAC PHONG", loaded_m.name[0..loaded_m.name_len]);
    try std.testing.expectEqual(Realm.foundation, loaded_m.realm);
    try std.testing.expectEqual(@as(u32, 8), loaded_m.herbs);

    // Check loaded beasts
    const b1_loaded = reg.get(loaded_party[0].?, Beast).?;
    try std.testing.expectEqualStrings("BICH THUY QUY", b1_loaded.getName());
    try std.testing.expectEqual(@as(?u8, 0), b1_loaded.slot_idx);
    try std.testing.expectEqual(@as(i32, 120), b1_loaded.hp);

    // Check collection beast (slot_idx == null)
    var count: usize = 0;
    const view = reg.view(Beast).?;
    for (view.dense.items) |ent| {
        const beast = reg.get(ent, Beast).?;
        if (std.mem.eql(u8, beast.getName(), "KIM GIAP HO")) {
            count += 1;
            try std.testing.expectEqual(@as(?u8, null), beast.slot_idx);
        }
    }
    try std.testing.expectEqual(@as(usize, 1), count);

    // Test deleteBeast
    try deleteBeast(loaded_party[0].?);
    reg.destroy(loaded_party[0].?);
    loaded_party[0] = null;
    try saveAll(&reg, &loaded_party, loaded_master, &loaded_dungeon);

    reg.clear();
    var p3 = [_]?ecs.Entity{null} ** 5;
    var m3: ecs.Entity = .{ .id = 0, .generation = 0 };
    var d3: Dungeon = undefined;
    _ = try loadAll(&reg, &p3, &m3, &d3);
    try std.testing.expectEqual(@as(?ecs.Entity, null), p3[0]);
}
