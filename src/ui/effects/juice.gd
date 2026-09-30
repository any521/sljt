extends Node
## Presentation clock and accessibility controls. Core combat never depends on this node.
## All positions passed to effects are 1920 x 1080 canvas coordinates.

signal settings_changed(key: String, value: Variant)

const SETTINGS_PATH := "user://combat_presentation.cfg"
const CYAN := Color("6bc7ff")
const MAGENTA := Color("c7479e")
const GOLD := Color("ffd23f")
const GREEN := Color("7fd9a0")
const RED := Color("eb6161")
const DEFAULT_SETTINGS := {
	"shake_strength": 0.7, "reduce_flashes": false, "reduce_motion": false,
	"particles": true, "damage_numbers": true, "screen_effects": true,
	"hit_stop": true, "sound": true, "card_animations": true,
	"enemy_animations": true, "combo_effects": true, "corruption_effects": true,
	"shield_effects": true, "turn_effects": true,
}

## 预制体：全部在 juice.tscn 的检查器里拖拽赋值，代码不写文件路径。
@export var particle_prefab: PackedScene
@export var ring_prefab: PackedScene
@export var number_prefab: PackedScene
@export var sound_prefab: PackedScene

var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var trauma := 0.0
var _world: Control
var _world_origin := Vector2.ZERO
var _world_rotation := 0.0
var _world_scale := Vector2.ONE
var _clock := 0.0
var _last_usec := 0
var _time_requests: Array[Dictionary] = []
var _normal_time_scale := 1.0
var _zoom := 0.0
var _overlay: Control
var _particles: Array[ParticleGlyph] = []
var _numbers: Array[Label] = []
var _rings: Array[RingGlyph] = []
var _audio: Array[AudioStreamPlayer] = []
var _particle_cursor := 0
var _number_cursor := 0
var _ring_cursor := 0
var _audio_cursor := 0
var _flash_rect: ColorRect
var _vignette_rect: ColorRect
var _corruption_rect: ColorRect
var _chromatic_rect: ColorRect
var _banner: Label
var _banner_band: ColorRect
var _active_tweens: Array[Tween] = []
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		for key: String in DEFAULT_SETTINGS:
			if config.has_section_key("effects", key):
				settings[key] = config.get_value("effects", key, DEFAULT_SETTINGS[key])
	settings["shake_strength"] = clampf(float(settings["shake_strength"]), 0.0, 1.0)

func setup(world: Control) -> void:
	_world = world
	_world_origin = world.position
	_world_rotation = world.rotation
	_world_scale = world.scale
	world.pivot_offset = Vector2(960, 540)
	_last_usec = Time.get_ticks_usec()
	_rng.seed = 0xA4C4A9
	# 屏幕特效容器与所有屏幕特效节点都写在 juice.tscn 里，这里只做绑定 —— 编辑器可随时改。
	_overlay = get_node_or_null("PresentationFX") as Control
	if _overlay == null:
		push_error("juice.tscn 缺少 PresentationFX 节点")
		return
	_spawn_pool(_particles, particle_prefab, 128, _overlay)
	_spawn_pool(_numbers, number_prefab, 28, _overlay)
	_spawn_pool(_rings, ring_prefab, 16, _overlay)
	_spawn_pool(_audio, sound_prefab, 12, self)
	_bind_screen_fx()


## 将任意 Control 的全局画布坐标转换为 PresentationFX 的局部坐标。
## 卡牌位于 Cards/Hand，而粒子位于 Juice/PresentationFX；不能直接拿卡牌 home 坐标发射。
func effects_position_from_global(global_position: Vector2) -> Vector2:
	if _overlay == null:
		return global_position
	return _overlay.get_global_transform_with_canvas().affine_inverse() * global_position


## 对象池：脚本只负责"预制体 → instantiate → add_child"，结构在预制体里。
func _spawn_pool(target: Array, prefab: PackedScene, count: int, parent: Node) -> void:
	if prefab == null:
		push_error("juice: 对象池未赋值预制体（请在 juice.tscn 检查器里拖拽）")
		return
	for i in count:
		var node: Node = prefab.instantiate()
		if node is CanvasItem:
			(node as CanvasItem).hide()
		parent.add_child(node)
		target.append(node)

func _bind_screen_fx() -> void:
	_flash_rect = _overlay.get_node_or_null("Flash") as ColorRect
	_vignette_rect = _overlay.get_node_or_null("Vignette") as ColorRect
	_corruption_rect = _overlay.get_node_or_null("Corruption") as ColorRect
	_chromatic_rect = _overlay.get_node_or_null("Chromatic") as ColorRect
	_banner_band = _overlay.get_node_or_null("BannerBand") as ColorRect
	_banner = _overlay.get_node_or_null("Banner") as Label
	for item in [_flash_rect, _vignette_rect, _corruption_rect, _chromatic_rect, _banner_band, _banner]:
		if item == null:
			push_error("juice.tscn 的 PresentationFX 缺少屏幕特效子节点")
			return

func enabled(key: String) -> bool:
	return bool(settings.get(key, true))

func set_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	settings[key] = clampf(float(value), 0.0, 1.0) if key == "shake_strength" else bool(value)
	var config := ConfigFile.new()
	for setting: String in settings:
		config.set_value("effects", setting, settings[setting])
	config.save(SETTINGS_PATH)
	if key == "hit_stop" and not enabled("hit_stop"):
		_time_requests.clear()
		Engine.time_scale = _normal_time_scale
	settings_changed.emit(key, settings[key])

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func hit_stop(duration: float) -> void:
	_request_time_scale(0.02, duration)

func slow_motion(scale_value: float, duration: float) -> void:
	_request_time_scale(clampf(scale_value, 0.02, 1.0), duration)

func _request_time_scale(scale_value: float, duration: float) -> void:
	if not enabled("hit_stop") or duration <= 0.0:
		return
	if _time_requests.is_empty():
		_normal_time_scale = Engine.time_scale
	_time_requests.append({"until": Time.get_ticks_usec() + int(duration * 1000000.0), "scale": scale_value})
	Engine.time_scale = minf(Engine.time_scale, scale_value)

func _process(_scaled_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.1)
	_last_usec = now
	_clock += real_delta
	if not _time_requests.is_empty():
		var target_scale := _normal_time_scale
		for index in range(_time_requests.size() - 1, -1, -1):
			if now >= int(_time_requests[index]["until"]):
				_time_requests.remove_at(index)
			else:
				target_scale = minf(target_scale, float(_time_requests[index]["scale"]))
		Engine.time_scale = target_scale
	trauma = maxf(0.0, trauma - 1.25 * real_delta)
	_zoom = maxf(0.0, _zoom - real_delta * 2.9)
	if is_instance_valid(_world):
		var magnitude := trauma * trauma * float(settings["shake_strength"])
		_world.position = _world_origin + Vector2(
			0.6 * sin(_clock * 11.0) + 0.4 * sin(_clock * 23.0),
			0.6 * sin(_clock * 13.0 + 1.7) + 0.4 * sin(_clock * 29.0 + 0.5)
		) * Vector2(14, 9) * magnitude
		_world.rotation = _world_rotation
		_world.scale = _world_scale
		if not enabled("reduce_motion"):
			_world.rotation += (0.6 * sin(_clock * 9.0) + 0.4 * sin(_clock * 19.0)) * 0.055 * magnitude
			_world.scale *= 1.0 + 0.05 * _zoom

func _track(tween: Tween) -> Tween:
	_active_tweens = _active_tweens.filter(func(item): return item != null and item.is_valid())
	_active_tweens.append(tween)
	return tween

func impact(position: Vector2, large: bool = false, faction: int = 0) -> void:
	var color := MAGENTA if faction == 1 else CYAN
	add_trauma(0.80 if large else 0.35)
	hit_stop(0.12 if large else 0.05)
	burst(position, "slime" if faction == 1 else "spark", 30 if large else 10)
	burst(position, "tissue" if faction == 1 else "shard", 10 if large else 4)
	ring(position, color, large)
	if enabled("screen_effects"):
		flash(Color(1, 1, 1), 0.13 if large else 0.055)
		if large and not enabled("reduce_motion"): _zoom = 1.0

func burst(position: Vector2, kind: String, count: int = 10) -> void:
	if not enabled("particles") or _particles.is_empty():
		return
	var palette := _particle_palette(kind)
	for i in mini(count, _particles.size()):
		var particle := _particles[_particle_cursor % _particles.size()]
		_particle_cursor += 1
		if particle.motion != null and particle.motion.is_valid(): particle.motion.kill()
		particle.kind = kind
		particle.tint = palette[i % palette.size()]
		particle.position = position + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
		particle.rotation = _rng.randf_range(-PI, PI)
		particle.scale = Vector2.ONE * _rng.randf_range(0.7, 1.35)
		particle.modulate.a = 1.0
		particle.show()
		particle.queue_redraw()
		var angle := TAU * float(i) / maxf(1.0, count) + _rng.randf_range(-0.26, 0.26)
		var speed := _rng.randf_range(75.0, 215.0)
		if kind == "heal": angle = _rng.randf_range(-2.0, -1.14); speed = _rng.randf_range(55, 115)
		if kind == "smoke": speed = _rng.randf_range(18, 52)
		var endpoint := particle.position + Vector2.from_angle(angle) * speed
		var duration := _rng.randf_range(0.38, 0.72) if kind != "heal" else _rng.randf_range(0.65, 0.9)
		var tw := _track(create_tween().set_parallel(true))
		particle.motion = tw
		tw.tween_property(particle, "position", endpoint, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(particle, "rotation", particle.rotation + _rng.randf_range(-2.0, 2.0), duration)
		tw.tween_property(particle, "scale", Vector2.ONE * (0.15 if kind != "smoke" else 1.8), duration)
		tw.tween_property(particle, "modulate:a", 0.0, duration).set_delay(duration * 0.35)
		tw.chain().tween_callback(particle.hide)

func _particle_palette(kind: String) -> Array[Color]:
	match kind:
		"slime", "tissue": return [MAGENTA, Color("ff9edc"), Color("8c2a70"), Color("f0f6fa")]
		"heal": return [GREEN, Color("46b46e"), Color("b2e8ff")]
		"smoke": return [Color("8592a0"), Color("2a303c"), Color("e0e8f0")]
		"glow": return [CYAN, GOLD, Color("b2e8ff")]
		"shard": return [CYAN, Color("3a82b2"), Color("e0e8f0")]
		_: return [Color.WHITE, CYAN, Color("b2e8ff"), GOLD]

## 通用发射器：所有特效配方都走这里，保持与既有粒子池一致的回收方式。
## 参数含义对齐尖塔2 的 ParticleProcessMaterial：
##   box = 盒形发射范围；speed = 初速区间；drift = 整体位移；flicker = 多次闪烁（原版用多段 alpha 抖动）。
func _emit_fx(position: Vector2, kind: String, palette: Array, count: int, opts: Dictionary = {}) -> void:
	if not enabled("particles") or _particles.is_empty():
		return
	var box: Vector2 = opts.get("box", Vector2.ZERO)
	var speed_range: Vector2 = opts.get("speed", Vector2(60, 180))
	var drift: Vector2 = opts.get("drift", Vector2.ZERO)
	var duration_range: Vector2 = opts.get("duration", Vector2(0.3, 0.6))
	var scale_range: Vector2 = opts.get("scale", Vector2(0.6, 1.2))
	var directional: bool = opts.get("directional", false)
	var flicker: bool = opts.get("flicker", false)
	for i in mini(count, _particles.size()):
		var particle := _particles[_particle_cursor % _particles.size()]
		_particle_cursor += 1
		if particle.motion != null and particle.motion.is_valid(): particle.motion.kill()
		particle.kind = kind
		particle.tint = palette[i % palette.size()]
		particle.position = position + Vector2(
			_rng.randf_range(-box.x, box.x) * 0.5,
			_rng.randf_range(-box.y, box.y) * 0.5)
		var angle := TAU * float(i) / maxf(1.0, count) + _rng.randf_range(-0.45, 0.45)
		particle.rotation = angle if directional else _rng.randf_range(-PI, PI)
		particle.scale = Vector2.ONE * _rng.randf_range(scale_range.x, scale_range.y)
		particle.modulate.a = 1.0
		particle.show()
		particle.queue_redraw()
		var speed := _rng.randf_range(speed_range.x, speed_range.y)
		var endpoint := particle.position + Vector2.from_angle(angle) * speed + drift
		var duration := _rng.randf_range(duration_range.x, duration_range.y)
		var tw := _track(create_tween().set_parallel(true))
		particle.motion = tw
		tw.tween_property(particle, "position", endpoint, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(particle, "scale", particle.scale * 0.25, duration)
		if not directional:
			tw.tween_property(particle, "rotation", particle.rotation + _rng.randf_range(-1.6, 1.6), duration)
		if flicker:
			# 顺序执行的闪烁段：并行组之后链式接上
			var step := duration * 0.14
			tw.chain().tween_property(particle, "modulate:a", 0.3, step)
			tw.chain().tween_property(particle, "modulate:a", 1.0, step)
			tw.chain().tween_property(particle, "modulate:a", 0.35, step)
			tw.chain().tween_property(particle, "modulate:a", 0.0, duration * 0.36)
		else:
			tw.chain().tween_property(particle, "modulate:a", 0.0, duration * 0.55)
		tw.chain().tween_callback(particle.hide)


## 卡面微光（尖塔2 card_sparkles_vfx）：盒形发射、铺开、微弱上浮、星点闪烁。
func sparkle(position: Vector2, accent: Color, count: int = 4) -> void:
	_emit_fx(position, "star", [accent, Color.WHITE, accent], count, {
		"box": Vector2(120, 170), "speed": Vector2(8, 34), "drift": Vector2(0, -18),
		"duration": Vector2(0.5, 0.9), "scale": Vector2(0.45, 1.0), "flicker": true,
	})


## 命中火花（尖塔2 hit_spark_vfx）：长/短速度线 + 碎屑 + 冲击环，快速熄灭。
func hit_spark(position: Vector2, accent: Color) -> void:
	_emit_fx(position, "streak", [Color.WHITE, accent], 7, {
		"speed": Vector2(190, 340), "duration": Vector2(0.16, 0.26),
		"scale": Vector2(0.8, 1.5), "directional": true,
	})
	_emit_fx(position, "streak", [Color.WHITE], 5, {
		"speed": Vector2(90, 170), "duration": Vector2(0.12, 0.2),
		"scale": Vector2(0.4, 0.8), "directional": true,
	})
	_emit_fx(position, "spark", [Color.WHITE, accent], 6, {
		"speed": Vector2(70, 190), "duration": Vector2(0.2, 0.34), "scale": Vector2(0.4, 0.9),
	})


## 格挡火花（尖塔2 block_spark_vfx）：冰蓝白碎屑 + 环。
func block_spark(position: Vector2) -> void:
	var ice: Array[Color] = [Color("bfd8ff"), Color.WHITE, Color("6bc7ff")]
	_emit_fx(position, "streak", ice, 5, {
		"speed": Vector2(120, 240), "duration": Vector2(0.14, 0.22),
		"scale": Vector2(0.5, 1.0), "directional": true,
	})
	_emit_fx(position, "spark", ice, 7, {
		"speed": Vector2(50, 150), "duration": Vector2(0.22, 0.36), "scale": Vector2(0.5, 1.0),
	})
	ring(position, Color("9fd0ff"))


## 消耗灰烬（尖塔2 exhaust_vfx）：暗色灰片 + 上升烟雾。
func exhaust_ash(position: Vector2) -> void:
	_emit_fx(position, "ash", [Color("2a303c"), Color("8592a0"), Color("e0e8f0")], 8, {
		"box": Vector2(70, 40), "speed": Vector2(14, 46), "drift": Vector2(0, -26),
		"duration": Vector2(0.5, 0.85), "scale": Vector2(0.4, 0.9),
	})
	_emit_fx(position, "smoke", [Color("8592a0"), Color("2a303c")], 5, {
		"box": Vector2(50, 30), "speed": Vector2(10, 30), "drift": Vector2(0, -30),
		"duration": Vector2(0.6, 1.0), "scale": Vector2(0.8, 1.6),
	})


## 辅助牌消散时的冷蓝色碎光，沿逐渐上移的卡牌边缘少量释放。
func blue_dissolve_edge(position: Vector2) -> void:
	_emit_fx(position, "star", [CYAN, Color("b2e8ff"), Color("3a82b2")], 4, {
		"box": Vector2(140, 8), "speed": Vector2(12, 48),
		"drift": Vector2(0, -34), "duration": Vector2(0.25, 0.46),
		"scale": Vector2(0.35, 0.70), "flicker": true,
	})


## 出牌拖尾的一步（尖塔2 card_trail_*）：小卡影 + 微光星点，快速淡出。
func card_trail(position: Vector2, accent: Color, trail_scale: float = 0.5) -> void:
	_emit_fx(position, "silhouette", [accent], 1, {
		"speed": Vector2(2, 10), "duration": Vector2(0.26, 0.34),
		"scale": Vector2(trail_scale, trail_scale),
	})
	_emit_fx(position, "star", [accent, Color.WHITE], 2, {
		"speed": Vector2(6, 26), "duration": Vector2(0.24, 0.4),
		"scale": Vector2(0.35, 0.7), "flicker": true,
	})


func number(position: Vector2, text: String, color: Color, large: bool = false) -> void:
	if not enabled("damage_numbers") or _numbers.is_empty(): return
	var item := _numbers[_number_cursor % _numbers.size()]
	_number_cursor += 1
	item.text = text
	item.position = position - item.size * 0.5 + Vector2(_rng.randf_range(-34, 34), 0)
	item.scale = Vector2(0.5, 0.5)
	item.modulate = color
	item.add_theme_font_size_override("font_size", 48 if large else 34)
	item.show()
	var tw := _track(create_tween())
	tw.set_parallel(true)
	tw.tween_property(item, "position:y", item.position.y - 80.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "scale", Vector2.ONE * (1.16 if large else 1.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "modulate:a", 0.0, 0.3).set_delay(0.6)
	tw.chain().tween_callback(item.hide)

func ring(position: Vector2, color: Color, large: bool = false, hexagonal: bool = false) -> void:
	if not enabled("particles") or _rings.is_empty(): return
	var item := _rings[_ring_cursor % _rings.size()]
	_ring_cursor += 1
	if item.motion != null and item.motion.is_valid(): item.motion.kill()
	item.position = position
	item.tint = color
	item.hexagonal = hexagonal
	item.radius = 10.0
	item.thickness = 7.0 if large else 4.0
	item.modulate.a = 0.92
	item.show()
	item.queue_redraw()
	var tw := _track(create_tween().set_parallel(true))
	item.motion = tw
	tw.tween_method(func(value: float): item.radius = value; item.queue_redraw(), 10.0, 148.0 if large else 84.0, 0.38 if large else 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "modulate:a", 0.0, 0.34)
	tw.chain().tween_callback(item.hide)

func echo(streak: int, position: Vector2) -> void:
	if not enabled("combo_effects") or streak <= 0: return
	var color := GOLD if streak >= 4 else CYAN
	ring(position, color, streak >= 4)
	burst(position, "glow", 4 + streak * 2)
	add_trauma([0.0, 0.10, 0.20, 0.40, 0.60, 1.0][mini(streak, 5)])
	play_sound("combo", pow(2.0, float(streak - 1) / 12.0))
	if streak == 3: vignette(CYAN, 0.46)
	elif streak == 4:
		flash(GOLD, 0.10)
		chromatic(4.0, 0.28)
		_zoom = 0.45
	elif streak >= 5:
		ring(Vector2(960, 540), GOLD, true)
		flash(Color.WHITE, 0.22)
		slow_motion(0.15, 0.2)
		number(Vector2(960, 380), "回声极限  ×2.00", GOLD, true)

func corruption(value: int) -> void:
	if not enabled("corruption_effects") or _corruption_rect.material == null: return
	var amount: float = float({3: 0.3, 6: 0.5, 8: 0.68, 10: 1.0}.get(value, clampf(value / 10.0, 0.0, 1.0)))
	var material := _corruption_rect.material as ShaderMaterial
	_corruption_rect.show()
	material.set_shader_parameter("corruption_amount", amount)
	material.set_shader_parameter("distortion", 0.0 if enabled("reduce_motion") else amount * 0.006)
	play_sound("corruption")
	add_trauma(0.25 + amount * 0.6)
	if value >= 10:
		flash(MAGENTA, 0.55)
		slow_motion(0.30, 1.0)
	var tw := _track(create_tween())
	tw.tween_method(func(a: float): material.set_shader_parameter("overlay_alpha", a), 0.0, amount, 0.25)
	tw.tween_interval(1.3 if value < 10 else 0.75)
	tw.tween_method(func(a: float): material.set_shader_parameter("overlay_alpha", a), amount, 0.0, 0.45)
	tw.tween_callback(_corruption_rect.hide)

func shield(position: Vector2) -> void:
	if not enabled("shield_effects"): return
	ring(position, CYAN, false, true)
	burst(position + Vector2(0, 35), "glow", 4)
	play_sound("shield")
	add_trauma(0.1)

func heal(position: Vector2) -> void:
	if not enabled("shield_effects"): return
	burst(position + Vector2(0, 95), "heal", 12)
	ring(position, GREEN, false)
	play_sound("heal")

func turn_banner(text: String, player_turn: bool) -> void:
	if not enabled("turn_effects"): return
	var color: Color = CYAN if player_turn else RED
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.position.x = 480 if player_turn else 840
	_banner.modulate.a = 0.0
	_banner_band.color = Color(color, 0.16)
	_banner_band.position.x = -240
	var tw := _track(create_tween())
	tw.set_parallel(true)
	tw.tween_property(_banner_band, "position:x", 1960.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_banner, "position:x", 660.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.18)
	tw.chain().tween_interval(0.35)
	tw.chain().tween_property(_banner, "modulate:a", 0.0, 0.20)
	play_sound("turn")

func flash(color: Color, intensity: float = 0.12) -> void:
	if not enabled("screen_effects"): return
	var value := minf(intensity, 0.10) if enabled("reduce_flashes") else intensity
	_flash_rect.color = Color(color, value)
	var tw := _track(create_tween())
	tw.tween_property(_flash_rect, "color:a", 0.0, 0.18 if value < 0.3 else 0.32)

func vignette(color: Color, intensity: float = 1.0) -> void:
	if not enabled("screen_effects") or _vignette_rect.material == null: return
	var material := _vignette_rect.material as ShaderMaterial
	material.set_shader_parameter("vignette_color", color)
	material.set_shader_parameter("intensity", intensity * (0.5 if enabled("reduce_flashes") else 1.0))
	var tw := _track(create_tween())
	tw.tween_interval(0.17)
	tw.tween_method(func(value: float): material.set_shader_parameter("intensity", value), intensity, 0.0, 0.28)

func chromatic(amount: float, duration: float) -> void:
	if not enabled("screen_effects") or enabled("reduce_motion") or _chromatic_rect.material == null: return
	var material := _chromatic_rect.material as ShaderMaterial
	_chromatic_rect.show()
	material.set_shader_parameter("aberration_amount", amount)
	var tw := _track(create_tween())
	tw.tween_method(func(value: float): material.set_shader_parameter("aberration_amount", value), amount, 0.0, duration)
	tw.tween_callback(_chromatic_rect.hide)

func play_sound(key: String, pitch: float = 1.0) -> void:
	if not enabled("sound") or _audio.is_empty(): return
	var path := "res://assets/audio/%s.wav" % key
	if not ResourceLoader.exists(path): return
	var player := _audio[_audio_cursor % _audio.size()]
	_audio_cursor += 1
	player.stream = load(path)
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.volume_db = -3.0 if key in ["impact_large", "death", "corruption"] else -7.0
	player.play()

func reset() -> void:
	trauma = 0.0
	_zoom = 0.0
	_time_requests.clear()
	Engine.time_scale = _normal_time_scale
	for tw in _active_tweens:
		if tw != null and tw.is_valid(): tw.kill()
	_active_tweens.clear()
	for item in _particles: item.hide()
	for item in _numbers: item.hide()
	for item in _rings: item.hide()
	for item in _audio:
		item.stop()
		# 释放底层 playback 与音频资源引用，避免测试/切场景时残留对象。
		item.stream = null
	if _flash_rect != null: _flash_rect.color.a = 0.0
	if _banner != null: _banner.modulate.a = 0.0
	if _vignette_rect != null and _vignette_rect.material != null: (_vignette_rect.material as ShaderMaterial).set_shader_parameter("intensity", 0.0)
	if _corruption_rect != null and _corruption_rect.material != null: (_corruption_rect.material as ShaderMaterial).set_shader_parameter("overlay_alpha", 0.0)
	if _corruption_rect != null: _corruption_rect.hide()
	if _chromatic_rect != null: _chromatic_rect.hide()
	if is_instance_valid(_world):
		_world.position = _world_origin
		_world.rotation = _world_rotation
		_world.scale = _world_scale

func _exit_tree() -> void:
	reset()
