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
                    max_distance = 10.0,
                    color        = rl.YELLOW,
                    is_active    = true,
                    spell_type   = .BALL,
                }
            }
            break // Spawn only one spell at a time
        }
    }
}

update_spells :: proc(spells: ^[max_spells]Spell, npc: ^NPC) {
    for i in 0..<max_spells {
        spell := &spells[i]
        if !spell.is_active {
            continue
        }

        // Movement
        spell.position = rl.Vector3Add(spell.position, rl.Vector3Scale(spell.velocity, spell.speed * rl.GetFrameTime()))

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
            }
        }

        // Check distance for deactivation
        if rl.Vector3Distance(spell.position, spell.start_pos) > spell.max_distance {
            spell.is_active = false
        }
    }
}

draw_spells :: proc(spells: ^[max_spells]Spell) {
    for i in 0..<max_spells {
        spell := &spells[i]
        if !spell.is_active {
            continue
        }

        switch spell.spell_type {
        case .BALL:
            rl.DrawSphere(spell.position, spell.radius, spell.color)
        }
    }
}

// --- Main Entry Point ---
main :: proc() {
    // Initialization
    rl.InitWindow(screenWidth, screenHeight, "Odin 2.5D RPG")
    rl.SetTargetFPS(60)

    // Camera setup
    camera: rl.Camera3D
    camera.position   = {20.0, 20.0, 20.0}
    camera.target     = {0.0, 0.0, 0.0}
    camera.up         = {0.0, 1.0, 0.0}
    camera.fovy       = 45.0
    camera.projection = .PERSPECTIVE

    // Game entities
    player := init_player()
    npc1 := init_npc({10.0, 0.0, 10.0}, "Hello, adventurer! The path to the east is dangerous.")
    
    // Spell management
    spells: [max_spells]Spell
    
    // Game state
    currentState := GameState.GAMEPLAY

    // Main game loop
    for !rl.WindowShouldClose() {
        // --- Update ---
        switch currentState {
        case .GAMEPLAY:
            // Player movement
            if rl.IsKeyDown(.W) { player.position.z -= playerSpeed * rl.GetFrameTime() }
            if rl.IsKeyDown(.S) { player.position.z += playerSpeed * rl.GetFrameTime() }
            if rl.IsKeyDown(.A) { player.position.x -= playerSpeed * rl.GetFrameTime() }
            if rl.IsKeyDown(.D) { player.position.x += playerSpeed * rl.GetFrameTime() }

            // Spell casting
            if rl.IsKeyPressed(.K) {
                direction: rl.Vector3
                if npc1.isActive {
                    direction = rl.Vector3Normalize(rl.Vector3Subtract(npc1.position, player.position))
                } else {
                    // Default direction if no target is active
                    direction = {0, 0, -1} // Assuming forward is -Z
                }
                spawn_spell(&spells, player.position, direction, .BALL)
            }

            // Update spells
            update_spells(&spells, &npc1)

            // Camera follow
            camera.target = player.position
            camera.position = rl.Vector3Add(player.position, {20.0, 20.0, 20.0})

            // NPC interaction
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

        // --- Draw ---
        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)

        // 3D Scene
        rl.BeginMode3D(camera)
        rl.DrawGrid(20, 1.0)
        rl.DrawCube(player.position, player.scale.x, player.scale.y, player.scale.z, player.color)
        if npc1.health > 0 {
            rl.DrawCube(npc1.position, npc1.scale.x, npc1.scale.y, npc1.scale.z, npc1.color)
        }
        draw_spells(&spells)
        rl.EndMode3D()

        // 2D UI
        rl.DrawText(fmt.ctprintf("Player Position: (%.1f, %.1f, %.1f)", player.position.x, player.position.y, player.position.z), 10, 10, 20, rl.BLACK)
        rl.DrawText("Use WASD to move", 10, 40, 20, rl.DARKGRAY)
        rl.DrawText("Press 'K' to cast a spell", 10, 70, 20, rl.DARKGRAY)
        rl.DrawText(fmt.ctprintf("NPC Health: %d", npc1.health), 10, 100, 20, rl.BLACK)

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

    // De-Initialization
    rl.CloseWindow()
}
