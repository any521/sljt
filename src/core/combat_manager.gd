extends RefCounted
class_name CombatManager
## 战斗状态机 —— 完整规则实现，纯逻辑，零场景依赖
##
## 这一层可以完全无头运行与单元测试（见 tests/test_combat.gd）。
## UI 通过监听这里的信号来做表现，绝不反向调用 UI。

# ---------------------------------------------------------------- 常量

const BASE_ENERGY := 3
const PLAYER_MAX_HP := 70

enum Phase { COMBAT_START, PLAYER_TURN, PLAYER_ACTING, ENEMY_TURN, VICTORY, DEFEAT, ASSIMILATED }

# ---------------------------------------------------------------- 信号

signal combat_started()
signal turn_started(turn_number: int, is_player: bool)
signal energy_changed(current: int, maximum: int)
signal hand_changed()
signal overflow_resolved()
signal piles_changed(draw: int, discard: int, exhaust: int)
signal card_played(instance: CardInstance)
signal echo_changed(streak: int, multiplier: float)
signal isolation_changed(value: int)
signal isolation_threshold(value: int, stage_name: String)
signal player_stats_changed()
signal enemy_stats_changed(index: int)
signal enemy_intents_updated()
signal enemy_acted(index: int, intent: Dictionary)
signal damage_dealt(source_name: String, target_name: String, amount: int, blocked: int)
signal whisper(text: String)
signal combat_ended(victory: bool)

# ---------------------------------------------------------------- 状态

var phase: Phase = Phase.COMBAT_START
var turn_number: int = 0

# 玩家状态
var player_max_hp: int = PLAYER_MAX_HP
var player_hp: int = PLAYER_MAX_HP
var player_block: int = 0
var player_statuses: Dictionary = {}   # strength / weak / vulnerable / shield / poison …

# 能量
var energy: int = BASE_ENERGY
var max_energy: int = BASE_ENERGY
var character_rules := CharacterRules.new()
var voluntary_discards_left: int = 0

# 子系统
var echo := EchoSystem.new()
var isolation := IsolationSystem.new()

# 牌堆（全部为 CardInstance）
var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []
## 本场已经使用的一次性卡牌 id；由 RunState 在战斗结算时从本局牌组删除。
var purged_card_ids: Array[String] = []

# 敌人
var enemies: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _uid_counter: int = 0
var _cards_played_this_turn: int = 0
var _current_play_context: Dictionary = {}
var _extended_draw_used := false
var _echo_storage_limit := 0
var _pending_echo_store_limit := 0
var _stored_echo := 0
var _stored_faction := -1
var _turn_started_with_stored := false
## 当前出牌的目标敌人索引（-1 = 自动选第一个存活敌人）
var _current_target: int = -1


func _init(seed_value: int = -1) -> void:
	# Relay subsystem thresholds through the manager so presentation and the
	# existing stage-3 gameplay hook observe the same authoritative event.
	if not isolation.threshold_reached.is_connected(on_isolation_threshold):
		isolation.threshold_reached.connect(on_isolation_threshold)
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


# ================================================================ 初始化

## 战斗初始化。
## 注意：这里接收的是「数据对象」而不是 id —— 核心逻辑层不依赖 CardDB autoload，
## 因此可以脱离引擎的单例环境独立运行与测试（调用方负责从 CardDB 取数据）。
func start_combat(
	deck: Array[CardData],
	enemy_data_list: Array[EnemyData],
	p_player_hp: int = -1,
	p_character_rules: CharacterRules = null,
	p_trinkets: Array[String] = [],
	p_initial_isolation: int = 0
) -> void:
	if p_character_rules != null:
		character_rules = p_character_rules
	player_hp = p_player_hp if p_player_hp >= 0 else player_max_hp
	player_block = 0
	player_statuses.clear()
	turn_number = 0
	_cards_played_this_turn = 0
	_current_play_context.clear()
	_extended_draw_used = false
	_echo_storage_limit = 0
	_pending_echo_store_limit = 0
	_stored_echo = 0
	_stored_faction = -1
	_turn_started_with_stored = false
	voluntary_discards_left = character_rules.voluntary_discard_limit
	echo.reset_combat()
	# 隔离属于本次爬塔的持续状态。这里只载入进入战斗前的数值，
	# 不重复触发已经跨越过的阈值事件。
	isolation.reset(p_initial_isolation)

	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	purged_card_ids.clear()

	for cd in deck:
		_uid_counter += 1
		draw_pile.append(CardInstance.new(cd, _uid_counter))
	draw_pile.shuffle()

	enemies.clear()
	for ed in enemy_data_list:
		enemies.append(_make_enemy(ed))

	emit_signal("combat_started")
	emit_signal("player_stats_changed")
	_emit_piles()
	_refresh_intents()
	_start_player_turn()
	if p_trinkets.has(TrinketCatalog.SPARE_CAPACITOR):
		energy += 1
		emit_signal("energy_changed", energy, max_energy)
	if p_trinkets.has(TrinketCatalog.CERAMIC_PLATE):
		player_block += 4
		emit_signal("player_stats_changed")


func _make_enemy(ed: EnemyData) -> Dictionary:
	var hp: int = ed.max_hp
	return {
		"data": ed,
		"name": ed.display_name,
		"hp": hp,
		"max_hp": hp,
		"block": 0,
		"statuses": {},
		"intent_index": 0,
		"alive": true,
	}


# ================================================================ 玩家回合

func _start_player_turn() -> void:
	if _check_combat_over():
		return
	phase = Phase.PLAYER_TURN

	player_block = 0
	_cards_played_this_turn = 0
	_extended_draw_used = false
	voluntary_discards_left = character_rules.voluntary_discard_limit
	_turn_started_with_stored = _stored_echo > 0 and _stored_faction >= 0
	if _turn_started_with_stored:
		echo.streak = _stored_echo
		echo.last_faction = _stored_faction
		emit_signal("echo_changed", echo.streak, echo.current_multiplier())
	_stored_echo = 0
	_stored_faction = -1

	if isolation.has_stage_6():
		_add_status(player_statuses, "strength", 1)
		emit_signal("player_stats_changed")

	_tick_player_statuses()
	# 回合开始的腐蚀可能致死。必须在补能量、抽牌和发出玩家回合信号前
	# 结束战斗，否则会出现生命为负但仍可继续出牌的“尸体回合”。
	if _check_combat_over():
		return

	energy = max_energy
	emit_signal("energy_changed", energy, max_energy)

	_draw(character_rules.opening_draw if turn_number == 0 else character_rules.turn_draw)
	_clear_invalid_corruption()

	emit_signal("turn_started", turn_number, true)
	_emit_piles()
	emit_signal("hand_changed")


## 回合开始的减益倒计时
func _tick_player_statuses() -> void:
	if player_statuses.get("poison", 0) > 0:
		var p: int = player_statuses["poison"]
		_take_damage_direct(p, "腐蚀")
		player_statuses["poison"] = p - 1
		if player_statuses["poison"] <= 0:
			player_statuses.erase("poison")
	for key in ["weak", "vulnerable"]:
		if player_statuses.get(key, 0) > 0:
			player_statuses[key] -= 1
			if player_statuses[key] <= 0:
				player_statuses.erase(key)


func end_turn() -> void:
	if phase != Phase.PLAYER_TURN and phase != Phase.PLAYER_ACTING:
		return
	if has_hand_overflow():
		return
	# 隔离 10 是“本回合最后的自救窗口”，不是触碰瞬间死亡。
	# 玩家按下结束回合时仍未降下来，才正式完成同化判定。
	if isolation.is_assimilated():
		phase = Phase.ASSIMILATED
		emit_signal("combat_ended", false)
		emit_signal("whisper", "「同化。」")
		return

	# 阈值 6 代价：每回合结束失去 2 点生命
	if isolation.has_stage_6():
		_take_damage_direct(2, "组织共生")

	# 宋梅按常规弃掉未打出的手牌；沈明保留它们到下一回合。
	if not character_rules.retain_hand:
		for card in hand:
			discard_pile.append(card)
		hand.clear()

	var store_limit := maxi(_echo_storage_limit, _pending_echo_store_limit)
	if store_limit > 0 and echo.streak >= 2 and echo.last_faction >= 0:
		_stored_echo = mini(store_limit, echo.streak)
		_stored_faction = echo.last_faction
	_pending_echo_store_limit = 0
	echo.reset_turn()
	emit_signal("echo_changed", echo.streak, echo.current_multiplier())
	_emit_piles()
	emit_signal("hand_changed")

	if _check_combat_over():
		return

	_enemy_turn()


# ================================================================ 出牌

func can_play(instance: CardInstance) -> bool:
	if phase != Phase.PLAYER_TURN and phase != Phase.PLAYER_ACTING:
		return false
	if not hand.has(instance):
		return false
	return instance.effective_cost(isolation) <= energy


func play_card(instance: CardInstance, target_index: int = -1) -> bool:
	if not can_play(instance):
		return false

	phase = Phase.PLAYER_ACTING
	_current_target = target_index
	var cost := instance.effective_cost(isolation)
	energy -= cost
	_cards_played_this_turn += 1
	emit_signal("energy_changed", energy, max_energy)

	hand.erase(instance)
	emit_signal("card_played", instance)

	# ★ 回声结算（必须在效果之前，让本张牌吃到本次连击的倍率）
	_current_play_context = {
		"verdict": echo.predict(instance.faction()),
		"old_streak": echo.streak,
		"isolation_before": isolation.value,
	}
	echo.on_card_played(instance.faction())
	emit_signal("echo_changed", echo.streak, echo.current_multiplier())

	# 被异化的牌额外增加隔离
	if instance.corrupted:
		isolation.add(1)
		emit_signal("isolation_changed", isolation.value)

	_resolve_effects(instance)

	# 归位
	if instance.data.purge_on_use:
		purged_card_ids.append(instance.data.id)
	if instance.data.exhaust:
		exhaust_pile.append(instance)
	else:
		discard_pile.append(instance)

	_emit_piles()
	emit_signal("hand_changed")
	_check_combat_over()
	_current_play_context.clear()
	return true


func _resolve_effects(instance: CardInstance) -> void:
	for e in instance.data.effects:
		var action: String = e.get("action", "")
		var value: int = e.get("value", 0)
		match action:
			"damage":
				_deal_player_attack(value)
			"damage_multi":
				var times: int = e.get("times", 1)
				for i in times:
					_deal_player_attack(value)
			"block":
				player_block += value
				emit_signal("player_stats_changed")
			"draw":
				_draw(value)
			"apply":
				_apply_to_target(e.get("status", ""), value)
			"self_damage":
				_take_damage_direct(value, instance.data.display_name)
			"heal":
				player_hp = mini(player_max_hp, player_hp + value)
				emit_signal("player_stats_changed")
			"gain_energy":
				energy += value
				emit_signal("energy_changed", energy, max_energy)
			"isolation":
				isolation.add(value)
				emit_signal("isolation_changed", isolation.value)
			"gain_status":
				_add_status(player_statuses, e.get("status", ""), value)
				emit_signal("player_stats_changed")
			"discard":
				for i in value:
					if hand.is_empty():
						break
					discard_pile.append(hand.pop_back())
				emit_signal("hand_changed")
			"enable_echo_storage":
				_echo_storage_limit = maxi(_echo_storage_limit, value)
			"store_echo":
				if echo.streak >= 2:
					_pending_echo_store_limit = maxi(_pending_echo_store_limit, value)
			"draw_if_stored":
				if _turn_started_with_stored:
					_draw(value)
			"draw_if_extend_once":
				if _current_play_context.get("verdict", "") == "extend" and not _extended_draw_used:
					_extended_draw_used = true
					_draw(value)
			"release_damage":
				var released := echo.streak
				if released > 0:
					_deal_player_attack(value * released)
				echo.reset_turn()
				emit_signal("echo_changed", echo.streak, echo.current_multiplier())
			"block_if_isolation":
				if int(_current_play_context.get("isolation_before", isolation.value)) >= int(e.get("threshold", 0)):
					player_block += value
					emit_signal("player_stats_changed")
			"damage_if_isolation":
				var base_damage := value
				if int(_current_play_context.get("isolation_before", isolation.value)) >= int(e.get("threshold", 0)):
					base_damage = int(e.get("high_value", value))
				_deal_player_attack(base_damage)
			"archive_hand_then_draw":
				# 暂存最右侧手牌，先从原抽牌堆抽牌，再把它放到抽牌堆顶。
				# 当前阶段保持纯数值原型；后续接卡牌选择器时只需替换选牌来源。
				var archived: CardInstance = hand.pop_back() if not hand.is_empty() else null
				_draw(value)
				if archived != null:
					draw_pile.append(archived)
					emit_signal("hand_changed")
					_emit_piles()
			"block_on_break":
				if _current_play_context.get("verdict", "") == "break":
					player_block += int(_current_play_context.get("old_streak", 0)) * value
					emit_signal("player_stats_changed")
			_:
				push_warning("[CombatManager] 未知效果: %s" % action)


# ================================================================ 伤害

## 结算攻击目标：优先用玩家指定的目标，目标无效时退回第一个存活敌人
func _resolve_target_index() -> int:
	if _current_target >= 0 and _current_target < enemies.size():
		if enemies[_current_target]["alive"]:
			return _current_target
	var alive := _alive_enemies()
	return alive[0] if not alive.is_empty() else -1


## 玩家攻击 → 敌人
func _deal_player_attack(base: int) -> void:
	var target_index := _resolve_target_index()
	if target_index < 0:
		return
	var enemy: Dictionary = enemies[target_index]

	var final_dmg := DamagePipeline.compute(
		base, player_statuses, enemy["statuses"], echo.current_multiplier()
	)
	var def_result := DamagePipeline.apply_defense(
		final_dmg, enemy["block"], enemy["statuses"].get("shield", 0)
	)
	enemy["block"] -= def_result["block_used"]
	if def_result["shield_used"] > 0:
		enemy["statuses"]["shield"] = enemy["statuses"].get("shield", 0) - def_result["shield_used"]

	enemy["hp"] -= def_result["through"]
	if enemy["hp"] <= 0:
		enemy["hp"] = 0
		enemy["alive"] = false

	emit_signal("damage_dealt", "你", enemy["name"], def_result["through"], def_result["block_used"])
	emit_signal("enemy_stats_changed", target_index)

	# 连击 ≥3 触发「深渊低语」
	if echo.should_whisper() and _cards_played_this_turn > 0:
		_draw(1)


## 敌人攻击 → 玩家
func enemy_attack_damage(enemy: Dictionary, base: int) -> int:
	return DamagePipeline.compute(
		base, enemy["statuses"], player_statuses, 1.0
	)


## 直接伤害（无视格挡，例如腐蚀、自伤）
func _take_damage_direct(amount: int, source: String) -> void:
	player_hp = maxi(0, player_hp - amount)
	emit_signal("damage_dealt", source, "你", amount, 0)
	emit_signal("player_stats_changed")


# ================================================================ 状态施加

## 玩家施加给敌人（框架分析 / 寄生孢子 / 深渊凝视）
func _apply_to_target(status: String, value: int) -> void:
	var target_index := _resolve_target_index()
	if target_index < 0:
		return
	var enemy: Dictionary = enemies[target_index]
	_add_status(enemy["statuses"], status, value)
	emit_signal("enemy_stats_changed", target_index)


static func _add_status(statuses: Dictionary, status: String, value: int) -> void:
	if status.is_empty() or value == 0:
		return
	if status == "strength" or status == "dexterity" or status == "shield":
		statuses[status] = statuses.get(status, 0) + value
	else:
		statuses[status] = statuses.get(status, 0) + value


# ================================================================ 敌人回合

func _enemy_turn() -> void:
	phase = Phase.ENEMY_TURN
	turn_number += 1
	emit_signal("turn_started", turn_number, false)

	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		if not enemy["alive"]:
			continue

		# 敌人回合开始：格挡清零 + 腐蚀结算
		enemy["block"] = 0
		if enemy["statuses"].get("poison", 0) > 0:
			var p: int = enemy["statuses"]["poison"]
			enemy["hp"] -= p
			if enemy["hp"] <= 0:
				enemy["hp"] = 0
				enemy["alive"] = false
			enemy["statuses"]["poison"] = p - 1
			if enemy["statuses"]["poison"] <= 0:
				enemy["statuses"].erase("poison")
			emit_signal("enemy_stats_changed", i)
			if not enemy["alive"]:
				continue

		var intent: Dictionary = enemy["data"].intent_at(enemy["intent_index"])
		enemy["intent_index"] += 1
		_execute_intent(i, enemy, intent)
		emit_signal("enemy_acted", i, intent)

		if _check_combat_over():
			return

	# 敌人减益倒计时
	for e in enemies:
		if not e["alive"]:
			continue
		for key in ["weak", "vulnerable"]:
			if e["statuses"].get(key, 0) > 0:
				e["statuses"][key] -= 1
				if e["statuses"][key] <= 0:
					e["statuses"].erase(key)

	_refresh_intents()
	_start_player_turn()


func _execute_intent(index: int, enemy: Dictionary, intent: Dictionary) -> void:
	var t: String = intent.get("type", "unknown")
	match t:
		"attack":
			var times: int = intent.get("times", 1)
			for i in times:
				_enemy_strike(enemy, intent.get("value", 0))
		"block":
			enemy["block"] += intent.get("value", 0)
			emit_signal("enemy_stats_changed", index)
		"attack_block":
			_enemy_strike(enemy, intent.get("value", 0))
			enemy["block"] += intent.get("block", 0)
			emit_signal("enemy_stats_changed", index)
		"debuff":
			_add_status(player_statuses, intent.get("status", ""), intent.get("value", 0))
			emit_signal("player_stats_changed")
		"buff":
			_add_status(enemy["statuses"], intent.get("status", ""), intent.get("value", 0))
			emit_signal("enemy_stats_changed", index)
		"unknown":
			pass


func _enemy_strike(enemy: Dictionary, base: int) -> void:
	var dmg := enemy_attack_damage(enemy, base)
	var res := DamagePipeline.apply_defense(dmg, player_block, player_statuses.get("shield", 0))
	player_block -= res["block_used"]
	if res["shield_used"] > 0:
		player_statuses["shield"] = player_statuses.get("shield", 0) - res["shield_used"]
	player_hp -= res["through"]
	if player_hp <= 0:
		player_hp = 0
	emit_signal("damage_dealt", enemy["name"], "你", res["through"], res["block_used"])
	emit_signal("player_stats_changed")


func _refresh_intents() -> void:
	emit_signal("enemy_intents_updated")


## 敌人下回合对玩家的预计伤害（用于 UI 显示「实际会掉多少血」）
func preview_incoming_damage(index: int) -> int:
	if index < 0 or index >= enemies.size():
		return 0
	var enemy: Dictionary = enemies[index]
	if not enemy["alive"]:
		return 0
	var intent: Dictionary = enemy["data"].intent_at(enemy["intent_index"])
	if intent.get("type", "") not in ["attack", "attack_block"]:
		return 0
	var times: int = intent.get("times", 1)
	return enemy_attack_damage(enemy, intent.get("value", 0)) * times


# ================================================================ 阈值效果

## 阈值 3「皮下蔓延」：手牌随机 1 张异化
func apply_stage_3() -> bool:
	var candidates: Array[CardInstance] = []
	for ci in hand:
		if ci.faction() != CardData.Faction.NEUTRAL and not ci.corrupted:
			candidates.append(ci)
	if candidates.is_empty():
		return false
	var pick: CardInstance = candidates[_rng.randi_range(0, candidates.size() - 1)]
	pick.corrupt()
	emit_signal("hand_changed")
	emit_signal("whisper", "「皮下蔓延」—— 你手上有一张牌变了。")
	return true


## 阈值 8「意识让渡」：随机弃掉 1 张手牌（你的手不听话了）
func apply_stage_8_discard() -> bool:
	if hand.is_empty():
		return false
	var pick: CardInstance = hand[_rng.randi_range(0, hand.size() - 1)]
	hand.erase(pick)
	discard_pile.append(pick)
	emit_signal("hand_changed")
	emit_signal("whisper", "「意识让渡」—— 你的手自己动了一下。")
	return true


## 每次隔离值跨越阈值时由外部调用
func on_isolation_threshold(value: int, stage_name: String) -> void:
	emit_signal("isolation_threshold", value, stage_name)
	if value == 3:
		apply_stage_3()


# ================================================================ 牌堆

func _draw(count: int) -> void:
	for i in count:
		if draw_pile.is_empty():
			_reshuffle()
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())
	emit_signal("hand_changed")
	_emit_piles()


## 仅在结束回合时检查；回合中可持有并打出超过此数量的手牌。
func has_hand_overflow() -> bool:
	return hand.size() > character_rules.end_turn_hand_limit


func overflow_discard_count() -> int:
	return maxi(0, hand.size() - character_rules.end_turn_hand_limit)


func discard_overflow_card(instance: CardInstance) -> bool:
	if not has_hand_overflow() or not hand.has(instance):
		return false
	hand.erase(instance)
	discard_pile.append(instance)
	emit_signal("hand_changed")
	_emit_piles()
	if not has_hand_overflow():
		emit_signal("overflow_resolved")
	return true


## 沈明每回合可以主动整理最多两张手牌；这不替代超限选择。
func discard_from_hand(instance: CardInstance) -> bool:
	if phase != Phase.PLAYER_TURN and phase != Phase.PLAYER_ACTING:
		return false
	if voluntary_discards_left <= 0 or not hand.has(instance):
		return false
	hand.erase(instance)
	discard_pile.append(instance)
	voluntary_discards_left -= 1
	emit_signal("hand_changed")
	_emit_piles()
	return true


func _reshuffle() -> void:
	if discard_pile.is_empty():
		return
	for c in discard_pile:
		draw_pile.append(c)
	discard_pile.clear()
	draw_pile.shuffle()


func _emit_piles() -> void:
	emit_signal("piles_changed", draw_pile.size(), discard_pile.size(), exhaust_pile.size())


## 清除已经不合法的手牌修饰（中立牌不该被异化）
func _clear_invalid_corruption() -> void:
	for ci in hand:
		if ci.corrupted and ci.faction() == CardData.Faction.NEUTRAL:
			ci.corrupted = false


# ================================================================ 胜负

func _alive_enemies() -> Array[int]:
	var result: Array[int] = []
	for i in enemies.size():
		if enemies[i]["alive"]:
			result.append(i)
	return result


func _check_combat_over() -> bool:
	if player_hp <= 0:
		phase = Phase.DEFEAT
		emit_signal("combat_ended", false)
		return true
	if _alive_enemies().is_empty():
		phase = Phase.VICTORY
		emit_signal("combat_ended", true)
		return true
	return false


func is_over() -> bool:
	return phase in [Phase.VICTORY, Phase.DEFEAT, Phase.ASSIMILATED]


# ================================================================ 查询

func total_block() -> int:
	return player_block


## 供 UI 使用：这张牌打出后，回声会怎么变化
## 返回 { "verdict": "extend"/"break"/"neutral"/"first", "streak": 结果连击数, "multiplier": 结果倍率 }
func echo_prediction(instance: CardInstance) -> Dictionary:
	var f := instance.faction()
	return {
		"verdict": echo.predict(f),
		"streak": echo.streak_if_played(f),
		"multiplier": echo.multiplier_if_played(f),
	}


## 供 UI 使用：要延续连击，下一张牌该出什么归属（-1 = 还没建立基准）
func required_faction() -> int:
	return echo.required_faction_for_extend()


## 玩家打出某张牌后的预计伤害（用于卡面显示「打出后造成 X」）
## target_index >= 0 时按该敌人计算（鼠标悬停到某个怪物上时用）
func preview_card_damage(instance: CardInstance, target_index: int = -1) -> int:
	var total := 0
	var mult := echo.multiplier_if_played(instance.faction())

	var idx := target_index
	if idx < 0 or idx >= enemies.size() or not enemies[idx]["alive"]:
		var alive := _alive_enemies()
		if alive.is_empty():
			return 0
		idx = alive[0]
	var enemy_statuses: Dictionary = enemies[idx]["statuses"]
	for e in instance.data.effects:
		if e.get("action", "") == "damage":
			total += DamagePipeline.compute(e.get("value", 0), player_statuses, enemy_statuses, mult)
		elif e.get("action", "") == "damage_multi":
			total += DamagePipeline.compute(
				e.get("value", 0), player_statuses, enemy_statuses, mult
			) * int(e.get("times", 1))
		elif e.get("action", "") == "damage_if_isolation":
			var base_damage := int(e.get("value", 0))
			if isolation.value >= int(e.get("threshold", 0)):
				base_damage = int(e.get("high_value", base_damage))
			total += DamagePipeline.compute(base_damage, player_statuses, enemy_statuses, mult)
		elif e.get("action", "") == "release_damage":
			total += DamagePipeline.compute(int(e.get("value", 0)) * echo.streak_if_played(instance.faction()), player_statuses, enemy_statuses, mult)
	return total
