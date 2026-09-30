extends SceneTree
## 出牌队列回归：
##   ① 前面的牌还在播动画时，仍然可以继续出牌并排队（非阻塞）
##   ② 轮到队列里的牌时若已不满足打出条件（能量被前面的牌花掉），自动放回手牌

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


func run() -> void:
	root.size = Vector2i(1920, 1080)
	var scene := MainScene.instantiate()
	root.add_child(scene)
	# 本脚本专测战斗表现；正式入口先显示路线图。
	scene.get_node('TowerMap').hide()
	scene.get_node('CombatView').show()
	scene.get_node('CombatView').process_mode = Node.PROCESS_MODE_INHERIT
	scene.get_node('CombatView').start_new_combat()
	for _frame in 90:
		await process_frame
	var view = scene.get_node("CombatView")
	var db = root.get_node("CardDB")

	# 用"自身牌"避免目标判定干扰：第一张刚好够能量，第二张必然不够
	var base = db.get_card("force_shield")
	var cost: int = base.cost
	print("BASE %s cost=%d" % [str(base.id), cost])
	if cost < 1:
		check(false, "测试用牌费用需 >= 1")
		quit(1)
		return

	var card_a = CardInstance.new(base, 90001)
	var card_b = CardInstance.new(base, 90002)
	var card_c = CardInstance.new(base, 90003)
	view.combat.hand.clear()
	view.combat.hand.append(card_a)
	view.combat.hand.append(card_b)
	view.combat.hand.append(card_c)
	view.combat.energy = cost
	view._sync_hand(view.combat.hand, false)
	for _frame in 40:
		await process_frame
	check(view.card_views.size() == 3, "手牌视图准备完毕（3 张）")

	var view_a: Control = view._find_card(card_a)
	var view_b: Control = view._find_card(card_b)
	var view_c: Control = view._find_card(card_c)

	print("JUICE card_animations=%s particles=%s busy=%s" % [
		view.juice.enabled("card_animations"), view.juice.enabled("particles"), view._busy])
	# ① 连续入队两张：第一张开始结算时，第二张应当在队列里等待
	view._enqueue_play(view_a, card_a, -1)
	print("AFTER_ENQUEUE_A resolving=%s queue=%d busy=%s depth=%d" % [
		view._resolving, view._play_queue.size(), view._busy, view._play_queue_depth])
	await process_frame
	view._enqueue_play(view_b, card_b, -1)
	await process_frame
	print("QUEUED resolving=%s queue=%d queued=%d busy=%s" % [
		view._resolving, view._play_queue.size(), view._queued_instances.size(), view._busy])
	check(view._resolving, "第一张牌正在结算（有牌在播动画）")
	check(view._queued_instances.has(card_b), "第二张牌已进入队列")
	check(view.card_views.size() == 1, "排队中的牌立即离开手牌布局（手牌只剩第 3 张）")

	# 非阻塞：结算期间仍能操作手牌
	view.pointer_override = view_c.global_position + view_c.size * 0.5
	view._on_card_pressed(view_c)
	await process_frame
	check(view._dragging, "结算期间仍可点击手牌（输入未被阻塞）")
	view._cancel_selection()
	view.pointer_override = Vector2.INF
	await process_frame

	# ② 等队列跑完：第二张能量不足，应被放回手牌
	for _frame in 420:
		await process_frame
		if not view._resolving and view._play_queue.is_empty():
			break
	print("SETTLED resolving=%s queue=%d queued=%d hand=%d energy=%d" % [
		view._resolving, view._play_queue.size(), view._queued_instances.size(), view.combat.hand.size(), view.combat.energy])
	check(not view._resolving, "队列已跑完")
	check(view._queued_instances.is_empty(), "队列清空且无残留标记")
	check(not view.combat.hand.has(card_a), "第一张牌成功打出并离开手牌")
	check(view.combat.hand.has(card_b), "第二张牌因能量不足被放回手牌")
	var returned: Control = view._find_card(card_b)
	check(returned != null and returned.get_parent() == view.hand_box, "放回的牌视图已交还手牌层")
	check(view.combat.hand.has(card_c), "第三张牌始终留在手牌")

	scene.queue_free()
	await process_frame
	print("出牌队列回归：%s" % ("全部通过" if failed == 0 else "%d 项失败" % failed))
	quit(0 if failed == 0 else 1)


