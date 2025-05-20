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

OverlapInfo :: struct {
	top:    bool,
	bottom: bool,
	left:   bool,
	right:  bool,
}

any_overlapping :: proc(using o: OverlapInfo) -> bool {
	return top || bottom || left || right
}

NON_OVERLAPPING :: OverlapInfo {
	top    = false,
	bottom = false,
	left   = false,
	right  = false,
}

ALL_OVERLAPPING :: OverlapInfo {
	top    = true,
	bottom = true,
	left   = true,
	right  = true,
}

player_overlaps_quad :: proc(
	player_p: Pos,
	player_d: Dim,
	quad_p: Pos,
	quad_d: Dim,
) -> OverlapInfo {
	player_top := player_p.y + player_d.h
	quad_top := quad_p.y + quad_d.h
	player_bot := player_p.y
	quad_bot := quad_p.y

	player_left := player_p.x - player_d.w / 2
	quad_left := quad_p.x - quad_d.w / 2
	player_right := player_p.x + player_d.w / 2
	quad_right := quad_p.x + quad_d.w / 2

	if player_bot > quad_top ||
	   quad_bot > player_top ||
	   player_right < quad_left ||
	   quad_right < player_left {return NON_OVERLAPPING}

	overlap_info: OverlapInfo = NON_OVERLAPPING
	if player_left > quad_left {overlap_info.left = true}
	if player_right < quad_right {overlap_info.right = true}
	if player_top < quad_top {overlap_info.top = true}
	if player_bot > quad_bot {overlap_info.bottom = true}
	return overlap_info
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
				overlap_info := player_overlaps_quad(
					next_pos,
					game.player.collision_dim,
					map_tile_world_pos,
					game.game_map.tile_world_dim,
				)
				if overlap_info.left {
					next_pos.x = game.player.pos.x
					game.player.vel.x = max(0, game.player.vel.x)
				}
				if overlap_info.right {
					next_pos.x = game.player.pos.x
					game.player.vel.x = min(0, game.player.vel.x)
				}
				if overlap_info.top {
					next_pos.y = game.player.pos.y
					game.player.vel.y = min(0, game.player.vel.y)
				}
				if overlap_info.bottom {
					next_pos.y = game.player.pos.y
					game.player.vel.y = max(0, game.player.vel.y)
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
