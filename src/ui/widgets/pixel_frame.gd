@tool
extends TextureRect
## 4px 屏幕像素网格 UI。所有线条、切角和图标都落在 BLOCK 的整数倍上。

const BLOCK := 4.0

@export_enum("panel", "echo", "isolation", "tray", "card", "end_turn", "intent_attack", "intent_debuff", "intent_shield", "intent_unknown") var variant := "panel":
	set(value):
		variant = value
		queue_redraw()
@export var accent := Color("55c8ff"):
	set(value):
		accent = value
		queue_redraw()
@export var fill := Color(0.025, 0.045, 0.07, 0.94):
	set(value):
		fill = value
		queue_redraw()
@export var dim_accent := Color("245678"):
	set(value):
		dim_accent = value
		queue_redraw()


func set_variant(value: String) -> void:
	variant = value
	match variant:
		"isolation", "intent_debuff": accent = Color("d84aa8")
		"end_turn": accent = Color("ffd15c")
		"intent_attack": accent = Color("ff6570")
		"intent_shield": accent = Color("6fc8ff")
		_: accent = Color("55c8ff")
	queue_redraw()


func _ready() -> void:
	texture = null
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var w := floorf(size.x / BLOCK) * BLOCK
	var h := floorf(size.y / BLOCK) * BLOCK
	if w < 24.0 or h < 24.0:
		return
	var cut := 12.0 if minf(w, h) >= 52.0 else 8.0
	var outer := _octagon(Rect2(0, 0, w, h), cut)
	draw_colored_polygon(outer, Color(0.005, 0.01, 0.02, 0.94))
	var border := _octagon(Rect2(BLOCK, BLOCK, w - BLOCK * 2.0, h - BLOCK * 2.0), maxf(BLOCK, cut - BLOCK))
	draw_colored_polygon(border, accent)
	var inner := _octagon(Rect2(BLOCK * 2.0, BLOCK * 2.0, w - BLOCK * 4.0, h - BLOCK * 4.0), maxf(BLOCK, cut - BLOCK * 2.0))
	draw_colored_polygon(inner, fill)
	draw_rect(Rect2(cut + BLOCK * 2.0, BLOCK * 2.0, maxf(BLOCK, w * 0.34), BLOCK), accent)
	draw_rect(Rect2(w - cut - BLOCK * 4.0, h - BLOCK * 3.0, BLOCK * 2.0, BLOCK), dim_accent)
	match variant:
		"echo": _draw_echo(w, h)
		"isolation": _draw_isolation(w, h)
		"tray": _draw_tray(w, h)
		"card": _draw_card(w, h)
		"end_turn": _draw_end_turn(w, h)
		"intent_attack", "intent_debuff", "intent_shield", "intent_unknown": _draw_intent(w, h)


func _octagon(rect: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(rect.position.x + cut, rect.position.y),
		Vector2(rect.end.x - cut, rect.position.y),
		Vector2(rect.end.x, rect.position.y + cut),
		Vector2(rect.end.x, rect.end.y - cut),
		Vector2(rect.end.x - cut, rect.end.y),
		Vector2(rect.position.x + cut, rect.end.y),
		Vector2(rect.position.x, rect.end.y - cut),
		Vector2(rect.position.x, rect.position.y + cut),
	])


func _pixel(x: float, y: float, color: Color = accent, width: float = BLOCK, height: float = BLOCK) -> void:
	draw_rect(Rect2(roundf(x / BLOCK) * BLOCK, roundf(y / BLOCK) * BLOCK, width, height), color)


func _draw_echo(_w: float, h: float) -> void:
	var cy := floorf(h * 0.5 / BLOCK) * BLOCK
	for p in [Vector2(24, cy), Vector2(28, cy - 4), Vector2(32, cy - 8), Vector2(36, cy), Vector2(40, cy + 4), Vector2(44, cy), Vector2(48, cy - 4)]:
		_pixel(p.x, p.y)


func _draw_isolation(w: float, h: float) -> void:
	draw_rect(Rect2(16, h - 16, w - 32, 4), Color("5d164f"))
	for x in range(20, int(w - 20), 32):
		_pixel(float(x), h - 20, accent)


func _draw_tray(w: float, h: float) -> void:
	draw_rect(Rect2(24, 20, w - 48, 4), dim_accent)
	draw_rect(Rect2(24, h - 24, w - 48, 4), dim_accent)
	for x in range(40, int(w - 40), 80):
		_pixel(float(x), h - 16, Color(accent, 0.55), 32, 4)


func _draw_card(w: float, h: float) -> void:
	draw_rect(Rect2(20, 40, w - 40, 4), dim_accent)
	draw_rect(Rect2(20, 176, w - 40, 4), accent)
	draw_rect(Rect2(20, 184, w - 40, 4), dim_accent)
	draw_rect(Rect2(20, h - 28, w - 40, 4), dim_accent)
	_pixel(8, 8, Color("ffd15c"), 32, 4)


func _draw_end_turn(w: float, h: float) -> void:
	draw_rect(Rect2(20, h - 20, w - 40, 4), Color(accent, 0.6))
	for i in 4:
		_pixel(w - 44 + i * 4, h * 0.5 - 8 + i * 4, accent)
		_pixel(w - 44 + i * 4, h * 0.5 + 8 - i * 4, accent)


func _draw_intent(w: float, h: float) -> void:
	var cx := floorf(w * 0.5 / BLOCK) * BLOCK
	var cy := floorf(h * 0.5 / BLOCK) * BLOCK
	match variant:
		"intent_attack":
			for i in 5:
				_pixel(cx - 12 + i * 4, cy + 8 - i * 4)
			_pixel(cx + 8, cy - 12, accent, 8, 4)
			_pixel(cx - 16, cy + 12, accent, 12, 4)
		"intent_shield":
			draw_rect(Rect2(cx - 12, cy - 12, 24, 4), accent)
			draw_rect(Rect2(cx - 12, cy - 8, 4, 16), accent)
			draw_rect(Rect2(cx + 8, cy - 8, 4, 16), accent)
			draw_rect(Rect2(cx - 8, cy + 8, 16, 4), accent)
			_pixel(cx - 4, cy + 12)
		"intent_debuff":
			_pixel(cx - 4, cy - 12, accent, 8, 8)
			_pixel(cx - 8, cy - 4, accent, 16, 12)
			_pixel(cx - 4, cy + 8, accent, 8, 8)
		_:
			_pixel(cx - 4, cy - 12, accent, 12, 4)
			_pixel(cx + 4, cy - 8, accent, 4, 8)
			_pixel(cx, cy, accent, 4, 8)
			_pixel(cx, cy + 12)
