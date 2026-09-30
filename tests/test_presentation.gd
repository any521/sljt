extends SceneTree
## Fast integration coverage for the battle presentation layer.
const View = preload("res://src/ui/combat_view.gd")
const MainScene = preload("res://scenes/main.tscn")
var passed := 0
var failed := 0

func check(value: bool, message: String) -> void:
	if value:
		passed += 1
		print("  ✓ ", message)
	else:
		failed += 1
		push_error("  ✗ %s" % message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("\n── 战斗表现集成测试 ──")
	var view: View = View.new()
	view.add_child(preload("res://scenes/ui/battle_overlays.tscn").instantiate())
	root.add_child(view)
	await process_frame
	await process_frame
	check(view.combat != null, "战斗视图创建 CombatManager")
	check(view.card_views.size() == 5, "起手创建 5 个卡牌视图")
	view.pointer_override = view.card_views[0].global_position + view.card_views[0].size * 0.5
	view._on_card_pressed(view.card_views[0])
	view._finish_drag()
	check(view._preview_card.visible and not view._arrow.visible, "点击卡牌只打开中央预览，不出现箭头")
	view._cancel_selection()
	view.pointer_override = Vector2.INF
	var overflow_db = root.get_node("CardDB")
	view.combat._draw(5)
	check(not view._overflow_overlay.visible and view.combat.hand.size() == 10, "回合中可暂时持有 10 张牌")
	view._on_end_turn_pressed()
	check(view._overflow_overlay.visible and view._overflow_overlay.grid.get_child_count() == 10, "结束回合时展示全部 10 张候选牌")
	view._on_overflow_card_chosen(view._overflow_overlay.grid.get_child(0).get_node("BattleCard").instance)
	check(view._overflow_overlay.visible and view.combat.overflow_discard_count() == 1, "弃第一张后继续要求玩家选择")
	view._on_overflow_card_chosen(view._overflow_overlay.grid.get_child(0).get_node("BattleCard").instance)
	check(not view._overflow_overlay.visible and view.combat.hand.size() == 8, "选够后关闭面板并保留 8 张手牌")
	await process_frame
	view.restart()
	await process_frame
	var draw_card := CardInstance.new(overflow_db.get_card("logic_lock_plus"), 70000)
	view.combat.hand.clear()
	view.combat.hand.append(draw_card)
	for i in 7:
		view.combat.hand.append(CardInstance.new(overflow_db.get_card("calibrate_shot"), 70001 + i))
	view._sync_hand(view.combat.hand, false)
	await view._play_card_on(draw_card, -1)
	check(view.combat.has_hand_overflow() and not view._overflow_overlay.visible, "打出抽二牌后可暂时持有 9 张")
	view._on_end_turn_pressed()
	check(view._overflow_overlay.visible, "结束回合时打开弃牌选择")
	view._on_overflow_card_chosen(view._overflow_overlay.grid.get_child(0).get_node("BattleCard").instance)
	check(not view._overflow_overlay.visible, "弃一张后自动关闭选择并结束回合")
	await process_frame
	view.restart()
	await process_frame
	for i in 2:
		view.combat.hand.append(CardInstance.new(overflow_db.get_card("calibrate_shot"), 81000 + i))
	view._sync_hand(view.combat.hand, false)
	await view._on_end_turn_pressed()
	check(view.combat.hand.size() == 10 and not view._overflow_overlay.visible, "留 7 张到下回合再抽 3 张仍可继续行动")
	view._on_end_turn_pressed()
	check(view._overflow_overlay.visible, "再次结束回合时需要整理到 8 张")
	for i in 2:
		view._on_overflow_card_chosen(view._overflow_overlay.grid.get_child(0).get_node("BattleCard").instance)
	check(view.combat.hand.size() == 8 and not view._overflow_overlay.visible, "回合抽牌超限可选弃到 8 张")
	await process_frame
	view.restart()
	await process_frame
	check(view.enemy_rows.size() == 2, "创建两套独立敌人表现")
	check(view.battle_world.get_node_or_null("Environment/Backdrop") != null and view.battle_world.backdrop.size.x > 0.0, "场景文件中的战斗背景尺寸有效")
	var actors := view.battle_world.get_node("Gameplay/Actors")
	var hero_actor = actors.get_node_or_null("ShenMing")
	var song_actor = actors.get_node_or_null("SongMei")
	var kin_front = actors.get_node_or_null("KinVariant1")
	var kin_back = actors.get_node_or_null("KinVariant2")
	check(hero_actor != null and hero_actor.get_node_or_null("AnimatedSprite2D") != null, "沈明场景使用可编辑 AnimatedSprite2D")
	check(song_actor != null and song_actor.get_node_or_null("AnimatedSprite2D") != null and kin_front.get_node_or_null("AnimatedSprite2D") != null and kin_back.get_node_or_null("AnimatedSprite2D") != null, "宋梅与两个眷族变体全部使用 AnimatedSprite2D")
	check(hero_actor != null and hero_actor.sprite.sprite_frames.has_animation("draw_gun") and hero_actor.sprite.sprite_frames.get_frame_count("draw_gun") == 12, "沈明 SpriteFrames 暴露 12 帧 draw_gun")
	check(not hero_actor.has_node("Flash") and not kin_front.has_node("Flash"), "角色场景不再包含会残留白块的 Flash ColorRect")
	check(absf(hero_actor.size.y - song_actor.size.y) < 1.0 and absf(hero_actor.size.y - kin_front.size.y) < 1.0, "四名角色视觉高度统一")
	check(not Rect2(hero_actor.position, hero_actor.size).intersects(Rect2(song_actor.position, song_actor.size)) and not Rect2(kin_front.position, kin_front.size).intersects(Rect2(kin_back.position, kin_back.size)), "前后排角色矩形互不遮挡")
	check(hero_actor.position.y > song_actor.position.y and kin_front.position.y > kin_back.position.y, "沈明与前排眷族位于更靠前的纵深")
	check(kin_front.facing_left and kin_back.facing_left and kin_front.sprite.flip_h and kin_back.sprite.flip_h, "两个眷族变体都朝向左侧")
	check(view.battle_world.get_node_or_null("Environment/Lighting/PracticalLights/LeftCyanKey") is PointLight2D, "光照场景提供可编辑 PointLight2D")
	check(view.battle_world.get_node_or_null("Environment/Lighting/Atmosphere/VolumetricBeams") is ColorRect, "环境层提供可编辑体积光节点")
	check(view.card_views[0].has_node("Frame") and view.card_views[0].has_node("Description"), "手牌由可编辑 battle_card.tscn 节点实例化")
	var card_text_fits := true
	var card_text_is_readable := true
	var card_title_regions_are_separate := true
	for card_view in view.card_views:
		for node_name in ["Cost", "Name", "Index", "Type", "Description", "Badge"]:
			var card_label := card_view.get_node(node_name) as Label
			card_text_fits = card_text_fits and card_label.get_minimum_size().y <= card_label.size.y + 1.0
			card_text_is_readable = card_text_is_readable and card_label.get_theme_font_size("font_size") >= 12
		var card_name := card_view.get_node("Name") as Label
		var card_index := card_view.get_node("Index") as Label
		card_title_regions_are_separate = card_title_regions_are_separate and card_name.position.x + card_name.size.x <= card_index.position.x
	check(card_text_fits, "卡牌名称、类型、描述和徽标均未越过各自纵向区域")
	check(card_text_is_readable, "卡牌最小字号不低于 12px")
	check(card_title_regions_are_separate, "卡名与右上角编号区域互不遮挡")
	check(view.get_node_or_null("HUD") != null and view.get_node_or_null("Cards") != null and view.get_node_or_null("Overlays") != null, "战斗表现按 World/HUD/Cards/Overlays 分层")
	check(view.get_node_or_null("HUD/PlayerStatus") != null and view.get_node_or_null("HUD/CombatMeters") != null, "HUD 控件进入可编辑的功能分组")
	var shen_status := view.get_node("HUD/PlayerStatus/ShenMingStatus") as Control
	var song_status := view.get_node("HUD/CompanionStatus/SongMeiStatus") as Control
	check(shen_status.size == song_status.size and shen_status.position.y + shen_status.size.y < song_status.position.y, "沈明与宋梅使用同规格左上状态框且无重叠")
	check(view.theme.default_font.resource_path.ends_with("ZLabsPixel_12px_M_CN.ttf"), "战斗界面统一继承工坊像素黑体")
	var shen_portrait_texture := (shen_status.get_node("Portrait") as TextureRect).texture as AtlasTexture
	check(shen_portrait_texture != null and shen_portrait_texture.atlas.resource_path.ends_with("portrait_shen_ming.png"), "沈明状态栏使用正式立绘资源")
	var critical_labels: Array[Label] = [
		shen_status.get_node("Name") as Label,
		shen_status.get_node("HPLabel") as Label,
		song_status.get_node("Name") as Label,
		view.enemy_rows[0].name_label as Label,
		view.enemy_rows[0].hp_label as Label,
		view.enemy_rows[1].name_label as Label,
		view.enemy_rows[1].hp_label as Label,
	]
	check(critical_labels.all(func(label: Label): return label.get_minimum_size().x <= label.size.x + 1.0 and label.get_minimum_size().y <= label.size.y + 1.0), "工坊像素黑体在角色与敌人关键状态文字中不越界")
	check(view.get_node("HUD/CombatMeters").get_children().any(func(node): return node.get_script() == preload("res://src/ui/widgets/pixel_frame.gd")), "主要 HUD 仪表使用统一 4px 像素框体")
	check(absf((view.enemy_rows[0].plate.position.x + view.enemy_rows[0].plate.size.x * 0.5) - (kin_front.position.x + kin_front.size.x * 0.5)) < 1.0, "敌人血条中心与角色头顶锚点对齐")
	check(not view.enemy_rows[0].plate.get_rect().intersects(view.enemy_rows[1].plate.get_rect()), "两个敌人头顶 UI 互不遮挡")
	check(view.hand_box == view.get_node_or_null("Cards/Hand") and view.flight_layer == view.get_node_or_null("Cards/Flight"), "手牌与飞行动画绑定场景预设节点")
	check(view.get_node_or_null("Overlays/WorldTargets").get_child_count() == 2, "敌人热区进入 WorldTargets 分组")
	check(view.juice.get_parent() == view.get_node_or_null("Overlays/Effects"), "战斗特效进入 Effects 分组")
	var authored_main := MainScene.instantiate()
	check(authored_main.has_node("CombatView/HUD/TopBar") and authored_main.has_node("CombatView/Cards/Hand") and authored_main.has_node("CombatView/Overlays/Menus"), "main.tscn 直接组合可展开的 UI 子场景")
	check(authored_main.has_node("CombatView/Overlays/Menus/HandOverflowPicker/Panel/CardScroll/CardGrid"), "超限选牌在主场景中保留可编辑节点")
	authored_main.free()
	check(view.juice._particles.size() == 128, "粒子池预分配 128 个节点")
	check(view.juice._numbers.size() == 28, "伤害数字池预分配 28 个标签")
	check(view.juice._rings.size() == 16, "冲击环池预分配 16 个节点")
	check(view.juice.settings.has("reduce_flashes") and view.juice.settings.has("reduce_motion") and view.juice.settings.has("shake_strength"), "三项必需无障碍设置可用")
	check(view.size == Vector2(1920, 1055), "战斗 UI 使用 1920×1055 安全画布")
	var card_db = root.get_node("CardDB")
	check(view._card_requires_enemy_target(CardInstance.new(card_db.get_card("calibrate_shot"))), "攻击牌要求敌方目标")
	check(not view._card_requires_enemy_target(CardInstance.new(card_db.get_card("force_shield"))), "自身策略牌可拖到战场使用")
	check(root.get_node("McpInteractionServer")._server == null, "普通游戏/测试不会开放调试命令端口")
	var threshold_events: Array[int] = []
	view.combat.isolation_threshold.connect(func(value, _stage): threshold_events.append(value))
	view.combat.isolation.add(3)
	check(threshold_events == [3], "隔离阈值从逻辑层正确转发表现层")
	check(view.combat.hand.any(func(card): return card.corrupted), "阈值 3 仍执行手牌异化规则")
	for card_view in view.card_views:
		card_view.modulate.a = 0.25
		card_view._dim.visible = true
		card_view.selected = true
	view._sync_hand(view.combat.hand, false)
	check(view.card_views.all(func(card_view): return is_equal_approx(card_view.modulate.a, 1.0) and not card_view._dim.visible and not card_view.selected), "跨回合复用卡牌会清除旧遮罩和透明度")
	# Disable duration-heavy pieces only for test speed; APIs and pools stay live.
	view.juice.settings["card_animations"] = false
	view.juice.settings["enemy_animations"] = false
	view.juice.settings["hit_stop"] = false
	view.juice.settings["sound"] = false
	var attack: CardInstance = null
	for card in view.combat.hand:
		if card.faction() == CardData.Faction.PROTOCOL and view.combat.preview_card_damage(card, 0) > 0 and view.combat.can_play(card):
			attack = card
			break
	if attack != null:
		var before: int = view.combat.enemies[0].hp
		var timings := {"gun_finished": 0, "damage": 0}
		hero_actor.sprite.animation_finished.connect(func():
			if timings.gun_finished == 0:
				timings.gun_finished = Time.get_ticks_msec())
		view.combat.damage_dealt.connect(func(_source, _target, _amount, _blocked):
			if timings.damage == 0:
				timings.damage = Time.get_ticks_msec())
		await view._play_card_on(attack, 0)
		check(view.combat.enemies[0].hp < before, "真实出牌链路造成伤害并完成事件回放")
		if attack.data.id in ["calibrate_shot", "calibrate_shot_plus"]:
			check(timings.gun_finished == 0 and timings.damage > 0, "校准射击直接结算，不播放拔枪动作")
		else:
			check(timings.gun_finished > 0 and timings.damage >= timings.gun_finished, "其他工程攻击在拔枪动画结束后才结算伤害")
		check(not view.combat.hand.has(attack), "已打出的卡从手牌视觉与逻辑移除")
	else:
		check(false, "起手至少存在一张可用攻击牌")
	kin_front.hit(false, false, false)
	kin_front.die(false)
	await create_timer(0.12, true, false, true).timeout
	check(not kin_front.visible, "眷族死亡后从战场隐藏且无白色残留节点")
	kin_front.reset_actor()
	var player_before: int = view.combat.player_hp
	await view._on_end_turn_pressed()
	check(view.combat.player_hp < player_before, "敌人回合伤害通过表现队列结算")
	check(view.combat.phase == CombatManager.Phase.PLAYER_TURN or view.combat.is_over(), "敌人行动后回到合法阶段")
	check(view.card_views.all(func(card_view): return is_equal_approx(card_view.modulate.a, 1.0)), "新回合卡牌不会继承上一轮的变暗透明度")
	check(view.juice._time_requests.is_empty(), "测试结束无悬挂时间缩放请求")
	if not view.combat.is_over():
		var self_card := CardInstance.new(card_db.get_card("force_shield"), 99999)
		view.combat.hand.clear()
		view.combat.hand.append(self_card)
		view._sync_hand(view.combat.hand, false)
		var block_before: int = view.combat.player_block
		await view._play_card_on(self_card, -1)
		check(view.combat.player_block > block_before, "自身策略牌无需敌方目标即可结算")
	view.juice.reset()
	# 给音频线程一个短暂清理窗口，避免 headless 进程退出时误报 WAV 泄漏。
	await create_timer(0.05, true, false, true).timeout
	view.queue_free()
	await process_frame
	await process_frame
	print("表现测试：%d 通过 / %d 失败" % [passed, failed])
	quit(0 if failed == 0 else 1)
