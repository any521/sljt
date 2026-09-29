extends SceneTree
## 使用真实渲染器截取当前 main.tscn，供布局、字体和遮挡回归检查。

const MainScene = preload("res://scenes/main.tscn")
const OUTPUT := "res://artifacts/verification/battle_layout.png"


func _init() -> void:
	call_deferred("capture")


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/verification"))
	var scene := MainScene.instantiate()
	root.add_child(scene)
	# 等待发牌和回合横幅动画稳定，截图才适合检查最终布局。
	for _frame in 90:
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
