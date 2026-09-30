extends Control
signal battle_finished(victory: bool)
## Battle presentation. The synchronous rules remain in CombatManager; this view
## snapshots its signals and replays them in order, without exposing future state.
const CardWidget = preload("res://src/ui/widgets/battle_card.gd")
const CardScene = preload("res://scenes/widgets/battle_card.tscn")
const BattleWorldScene = preload("res://scenes/battle_world_2d.tscn")
const CrewStatusScene = preload("res://scenes/widgets/crew_status_panel.tscn")
const PixelFontTheme = preload("res://assets/themes/pixel_font_theme.tres")
const PixelFrame = preload("res://src/ui/widgets/pixel_frame.gd")
const StatusIcon = preload("res://src/ui/widgets/status_icon.gd")
const INK := Color("0a0e14")
const TEXT := Color("e0e8f0")
const DIM := Color("8592a0")
const CYAN := Color("6bc7ff")
const MAGENTA := Color("c7479e")
const GOLD := Color("ffdc82")
const RED := Color("eb6161")
const GREEN := Color("7fd9a0")
const CARD_BASE_SCALE := 0.94
const CARD_HOVER_SCALE := 1.12
const DRAW_POINT := Vector2(1480, 842)
const DESIGN_SIZE := Vector2(1920, 1055)

# ── 出牌区 / 取消区（常量对齐《杀戮尖塔2》NMouseCardPlay） ────────────────
const PLAY_ZONE_PROPORTION := 0.75
const CANCEL_ZONE_PROPORTION := 0.95
const FAKE_LOWER_ENTER_DISTANCE := 100.0
const FAKE_UPPER_ENTER_DISTANCE := 50.0
const CLICK_DRAG_THRESHOLD := 14.0
## 指针移动超过这个距离才真正开始拖拽（之前只让牌微抬）——"点击"与"上滑"的分界。
const DRAG_FOLLOW_THRESHOLD := 10.0
## 手牌与卡槽左右内边距：自适应压缩时保留的留白
const HAND_TRAY_MARGIN := 26.0
## 卡牌自适应缩小的下限（相对档位缩放）：再小就改为压缩扇形
const CARD_SCALE_FLOOR := 0.62
## 相邻卡牌之间必须保留的间隙（不遮挡）
const CARD_NO_OVERLAP_GAP := 2.0
## 手牌托槽的占位矩形（托槽自身按扇形绘制，这里只定它在屏幕上的活动范围）
const HAND_TRAY_RECT := Rect2(259, 766, 1400, 252)
## 托槽最小宽度 = 屏幕中间的三分之二；手牌放不下时才会超出这个宽度继续撑开
const HAND_TRAY_MIN_WIDTH := 1280.0
const QUEUE_ANCHOR := Vector2(1150, 700)

# ── 逐帧 Lerp 运动（速率与吸附阈值对齐尖塔2 NHandCardHolder） ────────────
const MOTION_ROTATE_SPEED := 10.0
const MOTION_SCALE_SPEED := 8.0
const MOTION_MOVE_SPEED := 7.0
const MOTION_ROTATE_SNAP := 0.0017
const MOTION_SCALE_SNAP := 0.002
const MOTION_MOVE_SNAP := 1.0
const HITBOX_REENABLE_DISTANCE := 200.0

# ── 手牌版式（1~10 张逐张手调表，来自尖塔2 HandPosHelper） ───────────────
# 位置是相对手牌区中心的偏移：x 用 1220 的跨度归一，y 的 -50 对应本地 19px。
const HAND_Y_BASE := -25.0
const HAND_Y_SCALE := 0.18
const HAND_WIDTH_SPAN := 1220.0
const HAND_SCALE_STEPS := {8: 0.95, 9: 0.9, 10: 0.85}
const HAND_POSITIONS := [
	[Vector2(0, -50)],
	[Vector2(-100, -50), Vector2(100, -50)],
	[Vector2(-180, -50), Vector2(0, -59), Vector2(180, -50)],
	[Vector2(-240, -25), Vector2(-80, -50), Vector2(80, -50), Vector2(240, -25)],
	[Vector2(-340, 10), Vector2(-170, -30), Vector2(0, -50), Vector2(170, -30), Vector2(340, 10)],
	[Vector2(-460, 13), Vector2(-273, -25), Vector2(-90, -50), Vector2(90, -50), Vector2(273, -25), Vector2(460, 13)],
	[Vector2(-534, 18), Vector2(-365, -14), Vector2(-189, -39), Vector2(0, -50), Vector2(189, -39), Vector2(365, -14), Vector2(534, 18)],
	[Vector2(-565, 28), Vector2(-400, -14), Vector2(-231, -39), Vector2(-80, -50), Vector2(80, -50), Vector2(231, -39), Vector2(400, -14), Vector2(565, 28)],
	[Vector2(-600, 37), Vector2(-445, -2), Vector2(-300, -29), Vector2(-150, -45), Vector2(0, -50), Vector2(150, -45), Vector2(300, -29), Vector2(445, -2), Vector2(600, 37)],
	[Vector2(-610, 38), Vector2(-472, 5), Vector2(-340, -21), Vector2(-200, -41), Vector2(-64, -50), Vector2(64, -50), Vector2(200, -41), Vector2(340, -21), Vector2(472, 5), Vector2(610, 38)],
]
const HAND_ANGLES := [
	[0.0],
	[-2.0, 2.0],
	[-3.0, 0.0, 3.0],
	[-8.0, -4.0, 4.0, 8.0],
	[-8.0, -4.0, 0.0, 4.0, 8.0],
	[-9.0, -6.0, -3.0, 3.0, 6.0, 9.0],
	[-9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0],
	[-12.0, -9.0, -6.0, -3.0, 3.0, 6.0, 9.0, 12.0],
	[-12.0, -9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0, 12.0],
	[-15.0, -12.0, -9.0, -6.0, -3.0, 3.0, 6.0, 9.0, 12.0, 15.0],
]
## 预制体：在 main.tscn 的 CombatView 节点上拖拽赋值，代码不写文件路径。
@export var targeting_arrow_prefab: PackedScene = preload("res://scenes/fx/targeting_arrow.tscn")
@export var selection_reticle_prefab: PackedScene = preload("res://scenes/fx/selection_reticle.tscn")
@export var thought_bubble_prefab: PackedScene = preload("res://scenes/widgets/thought_bubble.tscn")
@export var juice_prefab: PackedScene = preload("res://scenes/ui/juice.tscn")
@export var hand_tray_prefab: PackedScene = preload("res://scenes/ui/hand_tray.tscn")
@export var world_status_prefab: PackedScene = preload("res://scenes/widgets/world_status_bar.tscn")
## 独立打开战斗场景/脚本测试时可自动生成一场预览战斗。
## Main 场景关闭此项，避免选角和地图阶段提前播放发牌与回合横幅。
@export var preview_battle_on_ready := true
var combat: CombatManager
var _run_deck: Array[CardData] = []
var _run_enemies: Array[EnemyData] = []
var _run_hp := -1
var _run_battle := false
var _run_rules := CharacterRules.new()
var _run_trinkets: Array[String] = []
var _pending_end_turn := false
var juice: Node
var world: Control
var battle_world: Control
var _hud_layer: Control
var _card_layer: Control
var _overlay_layer: Control
var _debug_layer: Control
var _hero_point := Vector2(500, 620)
var _enemy_points: Array[Vector2] = [Vector2(1270, 585), Vector2(1515, 550)]
var _enemy_ui_points: Array[Vector2] = [Vector2(1270, 390), Vector2(1515, 365)]
var hand_box: Control
var flight_layer: Control
var card_views: Array[Control] = []
var enemy_rows: Array[Dictionary] = []
var hero: Node
var ally: Node
var _busy := false
var _epoch := 0
var _recording := false
var _events: Array[Dictionary] = []
var _snapshot: Dictionary = {}
var _dragging := false
var _drag_view: Control
var _selected: Control
var _drag_start := Vector2.ZERO
var _hover_enemy := -1
var _hover_card: Control
## 可见卡槽（tray）节点：手牌版式以它的真实矩形为基准，而不是手牌容器的中心。
var _hand_tray: Control
var _drag_start_y := 0.0
var _cast_mode := false
## 指针接缝：设为有限值时，拖拽判定改用这个坐标。
## 用途是让自动化测试驱动真实处理函数，而不依赖系统光标
##（后台窗口无焦点时 Input.warp_mouse 不可靠）。运行时保持 Vector2.INF。
var pointer_override := Vector2.INF
var _arrow: Node2D
var _reticles: Array[Control] = []
var _thought_bubble: Label
var _thought_tween: Tween
var _play_queue_depth := 0
## 出牌队列：正在结算时仍可继续出牌，排进这里按顺序执行；
## 轮到它时若已不满足打出条件（例如前面把能量花掉了），就放回手牌。
var _play_queue: Array[Dictionary] = []
var _queued_instances: Array = []
var _resolving := false
## 只有指针真正移动过才开始跟随光标；单纯点击只让牌微抬（见 _update_drag）。
var _drag_follow := false
var _last_faction := 0
var _enemy_attacking := -1
var _intent_clock := 0.0
var _ui_tweens: Array[Tween] = []
var _log_lines: PackedStringArray = []
var _hp_label: Label
var _hp_bar: ProgressBar
var _hp_ghost: ProgressBar
var _block_label: Label
var _energy_label: Label
var _isolation_label: Label
var _isolation_cells: Array[ColorRect] = []
var _echo_label: Label
var _echo_cells: Array[Panel] = []
var _next_label: Label
var _turn_label: Label
var _status_label: Label
var _shen_status_panel: Panel
var _song_status_panel: Panel
var _player_status_layer: Control
var _companion_status_layer: Control
var _hint_label: Label
var _end_turn_button: Button
var _discard_drop_zone: Panel
var _player_world_bar: Panel
var _draw_button: Button
var _discard_button: Button
var _settings_button: Button
var _log_panel: Panel
var _log_label: RichTextLabel
var _settings_panel: Panel
var _help_panel: Panel
var _pile_panel: Panel
var _result_overlay: Control
var _result_label: Label
var _result_body: Label
var _target_label: Label
var _shield_seg: ColorRect
var _crosshair: Control
var _fps_label: Label
var _trajectory: Line2D
var _draw_generation := 0
var _pending_draw_views: Array[Control] = []
var _deck_icon: Control
var _preview_card: Control
var _preview_tween: Tween
var _overflow_overlay: Control

func _ready() -> void:
	name = "CombatView"
	size = DESIGN_SIZE
	mouse_filter = MOUSE_FILTER_IGNORE
	if theme == null:
		theme = PixelFontTheme
	_bind_scene_layers()
	_build_ui()
	_discard_drop_zone = get_node_or_null("HUD/TurnControls/DiscardDropZone") as Panel
	if juice_prefab == null:
		push_error("CombatView 缺少 juice 预制体（请在 main.tscn 检查器里拖拽赋值）")
	else:
		juice = juice_prefab.instantiate()
		_overlay_section("Effects").add_child(juice)
		juice.setup(world)
	_build_settings()
	if preview_battle_on_ready:
		start_new_combat()
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)


func _bind_scene_layers() -> void:
	_hud_layer = _get_or_create_layer("HUD", 10)
	_card_layer = _get_or_create_layer("Cards", 20)
	_overlay_layer = _get_or_create_layer("Overlays", 30)
	_debug_layer = _get_or_create_layer("Debug", 40)


func _get_or_create_layer(layer_name: String, layer_z: int) -> Control:
	var layer := get_node_or_null(layer_name) as Control
	if layer == null:
		layer = Control.new()
		layer.name = layer_name
		add_child(layer)
	layer.size = DESIGN_SIZE
	layer.mouse_filter = MOUSE_FILTER_IGNORE
	layer.z_index = layer_z
	return layer


func _ui_parent(parent: Node) -> Node:
	return _hud_layer if parent == self and _hud_layer != null else parent


func _section(layer: Control, section_name: String) -> Control:
	var section := layer.get_node_or_null(section_name) as Control
	if section == null:
		section = Control.new()
		section.name = section_name
		section.size = DESIGN_SIZE
		section.mouse_filter = MOUSE_FILTER_IGNORE
		layer.add_child(section)
	return section


func _hud_section(section_name: String) -> Control:
	return _section(_hud_layer, section_name)


func _overlay_section(section_name: String) -> Control:
	return _section(_overlay_layer, section_name)


## UI 按 1920×1055 的安全画布排版，再整体等比适配窗口。
## 常用的 1920×1055 窗口保持 1:1 像素；更小窗口才统一缩放，避免各层错位。
func _fit_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var factor := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	scale = Vector2.ONE * factor
	position = ((viewport_size - DESIGN_SIZE * factor) * 0.5).round()

func _panel(parent: Node, at: Vector2, bounds: Vector2, accent: Color = Color("2a303c"), solid: bool = true) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = bounds
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.049, 0.069, 0.94 if solid else 0.65)
	style.border_color = accent
	style.set_border_width_all(4)
	style.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", style)
	_ui_parent(parent).add_child(panel)
	return panel

func _label(parent: Node, text: String, at: Vector2, bounds: Vector2, font_size: int = 18, color: Color = TEXT) -> Label:
	var item := Label.new()
	item.position = at
	item.size = bounds
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = MOUSE_FILTER_IGNORE
	_ui_parent(parent).add_child(item)
	return item

func _button(parent: Node, text: String, at: Vector2, bounds: Vector2, callback: Callable, color: Color = CYAN) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = bounds
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("111e2b") if state != "hover" else Color("1e3a52")
		style.border_color = color if state in ["hover", "focus"] else Color(color, 0.4)
		style.set_border_width_all(4)
		style.set_corner_radius_all(0)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_disabled_color", DIM.darkened(0.3))
	button.pressed.connect(callback)
	_ui_parent(parent).add_child(button)
	return button

func _bar(parent: Node, at: Vector2, bounds: Vector2, color: Color, maximum: float = 70.0, pixel: bool = false) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.size = bounds
	bar.max_value = maximum
	bar.show_percentage = false
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("111620")
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	if pixel:
		# 像素风：直角 + 一圈描边，不用圆角
		bg.set_border_width_all(4)
		bg.border_color = Color(0.42, 0.55, 0.68, 0.85)
	else:
		bg.set_corner_radius_all(3)
		fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	_ui_parent(parent).add_child(bar)
	return bar


func _texture(parent: Node, variant_name: String, at: Vector2, bounds: Vector2, opacity: float = 1.0) -> TextureRect:
	var item := PixelFrame.new()
	item.position = at
	item.size = bounds
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.texture_filter = TEXTURE_FILTER_NEAREST
	item.mouse_filter = MOUSE_FILTER_IGNORE
	item.modulate.a = opacity
	item.set_variant(variant_name)
	_ui_parent(parent).add_child(item)
	return item


func _build_ui() -> void:
	# Main 场景可以直接持有 World/BattleWorld2D，这样背景、素材预览和
	# 角色站位在编辑器里都可见；纯脚本测试仍保留运行时后备创建路径。
	world = get_node_or_null("World") as Control
	if world == null:
		world = Control.new()
		world.name = "World"
		world.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(world)
	world.size = size
	battle_world = world.get_node_or_null("BattleWorld2D") as Control
	if battle_world == null:
		battle_world = BattleWorldScene.instantiate()
		world.add_child(battle_world)
	battle_world.size = world.size
	battle_world.build()
	hero = battle_world.player_actor
	ally = battle_world.companion_actor
	_hero_point = battle_world.player_screen_point()
	_enemy_points = [battle_world.enemy_screen_point(0), battle_world.enemy_screen_point(1)]
	if battle_world.has_method("enemy_ui_point"):
		_enemy_ui_points = [battle_world.enemy_ui_point(0), battle_world.enemy_ui_point(1)]

	# A subtle lower gradient keeps card text readable without hiding the 3D deck.
	var lower_shade := _hud_layer.get_node_or_null("BackdropShade") as ColorRect
	if lower_shade == null:
		lower_shade = ColorRect.new()
		lower_shade.name = "BackdropShade"
		lower_shade.position = Vector2(0, 790)
		lower_shade.size = Vector2(1920, 290)
		lower_shade.color = Color(0.015, 0.025, 0.038, 0.54)
		lower_shade.mouse_filter = MOUSE_FILTER_IGNORE
		_hud_layer.add_child(lower_shade)

	# Thin bridge-status rail. The central stage stays unobstructed.
	var rail := _panel(_hud_section("TopBar"), Vector2(26, 16), Vector2(1868, 54), Color("2b536e"), false)
	_label(rail, "ARKHAM // 07 生物实验舱", Vector2(20, 12), Vector2(370, 30), 17, CYAN)
	_turn_label = _label(rail, "你的回合 / 01", Vector2(1452, 10), Vector2(200, 32), 19, GOLD)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_button(rail, "记录", Vector2(1665, 7), Vector2(76, 38), func(): _log_panel.visible = not _log_panel.visible, DIM)
	_button(rail, "规则", Vector2(1746, 7), Vector2(72, 38), func(): _help_panel.visible = not _help_panel.visible, DIM)
	_settings_button = _button(rail, "设置", Vector2(1818, 7), Vector2(55, 38), _toggle_settings, CYAN)
	_settings_button.add_theme_font_size_override("font_size", 14)

	# Compact top-center diagnostic instruments.
	var meters := _hud_section("CombatMeters")
	var echo_panel := _texture(meters, "echo", Vector2(650, 83), Vector2(390, 86))
	_echo_label = _label(echo_panel, "回响 0  /  ×1.00", Vector2(82, 6), Vector2(280, 26), 17, CYAN)
	for i in 6:
		var cell := _panel(echo_panel, Vector2(92 + i * 46, 37), Vector2(34, 16), Color("1e3a52"))
		_echo_cells.append(cell)
	_next_label = _label(meters, "交替规程与变异，建立回响链", Vector2(645, 170), Vector2(400, 25), 14, CYAN)
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var isolation_panel := _texture(meters, "isolation", Vector2(1080, 91), Vector2(380, 54))
	_isolation_label = _label(isolation_panel, "隔离 0 / 10", Vector2(12, -23), Vector2(250, 25), 16, MAGENTA)
	for i in 10:
		var cell := ColorRect.new()
		cell.position = Vector2(24 + i * 33, 17)
		cell.size = Vector2(27, 20)
		cell.color = Color("271022")
		cell.mouse_filter = MOUSE_FILTER_IGNORE
		isolation_panel.add_child(cell)
		_isolation_cells.append(cell)

	# 左上两名船员共用 crew_status_panel.tscn。宋梅位于沈明下方，规格完全一致。
	var player_status := _hud_section("PlayerStatus")
	var shen_status := player_status.get_node_or_null("ShenMingStatus") as Panel
	if shen_status == null:
		shen_status = CrewStatusScene.instantiate()
		shen_status.name = "ShenMingStatus"
		shen_status.position = Vector2(26, 78)
		shen_status.set("crew_name", "沈明")
		var shen_portrait := AtlasTexture.new()
		shen_portrait.atlas = load("res://assets/art/characters/shen_mingyan/portrait_shen_ming.png")
		shen_portrait.region = Rect2(250, 100, 500, 500)
		shen_status.set("portrait_texture", shen_portrait)
		player_status.add_child(shen_status)
	var companion_status := _hud_section("CompanionStatus")
	var song_status := companion_status.get_node_or_null("SongMeiStatus") as Panel
	if song_status == null:
		song_status = CrewStatusScene.instantiate()
		song_status.name = "SongMeiStatus"
		song_status.position = Vector2(26, 176)
		song_status.set("crew_name", "宋梅")
		song_status.set("portrait_texture", load("res://assets/art/characters/song_mei/portrait_512.png"))
		song_status.set("show_block", false)
		companion_status.add_child(song_status)
	_player_status_layer = player_status
	_companion_status_layer = companion_status
	_shen_status_panel = shen_status
	_song_status_panel = song_status
	_hp_label = shen_status.get_node("HPLabel") as Label
	_hp_ghost = shen_status.get_node("HPGhost") as ProgressBar
	_hp_bar = shen_status.get_node("HPBar") as ProgressBar
	_block_label = shen_status.get_node("BlockLabel") as Label
	_shield_seg = shen_status.get_node("ShieldSegment") as ColorRect
	_status_label = shen_status.get_node("StatusLabel") as Label

	# ── 左下：能量球 ──
	var orb := PixelFrame.new()
	orb.position = Vector2(48, 866)
	orb.size = Vector2(116, 116)
	orb.mouse_filter = MOUSE_FILTER_IGNORE
	orb.set_variant("panel")
	orb.accent = GOLD
	player_status.add_child(orb)
	_energy_label = _label(orb, "3", Vector2(0, 20), Vector2(116, 56), 42, GOLD)
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(orb, "能量", Vector2(0, 80), Vector2(116, 20), 13, DIM).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for i in 2:
		_build_enemy(i)
	_player_world_bar = world_status_prefab.instantiate()
	_player_world_bar.name = "PlayerWorldStatus"
	_player_world_bar.position = _hero_point + Vector2(-72, -207)
	meters.add_child(_player_world_bar)
	_player_world_bar.call("place_statuses_at", _actor_foot_point(hero, _hero_point))

	# Recessed tray and smaller cards keep the characters and cast shadows visible.
	# 画布高 1055。待机牌放大到 0.94 后，扇形基线前移，避免卡牌底部越界。
	# 扇形托槽是预制体（scenes/ui/hand_tray.tscn），形状按手牌扇形程序化绘制。
	if hand_tray_prefab == null:
		push_error("CombatView 缺少手牌托槽预制体（请在 main.tscn 检查器里拖拽赋值）")
	else:
		_hand_tray = hand_tray_prefab.instantiate()
		_hand_tray.position = HAND_TRAY_RECT.position
		_hand_tray.size = HAND_TRAY_RECT.size
		_hud_section("HandArea").add_child(_hand_tray)
	hand_box = _card_layer.get_node_or_null("Hand") as Control
	if hand_box == null:
		hand_box = Control.new()
		hand_box.name = "Hand"
		_card_layer.add_child(hand_box)
	hand_box.position = Vector2(418, 758)
	hand_box.size = Vector2(1084, 266)
	hand_box.mouse_filter = MOUSE_FILTER_IGNORE
	flight_layer = _card_layer.get_node_or_null("Flight") as Control
	if flight_layer == null:
		flight_layer = Control.new()
		flight_layer.name = "Flight"
		_card_layer.add_child(flight_layer)
	flight_layer.size = size
	flight_layer.mouse_filter = MOUSE_FILTER_IGNORE
	flight_layer.z_index = 100
	_trajectory = _card_layer.get_node_or_null("Trajectory") as Line2D
	if _trajectory == null:
		_trajectory = Line2D.new()
		_trajectory.name = "Trajectory"
		_card_layer.add_child(_trajectory)
	_trajectory.width = 2
	_trajectory.default_color = CYAN
	_trajectory.z_index = 99

	# 抽牌堆图标：三张错位的牌，紧贴「牌库」按钮左侧
	_deck_icon = Control.new()
	_deck_icon.position = Vector2(1456, 816)
	_deck_icon.size = Vector2(48, 56)
	_deck_icon.pivot_offset = Vector2(24, 28)
	_deck_icon.mouse_filter = MOUSE_FILTER_IGNORE
	var pile_controls := _hud_section("PileControls")
	pile_controls.add_child(_deck_icon)
	for i in 3:
		var sheet := Panel.new()
		sheet.position = Vector2(i * 5, 14 - i * 6)
		sheet.size = Vector2(28, 40)
		sheet.mouse_filter = MOUSE_FILTER_IGNORE
		var sheet_style := StyleBoxFlat.new()
		sheet_style.bg_color = Color(0.09, 0.18, 0.28, 0.96)
		sheet_style.border_color = Color(0.42, 0.72, 0.95, 0.95)
		sheet_style.set_border_width_all(4)
		sheet_style.set_corner_radius_all(0)
		sheet.add_theme_stylebox_override("panel", sheet_style)
		_deck_icon.add_child(sheet)
	_draw_button = _button(pile_controls, "牌库  5", Vector2(1518, 825), Vector2(126, 40), func(): _show_pile("抽牌堆", combat.draw_pile), CYAN)
	_discard_button = _button(pile_controls, "弃牌  0", Vector2(1660, 825), Vector2(126, 40), func(): _show_pile("弃牌堆", combat.discard_pile), DIM)
	var turn_controls := _hud_section("TurnControls")
	_texture(turn_controls, "end_turn", Vector2(1588, 886), Vector2(270, 128))
	_end_turn_button = _button(turn_controls, "结束回合  →", Vector2(1606, 904), Vector2(234, 84), _on_end_turn_pressed, GOLD)
	_end_turn_button.add_theme_font_size_override("font_size", 24)
	_label(turn_controls, "SPACE", Vector2(1693, 986), Vector2(80, 20), 11, DIM).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hints := _hud_section("Hints")
	_hint_label = _label(hints, "按住卡牌拖动箭头 · 点击卡牌放大查看 · 右键取消", Vector2(605, 734), Vector2(710, 23), 13, DIM)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fps_label = _label(_debug_layer, "", Vector2(1730, 1018), Vector2(150, 22), 12, DIM)
	# 预测伤害读数：挪到右下。原来挂在敌人上方 -245，正好撞上新的头顶血条。
	_target_label = _label(hints, "", Vector2(1332, 752), Vector2(540, 40), 17, GOLD)
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_target_label.z_index = 110
	_target_label.visible = false
	_build_popups()
	_build_crosshair()
	_build_targeting()


## 拖牌瞄准时套在目标身上的准心（用户版式要求的 ⑥）
func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.size = Vector2(84, 84)
	_crosshair.mouse_filter = MOUSE_FILTER_IGNORE
	_crosshair.z_index = 105
	_crosshair.visible = false
	var ring := PixelFrame.new()
	ring.position = Vector2(10, 10)
	ring.size = Vector2(64, 64)
	ring.mouse_filter = MOUSE_FILTER_IGNORE
	ring.set_variant("panel")
	ring.accent = GOLD
	ring.fill = Color(0, 0, 0, 0.16)
	_crosshair.add_child(ring)
	for tick in [Vector2(40, 0), Vector2(40, 70), Vector2(0, 40), Vector2(70, 40)]:
		var mark := ColorRect.new()
		mark.position = tick
		mark.size = Vector2(4, 14) if tick.x == 40.0 else Vector2(14, 4)
		mark.color = GOLD
		mark.mouse_filter = MOUSE_FILTER_IGNORE
		_crosshair.add_child(mark)
	_overlay_section("Effects").add_child(_crosshair)

## 指向箭头 + 每个敌人一个准星 + 不可打出时的"思考泡"。
func _build_targeting() -> void:
	if targeting_arrow_prefab == null or selection_reticle_prefab == null or thought_bubble_prefab == null:
		push_error("CombatView 缺少指向箭头/准星/思考泡预制体（请在 main.tscn 检查器里拖拽赋值）")
		return
	_arrow = targeting_arrow_prefab.instantiate()
	_card_layer.add_child(_arrow)
	for i in _enemy_points.size():
		var reticle: Control = selection_reticle_prefab.instantiate()
		reticle.name = "Reticle%d" % i
		reticle.z_index = 106
		_overlay_section("Effects").add_child(reticle)
		_reticles.append(reticle)
	_thought_bubble = thought_bubble_prefab.instantiate()
	_thought_bubble.z_index = 130
	_thought_bubble.visible = false
	_overlay_section("Effects").add_child(_thought_bubble)


func _build_enemy(index: int) -> void:
	var center: Vector2 = _enemy_points[index]
	var ui_anchor: Vector2 = _enemy_ui_points[index]
	var actor: Node = battle_world.get_enemy_actor(index)
	var target := Control.new()
	# 热区严格对齐精灵本体：直接取角色节点自身的矩形。
	# 原来手写 center-(70,155)/尺寸(140,300)，而精灵底边在脚底、高 320 —— 两者差 37px，
	# 表现就是「点不到怪物 / 拖牌判定的位置和贴图对不上」。
	if actor != null and is_instance_valid(actor):
		target.position = actor.position
		target.size = actor.size
	else:
		target.position = center - Vector2(70, 155)
		target.size = Vector2(140, 300)
	target.mouse_filter = MOUSE_FILTER_STOP
	target.mouse_default_cursor_shape = CURSOR_CROSS
	_overlay_section("WorldTargets").add_child(target)
	target.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and is_instance_valid(_selected):
			_play_card_on(_selected.instance, index)
			get_viewport().set_input_as_handled())
	target.mouse_entered.connect(func():
		if is_instance_valid(_selected):
			_set_target(index))
	target.mouse_exited.connect(func():
		if not _dragging:
			_set_target(-1))
	# 血条和意图基于角色场景给出的 head_anchor，对齐后不再依赖人物缩放。
	var meters := _hud_section("CombatMeters")
	var intent_panel := _texture(meters, "intent_attack", ui_anchor + Vector2(-25, -151), Vector2(50, 50))
	intent_panel.mouse_filter = MOUSE_FILTER_STOP
	intent_panel.mouse_default_cursor_shape = CURSOR_HELP
	var intent := _label(meters, "攻击 6", ui_anchor + Vector2(-72, -99), Vector2(144, 22), 14, RED)
	intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent.mouse_filter = MOUSE_FILTER_STOP
	intent_panel.pivot_offset = intent_panel.size * 0.5
	var plate: Panel = world_status_prefab.instantiate()
	plate.position = ui_anchor + Vector2(-72, -78)
	meters.add_child(plate)
	var name_label := plate.get_node("NameLabel") as Label
	var ghost := plate.get_node("HPGhost") as ProgressBar
	var hp := plate.get_node("HPBar") as ProgressBar
	var hp_label := plate.get_node("HPLabel") as Label
	var statuses := plate.get_node("StatusRow") as HBoxContainer
	plate.call("place_statuses_at", _actor_foot_point(actor, center))
	enemy_rows.append({"actor": actor, "target": target, "intent": intent, "intent_panel": intent_panel, "plate": plate, "name_label": name_label, "hp": hp, "ghost": ghost, "hp_label": hp_label, "statuses": statuses, "alive": true, "last_intent": ""})

func _actor_foot_point(actor: Node, fallback: Vector2) -> Vector2:
	if actor is Control:
		return actor.position + Vector2(actor.size.x * 0.5, actor.size.y + 6.0)
	return fallback + Vector2(0, 148)

func _build_popups() -> void:
	var menus := _overlay_section("Menus")
	_preview_card = CardScene.instantiate()
	_preview_card.name = "CardPreview"
	_preview_card.mouse_filter = MOUSE_FILTER_IGNORE
	_preview_card.z_index = 160
	_preview_card.hide()
	menus.add_child(_preview_card)
	_overflow_overlay = menus.get_node("HandOverflowPicker") as Control
	_overflow_overlay.card_chosen.connect(_on_overflow_card_chosen)
	_log_panel = _panel(menus, Vector2(1240, 115), Vector2(630, 414), CYAN)
	_log_panel.z_index = 180
	_log_panel.mouse_filter = MOUSE_FILTER_STOP
	_log_panel.hide()
	_label(_log_panel, "战斗记录", Vector2(22, 17), Vector2(300, 36), 23)
	_log_label = RichTextLabel.new()
	_log_label.position = Vector2(23, 67)
	_log_label.size = Vector2(584, 322)
	_log_label.bbcode_enabled = true
	_log_label.add_theme_font_size_override("normal_font_size", 17)
	_log_panel.add_child(_log_label)
	_help_panel = _panel(menus, Vector2(1057, 114), Vector2(655, 469), CYAN)
	_help_panel.z_index = 180
	_help_panel.mouse_filter = MOUSE_FILTER_STOP
	_help_panel.hide()
	_label(_help_panel, "回声协议 / 战斗指南", Vector2(28, 22), Vector2(590, 43), 27, CYAN)
	var help := _label(_help_panel, "交替规程（青）与变异（品红），累积回声。\n首张牌建立基准；中立牌保持当前回声。\n\n连击      1      2      3      4      5+\n倍率  ×1.15  ×1.30  ×1.50  ×1.75  ×2.00\n3 连击后，攻击额外抽牌。回合结束连击归零。\n\n变异会推高隔离值：3 / 6 / 8 / 10 触发阈值。\n达到 10 时同化，结束战斗。\n\n按住卡牌拖动箭头选择目标，原卡留在手牌区。\n点击卡牌可在中央放大阅读；辅助牌可拖向战场。\n1–0 选牌，Tab 切换目标，Enter 确认。\n空格结束回合；右键取消；R 重新开始。", Vector2(28, 81), Vector2(600, 368), 19)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pile_panel = _panel(menus, Vector2(540, 150), Vector2(840, 750), CYAN)
	_pile_panel.z_index = 200
	_pile_panel.mouse_filter = MOUSE_FILTER_STOP
	_pile_panel.hide()
	_result_overlay = Control.new()
	_result_overlay.size = size
	_result_overlay.z_index = 220
	_result_overlay.mouse_filter = MOUSE_FILTER_STOP
	_overlay_section("Results").add_child(_result_overlay)
	var dim := ColorRect.new()
	dim.size = size
	dim.color = Color(0.025, 0.035, 0.055, 0.92)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	_result_overlay.add_child(dim)
	_label(_result_overlay, "ARKHAM / MISSION REPORT", Vector2(610, 256), Vector2(700, 34), 18, DIM).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label = _label(_result_overlay, "", Vector2(460, 329), Vector2(1000, 103), 70)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body = _label(_result_overlay, "", Vector2(460, 464), Vector2(1000, 180), 24)
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_overlay.hide()

func _show_overflow_picker() -> void:
	if combat == null or not combat.has_hand_overflow():
		return
	_refresh_discard_zone()
	_cancel_selection()
	# 待结算的牌还属于手牌。整理前撤回队列，让玩家能从全部手牌中选择；
	# 否则弃掉一张排队牌后，它的飞行视图可能悬空。
	for item in _play_queue:
		_queued_instances.erase(item.instance)
		_return_queued_card(item, "结束回合前先整理手牌")
	_play_queue.clear()
	_overflow_overlay.show_candidates(combat)


func _on_overflow_card_chosen(card: CardInstance) -> void:
	if combat == null or not combat.discard_overflow_card(card):
		return
	juice.play_sound("grab")
	if combat.has_hand_overflow():
		_show_overflow_picker()
		return
	_overflow_overlay.close()
	_apply_snapshot(_take_snapshot())
	_sync_hand(combat.hand)
	_animate_pending_draws()
	_hint_label.text = "已整理至 8 张手牌"
	if _pending_end_turn:
		_pending_end_turn = false
		call_deferred("_on_end_turn_pressed")


func _build_settings() -> void:
	_settings_panel = _panel(_overlay_section("Menus"), Vector2(563, 135), Vector2(795, 813), CYAN)
	_settings_panel.z_index = 210
	_settings_panel.mouse_filter = MOUSE_FILTER_STOP
	_settings_panel.hide()
	_label(_settings_panel, "表现与无障碍", Vector2(28, 22), Vector2(590, 45), 29)
	_button(_settings_panel, "关闭", Vector2(646, 23), Vector2(114, 42), _toggle_settings, DIM)
	_label(_settings_panel, "震屏强度  /  0–100%", Vector2(31, 88), Vector2(350, 28), 18, CYAN)
	var shake := HSlider.new()
	shake.position = Vector2(355, 92)
	shake.size = Vector2(397, 28)
	shake.min_value = 0
	shake.max_value = 100
	shake.value = float(juice.settings.shake_strength) * 100
	shake.value_changed.connect(func(value): juice.set_setting("shake_strength", value / 100.0))
	_settings_panel.add_child(shake)
	var settings := [["reduce_flashes", "减弱闪光 / 改用柔和色调"], ["reduce_motion", "减弱镜头运动 / 关闭旋转与推近"], ["particles", "粒子与拖尾"], ["damage_numbers", "浮动数字"], ["screen_effects", "屏幕光效 / 暗角与色差"], ["hit_stop", "命中停顿与慢动作"], ["sound", "战斗音效"], ["card_animations", "卡牌动画"], ["enemy_animations", "角色动作与受击动画"], ["combo_effects", "回声连击特效"], ["corruption_effects", "隔离值扭曲"], ["shield_effects", "护盾与治疗特效"], ["turn_effects", "回合过场与意图动画"]]
	for i in settings.size():
		var key: String = settings[i][0]
		var check := CheckButton.new()
		check.text = settings[i][1]
		check.position = Vector2(30, 146 + i * 43)
		check.size = Vector2(730, 38)
		check.button_pressed = bool(juice.settings.get(key, true))
		check.add_theme_font_size_override("font_size", 18)
		check.toggled.connect(func(value):
			juice.set_setting(key, value)
			_apply_motion_settings())
		_settings_panel.add_child(check)
	_label(_settings_panel, "设置自动保存。降低动效不影响任何战斗规则。", Vector2(32, 738), Vector2(718, 28), 16, DIM)
	_button(_settings_panel, "重新开始战斗", Vector2(31, 768), Vector2(350, 38), restart, GOLD)
	_button(_settings_panel, "退出游戏", Vector2(405, 768), Vector2(350, 38), func(): get_tree().quit(), RED)

func _toggle_settings() -> void:
	_cancel_selection()
	_settings_panel.visible = not _settings_panel.visible

func _apply_motion_settings() -> void:
	hero.animated = juice.enabled("enemy_animations")
	ally.animated = juice.enabled("enemy_animations")
	for row in enemy_rows:
		row.actor.animated = juice.enabled("enemy_animations")

func _show_pile(title: String, pile: Array[CardInstance]) -> void:
	_cancel_selection()
	for child in _pile_panel.get_children():
		child.queue_free()
	_label(_pile_panel, title + " / %d 张" % pile.size(), Vector2(32, 23), Vector2(630, 44), 29, CYAN)
	_button(_pile_panel, "关闭", Vector2(675, 24), Vector2(124, 42), func(): _pile_panel.hide(), DIM)
	var names: PackedStringArray = []
	for card in pile:
		names.append("%s   ·   %s   ·   %d 能量" % [card.display_name(), card.data.faction_name(), card.effective_cost(combat.isolation)])
	# Draw pile order is deliberately hidden, as in a physical shuffled deck.
	if title == "抽牌堆":
		names.sort()
	var content := _label(_pile_panel, "\n\n".join(names) if not names.is_empty() else "牌堆为空", Vector2(35, 90), Vector2(765, 620), 21)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pile_panel.show()

func _take_snapshot() -> Dictionary:
	var enemies: Array[Dictionary] = []
	for enemy in combat.enemies:
		enemies.append(enemy.duplicate(true))
	return {"hp": combat.player_hp, "block": combat.player_block, "energy": combat.energy, "statuses": combat.player_statuses.duplicate(), "isolation": combat.isolation.value, "stage": combat.isolation.stage_name(), "streak": combat.echo.streak, "multiplier": combat.echo.current_multiplier(), "required": combat.required_faction(), "turn": combat.turn_number, "phase": combat.phase, "enemies": enemies, "hand": combat.hand.duplicate(), "draw": combat.draw_pile.size(), "discard": combat.discard_pile.size(), "exhaust": combat.exhaust_pile.size()}

func _record(kind: String, data: Dictionary = {}) -> void:
	if not _recording:
		return
	data["kind"] = kind
	data["snapshot"] = _take_snapshot()
	_events.append(data)

func _set_active_character(character_id: String) -> void:
	battle_world.set_active_character(character_id)
	hero = battle_world.player_actor
	ally = battle_world.companion_actor
	var active_panel := _song_status_panel if character_id == CharacterRules.SONG_MEI else _shen_status_panel
	var support_panel := _shen_status_panel if character_id == CharacterRules.SONG_MEI else _song_status_panel
	if active_panel.get_parent() != _player_status_layer:
		active_panel.reparent(_player_status_layer)
	if support_panel.get_parent() != _companion_status_layer:
		support_panel.reparent(_companion_status_layer)
	active_panel.position = Vector2(26, 78)
	support_panel.position = Vector2(26, 176)
	active_panel.set("show_block", true)
	support_panel.set("show_block", false)
	_hp_label = active_panel.get_node("HPLabel") as Label
	_hp_ghost = active_panel.get_node("HPGhost") as ProgressBar
	_hp_bar = active_panel.get_node("HPBar") as ProgressBar
	_block_label = active_panel.get_node("BlockLabel") as Label
	_shield_seg = active_panel.get_node("ShieldSegment") as ColorRect
	_status_label = active_panel.get_node("StatusLabel") as Label
	_hero_point = battle_world.player_screen_point()
	if _player_world_bar != null:
		_player_world_bar.position = _hero_point + Vector2(-72, -207)
		_player_world_bar.get_node("NameLabel").set("text", "宋梅" if character_id == CharacterRules.SONG_MEI else "沈明")
		_player_world_bar.call("place_statuses_at", _actor_foot_point(hero, _hero_point))

func start_new_combat() -> void:
	_epoch += 1
	_pending_end_turn = false
	_draw_generation += 1
	_pending_draw_views.clear()
	_busy = false
	_recording = false
	_events.clear()
	_cancel_selection()
	if _overflow_overlay != null:
		_overflow_overlay.close()
	for tw in _ui_tweens:
		if tw != null and tw.is_valid(): tw.kill()
	_ui_tweens.clear()
	juice.reset()
	_result_overlay.hide()
	_log_lines.clear()
	for card in card_views:
		if is_instance_valid(card): card.queue_free()
	card_views.clear()
	for child in flight_layer.get_children(): child.queue_free()
	for row in enemy_rows:
		row.actor.reset_actor()
		# The 3D actor owns its authored world-space anchor.
		row.alive = true
		row.last_intent = ""
	_set_active_character(_run_rules.id if _run_battle else CharacterRules.SHEN_MING)
	hero.reset_actor()
	ally.reset_actor()
	combat = CombatManager.new()
	combat.damage_dealt.connect(func(source, target, amount, blocked): _record("damage", {"source": source, "target": target, "amount": amount, "blocked": blocked}))
	combat.hand_changed.connect(func(): _record("hand"))
	combat.player_stats_changed.connect(func(): _record("player"))
	combat.enemy_stats_changed.connect(func(index): _record("enemy", {"index": index}))
	combat.energy_changed.connect(func(_a, _b): _record("stats"))
	combat.piles_changed.connect(func(_a, _b, _c): _record("stats"))
	combat.echo_changed.connect(func(_a, _b): _record("stats"))
	combat.echo.echo_triggered.connect(func(streak): _record("echo", {"streak": streak}))
	combat.isolation_changed.connect(func(_value): _record("isolation"))
	combat.isolation_threshold.connect(func(value, stage): _record("threshold", {"value": value, "stage": stage}))
	combat.turn_started.connect(func(turn, player): _record("turn", {"turn": turn, "player": player}))
	combat.enemy_acted.connect(func(index, intent): _record("acted", {"index": index, "intent": intent}))
	combat.enemy_intents_updated.connect(func(): _record("intents"))
	combat.whisper.connect(func(text): _record("log", {"text": text}))
	combat.combat_ended.connect(func(victory): _record("result", {"victory": victory}))
	var card_db := get_node("/root/CardDB")
	var enemies: Array[EnemyData] = [card_db.get_enemy("lurker"), card_db.get_enemy("sentry")]
	if _run_battle:
		enemies = _run_enemies
		combat.start_combat(_run_deck, enemies, _run_hp, _run_rules, _run_trinkets)
	else:
		combat.start_combat(card_db.build_starter_deck(), enemies)
	_snapshot = _take_snapshot()
	_apply_snapshot(_snapshot, true)
	_sync_hand(combat.hand)
	_refresh_discard_zone()
	_animate_pending_draws()
	_apply_motion_settings()
	juice.turn_banner("你的回合", true)
	if _run_battle:
		var enemy_names: PackedStringArray = []
		for enemy in enemies: enemy_names.append(enemy.display_name)
		_log("[color=#6bc7ff]遭遇：%s。[/color]" % " / ".join(enemy_names))
	else:
		_log("[color=#6bc7ff]进入生物实验舱。威胁：眷族变体 A / 眷族变体 B。[/color]")
	if combat.character_rules.retain_hand:
		_log("沈明·留牌：首回合 5 张，此后每回合抽 3 并留住旧牌；结束回合须≤8 张。")
	else:
		_log("宋梅·常规抽牌：每回合抽 5 张；回合结束时未打出的牌进入弃牌堆。")

func begin_run_battle(deck: Array[CardData], enemies: Array[EnemyData], hp: int, rules: CharacterRules = null, trinkets: Array[String] = []) -> void:
	_run_battle = true
	_run_deck = deck
	_run_enemies = enemies
	_run_hp = hp
	_run_rules = rules if rules != null else CharacterRules.new()
	_run_trinkets = trinkets.duplicate()
	start_new_combat()

func restart() -> void:
	if _settings_panel != null: _settings_panel.hide()
	_pile_panel.hide()
	start_new_combat()

func _tween() -> Tween:
	var tw := create_tween()
	_ui_tweens = _ui_tweens.filter(func(item): return item != null and item.is_valid())
	_ui_tweens.append(tw)
	return tw

func _apply_snapshot(state: Dictionary, instant: bool = false) -> void:
	var previous := _snapshot
	_snapshot = state
	_hp_label.text = "%d / 70" % maxi(0, state.hp)
	_hp_bar.value = state.hp
	if instant:
		_hp_ghost.value = state.hp
	elif _hp_ghost.value != state.hp:
		_tween().tween_property(_hp_ghost, "value", state.hp, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_block_label.text = "格挡 %d" % state.block
	# 护盾黄段：从当前生命的末端往后接，右端不越出血条
	var hp_ratio: float = clampf(float(state.hp) / 70.0, 0.0, 1.0)
	var sh_ratio: float = clampf(float(state.block) / 70.0, 0.0, 1.0 - hp_ratio)
	var bar_w: float = _hp_bar.size.x - 2.0
	_shield_seg.position = _hp_bar.position + Vector2(1.0 + bar_w * hp_ratio, 1.0)
	_shield_seg.size = Vector2(bar_w * sh_ratio, _hp_bar.size.y - 2.0)
	_energy_label.text = str(state.energy)
	_isolation_label.text = "隔离 %d / 10  ·  %s" % [state.isolation, state.stage]
	for i in 10:
		var active_color := CYAN if i < 5 else (GOLD if i < 8 else RED)
		_isolation_cells[i].color = active_color if i < state.isolation else Color("271022")
	_echo_label.text = "回响 %d  /  ×%.2f" % [state.streak, state.multiplier]
	_echo_label.add_theme_color_override("font_color", GOLD if state.streak >= 4 else CYAN)
	for i in _echo_cells.size():
		var style := _echo_cells[i].get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		var active: bool = i < int(state.streak) or (i == 5 and int(state.streak) >= 5)
		style.bg_color = (GOLD if state.streak >= 4 else CYAN) if active else Color("111620")
		_echo_cells[i].add_theme_stylebox_override("panel", style)
	var required: int = state.required
	_next_label.text = "下一张打出「%s」 → 回声 +1" % ("规程" if required == 0 else "变异") if required >= 0 else "交替打出规程与变异，建立回声"
	_next_label.add_theme_color_override("font_color", MAGENTA if required == 1 else CYAN)
	_turn_label.text = "%s  /  %02d" % ["敌人行动" if state.phase == CombatManager.Phase.ENEMY_TURN else "你的回合", state.turn + 1]
	_status_label.text = _status_text(state.statuses)
	(_player_world_bar.get_node("HPBar") as ProgressBar).max_value = 70
	(_player_world_bar.get_node("HPGhost") as ProgressBar).max_value = 70
	_player_world_bar.get_node("HPBar").set("value", state.hp)
	_player_world_bar.get_node("HPLabel").set("text", "%d / 70%s" % [maxi(0, state.hp), "   格挡 %d" % state.block if state.block > 0 else ""])
	var player_ghost := _player_world_bar.get_node("HPGhost") as ProgressBar
	if instant: player_ghost.value = state.hp
	elif player_ghost.value != state.hp:
		_tween().tween_property(player_ghost, "value", state.hp, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_player_world_bar.call("set_statuses", state.statuses)
	_player_world_bar.call("place_statuses_at", _actor_foot_point(hero, _hero_point))
	_draw_button.text = "牌库  %d" % state.draw
	_discard_button.text = "弃牌  %d" % state.discard
	_discard_button.tooltip_text = "弃牌堆 %d · 消耗 %d" % [state.discard, state.exhaust]
	for i in enemy_rows.size():
		var row: Dictionary = enemy_rows[i]
		if i >= state.enemies.size():
			row.actor.visible = false
			row.intent.visible = false
			row.intent_panel.visible = false
			row.plate.visible = false
			row.target.visible = false
			row.target.mouse_filter = MOUSE_FILTER_IGNORE
			row.alive = false
			continue
		var enemy: Dictionary = state.enemies[i]
		row.name_label.text = enemy.data.display_name
		row.hp.max_value = enemy.max_hp
		row.ghost.max_value = enemy.max_hp
		row.hp.value = enemy.hp
		if instant: row.ghost.value = enemy.hp
		elif row.ghost.value != enemy.hp:
			_tween().tween_property(row.ghost, "value", enemy.hp, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		row.hp_label.text = "%d / %d%s" % [enemy.hp, enemy.max_hp, "   格挡 %d" % enemy.block if enemy.block > 0 else ""]
		row.plate.call("set_statuses", enemy.statuses)
		row.plate.call("place_statuses_at", _actor_foot_point(row.actor, _enemy_points[i]))
		if not enemy.alive:
			row.intent.visible = false
			row.intent_panel.visible = false
			row.plate.visible = false
			row.target.visible = false
			row.target.mouse_filter = MOUSE_FILTER_IGNORE
			if row.alive:
				row.alive = false
				row.actor.die(juice.enabled("enemy_animations"))
				juice.burst(_enemy_points[i], "tissue", 35)
				juice.burst(_enemy_points[i], "smoke", 8)
				juice.hit_stop(0.12)
				juice.add_trauma(0.8)
				juice.play_sound("death")
		else:
			row.alive = true
			row.actor.visible = true
			row.intent.visible = true
			row.intent_panel.visible = true
			row.plate.visible = true
			row.target.visible = true
			row.target.mouse_filter = MOUSE_FILTER_STOP
			var intent: Dictionary = enemy.data.intent_at(enemy.intent_index)
			var text := _intent_text(intent, enemy, state.statuses)
			row.intent.text = text
			row.intent_panel.tooltip_text = _intent_tooltip(intent, text)
			row.intent.tooltip_text = row.intent_panel.tooltip_text
			row.intent.add_theme_color_override("font_color", RED if intent.type in ["attack", "attack_block"] else CYAN)
			row.intent_panel.set_variant(_intent_variant(intent.get("type", "")))
			row.intent_panel.modulate.a = 1.0
			if text != row.last_intent:
				row.last_intent = text
				if juice.enabled("turn_effects"):
					# intent 现在直接挂在 self 下（绝对坐标），基准 y 必须重算；
					# 原来用的 -12 / 7.0 是「相对面板」的局部坐标，会把标签甩出屏幕。
					var base_y: float = _enemy_ui_points[i].y - 99.0
					row.intent.position.y = base_y - 12.0
					_tween().tween_property(row.intent, "position:y", base_y, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
					juice.burst(_enemy_points[i] + Vector2(0, -292), "smoke", 3)
	_end_turn_button.disabled = _busy or combat.is_over()
	_refresh_discard_zone()
	if not previous.is_empty() and not instant:
		if state.hp > previous.hp:
			juice.heal(_hero_point)
			juice.number(_hero_point + Vector2(0, -110), "+%d" % (state.hp - previous.hp), GREEN)
			_tween().tween_property(_hp_bar, "value", state.hp, 0.3).from(previous.hp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if state.block > previous.block:
			juice.shield(_hero_point)
			juice.block_spark(_hero_point)
			juice.number(_hero_point + Vector2(45, -80), "+%d 格挡" % (state.block - previous.block), CYAN)
		if state.isolation != previous.isolation:
			juice.number(Vector2(1310, 173), "隔离 %+d" % (state.isolation - previous.isolation), MAGENTA)
		for i in enemy_rows.size():
			if i < previous.enemies.size() and state.enemies[i].statuses != previous.enemies[i].statuses:
				enemy_rows[i].statuses.scale = Vector2(1.15, 1.15)
				_tween().tween_property(enemy_rows[i].statuses, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				juice.burst(_enemy_points[i], "glow", 4)
				juice.play_sound("hover", 0.82)

func _status_text(statuses: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in statuses:
		if statuses[key] > 0: parts.append("%s %d" % [CardData.new()._status_name(key), statuses[key]])
	return "  ·  ".join(parts)

func _intent_text(intent: Dictionary, enemy: Dictionary, player_statuses: Dictionary) -> String:
	var value: int = intent.get("value", 0)
	match intent.get("type", ""):
		"attack", "attack_block":
			var damage := DamagePipeline.compute(value, enemy.statuses, player_statuses, 1.0)
			return "攻击 %d%s%s" % [damage, " × %d" % intent.times if intent.get("times", 1) > 1 else "", " / 护盾" if intent.type == "attack_block" else ""]
		"block": return "格挡 %d" % value
		"debuff": return "%s %d" % [CardData.new()._status_name(intent.get("status", "")), value]
		"buff": return "%s +%d" % [CardData.new()._status_name(intent.get("status", "")), value]
	return "未知意图"

func _intent_variant(intent_type: String) -> String:
	match intent_type:
		"attack", "attack_block":
			return "intent_attack"
		"debuff":
			return "intent_debuff"
		"buff", "block":
			return "intent_shield"
	return "intent_unknown"

func _intent_tooltip(intent: Dictionary, preview: String) -> String:
	match intent.get("type", ""):
		"attack": return "敌人下次行动：%s。\n伤害会先被格挡抵消。" % preview
		"attack_block": return "敌人下次行动：%s。\n攻击后还会获得格挡。" % preview
		"block": return "敌人下次行动：%s。\n格挡会抵消本回合受到的伤害。" % preview
		"debuff", "buff":
			var status_key: String = intent.get("status", "")
			var info: Array = StatusIcon.DETAILS.get(status_key, [])
			return "敌人下次行动：%s。\n%s" % [preview, info[2] if info.size() > 2 else "查看下方状态图标了解效果。"]
	return "敌人下次行动：%s。" % preview

func _process(delta: float) -> void:
	_intent_clock += delta
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_sync_world_anchors()
	_sync_reticle_anchors()
	for row in enemy_rows:
		if row.alive and String(row.intent.text).begins_with("攻击"):
			var pulse := 1.0 + 0.035 * sin(_intent_clock * TAU / 1.2)
			row.intent_panel.scale = Vector2.ONE * pulse
	_drive_motion(delta)
	if _dragging and is_instance_valid(_drag_view):
		_update_drag()
	elif is_instance_valid(_selected):
		# 点击只显示中央预览；指向箭头只属于真实拖拽。
		_set_target(_enemy_at(_pointer_position()))


## 准星锚点同步：刻意不放在 _sync_world_anchors() 里，
## 因为那个函数在 battle_world.camera == null（纯 2D 战斗场景）时会提前返回，
## 会让准星永远停在 (0,0)。
func _sync_reticle_anchors() -> void:
	for i in _reticles.size():
		if i >= enemy_rows.size() or i >= _enemy_points.size():
			_reticles[i].visible = false
			continue
		var alive: bool = enemy_rows[i].alive
		_reticles[i].position = _enemy_points[i] - _reticles[i].size * 0.5
		_reticles[i].visible = alive
		if not alive and _reticles[i].selected:
			_reticles[i].deselect()


func _sync_world_anchors() -> void:
	if battle_world == null or battle_world.camera == null:
		return
	var transform := battle_world.get_global_transform()
	_hero_point = transform * battle_world.player_screen_point()
	_player_world_bar.position = _hero_point + Vector2(-72, -207)
	_player_world_bar.call("place_statuses_at", _actor_foot_point(hero, _hero_point))
	for i in mini(enemy_rows.size(), battle_world.enemy_actors.size()):
		var center: Vector2 = transform * battle_world.enemy_screen_point(i)
		_enemy_points[i] = center
		var row: Dictionary = enemy_rows[i]
		row.target.position = center - Vector2(70, 155)
		row.intent_panel.position = center + Vector2(-28, -330)
		row.intent.position = center + Vector2(-65, -270)
		# 名字 / 血条 / 状态全部挂在 plate 底下（局部坐标），只移动底板即可
		row.plate.position = center + Vector2(-72, -244)
		row.plate.call("place_statuses_at", _actor_foot_point(row.actor, center))

func _input(event: InputEvent) -> void:
	if _overflow_overlay != null and _overflow_overlay.visible:
		return
	# 点击拾起模式下：点在敌人身上 = 找到目标，入队释放。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
			and is_instance_valid(_selected) and not _dragging:
		var point := _pointer_position()
		if _preview_card.visible and _preview_card.get_global_rect().has_point(point):
			return
		# 点在卡牌上交给卡牌自身的 pressed 信号处理（换牌 / 取消）
		if _card_at(point) == null:
			var enemy_index := _enemy_at(point)
			if enemy_index >= 0:
				_play_picked(enemy_index)
				get_viewport().set_input_as_handled()
				return
			# 自身牌：点到出牌区即可释放（不需要找敌人）
			if not _card_requires_enemy_target(_selected.instance) and point.y < size.y * PLAY_ZONE_PROPORTION:
				_play_picked(-1)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_selection()
		get_viewport().set_input_as_handled()
		return
	if _dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _settings_panel.visible: _settings_panel.hide()
		elif _pile_panel.visible: _pile_panel.hide()
		elif _help_panel.visible: _help_panel.hide()
		elif _log_panel.visible: _log_panel.hide()
		else: _toggle_settings()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("end_turn"):
		_on_end_turn_pressed()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.keycode
		if key >= KEY_1 and key <= KEY_9:
			_select_card(int(key - KEY_1))
		elif key == KEY_0:
			_select_card(9)
		elif key == KEY_TAB and is_instance_valid(_selected):
			var alive := _alive_enemy_indices()
			if not alive.is_empty():
				var next := alive[0]
				if _hover_enemy in alive:
					next = alive[(alive.find(_hover_enemy) + 1) % alive.size()]
				_set_target(next)
		elif (key == KEY_ENTER or key == KEY_KP_ENTER) and is_instance_valid(_selected):
			var target := _hover_enemy
			if target < 0:
				var alive := _alive_enemy_indices()
				if not alive.is_empty(): target = alive[0]
			if target >= 0: _enqueue_play(_selected, _selected.instance, target)

# ── 出牌区 / 取消区 ─────────────────────────────────────────────────────
# 阈值不是一条固定横线，而是按拖拽起点自适应（尖塔2 的做法）：
#   基准 = 屏幕高 × 0.75；起点在基准下方 → 再多拖 100；起点在上方 → 只需再拖 50。
func _play_zone_threshold() -> float:
	var base := size.y * PLAY_ZONE_PROPORTION
	if _drag_start_y > base:
		return maxf(base, _drag_start_y - FAKE_LOWER_ENTER_DISTANCE)
	return minf(base, _drag_start_y - FAKE_UPPER_ENTER_DISTANCE)


func _cancel_zone_threshold() -> float:
	return size.y * CANCEL_ZONE_PROPORTION


func _pointer_position() -> Vector2:
	return pointer_override if pointer_override.is_finite() else get_global_mouse_position()


func _pointer_in_play_zone() -> bool:
	return _pointer_position().y < _play_zone_threshold()


func _pointer_in_cancel_zone() -> bool:
	return _pointer_position().y > _cancel_zone_threshold()


## 进入 / 退出出牌区时只切换指向状态，卡牌仍留在手牌槽。
func _enter_cast_mode() -> void:
	_cast_mode = true
	juice.play_sound("hover", 0.92)


func _exit_cast_mode() -> void:
	_cast_mode = false
	if juice.enabled("card_animations") and is_instance_valid(_drag_view):
		_drag_view.scale = Vector2.ONE * CARD_HOVER_SCALE


func _update_arrow() -> void:
	if _arrow == null: return
	var source: Control = _drag_view if _dragging else _selected
	if not is_instance_valid(source): return
	var from: Vector2 = source.get_global_transform() * (source.size * 0.5)
	_arrow.from_position = _arrow.get_global_transform().affine_inverse() * from


func _stop_arrow() -> void:
	if _arrow != null: _arrow.stop_drawing()
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _update_reticles() -> void:
	var all_targets := _dragging and is_instance_valid(_drag_view) \
		and not _card_requires_enemy_target(_drag_view.instance) and _pointer_in_play_zone()
	for i in _reticles.size():
		if i >= enemy_rows.size(): continue
		if not enemy_rows[i].alive:
			if _reticles[i].selected: _reticles[i].deselect()
			continue
		var focus := _hover_enemy if is_instance_valid(_active_card()) else -1
		var want := (i == focus) or all_targets
		if want and not _reticles[i].selected: _reticles[i].select()
		elif not want and _reticles[i].selected: _reticles[i].deselect()


## 不可打出的反馈：卡牌抖动 + 主角头顶冒一句"为什么打不了"。
func _deny_card(view: Control, reason: String) -> void:
	juice.play_sound("deny")
	_shake_card(view)
	_show_thought(reason)


func _shake_card(view: Control) -> void:
	if not is_instance_valid(view): return
	if not juice.enabled("card_animations"):
		_snap_card_home(view)
		return
	# 抖动只是偏移参数；同时重设运动目标为原位，保证抖完一定回手牌。
	view.shake_time = 0.22
	view.shake_amp = 10.0
	_set_motion(view, view.home, view.home_rotation, Vector2.ONE * view.base_scale)


func _show_thought(text: String) -> void:
	if _thought_bubble == null: return
	_thought_bubble.text = text
	_thought_bubble.position = _hero_point + Vector2(-160, -300)
	_thought_bubble.modulate.a = 1.0
	_thought_bubble.visible = true
	if _thought_tween != null and _thought_tween.is_valid(): _thought_tween.kill()
	_thought_tween = create_tween()
	_thought_tween.tween_interval(1.2)
	_thought_tween.tween_property(_thought_bubble, "modulate:a", 0.0, 0.35)
	_thought_tween.tween_callback(func(): if _thought_bubble != null: _thought_bubble.visible = false)


## 入队停放：牌先进出牌区左侧的队列位，等前一张结算完再飞出去。
## 位置与缩放公式来自尖塔2 NCardPlayQueue。
func _stage_card_in_queue(view: Control) -> void:
	if not is_instance_valid(view): return
	if not juice.enabled("card_animations"):
		return
	if view.motion != null and view.motion.is_running(): view.motion.kill()
	view.motion_active = false
	_play_queue_depth += 1
	var n := float(_play_queue_depth)
	var slot: Vector2 = QUEUE_ANCHOR + Vector2.LEFT * 300.0 * (n / (n + 2.0))
	var slot_scale: float = float(view.base_scale) * (1.0 - n / (n + 1.0))
	view.reparent(flight_layer, true)
	view.mouse_filter = MOUSE_FILTER_IGNORE
	view.z_index = 110
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(view, "global_position", slot - view.size * 0.5, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(view, "scale", Vector2.ONE * slot_scale, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(view, "rotation", 0.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	_play_queue_depth = maxi(0, _play_queue_depth - 1)


func _alive_enemy_indices() -> Array[int]:
	var result: Array[int] = []
	if combat == null: return result
	for i in combat.enemies.size():
		if combat.enemies[i].alive: result.append(i)
	return result

func _select_card(index: int) -> void:
	if index < 0 or index >= card_views.size(): return
	var view := card_views[index]
	if not view.playable:
		_deny_card(view, _deny_reason(view))
		return
	_cancel_selection()
	_pickup(view)

func _on_card_pressed(view: Control) -> void:
	if combat.is_over() or (_overflow_overlay != null and _overflow_overlay.visible):
		return
	# 再点一次已选中的同一张牌 → 关闭中央预览。
	if view == _selected:
		_cancel_selection()
		return
	if not view.playable:
		_deny_card(view, _deny_reason(view))
		return
	_cancel_selection()
	_cast_mode = false
	_drag_follow = false
	# 注意：这里不写 _selected。_selected 只表示"已拾起（固定）"，
	# 按下只是"可能开始拖拽"，由 _drag_view 表示。否则松手时
	# _handle_click 会误判成"点了同一张牌"而直接取消。
	_dragging = true
	_drag_view = view
	view.selected = true
	view.moving = true
	view.z_index = 100
	view.begin_drag()
	_drag_start = _pointer_position()
	_drag_start_y = _drag_start.y
	# 这里不隐藏光标、也不起箭头：只有指针真的移动（进入拖拽）才那样做。
	# 单纯点击走"中央预览 + 光标找目标"这条路，光标保持可见。
	juice.play_sound("grab")

func _discard_hand_view(view: Control) -> void:
	if _busy or view == null or not is_instance_valid(view): return
	if not combat.discard_from_hand(view.instance): return
	juice.play_sound("grab")
	_apply_snapshot(_take_snapshot())
	_sync_hand(combat.hand)
	_refresh_discard_zone()
	_hint_label.text = "已主动弃牌；剩余 %d 次" % combat.voluntary_discards_left

func _refresh_discard_zone() -> void:
	if _discard_drop_zone == null or combat == null: return
	var limit: int = combat.character_rules.voluntary_discard_limit
	_discard_drop_zone.visible = limit > 0
	var available := not _busy and not combat.is_over() and (_overflow_overlay == null or not _overflow_overlay.visible) and combat.voluntary_discards_left > 0
	_discard_drop_zone.call("set_state", combat.voluntary_discards_left, limit, available)
	if not available: _discard_drop_zone.call("set_hovered", false)

func _is_discard_target(point: Vector2) -> bool:
	return _discard_drop_zone != null and _discard_drop_zone.visible and combat != null and not _busy and not combat.is_over() and combat.voluntary_discards_left > 0 and (_overflow_overlay == null or not _overflow_overlay.visible) and _discard_drop_zone.get_global_rect().has_point(point)


func _deny_reason(view: Control) -> String:
	if view == null or view.instance == null: return "现在不能出牌"
	if view.instance.effective_cost(combat.isolation) > combat.energy: return "能量不足"
	return "等待行动"

func _update_drag() -> void:
	var mouse := _pointer_position()
	if _discard_drop_zone != null:
		_discard_drop_zone.call("set_hovered", _is_discard_target(mouse))
	# 只有箭头跟随光标；原卡始终留在手牌槽里。
	var in_zone := _pointer_in_play_zone()
	if in_zone and not _cast_mode:
		_enter_cast_mode()
	elif not in_zone and _cast_mode:
		_exit_cast_mode()
	# 单纯点击 → 只微抬，不跟随光标；指针真的移动了才开始拖拽。
	if not _drag_follow and _drag_start.distance_to(mouse) > DRAG_FOLLOW_THRESHOLD:
		_drag_follow = true
		# 进入拖拽模式：隐藏光标（箭头即光标）并起箭头
		if _arrow != null:
			var from: Vector2 = _drag_view.get_global_transform() * (_drag_view.size * 0.5)
			_arrow.start_drawing(_arrow.get_global_transform().affine_inverse() * from, true)
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if not _drag_follow:
		return
	var target := -1
	for i in enemy_rows.size():
		if enemy_rows[i].alive and enemy_rows[i].target.get_global_rect().has_point(mouse):
			target = i
			break
	# 指向牌尚未进入出牌区时不锁定目标，与尖塔2 一致：先"举起来"，再"瞄准"。
	if not _pointer_in_play_zone() and _card_requires_enemy_target(_drag_view.instance):
		target = -1
	_set_target(target)
	_update_arrow()
	_update_reticles()
	_trajectory.clear_points()

func _set_target(index: int) -> void:
	if index == _hover_enemy: return
	_hover_enemy = index
	for i in enemy_rows.size(): enemy_rows[i].actor.highlight(i == index)
	if _arrow != null:
		if _dragging and is_instance_valid(_drag_view) and _drag_view.playable:
			_arrow.set_highlight(index >= 0, true)
		else:
			_arrow.set_highlight(false, false)
	var active := _active_card()
	_target_label.visible = index >= 0 and is_instance_valid(active)
	# 拖拽瞄准用"箭头 + 四角准星"；点选出牌用"准心 + 四角准星"，两套不叠在一起。
	if _crosshair != null:
		_crosshair.visible = index >= 0 and index < _enemy_points.size() and not _dragging
	if index >= 0 and is_instance_valid(active):
		var damage := combat.preview_card_damage(active.instance, index)
		if _crosshair != null:
			_crosshair.position = _enemy_points[index] - Vector2(42, 42)
		_target_label.text = "锁定 %s%s" % [combat.enemies[index].name, "    预计伤害 %d" % damage if damage > 0 else ""]
		active.refresh(index)
	_update_reticles()

func _finish_drag() -> void:
	var view := _drag_view
	var target := _hover_enemy
	var release_point := _pointer_position()
	var distance := _drag_start.distance_to(release_point)
	_dragging = false
	_cast_mode = false
	_drag_view = null
	_trajectory.clear_points()
	_stop_arrow()
	if _discard_drop_zone != null: _discard_drop_zone.call("set_hovered", false)
	if not is_instance_valid(view): return
	view.moving = false
	# ① 几乎没移动 → 视为点击：拾起这张牌（抬出 1/4 屏高后固定），再点一次取消。
	if distance < CLICK_DRAG_THRESHOLD:
		_handle_click(view)
		return
	if _is_discard_target(release_point):
		_selected = null
		_set_target(-1)
		_discard_hand_view(view)
		return
	# ② 拖进最底部取消区 → 牌回手，什么都不发生。
	if _pointer_in_cancel_zone():
		_selected = null
		_set_target(-1)
		_snap_card_home(view)
		_hint_label.text = "按住卡牌拖动箭头 · 点击卡牌放大查看 · 右键取消"
		return
	# ③ 没拖进出牌区 → 回手。
	if not _pointer_in_play_zone():
		_selected = null
		_set_target(-1)
		_snap_card_home(view)
		_hint_label.text = "按住卡牌拖动箭头 · 点击卡牌放大查看 · 右键取消"
		return
	# ④ 已在出牌区内：有目标就打；自身牌直接结算；指向牌没目标则回手并说明。
	if target >= 0:
		_selected = null
		_enqueue_play(view, view.instance, target)
	elif not _card_requires_enemy_target(view.instance):
		_selected = null
		_enqueue_play(view, view.instance, -1)
	else:
		_selected = null
		_set_target(-1)
		_snap_card_home(view)
		_deny_card(view, "需要选定目标")


func _card_requires_enemy_target(instance: CardInstance) -> bool:
	for effect in instance.data.effects:
		if effect.get("action", "") in ["damage", "damage_multi", "apply", "damage_if_echo"]:
			return true
	return false

## 点击选牌：手牌留在原位，放大的副本平滑进入屏幕中央供阅读。
func _pickup(view: Control) -> void:
	if not is_instance_valid(view) or not view.playable:
		return
	_selected = view
	view.selected = true
	view.z_index = 70
	view.queue_redraw()
	_set_motion(view, view.home, view.home_rotation, Vector2.ONE * view.base_scale)
	_show_card_preview(view)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_target(_enemy_at(_pointer_position()))
	if _hint_label != null:
		_hint_label.text = "「%s」· 中央查看卡牌 · 点击目标出牌 · 右键取消" % view.instance.display_name()
	juice.play_sound("grab")


func _show_card_preview(view: Control) -> void:
	if _preview_card == null:
		return
	if _preview_tween != null and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview_card.setup(combat, view.instance, card_views.find(view))
	_preview_card.refresh(_hover_enemy)
	_preview_card.mouse_filter = MOUSE_FILTER_IGNORE
	for child in _preview_card.get_children():
		if child is Control:
			child.mouse_filter = MOUSE_FILTER_IGNORE
	_preview_card.global_position = view.global_position
	_preview_card.scale = view.scale
	_preview_card.rotation = view.rotation
	_preview_card.modulate.a = 0.75
	_preview_card.show()
	var destination := DESIGN_SIZE * 0.5 - _preview_card.size * 0.5
	_preview_tween = create_tween().set_parallel(true)
	_preview_tween.tween_property(_preview_card, "global_position", destination, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_preview_tween.tween_property(_preview_card, "scale", Vector2.ONE * 1.65, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_preview_tween.tween_property(_preview_card, "rotation", 0.0, 0.26)
	_preview_tween.tween_property(_preview_card, "modulate:a", 1.0, 0.20)


func _hide_card_preview() -> void:
	if _preview_card == null or not _preview_card.visible:
		return
	if _preview_tween != null and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview_card.hide()


## 点击一张手牌：同一张关闭预览，另一张切换预览。
func _handle_click(view: Control) -> void:
	if not is_instance_valid(view):
		return
	if _selected == view:
		_cancel_selection()
		return
	_cancel_selection()
	if not view.playable:
		_deny_card(view, _deny_reason(view))
		return
	_pickup(view)


## 走到"拾起 → 找到目标 → 点击 → 入队释放"的最后一步。
func _play_picked(target: int) -> void:
	var view := _selected
	if not is_instance_valid(view):
		return
	_detach_selection()
	_enqueue_play(view, view.instance, target)


## 清掉选中/拖拽/箭头状态，但不把牌弹回手牌（用于"这张牌要进队列了"）。
func _detach_selection() -> void:
	_dragging = false
	_cast_mode = false
	_drag_view = null
	_trajectory.clear_points()
	_stop_arrow()
	_hide_card_preview()
	if is_instance_valid(_selected):
		_selected.selected = false
		_selected.queue_redraw()
	_selected = null
	_set_target(-1)


## 当前正在操作的牌：拖拽中是被拖的牌，否则是已拾起的牌。
func _active_card() -> Control:
	if _dragging and is_instance_valid(_drag_view):
		return _drag_view
	return _selected if is_instance_valid(_selected) else null


func _card_at(point: Vector2) -> Control:
	for view in card_views:
		if is_instance_valid(view) and view.get_global_rect().has_point(point):
			return view
	var active := _active_card()
	if is_instance_valid(active) and active.get_global_rect().has_point(point):
		return active
	return null


func _enemy_at(point: Vector2) -> int:
	for i in enemy_rows.size():
		if enemy_rows[i].alive and enemy_rows[i].target.get_global_rect().has_point(point):
			return i
	return -1


func _cancel_selection() -> void:
	var view := _selected if is_instance_valid(_selected) else _drag_view
	_detach_selection()
	if is_instance_valid(view):
		_snap_card_home(view)
	if _hint_label != null: _hint_label.text = "按住卡牌拖动箭头 · 点击卡牌放大查看 · 右键取消"

func _snap_card_home(view: Control) -> void:
	if not is_instance_valid(view): return
	view.z_index = maxi(0, card_views.find(view))
	view.cancel_drag()
	_set_motion(view, view.home, view.home_rotation, Vector2.ONE * view.base_scale)

func _on_card_hovered(view: Control, entered: bool) -> void:
	if _dragging or _busy or not is_instance_valid(view): return
	_hover_card = view if entered else null
	if entered:
		view.lit = true
		view.z_index = 80
		_set_motion(view, view.home + Vector2(0, -34), 0.0, view.hover_scale())
		juice.play_sound("hover")
		# 金光牌 = 回声可续，悬停时撒一层闪烁微光（对应原版 card_sparkles_vfx）
		if view.glow == CardWidget.Glow.GOLD:
			juice.sparkle(view.home + view.size * 0.5, GOLD, 5)
	else:
		view.lit = false
		if view != _selected:
			view.z_index = maxi(0, card_views.find(view))
			_set_motion(view, view.home, view.home_rotation, Vector2.ONE * view.base_scale)
	view.queue_redraw()

func _sync_hand(hand: Array, animate_new: bool = true) -> void:
	# 回合中没有硬上限，额外抽到的牌仍能继续出牌。
	# 让上一批发牌回调失效；本次新牌集中到结算末尾逐张发出。
	_draw_generation += 1
	if not animate_new:
		_pending_draw_views.clear()
	var old_by_uid: Dictionary = {}
	for view in card_views:
		if is_instance_valid(view): old_by_uid[view.instance.uid] = view
	var next_views: Array[Control] = []
	var fresh: Array[Control] = []
	for i in hand.size():
		var card: CardInstance = hand[i]
		# 已排队的牌由队列管理，手牌里不能重复出现（它已经"离开"了手牌布局）。
		if _queued_instances.has(card):
			continue
		var view: Control
		if old_by_uid.has(card.uid):
			view = old_by_uid[card.uid]
			old_by_uid.erase(card.uid)
		else:
			view = CardScene.instantiate()
			view.setup(combat, card, i)
			view.pressed.connect(_on_card_pressed)
			view.hovered.connect(_on_card_hovered)
			hand_box.add_child(view)
			fresh.append(view)
		view.reset_visual_state()
		next_views.append(view)
	for uid in old_by_uid:
		var obsolete = old_by_uid[uid]
		if is_instance_valid(obsolete):
			if obsolete.motion != null and obsolete.motion.is_valid(): obsolete.motion.kill()
			obsolete.queue_free()
	card_views = next_views
	_layout_hand()
	for i in card_views.size():
		card_views[i]._index.text = str(i + 1)
		card_views[i].refresh(_hover_enemy)
	if animate_new and juice.enabled("card_animations"):
		for view in fresh:
			_pending_draw_views.append(view)
		_pending_draw_views = _pending_draw_views.filter(func(view): return is_instance_valid(view) and card_views.has(view))
		var start: Vector2 = hand_box.get_global_transform().affine_inverse() * DRAW_POINT
		for view in _pending_draw_views:
			view.position = start
			view.scale = Vector2.ONE * 0.42
			view.modulate.a = 0.0
			view.mouse_filter = MOUSE_FILTER_IGNORE


## 每次从牌库位置发出一张，落稳后再发下一张；出牌锁在动画结束后解除。
func _animate_pending_draws() -> void:
	if _pending_draw_views.is_empty():
		return
	var pending := _pending_draw_views.duplicate()
	_pending_draw_views.clear()
	var generation := _draw_generation
	for view in pending:
		if generation != _draw_generation:
			return
		if not is_instance_valid(view) or not card_views.has(view):
			continue
		var start: Vector2 = hand_box.get_global_transform().affine_inverse() * DRAW_POINT
		var destination: Vector2 = view.home
		view.position = start
		view.scale = Vector2.ONE * 0.42
		view.modulate.a = 0.0
		if is_instance_valid(_deck_icon):
			_deck_icon.scale = Vector2.ONE * 1.16
			create_tween().tween_property(_deck_icon, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		juice.play_sound("draw")
		var tw := create_tween()
		view.motion = tw
		tw.tween_method(_draw_card_step.bind(weakref(view), start, destination, generation), 0.0, 1.0, 0.27).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.29, true, false, true).timeout
		if generation != _draw_generation:
			return
		if is_instance_valid(view):
			view.position = view.home
			view.scale = Vector2.ONE * view.base_scale
			view.modulate.a = 1.0
			view.mouse_filter = MOUSE_FILTER_STOP

func _draw_card_step(t: float, reference: WeakRef, start: Vector2, destination: Vector2, generation: int) -> void:
	var view: Control = reference.get_ref()
	if not is_instance_valid(view): return
	if generation != _draw_generation:
		# 被更晚的一批发牌顶掉了。必须把牌恢复成「已就位且可见」，
		# 否则它会永远停在 modulate.a = 0 —— 表现就是「回合结束后手牌不再补充」，
		# 其实牌已经在手里，只是完全透明看不见。
		view.modulate.a = 1.0
		view.position = view.home
		view.scale = Vector2.ONE * CARD_BASE_SCALE
		return
	var mid: Vector2 = (start + destination) * 0.5 + Vector2(0, -125)
	view.position = start.lerp(mid, t).lerp(mid.lerp(destination, t), t)
	view.modulate.a = t
	view.scale = Vector2.ONE * lerpf(0.42, view.base_scale, t)

## 手牌布局的基准矩形：优先用**可见卡槽**，取不到时退回手牌容器。
## 之前用的是手牌容器自身中心，容器和卡槽贴图位置不一致时整排手牌就会看起来偏。
func _hand_tray_rect() -> Rect2:
	if is_instance_valid(_hand_tray):
		return _hand_tray.get_global_rect()
	return Rect2(hand_box.global_position, hand_box.size)


## 手牌版式：1~10 张逐张手调表（对齐尖塔2 HandPosHelper）。
## 中间牌抬高、两侧下落、两端外倾；牌多时整手缩小。
## 自适应：整排宽度超出卡槽可用宽度时，等比压缩扇形（保留表里的造型比例），
## 保证牌永远居中于卡槽、且不会被卡槽边缘裁掉。
func _layout_hand() -> void:
	var count := card_views.size()
	if count == 0: return
	var index := clampi(count, 1, HAND_POSITIONS.size()) - 1
	var positions: Array = HAND_POSITIONS[index].duplicate()
	var angles: Array = HAND_ANGLES[index].duplicate()
	if count > HAND_POSITIONS.size():
		positions.clear()
		angles.clear()
		for i in count:
			var t: float = float(i) / float(count - 1)
			var distance_from_center: float = absf(t - 0.5) * 2.0
			positions.append(Vector2(lerpf(-610.0, 610.0, t), -50.0 + 88.0 * distance_from_center * distance_from_center))
			angles.append(lerpf(-15.0, 15.0, t))
	var scale := _hand_scale(count)
	var tray := _hand_tray_rect()
	if count > HAND_POSITIONS.size():
		scale = minf(scale, maxf(tray.size.x - HAND_TRAY_MARGIN * 2.0, 32.0) / (float(count) * CardWidget.CARD_SIZE.x))
	var x_scale := tray.size.x / HAND_WIDTH_SPAN
	var center: Vector2 = hand_box.get_global_transform().affine_inverse() * tray.get_center()
	# 表格几何：扇形半宽 span、相邻牌的最小间隙 min_gap
	var span := 0.0
	var min_gap := 1e9
	for i in positions.size():
		span = maxf(span, absf(positions[i].x))
		if i > 0:
			min_gap = minf(min_gap, absf(positions[i].x - positions[i - 1].x))
	if min_gap > 1e8:
		min_gap = maxf(span, 1.0)
	# 联立求卡宽，同时满足两个约束（否则牌多时必然遮挡）：
	#   ① 整排落在卡槽内：2*span*x + card_w = avail
	#   ② 相邻牌不遮挡：min_gap*x = card_w + CARD_NO_OVERLAP_GAP
	var avail: float = maxf(tray.size.x - HAND_TRAY_MARGIN * 2.0, 32.0)
	var ratio: float = 2.0 * span / maxf(min_gap, 1.0)
	var card_w_fit: float = maxf((avail - ratio * CARD_NO_OVERLAP_GAP) / (ratio + 1.0), 1.0)
	scale = maxf(minf(scale, card_w_fit / CardWidget.CARD_SIZE.x), scale * CARD_SCALE_FLOOR)
	# 扇形压缩：保证整排不出卡槽
	var half_card: float = CardWidget.CARD_SIZE.x * scale * 0.5
	var allowed: float = maxf(tray.size.x * 0.5 - HAND_TRAY_MARGIN - half_card, 1.0)
	if span > 0.0 and span * x_scale > allowed:
		x_scale = allowed / span
	# 兜底：间距不足时把扇形张开到"卡宽 + 余量"，但仍不得超出卡槽
	if min_gap > 0.0 and span > 0.0:
		var needed_x: float = (CardWidget.CARD_SIZE.x * scale + CARD_NO_OVERLAP_GAP) / min_gap
		if x_scale < needed_x:
			x_scale = minf(needed_x, allowed / span)
	for i in count:
		var view := card_views[i]
		var offset: Vector2 = positions[i] if i < positions.size() else Vector2.ZERO
		# 注意：home 是 Control 的**左上角**。要让"视觉中心"落在 center 上，必须减去半张牌；
		# 而且要用**未缩放**的 size/2：缩放是绕 pivot（= size/2）进行的，
		# 所以视觉中心恒等于 position + size*0.5，与 scale 无关。
		view.home = Vector2(
			center.x + offset.x * x_scale - view.size.x * 0.5,
			HAND_Y_BASE + (offset.y + 50.0) * HAND_Y_SCALE)
		view.home_rotation = deg_to_rad(angles[i] if i < angles.size() else 0.0)
		view.base_scale = scale
		view.motion_active = false
		view.position = view.home
		view.rotation = view.home_rotation
		view.scale = Vector2.ONE * scale
		view.z_index = i
	# 扇形版式算完，把"整排有多宽、扇形有多深"告诉托槽，让它贴合手牌分布
	var min_offset_y := 1e9
	var max_offset_y := -1e9
	for offset in positions:
		min_offset_y = minf(min_offset_y, offset.y)
		max_offset_y = maxf(max_offset_y, offset.y)
	var fan_rise: float = maxf((max_offset_y - min_offset_y) * HAND_Y_SCALE, 6.0)
	var row_half: float = span * x_scale + half_card
	if is_instance_valid(_hand_tray) and _hand_tray.has_method("set_fan"):
		_hand_tray.set_fan(row_half * 2.0, fan_rise, HAND_TRAY_MIN_WIDTH)


func _hand_scale(count: int) -> float:
	return CARD_BASE_SCALE * float(HAND_SCALE_STEPS.get(count, 1.0))


# ── 逐帧 Lerp 运动系统 ──────────────────────────────────────────────────
# 与尖塔2 一致：不用 Tween，每帧向目标插值，因此随时可以改目标、随时可被打断。
func _set_motion(view: Control, target_pos: Vector2, target_rot: float, target_scale: Vector2) -> void:
	if not is_instance_valid(view): return
	view.target_position = target_pos
	view.target_rotation = target_rot
	view.target_scale = target_scale
	view.motion_active = true
	# 命中框防抖：目标离得太远就先禁用它，飞到位附近再打开，避免"牌还在飞就被点到"。
	if view.position.distance_to(target_pos) > HITBOX_REENABLE_DISTANCE:
		view.hitbox_ready = false
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _drive_motion(delta: float) -> void:
	for view in card_views:
		if not is_instance_valid(view): continue
		if view.shake_time > 0.0:
			view.shake_time = maxf(0.0, view.shake_time - delta)
			view.position.x += sin(view.shake_time * 72.0) * view.shake_amp * (view.shake_time / 0.22)
		if not view.motion_active: continue
		view.rotation = _approach(view.rotation, view.target_rotation, MOTION_ROTATE_SPEED, MOTION_ROTATE_SNAP, delta)
		view.scale = _approach_vec(view.scale, view.target_scale, MOTION_SCALE_SPEED, MOTION_SCALE_SNAP, delta)
		view.position = _approach_vec(view.position, view.target_position, MOTION_MOVE_SPEED, MOTION_MOVE_SNAP, delta)
		if not view.hitbox_ready and view.position.distance_to(view.target_position) < HITBOX_REENABLE_DISTANCE:
			view.hitbox_ready = true
			view.mouse_filter = Control.MOUSE_FILTER_STOP
		if view.position.is_equal_approx(view.target_position) and is_equal_approx(view.rotation, view.target_rotation) and view.scale.is_equal_approx(view.target_scale):
			view.motion_active = false


func _approach(current: float, target: float, speed: float, snap: float, delta: float) -> float:
	var next := lerpf(current, target, delta * speed)
	if absf(next - target) < snap: return target
	return next


func _approach_vec(current: Vector2, target: Vector2, speed: float, snap: float, delta: float) -> Vector2:
	var next := current.lerp(target, delta * speed)
	if next.distance_to(target) < snap: return target
	return next

func _find_card(instance: CardInstance) -> Control:
	for view in card_views:
		if is_instance_valid(view) and view.instance == instance: return view
	# 排队中 / 正在飞行的牌已经离开 card_views，但要能在飞行动画层里找回来
	if flight_layer != null:
		for child in flight_layer.get_children():
			if child is Control and child.get("instance") == instance:
				return child
	return null

## 入队出牌：立即把牌移出视作"已离开手牌"的手牌列表并停到队列位，
## 手牌马上重排 —— 玩家可以在前一张牌还在播动画时继续出牌。
func _enqueue_play(view: Control, instance: CardInstance, target: int) -> void:
	if combat.is_over():
		return
	if not _queued_instances.has(instance):
		_queued_instances.append(instance)
	if is_instance_valid(view):
		card_views.erase(view)
		view.reparent(flight_layer)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.motion_active = false
		_park_in_queue(view, _play_queue.size())
	_layout_hand()
	if _hint_label != null: _hint_label.text = "已排入队列（%d）" % (_play_queue.size() + 1)
	_play_queue.append({"view": view, "instance": instance, "target": target})
	if not _resolving:
		_run_play_queue()


## 队列位停放：位置/缩放公式取自尖塔2 NCardPlayQueue，非阻塞（不 await）。
func _park_in_queue(view: Control, index: int) -> void:
	if not is_instance_valid(view):
		return
	var n := float(index + 1)
	var slot: Vector2 = QUEUE_ANCHOR + Vector2.LEFT * 300.0 * (n / (n + 2.0))
	var slot_scale: float = float(view.base_scale) * (1.0 - n / (n + 1.0))
	if not juice.enabled("card_animations"):
		view.global_position = slot - view.size * 0.5
		view.scale = Vector2.ONE * slot_scale
		view.rotation = 0.0
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(view, "global_position", slot - view.size * 0.5, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(view, "scale", Vector2.ONE * slot_scale, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(view, "rotation", 0.0, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## 顺序执行队列：轮到某张牌时重新判定，不满足条件的放回手牌。
func _run_play_queue() -> void:
	_resolving = true
	while not _play_queue.is_empty():
		var item: Dictionary = _play_queue.pop_front()
		var instance: CardInstance = item.instance
		var view: Control = item.view
		_queued_instances.erase(instance)
		if combat.is_over():
			_return_queued_card(item, "战斗已结束")
			continue
		if not combat.can_play(instance):
			_return_queued_card(item, _queued_deny_reason(instance))
			continue
		await _play_card_on(instance, int(item.target), view)
	_resolving = false
	_end_turn_button.disabled = combat.is_over()


func _queued_deny_reason(instance: CardInstance) -> String:
	if instance == null:
		return "无法打出"
	if instance.effective_cost(combat.isolation) > combat.energy:
		return "能量不足"
	return "条件不满足"


## 把排队的牌放回手牌：视图交还手牌层并重新参与排布，然后给一次"打不出"的反馈。
func _return_queued_card(item: Dictionary, reason: String) -> void:
	var view: Control = item.view
	var instance: CardInstance = item.instance
	if is_instance_valid(view):
		view.reparent(hand_box)
		view.mouse_filter = Control.MOUSE_FILTER_STOP
		view.motion_active = false
		view.shake_time = 0.0
		if not card_views.has(view):
			card_views.append(view)
	_sync_hand(combat.hand)
	if is_instance_valid(view):
		_deny_card(view, reason)
	if _hint_label != null and instance != null:
		_hint_label.text = "「%s」%s · 已放回手牌" % [instance.display_name(), reason]
	juice.play_sound("deny")


func _play_card_on(instance: CardInstance, target: int, view_override: Control = null) -> void:
	if _busy or combat.is_over() or not combat.can_play(instance): return
	_busy = true
	_end_turn_button.disabled = true
	var view: Control = view_override if is_instance_valid(view_override) else _find_card(instance)
	var faction := instance.faction()
	var name := instance.display_name()
	var epoch := _epoch
	_cancel_selection()
	# 校准射击暂时不播放角色动作；其他规程攻击保留原有时序。
	if instance.data.type == CardData.Type.ATTACK and instance.faction() == CardData.Faction.PROTOCOL and instance.data.id not in ["calibrate_shot", "calibrate_shot_plus"] and hero != null and hero.has_method("attack_motion"):
		await hero.attack_motion(juice.enabled("enemy_animations"))
		if epoch != _epoch:
			return
	if is_instance_valid(view): await _stage_card_in_queue(view)
	if epoch != _epoch: return
	if is_instance_valid(view):
		if _card_has_direct_damage(instance):
			await _fly_card(view, target)
		else:
			await _dissolve_card(view)
	if epoch != _epoch: return
	_last_faction = faction
	_events.clear()
	_recording = true
	var success := combat.play_card(instance, target)
	_recording = false
	if success:
		var recipient: String = str(combat.enemies[target].name) if target >= 0 and target < combat.enemies.size() else "自身"
		_log("[color=#%s]打出「%s」[/color] → %s" % [("c7479e" if faction == 1 else "6bc7ff"), name, recipient])
		if instance.data.exhaust:
			var ash_at: Vector2 = _enemy_points[target] if target >= 0 and target < _enemy_points.size() else _hero_point
			juice.exhaust_ash(ash_at + Vector2(0, -40))
		await _replay_events(epoch)
	else:
		juice.play_sound("deny")
	if epoch != _epoch: return
	_apply_snapshot(_take_snapshot())
	_sync_hand(combat.hand)
	await _animate_pending_draws()
	_busy = false
	_end_turn_button.disabled = combat.is_over()

func _card_has_direct_damage(instance: CardInstance) -> bool:
	for effect in instance.data.effects:
		if effect.get("action", "") in ["damage", "damage_multi", "damage_if_echo"]:
			return true
	return false


## 辅助牌在中央被蓝色能量自下而上抹去，不飞向敌人。
func _dissolve_card(view: Control) -> void:
	if not juice.enabled("card_animations"):
		view.hide()
		return
	if view.motion != null and view.motion.is_running(): view.motion.kill()
	view.reparent(flight_layer, true)
	view.mouse_filter = MOUSE_FILTER_IGNORE
	view.z_index = 120
	var original_size: Vector2 = view.size
	var target_position := Vector2(960, 648) - original_size * 0.5
	var lift := create_tween().set_parallel(true)
	lift.tween_property(view, "global_position", target_position, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lift.tween_property(view, "scale", Vector2.ONE * 0.80, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lift.tween_property(view, "rotation", 0.0, 0.16)
	await lift.finished
	if not is_instance_valid(view): return
	view.clip_contents = true
	var burn_state := {"last_burst": -1.0}
	juice.play_sound("whoosh", 1.15)
	var burn := create_tween()
	burn.tween_method(func(t: float):
		if not is_instance_valid(view): return
		view.size.y = original_size.y * (1.0 - t)
		view.modulate.a = 1.0 - 0.32 * t
		if t - float(burn_state.last_burst) >= 0.12:
			burn_state.last_burst = t
			var edge := view.global_position + Vector2(original_size.x * 0.5, view.size.y) * view.scale
			juice.blue_dissolve_edge(edge)
	, 0.0, 1.0, 0.40).set_trans(Tween.TRANS_LINEAR)
	await burn.finished
	if is_instance_valid(view):
		view.hide()
		view.size = original_size
		view.clip_contents = false

func _fly_card(view: Control, target: int) -> void:
	if not juice.enabled("card_animations"):
		view.hide()
		return
	if view.motion != null and view.motion.is_running(): view.motion.kill()
	var start: Vector2 = view.get_global_transform() * (view.size * 0.5)
	var finish: Vector2 = _enemy_points[target] if target >= 0 and target < _enemy_points.size() else _hero_point
	view.reparent(flight_layer, true)
	view.mouse_filter = MOUSE_FILTER_IGNORE
	view.z_index = 120
	var mid: Vector2 = (start + finish) * 0.5 + Vector2(0, -120)
	var start_scale := view.scale.x
	# 拖尾状态用字典存，lambda 才能就地改（GDScript 局部变量按值捕获）。
	var trail := {
		"last": -1.0,
		"accent": CardWidget.COLORS[view.instance.faction()] if view.instance != null else CYAN,
	}
	juice.play_sound("whoosh")
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw.tween_method(func(t: float):
		var point := start.lerp(mid, t).lerp(mid.lerp(finish, t), t)
		view.global_position = point - view.size * 0.5
		view.rotation = lerpf(0.0, PI, t)
		view.scale = Vector2.ONE * lerpf(start_scale, 0.22, t)
		# 每 ~11% 航程留一步拖尾，密度对齐原版 card_trail 的连续残影
		if trail["last"] < 0.0 or t - float(trail["last"]) >= 0.11:
			trail["last"] = t
			juice.card_trail(point, trail["accent"], maxf(0.25, start_scale * 1.1))
		view.modulate.a = 1.0 if t < 0.6 else lerpf(1.0, 0.0, (t - 0.6) / 0.4), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	if is_instance_valid(view): view.hide()

func _replay_events(epoch: int) -> void:
	var events := _events.duplicate(true)
	_events.clear()
	for event in events:
		if epoch != _epoch: return
		match event.kind:
			"damage": await _present_damage(event)
			"echo":
				_apply_snapshot(event.snapshot)
				juice.echo(event.streak, _hero_point)
			"threshold":
				_apply_snapshot(event.snapshot)
				juice.corruption(event.value)
				if event.value >= 8: _shake_corrupted_hand()
				_log("[color=#c7479e]【隔离 %d】%s[/color]" % [event.value, event.stage])
			"turn":
				_apply_snapshot(event.snapshot)
				juice.turn_banner("你的回合" if event.player else "敌人回合", event.player)
				_log("[color=#8592a0]── %s · 第 %d 回合 ──[/color]" % ["你的回合" if event.player else "敌人回合", event.turn + 1])
			"hand": _sync_hand(event.snapshot.hand)
			"log": _log("[color=#c7479e]%s[/color]" % event.text)
			"result":
				_apply_snapshot(event.snapshot)
				_show_result(event.victory)
			_: _apply_snapshot(event.snapshot)

func _present_damage(event: Dictionary) -> void:
	var target_is_player: bool = event.target == "你"
	var index := -1
	if target_is_player:
		for i in event.snapshot.enemies.size():
			if event.snapshot.enemies[i].name == event.source: index = i
		if index >= 0: await _enemy_attack_motion(index)
	else:
		for i in event.snapshot.enemies.size():
			if event.snapshot.enemies[i].name == event.target: index = i
	var amount: int = event.amount
	var blocked: int = event.blocked
	var large: bool = amount >= 12 or int(event.snapshot.streak) >= 4 or (index >= 0 and not event.snapshot.enemies[index].alive)
	if target_is_player:
		if amount > 0:
			hero.hit(large, juice.enabled("reduce_flashes"), juice.enabled("enemy_animations"))
			juice.impact(_hero_point, large, 1)
			juice.vignette(RED, 0.85 if large else 0.55)
			juice.number(_hero_point + Vector2(0, -125), "-%d" % amount, RED, large)
			juice.play_sound("player_hit")
		else:
			juice.shield(_hero_point)
			juice.block_spark(_hero_point)
			juice.number(_hero_point + Vector2(25, -105), "格挡 %d" % blocked, CYAN)
		_log("%s → 你：[color=#eb6161]%d[/color]%s" % [event.source, amount, "（格挡 %d）" % blocked if blocked > 0 else ""])
	else:
		if index < 0: return
		enemy_rows[index].actor.hit(large, juice.enabled("reduce_flashes"), juice.enabled("enemy_animations"))
		juice.impact(_enemy_points[index], large, _last_faction)
		juice.hit_spark(_enemy_points[index], MAGENTA if _last_faction == 1 else CYAN)
		var multiplier: float = event.snapshot.multiplier
		var suffix := "  ×%.2f" % multiplier if multiplier > 1.0 else ""
		juice.number(_enemy_points[index] + Vector2(0, -145), ("%d" % amount) + suffix, GOLD if large else (GREEN if multiplier > 1.0 else TEXT), large)
		juice.play_sound("impact_large" if large else "impact")
		_log("你 → %s：[color=#ffdc82]%d[/color]%s" % [event.target, amount, "（格挡 %d）" % blocked if blocked > 0 else ""])
	_apply_snapshot(event.snapshot)
	await get_tree().create_timer(0.11 if large else 0.07, true, false, true).timeout

func _enemy_attack_motion(index: int) -> void:
	if not juice.enabled("enemy_animations"):
		return
	var actor = enemy_rows[index].actor
	if actor.has_method("attack_motion"):
		actor.attack_motion(true)
		await get_tree().create_timer(0.31).timeout
		juice.play_sound("enemy_whoosh")
		return
	var origin: Vector2 = actor.position
	var prep := create_tween()
	prep.tween_property(actor, "position", origin + Vector2(20, 0), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await prep.finished
	juice.play_sound("enemy_whoosh")
	var strike := create_tween()
	strike.tween_property(actor, "position", origin + Vector2(-60, 0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await strike.finished
	var recover := create_tween()
	recover.tween_property(actor, "position", origin, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _shake_corrupted_hand() -> void:
	if not juice.enabled("card_animations") or juice.enabled("reduce_motion"): return
	for view in card_views:
		if not is_instance_valid(view): continue
		var tw := create_tween()
		for step in 6:
			tw.tween_property(view, "rotation", view.home_rotation + deg_to_rad(3.0 if step % 2 == 0 else -3.0), 0.045)
		tw.tween_property(view, "rotation", view.home_rotation, 0.08)

func _on_end_turn_pressed() -> void:
	if _busy or combat == null: return
	if combat.is_over(): restart(); return
	if combat.has_hand_overflow():
		_pending_end_turn = true
		_show_overflow_picker()
		return
	_busy = true
	_cancel_selection()
	_end_turn_button.disabled = true
	# 回合清理规则由角色配置执行；沈明保留手牌，宋梅弃置手牌。
	var epoch := _epoch
	_events.clear()
	_recording = true
	combat.end_turn()
	_recording = false
	await _replay_events(epoch)
	if epoch != _epoch: return
	_apply_snapshot(_take_snapshot())
	_sync_hand(combat.hand)
	await _animate_pending_draws()
	_busy = false
	_end_turn_button.disabled = combat.is_over()
	_refresh_discard_zone()

func _log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > 12: _log_lines.remove_at(0)
	_log_label.text = "\n".join(_log_lines)
	_log_label.scroll_to_line(maxi(0, _log_lines.size() - 1))

func _show_result(victory: bool) -> void:
	if _run_battle:
		juice.play_sound("victory" if victory else "defeat")
		_emit_run_result_later(victory, _epoch)
		return
	_result_overlay.show()
	if combat.phase == CombatManager.Phase.ASSIMILATED:
		_result_label.text = "同  化"
		_result_label.add_theme_color_override("font_color", MAGENTA)
		_result_body.text = "你不再是你自己了。\n它们用你的手打开了舱门。"
	elif victory:
		_result_label.text = "清  除"
		_result_label.add_theme_color_override("font_color", GREEN)
		_result_body.text = "威胁已清除。\n最高回声 %d  ·  最终隔离 %d / 10" % [combat.echo.max_streak_this_combat, combat.isolation.value]
	else:
		_result_label.text = "失  败"
		_result_label.add_theme_color_override("font_color", RED)
		_result_body.text = "生命归零。\n最终隔离 %d / 10" % combat.isolation.value
	juice.play_sound("victory" if victory else "defeat")

func _emit_run_result_later(victory: bool, epoch: int) -> void:
	await get_tree().create_timer(0.4).timeout
	if epoch == _epoch:
		battle_finished.emit(victory)

## QA-only deterministic showcase. It exercises presentation layers without mutating rules.
func qa_showcase(level: int = 1) -> void:
	if level >= 1:
		juice.impact(_enemy_points[0], false, 0)
		enemy_rows[0].actor.hit(false, false, true)
		juice.number(_enemy_points[0] + Vector2(0, -145), "12  ×1.50", GREEN)
	if level >= 2: juice.echo(5, _hero_point)
	if level >= 3: juice.corruption(8)

func qa_drag_play(index: int = 0, target: int = 0) -> void:
	if _busy or index < 0 or index >= card_views.size(): return
	_on_card_pressed(card_views[index])
	_hover_enemy = target
	_finish_drag()

func qa_end_turn() -> void:
	_on_end_turn_pressed()
