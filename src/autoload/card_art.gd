extends Node
## CardArt —— 卡面美术资源管理器（autoload 单例）
##
## 数据来源：Aseprite 脚本生成的精灵表
##   tools/gen_card_art.lua  →  assets/art/cards/cards_art.png (8x3, 每格 32x32)
##   assets/art/cards/cards_art.json 保存每张卡在表里的坐标
##
## 卡片 id → AtlasTexture；同时计算每张画的平均色，用于给卡框上色。
## 没有美术素材时优雅降级（返回 null），UI 用纯色块兜底。

const ATLAS_PATH := "res://assets/art/cards/cards_art.png"
const JSON_PATH := "res://assets/art/cards/cards_art.json"

var atlas: Texture2D = null
var cell_size: int = 32
var frames: Dictionary = {}          # card_id -> { x, y }
var _textures: Dictionary = {}       # card_id -> AtlasTexture
var _avg_colors: Dictionary = {}     # card_id -> Color
var loaded: bool = false


func _ready() -> void:
	_load()


func _load() -> void:
	if not ResourceLoader.exists(ATLAS_PATH):
		push_warning("[CardArt] 未找到卡面精灵表，使用纯色兜底：%s" % ATLAS_PATH)
		return
	atlas = load(ATLAS_PATH)
	if atlas == null:
		push_warning("[CardArt] 卡面精灵表加载失败")
		return

	if FileAccess.file_exists(JSON_PATH):
		var f := FileAccess.open(JSON_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			cell_size = int(parsed.get("cell", 32))
			var fr: Dictionary = parsed.get("frames", {})
			for key in fr:
				frames[key] = fr[key]
	else:
		push_warning("[CardArt] 未找到索引 JSON，回退为按顺序切图")

	loaded = true
	print("[CardArt] 已加载卡面精灵表：%d 张" % frames.size())


## 取某张卡的卡面纹理（无素材时返回 null）
func get_card_texture(card_id: String) -> Texture2D:
	if not loaded:
		return null

	# 升级版卡面缺失 → 回退到基础卡
	if not frames.has(card_id) and card_id.ends_with("_plus"):
		var base := card_id.trim_suffix("_plus")
		if frames.has(base):
			return get_card_texture(base)
	# 反向：基础卡缺失 → 尝试升级版（两者共用同一套图形）
	if not frames.has(card_id) and frames.has(card_id + "_plus"):
		return get_card_texture(card_id + "_plus")

	if not frames.has(card_id):
		return null

	if _textures.has(card_id):
		return _textures[card_id]

	var fr: Dictionary = frames[card_id]
	var at := AtlasTexture.new()
	at.atlas = atlas
	at.region = Rect2(float(fr["x"]), float(fr["y"]), float(cell_size), float(cell_size))
	at.filter_clip = true
	_textures[card_id] = at
	return at


## 取某张卡面的平均色（用于卡框/边框配色）
func get_card_color(card_id: String) -> Color:
	if _avg_colors.has(card_id):
		return _avg_colors[card_id]

	var tex := get_card_texture(card_id)
	if tex == null:
		return Color(0.5, 0.5, 0.5)

	var img := tex.get_image()
	if img == null:
		return Color(0.5, 0.5, 0.5)

	var total := Vector3.ZERO
	var count := 0
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			# 跳过几乎透明的像素，避免平均色被拉黑
			if c.a > 0.5:
				total += Vector3(c.r, c.g, c.b)
				count += 1

	var result := Color(0.5, 0.5, 0.5)
	if count > 0:
		result = Color(total.x / count, total.y / count, total.z / count)
	_avg_colors[card_id] = result
	return result
