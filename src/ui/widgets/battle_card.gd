extends Control
## A readable, faction-coded card. Motion is owned by the battle view.
##
## 卡框来自素材图 card_frame_225.png（由 card_frame_ai.png 300x396 高保真缩放到
## 225x297 —— 缩放系数恰好 0.75，宽高比与边框原图完全一致，不会变形）。
## 卡框内部区域是按边框图量出来的：
##   能量圆槽 中心(24.75, 24.75) / 名牌条 y9-39 / 卡面窗 x19.5-208.5, y43.5-178.5
##   描述面板 x19.5-208.5, y187.5-273.75 / 底部装饰带 y277.5-294
const CARD_SIZE := Vector2(224, 296)
const FRAME := "res://assets/art/cards/card_frame_225.png"
const COLORS := [Color("6bc7ff"), Color("c7479e"), Color("a0aab2")]
signal pressed(view: Control)
signal hovered(view: Control, entered: bool)
var instance: CardInstance
var combat: CombatManager
var home := Vector2.ZERO
var home_rotation := 0.0
var moving := false
var selected := false
var lit := false
var motion: Tween
var _frame: TextureRect
var _dim: ColorRect
var _name: Label
var _cost: Label
var _description: Label
var _badge: Label
var _type: Label
var _art: TextureRect
var _index: Label
var playable := true
## 高亮四态，对齐尖塔2 的"能打 / 条件已激活 / 特殊警示 / 不可用"。
enum Glow { NONE, PLAYABLE, GOLD, RED }
var glow := Glow.NONE
## 当前手牌数量下的基准缩放（手牌越多越小），悬停与拖拽都基于它换算。
var base_scale := 0.94
## 逐帧 Lerp 运动：目标值由战斗视图设置，驱动在战斗视图的 _process。
var motion_active := false
var target_position := Vector2.ZERO
var target_rotation := 0.0
var target_scale := Vector2.ONE
var hitbox_ready := true
## 抖动是运动系统内部的一个瞬态偏移：绝不能用 Tween 另开一条写入 position 的通道，
## 也不能关掉 motion_active，否则牌会永远停在原地（"放在中间卡住"就是这么来的）。
var shake_time := 0.0
var shake_amp := 0.0


func setup(manager: CombatManager, card: CardInstance, index: int) -> void:
	combat = manager
	instance = card
	# 结构完全来自 battle_card.tscn：这里只绑定已有子节点。
	# 缺节点直接报错，不做动态构建兜底 —— 那样会生成编辑器里看不到、改不了的节点。
	_frame = get_node_or_null("Frame") as TextureRect
	_cost = get_node_or_null("Cost") as Label
	_name = get_node_or_null("Name") as Label
	_index = get_node_or_null("Index") as Label
	_art = get_node_or_null("Art") as TextureRect
	_type = get_node_or_null("Type") as Label
	_description = get_node_or_null("Description") as Label
	_badge = get_node_or_null("Badge") as Label
	_dim = get_node_or_null("Dim") as ColorRect
	if _frame == null or _dim == null or _description == null or _index == null:
		push_error("battle_card.tscn 缺少必需子节点：Frame / Dim / Description / Index")
		return
	_index.text = str(index + 1)
	var art_db: Node = Engine.get_main_loop().root.get_node_or_null("CardArt")
	_art.texture = art_db.get_card_texture(card.data.id) if art_db != null else null
	if not mouse_entered.is_connected(_emit_hover_entered):
		mouse_entered.connect(_emit_hover_entered)
		mouse_exited.connect(_emit_hover_exited)
		gui_input.connect(_on_gui_input)
	refresh()


func _emit_hover_entered() -> void:
	hovered.emit(self, true)


func _emit_hover_exited() -> void:
	hovered.emit(self, false)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(self)
		accept_event()


func refresh(target: int = -1) -> void:
	playable = combat.can_play(instance)
	_name.text = instance.display_name()
	_cost.text = str(instance.effective_cost(combat.isolation))
	_type.text = "%s / %s%s" % [instance.data.faction_name() if not instance.corrupted else "异化", instance.data.type_name(), " · 已异化" if instance.corrupted else ""]
	_type.add_theme_color_override("font_color", COLORS[instance.faction()])
	var lines: PackedStringArray = []
	for effect in instance.data.effects:
		var n: int = effect.get("value", 0)
		match effect.get("action", ""):
			"damage", "damage_multi":
				lines.append("造成 %d 点伤害" % combat.preview_card_damage(instance, target))
			"block": lines.append("获得 %d 格挡" % n)
			"draw": lines.append("抽 %d 张牌" % n)
			"apply": lines.append("%s %d" % [CardData.new()._status_name(effect.get("status", "")), n])
			"heal": lines.append("恢复 %d 生命" % n)
			"self_damage": lines.append("失去 %d 生命" % n)
			"gain_energy": lines.append("获得 %d 能量" % n)
			"gain_status": lines.append("%s +%d" % [CardData.new()._status_name(effect.get("status", "")), n])
			"isolation": lines.append("隔离值 %+d" % n)
	_description.text = "\n".join(lines)
	# 描述窗只有 60px 高，行数多时必须缩字号，否则文字会溢出卡框
	_description.add_theme_font_size_override("font_size", 12 if lines.size() >= 4 else (14 if lines.size() >= 3 else 16))
	var prediction := combat.echo_prediction(instance)
	match prediction.verdict:
		"extend":
			_badge.text = "回声 +1   /   ×%.2f" % prediction.multiplier
			_badge.add_theme_color_override("font_color", Color("7fd9a0"))
		"break":
			_badge.text = "同归属 · 回声归零"
			_badge.add_theme_color_override("font_color", Color("eb6161"))
		"neutral": _badge.text = "中立 · 保持回声"
		_: _badge.text = "建立回声基准"
	if not playable:
		_badge.text = "能量不足" if instance.effective_cost(combat.isolation) > combat.energy else "等待行动"
		_badge.add_theme_color_override("font_color", Color("8592a0"))
		glow = Glow.NONE
	elif prediction.verdict == "extend":
		glow = Glow.GOLD
	elif prediction.verdict == "break":
		glow = Glow.RED
	else:
		glow = Glow.PLAYABLE
	if _dim != null:
		_dim.visible = not playable
	tooltip_text = "%s\n%s\n%s" % [instance.display_name(), instance.data.description, "拖向敌人，或点击选牌后点击目标。右键取消。"]
	queue_redraw()


## 手牌节点会跨回合按 uid 复用。进入新手牌前必须清掉上一轮的遮罩、Tween 和交互状态。
func reset_visual_state() -> void:
	if motion != null and motion.is_valid():
		motion.kill()
	motion = null
	show()
	modulate = Color.WHITE
	self_modulate = Color.WHITE
	selected = false
	lit = false
	moving = false
	motion_active = false
	hitbox_ready = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _dim != null:
		_dim.visible = false
	queue_redraw()


## 拖拽开始：角度立刻归零、缩放立刻到悬停档（对齐尖塔2 的 BeginDrag）。
func begin_drag() -> void:
	motion_active = false
	rotation = 0.0
	scale = hover_scale()


## 拖拽取消：角度归零、缩放回基准（对齐尖塔2 的 CancelDrag）。
func cancel_drag() -> void:
	rotation = 0.0
	scale = Vector2.ONE * base_scale


## 悬停缩放：以基准缩放为锚，保持相同的视觉放大比例。
func hover_scale() -> Vector2:
	return Vector2.ONE * (base_scale * 1.189)

## 只在卡框外面画东西：投影 + 选中/悬停辉光。
## 卡框本体交给 card_frame_225.png，这里不再手绘边框。
func _draw() -> void:
	var accent: Color = COLORS[instance.faction()] if instance != null else COLORS[0]
	var ring := accent
	match glow:
		Glow.GOLD: ring = Color("ffdc82")
		Glow.RED: ring = Color("eb6161")
		Glow.PLAYABLE: ring = accent
		_: ring = accent
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.5)
	shadow.set_corner_radius_all(8)
	draw_style_box(shadow, Rect2(Vector2(4, 7 if not selected else 15), size))
	# 常驻状态光：可打出=归属色，回声可续=金，会断回声=红，不可用=无光。
	if glow != Glow.NONE:
		for i in range(3, 0, -1):
			draw_rect(Rect2(Vector2.ONE * (-i * 2), size + Vector2.ONE * i * 4), Color(ring, 0.055 * (4 - i)), false, 2)
	if lit or selected:
		for i in range(3, 0, -1):
			draw_rect(Rect2(Vector2.ONE * (-i * 2), size + Vector2.ONE * i * 4), Color(accent, 0.07 * (4 - i)), false, 2)
