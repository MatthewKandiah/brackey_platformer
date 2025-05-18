package main

import "base:intrinsics"
import "core:fmt"
import "core:mem"

Game :: struct {
	game_map: Map,
	player:   Player,
}

MAP_BASE_WORLD_POS :: Pos{0, 0}
MAP_TILE_WORLD_DIM :: Dim{0.5, 0.5}
game_to_drawables :: proc(game: Game) -> []Drawable {
	map_drawable_count := len(game.game_map.tiles)
	total_drawable_count := map_drawable_count
	map_to_drawables(
		game.game_map,
		MAP_BASE_WORLD_POS,
		MAP_TILE_WORLD_DIM,
		DRAWABLE_BACKING_BUFFER[0:map_drawable_count],
	)
	DRAWABLE_BACKING_BUFFER[map_drawable_count] = player_to_drawable(game.player)
	total_drawable_count += 1
	drawables := DRAWABLE_BACKING_BUFFER[0:total_drawable_count]
	return drawables
}

Player :: struct {
	pos: Pos,
	vel: Vel,
}

init_player :: proc() -> Player {
	return {pos = {0, 0}, vel = {0, 0}}
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
	width: int,
	tiles: []MapTile,
}

MapTile :: enum {
	empty,
	grass,
	dirt,
}

init_map :: proc() -> (m: Map) {
	m.width = 5
	tiles := []MapTile {
		.grass,
		.grass,
		.grass,
		.grass,
		.grass,
		.dirt,
		.dirt,
		.dirt,
		.dirt,
		.dirt,
		.grass,
		.grass,
		.empty,
		.grass,
		.grass,
		.dirt,
		.dirt,
		.dirt,
		.dirt,
		.dirt,
		.grass,
		.grass,
		.grass,
		.grass,
		.grass,
	}
	m.tiles = make([]MapTile, len(tiles))
	intrinsics.mem_copy_non_overlapping(
		raw_data(m.tiles),
		raw_data(tiles),
		size_of(MapTile) * len(tiles),
	)
	return m
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

map_to_drawables :: proc(
	m: Map,
	base_world_pos: Pos,
	tile_world_dim: Dim,
	drawables_buf: []Drawable,
) {
	if len(m.tiles) > len(drawables_buf) {panic("map won't fit in drawables slice")}
	for tile, idx in m.tiles {
		x_disp := base_world_pos.x + tile_world_dim.w * cast(f32)(idx % m.width)
		y_disp := base_world_pos.y + tile_world_dim.h * cast(f32)(idx / m.width)
		tex_idx, tex_base_pos, tex_dim := map_tile_tex_info(tile)
		drawable := Drawable {
			pos          = {base_world_pos.x + x_disp, base_world_pos.y + y_disp},
			dim          = tile_world_dim,
			tex_idx      = tex_idx,
			tex_dim      = tex_dim,
			tex_base_pos = tex_base_pos,
		}
		drawables_buf[idx] = drawable
	}
}
