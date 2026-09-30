extends Button
## Card art and its data stay visible for upgrade, reward, removal and purchase.

func configure(card: CardData, caption: String) -> void:
	$ChoiceLabel.text = caption
	var display: Control = $BattleCard
	_set_mouse_ignore(display)
	(display.get_node("Art") as TextureRect).texture = get_node("/root/CardArt").get_card_texture(card.id)
	(display.get_node("Name") as Label).text = card.display_name
	(display.get_node("Cost") as Label).text = str(card.cost)
	(display.get_node("Index") as Label).text = ""
	(display.get_node("Type") as Label).text = "%s / %s" % [card.faction_name(), card.type_name()]
	var description := display.get_node("Description") as Label
	description.text = card.description
	description.add_theme_font_size_override("font_size", 12 if card.description.length() > 45 else (14 if card.description.length() > 28 else 16))
	(display.get_node("Badge") as Label).text = "维护 +%d" % (card.maintenance_level * 3) if card.maintenance_level > 0 else caption
	(display.get_node("Dim") as ColorRect).hide()
	tooltip_text = "%s\n%s" % [card.display_name, card.description]

func _set_mouse_ignore(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: _set_mouse_ignore(child)
