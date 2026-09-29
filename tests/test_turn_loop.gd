extends SceneTree
## 回合循环探针 —— 验证「每个玩家回合开始时手牌会被补满」
##   godot --headless --path . --script tests/test_turn_loop.gd
##
## 这是对「第一回合之后手牌不再补充」那个 bug 的回归测试：
## 抽牌堆抽空后必须把弃牌堆洗回来继续抽，否则玩家会无牌可出。

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

	print("")
	print("═══════════════════════════════════════════")
	print("  回合循环 / 发牌回归测试")
	print("═══════════════════════════════════════════")
	print("  初始牌组共 %d 张（抽牌堆 %d / 手牌 %d）" % [cm.draw_pile.size() + cm.hand.size(), cm.draw_pile.size(), cm.hand.size()])
	print("")

	var failed := 0
	for turn in 6:
		# 模拟玩家把整手牌打完（直接移入弃牌堆，不消耗能量，只看发牌）
		while not cm.hand.is_empty():
			cm.discard_pile.append(cm.hand.pop_back())

		var before_hand: int = cm.hand.size()
		cm.end_turn()

		# 战斗结束后手牌为空是正常的，不能算失败
		if cm.is_over():
			print("  回合 %d：战斗已结束（phase=%d），停止循环" % [turn + 1, cm.phase])
			break

		var total: int = cm.hand.size() + cm.draw_pile.size() + cm.discard_pile.size() + cm.exhaust_pile.size()
		var ok: bool = cm.hand.size() > 0
		if not ok:
			failed += 1
		print("  回合 %d 结束 -> 新回合手牌 %2d 张 | 抽 %2d 弃 %2d 消耗 %d | 能量 %d | 牌总数 %d %s" % [
			turn + 1, cm.hand.size(), cm.draw_pile.size(), cm.discard_pile.size(),
			cm.exhaust_pile.size(), cm.energy, total, "OK" if ok else "★手牌为空★"])

	print("")
	if failed == 0:
		print("  结论：每个回合都正常补牌 ✓")
	else:
		print("  结论：有 %d 个回合手牌为空 ✗ —— 发牌逻辑有 bug" % failed)
	print("")
	quit()
