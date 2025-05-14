package main

import "core:fmt"
import "core:math/linalg/glsl"
import "core:time"
import glfw "vendor:glfw"
import vk "vendor:vulkan"

MAX_DRAWABLE_COUNT :: 100_000
VERTEX_BUFFER_SIZE :: 4 * MAX_DRAWABLE_COUNT * size_of(Vertex)
INDEX_BUFFER_SIZE :: 6 * MAX_DRAWABLE_COUNT * size_of(u32)
VERTEX_BACKING_BUFFER: [4 * MAX_DRAWABLE_COUNT]Vertex
INDEX_BACKING_BUFFER: [6 * MAX_DRAWABLE_COUNT]u32

GlobalContext :: struct {
	framebuffer_resized: bool,
	vk_instance:         vk.Instance,
}

gc: GlobalContext
NANOSECONDS_PER_FRAME :: 16_666_667

Pos :: struct {
	x, y: f32,
}

Dim :: struct {
	w, h: f32,
}

Drawable :: struct {
	pos:          Pos,
	dim:          Dim,
	tex_idx:      u32,
	tex_base_pos: Pos,
	tex_dim:      Dim,
}

get_draw_data :: proc(drawables: []Drawable) -> (vertices: []Vertex, indices: []u32) {
  if len(drawables) > MAX_DRAWABLE_COUNT {
    panic("Cannot fit drawables into allocated vertex and index buffers")
  }
	for drawable, i in drawables {
		using drawable
		VERTEX_BACKING_BUFFER[4 * i + 0] = {
			{pos.x - dim.w / 2, pos.y - dim.h},
			{tex_base_pos.x, tex_base_pos.y},
			tex_idx,
		}
		VERTEX_BACKING_BUFFER[4 * i + 1] = {
			{pos.x + dim.w / 2, pos.y - dim.h},
			{tex_base_pos.x + tex_dim.w, tex_base_pos.y},
			tex_idx,
		}
		VERTEX_BACKING_BUFFER[4 * i + 2] = {
			{pos.x + dim.w / 2, pos.y},
			{tex_base_pos.x + tex_dim.w, tex_base_pos.y + tex_dim.h},
			tex_idx,
		}
		VERTEX_BACKING_BUFFER[4 * i + 3] = {
			{pos.x - dim.w / 2, pos.y},
			{tex_base_pos.x, tex_base_pos.y + tex_dim.h},
			tex_idx,
		}

		INDEX_BACKING_BUFFER[6 * i + 0] = cast(u32)(4 * i + 0)
		INDEX_BACKING_BUFFER[6 * i + 1] = cast(u32)(4 * i + 1)
		INDEX_BACKING_BUFFER[6 * i + 2] = cast(u32)(4 * i + 2)
		INDEX_BACKING_BUFFER[6 * i + 3] = cast(u32)(4 * i + 2)
		INDEX_BACKING_BUFFER[6 * i + 4] = cast(u32)(4 * i + 3)
		INDEX_BACKING_BUFFER[6 * i + 5] = cast(u32)(4 * i + 0)
	}
	return VERTEX_BACKING_BUFFER[0:len(drawables) * 4], INDEX_BACKING_BUFFER[0:len(drawables) * 6]
}

drawables := []Drawable {
	{
		pos = {-0.80, 0.25},
		dim = {0.5, 0.5},
		tex_idx = 0,
		tex_base_pos = {0, 0},
		tex_dim = {32, 32},
	},
	{
		pos = {-0.3, 0.25},
		dim = {0.5, 0.25},
		tex_idx = 0,
		tex_base_pos = {32, 0},
		tex_dim = {32, 32},
	},
	{
		pos = {0.20, 0.25},
		dim = {0.5, 1.0},
		tex_idx = 0,
		tex_base_pos = {64, 0},
		tex_dim = {32, 32},
	},
	{
		pos = {0.70, 0.25},
		dim = {0.8, 0.8},
		tex_idx = 1,
		tex_base_pos = {80, 0},
		tex_dim = {16, 16},
	},
}

main :: proc() {
	context.user_ptr = &gc

	renderer := init_renderer()

	for !glfw.WindowShouldClose(renderer.window) {
		start_time := time.now()
		glfw.PollEvents()

		vertices, indices := get_draw_data(drawables)

		draw_frame(&renderer, vertices, indices)
		finish_time := time.now()
		frame_duration := time.diff(start_time, finish_time)
		wait_duration := max(NANOSECONDS_PER_FRAME * time.Nanosecond - frame_duration, 0)
		time.accurate_sleep(wait_duration)
	}
	vk.DeviceWaitIdle(renderer.device)
	deinit_renderer(&renderer)
}
