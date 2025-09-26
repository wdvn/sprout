//
// Simple 2.5D RPG example using Raylib, written in Odin
//
// This code demonstrates the core concepts for a 2.5D game in Odin:
// - A 3D camera fixed to a specific angle to create a 2.5D (isometric) perspective.
// - 3D models (represented by cubes) for the player and objects.
// - 2D drawing for the user interface (UI) and text.
// - Basic player movement and interaction with an NPC.
//

package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

// Global constants
screenWidth :: 1270
screenHeight :: 900
playerSpeed :: 5.0
interactionDistance :: 5.0

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

// --- Game Entities ---
GameState :: enum {
    GAMEPLAY,
    DIALOGUE,
}

Player :: struct {
    position: rl.Vector3,
    scale:    rl.Vector3,
    color:    rl.Color,
    health:   int,
}

NPC :: struct {
    position: rl.Vector3,
    scale:    rl.Vector3,
    color:    rl.Color,
    dialogue: string,
    isActive: bool,
    health:   int,
}

Enemy :: struct {
    position:  rl.Vector3,
    scale:     rl.Vector3,
    color:     rl.Color,
    health:    int,
    is_active: bool,
}

max_enemies :: 20

// --- Initialization Functions ---
init_player :: proc() -> Player {
    return Player{
        position = {0.0, 0.0, 0.0},
        scale    = {1.0, 2.0, 1.0},
        color    = rl.RED,
        health   = 100,
    }
}

init_npc :: proc(position: rl.Vector3, dialogue: string) -> NPC {
    return NPC{
        position = position,
        scale    = {1.0, 2.0, 1.0},
        color    = rl.BLUE,
        dialogue = dialogue,
        isActive = false,
        health   = 50,
    }
}

// --- Spell Management ---
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
                    max_distance = 10.0,
                    color        = rl.YELLOW,
                    is_active    = true,
                    spell_type   = .BALL,
                }
            }
            break
        }
    }
}

update_spells :: proc(spells: ^[max_spells]Spell, enemies: ^[max_enemies]Enemy) {
    for i in 0..<max_spells {
        spell := &spells[i]
        if !spell.is_active {
            continue
        }

        spell.position = rl.Vector3Add(spell.position, rl.Vector3Scale(spell.velocity, spell.speed * rl.GetFrameTime()))

        // Collision with enemies
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
                    break // Spell hits one enemy at a time
                }
            }
        }

        if rl.Vector3Distance(spell.position, spell.start_pos) > spell.max_distance {
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

// --- Enemy Management ---
spawn_enemy :: proc(enemies: ^[max_enemies]Enemy) {
    for i in 0..<max_enemies {
        if !enemies[i].is_active {
            enemies[i] = Enemy{
                position = {
                    f32(rand.int31_max(20)) - 10,
                    0,
                    f32(rand.int31_max(20)) - 10,
                },
                scale     = {1.0, 1.0, 1.0},
                color     = rl.GREEN,
                health    =  20, // Health between 20 and 70
                is_active = true,
            }
            break
        }
    }
}

draw_enemies :: proc(enemies: ^[max_enemies]Enemy) {
    for i in 0..<max_enemies {
        if enemies[i].is_active {
            rl.DrawCube(enemies[i].position, enemies[i].scale.x, enemies[i].scale.y, enemies[i].scale.z, enemies[i].color)
        }
    }
}

// --- Main Entry Point ---
main :: proc() {
    rl.InitWindow(screenWidth, screenHeight, "Odin 2.5D RPG")
    rl.SetTargetFPS(60)

    camera: rl.Camera3D
    camera.position   = {20.0, 20.0, 20.0}
    camera.target     = {0.0, 0.0, 0.0}
    camera.up         = {0.0, 1.0, 0.0}
    camera.fovy       = 45.0
    camera.projection = .PERSPECTIVE

    player := init_player()
    npc1 := init_npc({10.0, 0.0, 10.0}, "Hello, adventurer!")

    spells: [max_spells]Spell
    enemies: [max_enemies]Enemy

    spawn_timer := f32(0)
    currentState := GameState.GAMEPLAY

    for !rl.WindowShouldClose() {
        switch currentState {
        case .GAMEPLAY:
            if rl.IsKeyDown(.W) { player.position.z -= playerSpeed * rl.GetFrameTime() }
            if rl.IsKeyDown(.S) { player.position.z += playerSpeed * rl.GetFrameTime() }
            if rl.IsKeyDown(.A) { player.position.x -= playerSpeed * rl.GetFrameTime() }
            if rl.IsKeyDown(.D) { player.position.x += playerSpeed * rl.GetFrameTime() }

            if rl.IsKeyPressed(.K) {
                // Find the closest active enemy to target
                closest_enemy: ^Enemy = nil
                closest_dist :f32= 10

                for i in 0..<max_enemies {
                    enemy := &enemies[i]
                    if enemy.is_active {
                        dist := rl.Vector3Distance(player.position, enemy.position)
                        if f32(dist) < f32(closest_dist) && dist < interactionDistance {
                            closest_enemy = enemy
                            closest_dist = dist
                        }
                    }
                }

                direction: rl.Vector3
                if closest_enemy != nil {
                    direction = rl.Vector3Normalize(rl.Vector3Subtract(closest_enemy.position, player.position))
                } else {
                    direction = {0, 0, -1}
                }
                spawn_spell(&spells, player.position, direction, .BALL)
            }

            // Enemy spawning
            spawn_timer += rl.GetFrameTime()
            if spawn_timer >= 2.0 {
                spawn_enemy(&enemies)
                spawn_timer = 0
            }

            update_spells(&spells, &enemies)

            camera.target = player.position
            camera.position = rl.Vector3Add(player.position, {20.0, 20.0, 20.0})

            if rl.Vector3Distance(player.position, npc1.position) < interactionDistance {
                npc1.isActive = true
                if rl.IsKeyPressed(.E) { currentState = .DIALOGUE }
            } else {
                npc1.isActive = false
            }

        case .DIALOGUE:
            if rl.IsKeyPressed(.E) { currentState = .GAMEPLAY }
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)

        rl.BeginMode3D(camera)
        rl.DrawGrid(20, 1.0)
        rl.DrawCube(player.position, player.scale.x, player.scale.y, player.scale.z, player.color)
        if npc1.health > 0 {
            rl.DrawCube(npc1.position, npc1.scale.x, npc1.scale.y, npc1.scale.z, npc1.color)
        }
        draw_enemies(&enemies)
        draw_spells(&spells)
        rl.EndMode3D()

        rl.DrawText(fmt.ctprintf("Player HP: %d", player.health), 10, 10, 20, rl.BLACK)
        rl.DrawText("Press 'K' to cast a spell", 10, 40, 20, rl.DARKGRAY)

        if npc1.isActive && currentState == .GAMEPLAY && npc1.health > 0 {
            rl.DrawText("Press 'E' to talk", screenWidth / 2 - 100, screenHeight / 2, 20, rl.WHITE)
        }

        if currentState == .DIALOGUE {
            rl.DrawRectangle(0, screenHeight - 100, screenWidth, 100, rl.Fade(rl.BLACK, 0.7))
            rl.DrawText(fmt.ctprint(npc1.dialogue), 20, screenHeight - 80, 20, rl.WHITE)
            rl.DrawText("Press 'E' to continue...", 20, screenHeight - 40, 20, rl.GRAY)
        }

        rl.EndDrawing()
    }

    rl.CloseWindow()
}
