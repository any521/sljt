extends Node
## CardDB —— 卡池与敌池数据库（autoload 单例）
##
## 当前范围：14 张基础卡 + 9 张升级版；2 普通、1 精英、1 首领。
## 后续扩展：把 _build_* 换成从 res://data/*.tres 加载即可，接口不变。

var cards: Dictionary = {}         # id -> CardData
var enemies: Dictionary = {}       # id -> EnemyData
var starter_deck: Array[String] = []
var reward_pool: Array[String] = []  # M0 战斗后三选一的来源

const THRESHOLD_3 := 3
const THRESHOLD_6 := 6
const THRESHOLD_8 := 8
const THRESHOLD_10 := 10
const ISOLATION_MAX := 10


func _ready() -> void:
	_build_cards()
	_build_enemies()
	_build_pools()
	print("[CardDB] 已加载 %d 张卡，%d 个敌人" % [cards.size(), enemies.size()])


# ---------------------------------------------------------------- 卡牌构造

func _card(
	p_id: String, p_name: String, p_faction: int, p_type: int, p_cost: int,
	p_effects: Array, p_exhaust: bool = false
) -> CardData:
	var c := CardData.new()
	c.id = p_id
	c.display_name = p_name
	c.faction = p_faction
	c.type = p_type
	c.cost = p_cost
	c.exhaust = p_exhaust
	c.effects.assign(p_effects)
	c.build_description()
	return c


func _upgrade_of(base: CardData, p_name: String, p_effects: Array) -> CardData:
	var c := _card(
		base.id + "_plus", p_name, base.faction, base.type, base.cost, p_effects, base.exhaust
	)
	c.upgraded = true
	c.base_card_id = base.id
	return c


func _build_cards() -> void:
	var P := CardData.Faction.PROTOCOL
	var M := CardData.Faction.MUTATION
	var N := CardData.Faction.NEUTRAL
	var ATK := CardData.Type.ATTACK
	var SKL := CardData.Type.SKILL

	# ============================ 规程（6 张）============================
	_add(_card("calibrate_shot", "校准射击", P, ATK, 1,
		[{"action": "damage", "value": 6}]))
	_add(_card("precision_strike", "精准打击", P, ATK, 2,
		[{"action": "damage", "value": 14}]))
	_add(_card("force_shield", "力场护罩", P, SKL, 1,
		[{"action": "block", "value": 6}]))
	_add(_card("framework_scan", "框架分析", P, SKL, 1,
		[{"action": "apply", "status": "vulnerable", "value": 1},
		 {"action": "draw", "value": 1}]))
	_add(_card("overclock", "超频运转", P, SKL, 0,
		[{"action": "gain_energy", "value": 2},
		 {"action": "self_damage", "value": 4}], true))
	_add(_card("insulation", "绝缘屏障", P, SKL, 1,
		[{"action": "block", "value": 8}]))

	# ============================ 变异（6 张）============================
	_add(_card("lacerate", "撕裂", M, ATK, 1,
		[{"action": "damage", "value": 9},
		 {"action": "self_damage", "value": 2},
		 {"action": "isolation", "value": 1}]))
	_add(_card("parasite_spore", "寄生孢子", M, ATK, 1,
		[{"action": "damage", "value": 4},
		 {"action": "apply", "status": "poison", "value": 3},
		 {"action": "isolation", "value": 1}]))
	_add(_card("flesh_reshape", "血肉重塑", M, SKL, 1,
		[{"action": "block", "value": 8},
		 {"action": "isolation", "value": 1}]))
	_add(_card("abyss_gaze", "深渊凝视", M, SKL, 1,
		[{"action": "apply", "status": "weak", "value": 2},
		 {"action": "block", "value": 3},
		 {"action": "isolation", "value": 1}]))
	_add(_card("sacrifice_blood", "献祭之血", M, SKL, 0,
		[{"action": "self_damage", "value": 3},
		 {"action": "gain_status", "status": "strength", "value": 1},
		 {"action": "isolation", "value": 1}], true))
	_add(_card("symbiotic_shell", "共生甲壳", M, SKL, 1,
		[{"action": "block", "value": 11},
		 {"action": "isolation", "value": 2}]))

	# ============================ 中立（2 张）============================
	_add(_card("emergency_medkit", "应急医疗", N, SKL, 1,
		[{"action": "heal", "value": 8}], true))
	_add(_card("logic_lock", "逻辑锁", N, SKL, 1,
		[{"action": "isolation", "value": -2},
		 {"action": "draw", "value": 1}], true))

	# ============================ 升级版 ============================
	_add(_upgrade_of(cards["calibrate_shot"], "校准射击+",
		[{"action": "damage", "value": 9}]))
	_add(_upgrade_of(cards["lacerate"], "撕裂+",
		[{"action": "damage", "value": 12},
		 {"action": "self_damage", "value": 2},
		 {"action": "isolation", "value": 1}]))
	_add(_upgrade_of(cards["force_shield"], "力场护罩+",
		[{"action": "block", "value": 9}]))
	_add(_upgrade_of(cards["framework_scan"], "框架分析+",
		[{"action": "apply", "status": "vulnerable", "value": 2},
		 {"action": "draw", "value": 1}]))
	_add(_upgrade_of(cards["precision_strike"], "精准打击+",
		[{"action": "damage", "value": 18}]))
	_add(_upgrade_of(cards["logic_lock"], "逻辑锁+",
		[{"action": "isolation", "value": -2},
		 {"action": "draw", "value": 2}]))
	_add(_upgrade_of(cards["flesh_reshape"], "血肉重塑+",
		[{"action": "block", "value": 11},
		 {"action": "isolation", "value": 1}]))
	_add(_upgrade_of(cards["insulation"], "绝缘屏障+",
		[{"action": "block", "value": 11}]))
	_add(_upgrade_of(cards["symbiotic_shell"], "共生甲壳+",
		[{"action": "block", "value": 15}, {"action": "isolation", "value": 2}]))


func _add(c: CardData) -> void:
	cards[c.id] = c


func _build_pools() -> void:
	# 沈明与宋梅暂时共用基础牌组：5 攻、4 防、2 撕裂、1 逻辑锁。
	starter_deck = [
		"calibrate_shot", "calibrate_shot", "calibrate_shot", "calibrate_shot", "calibrate_shot",
		"force_shield", "force_shield", "force_shield", "force_shield",
		"lacerate", "lacerate", "logic_lock",
	]
	# M0 战斗奖励池（不含初始牌与升级版；升级走后续的"营地"系统）
	reward_pool = [
		"precision_strike", "overclock", "framework_scan", "insulation",
		"parasite_spore", "abyss_gaze", "flesh_reshape", "symbiotic_shell",
		"emergency_medkit",
	]


# ---------------------------------------------------------------- 敌人构造

func _build_enemies() -> void:
	# 潜伏者 —— 低压教学敌人，带腐蚀
	var lurker := EnemyData.new()
	lurker.id = "lurker"
	lurker.display_name = "眷族变体 A"
	lurker.kind = EnemyData.Kind.NORMAL
	lurker.max_hp = 30
	lurker.art_color = Color(0.35, 0.72, 0.55)
	lurker.intent_pattern.assign([
		{"type": "attack", "value": 6},
		{"type": "debuff", "status": "poison", "value": 2},
		{"type": "attack", "value": 9},
	])
	enemies[lurker.id] = lurker

	# 巡逻机兵 —— 教玩家"打格挡"的敌人
	var sentry := EnemyData.new()
	sentry.id = "sentry"
	sentry.display_name = "眷族变体 B"
	sentry.kind = EnemyData.Kind.NORMAL
	sentry.max_hp = 42
	sentry.art_color = Color(0.55, 0.62, 0.78)
	sentry.intent_pattern.assign([
		{"type": "attack", "value": 5, "times": 2},
		{"type": "block", "value": 8},
		{"type": "attack_block", "value": 8, "block": 5},
	])
	enemies[sentry.id] = sentry

	var guardian := EnemyData.new()
	guardian.id = "guardian"
	guardian.display_name = "封锁机兵"
	guardian.kind = EnemyData.Kind.ELITE
	guardian.max_hp = 65
	guardian.art_color = Color(0.75, 0.55, 0.78)
	guardian.intent_pattern.assign([
		{"type": "attack", "value": 11},
		{"type": "block", "value": 10},
		{"type": "attack_block", "value": 9, "block": 7},
	])
	enemies[guardian.id] = guardian

	var lab_core := EnemyData.new()
	lab_core.id = "lab_core"
	lab_core.display_name = "实验室守卫"
	lab_core.kind = EnemyData.Kind.BOSS
	lab_core.max_hp = 115
	lab_core.art_color = Color(0.69, 0.28, 0.53)
	lab_core.intent_pattern.assign([
		{"type": "attack", "value": 10},
		{"type": "debuff", "status": "poison", "value": 2},
		{"type": "attack", "value": 14},
		{"type": "block", "value": 12},
	])
	enemies[lab_core.id] = lab_core


# ---------------------------------------------------------------- 查询接口

func get_card(id: String) -> CardData:
	if not cards.has(id):
		push_error("[CardDB] 未知卡牌 id: %s" % id)
		return null
	return cards[id]


func get_enemy(id: String) -> EnemyData:
	if not enemies.has(id):
		push_error("[CardDB] 未知敌人 id: %s" % id)
		return null
	return enemies[id]


## 构建一套初始卡组（返回副本，避免战斗中被污染）
func build_starter_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	for id in starter_deck:
		deck.append(get_card(id).duplicate_card())
	return deck
