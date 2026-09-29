extends RefCounted
class_name DamagePipeline
## 伤害计算管线 —— 纯函数，无状态，可独立测试
##
## 计算顺序（严格，不可调换）：
##   floor( (基础值 + 力量) × 虚弱修正 × 易伤修正 × 回声倍率 )
##
## 设计要点：
##   1. 力量是整数加减，在倍率「之前」计算 —— 所以"力量 × 易伤"是乘法叠加，这是爆发感来源
##   2. 所有乘算结果向下取整，避免浮点误差在多次计算中累积
##   3. 格挡只吸收伤害，不改变易伤层数

const WEAK_MULTIPLIER := 0.75
const VULNERABLE_MULTIPLIER := 1.5


## 计算最终伤害
## attacker_statuses / defender_statuses 形如 { "strength": 2, "weak": 1 }
static func compute(
	base: int,
	attacker_statuses: Dictionary,
	defender_statuses: Dictionary,
	echo_multiplier: float = 1.0
) -> int:
	var dmg := float(base)
	dmg += float(attacker_statuses.get("strength", 0))
	if attacker_statuses.get("weak", 0) > 0:
		dmg *= WEAK_MULTIPLIER
	if defender_statuses.get("vulnerable", 0) > 0:
		dmg *= VULNERABLE_MULTIPLIER
	dmg *= echo_multiplier
	return maxi(0, int(floor(dmg)))


## 格挡吸收：返回 { "blocked": 吸收量, "through": 穿透量 }
## shield 为「护盾」状态，先于格挡结算
static func apply_defense(
	incoming: int, block: int, shield: int = 0
) -> Dictionary:
	var remaining := incoming
	var shield_used := mini(shield, remaining)
	remaining -= shield_used
	var block_used := mini(block, remaining)
	remaining -= block_used
	return {
		"shield_used": shield_used,
		"block_used": block_used,
		"through": remaining,
	}
