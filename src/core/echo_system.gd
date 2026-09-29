extends RefCounted
class_name EchoSystem
## 回声系统 —— 规程 / 变异 交替连击
##
## 核心张力：连击要求你「交替」出牌，而交替意味着你必然要用变异牌。
## 你越想变强，越快变成它们。
##
## 规则：
##   打出与上次「相反归属」的牌   → 连击 +1，倍率提升
##   打出与上次「相同归属」的牌   → 连击清零
##   打出中立牌                   → 不参与，也不打断（连击保持）
##   回合结束                     → 连击清零（但每场战斗内的最大连击会被记录）

const MULTIPLIERS := [1.00, 1.15, 1.30, 1.50, 1.75, 2.00]

signal echo_changed(streak: int, multiplier: float)
signal echo_triggered(streak: int)
signal echo_broken(previous_streak: int)

var streak: int = 0
var max_streak_this_combat: int = 0
var last_faction: int = -1


func reset_combat() -> void:
	streak = 0
	max_streak_this_combat = 0
	last_faction = -1


func reset_turn() -> void:
	if streak != 0:
		var prev := streak
		streak = 0
		last_faction = -1
		echo_broken.emit(prev)
		echo_changed.emit(streak, current_multiplier())


func current_multiplier() -> float:
	var idx := clampi(streak, 0, MULTIPLIERS.size() - 1)
	return MULTIPLIERS[idx]


## 预测：如果现在打出某归属的牌，连击会变成几
## 注意：第一张非中立牌只建立基准、不加连击（与 on_card_played 保持一致）
func streak_if_played(faction: int) -> int:
	if faction == CardData.Faction.NEUTRAL:
		return streak
	if last_faction == -1:
		return 0
	if faction != last_faction:
		return streak + 1
	return 0


## 预测：如果现在打出某归属的牌，倍率会是多少（用于卡面「预计伤害」）
func multiplier_if_played(faction: int) -> float:
	var idx := clampi(streak_if_played(faction), 0, MULTIPLIERS.size() - 1)
	return MULTIPLIERS[idx]


## 预测：这张牌会「延续连击」「打断连击」还是「不参与」
## 返回 "extend" / "break" / "neutral" / "first"
func predict(faction: int) -> String:
	if faction == CardData.Faction.NEUTRAL:
		return "neutral"
	if last_faction == -1:
		return "first"
	return "extend" if faction != last_faction else "break"


## 要延续连击，下一张牌必须是什么归属？
## 返回 CardData.Faction 值；若当前无连击基准（还没出过牌）返回 -1
func required_faction_for_extend() -> int:
	if last_faction == -1:
		return -1
	return CardData.Faction.MUTATION if last_faction == CardData.Faction.PROTOCOL else CardData.Faction.PROTOCOL


## 打出一张牌后调用。返回本次是否为「回声触发」
func on_card_played(faction: int) -> bool:
	# 中立牌：不参与也不打断
	if faction == CardData.Faction.NEUTRAL:
		return false

	# 第一张非中立牌：建立基准，不计连击
	if last_faction == -1:
		last_faction = faction
		echo_changed.emit(streak, current_multiplier())
		return false

	# 交替 → 连击提升
	if faction != last_faction:
		last_faction = faction
		streak += 1
		max_streak_this_combat = maxi(max_streak_this_combat, streak)
		echo_triggered.emit(streak)
		echo_changed.emit(streak, current_multiplier())
		return true

	# 同归属 → 连击清零
	var prev := streak
	last_faction = faction
	streak = 0
	if prev > 0:
		echo_broken.emit(prev)
	echo_changed.emit(streak, current_multiplier())
	return false


## 连击 ≥3 时触发「深渊低语」：抽 1 张牌
func should_whisper() -> bool:
	return streak >= 3


## 连击 ≥5 时额外效果：本回合伤害再 +50%
func bonus_damage_multiplier() -> float:
	return 1.5 if streak >= 5 else 1.0


func describe() -> String:
	return "回声 ×%d (%.2f)" % [streak, current_multiplier()]
