extends SceneTree
## 箭头单独预览：只实例化箭头预制体，不加载整场战斗，用来快速核对形态与接缝。
## 输出：artifacts/verification/arrow-preview.png
const ArrowScene = preload("res://scenes/fx/targeting_arrow.tscn")

func _init() -> void:
	call_deferred("run")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/verification"))
	# 长距离（看光束锥形与箭头衔接）
	var long_arrow = ArrowScene.instantiate()
	root.add_child(long_arrow)
	long_arrow.follow_mouse = false
	long_arrow.start_drawing(Vector2(300, 720), false)
	long_arrow.update_drawing_to(Vector2(1260, 300))
	# 短距离（看伸缩后的形态）
	var short_arrow = ArrowScene.instantiate()
	root.add_child(short_arrow)
	short_arrow.follow_mouse = false
	short_arrow.start_drawing(Vector2(900, 780), false)
	short_arrow.update_drawing_to(Vector2(1180, 600))
	# 悬停高亮态（金 -> 亮金）
	var hot_arrow = ArrowScene.instantiate()
	root.add_child(hot_arrow)
	hot_arrow.follow_mouse = false
	hot_arrow.start_drawing(Vector2(1400, 760), false)
	hot_arrow.update_drawing_to(Vector2(1700, 520))
	hot_arrow.set_highlight(true, true)
	for _frame in 90:
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var path := ProjectSettings.globalize_path("res://artifacts/verification/arrow-preview.png")
	var error := root.get_texture().get_image().save_png(path)
	print("ARROW_PREVIEW ", ("OK" if error == OK else error_string(error)))
	quit(0)
