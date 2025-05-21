package main

/*
  All animation frames must be contained within a single texture and are assumed to have the same uv dimensions, and each is assumed to be held for the same number of frames
*/
Animation :: struct {
	tex_idx:           u32,
	tex_dim:           Dim,
	tex_base_pos_list: []Pos,
	duration_frames:   int,
}

player_idle := Animation {
	tex_idx           = 0,
	tex_dim           = {32, 28},
	tex_base_pos_list = {{0, 0}, {32, 0}, {64, 0}, {96, 0}},
	duration_frames   = 6,
}
