extends RefCounted
class_name CardInstance
## 战斗中的卡牌实例 —— 包装 CardData，携带本场战斗的临时修饰
##
## 为什么需要它：卡牌在战斗中会发生变化（异化、费用修正），
## 但这些变化不能污染 CardData 本身（CardDB 是共享的）。

var data: CardData
var cost_delta: int = 0        # 本场战斗的费用修饰（异化 -1 等）
var corrupted: bool = false    # 被阈值 3「皮下蔓延」异化
var uid: int = 0


func _init(p_data: CardData, p_uid: int = 0) -> void:
	data = p_data
	uid = p_uid


func effective_cost(isolation: IsolationSystem = null) -> int:
	var c := data.cost + cost_delta
	if isolation != null:
		c += isolation.cost_modifier_for(data.faction)
	if corrupted:
		c = maxi(0, c - 1)
	return maxi(0, c)


func display_name() -> String:
	return data.display_name


func faction() -> int:
	return data.faction


func is_playable(isolation: IsolationSystem, energy: int) -> bool:
	return effective_cost(isolation) <= energy


## 被异化：费用 -1，打出时隔离 +1（由 CombatManager 处理额外隔离）
func corrupt() -> bool:
	if corrupted or data.faction == CardData.Faction.NEUTRAL:
		return false
	corrupted = true
	return true


func duplicate_instance() -> CardInstance:
	var ci := CardInstance.new(data, uid)
	ci.cost_delta = cost_delta
	ci.corrupted = corrupted
	return ci
