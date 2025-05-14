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

get_draw_data :: proc(
	screen_height_over_width: f32,
	drawables: []Drawable,
) -> (
	vertices: []Vertex,
	indices: []u32,
) {
	if len(drawables) > MAX_DRAWABLE_COUNT {
		panic("Cannot fit drawables into allocated vertex and index buffers")
	}
	for drawable, i in drawables {
		width_world_to_screen_factor: f32 = 0.2
		height_world_to_screen_factor: f32 =
			width_world_to_screen_factor * screen_height_over_width
		scaled_pos: Pos = {
			drawable.pos.x * width_world_to_screen_factor,
			drawable.pos.y * height_world_to_screen_factor,
		}
		scaled_dim: Dim = {
			drawable.dim.w * width_world_to_screen_factor,
			drawable.dim.h * height_world_to_screen_factor,
		}
		VERTEX_BACKING_BUFFER[4 * i + 0] = {
			{scaled_pos.x - scaled_dim.w / 2, scaled_pos.y - scaled_dim.h},
			{drawable.tex_base_pos.x, drawable.tex_base_pos.y},
			drawable.tex_idx,
		}
		VERTEX_BACKING_BUFFER[4 * i + 1] = {
			{scaled_pos.x + scaled_dim.w / 2, scaled_pos.y - scaled_dim.h},
			{drawable.tex_base_pos.x + drawable.tex_dim.w, drawable.tex_base_pos.y},
			drawable.tex_idx,
		}
		VERTEX_BACKING_BUFFER[4 * i + 2] = {
			{scaled_pos.x + scaled_dim.w / 2, scaled_pos.y},
			{
				drawable.tex_base_pos.x + drawable.tex_dim.w,
				drawable.tex_base_pos.y + drawable.tex_dim.h,
			},
			drawable.tex_idx,
		}
		VERTEX_BACKING_BUFFER[4 * i + 3] = {
			{scaled_pos.x - scaled_dim.w / 2, scaled_pos.y},
			{drawable.tex_base_pos.x, drawable.tex_base_pos.y + drawable.tex_dim.h},
			drawable.tex_idx,
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

drawables := []Drawable {
	solid(pos = {-2, -2}),
	solid(pos = {-1, -1}),
	knight(pos = {0, 0}),
	solid(pos = {1, 1}),
	solid(pos = {2, 2}),
}

main :: proc() {
	context.user_ptr = &gc

	renderer := init_renderer()

	for !glfw.WindowShouldClose(renderer.window) {
		start_time := time.now()
		glfw.PollEvents()

		vertices, indices := get_draw_data(
			cast(f32)renderer.surface_extent.width / cast(f32)renderer.surface_extent.height,
			drawables,
		)

		draw_frame(&renderer, vertices, indices)
		finish_time := time.now()
		frame_duration := time.diff(start_time, finish_time)
		wait_duration := max(NANOSECONDS_PER_FRAME * time.Nanosecond - frame_duration, 0)
		time.accurate_sleep(wait_duration)
	}
	vk.DeviceWaitIdle(renderer.device)
	deinit_renderer(&renderer)
}
