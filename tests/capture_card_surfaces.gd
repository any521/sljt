extends SceneTree
## 截取战斗牌堆完整卡面网格，供卡牌展示回归检查。

const MainScene = preload("res://scenes/main.tscn")
const OUTPUT := "res://artifacts/verification/card_pile_grid.png"
const EXCHANGE_OUTPUT := "res://artifacts/verification/exchange_card_faces.png"

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/verification"))
	root.size = Vector2i(1920, 1080)
	var scene = MainScene.instantiate()
	root.add_child(scene)
	scene.get_node("TowerMap").hide()
	var view = scene.get_node("CombatView")
	view.show()
	view.process_mode = Node.PROCESS_MODE_INHERIT
	view.start_new_combat()
	for _frame in 80:
		await process_frame
	view._show_pile("抽牌堆", view.combat.draw_pile)
	for _frame in 5:
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	if error == OK:
		print("CAPTURE_OK: ", ProjectSettings.globalize_path(OUTPUT))
	else:
		push_error("截图保存失败: %s" % error_string(error))
	view.hide()
	scene.character_panel.hide()
	scene.run = RunState.new(420260930, root.get_node("CardDB").build_starter_deck(), root.get_node("CardDB"), CharacterRules.SHEN_MING)
	scene._rng.seed = scene.run.seed_value
	scene._show_exchange()
	for _frame in 5:
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var exchange_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(EXCHANGE_OUTPUT))
	if exchange_error == OK:
		print("CAPTURE_OK: ", ProjectSettings.globalize_path(EXCHANGE_OUTPUT))
	else:
		push_error("交换台截图保存失败: %s" % error_string(exchange_error))
	scene.queue_free()
	await process_frame
	quit(0 if error == OK and exchange_error == OK else 1)
