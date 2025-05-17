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

knight :: proc(pos: Pos) -> Drawable {
	return Drawable {
		pos = pos,
		dim = {1, 1},
		tex_idx = 0,
		tex_base_pos = {0, 0},
		tex_dim = {32, 32},
	}
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

foreground_drawables := []Drawable {
	solid(pos = {-2, -2}),
	solid(pos = {-1, -1}),
	knight(pos = {0, 0}),
	coin(pos = {1, 1}),
	coin(pos = {2, 2}),
}

PressedKeys :: struct {
	left:  bool,
	right: bool,
	up:    bool,
	down:  bool,
}

main :: proc() {
	context.user_ptr = &gc

	game_map := init_map()

	map_drawable_count := len(game_map.tiles)
	foreground_drawable_count := len(foreground_drawables)
	total_drawable_count := map_drawable_count + foreground_drawable_count
	map_to_drawables(game_map, {0, 0}, {1, 1}, DRAWABLE_BACKING_BUFFER[0:map_drawable_count])
	intrinsics.mem_copy_non_overlapping(
		&DRAWABLE_BACKING_BUFFER[map_drawable_count],
		raw_data(foreground_drawables),
		foreground_drawable_count * size_of(Drawable),
	)
	drawables := DRAWABLE_BACKING_BUFFER[0:total_drawable_count]

	renderer := init_renderer()
	glfw.SetWindowUserPointer(renderer.window, &gc)

	vid_mode := glfw.GetVideoMode(renderer.monitor)
	if vid_mode == nil {
		panic("failed to get monitor video mode")
	}
	refresh_rate := cast(f64)vid_mode.refresh_rate
	NANOSECONDS_PER_FRAME: f64 = 1_000_000_000 / refresh_rate

	camera: Camera = {
		pos         = {0, 0},
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
			camera.pos.x -= speed
		}
		if gc.pressed.right {
			camera.pos.x += speed
		}
		if gc.pressed.up {
			camera.zoom_factor += speed
		}
		if gc.pressed.down {
			camera.zoom_factor -= speed
		}

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
