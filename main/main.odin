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
	running:             bool,
}

gc: GlobalContext

Pos :: struct {
	x, y: f32,
}

Dim :: struct {
	w, h: f32,
}

PressedKeys :: struct {
	left:  bool,
	right: bool,
	up:    bool,
	down:  bool,
	p:     bool,
	f:     bool,
	esc:   bool,
}

main :: proc() {
	gc.running = true
	context.user_ptr = &gc

	game := Game {
		game_map = init_map(),
		player = Player{pos = {0, 0}},
	}

	renderer := init_renderer()
	glfw.SetWindowUserPointer(renderer.window, &gc)
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
			if key == glfw.KEY_P {
				if action == glfw.PRESS {
					user_ptr.pressed.p = true
				}
				if action == glfw.RELEASE {
					user_ptr.pressed.p = false
				}
			}
			if key == glfw.KEY_F {
				if action == glfw.PRESS {
					user_ptr.pressed.f = true
				}
				if action == glfw.RELEASE {
					user_ptr.pressed.f = false
				}
			}
			if key == glfw.KEY_ESCAPE {
				if action == glfw.PRESS {
					user_ptr.pressed.esc = true
				}
				if action == glfw.RELEASE {
					user_ptr.pressed.esc = false
				}
			}
		},
	)

	refresh_rate :: 60
	NANOSECONDS_PER_FRAME: f64 = 1_000_000_000 / refresh_rate

	camera: Camera = {
		pos         = game.player.pos,
		zoom_factor = 1,
	}
	for gc.running && !glfw.WindowShouldClose(renderer.window) {
		start_time := time.now()
		glfw.PollEvents()

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
			game.player.pos.y -= speed
			camera.pos = game.player.pos
		}
		if gc.pressed.down {
			game.player.pos.y += speed
			camera.pos = game.player.pos
		}
		if gc.pressed.p {
			camera.zoom_factor += speed
		}
		if gc.pressed.f {
			camera.zoom_factor -= speed
		}
		if gc.pressed.esc {
			gc.running = false
		}

		drawables := game_to_drawables(game)
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
