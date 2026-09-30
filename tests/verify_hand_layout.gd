extends SceneTree
## 手牌版式回归：1~16 张手牌都必须
##   ① 整排居中于可见卡槽
##   ② 整排宽度不超出卡槽（自适应压缩生效）
##   ③ 左右各留出内边距，不被卡槽边缘裁切

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
	scene.get_node('CharacterSelectPanel').hide()
	scene.get_node('CombatView').show()
	scene.get_node('CombatView').process_mode = Node.PROCESS_MODE_INHERIT
	scene.get_node('CombatView').start_new_combat()
	for _frame in 60:
		await process_frame
	var view = scene.get_node("CombatView")
	var db = root.get_node("CardDB")
	var base = db.get_card("force_shield")

	for count in range(1, 17):
		view.combat.hand.clear()
		for i in count:
			view.combat.hand.append(CardInstance.new(base, 70000 + count * 100 + i))
		view._sync_hand(view.combat.hand, false)
		await process_frame
		await process_frame
		var tray: Rect2 = view._hand_tray.get_global_rect()
		var transform: Transform2D = view.hand_box.get_global_transform()
		var left := 1e9
		var right := -1e9
		for card_view in view.card_views:
			var half: float = card_view.size.x * card_view.base_scale * 0.5
			var center: Vector2 = transform * (card_view.home + card_view.size * 0.5)
			left = minf(left, center.x - half)
			right = maxf(right, center.x + half)
		var cards_center := (left + right) * 0.5
		var tray_center := tray.get_center().x
		print("N=%2d tray=%.0f..%.0f cards=%.1f..%.1f center_delta=%+.2f width=%0.1f/%.1f fit=%s" % [
			count, tray.position.x, tray.end.x, left, right,
			cards_center - tray_center, right - left, tray.size.x,
			"OK" if right - left <= tray.size.x - 2.0 * 26.0 + 2.0 else "OVER"])
		check(absf(cards_center - tray_center) < 1.5, "N=%d 整排居中于卡槽（偏差 %.2f px）" % [count, cards_center - tray_center])
		check(right - left <= tray.size.x - 2.0 * 26.0 + 2.0, "N=%d 整排不超出卡槽（宽 %.0f / %.0f）" % [count, right - left, tray.size.x])
		check(left >= tray.position.x + 20.0 and right <= tray.end.x - 20.0, "N=%d 左右留白不被裁切" % count)
		# 相邻卡牌不重叠（"不要遮挡"）：中心距必须 >= 卡宽
		var min_gap := 1e9
		for i in range(1, view.card_views.size()):
			var a: Vector2 = transform * (view.card_views[i - 1].home + view.card_views[i - 1].size * 0.5)
			var b: Vector2 = transform * (view.card_views[i].home + view.card_views[i].size * 0.5)
			var card_w: float = view.card_views[i].size.x * view.card_views[i].base_scale
			min_gap = minf(min_gap, absf(b.x - a.x) - card_w)
		check(min_gap > -1.0, "N=%d 相邻卡牌不重叠（最小余量 %.1f px）" % [count, min_gap])
		check(view._hand_tray.clip_contents, "N=%d 托槽开启裁剪，不会向上溢出" % count)

	scene.queue_free()
	await process_frame
	print("手牌版式回归：%s" % ("全部通过" if failed == 0 else "%d 项失败" % failed))
	quit(0 if failed == 0 else 1)

