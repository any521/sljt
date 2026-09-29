extends Control
## 2D 版战斗角色 —— 实现与 BattleActor3D 完全相同的接口契约
##
## 契约（由 combat_view.gd 调用）：
##   animated (属性)
##   highlight(active: bool)
##   hit(large: bool, reduced_flash: bool, allow_motion: bool)
##   die(allow_motion: bool)
##   attack_motion(allow_motion: bool)
##   reset_actor()
##   position : Vector2
##
## 统一用 AnimatedSprite2D 承载：单张静态图 = 只有 1 帧的动画，序列帧图 = 逐帧循环。
## 这样「会动的角色」和「静止的角色」走同一条代码路径，不会再出现
## 「明明有序列帧却只显示一张静态图」的情况。
##
## 为什么不用 TextureRect：Control 会被 get_minimum_size() 钳制到贴图原始尺寸，
## 设好的 size 会被顶回去（主角 298x550 就吃过这个亏）。

@export var animated := true
@export var facing_left := false          ## 怪物朝左，角色朝右
@export var attack_animation: StringName = &"attack"
var sprite: AnimatedSprite2D
var _base_pos := Vector2.ZERO
var _base_modulate := Color.WHITE
var _base_scale := Vector2.ONE
var _tweens: Array[Tween] = []


func _ready() -> void:
	# 编辑器场景中的真实 AnimatedSprite2D 节点优先；setup_* 只作为测试后备。
	if sprite == null:
		sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite == null:
			sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	var legacy_flash := get_node_or_null("Flash") as CanvasItem
	if legacy_flash != null:
		legacy_flash.visible = false
	if sprite != null:
		_base_scale = sprite.scale
		_base_pos = position
		_base_modulate = modulate
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("[BattleActor2D] 贴图不存在: %s" % path)
	return null


## ── 序列帧模式 ──
## cols x rows 的帧表按「从左到右、从上到下」切成逐帧动画。
## content 是人物在单帧格子内的实际占用矩形（含偏移），用于把脚底精确对齐、
## 并让白闪只盖住人物本身而不是整个格子。
func setup_sheet(tex_path: String, cols: int, rows: int, cell: Vector2, content: Rect2, px_scale: float, fps: float, p_facing_left: bool = false) -> void:
	var tex := _load_tex(tex_path)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", fps)
	if tex != null:
		for r in rows:
			for c in cols:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(c * cell.x, r * cell.y, cell.x, cell.y)
				frames.add_frame("idle", at)
	if frames.get_frame_count("idle") == 0:
		frames.add_frame("idle", tex)
	_attach(frames, content, px_scale, p_facing_left, cell)


## ── 单图模式 ──
## 只给高度，宽度按贴图原始比例推导 —— 从根上杜绝非等比拉伸。
func setup_sprite(tex_path: String, target_height: float, p_facing_left: bool = false) -> void:
	var tex := _load_tex(tex_path)
	var sz := tex.get_size() if tex != null else Vector2(1, 1)
	var s := target_height / maxf(sz.y, 1.0)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 1.0)
	frames.add_frame("idle", tex)
	_attach(frames, Rect2(Vector2.ZERO, sz), s, p_facing_left, sz)


func _attach(frames: SpriteFrames, content: Rect2, px_scale: float, p_facing_left: bool, frame_cell: Vector2) -> void:
	name = "BattleActor2D"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	facing_left = p_facing_left
	# 节点矩形 = 人物实际占用区，调用方拿 size 就能把脚底对齐
	size = content.size * px_scale

	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = frames
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = p_facing_left
	sprite.scale = Vector2(px_scale, px_scale)
	# 让实际人物包围盒正好落在角色根节点矩形内；翻转后使用镜像包围盒补偿。
	if p_facing_left:
		sprite.position = Vector2(content.end.x - frame_cell.x * 0.5, frame_cell.y * 0.5 - content.position.y) * px_scale
	else:
		sprite.position = (frame_cell * 0.5 - content.position) * px_scale
	add_child(sprite)
	sprite.play("idle")

	_base_scale = sprite.scale
	_base_pos = position
	_base_modulate = modulate


func _kill_tweens() -> void:
	for t in _tweens:
		if t != null and t.is_valid():
			t.kill()
	_tweens.clear()


## 高亮（拖拽卡牌瞄准时 / 鼠标悬停时）
func highlight(active: bool) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	if active:
		sprite.modulate = Color(1.45, 1.45, 1.5)
	else:
		sprite.modulate = Color.WHITE


## 受击
func hit(large: bool, reduced_flash: bool, allow_motion: bool = true) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	_kill_tweens()
	sprite.modulate = Color.WHITE

	# 只提亮人物像素本身，不再叠加矩形 ColorRect，因此不会留下白色方块。
	if not reduced_flash:
		sprite.modulate = Color(1.8, 1.8, 1.8, 1.0)
		var fade := create_tween()
		fade.tween_property(sprite, "modulate", Color.WHITE, 0.16 if large else 0.10)
		_tweens.append(fade)

	# 2) 位移抖动（沿受击方向后退再弹回）
	if allow_motion:
		var dist := 22.0 if large else 12.0
		var dir := 1.0 if facing_left else -1.0   # 朝左的怪物被击退向右
		var origin := _base_pos
		var tw := create_tween()
		tw.tween_property(self, "position", origin + Vector2(dist * dir, 0), 0.05)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "position", origin, 0.28 if large else 0.18)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_tweens.append(tw)
	else:
		position = _base_pos


## 死亡
func die(allow_motion: bool = true) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	_kill_tweens()
	sprite.modulate = Color.WHITE
	var tw := create_tween()
	tw.set_parallel(true)
	var duration := 0.55 if allow_motion else 0.08
	tw.tween_property(sprite, "modulate:a", 0.0, duration)
	tw.tween_property(sprite, "scale", _base_scale * Vector2(1.08, 0.82), duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if allow_motion:
		tw.tween_property(self, "position", _base_pos + Vector2(0, 28), duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens.append(tw)
	tw.finished.connect(func():
		if is_instance_valid(self):
			visible = false)


## 攻击动作：预备 → 前冲 → 归位
func attack_motion(allow_motion: bool = true) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	_kill_tweens()
	var has_authored_action := sprite.sprite_frames != null and sprite.sprite_frames.has_animation(attack_animation)
	if has_authored_action:
		sprite.play(attack_animation)
		await sprite.animation_finished
		if is_instance_valid(sprite):
			sprite.play("idle")
		return
	if not allow_motion:
		return
	var dir := -1.0 if facing_left else 1.0   # 朝左的怪物朝左冲
	var origin := _base_pos

	var prep := create_tween()
	prep.tween_property(self, "position", origin + Vector2(-18 * dir, 0), 0.22)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tweens.append(prep)
	await prep.finished

	var strike := create_tween()
	strike.tween_property(self, "position", origin + Vector2(56 * dir, 0), 0.11)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens.append(strike)
	await strike.finished

	var back := create_tween()
	back.tween_property(self, "position", origin, 0.30)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tweens.append(back)
	await back.finished
	if is_instance_valid(sprite):
		sprite.play("idle")


## 复位（新战斗 / 重开时）
func reset_actor() -> void:
	_kill_tweens()
	visible = true
	position = _base_pos
	modulate = _base_modulate
	if sprite != null and is_instance_valid(sprite):
		sprite.modulate = Color.WHITE
		sprite.scale = _base_scale      ## 恢复基准缩放（不是 ONE —— 精灵本身带缩放）
		sprite.modulate.a = 1.0
		sprite.rotation = 0.0
		sprite.play("idle")
## 让外部（战斗世界）在摆好位置后登记基准坐标
func mark_base_position() -> void:
	_base_pos = position


func body_center() -> Vector2:
	return position + size * 0.5


func head_anchor() -> Vector2:
	return position + Vector2(size.x * 0.5, 0.0)
