package main

/*
  All animation frames must be contained within a single texture and are assumed to have the same uv dimensions, and each is assumed to be held for the same number of frames
*/
AnimationType :: enum {
	player_idle,
	player_run,
}

Animation :: struct {
	type:              AnimationType,
	tex_idx:           u32,
	tex_dim:           Dim,
	tex_base_pos_list: []Pos,
	duration_frames:   int,
}

player_idle := Animation {
	type              = .player_idle,
	tex_idx           = 0,
	tex_dim           = {32, 28},
	tex_base_pos_list = {{0, 0}, {32, 0}, {64, 0}, {96, 0}},
	duration_frames   = 6,
}

player_run := Animation {
	type              = .player_run,
	tex_idx           = 0,
	tex_dim           = {32, 28},
	tex_base_pos_list = {
		{0, 64},
		{32, 64},
		{64, 64},
		{96, 64},
		{128, 64},
		{160, 64},
		{192, 64},
		{224, 64},
		{0, 96},
		{32, 96},
		{64, 96},
		{96, 96},
		{128, 96},
		{160, 96},
		{192, 96},
		{224, 96},
	},
	duration_frames   = 6,
}
