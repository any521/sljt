extends SceneTree
## 回合循环探针 —— 首回合 5 张，后续每回合新增 3 张且保留旧牌
##   godot --headless --path . --script tests/test_turn_loop.gd
##
## 同时覆盖抽牌堆耗尽后将弃牌堆重洗的情况。

var _db_inst: Node = null


func _init() -> void:
	_db_inst = load("res://src/autoload/card_db.gd").new()
	_db_inst._build_cards()
	_db_inst._build_enemies()
	_db_inst._build_pools()
	root.add_child(_db_inst)

	var eds: Array[EnemyData] = [_db_inst.get_enemy("lurker"), _db_inst.get_enemy("sentry")]
	var cm: CombatManager = CombatManager.new(20240927)
	cm.start_combat(_db_inst.build_starter_deck(), eds)
	cm.player_hp = 999

	print("")
	print("═══════════════════════════════════════════")
	print("  回合循环 / 发牌回归测试")
	print("═══════════════════════════════════════════")
	print("  初始牌组共 %d 张（抽牌堆 %d / 手牌 %d）" % [cm.draw_pile.size() + cm.hand.size(), cm.draw_pile.size(), cm.hand.size()])
	print("")

	var failed := 0
	for turn in 6:
		var keep_count: int = 2 + turn % 4
		# 模拟部分牌已经打出：只有这些牌进入弃牌堆，其余实例应跨回合保留。
		while cm.hand.size() > keep_count:
			cm.discard_pile.append(cm.hand.pop_back())
		var retained := cm.hand.duplicate()
		cm.end_turn()

		# 战斗结束后手牌为空是正常的，不能算失败
		if cm.is_over():
			print("  回合 %d：战斗已结束（phase=%d），停止循环" % [turn + 1, cm.phase])
			break

		var total: int = cm.hand.size() + cm.draw_pile.size() + cm.discard_pile.size() + cm.exhaust_pile.size()
		var ok: bool = cm.hand.size() == keep_count + 3 and retained.all(func(card): return cm.hand.has(card))
		if not ok:
			failed += 1
		print("  回合 %d：留 %d 补 %d → 手牌 %d | 抽牌堆 %d 弃牌堆 %d 消耗 %d | 能量 %d | 总数 %d %s" % [
			turn + 1, keep_count, 3, cm.hand.size(), cm.draw_pile.size(), cm.discard_pile.size(),
			cm.exhaust_pile.size(), cm.energy, total, "OK" if ok else "★手牌为空★"])

	print("")
	if failed == 0:
		print("  结论：留牌不被弃掉，后续每回合新增 3 张 ✓")
	else:
		print("  结论：有 %d 个回合手牌为空 ✗ —— 发牌逻辑有 bug" % failed)
	print("")
	quit(0 if failed == 0 else 1)
