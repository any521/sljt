extends Control
class_name RingGlyph
## 池化冲击环。由 juice.tscn 的 ring_prefab 指定。
## 以自身原点为圆心绘制，radius/thickness/hexagonal 由 juice 在运行时驱动。
var tint := Color.WHITE
var radius := 10.0
var thickness := 4.0
var hexagonal := false
var motion: Tween


func _draw() -> void:
	if hexagonal:
		var points := PackedVector2Array()
		for i in 7:
			points.append(Vector2.from_angle(-PI * 0.5 + i * TAU / 6.0) * radius)
		draw_polyline(points, tint, thickness, true)
		var inner := PackedVector2Array()
		for i in 7:
			inner.append(Vector2.from_angle(-PI * 0.5 + i * TAU / 6.0) * radius * 0.72)
		draw_polyline(inner, Color(tint, 0.38), maxf(1.0, thickness * 0.35), true)
	else:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, tint, thickness, true)
		draw_arc(Vector2.ZERO, radius * 0.72, -0.4, PI + 0.7, 32, Color(tint, 0.35), maxf(1.0, thickness * 0.35), true)
