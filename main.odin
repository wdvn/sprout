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
screenWidth :: 800
screenHeight :: 450
playerSpeed :: 5.0
interactionDistance :: 5.0

// Enums for game states
GameState :: enum {
    GAMEPLAY,
    DIALOGUE,
}

// Player data structure
Player :: struct {
    position: rl.Vector3,
    scale: rl.Vector3,
    color: rl.Color,
}

// NPC data structure
NPC :: struct {
    position: rl.Vector3,
    scale: rl.Vector3,
    color: rl.Color,
    dialogue: string,
    isActive: bool,
}

// Function to initialize the player
init_player :: proc() -> Player {
    player: Player
    player.position = { 0.0, 0.0, 0.0 }
    player.scale = { 1.0, 2.0, 1.0 }
    player.color = rl.RED
    return player
}

// Function to initialize an NPC
init_npc :: proc(position: rl.Vector3, dialogue: string) -> NPC {
    npc: NPC
    npc.position = position
    npc.scale = { 1.0, 2.0, 1.0 }
    npc.color = rl.BLUE
    npc.dialogue = dialogue
    npc.isActive = false
    return npc
}

// Main entry point
main :: proc() {
// Initialization
    rl.InitWindow(screenWidth, screenHeight, "Odin 2.5D RPG")

    // Initialize the camera for a 2.5D view
    camera: rl.Camera3D
    camera.position = { 20.0, 20.0, 20.0 }
    camera.target = { 0.0, 0.0, 0.0 }
    camera.up = { 0.0, 1.0, 0.0 }
    camera.fovy = 45.0
    camera.projection = rl.CameraProjection.PERSPECTIVE

    // Initialize player and NPCs
    player := init_player()
    npc1 := init_npc({ 10.0, 0.0, 10.0 }, "Hello, adventurer! The path to the east is dangerous.")

    // Game state
    currentState := GameState.GAMEPLAY

    rl.SetTargetFPS(60)

    // Main game loop
    for !rl.WindowShouldClose() {
    // Update
        if currentState == GameState.GAMEPLAY {
        // Player movement
            if rl.IsKeyDown(.W) {
                player.position = rl.Vector3Add(player.position, rl.Vector3Scale({ 0.0, 0.0, -1.0 }, playerSpeed * rl.GetFrameTime()))
            }
            if rl.IsKeyDown(.S) {
                player.position = rl.Vector3Add(player.position, rl.Vector3Scale({ 0.0, 0.0, 1.0 }, playerSpeed * rl.GetFrameTime()))
            }
            if rl.IsKeyDown(.A) {
                player.position = rl.Vector3Add(player.position, rl.Vector3Scale({ -1.0, 0.0, 0.0 }, playerSpeed * rl.GetFrameTime()))
            }
            if rl.IsKeyDown(.D) {
                player.position = rl.Vector3Add(player.position, rl.Vector3Scale({ 1.0, 0.0, 0.0 }, playerSpeed * rl.GetFrameTime()))
            }

            // Update camera to follow player (while maintaining fixed angle)
            camera.target = player.position
            camera.position = rl.Vector3Add(player.position, { 20.0, 20.0, 20.0 })

            // Check for NPC interaction
            if rl.Vector3Distance(player.position, npc1.position) < interactionDistance {
                npc1.isActive = true
                if rl.IsKeyPressed(.E) {
                    currentState = GameState.DIALOGUE
                }
            } else {
                npc1.isActive = false
            }
        } else if currentState == GameState.DIALOGUE {
        // Exit dialogue state when "E" is pressed
            if rl.IsKeyPressed(.E) {
                currentState = GameState.GAMEPLAY
            }
        }

        // Draw
        rl.BeginDrawing()

        rl.ClearBackground(rl.SKYBLUE)

        // Draw the 3D scene (2.5D world)
        rl.BeginMode3D(camera)

        // Draw a grid for the ground plane
        rl.DrawGrid(20, 1.0)

        // Draw player
        rl.DrawCube(player.position, player.scale.x, player.scale.y, player.scale.z, player.color)

        // Draw NPC
        rl.DrawCube(npc1.position, npc1.scale.x, npc1.scale.y, npc1.scale.z, npc1.color)

        rl.EndMode3D()

        // Draw the 2D UI on top of the 3D scene
        text := fmt.ctprintf("Player Position: (%.1f, %.1f, %.1f)", player.position.x, player.position.y, player.position.z)
        rl.DrawText(text, 10, 10, 20, rl.BLACK)
        rl.DrawText(cstring("Use WASD to move"), 10, 40, 20, rl.DARKGRAY)

        // Draw interaction prompt
        if npc1.isActive && currentState == GameState.GAMEPLAY {
            rl.DrawText(cstring("Press 'E' to talk"), rl.GetScreenWidth() / 2 - 100, rl.GetScreenHeight() / 2, 20, rl.WHITE)
        }

        // Draw dialogue box
        if currentState == GameState.DIALOGUE {
            rl.DrawRectangle(0, rl.GetScreenHeight() - 100, rl.GetScreenWidth(), 100, rl.Fade(rl.BLACK, 0.7))
            rl.DrawText(fmt.ctprint(npc1.dialogue), 20, rl.GetScreenHeight() - 80, 20, rl.WHITE)
            rl.DrawText(cstring("Press 'E' to continue..."), 20, rl.GetScreenHeight() - 40, 20, rl.GRAY)
        }

        rl.EndDrawing()
    }

    // De-Initialization
    rl.CloseWindow()
}
