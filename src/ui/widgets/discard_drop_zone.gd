extends Panel
## Shen Ming's optional discard target. Card input is handled by CombatView.

@onready var title_label: Label = $Title
@onready var count_label: Label = $Count
var _available := false
var _hovered := false

func set_state(left: int, limit: int, available: bool) -> void:
	_available = available
	title_label.text = "拖牌至此弃置" if available else "本回合已整理"
	count_label.text = "%d / %d" % [left, limit]
	tooltip_text = "沈明每回合最多主动弃置两张手牌。按住卡牌拖到这里松开，弃牌进入弃牌堆。"
	_update_style()

func set_hovered(value: bool) -> void:
	if _hovered == value: return
	_hovered = value
	_update_style()

func _update_style() -> void:
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = Color("ffe286") if _hovered and _available else Color("5b8baa")
	style.bg_color = Color("213f50") if _hovered and _available else Color("0b2030")
	add_theme_stylebox_override("panel", style)
	modulate.a = 1.0 if _available else 0.55
