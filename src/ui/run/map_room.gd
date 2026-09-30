extends Button
signal chosen(floor_index: int, lane: int)

var floor_index := 0
var lane := 0
var room_id := ""
var room_type := ""
var _selectable := false
var _current := false
var _base_modulate := Color.WHITE
var _selection_tween: Tween

const ROOM_NAMES := {
	"battle": "战斗", "elite": "精英", "boss": "首领", "medicine": "药品",
	"tools": "工具", "maintenance": "维护", "exchange": "交换", "shop": "商店",
	"event": "未知", "rest": "休整",
}

const ROOM_HINTS := {
	"battle": "普通遭遇", "elite": "高风险精英战", "boss": "生物实验室首领",
	"medicine": "恢复生命或取得应急卡", "tools": "升级卡牌或取得工具卡",
	"maintenance": "永久强化一张攻击牌", "exchange": "用基础牌交换新卡",
	"shop": "购买卡牌、饰品或移除卡牌", "event": "结果未知的舱室事件",
	"rest": "恢复生命或调整卡组",
}


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure(room: Dictionary, selectable: bool, visited: bool) -> void:
	floor_index = room.floor
	lane = room.lane
	room_id = room.id
	room_type = room.type
	$Name.text = ROOM_NAMES.get(room_type, "房间")
	$Icon.texture = load("res://assets/art/ui/room_icons/%s.svg" % room_type)
	$VisitedMark.visible = visited
	$SelectionGlow.hide()
	tooltip_text = "%s · 第 %d 舱段\n%s" % [$Name.text, floor_index + 1, ROOM_HINTS.get(room_type, "未知航路节点")]
	_set_room_tint(room_type)
	set_selectable(selectable)
	if visited:
		self_modulate = Color(0.48, 0.88, 0.84, 0.86)
	elif not selectable:
		self_modulate = Color(0.46, 0.57, 0.64, 0.48)
	_base_modulate = self_modulate


func set_selectable(value: bool) -> void:
	_selectable = value
	disabled = not value
	if value:
		self_modulate = Color.WHITE


func set_current(value: bool) -> void:
	_current = value
	if not value:
		return
	$SelectionGlow.show()
	$SelectionGlow.modulate = Color(0.38, 0.86, 1.0, 0.48)
	self_modulate = Color(0.58, 0.92, 1.0, 1.0)
	_base_modulate = self_modulate


func set_legend_highlight(value: bool) -> void:
	if value:
		$SelectionGlow.show()
		$SelectionGlow.modulate = Color(0.38, 0.9, 1.0, 0.86)
		self_modulate = Color(0.9, 1.0, 1.0, 1.0)
		create_tween().tween_property(self, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_SINE)
	else:
		if not _current:
			$SelectionGlow.hide()
		self_modulate = _base_modulate
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)


func play_selected() -> void:
	disabled = true
	_selectable = false
	$SelectionGlow.show()
	$SelectionGlow.modulate = Color(0.55, 0.95, 1.0, 0.0)
	$SelectionGlow.scale = Vector2(0.82, 0.82)
	self_modulate = Color(0.25, 0.82, 1.0, 1.0)
	if _selection_tween != null and _selection_tween.is_valid():
		_selection_tween.kill()
	_selection_tween = create_tween().set_parallel(true)
	_selection_tween.tween_property($SelectionGlow, "modulate:a", 1.0, 0.18)
	_selection_tween.tween_property($SelectionGlow, "scale", Vector2(1.08, 1.08), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_selection_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_room_tint(room_type: String) -> void:
	match room_type:
		"elite", "boss": $Icon.self_modulate = Color("ff78c8")
		"shop", "maintenance": $Icon.self_modulate = Color("ffdc82")
		"medicine", "rest": $Icon.self_modulate = Color("7fe0b4")
		_: $Icon.self_modulate = Color("82dcff")


func _on_mouse_entered() -> void:
	if not _selectable:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.07, 1.07), 0.14).set_trans(Tween.TRANS_SINE)
	tween.tween_property($Icon, "modulate:a", 1.0, 0.12)


func _on_mouse_exited() -> void:
	if not _selectable:
		return
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)


func _pressed() -> void:
	if _selectable:
		chosen.emit(floor_index, lane)
