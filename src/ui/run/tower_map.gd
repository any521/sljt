extends Control
signal room_chosen(floor_index: int, lane: int)

@export var room_prefab: PackedScene
@export var edge_prefab: PackedScene

@onready var nodes_layer: Control = $MapArea/Nodes
@onready var edges_layer: Control = $MapArea/Edges
@onready var status_label: Label = $Top/Status
@onready var hint_label: Label = $Bottom/Hint

const LANE_X := [80.0, 360.0, 640.0, 920.0, 1200.0]
const TOP_Y := 26.0
const STEP_Y := 60.0

func _room_position(floor_index: int, lane: int) -> Vector2:
	return Vector2(LANE_X[lane], TOP_Y + (RouteMap.FLOOR_COUNT - 1 - floor_index) * STEP_Y)

func show_run(run: RunState) -> void:
	for child in nodes_layer.get_children(): child.queue_free()
	for child in edges_layer.get_children(): child.queue_free()
	status_label.text = "%s  ·  已过 %d 间  ·  生命 %d/70  ·  金币 %d  ·  卡组 %d  ·  饰品 %d" % [run.character_rules.display_name, run.path.size(), run.hp, run.gold, run.deck.size(), run.trinkets.size()]
	hint_label.text = "选择发光的房间沿线前进；金线是可选捷径。每局路径与事件随机，终点约 11–13 间。"
	var choices: Array[String] = []
	for choice in run.available_rooms(): choices.append(choice.id)
	var visited: Array[String] = []
	for old_room in run.path: visited.append(old_room.id)
	for floor_index in RouteMap.FLOOR_COUNT:
		for lane in RouteMap.LANES:
			var room: Dictionary = run.rows[floor_index][lane]
			if not room.active: continue
			var widget: Button = room_prefab.instantiate()
			nodes_layer.add_child(widget)
			widget.position = _room_position(floor_index, lane)
			widget.configure(room, choices.has(room.id), visited.has(room.id))
			widget.chosen.connect(func(chosen_floor: int, chosen_lane: int): room_chosen.emit(chosen_floor, chosen_lane))
			if floor_index < RouteMap.FLOOR_COUNT - 1:
				for connection in room.next:
					var edge: Line2D = edge_prefab.instantiate()
					edges_layer.add_child(edge)
					var target: Dictionary = run.rows[connection.floor][connection.lane]
					var bypass: bool = connection.floor == floor_index + 2
					edge.call("configure", widget.position + Vector2(64, 0), _room_position(connection.floor, connection.lane) + Vector2(64, 52), room.id == run.selected_room.get("id", "") and choices.has(target.id), bypass)
