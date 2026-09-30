extends Button
## 交换台的一整行：左侧为玩家交出的牌，右侧为将获得的牌。

@onready var source_option: Button = $SourceCard
@onready var target_option: Button = $TargetCard
@onready var arrow_label: Label = $Arrow
@onready var unavailable_label: Label = $Unavailable

func configure(source: CardData, target: CardData, owned_count: int) -> void:
	source_option.configure(source, "交出 · 当前持有 %d 张" % owned_count)
	target_option.configure(target, "获得")
	_make_mouse_transparent(source_option)
	_make_mouse_transparent(target_option)
	disabled = owned_count <= 0
	unavailable_label.visible = disabled
	modulate.a = 0.46 if disabled else 1.0
	tooltip_text = "缺少可用于交换的%s" % source.display_name if disabled else "交出%s，获得%s" % [source.display_name, target.display_name]

func _make_mouse_transparent(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_make_mouse_transparent(child)
