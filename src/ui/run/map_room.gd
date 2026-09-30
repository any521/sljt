extends Button
signal chosen(floor_index: int, lane: int)

var floor_index := 0
var lane := 0

func configure(room: Dictionary, selectable: bool, visited: bool) -> void:
	floor_index = room.floor
	lane = room.lane
	var names := {"battle": "战斗", "elite": "精英", "boss": "首领", "medicine": "药品", "tools": "工具", "maintenance": "维护", "exchange": "交换", "shop": "商店", "event": "未知", "rest": "休整"}
	$Name.text = names.get(room.type, "房间")
	$Icon.texture = load("res://assets/art/ui/room_icons/%s.svg" % room.type)
	disabled = not selectable
	modulate = Color(1.0, 1.0, 1.0) if selectable else (Color(0.55, 0.8, 0.75) if visited else Color(0.57, 0.62, 0.69))

func _pressed() -> void:
	chosen.emit(floor_index, lane)
