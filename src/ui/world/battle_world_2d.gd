extends Control
## 2D 版战斗场景 —— 纯 2D 像素画背景 + 序列帧角色
##
## 实现与（已归档的）3D 版完全相同的接口契约：
##   build()
##   player_screen_point() / enemy_screen_point(i) / get_enemy_actor(i)
##   camera / player_actor / companion_actor / enemy_actors
##
## 三个关键设计（都是踩过坑换来的）：
##   1) camera = null → combat_view.gd 的 _sync_world_anchors() 提前返回，
##      改用 build() 时算好的静态锚点。2D 背景不需要每帧重投影。
##   2) 背景按视口尺寸显式铺满，不用 FULL_RECT 锚点。因为 combat_view.gd 在
##      _ready() 里执行 world.size = size，那一刻父容器还没跑布局，size 还是
##      (0,0)，锚点会把背景算成 0x0 —— 表现就是「背景整个不显示」。
##   3) 站位用「背景图像素坐标」书写，运行时按 COVER 规则换算成屏幕坐标。
##      换背景图、改分辨率都不用重算。
##
## 像素密度（决定「像素质感是否统一」）——
##   主角帧表原生 2px/格点，宋梅帧表也是 2px/格点，两者同源；
##   眷族静态图是 4px/格点，比人物粗一倍。
##   屏幕每格点像素 = px_scale * 原生格点，所以：
##     主角 3.0 -> 6.0    宋梅 4.0 -> 8.0    眷族 330/364*4 ≈ 3.6
##   想调某个角色的观感，只改下面 *_PX / *_HEIGHT 即可。

const Actor2D = preload("res://src/ui/world/battle_actor_2d.gd")

const BACKDROP := "res://assets/art/battle/biolab_backdrop.png"
const BACKDROP_SRC := Vector2(1670.0, 941.0)

## ── 序列帧表：128x128 一格，从左到右、从上到下 ──
## content 取「全部帧的并集包围盒」，用它对齐脚底、并让受击白闪只盖住人物本身
const HERO_SHEET := "res://assets/art/characters/shen_mingyan/battle_clean_512x256.png"
const HERO_SHEET_COLS := 4
const HERO_SHEET_ROWS := 2
const HERO_CONTENT := Rect2(48.0, 41.0, 32.0, 51.0)
const HERO_PX := 4.3

const ALLY_SHEET := "res://assets/art/characters/song_mei/battle_512x384.png"
const ALLY_SHEET_COLS := 4
const ALLY_SHEET_ROWS := 3
const ALLY_CONTENT := Rect2(45.0, 44.0, 29.0, 47.0)
const ALLY_PX := 4.65

const FRAME_CELL := Vector2(128.0, 128.0)
const FRAME_FPS := 8.0

## ── 眷族暂时只有静态单图（没有序列帧素材）──
const ENEMY_SPRITE := "res://assets/art/enemies/kin_attached_512.png"
const ENEMY_HEIGHT := 219.0

## ── 站位：直接写「背景图上的像素坐标」，y 为脚底 ──
## 宋梅站在主角身后：脚底更靠上 = 更远、更小，并被主角遮住一部分；
## 主角站在前面（更靠近敌人一侧）。两行 y 的差值就是前后进深。
## 数值取自 assets/art/reference/scene_layout_annotated.png 与干净背景的像素差分
const ALLY_FEET_SRC := Vector2(474.0, 566.0)     ## 后排，偏左
const HERO_FEET_SRC := Vector2(600.0, 606.0)     ## 前排，靠敌人
const ENEMY_FEET_SRC := [Vector2(1200.0, 572.0), Vector2(1320.0, 576.0)]

## ── UI 锚点相对脚底的抬升量（血条 / 意图 / 名字都挂在这个点上）──
const HERO_ANCHOR_LIFT := 168.0
const ENEMY_ANCHOR_LIFT := 182.0

var camera = null                 ## ★ 无 3D 相机 → combat_view 走静态锚点分支
var stage: Control
var backdrop: TextureRect
var player_actor: Node
var companion_actor: Node
var _shen_actor: Control
var _song_actor: Control
var _shen_home := Vector2.ZERO
var _song_home := Vector2.ZERO
var enemy_actors: Array = []
var _hero_point := Vector2.ZERO
var _enemy_points: Array[Vector2] = []
var _enemy_ui_points: Array[Vector2] = []
var _built := false


func build() -> void:
	if _built:
		return
	_built = true
	name = "BattleWorld2D"
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(1920, 1055)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_backdrop()

	stage = get_node_or_null("Gameplay/Actors") as Control
	if stage == null:
		stage = Control.new()
		stage.name = "Actors"
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stage)
	stage.size = size

	_build_actors()
	_compute_anchors()


func _build_backdrop() -> void:
	backdrop = get_node_or_null("Environment/Backdrop") as TextureRect
	if backdrop == null:
		backdrop = TextureRect.new()
		backdrop.name = "Backdrop"
		if ResourceLoader.exists(BACKDROP):
			backdrop.texture = load(BACKDROP)
		var environment := get_node_or_null("Environment")
		(environment if environment != null else self).add_child(backdrop)
	# 显式 TOP_LEFT + 手动给尺寸：父容器 size 为 0 时锚点方案会失效
	backdrop.set_anchors_preset(Control.PRESET_TOP_LEFT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_backdrop()


## 让背景始终铺满整个视口（窗口拉大也能跟上）
func _fit_backdrop() -> void:
	if backdrop == null or not is_instance_valid(backdrop):
		return
	backdrop.position = Vector2.ZERO
	backdrop.size = size


## 复算背景图的 COVER 变换：背景图像素坐标 → 屏幕坐标
## 与 backdrop 的 STRETCH_KEEP_ASPECT_COVERED 保持一致
func _src_to_screen(p: Vector2) -> Vector2:
	var vp := size
	if BACKDROP_SRC.x <= 0.0 or BACKDROP_SRC.y <= 0.0:
		return p
	var k := maxf(vp.x / BACKDROP_SRC.x, vp.y / BACKDROP_SRC.y)
	return p * k + (vp - BACKDROP_SRC * k) * 0.5


## 生成一个序列帧角色（人物内容底部对齐脚底坐标）
func _spawn_sheet(tex_path: String, cols: int, rows: int, content: Rect2, px: float, feet: Vector2, facing_left: bool) -> Node:
	var actor = Actor2D.new()
	actor.setup_sheet(tex_path, cols, rows, FRAME_CELL, content, px, FRAME_FPS, facing_left)
	return _place(actor, feet)


## 生成一个静态单图角色
func _spawn_sprite(tex_path: String, height: float, feet: Vector2, facing_left: bool) -> Node:
	var actor = Actor2D.new()
	actor.setup_sprite(tex_path, height, facing_left)
	return _place(actor, feet)


func _place(actor: Node, feet: Vector2) -> Node:
	var s: Vector2 = actor.size
	# 取整：像素画落在整数像素边界上才锐利
	actor.position = (feet - Vector2(s.x * 0.5, s.y)).round()
	stage.add_child(actor)
	actor.mark_base_position()
	return actor


func _build_actors() -> void:
	# 正式角色直接来自 battle_world_2d.tscn，可在编辑器中展开并修改 SpriteFrames。
	companion_actor = stage.get_node_or_null("SongMei")
	player_actor = stage.get_node_or_null("ShenMing")
	if companion_actor == null:
		companion_actor = _spawn_sheet(ALLY_SHEET, ALLY_SHEET_COLS, ALLY_SHEET_ROWS, ALLY_CONTENT, ALLY_PX, _src_to_screen(ALLY_FEET_SRC), false)
	if player_actor == null:
		player_actor = _spawn_sheet(HERO_SHEET, HERO_SHEET_COLS, HERO_SHEET_ROWS, HERO_CONTENT, HERO_PX, _src_to_screen(HERO_FEET_SRC), false)
	_shen_actor = player_actor as Control
	_song_actor = companion_actor as Control
	_shen_home = _shen_actor.position
	_song_home = _song_actor.position
	enemy_actors.clear()
	for i in ENEMY_FEET_SRC.size():
		var actor = stage.get_node_or_null("KinVariant%d" % (i + 1))
		if actor == null:
			actor = _spawn_sprite(ENEMY_SPRITE, ENEMY_HEIGHT, _src_to_screen(ENEMY_FEET_SRC[i]), true)
		enemy_actors.append(actor)
	for actor in [companion_actor, player_actor] + enemy_actors:
		if actor != null and actor.has_method("mark_base_position"):
			actor.mark_base_position()

func set_active_character(character_id: String) -> void:
	if _shen_actor == null or _song_actor == null: return
	var song_active := character_id == CharacterRules.SONG_MEI
	player_actor = _song_actor if song_active else _shen_actor
	companion_actor = _shen_actor if song_active else _song_actor
	var shen_feet := _shen_home + Vector2(_shen_actor.size.x * 0.5, _shen_actor.size.y)
	var song_feet := _song_home + Vector2(_song_actor.size.x * 0.5, _song_actor.size.y)
	if song_active:
		_song_actor.position = shen_feet - Vector2(_song_actor.size.x * 0.5, _song_actor.size.y)
		_shen_actor.position = song_feet - Vector2(_shen_actor.size.x * 0.5, _shen_actor.size.y)
	else:
		_shen_actor.position = _shen_home
		_song_actor.position = _song_home
	player_actor.z_index = 1
	companion_actor.z_index = 0
	for actor in [player_actor, companion_actor]: actor.mark_base_position()
	_compute_anchors()


func _actor_feet(actor: Control, fallback: Vector2) -> Vector2:
	if actor == null:
		return fallback
	return actor.position + Vector2(actor.size.x * 0.5, actor.size.y)


func _compute_anchors() -> void:
	_hero_point = player_actor.body_center() if player_actor != null and player_actor.has_method("body_center") else _actor_feet(player_actor, _src_to_screen(HERO_FEET_SRC)) - Vector2(0.0, HERO_ANCHOR_LIFT)
	_enemy_points = []
	_enemy_ui_points = []
	for i in ENEMY_FEET_SRC.size():
		var actor = enemy_actors[i]
		var feet := _actor_feet(actor, _src_to_screen(ENEMY_FEET_SRC[i]))
		_enemy_points.append(actor.body_center() if actor != null and actor.has_method("body_center") else feet - Vector2(0.0, ENEMY_ANCHOR_LIFT))
		_enemy_ui_points.append(actor.head_anchor() if actor != null and actor.has_method("head_anchor") else feet - Vector2(0.0, ENEMY_ANCHOR_LIFT * 2.0))


# ================================================================ 契约接口

func player_screen_point() -> Vector2:
	return _hero_point


func enemy_screen_point(index: int) -> Vector2:
	if index < 0 or index >= _enemy_points.size():
		return Vector2.ZERO
	return _enemy_points[index]


func enemy_ui_point(index: int) -> Vector2:
	if index < 0 or index >= _enemy_ui_points.size():
		return Vector2.ZERO
	return _enemy_ui_points[index]


func get_enemy_actor(index: int) -> Node:
	if index < 0 or index >= enemy_actors.size():
		return null
	return enemy_actors[index]


## 兼容 3D 版的签名（UI 里若有其他调用点不会崩）
func actor_screen_point(actor, height_offset: float = 0.0) -> Vector2:
	if actor == null or not is_instance_valid(actor):
		return Vector2.ZERO
	return actor.position + Vector2(0, -height_offset)
