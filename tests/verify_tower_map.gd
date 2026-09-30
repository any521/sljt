extends SceneTree

const MapScene = preload("res://scenes/ui/tower_map.tscn")


func _init() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	await process_frame
	var db := root.get_node("CardDB")
	var run := RunState.new(420260930, db.build_starter_deck(), db, CharacterRules.SHEN_MING)
	var map = MapScene.instantiate()
	root.add_child(map)
	map.show_run(run)
	await process_frame
	await process_frame

	assert(map.map_canvas.size.y > map.map_scroll.size.y * 2.0, "地图画布应明显高于平板视口")
	assert(map.get_node("Tablet").size.y > map.get_node("Tablet").size.x, "导航平板应使用竖屏比例")
	assert(map.map_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
	assert(map.map_scroll.scroll_vertical > 0, "初始视角应定位到地图入口附近")
	assert(map.nodes_layer.get_child_count() >= 30, "应显示完整分支地图，而不是压缩节点")
	assert(not map._choice_edges.is_empty(), "入口可选路线应显示发光虚线")
	assert(map.get_node_or_null("Tablet/Top") == null and map.get_node_or_null("Tablet/Bottom") == null, "地图画布不应保留顶部状态和底部说明")
	assert(map.get_node_or_null("Tablet/Screen/ScrollHint") == null, "地图上不应覆盖滚轮浏览文字")
	assert(map.legend_list.get_child_count() == map.LEGEND_TYPES.size(), "右侧应汇总全部舱室图例")
	var legend_item = map.legend_list.get_child(0)
	var highlighted_widget = map._room_widgets.values().filter(func(widget): return widget.room_type == legend_item.room_type)[0]
	map._on_legend_type_hovered(legend_item.room_type, true)
	assert(highlighted_widget.get_node("SelectionGlow").visible, "悬停图例应高亮地图中的同类节点")
	map._on_legend_type_hovered(legend_item.room_type, false)
	assert(not highlighted_widget.get_node("SelectionGlow").visible, "离开图例后应清除临时高亮")
	for widget in map.nodes_layer.get_children():
		assert(not widget.get_node("Name").visible, "地图节点应隐藏重复名称")
		assert(widget.custom_minimum_size.x <= 84.0, "地图节点预制体应缩小")
	var first_floor_y: Array[float] = []
	var lowest_first_room_bottom := 0.0
	for room in run.rows[0]:
		if not room.active:
			continue
		var room_position: Vector2 = map._room_position(0, room.lane)
		first_floor_y.append(room_position.y)
		lowest_first_room_bottom = maxf(lowest_first_room_bottom, room_position.y + 72.0)
	assert(first_floor_y.max() - first_floor_y.min() >= map.MIN_ROW_STAGGER, "同层节点应有稳定的纵向错落")
	assert(map.start_anchor.position.y - lowest_first_room_bottom >= 120.0, "船长室与第一层战斗应留出清楚间距")
	for seed_value in 50:
		var layout_run := RunState.new(420260930 + seed_value, db.build_starter_deck(), db, CharacterRules.SHEN_MING)
		map._build_visual_offsets(layout_run)
		var segments: Array[Dictionary] = []
		for floor_index in RouteMap.FLOOR_COUNT - 1:
			for source_lane in RouteMap.LANES:
				var source: Dictionary = layout_run.rows[floor_index][source_lane]
				if not source.active:
					continue
				for connection in source.next:
					if connection.floor != floor_index + 1:
						continue
					var target: Dictionary = layout_run.rows[connection.floor][connection.lane]
					segments.append({"from_id": source.id, "to_id": target.id,
						"a": map._room_center(floor_index, source_lane),
						"b": map._room_center(connection.floor, connection.lane)})
		for i in segments.size():
			for j in range(i + 1, segments.size()):
				var first: Dictionary = segments[i]
				var second: Dictionary = segments[j]
				if first.from_id == second.from_id or first.to_id == second.to_id:
					continue
				assert(not _segments_cross(first.a, first.b, second.a, second.b), "视觉偏移后航路线仍不得交叉")

	assert(map.map_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "纵向滚轮浏览不能被禁用")
	var initial_scroll: int = map.map_scroll.scroll_vertical
	map.map_scroll.scroll_vertical = initial_scroll - 160
	await process_frame
	assert(map.map_scroll.scroll_vertical < initial_scroll, "纵向滚动位置应可改变")

	var first_id: String = map._choice_edges.keys()[0]
	var edge = map._choice_edges[first_id]
	assert(edge._state == "available")
	await edge.reveal(0.01)
	assert(edge._state == "traversed" and is_equal_approx(edge._reveal_progress, 1.0), "选择路线后虚线应转为实线")

	map.queue_free()
	await process_frame
	print("TOWER_MAP_OK")
	quit(0)


func _segments_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab_c := (b - a).cross(c - a)
	var ab_d := (b - a).cross(d - a)
	var cd_a := (d - c).cross(a - c)
	var cd_b := (d - c).cross(b - c)
	return ab_c * ab_d < -0.001 and cd_a * cd_b < -0.001
