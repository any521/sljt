extends Control
## 战斗中的抽牌堆／弃牌堆查看器。完整卡面由 CardListOption 预制体承担。

@export var option_prefab: PackedScene
@onready var title_label: Label = $Panel/Title
@onready var subtitle_label: Label = $Panel/Subtitle
@onready var grid: GridContainer = $Panel/Scroll/Grid
@onready var empty_label: Label = $Panel/Empty


func _ready() -> void:
	$Panel/Close.pressed.connect(hide)


func present(title_text: String, pile: Array[CardInstance], manager: CombatManager, hide_order: bool) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.free()
	title_label.text = "%s  /  %d 张" % [title_text, pile.size()]
	subtitle_label.text = "显示全部卡牌；抽牌堆只隐藏实际抽取顺序。" if hide_order else "显示当前弃牌堆中的全部卡牌。"
	var cards: Array[CardInstance] = pile.duplicate()
	if hide_order:
		cards.sort_custom(func(a: CardInstance, b: CardInstance): return a.display_name() < b.display_name())
	for instance in cards:
		var option: Button = option_prefab.instantiate()
		grid.add_child(option)
		option.configure(instance.data, "当前费用 %d" % instance.effective_cost(manager.isolation))
		option.mouse_default_cursor_shape = Control.CURSOR_ARROW
		option.focus_mode = Control.FOCUS_NONE
	empty_label.visible = cards.is_empty()
	show()
