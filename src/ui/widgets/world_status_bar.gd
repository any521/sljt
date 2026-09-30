extends Panel
## Reusable in-world health UI for the active hero and enemies.

@export var status_icon_prefab: PackedScene
@onready var status_row: HBoxContainer = $StatusRow
var _signature := ""

func set_statuses(statuses: Dictionary) -> void:
	var signature := str(statuses)
	if signature == _signature: return
	_signature = signature
	for child in status_row.get_children():
		status_row.remove_child(child)
		child.queue_free()
	for key in statuses:
		var stacks: int = int(statuses[key])
		if stacks <= 0: continue
		var icon: Control = status_icon_prefab.instantiate()
		status_row.add_child(icon)
		icon.call("configure", str(key), stacks)
	status_row.visible = status_row.get_child_count() > 0

func place_statuses_at(foot_point: Vector2) -> void:
	var width := float(status_row.get_child_count()) * 34.0 + float(maxi(0, status_row.get_child_count() - 1)) * 4.0
	status_row.position = foot_point - position - Vector2(width * 0.5, 0)
