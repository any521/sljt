extends Resource
class_name EnemyData
## 敌人数据定义 —— 纯数据
##
## 意图模式（intent_pattern）是一组字典，按回合循环执行：
##   { "type": "attack",     "value": 6,  "times": 1 }
##   { "type": "block",      "value": 8 }
##   { "type": "attack_block","value": 6, "block": 5 }
##   { "type": "debuff",     "status": "weak", "value": 1 }
##   { "type": "buff",       "status": "strength", "value": 2 }
##   { "type": "unknown" }

enum Kind { NORMAL, ELITE, BOSS }

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.NORMAL
@export var max_hp: int = 30
@export var art_color: Color = Color(0.5, 0.8, 0.6)
@export var intent_pattern: Array[Dictionary] = []


func kind_name() -> String:
	match kind:
		Kind.NORMAL: return "普通"
		Kind.ELITE: return "精英"
		Kind.BOSS: return "首领"
	return "?"


func intent_at(turn_index: int) -> Dictionary:
	if intent_pattern.is_empty():
		return {"type": "unknown"}
	return intent_pattern[turn_index % intent_pattern.size()]
