extends Control
## 手牌托槽（矩形）：缠藤金蓝边框 + 半透明蓝内衬，卡牌放在里面。
##
## 版式：宽度 = max(贴合手牌所需, 最小宽度)，再由战斗视图夹在托槽可用范围内 ——
## 牌少时保持"中间占三分之二"的最小观感，牌多放不下才继续撑开；整体始终居中。
##
## 边框有两种画法：
##   ① 贴图模式（有素材时）：四角用四角素材的四个象限，四边用边条素材平铺；
##   ② 程序化回退（无素材时）：金轨 + 蓝带 + 等距金环的连环镶嵌。
##
## 素材请用 tools/key_white_tray.gd 处理过的 *_cut.png（AI 出的图多为白底不透明，
## 直接画会是一片白块）。全部参数可在编辑器直接改（scenes/ui/hand_tray.tscn）。

const EDGE_WIDTH := 2.0
const BAND_HALF := 12.0          ## 程序化边框半宽
const RING_STEP := 3
const PAD_INNER := 12.0          ## 内衬相对边框内沿再收进多少（越小越贴近卡牌）
const FRAME_MARGIN := 6.0        ## 边框距控件边缘

const GOLD_BRIGHT := Color("ffe9a8")
const GOLD_MAIN := Color("d4a53a")
const GOLD_DEEP := Color("7a5a16")

@export var interior_color := Color(0.157, 0.443, 0.839, 0.30)   ## 半透明蓝内衬
@export var interior_deep := Color(0.078, 0.235, 0.549, 0.34)    ## 下层深蓝
@export var band_color := Color(0.106, 0.298, 0.639, 0.42)       ## 程序化边框内的蓝带
@export var inlay_blue := Color("3f9bf0")
@export var inlay_deep := Color("123c78")
@export var edge_color := Color("2a7fb8")

## ── 贴图模式 ──────────────────────────────────────────────
@export var edge_texture: Texture2D             ## 横边条（上、下两用）
@export var edge_v_texture: Texture2D          ## 竖边条（左、右两用；没有时用横条旋转 90° 代替）
@export var corners_texture: Texture2D          ## 四角（四象限，运行时自动切分）
@export var asset_scale := 0.78                 ## 贴图绘制缩放
@export var edge_band_center_ratio := 0.47      ## 编织带中心在贴图高度中的位置
@export var edge_overlap := 0.62                ## 相邻边条间距 = 贴图屏宽 × 该值（越小越密）
@export var corner_scale_mult := 1.0            ## 角件尺寸微调
@export var corner_gap := 14.0                  ## 四边与四角之间的缝隙（同卡牌：四角独立露出）

var frame_width := 1280.0
var min_width := 1280.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 像素风：素材必须最近邻过滤，否则降采样后的像素格会被插值糊掉
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 关键：角件素材自带外观装饰会向外铺开，裁掉控件矩形外的部分，
	# 保证托槽只占自己那一块、不会往上延伸盖住战场。
	clip_contents = true
	queue_redraw()


## 由战斗视图在手牌重排后调用：这排手牌有多宽、扇形有多深、最小要占多宽。
## 矩形版不用 rise（保留形参以兼容调用方）。
func set_fan(width: float, rise: float, floor_width: float = -1.0, animate: bool = true) -> void:
	if floor_width > 0.0:
		min_width = floor_width
	var target: float = maxf(width + PAD_INNER * 2.0, min_width)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animate or not is_inside_tree():
		frame_width = target
		queue_redraw()
		return
	var from_width := frame_width
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void:
		frame_width = lerpf(from_width, target, t)
		queue_redraw(), 0.0, 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _frame_rect() -> Rect2:
	var width := clampf(frame_width, 200.0, size.x - FRAME_MARGIN * 2.0)
	var height := size.y - FRAME_MARGIN * 2.0
	return Rect2(Vector2(size.x * 0.5 - width * 0.5, FRAME_MARGIN), Vector2(width, height))


func _straight_spine(a: Vector2, b: Vector2, spacing: float) -> PackedVector2Array:
	var count := maxi(2, int(ceil(a.distance_to(b) / maxf(spacing, 1.0))))
	var out := PackedVector2Array()
	for i in count + 1:
		out.append(a.lerp(b, float(i) / float(count)))
	return out


func _offset_normal(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	for i in n:
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, n - 1)]
		var tangent := b - a
		var normal := Vector2(tangent.y, -tangent.x).normalized() if tangent.length_squared() > 0.0001 else Vector2.UP
		out.append(points[i] + normal * distance)
	return out


## 边条沿直线平铺（上下用横条，左右会因切线方向自动旋转 90°）
func _place_edge_along(points: PackedVector2Array) -> void:
	if edge_texture == null or points.size() < 2:
		return
	var width_px: float = float(edge_texture.get_width())
	var height_px: float = float(edge_texture.get_height())
	var step: float = maxf(width_px * asset_scale * edge_overlap, 8.0)
	var spacing: float = points[0].distance_to(points[1])
	var stride: int = maxi(1, int(round(step / maxf(spacing, 0.001))))
	for i in range(0, points.size(), stride):
		var point: Vector2 = points[i]
		var before: Vector2 = points[maxi(i - 1, 0)]
		var after: Vector2 = points[mini(i + 1, points.size() - 1)]
		draw_set_transform(point, (after - before).angle(), Vector2.ONE * asset_scale)
		draw_texture(edge_texture, Vector2(-width_px * 0.5, -height_px * edge_band_center_ratio))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 竖边条沿竖直折线平铺：**不旋转**，直接把"带中心"对到折线上。
## 用专用竖条可以避免横条旋转 90° 后接缝错位、看起来像拼接。
func _place_edge_vertical(points: PackedVector2Array) -> void:
	if edge_v_texture == null or points.size() < 2:
		return
	var width_px: float = float(edge_v_texture.get_width())
	var height_px: float = float(edge_v_texture.get_height())
	var step: float = maxf(height_px * asset_scale * edge_overlap, 8.0)
	var spacing: float = points[0].distance_to(points[1])
	var stride: int = maxi(1, int(round(step / maxf(spacing, 0.001))))
	for i in range(0, points.size(), stride):
		var point: Vector2 = points[i]
		draw_set_transform(point, 0.0, Vector2.ONE * asset_scale)
		draw_texture(edge_v_texture, Vector2(-width_px * edge_band_center_ratio, -height_px * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 四角：把四角素材按象限切开，各自的"内角"对齐到矩形对应的角
func _draw_quadrant(region: Rect2, anchor_world: Vector2, anchor_in_region: Vector2, scale: float) -> void:
	var dest := Rect2(anchor_world - anchor_in_region * scale, region.size * scale)
	draw_texture_rect_region(corners_texture, dest, region)


func _draw_textured_frame(frame: Rect2) -> void:
	# 四边与四角之间留缝：四角独立露出，不连成一整圈
	var corner_span := 0.0
	if corners_texture != null:
		corner_span = minf(float(corners_texture.get_width()), float(corners_texture.get_height())) \
			* 0.5 * asset_scale * corner_scale_mult
	var inset := corner_span + corner_gap
	var x0 := frame.position.x + inset
	var x1 := frame.end.x - inset
	var y0 := frame.position.y + inset
	var y1 := frame.end.y - inset
	_place_edge_along(_straight_spine(Vector2(x0, frame.position.y), Vector2(x1, frame.position.y), 32.0))
	_place_edge_along(_straight_spine(Vector2(x0, frame.end.y), Vector2(x1, frame.end.y), 32.0))
	var left := _straight_spine(Vector2(frame.position.x, y0), Vector2(frame.position.x, y1), 32.0)
	var right := _straight_spine(Vector2(frame.end.x, y0), Vector2(frame.end.x, y1), 32.0)
	if edge_v_texture != null:
		_place_edge_vertical(left)
		_place_edge_vertical(right)
	else:
		_place_edge_along(left)
		_place_edge_along(right)
	# 四角
	if corners_texture == null:
		return
	var half_w: float = float(corners_texture.get_width()) * 0.5
	var half_h: float = float(corners_texture.get_height()) * 0.5
	var scale: float = asset_scale * corner_scale_mult
	_draw_quadrant(Rect2(0.0, 0.0, half_w, half_h), frame.position, Vector2(half_w, half_h), scale)
	_draw_quadrant(Rect2(half_w, 0.0, half_w, half_h), Vector2(frame.end.x, frame.position.y), Vector2(0.0, half_h), scale)
	_draw_quadrant(Rect2(0.0, half_h, half_w, half_h), Vector2(frame.position.x, frame.end.y), Vector2(half_w, 0.0), scale)
	_draw_quadrant(Rect2(half_w, half_h, half_w, half_h), frame.end, Vector2(0.0, 0.0), scale)


## 程序化回退：金轨 + 蓝带 + 等距金环的连环镶嵌
func _draw_knot_band(spine: PackedVector2Array, half_width: float) -> void:
	var outer := _offset_normal(spine, half_width)
	var inner := _offset_normal(spine, -half_width)
	var band := PackedVector2Array(outer)
	for i in range(inner.size() - 1, -1, -1):
		band.append(inner[i])
	draw_colored_polygon(band, band_color)
	for rail in [outer, inner]:
		draw_polyline(rail, Color(GOLD_DEEP, 0.9), 3.2, true)
		draw_polyline(rail, Color(GOLD_MAIN, 0.98), 2.0, true)
		draw_polyline(_offset_normal(rail, 0.8), Color(GOLD_BRIGHT, 0.5), 0.9, true)
	var ring := 0
	for i in range(RING_STEP, spine.size() - RING_STEP, RING_STEP):
		var center: Vector2 = spine[i]
		var radius := half_width * 0.92
		var cross := Vector2(7.0, half_width * 0.62)
		if ring % 2 == 0:
			draw_line(center - cross, center + cross, Color(GOLD_DEEP, 0.75), 2.0, true)
		else:
			draw_line(center + Vector2(-cross.x, cross.y), center + Vector2(cross.x, -cross.y), Color(GOLD_DEEP, 0.75), 2.0, true)
		draw_circle(center, radius, Color(GOLD_MAIN, 1.0))
		draw_circle(center, radius * 0.74, Color(GOLD_DEEP, 0.95))
		draw_circle(center, radius * 0.64, inlay_deep)
		draw_circle(center, radius * 0.46, inlay_blue)
		draw_circle(center, radius * 0.20, Color(GOLD_BRIGHT, 0.92))
		ring += 1


func _draw_procedural_frame(frame: Rect2) -> void:
	_draw_knot_band(_straight_spine(Vector2(frame.position.x, frame.position.y), Vector2(frame.end.x, frame.position.y), 30.0), BAND_HALF)
	_draw_knot_band(_straight_spine(Vector2(frame.position.x, frame.end.y), Vector2(frame.end.x, frame.end.y), 30.0), BAND_HALF)
	_draw_knot_band(_straight_spine(Vector2(frame.position.x, frame.position.y), Vector2(frame.position.x, frame.end.y), 30.0), BAND_HALF)
	_draw_knot_band(_straight_spine(Vector2(frame.end.x, frame.position.y), Vector2(frame.end.x, frame.end.y), 30.0), BAND_HALF)


func _draw() -> void:
	var frame := _frame_rect()
	# ① 内衬：半透明蓝两层（卡牌放在上面）
	draw_rect(frame.grow(-PAD_INNER), interior_color, true)
	draw_rect(frame.grow(-PAD_INNER - 10.0), interior_deep, true)
	# ② 边框
	if edge_texture != null:
		_draw_textured_frame(frame)
	else:
		_draw_procedural_frame(frame)
	# ③ 内沿亮边：把卡牌"框"在里面
	var inner := frame.grow(-PAD_INNER)
	draw_rect(inner, Color(edge_color, 0.55), false, EDGE_WIDTH)
