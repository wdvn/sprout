package main

import "core:fmt"
import rl "vendor:raylib"

// --- Spell System ---
Spell_Type :: enum {
    BALL,
}

max_spells :: 10

Spell :: struct {
    position:     rl.Vector3,
    velocity:     rl.Vector3,
    start_pos:    rl.Vector3,
    radius:       f32,
    speed:        f32,
    damage:       int,
    max_distance: f32,
    color:        rl.Color,
    is_active:    bool,
    spell_type:   Spell_Type,
}

// --- Spell Management Functions ---
spawn_spell :: proc(
    spells:     ^[max_spells]Spell,
    start_pos:  rl.Vector3,
    direction:  rl.Vector3,
    spell_type: Spell_Type,
) {
    for i in 0..<max_spells {
        if !spells[i].is_active {
            switch spell_type {
            case .BALL:
                spells[i] = Spell{
                    position     = start_pos,
                    velocity     = direction,
                    start_pos    = start_pos,
                    radius       = 0.5,
                    speed        = 10.0,
                    damage       = 10,
                    max_distance = 120.0,
                    color        = rl.YELLOW,
                    is_active    = true,
                    spell_type   = .BALL,
                }
            }
            break // Spawn only one spell at a time
        }
    }
}

update_spells :: proc(spells: ^[max_spells]Spell, npc: ^NPC, enemies: ^[max_enemies]Enemy) {
    for i in 0..<max_spells {
        spell := &spells[i]
        if !spell.is_active {
            continue
        }

        // Movement
        spell.position = rl.Vector3Add(spell.position, rl.Vector3Scale(spell.velocity, spell.speed * rl.GetFrameTime()))
        
        hit_something := false

        // Collision with NPC
        if npc.health > 0 {
            npc_box := rl.BoundingBox{
                min = rl.Vector3Subtract(npc.position, rl.Vector3Scale(npc.scale, 0.5)),
                max = rl.Vector3Add(npc.position, rl.Vector3Scale(npc.scale, 0.5)),
            }
            if rl.CheckCollisionBoxSphere(npc_box, spell.position, spell.radius) {
                spell.is_active = false
                npc.health -= spell.damage
                fmt.printf("Dealt %d damage to NPC. NPC health: %d\n", spell.damage, npc.health)
                hit_something = true
            }
        }

        // Collision with enemies
        if !hit_something {
            for j in 0..<max_enemies {
                enemy := &enemies[j]
                if enemy.is_active && enemy.health > 0 {
                    enemy_box := rl.BoundingBox{
                        min = rl.Vector3Subtract(enemy.position, rl.Vector3Scale(enemy.scale, 0.5)),
                        max = rl.Vector3Add(enemy.position, rl.Vector3Scale(enemy.scale, 0.5)),
                    }
                    if rl.CheckCollisionBoxSphere(enemy_box, spell.position, spell.radius) {
                        spell.is_active = false
                        enemy.health -= spell.damage
                        fmt.printf("Dealt %d damage to enemy. Enemy health: %d\n", spell.damage, enemy.health)
                        if enemy.health <= 0 {
                            enemy.is_active = false
                        }
                        hit_something = true
                        break // Spell hits one enemy at a time
                    }
                }
            }
        }

        // Check distance for deactivation
        if !hit_something && rl.Vector3Distance(spell.position, spell.start_pos) > spell.max_distance {
            spell.is_active = false
        }
    }
}

draw_spells :: proc(spells: ^[max_spells]Spell) {
    for i in 0..<max_spells {
        if spells[i].is_active {
            rl.DrawSphere(spells[i].position, spells[i].radius, spells[i].color)
        }
    }
}
