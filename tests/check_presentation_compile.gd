extends SceneTree
const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("run")


func run() -> void:
	# --script 的 _init 比 autoload._ready 更早；先等一帧，避免把数据库尚未
	# 初始化造成的一串运行时错误误报成“编译成功”。
	await process_frame
	var card_db := root.get_node_or_null("CardDB")
	if card_db == null or card_db.enemies.size() < 2:
		push_error("PRESENTATION_COMPILE_FAILED: CardDB 未就绪")
		quit(1)
		return
	var main := MainScene.instantiate()
	root.add_child(main)
	var view := main.get_node("CombatView")
	view.show()
	view.process_mode = Node.PROCESS_MODE_INHERIT
	view.start_new_combat()
	await process_frame
	await process_frame
	if view.combat == null or view.enemy_rows.size() != 2 or view.card_views.size() != 5:
		push_error("PRESENTATION_COMPILE_FAILED: 战斗视图初始化不完整")
		main.queue_free()
		await process_frame
		quit(1)
		return
	print("PRESENTATION_COMPILE_OK")
	view.juice.reset()
	await create_timer(0.05, true, false, true).timeout
	main.queue_free()
	await process_frame
	await process_frame
	quit(0)
