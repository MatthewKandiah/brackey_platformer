package main

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:math/linalg/glsl"
import "core:time"
import glfw "vendor:glfw"
import vk "vendor:vulkan"

MAX_KEY_EVENT_COUNT :: 10
KEY_EVENT_BACKING_BUFFER := [MAX_KEY_EVENT_COUNT]KeyEvent{}
GlobalContext :: struct {
	framebuffer_resized: bool,
	vk_instance:         vk.Instance,
	key_events_count:    int,
	running:             bool,
}

gc: GlobalContext

quads_overlap :: proc(p1: Pos, d1: Dim, p2: Pos, d2: Dim) -> bool {
	top1 := p1.y + d1.h
	top2 := p2.y + d2.h
	bot1 := p1.y
	bot2 := p2.y

	left1 := p1.x - d1.w / 2
	left2 := p2.x - d2.w / 2
	right1 := p1.x + d1.w / 2
	right2 := p2.x + d2.w / 2

	return !(bot1 > top2 || bot2 > top1 || right1 < left2 || right2 < left1)
}

main :: proc() {
	gc.running = true
	context.user_ptr = &gc

	game := Game {
		game_map = init_map(),
		player   = init_player(),
	}

	renderer := init_renderer()
	glfw.SetWindowUserPointer(renderer.window, &gc)
	glfw.SetKeyCallback(renderer.window, handle_key_press)

	refresh_rate :: 60
	NANOSECONDS_PER_FRAME: f64 = 1_000_000_000 / refresh_rate

	camera: Camera = {
		pos         = game.player.pos,
		zoom_factor = 1,
	}
	for gc.running && !glfw.WindowShouldClose(renderer.window) {
		start_time := time.now()
		glfw.PollEvents()

		{ 	// update game state
			speed :: 0.04
			for i in 0 ..< gc.key_events_count {
				ke := KEY_EVENT_BACKING_BUFFER[i]
				if ke.key == .left {
					if ke.action == .pressed {
						game.player.vel.x = -speed
					}
					if ke.action == .released {
						game.player.vel.x = 0
					}
				}
				if ke.key == .right {
					if ke.action == .pressed {
						game.player.vel.x = speed
					}
					if ke.action == .released {
						game.player.vel.x = 0
					}
				}
				if ke.key == .up {
					if ke.action == .pressed {
						game.player.vel.y = speed
					}
					if ke.action == .released {
						game.player.vel.y = 0
					}
				}
				if ke.key == .down {
					if ke.action == .pressed {
						game.player.vel.y = -speed
					}
					if ke.action == .released {
						game.player.vel.y = 0
					}
				}
				if ke.key == .p {
					if ke.action == .pressed {
						camera.zoom_factor += speed
					}
				}
				if ke.key == .f {
					if ke.action == .pressed {
						camera.zoom_factor -= speed
					}
				}
				if ke.key == .esc {
					if ke.action == .pressed {
						gc.running = false
					}
				}
			}
			gc.key_events_count = 0

			next_pos := Pos {
				game.player.pos.x + game.player.vel.x,
				game.player.pos.y + game.player.vel.y,
			}
			for map_tile, i in game.game_map.tiles {
				if map_tile == .empty {continue}
				map_tile_world_pos := map_tile_pos(game.game_map, i)
				if quads_overlap(
					next_pos,
					game.player.collision_dim,
					map_tile_world_pos,
					game.game_map.tile_world_dim,
				) {
					next_pos = game.player.pos
					game.player.vel.y = 0
					break
				}
			}
			game.player.pos = next_pos
			camera.pos = game.player.pos
		}

		{ 	// draw current game state
			drawables := game_to_drawables(game)
			draw_frame(
				&renderer,
				drawables,
				camera,
				cast(f32)renderer.surface_extent.width / cast(f32)renderer.surface_extent.height,
			)
		}

		{ 	// restrict frame rate
			finish_time := time.now()
			frame_duration := time.diff(start_time, finish_time)
			wait_duration := max(
				cast(time.Duration)NANOSECONDS_PER_FRAME * time.Nanosecond - frame_duration,
				0,
			)
			time.accurate_sleep(wait_duration)
		}
	}
	vk.DeviceWaitIdle(renderer.device)
	deinit_renderer(&renderer)
}
