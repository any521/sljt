extends Button
signal type_hovered(room_type: String, active: bool)

var room_type := ""

const NAMES := {
	"battle": "战斗", "elite": "精英", "boss": "首领", "medicine": "药品柜",
	"tools": "工具间", "maintenance": "维护台", "exchange": "交换台",
	"shop": "商店", "event": "未知事件", "rest": "休整站",
}

const DESCRIPTIONS := {
	"battle": "普通遭遇", "elite": "高风险战斗", "boss": "章节终点",
	"medicine": "治疗或应急卡", "tools": "升级或工具卡",
	"maintenance": "强化攻击牌", "exchange": "交换基础牌",
	"shop": "购买与移除", "event": "结果尚未确定", "rest": "恢复或调整卡组",
}


func _ready() -> void:
	mouse_entered.connect(func(): type_hovered.emit(room_type, true))
	mouse_exited.connect(func(): type_hovered.emit(room_type, false))


func configure(value: String) -> void:
	room_type = value
	$Icon.texture = load("res://assets/art/ui/room_icons/%s.svg" % room_type)
	$Name.text = NAMES.get(room_type, "房间")
	$Description.text = DESCRIPTIONS.get(room_type, "航路节点")
