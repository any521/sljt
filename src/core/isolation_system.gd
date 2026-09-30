extends RefCounted
class_name IsolationSystem
## 隔离系统 —— 《阿卡姆号》的核心压力机制
##
## 隔离值 = 你体内外星组织的占比。
## 每打出一次「变异」牌，隔离值 +1，同时变异牌本身已经更强了。
##
## 满值不是死亡，是【同化】—— 你变成它们的一员，成为游戏的一部分。
##
## 机制即故事：你想逃出去，但你每逃一步都更像它们。

const MAX_VALUE := 10

const STAGE_NAMES := {
	0: "正常",
	3: "皮下蔓延",
	6: "组织共生",
	8: "意识让渡",
	10: "同化",
}

signal changed(value: int)
signal threshold_reached(value: int, stage_name: String)
signal assimilated()

var value: int = 0


func reset(initial_value: int = 0) -> void:
	value = clampi(initial_value, 0, MAX_VALUE)
	changed.emit(value)


func add(amount: int) -> void:
	if amount == 0:
		return
	var before := value
	value = clampi(value + amount, 0, MAX_VALUE)
	changed.emit(value)

	# 跨越阈值时依次触发（一次 +3 可能跨过两个阈值）
	for t in [3, 6, 8, 10]:
		if before < t and value >= t:
			threshold_reached.emit(t, STAGE_NAMES[t])
			if t == 10:
				assimilated.emit()


func is_assimilated() -> bool:
	return value >= MAX_VALUE


func stage_name() -> String:
	var result := "正常"
	for t in [3, 6, 8, 10]:
		if value >= t:
			result = STAGE_NAMES[t]
	return result


## —— 以下为阈值效果的查询接口，供 CombatManager 调用 ——

## 阈值 3：手牌随机 1 张变为「异化」（费用 -1，打出时隔离再 +1）
func has_stage_3() -> bool:
	return value >= 3


## 阈值 6：每回合开始 +1 力量，但每回合结束失去 2 点生命
func has_stage_6() -> bool:
	return value >= 6


## 阈值 8：所有变异牌费用 -1，但每回合随机弃掉 1 张牌
func has_stage_8() -> bool:
	return value >= 8


## 阈值 8 的费用修正
func cost_modifier_for(faction: int) -> int:
	if has_stage_8() and faction == CardData.Faction.MUTATION:
		return -1
	return 0


func describe() -> String:
	return "隔离 %d/10 · %s" % [value, stage_name()]
