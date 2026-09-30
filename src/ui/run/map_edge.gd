extends Line2D

@export var normal_color := Color("3e5160")
@export var active_color := Color("6bc7ff")
@export var shortcut_color := Color("907457")
@export var active_shortcut_color := Color("ffd27a")

func configure(from_point: Vector2, to_point: Vector2, active: bool, shortcut: bool = false) -> void:
	if shortcut:
		points = PackedVector2Array([from_point, (from_point + to_point) * 0.5 + Vector2(190, 0), to_point])
	else:
		points = PackedVector2Array([from_point, to_point])
	default_color = (active_shortcut_color if active else shortcut_color) if shortcut else (active_color if active else normal_color)
