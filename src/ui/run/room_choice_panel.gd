extends Control
signal choice_made(index: int)

@export var card_option_prefab: PackedScene
@onready var title_label: Label = $Panel/Title
@onready var body_label: Label = $Panel/Body
@onready var card_scroll: ScrollContainer = $Panel/CardPreviewScroll
@onready var card_list: HBoxContainer = $Panel/CardPreviewScroll/CardPreviewList
@onready var choices: VBoxContainer = $Panel/Choices
@onready var buttons: Array[Button] = [$Panel/Choices/Choice0, $Panel/Choices/Choice1, $Panel/Choices/Choice2, $Panel/Choices/Choice3]

func _ready() -> void:
	for i in buttons.size():
		buttons[i].pressed.connect(_choose.bind(i))

func present(title_text: String, body_text: String, options: Array, disabled_options: Array = [], icon_ids: Array = []) -> void:
	_clear_card_previews()
	title_label.text = title_text
	body_label.text = body_text
	var has_card_options := false
	for i in buttons.size():
		var available := i < options.size()
		var icon_id := str(icon_ids[i]) if i < icon_ids.size() else ""
		var is_card := available and _is_card_id(icon_id)
		buttons[i].visible = available and not is_card
		if available and is_card:
			has_card_options = true
			_add_card_preview(i, icon_id, str(options[i]), i < disabled_options.size() and bool(disabled_options[i]))
		elif available:
			buttons[i].text = "   " + str(options[i])
			buttons[i].icon = _icon(icon_id)
			buttons[i].icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			buttons[i].expand_icon = true
			buttons[i].disabled = i < disabled_options.size() and disabled_options[i]
	card_scroll.visible = has_card_options
	choices.offset_top = 590.0 if has_card_options else 210.0
	show()

func _is_card_id(icon_id: String) -> bool:
	return not icon_id.is_empty() and not icon_id.begins_with("room:") and not icon_id.begins_with("trinket:") and get_node("/root/CardDB").cards.has(icon_id)

func _add_card_preview(index: int, card_id: String, caption: String, is_disabled: bool) -> void:
	var option: Button = card_option_prefab.instantiate()
	card_list.add_child(option)
	option.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	option.configure(get_node("/root/CardDB").get_card(card_id), caption)
	option.disabled = is_disabled
	option.pressed.connect(_choose.bind(index))

func _clear_card_previews() -> void:
	for child in card_list.get_children():
		card_list.remove_child(child)
		child.free()

func _icon(icon_id: String) -> Texture2D:
	if icon_id.is_empty(): return null
	if icon_id.begins_with("room:"):
		return load("res://assets/art/ui/room_icons/%s.svg" % icon_id.trim_prefix("room:"))
	if icon_id.begins_with("trinket:"):
		return load("res://assets/art/ui/trinkets/%s.svg" % icon_id.trim_prefix("trinket:"))
	return null

func _choose(index: int) -> void:
	choice_made.emit(index)
