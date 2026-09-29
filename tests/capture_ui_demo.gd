extends SceneTree
## 截取 UI 小 demo：同时出「5 张手牌」与「10 张手牌（自适应缩小）」两张图。
const DemoScene = preload("res://scenes/demo/ui_demo.tscn")
const OUT := "res://artifacts/verification"

func _init() -> void:
	call_deferred("run")

func shoot(node: Control, name: String) -> void:
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	var region := Rect2i(Vector2i.ZERO, Vector2i(1920, 1055))
	region = region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var err := image.get_region(region).save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))
	print("SHOT %s %s" % [name, "OK" if err == OK else error_string(err)])

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var demo := DemoScene.instantiate()
	root.add_child(demo)
	for _frame in 40:
		await process_frame
	await shoot(demo, "ui-demo-hand5")
	demo.hand_count = 10
	demo.queue_redraw()
	for _frame in 20:
		await process_frame
	await shoot(demo, "ui-demo-hand10")
	quit(0)
