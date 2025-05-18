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

Pos :: struct {
	x, y: f32,
}

Vel :: struct {
	x, y: f32,
}

Dim :: struct {
	w, h: f32,
}

KeyEvent :: struct {
	key:    Key,
	action: KeyAction,
}

Key :: enum {
	left,
	right,
	up,
	down,
	p,
	f,
	esc,
}

key_from_glfw :: proc "c" (glfw_key: i32) -> (k: Key, success: bool) {
	switch glfw_key {
	case glfw.KEY_LEFT:
		return .left, true
	case glfw.KEY_RIGHT:
		return .right, true
	case glfw.KEY_UP:
		return .up, true
	case glfw.KEY_DOWN:
		return .down, true
	case glfw.KEY_P:
		return .p, true
	case glfw.KEY_F:
		return .f, true
	case glfw.KEY_ESCAPE:
		return .esc, true
	}
	return nil, false
}

KeyAction :: enum {
	pressed,
	released,
}

action_from_glfw :: proc "c" (glfw_action: i32) -> (a: KeyAction, success: bool) {
	switch glfw_action {
	case glfw.PRESS:
		return .pressed, true
	case glfw.RELEASE:
		return .released, true
	}
	return nil, false
}

handle_key_press :: proc "c" (
	window: glfw.WindowHandle,
	glfw_key: i32,
	glfw_scancode: i32,
	glfw_action: i32,
	glfw_mods: i32,
) {
	user_ptr := cast(^GlobalContext)glfw.GetWindowUserPointer(window)
	key, key_success := key_from_glfw(glfw_key)
	action, action_success := action_from_glfw(glfw_action)
	if !key_success || !action_success {return}
	KEY_EVENT_BACKING_BUFFER[user_ptr.key_events_count] = KeyEvent {
		key    = key,
		action = action,
	}
	user_ptr.key_events_count += 1
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
			game.player.pos = {
				game.player.pos.x + game.player.vel.x,
				game.player.pos.y + game.player.vel.y,
			}
			camera.pos = game.player.pos
		}

		{ 	// current game state
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
