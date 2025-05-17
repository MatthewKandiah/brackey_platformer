package main

import "base:intrinsics"
import "core:fmt"
import "core:mem"

Game :: struct {
	game_map: Map,
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
