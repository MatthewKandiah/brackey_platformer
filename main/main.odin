package main

import "core:fmt"
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
		glfw.PollEvents()
		draw_frame(&renderer)
	}
	vk.DeviceWaitIdle(renderer.device)
	deinit_renderer(&renderer)
}
