extends Control
## 卡牌的金色镶嵌：四边金边条 + 四角金饰。
##
## 为什么必须是 battle_card.tscn 的**最后一个子节点**：
## Control 自身的 _draw() 永远渲染在自己的子节点下面，卡框是全尺寸贴图，
## 画在根节点上会被整片盖住（之前看不到金饰就是这个原因）。
##
## 四边用金边条沿卡边平铺（上/下用横条、左/右用竖条、不旋转，避免切缝）；
## 四角用四角素材的四个象限，各自的"外角"对齐卡牌四角。
## 素材均为 1/8 最近邻降采样 + 白底软抠图后的 *_cut.png，在预制体里拖拽赋值。

@export var corners_texture: Texture2D
@export var corner_scale := 0.34        ## 单个角件边长 = 象限边长 × 该值
@export var corner_inset := 1.0         ## 角件往内收，避免贴出卡边
@export var edge_texture: Texture2D     ## 横边条（卡牌上、下）
@export var edge_v_texture: Texture2D   ## 竖边条（卡牌左、右）
@export var edge_scale := 0.16          ## 边条绘制缩放（相对 1/8 素材）——越小越细，不要盖住卡面
@export var edge_band_center_ratio := 0.49  ## 带中心在素材里的位置
@export var edge_overlap := 0.5         ## 相邻边条间距 = 素材屏宽 × 该值
@export var edge_inset := 4.0           ## 边条中心距卡边的像素（贴着卡框走，不往卡面里挤）
@export var corner_gap := 8.0           ## 四边与四角之间留的缝隙：四角独立露出，不连成一整圈


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var corner_side := _corner_size()
	_draw_sides(corner_side)
	_draw_corners(corner_side)


func _corner_size() -> float:
	if corners_texture == null:
		return 0.0
	var half_w: float = float(corners_texture.get_width()) * 0.5
	var half_h: float = float(corners_texture.get_height()) * 0.5
	return minf(half_w, half_h) * corner_scale


## 四边：在上/下沿横向平铺横条，在左/右沿竖向平铺竖条
func _draw_sides(corner_side: float) -> void:
	# 四边从"角件 + 缝隙"之后才开始，保证四角独立、不连成一整圈
	var from_x: float = corner_side + corner_gap
	var to_x: float = size.x - corner_side - corner_gap
	if to_x > from_x:
		_tile_horizontal(from_x, to_x, edge_inset)
		_tile_horizontal(from_x, to_x, size.y - edge_inset)
	var from_y: float = corner_side + corner_gap
	var to_y: float = size.y - corner_side - corner_gap
	if to_y > from_y:
		_tile_vertical(edge_inset, from_y, to_y)
		_tile_vertical(size.x - edge_inset, from_y, to_y)


func _tile_horizontal(from_x: float, to_x: float, center_y: float) -> void:
	if edge_texture == null:
		return
	var width_px: float = float(edge_texture.get_width())
	var height_px: float = float(edge_texture.get_height())
	var span: float = to_x - from_x
	var step: float = maxf(width_px * edge_scale * edge_overlap, 4.0)
	var count: int = maxi(1, int(ceil(span / step)))
	var actual: float = span / float(count)
	for i in count + 1:
		draw_set_transform(Vector2(from_x + actual * float(i), center_y), 0.0, Vector2.ONE * edge_scale)
		draw_texture(edge_texture, Vector2(-width_px * 0.5, -height_px * edge_band_center_ratio))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _tile_vertical(center_x: float, from_y: float, to_y: float) -> void:
	if edge_v_texture == null:
		return
	var width_px: float = float(edge_v_texture.get_width())
	var height_px: float = float(edge_v_texture.get_height())
	var span: float = to_y - from_y
	var step: float = maxf(height_px * edge_scale * edge_overlap, 4.0)
	var count: int = maxi(1, int(ceil(span / step)))
	var actual: float = span / float(count)
	for i in count + 1:
		draw_set_transform(Vector2(center_x, from_y + actual * float(i)), 0.0, Vector2.ONE * edge_scale)
		draw_texture(edge_v_texture, Vector2(-width_px * edge_band_center_ratio, -height_px * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_corners(corner_side: float) -> void:
	if corners_texture == null:
		return
	var half_w: float = float(corners_texture.get_width()) * 0.5
	var half_h: float = float(corners_texture.get_height()) * 0.5
	var box := Vector2(corner_side, corner_side)
	var offset := Vector2(corner_inset, corner_inset)
	draw_texture_rect_region(corners_texture, Rect2(offset, box), Rect2(0.0, 0.0, half_w, half_h))
	draw_texture_rect_region(corners_texture, Rect2(Vector2(size.x - corner_side - corner_inset, corner_inset), box), Rect2(half_w, 0.0, half_w, half_h))
	draw_texture_rect_region(corners_texture, Rect2(Vector2(corner_inset, size.y - corner_side - corner_inset), box), Rect2(0.0, half_h, half_w, half_h))
	draw_texture_rect_region(corners_texture, Rect2(size - box - offset, box), Rect2(half_w, half_h, half_w, half_h))
