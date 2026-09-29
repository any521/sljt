extends SceneTree
## 无头逻辑测试 —— 运行方式：
##   godot --headless --path . --script tests/test_combat.gd
##
## 只测试纯逻辑层（DamagePipeline / EchoSystem / IsolationSystem / CombatManager），
## 不涉及任何 UI 或场景，保证规则正确性可以脱离画面独立验证。

var _passed: int = 0
var _failed: int = 0
var _current_section: String = ""
## 独立加载 CardDB 脚本（不用 autoload —— `--script` 模式下 autoload 不会注册）
var _db_inst: Node = null


func _init() -> void:
	_db_inst = _db()
	root.add_child(_db_inst)
	print("")
	print("═══════════════════════════════════════════")
	print("  《阿卡姆号》M0 战斗逻辑测试")
	print("═══════════════════════════════════════════")

	_section("伤害管线 DamagePipeline")
	test_damage_base()
	test_damage_strength()
	test_damage_weak()
	test_damage_vulnerable()
	test_damage_strength_times_vulnerable()
	test_damage_echo_multiplier()
	test_damage_full_stack()
	test_defense_absorption()

	_section("回声系统 EchoSystem")
	test_echo_single_card_no_combo()
	test_echo_alternating_builds()
	test_echo_same_faction_resets()
	test_echo_neutral_does_not_break()
	test_echo_multiplier_caps()
	test_echo_turn_reset()
	test_echo_streak_if_played()
	test_echo_predict_verdict()
	test_echo_required_faction()
	test_echo_multiplier_if_played()

	_section("隔离系统 IsolationSystem")
	test_isolation_accumulate()
	test_isolation_thresholds()
	test_isolation_assimilation()
	test_isolation_reduction()
	test_isolation_cost_modifier()

	_section("战斗管理器 CombatManager")
	test_combat_init()
	test_energy_spent()
	test_cannot_afford()
	test_too_many_cards()
	test_enemy_defeated()
	test_victory()
	test_defeat()
	test_poison_defeat_before_draw()
	test_assimilation_counts_as_victory()
	test_enemy_intent_cycle()
	test_enemy_block()
	test_poison_ticks()
	test_self_damage_card()
	test_corrupted_card_isolation()
	test_predicted_damage()

	print("")
	print("═══════════════════════════════════════════")
	if _failed == 0:
		print("  ✓ 全部通过：%d 项" % _passed)
	else:
		print("  ✗ 通过 %d 项 / 失败 %d 项" % [_passed, _failed])
	print("═══════════════════════════════════════════")
	print("")
	_db_inst.free()
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- 断言工具

func _section(title: String) -> void:
	_current_section = title
	print("")
	print("── %s ──" % title)


func _ok(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  ✓ %s" % label)
	else:
		_failed += 1
		print("  ✗ %s   <<< 失败" % label)


func _eq(actual, expected, label: String) -> void:
	if actual == expected:
		_passed += 1
		print("  ✓ %s" % label)
	else:
		_failed += 1
		print("  ✗ %s   期望 [%s] 实际 [%s]   <<< 失败" % [label, expected, actual])


# ---------------------------------------------------------------- 测试辅助

func _db() -> Node:
	var db = load("res://src/autoload/card_db.gd").new()
	db._build_cards()
	db._build_enemies()
	db._build_pools()
	return db


func _new_combat(enemy_ids: Array[String], seed_value: int = 12345) -> CombatManager:
	var cm := CombatManager.new(seed_value)
	var enemy_data_list: Array[EnemyData] = []
	for eid in enemy_ids:
		enemy_data_list.append(_db_inst.get_enemy(eid))
	cm.start_combat(_db_inst.build_starter_deck(), enemy_data_list)
	return cm


func _force_hand(cm: CombatManager, ids: Array[String]) -> void:
	cm.hand.clear()
	for id in ids:
		cm.hand.append(CardInstance.new(_db_inst.get_card(id)))


func _first_enemy_hp(cm: CombatManager) -> int:
	return cm.enemies[0]["hp"]


# ════════════════════════════════════════════════ 伤害管线

func test_damage_base() -> void:
	_eq(DamagePipeline.compute(6, {}, {}, 1.0), 6, "基础 6 伤害 → 6")


func test_damage_strength() -> void:
	_eq(DamagePipeline.compute(6, {"strength": 2}, {}, 1.0), 8, "6 + 力量2 → 8")


func test_damage_weak() -> void:
	_eq(DamagePipeline.compute(8, {"weak": 1}, {}, 1.0), 6, "8 伤害 + 虚弱 → floor(6.0) = 6")


func test_damage_vulnerable() -> void:
	_eq(DamagePipeline.compute(6, {}, {"vulnerable": 1}, 1.0), 9, "6 伤害 + 易伤 → 9")


func test_damage_strength_times_vulnerable() -> void:
	# (6+2) × 1.5 = 12 —— 力量与易伤是乘法叠加，这是爆发感来源
	_eq(DamagePipeline.compute(6, {"strength": 2}, {"vulnerable": 1}, 1.0), 12,
		"(6+2) × 易伤1.5 → 12（乘法叠加）")


func test_damage_echo_multiplier() -> void:
	_eq(DamagePipeline.compute(6, {}, {}, 1.5), 9, "6 伤害 × 回声1.5 → 9")


func test_damage_full_stack() -> void:
	# (12 + 2) × 0.75 (虚弱) × 1.5 (易伤) × 2.0 (回声5连) = 31.5 → 31
	_eq(DamagePipeline.compute(12, {"strength": 2, "weak": 1}, {"vulnerable": 1}, 2.0), 31,
		"完整链路 (12+2)×0.75×1.5×2.0 → 31")


func test_defense_absorption() -> void:
	var r1 := DamagePipeline.apply_defense(10, 4, 0)
	_eq(r1["through"], 6, "10 伤害 vs 4 格挡 → 穿透 6")
	_eq(r1["block_used"], 4, "  格挡消耗 4")
	var r2 := DamagePipeline.apply_defense(3, 10, 0)
	_eq(r2["through"], 0, "3 伤害 vs 10 格挡 → 全挡")
	var r3 := DamagePipeline.apply_defense(10, 2, 3)
	_eq(r3["through"], 5, "10 伤害 vs 护盾3+格挡2 → 穿透 5")


# ════════════════════════════════════════════════ 回声系统

func _echo() -> EchoSystem:
	return EchoSystem.new()


func test_echo_single_card_no_combo() -> void:
	var e := _echo()
	var triggered := e.on_card_played(CardData.Faction.PROTOCOL)
	_ok(not triggered, "第一张牌不触发连击")
	_eq(e.streak, 0, "  连击数 0")
	_eq(e.current_multiplier(), 1.0, "  倍率 1.0")


func test_echo_alternating_builds() -> void:
	var e := _echo()
	e.on_card_played(CardData.Faction.PROTOCOL)
	e.on_card_played(CardData.Faction.MUTATION)
	_eq(e.streak, 1, "规程→变异 → 连击 1")
	e.on_card_played(CardData.Faction.PROTOCOL)
	_eq(e.streak, 2, "→规程 → 连击 2")
	_eq(e.current_multiplier(), 1.30, "  倍率 1.30")
	e.on_card_played(CardData.Faction.MUTATION)
	_eq(e.streak, 3, "→变异 → 连击 3")
	_eq(e.current_multiplier(), 1.50, "  倍率 1.50")


func test_echo_same_faction_resets() -> void:
	var e := _echo()
	e.on_card_played(CardData.Faction.PROTOCOL)
	e.on_card_played(CardData.Faction.MUTATION)
	e.on_card_played(CardData.Faction.PROTOCOL)
	_eq(e.streak, 2, "连击 2")
	e.on_card_played(CardData.Faction.PROTOCOL)
	_eq(e.streak, 0, "打出同归属 → 连击清零")
	_eq(e.current_multiplier(), 1.0, "  倍率回到 1.0")


func test_echo_neutral_does_not_break() -> void:
	var e := _echo()
	e.on_card_played(CardData.Faction.PROTOCOL)
	e.on_card_played(CardData.Faction.MUTATION)
	_eq(e.streak, 1, "连击 1")
	e.on_card_played(CardData.Faction.NEUTRAL)
	_eq(e.streak, 1, "中立牌不打断连击")
	e.on_card_played(CardData.Faction.PROTOCOL)
	_eq(e.streak, 2, "  之后仍可继续交替 → 连击 2")


func test_echo_multiplier_caps() -> void:
	var e := _echo()
	var factions := [CardData.Faction.PROTOCOL, CardData.Faction.MUTATION]
	for i in 12:
		e.on_card_played(factions[i % 2])
	_eq(e.current_multiplier(), 2.00, "连击超过 5 → 倍率封顶 2.0")
	_ok(e.streak >= 5, "  连击数继续累加（用于其他效果）")


func test_echo_turn_reset() -> void:
	var e := _echo()
	e.on_card_played(CardData.Faction.PROTOCOL)
	e.on_card_played(CardData.Faction.MUTATION)
	e.on_card_played(CardData.Faction.PROTOCOL)
	_eq(e.streak, 2, "回合结束前连击 2")
	e.reset_turn()
	_eq(e.streak, 0, "回合结束 → 连击清零")


# —— 预测 API（UI 的「下一张出什么」提示与卡面预测标记依赖它们）——

func test_echo_streak_if_played() -> void:
	var e := _echo()
	_eq(e.streak_if_played(CardData.Faction.PROTOCOL), 0,
		"空场打出第一张 → 预测连击 0（只建立基准，不加连击）")
	e.on_card_played(CardData.Faction.PROTOCOL)
	_eq(e.streak_if_played(CardData.Faction.MUTATION), 1,
		"上一张规程 → 出变异预测连击 1")
	_eq(e.streak_if_played(CardData.Faction.PROTOCOL), 0,
		"上一张规程 → 再出规程预测归零")
	_eq(e.streak_if_played(CardData.Faction.NEUTRAL), 0,
		"中立牌不改变连击数")
	e.on_card_played(CardData.Faction.MUTATION)
	e.on_card_played(CardData.Faction.PROTOCOL)
	_eq(e.streak, 2, "  当前连击 2")
	_eq(e.streak_if_played(CardData.Faction.MUTATION), 3,
		"  出变异 → 预测连击 3")
	_eq(e.streak_if_played(CardData.Faction.NEUTRAL), 2,
		"  中立 → 预测连击保持 2")


func test_echo_predict_verdict() -> void:
	var e := _echo()
	_eq(e.predict(CardData.Faction.PROTOCOL), "first", "空场 → first（建立基准）")
	_eq(e.predict(CardData.Faction.NEUTRAL), "neutral", "中立 → neutral")
	e.on_card_played(CardData.Faction.PROTOCOL)
	_eq(e.predict(CardData.Faction.MUTATION), "extend", "上一张规程 + 出变异 → extend")
	_eq(e.predict(CardData.Faction.PROTOCOL), "break", "上一张规程 + 再出规程 → break")
	_eq(e.predict(CardData.Faction.NEUTRAL), "neutral", "中立永不打断")


func test_echo_required_faction() -> void:
	var e := _echo()
	_eq(e.required_faction_for_extend(), -1, "未建立基准时返回 -1")
	e.on_card_played(CardData.Faction.PROTOCOL)
	_eq(e.required_faction_for_extend(), CardData.Faction.MUTATION,
		"上一张规程 → 需要变异才能延续")
	e.on_card_played(CardData.Faction.MUTATION)
	_eq(e.required_faction_for_extend(), CardData.Faction.PROTOCOL,
		"上一张变异 → 需要规程才能延续")


func test_echo_multiplier_if_played() -> void:
	var e := _echo()
	e.on_card_played(CardData.Faction.PROTOCOL)
	e.on_card_played(CardData.Faction.MUTATION)
	e.on_card_played(CardData.Faction.PROTOCOL)
	_eq(e.streak, 2, "当前连击 2（倍率 1.30）")
	_eq(e.multiplier_if_played(CardData.Faction.MUTATION), 1.50,
		"出变异 → 连击 3 → 倍率 1.50")
	_eq(e.multiplier_if_played(CardData.Faction.PROTOCOL), 1.00,
		"出规程 → 打断 → 倍率 1.00")
	_eq(e.multiplier_if_played(CardData.Faction.NEUTRAL), 1.30,
		"中立 → 连击不变 → 倍率 1.30")


# ════════════════════════════════════════════════ 隔离系统

func test_isolation_accumulate() -> void:
	var iso := IsolationSystem.new()
	iso.add(1)
	iso.add(1)
	_eq(iso.value, 2, "累积 → 2")
	_eq(iso.stage_name(), "正常", "  阶段：正常")


func test_isolation_thresholds() -> void:
	var iso := IsolationSystem.new()
	var reached: Array[int] = []
	iso.threshold_reached.connect(func(v, n): reached.append(v))
	iso.add(3)
	_eq(reached, [3], "到 3 → 触发「皮下蔓延」")
	_eq(iso.stage_name(), "皮下蔓延", "  阶段名正确")
	iso.add(3)
	_eq(reached, [3, 6], "到 6 → 触发「组织共生」")
	iso.add(2)
	_eq(reached, [3, 6, 8], "到 8 → 触发「意识让渡」")


func test_isolation_assimilation() -> void:
	var iso := IsolationSystem.new()
	var fired := [false]
	iso.assimilated.connect(func(): fired[0] = true)
	iso.add(10)
	_eq(iso.value, 10, "到 10 → 同化")
	_ok(fired[0], "  同化信号已发出")
	_ok(iso.is_assimilated(), "  is_assimilated() = true")
	iso.add(5)
	_eq(iso.value, 10, "  超过上限被钳制在 10")


func test_isolation_reduction() -> void:
	var iso := IsolationSystem.new()
	iso.add(5)
	iso.add(-2)
	_eq(iso.value, 3, "逻辑锁 −2 → 3")
	iso.add(-10)
	_eq(iso.value, 0, "  下限钳制在 0")


func test_isolation_cost_modifier() -> void:
	var iso := IsolationSystem.new()
	_eq(iso.cost_modifier_for(CardData.Faction.MUTATION), 0, "低隔离：变异牌无费用修正")
	iso.add(8)
	_eq(iso.cost_modifier_for(CardData.Faction.MUTATION), -1,
		"阈值 8：变异牌费用 −1")
	_eq(iso.cost_modifier_for(CardData.Faction.PROTOCOL), 0,
		"  规程牌不受影响")


# ════════════════════════════════════════════════ 战斗管理器

func test_combat_init() -> void:
	var cm := _new_combat(["lurker"])
	_eq(cm.player_hp, 70, "初始生命 70")
	_eq(cm.energy, 3, "初始能量 3")
	_eq(cm.hand.size(), 5, "起手抽 5 张")
	_eq(cm.draw_pile.size(), 5, "抽牌堆剩余 5 张（共 10 张）")
	_eq(cm.discard_pile.size(), 0, "弃牌堆为空")
	_eq(cm.enemies.size(), 1, "敌人数量 1")
	_eq(_first_enemy_hp(cm), 30, "潜伏者生命 30")
	_eq(cm.isolation.value, 0, "隔离值 0")


func test_energy_spent() -> void:
	var cm := _new_combat(["lurker"])
	_force_hand(cm, ["calibrate_shot", "precision_strike"])
	var card: CardInstance = cm.hand[1]
	_eq(card.effective_cost(cm.isolation), 2, "精准打击费用 2")
	cm.play_card(card)
	_eq(cm.energy, 1, "打出后剩余能量 1")
	_eq(_first_enemy_hp(cm), 30 - 12, "造成 12 伤害 → 敌人 18")


func test_cannot_afford() -> void:
	var cm := _new_combat(["lurker"])
	cm.energy = 1
	_force_hand(cm, ["precision_strike"])
	_ok(not cm.can_play(cm.hand[0]), "能量 1 无法打出 2 费牌")
	_ok(not cm.play_card(cm.hand[0]), "  play_card 返回 false")
	_eq(_first_enemy_hp(cm), 30, "  敌人未受伤")


func test_too_many_cards() -> void:
	var cm := _new_combat(["lurker"])
	# 塞满抽牌堆（20 张），手牌留空，验证抽 12 张只会拿到 10 张
	cm.hand.clear()
	cm.draw_pile.clear()
	cm.discard_pile.clear()
	for i in 20:
		cm.draw_pile.append(CardInstance.new(_db_inst.get_card("calibrate_shot")))
	cm._draw(12)
	_eq(cm.hand.size(), 10, "手牌上限 10，超出不抽")
	_eq(cm.draw_pile.size(), 10, "  只抽走 10 张（12 张请求被上限截断）")


func test_enemy_defeated() -> void:
	var cm := _new_combat(["lurker"])
	_force_hand(cm, ["precision_strike", "precision_strike", "precision_strike"])
	cm.energy = 9
	cm.play_card(cm.hand[0])
	cm.play_card(cm.hand[0])
	_eq(_first_enemy_hp(cm), 6, "两次 12 伤害 → 敌人 6")
	cm.play_card(cm.hand[0])
	_ok(not cm.enemies[0]["alive"], "第三次击杀 → 敌人死亡")


func test_victory() -> void:
	var cm := _new_combat(["lurker"])
	var won := [false]
	cm.combat_ended.connect(func(v): won[0] = v)
	_force_hand(cm, ["precision_strike", "precision_strike", "precision_strike"])
	cm.energy = 9
	for i in 3:
		cm.play_card(cm.hand[0])
	_ok(won[0], "全部敌人死亡 → 胜利信号")
	_eq(cm.phase, CombatManager.Phase.VICTORY, "  阶段 = VICTORY")
	_ok(cm.is_over(), "  is_over() = true")


func test_defeat() -> void:
	var cm := _new_combat(["lurker"])
	var ended := [false]
	cm.combat_ended.connect(func(v): ended[0] = true)
	cm.player_hp = 5
	cm.end_turn()   # 敌人攻击 6 → 玩家死亡
	_ok(ended[0], "生命归零 → 战斗结束信号")
	_eq(cm.phase, CombatManager.Phase.DEFEAT, "  阶段 = DEFEAT")


func test_poison_defeat_before_draw() -> void:
	var cm := _new_combat(["sentry"])
	cm.player_hp = 1
	cm.player_statuses["poison"] = 2
	cm.end_turn() # 机兵行动后进入新回合，腐蚀应在抽牌前致死
	_eq(cm.player_hp, 0, "回合开始腐蚀致死 → 生命钳制为 0")
	_eq(cm.phase, CombatManager.Phase.DEFEAT, "  腐蚀致死立即进入 DEFEAT")
	_ok(cm.is_over(), "  不会进入可操作的尸体回合")


func test_assimilation_counts_as_victory() -> void:
	var cm := _new_combat(["lurker"])
	var result := [false]
	cm.combat_ended.connect(func(victory): result[0] = victory)
	cm.isolation.add(10)
	cm.end_turn()
	_eq(cm.phase, CombatManager.Phase.ASSIMILATED, "隔离 10 → 特殊结局 ASSIMILATED")
	_ok(result[0], "  同化按规则上报为胜利")


func test_enemy_intent_cycle() -> void:
	var cm := _new_combat(["lurker"])
	var ed: EnemyData = cm.enemies[0]["data"]
	_eq(ed.intent_at(0)["value"], 6, "意图 1：攻击 6")
	_eq(ed.intent_at(1)["type"], "debuff", "意图 2：减益（腐蚀）")
	_eq(ed.intent_at(2)["value"], 9, "意图 3：攻击 9")
	_eq(ed.intent_at(3)["value"], 6, "意图 4：循环回攻击 6")


func test_enemy_block() -> void:
	var cm := _new_combat(["sentry"])
	# 机兵意图：攻击5×2 → 格挡8 → 攻击8+格挡5
	cm.end_turn()   # 回合 1：攻击 5×2
	cm.end_turn()   # 回合 2：获得格挡 8
	_eq(cm.enemies[0]["block"], 8, "机兵获得 8 点格挡")
	_force_hand(cm, ["precision_strike"])
	cm.play_card(cm.hand[0])
	_eq(cm.enemies[0]["hp"], 42 - 4, "12 伤害 vs 8 格挡 → 掉 4 血")
	_eq(cm.enemies[0]["block"], 0, "  格挡被消耗完")


func test_poison_ticks() -> void:
	var cm := _new_combat(["lurker"])
	_force_hand(cm, ["parasite_spore"])
	cm.play_card(cm.hand[0])
	_eq(cm.enemies[0]["hp"], 30 - 4, "孢子造成 4 伤害 → 26")
	_eq(cm.enemies[0]["statuses"]["poison"], 3, "  施加 3 层腐蚀")
	# 回合结束 → 敌人回合：腐蚀先结算 3，然后敌人攻击玩家
	cm.end_turn()
	_eq(cm.enemies[0]["hp"], 26 - 3, "腐蚀结算 3 → 23")
	_eq(cm.enemies[0]["statuses"]["poison"], 2, "  腐蚀层数 3 → 2")


func test_self_damage_card() -> void:
	var cm := _new_combat(["lurker"])
	_force_hand(cm, ["sacrifice_blood"])
	cm.play_card(cm.hand[0])
	_eq(cm.player_hp, 70 - 3, "献祭之血：自身失去 3 → 67")
	_eq(cm.player_statuses["strength"], 2, "  获得 2 点力量")
	_eq(cm.isolation.value, 1, "  隔离值 +1")


func test_corrupted_card_isolation() -> void:
	var cm := _new_combat(["lurker"])
	_force_hand(cm, ["calibrate_shot"])
	var card: CardInstance = cm.hand[0]
	_ok(card.corrupt(), "卡牌可被异化")
	_ok(card.corrupted, "  corrupted 标记生效")
	_eq(card.data.cost, 1, "  原始费用 1")
	_eq(card.effective_cost(cm.isolation), 0, "  异化后费用 1 → 0")
	cm.play_card(card)
	_eq(cm.isolation.value, 1, "  打出异化牌 → 隔离值 +1")


func test_predicted_damage() -> void:
	var cm := _new_combat(["lurker"])
	_force_hand(cm, ["calibrate_shot"])
	var dmg := cm.preview_card_damage(cm.hand[0])
	_eq(dmg, 6, "首张校准射击预计 6 伤害")
	# 打出后打变异牌，连击 1 → 倍率 1.15
	cm.play_card(cm.hand[0])
	_force_hand(cm, ["lacerate"])
	var dmg2 := cm.preview_card_damage(cm.hand[0])
	_eq(dmg2, 8, "连击1 的撕裂：floor(7 × 1.15) = 8")
