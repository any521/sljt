extends SceneTree
## 生成真实路线界面截图，供平板、节点间距和连线效果回归检查。

const MainScene = preload("res://scenes/main.tscn")
const OUTPUT := "res://artifacts/verification/tower_map_tablet.png"


func _init() -> void:
	call_deferred("capture")


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/verification"))
	root.size = Vector2i(1920, 1080)
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	var db := root.get_node("CardDB")
	scene.run = RunState.new(420260930, db.build_starter_deck(), db, CharacterRules.SHEN_MING)
	scene.character_panel.hide()
	scene._show_map()
	for _frame in 8:
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error == OK:
		print("CAPTURE_OK: ", ProjectSettings.globalize_path(OUTPUT))
	else:
		push_error("截图保存失败: %s" % error_string(error))
	scene.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
