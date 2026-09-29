extends Control
## A persistent actor: idle motion never replaces its hit/death state.
var sprite: TextureRect
var base_size := Vector2(220, 340)
var idle_phase := 0.0
var dead := false
var reacting := false
var motion: Tween
var shader_material: ShaderMaterial
var animated := true
var _atlas: AtlasTexture
var _frame := 0
var _elapsed := 0.0
var _columns := 1
var _rows := 1
var _outline_width := 0.0

func setup(path: String, bounds: Vector2, flipped: bool = false, columns: int = 1, rows: int = 1) -> void:
	size = bounds
	base_size = bounds
	pivot_offset = Vector2(bounds.x * 0.5, bounds.y)
	mouse_filter = MOUSE_FILTER_IGNORE
	idle_phase = position.x * 0.01
	sprite = TextureRect.new()
	sprite.size = bounds
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	sprite.flip_h = flipped
	sprite.mouse_filter = MOUSE_FILTER_IGNORE
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_columns = columns
	_rows = rows
	if columns * rows > 1 and texture != null:
		_atlas = AtlasTexture.new()
		_atlas.atlas = texture
		_atlas.region = Rect2(0, 0, texture.get_width() / columns, texture.get_height() / rows)
		sprite.texture = _atlas
	else:
		sprite.texture = texture
	add_child(sprite)
	if ResourceLoader.exists("res://src/ui/effects/shaders/outline.gdshader"):
		shader_material = ShaderMaterial.new()
		shader_material.shader = load("res://src/ui/effects/shaders/outline.gdshader")
		shader_material.set_shader_parameter("outline_width", 0.0)
		sprite.material = shader_material

func _process(delta: float) -> void:
	if dead or not animated:
		return
	_elapsed += delta
	if _atlas != null:
		var frame := int(_elapsed * 6.0) % (_columns * _rows)
		if frame != _frame:
			_frame = frame
			var fw := _atlas.atlas.get_width() / _columns
			var fh := _atlas.atlas.get_height() / _rows
			_atlas.region = Rect2((_frame % _columns) * fw, int(_frame / _columns) * fh, fw, fh)
	if not reacting:
		sprite.position.y = sin(_elapsed * 1.7 + idle_phase) * 2.2
		sprite.scale = Vector2(1.0 + sin(_elapsed * 1.7 + idle_phase) * 0.003, 1.0 + sin(_elapsed * 1.7 + idle_phase) * 0.007)

func highlight(active: bool) -> void:
	_outline_width = 3.0 if active else 0.0
	if shader_material != null and not dead:
		shader_material.set_shader_parameter("outline_width", _outline_width)

func hit(large: bool, reduced_flash: bool, allow_motion: bool = true) -> void:
	if dead:
		return
	if motion != null and motion.is_running():
		motion.kill()
	reacting = true
	if shader_material != null:
		shader_material.set_shader_parameter("flash_amount", 0.22 if reduced_flash else 1.0)
	motion = create_tween()
	if allow_motion:
		sprite.position = Vector2(22 if large else 12, 0)
		motion.tween_property(sprite, "position", Vector2.ZERO, 0.22 if large else 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		motion.tween_interval(0.06)
	if shader_material != null:
		motion.parallel().tween_method(func(value: float): shader_material.set_shader_parameter("flash_amount", value), 0.22 if reduced_flash else 1.0, 0.0, 0.14)
	motion.tween_callback(func(): reacting = false)

func die(allow_motion: bool = true) -> void:
	if dead:
		return
	dead = true
	if motion != null:
		motion.kill()
	if ResourceLoader.exists("res://src/ui/effects/shaders/dissolve.gdshader"):
		var dissolve := ShaderMaterial.new()
		dissolve.shader = load("res://src/ui/effects/shaders/dissolve.gdshader")
		dissolve.set_shader_parameter("edge_color", Color("ff9edc"))
		sprite.material = dissolve
		motion = create_tween()
		motion.tween_method(func(value: float): dissolve.set_shader_parameter("dissolve_amount", value), 0.0, 1.0, 0.8 if allow_motion else 0.08)
	else:
		motion = create_tween()
		motion.tween_property(sprite, "modulate:a", 0.0, 0.8 if allow_motion else 0.08)

func reset_actor() -> void:
	if motion != null:
		motion.kill()
	dead = false
	reacting = false
	sprite.material = shader_material
	sprite.modulate = Color.WHITE
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE
	if shader_material != null:
		shader_material.set_shader_parameter("flash_amount", 0.0)
		highlight(false)
