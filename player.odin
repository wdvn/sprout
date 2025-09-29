package main

import rl "vendor:raylib"

Player :: struct {
    position: rl.Vector3,
    scale:    rl.Vector3,
    color:    rl.Color,
    health:   int,
}

init_player :: proc() -> Player {
    return Player{
        position = {0.0, 0.0, 0.0},
        scale    = {1.0, 2.0, 1.0},
        color    = rl.RED,
        health   = 100,
    }
}

update_player :: proc(player: ^Player, speed: f32) {
    if rl.IsKeyDown(.W) { player.position.z -= speed * rl.GetFrameTime() }
    if rl.IsKeyDown(.S) { player.position.z += speed * rl.GetFrameTime() }
    if rl.IsKeyDown(.A) { player.position.x -= speed * rl.GetFrameTime() }
    if rl.IsKeyDown(.D) { player.position.x += speed * rl.GetFrameTime() }
}
