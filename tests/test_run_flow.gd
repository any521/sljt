extends SceneTree
const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	await process_frame
	var db := root.get_node("CardDB")
	var art := root.get_node("CardArt")
	for id in db.cards:
		var card: CardData = db.cards[id]
		if not card.upgraded:
			assert(art.get_card_texture(id) != null, "基础卡必须有可识别卡面：%s" % card.display_name)
	assert(db.starter_deck.size() == 12)
	assert(db.starter_deck.count("calibrate_shot") == 5)
	assert(db.starter_deck.count("force_shield") == 4)
	assert(db.starter_deck.count("lacerate") == 2)
	assert(db.starter_deck.count("logic_lock") == 1)
	var prior_map := RouteMap.generate(1)
	var different := false
	for seed_value in 100:
		var rows := RouteMap.generate(seed_value)
		assert(rows == RouteMap.generate(seed_value), "同种子应复现路径与房间")
		if rows != prior_map: different = true
		assert(rows.size() == 13)
		assert(rows[4][2].type == "shop", "每局至少有一处可达商店")
		for crossing_floor in 12:
			var adjacent_edges: Array[Dictionary] = []
			for source_lane in RouteMap.LANES:
				for route_edge in rows[crossing_floor][source_lane].next:
					if route_edge.floor == crossing_floor + 1:
						adjacent_edges.append({"from": source_lane, "to": route_edge.lane})
			for left_index in adjacent_edges.size():
				for right_index in range(left_index + 1, adjacent_edges.size()):
					var first: Dictionary = adjacent_edges[left_index]
					var second: Dictionary = adjacent_edges[right_index]
					assert(not ((first.from < second.from and first.to > second.to) or (first.from > second.from and first.to < second.to)), "相邻舱段的航路线不得交叉")
		for floor_index in 13:
			for lane in RouteMap.LANES:
				var room: Dictionary = rows[floor_index][lane]
				if not room.active: continue
				if floor_index in [5, 11]: assert(room.type == "rest")
				if floor_index == 12: assert(room.type == "boss")
				for edge in room.next:
					assert(edge.floor == floor_index + 1 or (floor_index in [1, 7] and edge.floor == floor_index + 2))
					assert(abs(edge.lane - lane) <= 1)
					assert(rows[edge.floor][edge.lane].active)
		var path_run := RunState.new(seed_value, db.build_starter_deck(), db)
		while path_run.floor_index < 12:
			var choices := path_run.available_rooms()
			assert(not choices.is_empty(), "已进入房间必须能走到终点")
			assert(not path_run.choose_room(choices[0].floor, choices[0].lane).is_empty())
		assert(path_run.path.size() >= 11 and path_run.path.size() <= 13)
		assert(path_run.path[-1].type == "boss")
		assert(path_run.path.filter(func(room): return room.type == "rest").size() == 2)
		var consecutive := 0
		for room in path_run.path:
			consecutive = consecutive + 1 if room.type in ["battle", "elite", "boss"] else 0
			assert(consecutive <= 2, "不连续三场战斗")
	assert(different, "不同种子应产生不同地图")
	for skip_count in 3:
		var short_run := RunState.new(7421, db.build_starter_deck(), db)
		while short_run.floor_index < 12:
			var destination := short_run.floor_index + 1
			if short_run.floor_index == 1 and skip_count >= 1: destination = 3
			if short_run.floor_index == 7 and skip_count == 2: destination = 9
			assert(not short_run.choose_room(destination, 2).is_empty())
		assert(short_run.path.size() == 13 - skip_count)
	var main := MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.room_transition.cover_seconds = 0.01
	main.room_transition.reveal_seconds = 0.01
	assert(main._mode == "character_select" and main.character_panel.visible)
	assert(main.view.combat == null and main.view.card_views.is_empty(), "选角阶段不应提前初始化战斗或播放发牌表现")
	await main.start_new_run(CharacterRules.SHEN_MING)
	assert(main._mode == "map" and main.map_view.visible)
	assert(not main.room_transition.visible, "选角进入首次地图应完成像素过渡")
	var icon_found := false
	for widget in main.map_view.nodes_layer.get_children():
		if widget.get_node("Icon").texture != null: icon_found = true
	assert(icon_found, "地图房间显示图标")
	main._on_room_chosen(0, 2)
	assert(main._mode == "battle" and main.view.combat.hand.size() == 5)
	main.view.combat.isolation.add(4)
	assert(main.view.combat.isolation.value == 4, "隔离在战斗回合中累积")
	main.view.combat.end_turn()
	assert(main.view.combat.isolation.value == 4, "沈明进入下一回合时隔离不会清零")
	main.view._apply_snapshot(main.view._take_snapshot(), true)
	assert(main.view._map_button != null and main.view._map_button.visible, "战斗右上角应提供导航图标")
	await main._open_battle_map()
	assert(main._battle_map_open and main.map_view.visible and main.map_view.z_index == 200)
	assert(main.view.process_mode == Node.PROCESS_MODE_DISABLED and main.map_view._read_only)
	assert(main.map_view._choice_edges.is_empty() and main.map_view.close_button.visible, "战斗中地图只读且可返回战斗")
	await main._close_battle_map()
	assert(not main._battle_map_open and not main.map_view.visible)
	assert(main.view.process_mode == Node.PROCESS_MODE_INHERIT, "关闭地图后应恢复战斗")
	assert(main.view._player_world_bar.get_node("HPBar").value == main.view.combat.player_hp)
	assert(main.view.enemy_rows[0].intent_panel.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(not main.view.enemy_rows[0].intent_panel.tooltip_text.is_empty())
	main.view.combat.player_statuses["weak"] = 2
	main.view.combat.enemies[0]["statuses"]["vulnerable"] = 1
	main.view._apply_snapshot(main.view._take_snapshot())
	var player_icon := main.view._player_world_bar.get_node("StatusRow").get_child(0) as Control
	var enemy_icon := main.view.enemy_rows[0].statuses.get_child(0) as Control
	assert(player_icon.tooltip_text.contains("虚弱") and enemy_icon.tooltip_text.contains("易伤"))
	var foot_on_screen: Vector2 = main.view.get_global_transform() * main.view._actor_foot_point(main.view.hero, Vector2.ZERO)
	assert(absf(player_icon.global_position.y - foot_on_screen.y) < 2.0)
	assert(main.view._discard_drop_zone.visible)
	var first_card: CardInstance = main.view.card_views[0].instance
	main.view.pointer_override = main.view.card_views[0].get_global_rect().get_center()
	main.view._on_card_pressed(main.view.card_views[0])
	main.view.pointer_override = main.view._discard_drop_zone.get_global_rect().get_center()
	main.view._finish_drag()
	main.view.pointer_override = Vector2.INF
	assert(not main.view.combat.hand.has(first_card) and main.view.combat.voluntary_discards_left == 1)
	await main._on_battle_finished(true)
	assert(main._mode == "map" and main.run.gold == 80, "普通首战只给金币并返回地图")
	assert(main.run.isolation == 4 and main.map_view.status_label.text.contains("隔离  4 / 10"), "隔离结算进本局状态并显示在地图")
	main._enter_battle("battle")
	assert(main.view.combat.isolation.value == 4, "进入下一场战斗后继承隔离值")
	main._mode = "map"
	main.view.hide()
	assert(not main.room_transition.visible, "像素过渡在显出地图后关闭")
	main._on_battle_finished(true)
	assert(main.run.gold == 80, "过渡完成后重复战斗信号不会重复结算奖励")
	main._show_maintenance_choices()
	assert(main.card_list_panel.visible and main.card_list_panel.list_box.get_child_count() >= 5)
	assert(main.card_list_panel.list_box.get_child(0).get_node_or_null("BattleCard/Art") != null)
	await main._on_card_list_choice(0)
	assert(main.run.deck[0].effects[0].value == 9)
	main._show_shop(true)
	assert(main._mode == "shop" and main._shop_offer_ids.size() == 3)
	main._show_shop_cards()
	var offer_id: String = main._shop_offer_ids[0]
	main.run.gold = 100
	await main._on_card_list_choice(0)
	assert(main.run.gold == 10 and main.run.deck.any(func(card): return card.id == offer_id))
	main.run.gold = 200
	main._show_shop_remove()
	var before_size: int = main.run.deck.size()
	await main._on_card_list_choice(0)
	assert(main.run.deck.size() == before_size - 1 and main.run.remove_count == 1)
	main._show_exchange()
	var exchange_rows: VBoxContainer = main.exchange_panel.get_node("Panel/Rows") as VBoxContainer
	var first_exchange: Button = exchange_rows.get_child(0) as Button
	assert(main.exchange_panel.visible and exchange_rows.get_child_count() == 2, "交换台展示两组卡牌交易")
	assert(first_exchange.get_node_or_null("SourceCard/BattleCard/Art") != null and first_exchange.get_node_or_null("TargetCard/BattleCard/Art") != null, "每组交易同时展示交出与获得的完整卡面")
	assert((first_exchange.get_node("SourceCard/BattleCard/Name") as Label).text == "校准射击", "交换台左侧显示玩家要交出的牌")
	main._show_shop_trinkets()
	await main._on_choice(0)
	assert(main.run.trinkets.has(TrinketCatalog.FIELD_DRESSING))
	main._show_event()
	assert(main._mode == "event")
	await main._on_choice(2)
	assert(main._mode == "map")
	main._event_id = "sample"
	main.run.hp = 70
	await main._resolve_event(0)
	assert(main.run.hp == 61 and main.run.trinkets.has(TrinketCatalog.CERAMIC_PLATE), "事件可按百分比扣血换饰品")
	await main.start_new_run(CharacterRules.SONG_MEI)
	main._on_room_chosen(0, 2)
	assert(main.view.combat.character_rules.id == CharacterRules.SONG_MEI)
	assert(main.view.hero == main.view.battle_world.get_node("Gameplay/Actors/SongMei"))
	assert(main.view.get_node_or_null("HUD/PlayerStatus/SongMeiStatus") != null)
	assert(not main.view._discard_drop_zone.visible)
	main.view.juice.reset()
	main.queue_free()
	await process_frame
	await process_frame
	print("RUN_FLOW_OK")
	quit(0)
