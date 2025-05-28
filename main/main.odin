package main

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:math/linalg/glsl"
import "core:time"
import glfw "vendor:glfw"
import ma "vendor:miniaudio"
import vk "vendor:vulkan"

MAX_KEY_EVENT_COUNT :: 10
KEY_EVENT_BACKING_BUFFER := [MAX_KEY_EVENT_COUNT]KeyEvent{}
GlobalContext :: struct {
	framebuffer_resized: bool,
	vk_instance:         vk.Instance,
	key_events_count:    int,
	keys_held:           KeysPressed,
	running:             bool,
	sound_engine:        ^ma.engine,
}

KeysPressed :: struct {
	left:  bool,
	right: bool,
}

any :: proc(using kp: KeysPressed) -> bool {return left || right}

gc: GlobalContext

main :: proc() {
	gc.running = true
	context.user_ptr = &gc

	game := Game {
		game_map = init_map(),
		player   = init_player(),
		coin     = init_coin(),
	}
	gc.sound_engine = init_sound()

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
			game.player.animation_frame_held += 1
			if game.player.animation_frame_held >= game.player.animation.duration_frames {
				advance_player_animation_frame(&game)
			}
			game.coin.animation_frame_held += 1
			if game.coin.animation_frame_held >= coin_spin_animation.duration_frames {
				advance_coin_animation_frame(&game)
			}

			speed :: 0.04
			for i in 0 ..< gc.key_events_count {
				ke := KEY_EVENT_BACKING_BUFFER[i]
				if ke.key == .left {
					if ke.action == .pressed {
						game.player.vel.x -= speed
						game.player.is_facing_left = true
						gc.keys_held.left = true
						set_new_animation(&game, player_run)
					}
					if ke.action == .released {
						game.player.vel.x += speed
						gc.keys_held.left = false
						if !any(gc.keys_held) {
							set_new_animation(&game, player_idle)
						}
					}
				}
				if ke.key == .right {
					if ke.action == .pressed {
						game.player.vel.x += speed
						game.player.is_facing_left = false
						gc.keys_held.right = true
						set_new_animation(&game, player_run)
					}
					if ke.action == .released {
						game.player.vel.x -= speed
						gc.keys_held.right = false
						if !any(gc.keys_held) {
							set_new_animation(&game, player_idle)
						}
					}
				}
				if ke.key == .up {
					if ke.action == .pressed {
						if game.player.is_grounded {
							game.player.vel.y = JUMP_SPEED
							game.player.is_grounded = false
							if res := ma.engine_play_sound(
								gc.sound_engine,
								"brackeys_platformer_assets/sounds/jump.wav",
								nil,
							); res != ma.result.SUCCESS {
								fmt.eprintln("failed to play jump.wav")
							}
						}
					}
				}
				if ke.key == .down {
					// noop
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
						game.player = init_player()
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
				if overlap_info.w {
					next_pos.x = game.player.pos.x
				}
				if overlap_info.e {
					next_pos.x = game.player.pos.x
				}
				if overlap_info.n {
					next_pos.y = game.player.pos.y
					game.player.vel.y = min(0, game.player.vel.y)
				}
				if overlap_info.s ||
				   (overlap_info.se && overlap_info.e) ||
				   (overlap_info.sw && overlap_info.w) {
					next_pos.y = game.player.pos.y
					game.player.vel.y = max(0, game.player.vel.y)
					game.player.is_grounded = true
				}
			}
			if next_pos.y != game.player.pos.y {game.player.is_grounded = false}
			game.player.pos = next_pos
			if game.player.is_alive && game.player.pos.y < DEATH_Y {
				game.player.is_alive = false
				ma.engine_play_sound(
					gc.sound_engine,
					"brackeys_platformer_assets/sounds/hurt.wav",
					nil,
				)
			}
			if game.player.is_alive {
				camera.pos = game.player.pos
			}
			game.player.vel.y -= FALLING_ACCEL

			{ 	// handle player-coin collision
				if any_overlapping(
					player_overlaps_quad(
						game.player.pos,
						game.player.collision_dim,
						game.coin.pos,
						game.coin.collision_dim,
					),
				) {
					ma.engine_play_sound(
						gc.sound_engine,
						"brackeys_platformer_assets/sounds/coin.wav",
						nil,
					)
					if game.coin.pos == COIN_POS1 {
						game.coin.pos = COIN_POS2
					} else if game.coin.pos == COIN_POS2 {
						game.coin.pos = COIN_POS1
					} else {
						unreachable()
					}
				}
			}
		}

		{ 	// draw current game state
			drawables := game_to_drawables(game)
			draw_frame(
				&renderer,
				drawables,
				camera,
				cast(f32)renderer.surface_extent.width / cast(f32)renderer.surface_extent.height,
				game.player.is_facing_left,
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
