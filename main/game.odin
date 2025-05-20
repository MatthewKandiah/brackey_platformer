package main

import "base:intrinsics"
import "core:fmt"
import "core:mem"
import "vendor:glfw"

Game :: struct {
	game_map: Map,
	player:   Player,
}

FALLING_SPEED :: 0.04
FALLING_ACCEL :: 0.0025
MAP_BASE_WORLD_POS :: Pos{0, 0}
MAP_TILE_WORLD_DIM :: Dim{0.5, 0.5}
game_to_drawables :: proc(game: Game) -> []Drawable {
	total_drawable_count := 0

	DRAWABLE_BACKING_BUFFER[total_drawable_count] = background_to_drawable()
	total_drawable_count += 1

	map_drawable_count := len(game.game_map.tiles)
	map_to_drawables(
		game.game_map,
		DRAWABLE_BACKING_BUFFER[total_drawable_count:total_drawable_count + map_drawable_count],
	)
	total_drawable_count += map_drawable_count

	DRAWABLE_BACKING_BUFFER[total_drawable_count] = player_to_drawable(game.player)
	total_drawable_count += 1

	return DRAWABLE_BACKING_BUFFER[0:total_drawable_count]
}

background_to_drawable :: proc() -> Drawable {
	tex_idx, tex_base_pos, tex_dim := map_tile_tex_info(.empty)
	return Drawable {
		pos = {-10, -100},
		dim = {500, 500},
		tex_idx = tex_idx,
		tex_base_pos = tex_base_pos,
		tex_dim = tex_dim,
	}
}

Player :: struct {
	pos:           Pos,
	vel:           Vel,
	collision_dim: Dim,
}

init_player :: proc() -> Player {
	return {pos = {0, 1}, vel = {0, -FALLING_SPEED}, collision_dim = {0.3, 0.6}}
}

player_to_drawable :: proc(player: Player) -> Drawable {
	original_tile_size: f32 : 32
	bottom_margin: f32 : 4
	return Drawable {
		pos = player.pos,
		dim = {1, 1},
		tex_idx = 0,
		tex_base_pos = {0, 0},
		tex_dim = {original_tile_size, original_tile_size - bottom_margin},
	}
}

Map :: struct {
	width:          int,
	tiles:          []MapTile,
	base_world_pos: Pos,
	tile_world_dim: Dim,
}

MapTile :: enum {
	empty,
	grass,
	dirt,
}

init_map :: proc() -> (m: Map) {
	m.width = 5
	m.base_world_pos = MAP_BASE_WORLD_POS
	m.tile_world_dim = MAP_TILE_WORLD_DIM
	tiles := []MapTile {
		// top
		.grass,
		.grass,
		.grass,
		.grass,
		.grass,
		//
		.dirt,
		.dirt,
		.dirt,
		.dirt,
		.dirt,
		//
		.grass,
		.grass,
		.empty,
		.grass,
		.grass,
		//
		.dirt,
		.dirt,
		.dirt,
		.dirt,
		.dirt,
		//
		.dirt,
		.dirt,
		.dirt,
		.dirt,
		.dirt,
		// bottom
	}
	m.tiles = make([]MapTile, len(tiles))
	intrinsics.mem_copy_non_overlapping(
		raw_data(m.tiles),
		raw_data(tiles),
		size_of(MapTile) * len(tiles),
	)
	return m
}

map_tile_pos :: proc(m: Map, idx: int) -> Pos {
	if idx >= len(m.tiles) {panic("idx out of bounds for map tiles")}
	x := m.base_world_pos.x + cast(f32)(idx % m.width) * m.tile_world_dim.w
	y := m.base_world_pos.y - cast(f32)(idx / m.width) * m.tile_world_dim.h
	return {x, y}
}

map_tile_tex_info :: proc(mt: MapTile) -> (tex_idx: u32, tex_base_pos: Pos, tex_dim: Dim) {
	tex_idx = 2
	tex_dim = {16, 16}
	switch mt {
	case .empty:
		tex_base_pos = {0, 176}
	case .grass:
		tex_base_pos = {0, 0}
	case .dirt:
		tex_base_pos = {16, 0}
	}
	return
}

map_to_drawables :: proc(m: Map, drawables_buf: []Drawable) {
	if len(m.tiles) > len(drawables_buf) {panic("map won't fit in drawables slice")}
	for tile, idx in m.tiles {
		x_disp := m.base_world_pos.x + m.tile_world_dim.w * cast(f32)(idx % m.width)
		y_disp := m.base_world_pos.y - m.tile_world_dim.h * cast(f32)(idx / m.width)
		tex_idx, tex_base_pos, tex_dim := map_tile_tex_info(tile)
		drawable := Drawable {
			pos          = {m.base_world_pos.x + x_disp, m.base_world_pos.y + y_disp},
			dim          = m.tile_world_dim,
			tex_idx      = tex_idx,
			tex_dim      = tex_dim,
			tex_base_pos = tex_base_pos,
		}
		drawables_buf[idx] = drawable
	}
}

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
