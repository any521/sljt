extends SceneTree
## 鼠标拖拽路径回归（确定性）。
##
## 直接驱动真实处理函数 —— _on_card_pressed（pressed 信号的处理者）、
## _update_drag（逐帧）、_finish_drag（松手）—— 并用 combat_view.pointer_override
## 注入指针坐标。不依赖系统光标：后台窗口无焦点时 Input.warp_mouse 不可靠，
## 会让测试假失败（那不是游戏逻辑的问题）。
##
## 覆盖两个真实操作才会暴露的问题：
##   ① 牌跟着光标 → 箭头起点终点重合，19 段挤成一个点（看不见箭头）
##   ② 不可打出时抖动打断逐帧运动 → 牌永久卡在中场

const MainScene = preload("res://scenes/main.tscn")
const OUT_DIR := "res://artifacts/verification"
var failed := 0


func _init() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if value:
		print("  PASS ", message)
	else:
		failed += 1
		push_error("  FAIL " + message)


func shoot(name: String) -> void:
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, name])
	var error := image.save_png(path)
	print("CAPTURE %s: %s" % [name, "OK" if error == OK else error_string(error)])


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	root.size = Vector2i(1920, 1080)
	var scene := MainScene.instantiate()
	root.add_child(scene)
	# 本脚本专测战斗表现；正式入口先显示路线图。
	scene.get_node('TowerMap').hide()
	scene.get_node('CombatView').show()
	scene.get_node('CombatView').process_mode = Node.PROCESS_MODE_INHERIT
	scene.get_node('CombatView').start_new_combat()
	for _frame in 100:
		await process_frame
	var view = scene.get_node("CombatView")

	# 挑一张"可打出且需要敌方目标"的牌
	var card: Control = null
	for candidate in view.card_views:
		if not candidate.playable:
			continue
		if card == null:
			card = candidate
		if view._card_requires_enemy_target(candidate.instance) and view.combat.can_play(candidate.instance):
			card = candidate
			break
	if card == null:
		check(false, "起手至少有一张可打出的牌")
		quit(1)
		return
	var targeted: bool = view._card_requires_enemy_target(card.instance)
	print("CARD %s targeted=%s playable=%s" % [card.instance.display_name(), targeted, card.playable])

	# ① 按下：走 pressed 信号真正连到的那条路径
	var grab: Vector2 = card.global_position + card.size * 0.5
	view.pointer_override = grab
	view._on_card_pressed(card)
	await process_frame
	print("PRESS dragging=%s arrow=%s follow=%s" % [view._dragging, view._arrow.visible, view._drag_follow])
	check(view._dragging, "按下即进入待拖拽状态")
	check(not view._arrow.visible, "仅按下不起箭头（可能只是一次点击）")

	# ② 把光标拖到出牌区里的空白处（真人用法的位置：离停放点有距离，但没落在敌人身上）
	var mid := Vector2(700, 512)
	view.pointer_override = mid
	view._arrow.follow_mouse = false
	view._arrow.update_drawing_to(mid + Vector2(30, -20))
	for _frame in 40:
		await process_frame
	var span: float = view._arrow.from_position.distance_to(view._arrow.to_position)
	var card_center: Vector2 = card.global_position + card.size * 0.5
	print("DRAG cast=%s span=%.0f card_from_cursor=%.0f mouse_mode=%d" % [
		view._cast_mode, span, card_center.distance_to(mid), Input.mouse_mode])
	check(view._drag_follow, "指针移动超过阈值后进入拖拽模式")
	check(view._arrow.visible, "拖拽时指向箭头可见")
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "拖拽时隐藏系统光标")
	check(view._cast_mode, "进入出牌区后牌脱离光标（CenterCard）")
	check(card_center.distance_to(mid) > 80.0, "牌已离开光标：%.0f px" % card_center.distance_to(mid))
	check(span > 100.0, "箭头拉得开：起点到终点 %.0f px" % span)
	check(absf(card_center.x - view.CAST_POINT.x) < 6.0 or card_center.distance_to(view.CAST_POINT) < 40.0, "牌停在停放点附近")
	await shoot("interaction-7-mouse-drag")

	# ③ 松手在中间空白处：需要目标的牌应回手，且不能卡住
	view._finish_drag()
	await process_frame
	check(not view._dragging, "松手结束拖拽")
	check(view._arrow.visible == false, "松手后箭头立即收起")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "松手后系统光标恢复")
	view._on_card_hovered(card, false)
	for _frame in 160:
		await process_frame
	var home_distance: float = card.position.distance_to(card.home)
	print("AFTER_RELEASE busy=%s motion=%s home_dist=%.2f hand=%d" % [view._busy, card.motion_active, home_distance, view.card_views.size()])
	check(not view._busy, "松手后没有卡在忙碌态")
	check(not card.motion_active and home_distance < 2.0, "牌精确回到手牌原位（不会卡在中场）")
	check(view._play_queue_depth == 0, "未出牌时队列保持空")

	view.pointer_override = Vector2.INF
	scene.queue_free()
	await process_frame
	print("鼠标拖拽回归：%s" % ("全部通过" if failed == 0 else "%d 项失败" % failed))
	quit(0 if failed == 0 else 1)


