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
import "core:math/rand"
import rl "vendor:raylib"

// Global constants
screenWidth :i32 = 1270
screenHeight :i32 = 900
playerSpeed :f32 = 5.0
interactionDistance :f32 = 205.0

// --- Game Entities ---
GameState :: enum {
    GAMEPLAY,
    DIALOGUE,
}

Player :: struct {
    position: rl.Vector3,
    scale: rl.Vector3,
    color: rl.Color,
    health: int,
}

NPC :: struct {
    position: rl.Vector3,
    scale: rl.Vector3,
    color: rl.Color,
    dialogue: string,
    isActive: bool,
    health: int,
}

Enemy :: struct {
    position: rl.Vector3,
    scale: rl.Vector3,
    color: rl.Color,
    health: int,
    is_active: bool,
}

max_enemies :: 20

// --- Initialization Functions ---
init_player :: proc() -> Player {
    return Player{
        position = { 0.0, 0.0, 0.0 },
        scale    = { 1.0, 2.0, 1.0 },
        color    = rl.RED,
        health   = 100,
    }
}

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

// --- Enemy Management ---
spawn_enemy :: proc(enemies: ^[max_enemies]Enemy) {
    for i in 0 ..< max_enemies {
        if !enemies[i].is_active {
            enemies[i] = Enemy{
                position = {
                    f32(rand.int31_max(20)) - 10,
                    0,
                    f32(rand.int31_max(20)) - 10,
                },
                scale     = { 1.0, 1.0, 1.0 },
                color     = rl.GREEN,
                health    = 20, // Health between 20 and 70
                is_active = true,
            }
            break
        }
    }
}

draw_enemies :: proc(enemies: ^[max_enemies]Enemy) {
    for i in 0 ..< max_enemies {
        if enemies[i].is_active {
            rl.DrawCube(enemies[i].position, enemies[i].scale.x, enemies[i].scale.y, enemies[i].scale.z, enemies[i].color)
        }
    }
}
handle_dialogue :: proc(
currentState: ^GameState,
screenWidth: i32,
screenHeight: i32,
npc: ^NPC
) {
// Check for exit condition to switch back to gameplay
    if rl.IsKeyPressed(.E) {
    // Change the state back to GAMEPLAY by dereferencing the pointer
        currentState^ = .GAMEPLAY
    }

    // Draw the dialogue box
    rl.DrawRectangle(0, screenHeight - 100, screenWidth, 100, rl.Fade(rl.BLACK, 0.7))
    // Draw the NPC's dialogue text
    // NOTE: fmt.ctprint converts your string to a C-style string for Raylib
    rl.DrawText(fmt.ctprint(npc.dialogue), 20, screenHeight - 80, 20, rl.WHITE)
}

// NOTE: Assuming 'Player' is a struct that contains a 'position: rl.Vector3' field.
// We also assume 'playerSpeed' is a globally accessible constant/variable.
update_player_movement :: proc(player: ^Player, playerSpeed: f32) {
    delta_time := rl.GetFrameTime()

    // Move forward (Z-axis negative)
    if rl.IsKeyDown(.W) {
        player.position.z -= playerSpeed * delta_time
    }
    // Move backward (Z-axis positive)
    if rl.IsKeyDown(.S) {
        player.position.z += playerSpeed * delta_time
    }
    // Move left (X-axis negative)
    if rl.IsKeyDown(.A) {
        player.position.x -= playerSpeed * delta_time
    }
    // Move right (X-axis positive)
    if rl.IsKeyDown(.D) {
        player.position.x += playerSpeed * delta_time
    }
}

// --- Main Entry Point ---
main :: proc() {
    rl.InitWindow(screenWidth, screenHeight, cstring("Odin 2.5D RPG"))
    rl.SetTargetFPS(60)

    // ... (camera setup remains the same)
    camera: rl.Camera3D
    camera.position = { 20.0, 20.0, 20.0 }
    camera.target = { 0.0, 0.0, 0.0 }
    camera.up = { 0.0, 1.0, 0.0 }
    camera.fovy = 45.0
    camera.projection = .PERSPECTIVE

    player := init_player()
    npc1 := init_npc({ 10.0, 0.0, 10.0 }, "Hello, adventurer!") // NOTE: You need to ensure init_npc is defined to return NPC

    spells: [max_spells]Spell
    enemies: [max_enemies]Enemy

    spawn_timer := f32(0)
    currentState := GameState.GAMEPLAY

    for !rl.WindowShouldClose() {
    // 1. UPDATE LOGIC
        #partial switch currentState {
        case .GAMEPLAY:
            update_player_movement(&player, playerSpeed)

            if rl.IsKeyPressed(.K) {
            // ... (spell casting logic remains the same)
                direction: rl.Vector3
                // Find the closest active enemy to target
                closest_enemy : ^Enemy = nil
                closest_dist := f32(math.F32_MAX - 1)

                for i in 0 ..< max_enemies {
                    enemy := &enemies[i]
                    if enemy.is_active {
                        dist := rl.Vector3Distance(player.position, enemy.position)
                        if dist < closest_dist && dist < interactionDistance {
                            closest_enemy = enemy
                            closest_dist = dist
                        }
                    }
                }

                if closest_enemy != nil {
                    direction = rl.Vector3Normalize(rl.Vector3Subtract(closest_enemy.position, player.position))
                } else {
                    direction = { 0, 0, -1 }
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
                if rl.IsKeyPressed(.E) do  currentState = .DIALOGUE
            } else {
                npc1.isActive = false
            }

        // The .DIALOGUE case is REMOVED from the update switch
        // case .DIALOGUE:
        //     if rl.IsKeyPressed(.E) { currentState = .GAMEPLAY }
        }

        // 2. DRAWING LOGIC
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

        // Draw interaction prompt
        if npc1.isActive && currentState == .GAMEPLAY && npc1.health > 0 {
            rl.DrawText(cstring("Press 'E' to talk"), i32(screenWidth) / 2 - 100, i32(screenHeight) / 2, 20, rl.WHITE)
        }

        // CALL THE NEW DIALOGUE HANDLER HERE
        if currentState == .DIALOGUE {
            handle_dialogue(&currentState, screenWidth, screenHeight, &npc1)
        }
        // The old dialogue drawing code is REMOVED from here

        rl.EndDrawing()
    }

    rl.CloseWindow()
}