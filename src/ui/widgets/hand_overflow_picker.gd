extends Control
class_name HandOverflowPicker
## 手牌超限选择界面。可编辑布局和样式在 hand_overflow_picker.tscn；
## 本脚本只负责生成候选卡节点并把玩家的选择交回战斗视图。

signal card_chosen(card: CardInstance)

@export var card_slot_prefab: PackedScene
@export_range(1, 12, 1) var columns := 7
@export var cell_size := Vector2(222, 270)
@export var grid_minimum_size := Vector2(1560, 700)

@onready var title_label: Label = $Panel/Title
@onready var scroll: ScrollContainer = $Panel/CardScroll
@onready var grid: Control = $Panel/CardScroll/CardGrid


func show_candidates(manager: CombatManager) -> void:
	clear_cards()
	if card_slot_prefab == null:
		push_error("HandOverflowPicker 缺少 card_slot_prefab")
		return
	title_label.text = "结束回合前整理手牌  ·  请选择弃掉 %d 张" % manager.overflow_discard_count()
	for i in manager.hand.size():
		var instance: CardInstance = manager.hand[i]
		var slot: Control = card_slot_prefab.instantiate()
		slot.position = Vector2(float(i % columns) * cell_size.x, float(int(i / columns)) * cell_size.y)
		grid.add_child(slot)
		var card: Control = slot.get_node("BattleCard")
		card.setup(manager, instance, i)
		card.playable = true
		card.get_node("Dim").hide()
		card.tooltip_text = "%s\n%s\n点击将这张牌弃入弃牌堆" % [instance.display_name(), instance.data.description]
		card.pressed.connect(_on_card_pressed)
	grid.custom_minimum_size = Vector2(grid_minimum_size.x, maxf(grid_minimum_size.y, ceilf(float(manager.hand.size()) / float(columns)) * cell_size.y))
	show()


func clear_cards() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


func close() -> void:
	hide()
	clear_cards()


func _on_card_pressed(view: Control) -> void:
	card_chosen.emit(view.instance)
