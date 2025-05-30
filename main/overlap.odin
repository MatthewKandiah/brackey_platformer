package main

OverlapInfo :: struct {
	n:  bool,
	ne: bool,
	e:  bool,
	se: bool,
	s:  bool,
	sw: bool,
	w:  bool,
	nw: bool,
}

any_overlapping :: proc(using o: OverlapInfo) -> bool {
	return n || e || s || w || ne || se || sw || nw
}

NON_OVERLAPPING :: OverlapInfo {
	n  = false,
	ne = false,
	e  = false,
	se = false,
	s  = false,
	sw = false,
	w  = false,
	nw = false,
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

	single_intersection_exists := den != 0
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
	if pos_contained_within_quad(l.start, quad_p, quad_d) &&
	   pos_contained_within_quad(l.end, quad_p, quad_d) {return true}
	if lines_intersect(l, {q_top_left, q_top_right}) {return true}
	if lines_intersect(l, {q_top_right, q_bot_right}) {return true}
	if lines_intersect(l, {q_bot_right, q_bot_left}) {return true}
	if lines_intersect(l, {q_bot_left, q_top_left}) {return true}
	return false
}

pos_contained_within_quad :: proc(p: Pos, quad_p: Pos, quad_d: Dim) -> bool {
	top := quad_p.y + quad_d.h
	bot := quad_p.y
	left := quad_p.x - quad_d.w / 2
	right := quad_p.x + quad_d.w / 2
	return p.x > left && p.x < right && p.y < top && p.y > bot
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
	corner_allowance_x := player_d.w / 10
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
	bot_right_line := Line {
		start = {x = player_right - corner_allowance_x, y = player_bot},
		end = {x = player_right, y = player_bot + corner_allowance_y},
	}
	bot_left_line := Line {
		start = {x = player_left + corner_allowance_x, y = player_bot},
		end = {x = player_left, y = player_bot + corner_allowance_y},
	}
	top_right_line := Line {
		start = {x = player_right - corner_allowance_x, y = player_top},
		end = {x = player_right, y = player_top - corner_allowance_y},
	}
	top_left_line := Line {
		start = {x = player_left + corner_allowance_x, y = player_top},
		end = {x = player_left, y = player_top - corner_allowance_y},
	}
	overlap_info.s = line_intersects_quad(bot_line, quad_p, quad_d)
	overlap_info.n = line_intersects_quad(top_line, quad_p, quad_d)
	overlap_info.w = line_intersects_quad(left_line, quad_p, quad_d)
	overlap_info.e = line_intersects_quad(right_line, quad_p, quad_d)
	overlap_info.se = line_intersects_quad(bot_right_line, quad_p, quad_d)
	overlap_info.sw = line_intersects_quad(bot_left_line, quad_p, quad_d)
	overlap_info.ne = line_intersects_quad(top_right_line, quad_p, quad_d)
	overlap_info.nw = line_intersects_quad(top_left_line, quad_p, quad_d)
	return overlap_info
}

import "core:testing"
@(test)
non_overlapping_non_parallel :: proc(t: ^testing.T) {
	line1 := Line {
		start = {1, 2},
		end   = {3, 4},
	}
	line2 := Line {
		start = {2, 6},
		end   = {2.5, 4},
	}
	testing.expect(t, !lines_intersect(line1, line2))
	testing.expect(t, !lines_intersect(line2, line1))
}

@(test)
non_overlapping_parallel :: proc(t: ^testing.T) {
	line1 := Line {
		start = {1, 2},
		end   = {3, 4},
	}
	line2 := Line {
		start = {6, 6},
		end   = {7, 7},
	}
	testing.expect(t, !lines_intersect(line1, line2))
	testing.expect(t, !lines_intersect(line2, line1))
}

@(test)
non_overlapping_colinear :: proc(t: ^testing.T) {
	line1 := Line {
		start = {1, 2},
		end   = {3, 4},
	}
	line2 := Line {
		start = {6, 7},
		end   = {7, 8},
	}
	testing.expect(t, !lines_intersect(line1, line2))
	testing.expect(t, !lines_intersect(line2, line1))
}

@(test)
overlapping_non_parallel :: proc(t: ^testing.T) {
	line1 := Line {
		start = {1, 2},
		end   = {3, 4},
	}
	line2 := Line {
		start = {2, 6},
		end   = {4, -10},
	}
	testing.expect(t, lines_intersect(line1, line2))
	testing.expect(t, lines_intersect(line2, line1))
}

@(test)
overlapping_colinear :: proc(t: ^testing.T) {
	line1 := Line {
		start = {1, 2},
		end   = {3, 4},
	}
	line2 := Line {
		start = {2, 3},
		end   = {7, 8},
	}
	testing.expect(t, lines_intersect(line1, line2))
	testing.expect(t, lines_intersect(line2, line1))
}

@(test)
non_overlapping_line_and_quad :: proc(t: ^testing.T) {
	line := Line {
		start = {1, 2},
		end   = {3, 4},
	}
	quad_p := Pos{8, 4}
	quad_d := Dim{1, 1}
	testing.expect(t, !line_intersects_quad(line, quad_p, quad_d))
}

@(test)
overlaps_quad_top :: proc(t: ^testing.T) {
	line := Line {
		start = {3, 10},
		end   = {6, 0},
	}
	quad_p := Pos{5, 0}
	quad_d := Dim{10, 5}
	testing.expect(t, line_intersects_quad(line, quad_p, quad_d))
}

@(test)
overlaps_quad_bot :: proc(t: ^testing.T) {
	line := Line {
		start = {3, -10},
		end   = {6, 0},
	}
	quad_p := Pos{5, 0}
	quad_d := Dim{10, 5}
	testing.expect(t, line_intersects_quad(line, quad_p, quad_d))
}

@(test)
overlaps_quad_left :: proc(t: ^testing.T) {
	line := Line {
		start = {-5, -2},
		end   = {5, 3},
	}
	quad_p := Pos{5, 0}
	quad_d := Dim{10, 5}
	testing.expect(t, line_intersects_quad(line, quad_p, quad_d))
}

@(test)
overlaps_quad_right :: proc(t: ^testing.T) {
	line := Line {
		start = {15, 2},
		end   = {5, 3},
	}
	quad_p := Pos{5, 0}
	quad_d := Dim{10, 5}
	testing.expect(t, line_intersects_quad(line, quad_p, quad_d))
}

@(test)
line_inside_quad_overlaps_it :: proc(t: ^testing.T) {
	line := Line {
		start = {1, 2},
		end   = {3, 4},
	}
	quad_p := Pos{0, 0}
	quad_d := Dim{100, 100}
	testing.expect(t, line_intersects_quad(line, quad_p, quad_d))
}
