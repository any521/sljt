@tool
extends Panel
## 左上角船员状态组件。沈明和宋梅共用同一场景，避免两套 UI 尺寸漂移。

@export var crew_name := "船员":
	set(value):
		crew_name = value
		_refresh_preview()
@export var portrait_texture: Texture2D:
	set(value):
		portrait_texture = value
		_refresh_preview()
@export var max_health := 70:
	set(value):
		max_health = maxi(1, value)
		_refresh_preview()
@export var show_block := true:
	set(value):
		show_block = value
		_refresh_preview()


func _ready() -> void:
	_refresh_preview()


func _refresh_preview() -> void:
	if not is_inside_tree():
		return
	var portrait := get_node_or_null("Portrait") as TextureRect
	var name_label := get_node_or_null("Name") as Label
	var hp_label := get_node_or_null("HPLabel") as Label
	var hp_bar := get_node_or_null("HPBar") as ProgressBar
	var hp_ghost := get_node_or_null("HPGhost") as ProgressBar
	var block_label := get_node_or_null("BlockLabel") as Label
	if portrait != null:
		portrait.texture = portrait_texture
	if name_label != null:
		name_label.text = crew_name
	if hp_label != null:
		hp_label.text = "%d / %d" % [max_health, max_health]
	for bar in [hp_bar, hp_ghost]:
		if bar != null:
			bar.max_value = max_health
			bar.value = max_health
	if block_label != null:
		block_label.visible = show_block

