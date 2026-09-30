extends Control
## Holographic route edge: dashed while undecided, solid after traversal.

@export var normal_color := Color("315264")
@export var available_color := Color("62cfff")
@export var traversed_color := Color("63d4ed")
@export var shortcut_color := Color("8d7046")
@export var active_shortcut_color := Color("ffd27a")
@export_range(1.0, 8.0, 0.5) var line_width := 2.0
@export_range(4.0, 30.0, 1.0) var dash_length := 13.0
@export_range(3.0, 24.0, 1.0) var dash_gap := 10.0

var _path := PackedVector2Array()
var _state := "locked"
var _shortcut := false
var _dash_phase := 0.0
var _reveal_progress := 0.0


func configure(from_point: Vector2, to_point: Vector2, state: String, shortcut: bool = false) -> void:
	_shortcut = shortcut
	_state = state
	# Shortcuts stay on their own lane. A wide detour can cut through several
	# ordinary branches and makes the graph ambiguous.
	_path = PackedVector2Array([from_point, to_point])
	_reveal_progress = 1.0 if state == "traversed" else 0.0
	set_process(state == "available")
	queue_redraw()


func reveal(duration: float = 0.7) -> void:
	_state = "revealing"
	_reveal_progress = 0.0
	set_process(true)
	var tween := create_tween()
	tween.tween_method(_set_reveal_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_state = "traversed"
	_reveal_progress = 1.0
	set_process(false)
	queue_redraw()


func _set_reveal_progress(value: float) -> void:
	_reveal_progress = value
	queue_redraw()


func _process(delta: float) -> void:
	_dash_phase = fmod(_dash_phase + delta * 24.0, dash_length + dash_gap)
	queue_redraw()


func _draw() -> void:
	if _path.size() < 2:
		return
	var base_color := shortcut_color if _shortcut else normal_color
	if _state in ["available", "revealing"]:
		base_color = active_shortcut_color if _shortcut else available_color
	_draw_dashed(base_color)
	if _state in ["traversed", "revealing"]:
		var solid_color := active_shortcut_color if _shortcut else traversed_color
		_draw_partial_solid(solid_color, _reveal_progress)


func _draw_dashed(color: Color) -> void:
	var shown := color
	shown.a = 0.9 if _state in ["available", "revealing"] else 0.42
	if _state in ["available", "revealing"]:
		var glow := shown
		glow.a = 0.16
		for i in range(_path.size() - 1):
			draw_line(_path[i], _path[i + 1], glow, line_width + 4.0, true)
	for i in range(_path.size() - 1):
		_draw_dashed_segment(_path[i], _path[i + 1], shown)


func _draw_dashed_segment(from_point: Vector2, to_point: Vector2, color: Color) -> void:
	var delta := to_point - from_point
	var length := delta.length()
	if length <= 0.01:
		return
	var direction := delta / length
	var cycle := dash_length + dash_gap
	var cursor := -_dash_phase
	while cursor < length:
		var dash_start := maxf(cursor, 0.0)
		var dash_end := minf(cursor + dash_length, length)
		if dash_end > dash_start:
			draw_line(from_point + direction * dash_start, from_point + direction * dash_end, color, line_width, true)
		cursor += cycle


func _draw_partial_solid(color: Color, progress: float) -> void:
	var total := 0.0
	for i in range(_path.size() - 1):
		total += _path[i].distance_to(_path[i + 1])
	var remaining := total * clampf(progress, 0.0, 1.0)
	var glow := color
	glow.a = 0.24
	for i in range(_path.size() - 1):
		if remaining <= 0.0:
			break
		var from_point := _path[i]
		var to_point := _path[i + 1]
		var segment_length := from_point.distance_to(to_point)
		var amount := minf(remaining, segment_length)
		var endpoint := from_point.lerp(to_point, amount / maxf(segment_length, 0.001))
		draw_line(from_point, endpoint, glow, line_width + 6.0, true)
		draw_line(from_point, endpoint, color, line_width + 1.0, true)
		remaining -= segment_length
