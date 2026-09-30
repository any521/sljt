extends Node

var total_frames := 120
var every := 40
var max_shots := 3
var out_dir := ""
var frame_count := 0
var shot_count := 0

func _ready() -> void:
	total_frames = _int_env("DSH_GODOT_FRAMES", 120)
	every = _int_env("DSH_GODOT_EVERY", 40)
	max_shots = _int_env("DSH_GODOT_SHOTS", 3)
	out_dir = OS.get_environment("DSH_GODOT_OUT")
	if DisplayServer.get_name() == "headless":
		max_shots = 0
	var main_path := OS.get_environment("DSH_GODOT_MAIN")
	if main_path != "":
		var packed := load(main_path)
		if packed == null:
			push_error("dsh-godot capture: cannot load main scene " + main_path)
			get_tree().quit(1)
			return
		add_child(packed.instantiate())

func _process(_delta: float) -> void:
	frame_count += 1
	if max_shots > 0 and shot_count < max_shots and frame_count >= every * (shot_count + 1):
		var image := get_viewport().get_texture().get_image()
		if image != null and not image.is_empty():
			DirAccess.make_dir_recursive_absolute(out_dir)
			image.save_png(out_dir.path_join("shot-%02d.png" % shot_count))
		shot_count += 1
	if frame_count >= total_frames:
		get_tree().quit(0)

func _int_env(key: String, fallback: int) -> int:
	var raw := OS.get_environment(key)
	if raw == "":
		return fallback
	return int(raw)
