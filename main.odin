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
import "core:math"
import rl "vendor:raylib"

// Global constants
screenWidth : i32 = 1270
screenHeight : i32 = 900
playerSpeed : f32 = 5.0
interactionDistance : f32 = 5.0

// --- Game Entities ---
GameState :: enum {
    GAMEPLAY,
    DIALOGUE,
}

NPC :: struct {
    position: rl.Vector3,
    scale: rl.Vector3,
    color: rl.Color,
    dialogue: string,
    isActive: bool,
    health: int,
}

// --- Initialization Functions ---
init_npc :: proc(position: rl.Vector3, dialogue: string) -> NPC {
    return NPC{
        position = position,
        scale    = { 1.0, 2.0, 1.0 },
        color    = rl.BLUE,
        dialogue = dialogue,
        isActive = false,
        health   = 50,
    }
}

// --- Main Entry Point ---
main :: proc() {
    rl.InitWindow(screenWidth, screenHeight, cstring("Odin 2.5D RPG"))
    rl.SetTargetFPS(60)

    camera: rl.Camera3D
    camera.position = { 20.0, 20.0, 20.0 }
    camera.target = { 0.0, 0.0, 0.0 }
    camera.up = { 0.0, 1.0, 0.0 }
    camera.fovy = 45.0
    camera.projection = .PERSPECTIVE

    player := init_player()
    npc1 := init_npc({ 10.0, 0.0, 10.0 }, "Hello, adventurer!")

    spells: [max_spells]Spell
    enemies: [max_enemies]Enemy

    spawn_timer := f32(0)
    currentState := GameState.GAMEPLAY

    for !rl.WindowShouldClose() {
        switch currentState {
        case .GAMEPLAY:
            update_player(&player, playerSpeed)

            if rl.IsKeyPressed(.K) {
                direction: rl.Vector3
                if npc1.isActive {
                    direction = rl.Vector3Normalize(rl.Vector3Subtract(npc1.position, player.position))
                } else {
                // Find the closest active enemy to target
                    closest_enemy : ^Enemy = nil
                    closest_dist := math.F32_MAX

                    for i in 0 ..< max_enemies {
                        enemy := &enemies[i]
                        if enemy.is_active {
                            dist := rl.Vector3Distance(player.position, enemy.position)
                            if f64(dist) < closest_dist  {
                                closest_enemy = enemy
                                closest_dist = f64(dist)
                            }
                        }
                    }

                    if closest_enemy != nil {
                        direction = rl.Vector3Normalize(rl.Vector3Subtract(closest_enemy.position, player.position))
                    } else {
                        direction = { 0, 0, -1 }
                    }
                }
                spawn_spell(&spells, player.position, direction, .BALL)
            }

            // Enemy spawning
            spawn_timer += rl.GetFrameTime()
            if spawn_timer >= 2.0 {
                spawn_enemy(&enemies)
                spawn_timer = 0
            }

            update_spells(&spells, &npc1, &enemies)

            camera.target = player.position
            camera.position = rl.Vector3Add(player.position, { 20.0, 20.0, 20.0 })

            if rl.Vector3Distance(player.position, npc1.position) < interactionDistance {
                npc1.isActive = true
                if rl.IsKeyPressed(.E) {
                    currentState = .DIALOGUE
                }
            } else {
                npc1.isActive = false
            }

        case .DIALOGUE:
            if rl.IsKeyPressed(.E) {
                currentState = .GAMEPLAY
            }
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
        rl.DrawText(cstring("Press 'K' to cast a spell"), 10, 40, 20, rl.DARKGRAY)

        if npc1.isActive && currentState == .GAMEPLAY && npc1.health > 0 {
            rl.DrawText(cstring("Press 'E' to talk"), screenWidth / 2 - 100, screenHeight / 2, 20, rl.WHITE)
        }

        if currentState == .DIALOGUE {
            rl.DrawRectangle(0, screenHeight - 100, screenWidth, 100, rl.Fade(rl.BLACK, 0.7))
            rl.DrawText(fmt.ctprint(npc1.dialogue), 20, screenHeight - 80, 20, rl.WHITE)
        }

        rl.EndDrawing()
    }

    rl.CloseWindow()
}
