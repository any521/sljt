extends Control
signal choice_made(index: int)

@onready var title_label: Label = $Panel/Title
@onready var body_label: Label = $Panel/Body
@onready var buttons: Array[Button] = [$Panel/Choices/Choice0, $Panel/Choices/Choice1, $Panel/Choices/Choice2, $Panel/Choices/Choice3]

func _ready() -> void:
	for i in buttons.size():
		buttons[i].pressed.connect(_choose.bind(i))

func present(title_text: String, body_text: String, options: Array, disabled_options: Array = [], icon_ids: Array = []) -> void:
	title_label.text = title_text
	body_label.text = body_text
	for i in buttons.size():
		buttons[i].visible = i < options.size()
		if i < options.size():
			buttons[i].text = "   " + str(options[i])
			buttons[i].icon = _icon(icon_ids[i]) if i < icon_ids.size() else null
			buttons[i].icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			buttons[i].expand_icon = true
		buttons[i].disabled = i < disabled_options.size() and disabled_options[i]
	show()

func _icon(icon_id: String) -> Texture2D:
	if icon_id.is_empty(): return null
	if icon_id.begins_with("room:"):
		return load("res://assets/art/ui/room_icons/%s.svg" % icon_id.trim_prefix("room:"))
	if icon_id.begins_with("trinket:"):
		return load("res://assets/art/ui/trinkets/%s.svg" % icon_id.trim_prefix("trinket:"))
	return get_node("/root/CardArt").get_card_texture(icon_id)

func _choose(index: int) -> void:
	choice_made.emit(index)
