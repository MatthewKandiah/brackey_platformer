package main

import "base:intrinsics"
import "core:fmt"
import "core:math/linalg/glsl"
import "core:time"
import glfw "vendor:glfw"
import vk "vendor:vulkan"

GlobalContext :: struct {
	framebuffer_resized: bool,
	vk_instance:         vk.Instance,
	pressed:             PressedKeys,
}

gc: GlobalContext

Pos :: struct {
	x, y: f32,
}

Dim :: struct {
	w, h: f32,
}

coin :: proc(pos: Pos) -> Drawable {
	return Drawable {
		pos = pos,
		dim = {0.5, 0.5},
		tex_idx = 1,
		tex_base_pos = {0, 0},
		tex_dim = {16, 16},
	}
}

solid :: proc(pos: Pos) -> Drawable {
	return Drawable {
		pos = pos,
		dim = {1, 1},
		tex_idx = 2,
		tex_base_pos = {0, 176},
		tex_dim = {16, 16},
	}
}

PressedKeys :: struct {
	left:  bool,
	right: bool,
	up:    bool,
	down:  bool,
}

main :: proc() {
	context.user_ptr = &gc

	game := Game {
		game_map = init_map(),
		player = Player{pos = {0, 0}},
	}

	renderer := init_renderer()
	glfw.SetWindowUserPointer(renderer.window, &gc)

	vid_mode := glfw.GetVideoMode(renderer.monitor)
	if vid_mode == nil {
		panic("failed to get monitor video mode")
	}
	refresh_rate := cast(f64)vid_mode.refresh_rate
	NANOSECONDS_PER_FRAME: f64 = 1_000_000_000 / refresh_rate

	camera: Camera = {
		pos         = game.player.pos,
		zoom_factor = 1,
	}
	for !glfw.WindowShouldClose(renderer.window) {
		start_time := time.now()
		glfw.PollEvents()

		glfw.SetKeyCallback(
			renderer.window,
			proc "c" (window: glfw.WindowHandle, key: i32, scancode: i32, action: i32, mods: i32) {
				user_ptr := cast(^GlobalContext)glfw.GetWindowUserPointer(window)
				if key == glfw.KEY_LEFT {
					if action == glfw.PRESS {
						user_ptr.pressed.left = true
					}
					if action == glfw.RELEASE {
						user_ptr.pressed.left = false
					}
				}
				if key == glfw.KEY_RIGHT {
					if action == glfw.PRESS {
						user_ptr.pressed.right = true
					}
					if action == glfw.RELEASE {
						user_ptr.pressed.right = false
					}
				}
				if key == glfw.KEY_UP {
					if action == glfw.PRESS {
						user_ptr.pressed.up = true
					}
					if action == glfw.RELEASE {
						user_ptr.pressed.up = false
					}
				}
				if key == glfw.KEY_DOWN {
					if action == glfw.PRESS {
						user_ptr.pressed.down = true
					}
					if action == glfw.RELEASE {
						user_ptr.pressed.down = false
					}
				}
			},
		)

		speed :: 0.04
		if gc.pressed.left {
			game.player.pos.x -= speed
			camera.pos = game.player.pos
		}
		if gc.pressed.right {
			game.player.pos.x += speed
			camera.pos = game.player.pos
		}
		if gc.pressed.up {
			camera.zoom_factor += speed
		}
		if gc.pressed.down {
			camera.zoom_factor -= speed
		}

		map_drawable_count := len(game.game_map.tiles)
		total_drawable_count := map_drawable_count
		map_to_drawables(
			game.game_map,
			{0, 0},
			{0.5, 0.5},
			DRAWABLE_BACKING_BUFFER[0:map_drawable_count],
		)
		DRAWABLE_BACKING_BUFFER[map_drawable_count] = player_to_drawable(game.player)
		total_drawable_count += 1
		drawables := DRAWABLE_BACKING_BUFFER[0:total_drawable_count]

		draw_frame(
			&renderer,
			drawables,
			camera,
			cast(f32)renderer.surface_extent.width / cast(f32)renderer.surface_extent.height,
		)
		finish_time := time.now()
		frame_duration := time.diff(start_time, finish_time)
		wait_duration := max(
			cast(time.Duration)NANOSECONDS_PER_FRAME * time.Nanosecond - frame_duration,
			0,
		)
		time.accurate_sleep(wait_duration)
	}
	vk.DeviceWaitIdle(renderer.device)
	deinit_renderer(&renderer)
}
