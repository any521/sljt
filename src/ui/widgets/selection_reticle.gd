extends Control
## 目标准星：四角括号。
##
## 出现/消失曲线对齐《杀戮尖塔2》的 NSelectionReticle：
##   选中：alpha 0→1 用 0.2s；scale 0.9→1.0 用 0.5s，EXPO 缓出
##   取消：alpha→0 用 0.2s（SINE 出）；scale 推到 1.05，0.2s —— "涨一下再消失"

const BRACKET := 34.0
const THICK := 5.0

var accent := Color("ffdc82")
var selected := false
var _tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2.ONE * 0.9


func select() -> void:
	_kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO).from(Vector2.ONE * 0.9)
	modulate.a = 1.0
	scale = Vector2.ONE
	selected = true


func deselect() -> void:
	if not selected:
		return
	_kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "scale", Vector2.ONE * 1.05, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	selected = false


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _exit_tree() -> void:
	_kill()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# 外圈柔光：让准星在杂乱背景上也能被一眼看到
	draw_rect(Rect2(0.0, 0.0, w, h), Color(accent, 0.10), false, 2.0)
	# 四角内发光
	var glow := Color(accent, 0.16)
	for corner_rect in [Rect2(0.0, 0.0, BRACKET + 6.0, THICK + 6.0), Rect2(w - BRACKET - 6.0, 0.0, BRACKET + 6.0, THICK + 6.0), Rect2(0.0, h - THICK - 6.0, BRACKET + 6.0, THICK + 6.0), Rect2(w - BRACKET - 6.0, h - THICK - 6.0, BRACKET + 6.0, THICK + 6.0)]:
		draw_rect(corner_rect, glow)
	# 左上
	draw_rect(Rect2(0.0, 0.0, BRACKET, THICK), accent)
	draw_rect(Rect2(0.0, 0.0, THICK, BRACKET), accent)
	# 右上
	draw_rect(Rect2(w - BRACKET, 0.0, BRACKET, THICK), accent)
	draw_rect(Rect2(w - THICK, 0.0, THICK, BRACKET), accent)
	# 左下
	draw_rect(Rect2(0.0, h - THICK, BRACKET, THICK), accent)
	draw_rect(Rect2(0.0, h - BRACKET, THICK, BRACKET), accent)
	# 右下
	draw_rect(Rect2(w - BRACKET, h - THICK, BRACKET, THICK), accent)
	draw_rect(Rect2(w - THICK, h - BRACKET, THICK, BRACKET), accent)
