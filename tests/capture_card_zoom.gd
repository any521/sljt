extends SceneTree
## 卡牌特写：截取第一张手牌的区域并放大 3 倍（最近邻），用于检查四角金饰之类的细节。
const MainScene = preload("res://scenes/main.tscn")
const OUT := "res://artifacts/verification/card-zoom.png"

func _init() -> void:
	call_deferred("run")


func run() -> void:
	var scene := MainScene.instantiate()
	root.add_child(scene)
	for _frame in 110:
		await process_frame
	var view = scene.get_node("CombatView")
	var card: Control = view.card_views[0]
	# Control 按 pivot 缩放，中心不变 → 视觉矩形 = 中心 ± size*scale/2
	# 把这张牌临时上移，保证四个角都落在画面内（截完不影响其它测试）
	card.global_position.y -= 230.0
	await process_frame
	var center: Vector2 = card.global_position + card.size * 0.5
	var visual := Rect2(center - card.size * card.scale * 0.5, card.size * card.scale)
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	var transform: Transform2D = view.get_global_transform()
	var scale_factor: float = transform.get_scale().x
	var origin: Vector2 = transform * (visual.position - Vector2(12, 12))
	var region := Rect2i(Vector2i(origin), Vector2i((visual.size + Vector2(24, 24)) * scale_factor))
	region = region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(region)
	crop.resize(maxi(1, crop.get_width() * 3), maxi(1, crop.get_height() * 3), Image.INTERPOLATE_NEAREST)
	var err := crop.save_png(ProjectSettings.globalize_path(OUT))
	print("CARD_ZOOM %s region=%s" % ["OK" if err == OK else error_string(err), str(region)])
	quit(0)
