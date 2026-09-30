extends Control
signal room_chosen(floor_index: int, lane: int)
signal close_requested

@export var room_prefab: PackedScene
@export var edge_prefab: PackedScene
@export var legend_item_prefab: PackedScene

@onready var map_scroll: ScrollContainer = $Tablet/Screen/MapScroll
@onready var map_canvas: Control = $Tablet/Screen/MapScroll/MapCanvas
@onready var nodes_layer: Control = $Tablet/Screen/MapScroll/MapCanvas/Nodes
@onready var edges_layer: Control = $Tablet/Screen/MapScroll/MapCanvas/Edges
@onready var start_anchor: Panel = $Tablet/Screen/MapScroll/MapCanvas/StartAnchor
@onready var status_label: Label = $SidePanel/RunInfo
@onready var hint_label: Label = $SidePanel/RouteState
@onready var legend_list: VBoxContainer = $SidePanel/LegendList
@onready var close_button: Button = $SidePanel/CloseButton
@onready var scroll_rail: ColorRect = $Tablet/Screen/ScrollRail
@onready var scroll_thumb: ColorRect = $Tablet/Screen/ScrollThumb

const LANE_X := [30.0, 180.0, 330.0, 480.0, 630.0]
const TOP_Y := 80.0
const STEP_Y := 155.0
const NODE_CENTER := Vector2(42, 36)
const JITTER_X := 18.0
const FLOOR_JITTER_Y := 18.0
const NODE_JITTER_Y := 22.0
const MIN_ROW_STAGGER := 22.0

var _choice_edges: Dictionary = {}
var _room_widgets: Dictionary = {}
var _position_offsets: Dictionary = {}
var _selection_locked := false
var _read_only := false

const LEGEND_TYPES := [
	"battle", "elite", "rest", "shop", "event", "medicine",
	"tools", "maintenance", "exchange", "boss",
]


func _ready() -> void:
	map_scroll.get_v_scroll_bar().value_changed.connect(_update_scroll_indicator)
	_build_legend()
	close_button.pressed.connect(func(): close_requested.emit())
	_update_scroll_indicator(0.0)


func _build_legend() -> void:
	for room_type in LEGEND_TYPES:
		var item = legend_item_prefab.instantiate()
		legend_list.add_child(item)
		item.configure(room_type)
		item.type_hovered.connect(_on_legend_type_hovered)


func _on_legend_type_hovered(room_type: String, active: bool) -> void:
	for widget in _room_widgets.values():
		widget.set_legend_highlight(widget.room_type == room_type and active)


func _room_position(floor_index: int, lane: int) -> Vector2:
	var room_id := "%02d_%d" % [floor_index, lane]
	var offset: Vector2 = _position_offsets.get(room_id, Vector2.ZERO)
	return Vector2(LANE_X[lane], TOP_Y + (RouteMap.FLOOR_COUNT - 1 - floor_index) * STEP_Y) + offset


func _room_center(floor_index: int, lane: int) -> Vector2:
	return _room_position(floor_index, lane) + NODE_CENTER


func show_run(run: RunState, read_only: bool = false) -> void:
	_read_only = read_only
	_selection_locked = false
	_choice_edges.clear()
	_room_widgets.clear()
	_build_visual_offsets(run)
	for child in nodes_layer.get_children():
		child.queue_free()
	for child in edges_layer.get_children():
		child.queue_free()
	var progress_text := "入口" if run.floor_index < 0 else "%d/13" % (run.floor_index + 1)
	status_label.text = "%s\n舱段  %s\n生命  %d / 70\n隔离  %d / 10\n金币  %d\n卡组  %d 张\n饰品  %d 件" % [run.character_rules.display_name, progress_text, run.hp, run.isolation, run.gold, run.deck.size(), run.trinkets.size()]
	hint_label.text = "战斗暂停 · 正在查看航路" if _read_only else "等待选择航路"
	close_button.visible = _read_only
	var choices: Array[String] = []
	if not _read_only:
		for choice in run.available_rooms():
			choices.append(choice.id)
	var visited: Array[String] = []
	for old_room in run.path:
		visited.append(old_room.id)
	_build_nodes(run, choices, visited)
	_build_edges(run, choices)
	_build_start_edges(run, choices)
	call_deferred("_focus_current_route", run.floor_index, run.lane)


func _build_visual_offsets(run: RunState) -> void:
	_position_offsets.clear()
	var visual_rng := RandomNumberGenerator.new()
	visual_rng.seed = run.seed_value ^ 0x52A17E
	for floor_index in RouteMap.FLOOR_COUNT:
		# A small shared shift keeps the floor band readable. Per-node offsets then
		# break the ruler-straight row without changing the logical graph.
		var floor_shift := visual_rng.randf_range(-FLOOR_JITTER_Y, FLOOR_JITTER_Y)
		var active_lanes: Array[int] = []
		var local_y: Dictionary = {}
		for lane in RouteMap.LANES:
			var room: Dictionary = run.rows[floor_index][lane]
			if not room.active:
				continue
			active_lanes.append(lane)
			local_y[lane] = visual_rng.randf_range(-NODE_JITTER_Y, NODE_JITTER_Y)
		# Avoid a random result that accidentally puts the whole floor back on a
		# ruler-straight line. The endpoints provide a visible minimum stagger.
		if active_lanes.size() >= 2:
			var row_min := INF
			var row_max := -INF
			for lane in active_lanes:
				row_min = minf(row_min, local_y[lane])
				row_max = maxf(row_max, local_y[lane])
			if row_max - row_min < MIN_ROW_STAGGER:
				local_y[active_lanes[0]] = -MIN_ROW_STAGGER * 0.5
				local_y[active_lanes[-1]] = MIN_ROW_STAGGER * 0.5
		for lane in active_lanes:
			var room: Dictionary = run.rows[floor_index][lane]
			_position_offsets[room.id] = Vector2(
				visual_rng.randf_range(-JITTER_X, JITTER_X),
				floor_shift + float(local_y[lane])
			)


func _build_nodes(run: RunState, choices: Array[String], visited: Array[String]) -> void:
	for floor_index in RouteMap.FLOOR_COUNT:
		for lane in RouteMap.LANES:
			var room: Dictionary = run.rows[floor_index][lane]
			if not room.active:
				continue
			var widget: Button = room_prefab.instantiate()
			nodes_layer.add_child(widget)
			widget.position = _room_position(floor_index, lane)
			widget.configure(room, choices.has(room.id), visited.has(room.id))
			widget.set_current(room.id == run.selected_room.get("id", ""))
			widget.chosen.connect(_on_room_requested.bind(widget))
			_room_widgets[room.id] = widget


func _build_edges(run: RunState, choices: Array[String]) -> void:
	for floor_index in RouteMap.FLOOR_COUNT - 1:
		for lane in RouteMap.LANES:
			var room: Dictionary = run.rows[floor_index][lane]
			if not room.active:
				continue
			for connection in room.next:
				var target: Dictionary = run.rows[connection.floor][connection.lane]
				var state := "locked"
				if _is_traversed_segment(run.path, room.id, target.id):
					state = "traversed"
				elif room.id == run.selected_room.get("id", "") and choices.has(target.id):
					state = "available"
				var edge = edge_prefab.instantiate()
				edges_layer.add_child(edge)
				var bypass: bool = connection.floor == floor_index + 2
				edge.configure(_room_center(floor_index, lane), _room_center(connection.floor, connection.lane), state, bypass)
				if state == "available":
					_choice_edges[target.id] = edge


func _build_start_edges(run: RunState, choices: Array[String]) -> void:
	var from_point := Vector2(start_anchor.position.x + start_anchor.size.x * 0.5, start_anchor.position.y)
	for lane in RouteMap.LANES:
		var room: Dictionary = run.rows[0][lane]
		if not room.active:
			continue
		var state := "locked"
		if not run.path.is_empty() and run.path[0].id == room.id:
			state = "traversed"
		elif choices.has(room.id):
			state = "available"
		var edge = edge_prefab.instantiate()
		edges_layer.add_child(edge)
		edge.configure(from_point, _room_center(0, lane), state, false)
		if state == "available":
			_choice_edges[room.id] = edge


func _is_traversed_segment(path: Array[Dictionary], from_id: String, to_id: String) -> bool:
	for i in range(path.size() - 1):
		if path[i].id == from_id and path[i + 1].id == to_id:
			return true
	return false


func _on_room_requested(floor_index: int, lane: int, widget: Button) -> void:
	if _selection_locked or _read_only:
		return
	_selection_locked = true
	for id in _room_widgets:
		var other = _room_widgets[id]
		if other != widget and not other.disabled:
			other.set_selectable(false)
	widget.play_selected()
	hint_label.text = "航路同步中……"
	var room_id: String = widget.room_id
	if _choice_edges.has(room_id):
		await _choice_edges[room_id].reveal(0.72)
	hint_label.text = "航路已确认"
	room_chosen.emit(floor_index, lane)


func _focus_current_route(floor_index: int, lane: int) -> void:
	await get_tree().process_frame
	var focus_y := start_anchor.position.y + start_anchor.size.y * 0.5
	var focus_ratio := 0.84
	if floor_index >= 0:
		focus_y = _room_position(floor_index, lane).y
		focus_ratio = 0.56
	var target := clampi(int(focus_y - map_scroll.size.y * focus_ratio), 0, int(maxf(0.0, map_canvas.size.y - map_scroll.size.y)))
	map_scroll.scroll_vertical = target
	_update_scroll_indicator(float(target))


func _update_scroll_indicator(value: float) -> void:
	if map_scroll == null or scroll_rail == null or scroll_thumb == null:
		return
	var bar := map_scroll.get_v_scroll_bar()
	var total := maxf(bar.max_value, map_scroll.size.y)
	var page := map_scroll.size.y
	var rail_height := scroll_rail.size.y
	var thumb_height := clampf(rail_height * page / total, 66.0, rail_height)
	var travel := maxf(rail_height - thumb_height, 0.0)
	var max_scroll := maxf(bar.max_value - page, 1.0)
	var ratio := clampf(value / max_scroll, 0.0, 1.0)
	scroll_thumb.position.y = scroll_rail.position.y + travel * ratio
	scroll_thumb.size.y = thumb_height
