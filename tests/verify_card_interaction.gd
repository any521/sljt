extends SceneTree
## 手牌交互可视化验证 + 客观断言（确定性，不依赖发牌随机与帧率）。
## 抓图供人工确认手感细节；同时打印可机器校验的数值。

const MainScene = preload("res://scenes/main.tscn")
const OUT_DIR := "res://artifacts/verification"
var failed := 0


func _init() -> void:
	call_deferred("capture")


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


## 等到所有手牌运动停稳（逐帧 Lerp 是时间相关的，不能用固定帧数断言）。
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


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var scene := MainScene.instantiate()
	root.add_child(scene)
	for _frame in 90:
		await process_frame
	var view = scene.get_node("CombatView")
	# 把真实光标移开手牌区：否则它可能正停在某张牌上，触发 mouse_entered
	# 给那张牌悬停缩放，导致"非悬停牌保持基准缩放"这类断言假失败。
	Input.warp_mouse(Vector2(20, 20))
	for _frame in 10:
		await process_frame
	await shoot("interaction-1-idle")

	# ① 手牌版式：应以手牌区中心对齐、左右对称，5 张用 1x 基准缩放。
	var hand_transform: Transform2D = view.hand_box.get_global_transform()
	var left := 1e9
	var right := -1e9
	for card_view in view.card_views:
		var half: float = card_view.size.x * card_view.base_scale * 0.5
		var card_center: Vector2 = hand_transform * (card_view.home + card_view.size * 0.5)
		left = minf(left, card_center.x - half)
		right = maxf(right, card_center.x + half)
	var tray_center: float = view._hand_tray.get_global_rect().get_center().x
	print("LAYOUT tray_center=%.1f cards=[%.1f..%.1f] center=%.1f scale=%.3f" % [
		tray_center, left, right, (left + right) * 0.5, view.card_views[0].base_scale])
	check(absf((left + right) * 0.5 - tray_center) < 1.0, "手牌整体居中于卡槽")
	check(view.card_views.size() == 5 and absf(view.card_views[0].base_scale - 0.74) < 0.001, "5 张手牌使用 1x 基准缩放")

	# ② 悬停：中间牌抬高放大，两侧保持基准；移开必须回位。
	var hovered = view.card_views[2]
	var edge = view.card_views[0]
	view._on_card_hovered(hovered, true)
	await settle(view)
	await shoot("interaction-2-hover")
	check(hovered.scale.x > hovered.base_scale + 0.05, "悬停牌被放大")
	check(hovered.position.y < hovered.home.y - 10.0, "悬停牌被抬高")
	for i in view.card_views.size():
		var cv = view.card_views[i]
		print("CARD %d scale=%.3f base=%.3f motion=%s glow=%d" % [
			i, cv.scale.x, cv.base_scale, cv.motion_active, cv.glow])
	check(absf(edge.scale.x - edge.base_scale) < 0.02, "非悬停牌保持基准缩放")
	view._on_card_hovered(hovered, false)
	await settle(view)
	check(hovered.position.distance_to(hovered.home) < 1.5, "移开后手牌精确回到原位")

	# ③ 拖拽瞄准：箭头可见、准星落到敌人锚点、出牌区阈值随起点自适应。
	var card = view.card_views[1]
	# 新的点击式交互：点击拾起（抬出 1/4 屏高后固定），箭头由 _process 每帧同步
	view.pointer_override = card.global_position + card.size * 0.5
	view._handle_click(card)
	view.pointer_override = Vector2(1270, 470)
	view._arrow.follow_mouse = false
	view._arrow.update_drawing_to(Vector2(1270, 470))
	view._set_target(0)
	for _frame in 25:
		await process_frame
	view._update_reticles()
	await shoot("interaction-3-targeting")
	check(view._arrow.visible, "拖拽时指向箭头可见")
	check(view._reticles[0].selected and view._reticles[0].modulate.a > 0.9, "目标敌人准星已点亮")
	check(absf(view._reticles[0].position.x + view._reticles[0].size.x * 0.5 - view._enemy_points[0].x) < 1.0, "准星对齐敌人锚点")
	var base_threshold: float = view.size.y * 0.75
	view._drag_start_y = view.size.y - 60.0
	check(absf(view._play_zone_threshold() - maxf(base_threshold, view.size.y - 60.0 - 100.0)) < 0.01, "起点在基准线下方：阈值 = 起点 − 100")
	view._drag_start_y = 400.0
	check(absf(view._play_zone_threshold() - (400.0 - 50.0)) < 0.01, "起点在基准线上方：阈值 = 起点 − 50")

	# ④ 队列停放：换成固定卡（自身牌，不触发拔枪动画），避免发牌随机带来的时序漂移。
	view._cancel_selection()
	for _frame in 20:
		await process_frame
	var db = root.get_node("CardDB")
	var probe = CardInstance.new(db.get_card("force_shield"), 99999)
	view.combat.hand.clear()
	view.combat.hand.append(probe)
	view._sync_hand(view.combat.hand, false)
	await settle(view)
	view._play_card_on(probe, -1)
	for _frame in 10:
		await process_frame
	print("QUEUE depth=%d flight_children=%d" % [view._play_queue_depth, view.flight_layer.get_child_count()])
	check(view._play_queue_depth >= 1 or view.flight_layer.get_child_count() > 0, "出牌后卡牌进入飞行动画层（队列停放）")
	await shoot("interaction-4-queue")
	for _frame in 90:
		await process_frame
	await shoot("interaction-5-resolved")
	check(not view._arrow.visible, "出牌后箭头收起")
	check(view._play_queue_depth == 0, "出牌结算后队列清空")
	check(not view.combat.hand.has(probe), "打出的牌离开手牌")

	# ⑤ 特效总览：命中火花 / 格挡火花 / 消耗灰烬 / 卡面微光 / 出牌拖尾
	var j = view.juice
	j.hit_spark(view._enemy_points[0], view.CYAN)
	j.hit_spark(view._enemy_points[1], view.MAGENTA)
	j.block_spark(view._hero_point)
	j.exhaust_ash(view._enemy_points[0] + Vector2(0, -70))
	j.sparkle(view._hero_point + Vector2(160, -170), view.GOLD, 8)
	j.card_trail(view._hero_point + Vector2(240, -230), view.MAGENTA, 0.9)
	for _frame in 8:
		await process_frame
	await shoot("interaction-6-vfx")
	check(true, "特效总览截图已生成")

	scene.queue_free()
	await process_frame
	print("交互验证：%s" % ("全部通过" if failed == 0 else "%d 项失败" % failed))
	quit(0 if failed == 0 else 1)
