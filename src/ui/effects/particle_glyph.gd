extends Control
class_name ParticleGlyph
## 池化粒子的字形。由 juice.tscn 的 particle_prefab 指定，编辑器里可直接改尺寸/pivot。
## 形状按 24x24 设计框绘制，并自动缩放到实际 size —— 改预制体尺寸，全部粒子一起变。
## 形状：spark / slime / smoke / heal / glow / streak / star / ash / silhouette
var kind := "spark"
var tint := Color.WHITE
var motion: Tween


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(24.0, 24.0))
	match kind:
		"spark":
			draw_polygon(PackedVector2Array([Vector2(12,0),Vector2(15,9),Vector2(24,12),Vector2(15,15),Vector2(12,24),Vector2(9,15),Vector2(0,12),Vector2(9,9)]), PackedColorArray([tint]))
		"slime":
			draw_circle(Vector2(12, 13), 7, tint)
			draw_polygon(PackedVector2Array([Vector2(9,8),Vector2(12,0),Vector2(16,9)]), PackedColorArray([tint]))
		"smoke":
			draw_circle(Vector2(12, 12), 10, Color(tint, 0.62))
			draw_circle(Vector2(6, 9), 5, Color(tint, 0.35))
		"heal":
			draw_rect(Rect2(9, 2, 6, 20), tint)
			draw_rect(Rect2(2, 9, 20, 6), tint)
		"glow":
			draw_circle(Vector2(12,12), 9, Color(tint, 0.22))
			draw_circle(Vector2(12,12), 4, tint)
		"streak":
			draw_rect(Rect2(10.5, 0, 3, 24), Color(tint, 0.85))
			draw_circle(Vector2(12, 12), 4.2, tint)
			draw_circle(Vector2(12, 2), 2.0, Color(tint, 0.7))
		"star":
			draw_rect(Rect2(11, 1, 2, 22), tint)
			draw_rect(Rect2(1, 11, 22, 2), tint)
			draw_circle(Vector2(12, 12), 3.4, tint)
		"ash":
			draw_rect(Rect2(7, 8, 10, 8), Color(tint, 0.85))
			draw_rect(Rect2(9.5, 4, 5, 16), Color(tint, 0.5))
		"silhouette":
			draw_rect(Rect2(3, 0, 18, 24), Color(tint, 0.22))
			draw_rect(Rect2(5, 2, 14, 20), Color(tint, 0.5))
		_:
			draw_polygon(PackedVector2Array([Vector2(12,1),Vector2(22,12),Vector2(12,23),Vector2(4,14)]), PackedColorArray([tint]))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
