package main

OverlapInfo :: struct {
	top:   bool,
	bot:   bool,
	left:  bool,
	right: bool,
}

any_overlapping :: proc(using o: OverlapInfo) -> bool {
	return top || bot || left || right
}

NON_OVERLAPPING :: OverlapInfo {
	top   = false,
	bot   = false,
	left  = false,
	right = false,
}

ALL_OVERLAPPING :: OverlapInfo {
	top   = true,
	bot   = true,
	left  = true,
	right = true,
}

Line :: struct {
	start: Pos,
	end:   Pos,
}

lines_intersect :: proc(a: Line, b: Line) -> bool {
	// conditions derived using https://en.wikipedia.org/wiki/Line%E2%80%93line_intersection
	// formula for "Given two points on each line segment"
	// lines are not parallel or colinear => denominators non-zero
	// intersection lies on line segment => t <= 1 and u <= 1
	//                                   => signs of numerators != signs of denominators
	x1 := a.start.x
	x2 := a.end.x
	x3 := b.start.x
	x4 := b.end.x
	y1 := a.start.y
	y2 := a.end.y
	y3 := b.start.y
	y4 := b.end.y

	t_num := (x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)
	u_num := (y1 - y2) * (x1 - x3) - (x1 - x2) * (y1 - y3)
	den := (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)

  single_intersection_exists := den == 0
  if !single_intersection_exists {return colinear_lines_intersect(a, b)}

  // Note - can conclude if 0 <= t <= 1 and 0 <= u <= 1 without divisions to improve performance
  t := t_num / den
  u := u_num / den
  return t >= 0 && t <= 1 && u >= 0 && u <= 1
}

colinear_lines_intersect :: proc(a: Line, b: Line) -> bool {
  TODO()
}

horizontal_line_overlaps_quad :: proc(left, right, y: f32, quad_p: Pos, quad_d: Dim) -> bool {
	if left >= right {panic("left must be less than right")}
	quad_top := quad_p.y + quad_d.h
	quad_bot := quad_p.y
	quad_left := quad_p.x - quad_d.w / 2
	quad_right := quad_p.x + quad_d.w / 2
	return !(y > quad_top || y < quad_bot || right < quad_left || left > quad_right)
}

vertical_line_overlaps_quad :: proc(bot, top, x: f32, quad_p: Pos, quad_d: Dim) -> bool {
	if bot >= top {panic("bot must be less than top")}
	quad_top := quad_p.y + quad_d.h
	quad_bot := quad_p.y
	quad_left := quad_p.x - quad_d.w / 2
	quad_right := quad_p.x + quad_d.w / 2
	return !(x < quad_left || x > quad_right || bot > quad_top || top < quad_bot)
}

player_overlaps_quad :: proc(
	player_p: Pos,
	player_d: Dim,
	quad_p: Pos,
	quad_d: Dim,
) -> OverlapInfo {
	player_top := player_p.y + player_d.h
	player_bot := player_p.y
	player_left := player_p.x - player_d.w / 2
	player_right := player_p.x + player_d.w / 2

	quad_top := quad_p.y + quad_d.h
	quad_bot := quad_p.y
	quad_left := quad_p.x - quad_d.w / 2
	quad_right := quad_p.x + quad_d.w / 2

	if player_bot > quad_top ||
	   quad_bot > player_top ||
	   player_right < quad_left ||
	   quad_right < player_left {return NON_OVERLAPPING}

	overlap_info: OverlapInfo = NON_OVERLAPPING
	corner_allowance_x := (player_right - player_left) / 3
	if corner_allowance_x <= 0 {panic("Unexpected player x-dimensions")}
	corner_allowance_y := (player_top - player_bot) / 10
	if corner_allowance_y <= 0 {panic("Unexpected player y-dimensions")}
	overlap_info.bot = horizontal_line_overlaps_quad(
		player_left + corner_allowance_x,
		player_right - corner_allowance_x,
		player_bot,
		quad_p,
		quad_d,
	)
	overlap_info.top = horizontal_line_overlaps_quad(
		player_left + corner_allowance_x,
		player_right - corner_allowance_x,
		player_top,
		quad_p,
		quad_d,
	)
	overlap_info.left = vertical_line_overlaps_quad(
		player_bot + corner_allowance_y,
		player_top - corner_allowance_y,
		player_left,
		quad_p,
		quad_d,
	)
	overlap_info.right = vertical_line_overlaps_quad(
		player_bot + corner_allowance_y,
		player_top - corner_allowance_y,
		player_right,
		quad_p,
		quad_d,
	)
	return overlap_info
}
