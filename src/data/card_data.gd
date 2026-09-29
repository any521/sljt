extends Resource
class_name CardData
## 卡牌数据定义 —— 纯数据，不含任何逻辑或场景依赖
##
## 归属（faction）是《阿卡姆号》的核心设计：
##   规程 PROTOCOL —— 稳定、费用低、伤害平
##   变异 MUTATION —— 伤害高、有额外效果，代价是隔离值
##   中立 NEUTRAL  —— 不参与回声连击，也不打断它

enum Faction { PROTOCOL, MUTATION, NEUTRAL }
enum Type { ATTACK, SKILL, POWER }

const FACTION_NAMES := {
	Faction.PROTOCOL: "规程",
	Faction.MUTATION: "变异",
	Faction.NEUTRAL: "中立",
}

const FACTION_COLORS := {
	Faction.PROTOCOL: Color(0.42, 0.78, 1.0),
	Faction.MUTATION: Color(0.78, 0.28, 0.62),
	Faction.NEUTRAL: Color(0.72, 0.76, 0.72),
}

@export var id: String = ""
@export var display_name: String = ""
@export var faction: Faction = Faction.PROTOCOL
@export var type: Type = Type.ATTACK
@export var cost: int = 1
@export var exhaust: bool = false
@export var description: String = ""
@export var upgraded: bool = false
@export var base_card_id: String = ""
## 效果列表：[{ "action": "damage", "value": 6 }, ...]
@export var effects: Array[Dictionary] = []


func faction_name() -> String:
	return FACTION_NAMES.get(faction, "?")


func faction_color() -> Color:
	return FACTION_COLORS.get(faction, Color.WHITE)


func type_name() -> String:
	match type:
		Type.ATTACK: return "攻击"
		Type.SKILL: return "策略"
		Type.POWER: return "心法"
	return "?"


## 生成卡面文本（从 effects 自动拼装，避免手写描述与逻辑不一致）
func build_description() -> String:
	var parts: PackedStringArray = []
	for e in effects:
		var action: String = e.get("action", "")
		var v: int = e.get("value", 0)
		match action:
			"damage":
				parts.append("造成 %d 点伤害" % v)
			"damage_multi":
				parts.append("造成 %d 点伤害 ×%d 次" % [e.get("value", 0), e.get("times", 1)])
			"block":
				parts.append("获得 %d 点格挡" % v)
			"draw":
				parts.append("抽 %d 张牌" % v)
			"apply":
				parts.append("施加 %d 层%s" % [v, _status_name(e.get("status", ""))])
			"self_damage":
				parts.append("自身失去 %d 点生命" % v)
			"heal":
				parts.append("恢复 %d 点生命" % v)
			"gain_energy":
				parts.append("获得 %d 点能量" % v)
			"isolation":
				var n: int = e.get("value", 0)
				if n > 0:
					parts.append("隔离值 +%d" % n)
				elif n < 0:
					parts.append("隔离值 %d" % n)
			"gain_status":
				parts.append("获得 %d 点%s" % [v, _status_name(e.get("status", ""))])
			"damage_if_echo":
				parts.append("若已触发回声，改为 %d 点伤害" % v)
			"discard":
				parts.append("弃 %d 张牌" % v)
	if exhaust:
		parts.append("消耗")
	description = "。".join(parts) + ("。" if parts.size() > 0 else "")
	return description


func _status_name(s: String) -> String:
	match s:
		"weak": return "虚弱"
		"vulnerable": return "易伤"
		"strength": return "力量"
		"dexterity": return "敏捷"
		"poison": return "腐蚀"
		"ritual": return "仪式"
	return s


func duplicate_card() -> CardData:
	var c := CardData.new()
	c.id = id
	c.display_name = display_name
	c.faction = faction
	c.type = type
	c.cost = cost
	c.exhaust = exhaust
	c.description = description
	c.upgraded = upgraded
	c.base_card_id = base_card_id
	c.effects = effects.duplicate(true)
	return c
