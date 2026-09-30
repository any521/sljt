extends SceneTree
## 点击式交互回归：
##   ① 点击一张牌 → 向上抬出 1/4 屏高并固定，箭头出现，光标保持可见
##   ② 再点同一张牌 → 取消，回到手牌
##   ③ 拾起后点敌人 → 入队释放，箭头收起，卡牌最终离手

const MainScene = preload("res://scenes/main.tscn")
var failed := 0


func _init() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if value:
		print("  PASS ", message)
	else:
		failed += 1
		push_error("  FAIL " + message)


func left_click(view, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	event.global_position = point
	view._input(event)


func settle(view, max_frames: int = 300) -> void:
	for _frame in max_frames:
		var moving := false
		for card_view in view.card_views:
			if card_view.motion_active:
				moving = true
				break
		if not moving:
			return
		await process_frame


func run() -> void:
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
	Input.warp_mouse(Vector2(20, 20))
	for _frame in 10:
		await process_frame

	# 挑一张可打出的指向牌（走"找目标"这条路）
	var card: Control = null
	for candidate in view.card_views:
		if candidate.playable and view._card_requires_enemy_target(candidate.instance):
			card = candidate
			break
	if card == null:
		for candidate in view.card_views:
			if candidate.playable:
				card = candidate
				break
	check(card != null, "起手存在可打出的牌")
	if card == null:
		quit(1)
		return
	var targeted: bool = view._card_requires_enemy_target(card.instance)
	print("CARD %s targeted=%s" % [card.instance.display_name(), targeted])

	# ① 点击拾起
	view.pointer_override = card.global_position + card.size * 0.5
	view._on_card_pressed(card)
	view._finish_drag()
	await process_frame
	var rise: float = view.size.y * 0.25
	var want_y: float = card.home.y - rise
	print("PICK selected=%s arrow=%s rise_target=%.1f actual=%.1f mouse_mode=%d" % [
		is_instance_valid(view._selected), view._arrow.visible, want_y, card.target_position.y, Input.mouse_mode])
	check(view._selected == card, "点击后该牌被拾起")
	check(view._arrow.visible, "拾起后箭头出现（连线找目标）")
	check(absf(card.target_position.y - want_y) < 1.0, "牌向上抬出 1/4 屏高（%.0f px）" % rise)
	check(absf(card.target_position.x - card.home.x) < 1.0, "拾起时水平位置不动（原地抬起）")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "点击模式下系统光标保持可见")
	check(card.mouse_filter == Control.MOUSE_FILTER_STOP, "抬起的牌仍可点击（能再点一次取消）")
	await settle(view)

	# ② 再点同一张 → 取消
	view._on_card_pressed(card)
	await process_frame
	print("CANCEL selected=%s arrow=%s" % [is_instance_valid(view._selected), view._arrow.visible])
	check(not is_instance_valid(view._selected), "再点同一张牌即取消拾起")
	check(not view._arrow.visible, "取消后箭头收起")
	# 显式清掉悬停态：真实光标可能正停在这张牌上，会把运动目标改成"悬停位"，
	# 造成"没回到原位"的假失败（不是游戏逻辑问题）。
	view._on_card_hovered(card, false)
	await settle(view)
	print("HOME pos=%s home=%s dist=%.2f motion=%s target=%s" % [
		str(card.position), str(card.home), card.position.distance_to(card.home),
		card.motion_active, str(card.target_position)])
	check(card.position.distance_to(card.home) < 2.0, "取消后牌回到手牌原位")

	# ③ 重新拾起 → 点敌人 → 入队释放
	view._on_card_pressed(card)
	view._finish_drag()
	await process_frame
	check(view._selected == card, "重新拾起成功")
	var enemy_rect: Rect2 = view.enemy_rows[0].target.get_global_rect()
	view.pointer_override = enemy_rect.get_center()
	left_click(view, enemy_rect.get_center())
	await process_frame
	print("RELEASE selected=%s queued=%d queue=%d" % [
		is_instance_valid(view._selected), view._queued_instances.size(), view._play_queue.size()])
	check(not is_instance_valid(view._selected), "点击敌人后结束拾起状态")
	check(view._queued_instances.has(card.instance) or not view.card_views.has(card), "卡牌已进入队列等待释放")
	check(not view._arrow.visible, "入队后箭头收起")

	# ④ 动画与特效播完后，按机制正常推进：牌离手
	for _frame in 500:
		await process_frame
		if not view._resolving and view._play_queue.is_empty():
			break
	print("RESOLVED resolving=%s hand=%d has_card=%s" % [
		view._resolving, view.combat.hand.size(), view.combat.hand.has(card.instance)])
	check(not view._resolving, "队列已跑完")
	check(not view.combat.hand.has(card.instance), "打出的牌按机制离开手牌")
	check(view._queued_instances.is_empty(), "队列无残留")

	view.pointer_override = Vector2.INF
	scene.queue_free()
	await process_frame
	print("点击流程回归：%s" % ("全部通过" if failed == 0 else "%d 项失败" % failed))
	quit(0 if failed == 0 else 1)


