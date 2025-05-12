package main

import "core:fmt"
import "core:math/linalg/glsl"
import "core:time"
import glfw "vendor:glfw"
import vk "vendor:vulkan"

GlobalContext :: struct {
	framebuffer_resized: bool,
	vk_instance:         vk.Instance,
}

gc: GlobalContext
FRAMES_PER_ANIMATION_CYCLE :: 6
current_idle_uv := 0
global_vertices := []Vertex {
	{{-0.5, -0.5}, idle_uvs[current_idle_uv][0]},
	{{0.5, -0.5}, idle_uvs[current_idle_uv][1]},
	{{0.5, 0.5}, idle_uvs[current_idle_uv][2]},
	{{-0.5, 0.5}, idle_uvs[current_idle_uv][3]},
}

idle_uv_1: []glsl.vec2 : {{0, 0}, {31, 0}, {31, 31}, {0, 31}}
idle_uv_2: []glsl.vec2 : {{32, 0}, {63, 0}, {63, 31}, {32, 31}}
idle_uv_3: []glsl.vec2 : {{64, 0}, {95, 0}, {95, 31}, {64, 31}}
idle_uv_4: []glsl.vec2 : {{96, 0}, {127, 0}, {127, 31}, {96, 31}}
idle_uvs := [][]glsl.vec2{idle_uv_1, idle_uv_2, idle_uv_3, idle_uv_4}

global_indices :: []u32{0, 1, 2, 2, 3, 0}

main :: proc() {
	context.user_ptr = &gc

	renderer := init_renderer()

	frame_count := 0
	for !glfw.WindowShouldClose(renderer.window) {
		start_time := time.now()
		glfw.PollEvents()

		global_vertices = []Vertex {
			{{-0.5, -0.5}, idle_uvs[current_idle_uv][0]},
			{{0.5, -0.5}, idle_uvs[current_idle_uv][1]},
			{{0.5, 0.5}, idle_uvs[current_idle_uv][2]},
			{{-0.5, 0.5}, idle_uvs[current_idle_uv][3]},
		}

		draw_frame(&renderer, global_vertices, global_indices)
		finish_time := time.now()
		frame_duration := time.diff(start_time, finish_time)
		wait_duration := max(16_666_667 * time.Nanosecond - frame_duration, 0)
		time.accurate_sleep(wait_duration)
		frame_count += 1
		if (frame_count >= FRAMES_PER_ANIMATION_CYCLE) {
			frame_count = 0
			current_idle_uv = (current_idle_uv + 1) % 4
		}
	}
	vk.DeviceWaitIdle(renderer.device)
	deinit_renderer(&renderer)
}
