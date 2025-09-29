package main

import "core:math/rand"
import rl "vendor:raylib"

Enemy :: struct {
    position:  rl.Vector3,
    scale:     rl.Vector3,
    color:     rl.Color,
    health:    int,
    is_active: bool,
}

max_enemies :: 20

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
                health    = int(rand.int31_max(50)) + 20, // Health between 20 and 70
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
