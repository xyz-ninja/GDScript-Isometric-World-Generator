extends Node2D

var draw_lines = []

class Line:
	var start_pos = Vector2()
	var final_pos = Vector2()
	var draw_color = Color()

	var show_once = true

	var already_painted = false

	func _init(_s_pos, _f_pos, _d_color):
		start_pos = _s_pos
		final_pos = _f_pos
		draw_color = _d_color

func _ready():
	set_process(true)

func _process(delta):
	update()

func _draw():
	for line in draw_lines:
		if !line.already_painted:
			draw_line(line.start_pos, line.final_pos, line.draw_color)
			if line.show_once:
				line.already_painted = true

func paint_line(_s_pos, _f_pos, _color, _show_once = true):
	var l = Line.new(_s_pos, _f_pos, _color)
	if !_show_once:
		l.show_once = false

	draw_lines.append(l)
	
func clear_graphics():
	for l in draw_lines:
		draw_lines.erase(l)