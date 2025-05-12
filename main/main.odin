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
NANOSECONDS_PER_FRAME :: 16_666_667
FRAMES_PER_ANIMATION_CYCLE :: 6
current_idle_uv := 0
current_coin_uv := 0
// initial values don't matter, they are overwritten each frame
global_vertices := []Vertex {
	{{-0.5, 0}, idle_uvs[current_idle_uv][0], 0},
	{{0, 0}, idle_uvs[current_idle_uv][1], 0},
	{{0, 0.5}, idle_uvs[current_idle_uv][2], 0},
	{{-0.5, 0.5}, idle_uvs[current_idle_uv][3], 0},
	{{-0.5, -0.5}, idle_uvs[current_idle_uv][0], 0},
	{{0.5, -0.5}, idle_uvs[current_idle_uv][1], 0},
	{{0.5, 0.5}, idle_uvs[current_idle_uv][2], 0},
	{{-0.5, 0.5}, idle_uvs[current_idle_uv][3], 0},
}

idle_uv_1: []glsl.vec2 : {{0, 0}, {31, 0}, {31, 31}, {0, 31}}
idle_uv_2: []glsl.vec2 : {{32, 0}, {63, 0}, {63, 31}, {32, 31}}
idle_uv_3: []glsl.vec2 : {{64, 0}, {95, 0}, {95, 31}, {64, 31}}
idle_uv_4: []glsl.vec2 : {{96, 0}, {127, 0}, {127, 31}, {96, 31}}
idle_uvs := [][]glsl.vec2{idle_uv_1, idle_uv_2, idle_uv_3, idle_uv_4}

coin_uv_1: []glsl.vec2 : {{0, 0}, {15, 0}, {15, 15}, {0, 15}}
coin_uv_2: []glsl.vec2 : {{16, 0}, {31, 0}, {31, 15}, {16, 15}}
coin_uv_3: []glsl.vec2 : {{32, 0}, {47, 0}, {47, 15}, {32, 15}}
coin_uv_4: []glsl.vec2 : {{48, 0}, {63, 0}, {63, 15}, {48, 15}}
coin_uv_5: []glsl.vec2 : {{64, 0}, {79, 0}, {79, 15}, {64, 15}}
coin_uv_6: []glsl.vec2 : {{80, 0}, {95, 0}, {95, 15}, {80, 15}}
coin_uv_7: []glsl.vec2 : {{96, 0}, {111, 0}, {111, 15}, {96, 15}}
coin_uv_8: []glsl.vec2 : {{112, 0}, {127, 0}, {127, 15}, {112, 15}}
coin_uv_9: []glsl.vec2 : {{128, 0}, {143, 0}, {143, 15}, {128, 15}}
coin_uv_10: []glsl.vec2 : {{144, 0}, {159, 0}, {159, 15}, {144, 15}}
coin_uv_11: []glsl.vec2 : {{160, 0}, {175, 0}, {175, 15}, {160, 15}}
coin_uv_12: []glsl.vec2 : {{176, 0}, {191, 0}, {191, 15}, {176, 15}}
coin_uvs := [][]glsl.vec2 {
	coin_uv_1,
	coin_uv_2,
	coin_uv_3,
	coin_uv_4,
	coin_uv_5,
	coin_uv_6,
	coin_uv_7,
	coin_uv_8,
	coin_uv_9,
	coin_uv_10,
	coin_uv_11,
	coin_uv_12,
}

global_indices :: []u32{0, 1, 2, 2, 3, 0, 4, 5, 6, 6, 7, 4}

main :: proc() {
	context.user_ptr = &gc

	renderer := init_renderer()

	frame_count := 0
	for !glfw.WindowShouldClose(renderer.window) {
		start_time := time.now()
		glfw.PollEvents()

		global_vertices = []Vertex {
			{{-0.5, -0.25}, idle_uvs[current_idle_uv][0], 0},
			{{0, -0.25}, idle_uvs[current_idle_uv][1], 0},
			{{0, 0.25}, idle_uvs[current_idle_uv][2], 0},
			{{-0.5, 0.25}, idle_uvs[current_idle_uv][3], 0},
			{{0, 0}, coin_uvs[current_coin_uv][0], 1},
			{{0.25, 0}, coin_uvs[current_coin_uv][1], 1},
			{{0.25, 0.25}, coin_uvs[current_coin_uv][2], 1},
			{{0, 0.25}, coin_uvs[current_coin_uv][3], 1},
		}

		draw_frame(&renderer, global_vertices, global_indices)
		finish_time := time.now()
		frame_duration := time.diff(start_time, finish_time)
		wait_duration := max(NANOSECONDS_PER_FRAME * time.Nanosecond - frame_duration, 0)
		time.accurate_sleep(wait_duration)
		frame_count += 1
		if (frame_count >= FRAMES_PER_ANIMATION_CYCLE) {
			frame_count = 0
			current_idle_uv = (current_idle_uv + 1) % len(idle_uvs)
			current_coin_uv = (current_coin_uv + 1) % len(coin_uvs)
		}
	}
	vk.DeviceWaitIdle(renderer.device)
	deinit_renderer(&renderer)
}
