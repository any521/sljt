extends Control
## Editable pixel dissolve overlay. Cover before changing rooms, reveal afterwards.

@export_range(0.1, 2.0, 0.01) var cover_seconds := 0.55
@export_range(0.1, 2.0, 0.01) var reveal_seconds := 0.47
@onready var veil: ColorRect = $Veil

var _motion: Tween

func _ready() -> void:
	hide()
	_set_progress(0.0)

func cover() -> void:
	if _motion != null and _motion.is_valid(): _motion.kill()
	show()
	_set_progress(0.0)
	_motion = create_tween()
	_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_method(_set_progress, 0.0, 1.0, cover_seconds)
	await _motion.finished

func reveal() -> void:
	if _motion != null and _motion.is_valid(): _motion.kill()
	show()
	_set_progress(1.0)
	_motion = create_tween()
	_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_method(_set_progress, 1.0, 0.0, reveal_seconds)
	await _motion.finished
	hide()

func _set_progress(value: float) -> void:
	(veil.material as ShaderMaterial).set_shader_parameter("progress", value)
