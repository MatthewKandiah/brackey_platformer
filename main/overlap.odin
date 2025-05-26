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
	if !single_intersection_exists {return parallel_lines_intersect(a, b)}

	// Note - can conclude if 0 <= t <= 1 and 0 <= u <= 1 without divisions to improve performance
	t := t_num / den
	u := u_num / den
	return t >= 0 && t <= 1 && u >= 0 && u <= 1
}

parallel_lines_intersect :: proc(a: Line, b: Line) -> bool {
	// assumed that the lines are already known to be parallel
	// if the lines both intersect the same point at x = 0, then they are colinear
	// use y = mx + c
	ma := (a.end.y - a.start.y) / (a.end.x - a.start.x)
	ca := a.start.y - ma * a.start.x
	mb := (b.end.y - b.start.y) / (b.end.x - b.start.x)
	cb := b.start.y - mb * b.start.x
	float_comparison_tolerance := min(ca, cb) / 1000
	if abs(ca - cb) < float_comparison_tolerance {
		// lines are colinear, therefore overlapping if ranges overlap
		a_left := min(a.start.x, a.end.x)
		a_right := max(a.start.x, a.end.x)
		a_top := max(a.start.y, a.end.y)
		a_bot := min(a.start.y, a.end.y)
		b_left := min(b.start.x, b.end.x)
		b_right := max(b.start.x, b.end.x)
		b_top := max(b.start.y, b.end.y)
		b_bot := min(b.start.y, b.end.y)
		return !(a_left > b_right || b_left > a_right || a_bot > b_top || b_bot > a_top)
	}
	return false
}

line_intersects_quad :: proc(l: Line, quad_p: Pos, quad_d: Dim) -> bool {
	top := quad_p.y + quad_d.h
	bot := quad_p.y
	left := quad_p.x - quad_d.w / 2
	right := quad_p.x + quad_d.w / 2
	q_top_left := Pos {
		x = left,
		y = top,
	}
	q_top_right := Pos {
		x = right,
		y = top,
	}
	q_bot_left := Pos {
		x = left,
		y = bot,
	}
	q_bot_right := Pos {
		x = right,
		y = bot,
	}
	if lines_intersect(l, {q_top_left, q_top_right}) {return true}
	if lines_intersect(l, {q_top_right, q_bot_right}) {return true}
	if lines_intersect(l, {q_bot_right, q_bot_left}) {return true}
	if lines_intersect(l, {q_bot_left, q_top_left}) {return true}
	return false
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
	corner_allowance_x := player_d.w / 3
	corner_allowance_y := player_d.h / 10

	bot_line := Line {
		start = {x = player_left + corner_allowance_x, y = player_bot},
		end = {x = player_right - corner_allowance_x, y = player_bot},
	}
	top_line := Line {
		start = {x = player_left + corner_allowance_x, y = player_top},
		end = {x = player_right - corner_allowance_x, y = player_top},
	}
	left_line := Line {
		start = {x = player_left, y = player_top - corner_allowance_y},
		end = {x = player_left, y = player_bot + corner_allowance_y},
	}
	right_line := Line {
		start = {x = player_right, y = player_top - corner_allowance_y},
		end = {x = player_right, y = player_bot + corner_allowance_y},
	}
	overlap_info.bot = line_intersects_quad(bot_line, quad_p, quad_d)
	overlap_info.top = line_intersects_quad(top_line, quad_p, quad_d)
	overlap_info.left = line_intersects_quad(left_line, quad_p, quad_d)
	overlap_info.right = line_intersects_quad(right_line, quad_p, quad_d)
	return overlap_info
}
