package main

import "core:fmt"
import "core:time"
import glfw "vendor:glfw"
import vk "vendor:vulkan"

GlobalContext :: struct {
	framebuffer_resized: bool,
	vk_instance:         vk.Instance,
}

gc: GlobalContext

vertices :: []Vertex {
	{{-0.5, -0.5}, {0, 0}},
	{{0.5, -0.5}, {32, 0}},
	{{0.5, 0.5}, {32, 32}},
	{{-0.5, 0.5}, {0, 32}},
}

indices :: []u32{0, 1, 2, 2, 3, 0}

main :: proc() {
	context.user_ptr = &gc

	renderer := init_renderer()

	for !glfw.WindowShouldClose(renderer.window) {
		start_time := time.now()
		glfw.PollEvents()
		draw_frame(&renderer)
		finish_time := time.now()
    frame_duration := time.diff(start_time, finish_time)
    wait_duration := max(16_666_667 * time.Nanosecond - frame_duration, 0)
    time.accurate_sleep(wait_duration)
	}
	vk.DeviceWaitIdle(renderer.device)
	deinit_renderer(&renderer)
}
