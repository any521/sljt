extends Node2D
## Chapter flow: map -> room -> battle/reward -> map.

@onready var view: Control = $CombatView
@onready var map_view: Control = $TowerMap
@onready var choice_panel: Control = $RoomChoicePanel
@onready var card_list_panel: Control = $CardListPanel
@onready var exchange_panel: Control = $ExchangePanel
@onready var character_panel: Control = $CharacterSelectPanel
@onready var room_transition: Control = $RoomTransition

@onready var _db = get_node("/root/CardDB")
var run: RunState
var _rng := RandomNumberGenerator.new()
var _mode := ""
var _reward_ids: Array[String] = []
var _exchange_offers: Array[String] = []
var _shop_offer_ids: Array[String] = []
var _event_id := ""
var _transitioning := false
var _battle_map_open := false

const SHOP_CARD_PRICE := 90
const SHOP_REMOVE_BASE := 75
const SHOP_REMOVE_STEP := 30

func _ready() -> void:
	map_view.room_chosen.connect(_on_room_chosen)
	map_view.close_requested.connect(_close_battle_map)
	choice_panel.choice_made.connect(_on_choice)
	exchange_panel.choice_made.connect(_on_choice)
	card_list_panel.option_chosen.connect(_on_card_list_choice)
	character_panel.character_chosen.connect(start_new_run)
	view.battle_finished.connect(_on_battle_finished)
	view.map_requested.connect(_open_battle_map)
	_show_character_select()

func _show_character_select() -> void:
	_mode = "character_select"
	view.hide()
	view.process_mode = Node.PROCESS_MODE_DISABLED
	map_view.hide()
	map_view.z_index = 0
	_battle_map_open = false
	choice_panel.hide()
	card_list_panel.hide()
	exchange_panel.hide()
	character_panel.show()

func start_new_run(character_id: String = CharacterRules.SHEN_MING) -> void:
	if _transitioning:
		return
	_rng.randomize()
	run = RunState.new(_rng.randi(), _db.build_starter_deck(), _db, character_id)
	_rng.seed = run.seed_value
	_transitioning = true
	await room_transition.cover()
	character_panel.hide()
	_show_map()
	await room_transition.reveal()
	_transitioning = false

func _show_map() -> void:
	_mode = "map"
	_battle_map_open = false
	view.hide()
	view.process_mode = Node.PROCESS_MODE_DISABLED
	choice_panel.hide()
	card_list_panel.hide()
	exchange_panel.hide()
	character_panel.hide()
	map_view.z_index = 0
	map_view.show_run(run, false)
	map_view.show()


func _return_to_map() -> void:
	if _transitioning:
		return
	_transitioning = true
	await room_transition.cover()
	_show_map()
	await room_transition.reveal()
	_transitioning = false


func _open_battle_map() -> void:
	if _mode != "battle" or _transitioning or _battle_map_open:
		return
	_transitioning = true
	await room_transition.cover()
	_battle_map_open = true
	view.process_mode = Node.PROCESS_MODE_DISABLED
	map_view.z_index = 200
	map_view.show_run(run, true)
	map_view.show()
	await room_transition.reveal()
	_transitioning = false


func _close_battle_map() -> void:
	if _mode != "battle" or _transitioning or not _battle_map_open:
		return
	_transitioning = true
	await room_transition.cover()
	map_view.hide()
	map_view.z_index = 0
	_battle_map_open = false
	view.process_mode = Node.PROCESS_MODE_INHERIT
	await room_transition.reveal()
	_transitioning = false

func _on_room_chosen(floor_index: int, lane: int) -> void:
	if _mode != "map": return
	var room := run.choose_room(floor_index, lane)
	if room.is_empty(): return
	map_view.hide()
	match room.type:
		"battle", "elite", "boss": _enter_battle(room.type)
		"medicine":
			_mode = "medicine"
			choice_panel.present("药品柜", "在废弃舱室里发现了尚可使用的医疗用品。", ["使用药剂：恢复 8 点生命", "收下应急医疗卡", "离开"], [], ["room:medicine", "emergency_medkit", ""])
		"tools":
			_mode = "tools"
			choice_panel.present("工具间", "工作台上还有几件能用的工具。", ["调整一张卡牌（升级）", "取走绝缘屏障卡", "离开"], [], ["room:tools", "insulation", ""])
		"maintenance":
			_mode = "maintenance"
			choice_panel.present("维护台", "选择一张攻击牌，永久提高它的基础伤害。", ["强化一张攻击牌：伤害 +3", "离开"], [], ["room:maintenance", ""])
		"exchange":
			_show_exchange()
		"shop":
			_show_shop(true)
		"rest":
			_mode = "rest"
			choice_panel.present("休整站", "安全门短暂关闭。选择恢复体力，或调整卡组。", ["恢复 14 点生命", "升级一张卡牌", "继续前进"], [], ["room:rest", "room:maintenance", ""])
		_:
			_show_event()

func _enter_battle(kind: String) -> void:
	_mode = "battle"
	_battle_map_open = false
	map_view.hide()
	map_view.z_index = 0
	var enemies: Array[EnemyData] = []
	match kind:
		"boss": enemies.append(_db.get_enemy("lab_core"))
		"elite": enemies.append(_db.get_enemy("guardian"))
		_:
			enemies.append(_db.get_enemy("lurker" if _rng.randi_range(0, 1) == 0 else "sentry"))
	choice_panel.hide()
	exchange_panel.hide()
	view.show()
	view.process_mode = Node.PROCESS_MODE_INHERIT
	view.begin_run_battle(run.deck, enemies, run.hp, run.character_rules, run.trinkets, run.isolation)

func _on_battle_finished(victory: bool) -> void:
	if _mode != "battle" or _transitioning: return
	_transitioning = true
	_mode = "transition"
	view.process_mode = Node.PROCESS_MODE_DISABLED
	await room_transition.cover()
	_settle_battle(victory)
	await room_transition.reveal()
	_transitioning = false

func _settle_battle(victory: bool) -> void:
	run.hp = view.combat.player_hp
	run.isolation = view.combat.isolation.value
	run.purge_used_cards(view.combat.purged_card_ids)
	view.hide()
	view.process_mode = Node.PROCESS_MODE_DISABLED
	if not victory:
		_mode = "defeat"
		choice_panel.present("行动中止", "%s未能抵达生物实验室。" % run.character_rules.display_name, ["重新开始"])
		return
	if run.selected_room.type == "boss":
		run.completed = true
		_mode = "complete"
		choice_panel.present("抵达生物实验室", "已突破实验室入口。当前章节完成。", ["重新开始"])
		return
	run.battles_won += 1
	run.gold += 35 if run.selected_room.type == "elite" else 20
	if run.trinkets.has(TrinketCatalog.FIELD_DRESSING): run.heal(4)
	# Ordinary fights do not flood the deck: only every second win offers cards.
	if run.selected_room.type == "elite" or run.battles_won % 2 == 0:
		_show_card_reward("战斗收获", "从残骸中选一张卡，也可以只带走金币。")
	else:
		_show_map()

func _show_card_reward(title_text: String, body_text: String) -> void:
	_mode = "reward"
	_reward_ids.clear()
	var pool: Array[String] = _db.reward_pool.duplicate()
	while _reward_ids.size() < 3 and not pool.is_empty():
		var index := _rng.randi_range(0, pool.size() - 1)
		_reward_ids.append(pool.pop_at(index))
	var offered: Array[CardData] = []
	var indexes: Array[int] = []
	for id in _reward_ids:
		indexes.append(offered.size())
		offered.append(_db.get_card(id))
	choice_panel.hide()
	card_list_panel.present(title_text, body_text, offered, indexes, "不取卡，继续前进")

func _show_exchange() -> void:
	_mode = "exchange"
	_exchange_offers.clear()
	var pool: Array[String] = _db.reward_pool.duplicate()
	for i in 2:
		_exchange_offers.append(pool.pop_at(_rng.randi_range(0, pool.size() - 1)))
	var shot_count := 0
	var shield_count := 0
	for card in run.deck:
		if card.id == "calibrate_shot": shot_count += 1
		elif card.id == "force_shield": shield_count += 1
	choice_panel.hide()
	card_list_panel.hide()
	var sources: Array[CardData] = [_db.get_card("calibrate_shot"), _db.get_card("force_shield")]
	var targets: Array[CardData] = [_db.get_card(_exchange_offers[0]), _db.get_card(_exchange_offers[1])]
	var owned_counts: Array[int] = [shot_count, shield_count]
	exchange_panel.present(sources, targets, owned_counts)

func _show_shop(refresh_stock: bool = false) -> void:
	_mode = "shop"
	card_list_panel.hide()
	exchange_panel.hide()
	if refresh_stock:
		_shop_offer_ids.clear()
		var pool: Array[String] = _db.reward_pool.duplicate()
		while _shop_offer_ids.size() < 3 and not pool.is_empty():
			_shop_offer_ids.append(pool.pop_at(_rng.randi_range(0, pool.size() - 1)))
	choice_panel.present("小周的补给终端", "库存有限。当前金币 %d；战斗可获得金币。" % run.gold,
		["购买卡牌 · 每张 %d 金币" % SHOP_CARD_PRICE, "移除一张卡 · %d 金币" % (SHOP_REMOVE_BASE + run.remove_count * SHOP_REMOVE_STEP), "购买饰品 · 永久生效", "离开商店"],
		[_shop_offer_ids.is_empty() or run.gold < SHOP_CARD_PRICE, run.gold < SHOP_REMOVE_BASE + run.remove_count * SHOP_REMOVE_STEP or run.deck.size() <= 1, false, false],
		["room:shop", "room:tools", "trinket:spare_capacitor", ""])

func _show_shop_cards() -> void:
	_mode = "shop_cards"
	choice_panel.hide()
	var offered: Array[CardData] = []
	var indexes: Array[int] = []
	var captions: Array[String] = []
	for id in _shop_offer_ids:
		indexes.append(offered.size())
		offered.append(_db.get_card(id))
		captions.append("购买 · %d 金币" % SHOP_CARD_PRICE)
	card_list_panel.present("购买卡牌", "当前金币 %d · 选择卡牌加入卡组" % run.gold, offered, indexes, "返回商店", captions)

func _show_shop_remove() -> void:
	_mode = "shop_remove"
	choice_panel.hide()
	var indexes: Array[int] = []
	var captions: Array[String] = []
	for i in run.deck.size():
		indexes.append(i)
		captions.append("移除 · %d 金币" % (SHOP_REMOVE_BASE + run.remove_count * SHOP_REMOVE_STEP))
	card_list_panel.present("移除卡牌", "从卡组永久移除一张牌。当前金币 %d。" % run.gold, run.deck, indexes, "返回商店", captions)

func _show_shop_trinkets() -> void:
	_mode = "shop_trinkets"
	var options: Array[String] = []
	var disabled: Array[bool] = []
	var icons: Array[String] = []
	for id in TrinketCatalog.IDS:
		var item := TrinketCatalog.info(id)
		options.append("%s · %d 金币 · %s" % [item.name, item.price, item.description])
		disabled.append(run.trinkets.has(id) or run.gold < item.price)
		icons.append("trinket:" + id)
	options.append("返回商店")
	icons.append("")
	choice_panel.present("购买饰品", "永久生效，当前金币 %d。已拥有的饰品不可重复购买。" % run.gold, options, disabled, icons)

func _show_event() -> void:
	_mode = "event"
	_event_id = ["sample", "locker", "signal"][_rng.randi_range(0, 2)]
	match _event_id:
		"sample":
			choice_panel.present("破裂的样本箱", "宋梅留下的记录警告：舱内孢子会伤人。生命 %d / 70 · 金币 %d" % [run.hp, run.gold], [
				"失去最大生命的 12%，取得陶瓷护板", "冒险搜刮：失去 5 生命，获得 35 金币", "封门离开"],
				[run.hp <= 9 or run.trinkets.has(TrinketCatalog.CERAMIC_PLATE), run.hp <= 5, false],
				["trinket:ceramic_plate", "room:shop", ""])
		"locker":
			choice_panel.present("老吴的工具柜", "门锁坏了，老吴的超频程序还在里面。生命 %d / 70 · 金币 %d" % [run.hp, run.gold], [
				"支付 30 金币，取得超频运转", "拆取零件：失去 4 生命，获得 30 金币", "离开"],
				[run.gold < 30, run.hp <= 4, false], ["overclock", "room:tools", ""])
		_:
			choice_panel.present("通讯中继残片", "小周的中继器还能回收。生命 %d / 70 · 金币 %d" % [run.hp, run.gold], [
				"强行拆解：失去 8% 最大生命，获得 45 金币", "支付 25 金币，恢复 12 生命", "继续前进"],
				[run.hp <= 6, run.gold < 25, false], ["room:exchange", "room:medicine", ""])

func _resolve_event(index: int) -> void:
	match _event_id:
		"sample":
			if index == 0 and run.hp > 9 and run.add_trinket(TrinketCatalog.CERAMIC_PLATE): run.lose_hp_percent(0.12)
			elif index == 1 and run.hp > 5:
				run.hp -= 5
				run.gold += 35
		"locker":
			if index == 0 and run.spend_gold(30): run.add_card(_db.get_card("overclock"))
			elif index == 1 and run.hp > 4:
				run.hp -= 4
				run.gold += 30
		"signal":
			if index == 0 and run.hp > 6:
				run.lose_hp_percent(0.08)
				run.gold += 45
			elif index == 1 and run.spend_gold(25): run.heal(12)
	await _return_to_map()

func _show_upgrade_choices() -> void:
	_mode = "upgrade"
	var indexes: Array[int] = []
	for i in run.deck.size():
		if run.deck[i].upgraded or not _db.cards.has(run.deck[i].id + "_plus"): continue
		indexes.append(i)
	if indexes.is_empty():
		_mode = "no_cards"
		choice_panel.present("调整卡牌", "当前卡组没有可升级的卡牌。", ["继续前进"])
	else:
		choice_panel.hide()
		card_list_panel.present("调整卡牌", "选择一张卡牌升级。", run.deck, indexes)

func _show_maintenance_choices() -> void:
	_mode = "maintain_card"
	var indexes: Array[int] = []
	for i in run.deck.size():
		if run.deck[i].can_maintain_damage(): indexes.append(i)
	if indexes.is_empty():
		_mode = "no_cards"
		choice_panel.present("维护台", "当前没有可继续强化的攻击牌。", ["继续前进"])
	else:
		choice_panel.hide()
		card_list_panel.present("维护台", "选择一张攻击牌：本次基础伤害 +3（每张最多强化两次）。", run.deck, indexes)

func _on_card_list_choice(index: int) -> void:
	match _mode:
		"upgrade":
			if index >= 0: run.upgrade_at(index)
			await _return_to_map()
		"maintain_card":
			if index >= 0: run.maintain_damage_at(index)
			await _return_to_map()
		"reward":
			if index >= 0 and index < _reward_ids.size(): run.add_card(_db.get_card(_reward_ids[index]))
			await _return_to_map()
		"shop_cards":
			if index >= 0 and index < _shop_offer_ids.size() and run.spend_gold(SHOP_CARD_PRICE):
				run.add_card(_db.get_card(_shop_offer_ids[index]))
				_shop_offer_ids.remove_at(index)
			_show_shop()
		"shop_remove":
			var price := SHOP_REMOVE_BASE + run.remove_count * SHOP_REMOVE_STEP
			if index >= 0 and run.gold >= price and run.remove_card_at(index): run.spend_gold(price)
			_show_shop()

func _on_choice(index: int) -> void:
	match _mode:
		"medicine":
			if index == 0: run.heal(8)
			elif index == 1: run.add_card(_db.get_card("emergency_medkit"))
			await _return_to_map()
		"tools":
			if index == 0: _show_upgrade_choices()
			else:
				if index == 1: run.add_card(_db.get_card("insulation"))
				await _return_to_map()
		"maintenance":
			if index == 0: _show_maintenance_choices()
			else: await _return_to_map()
		"exchange":
			if index < 2:
				var old_id := "calibrate_shot" if index == 0 else "force_shield"
				for i in run.deck.size():
					if run.deck[i].id == old_id:
						run.deck.remove_at(i)
						run.add_card(_db.get_card(_exchange_offers[index]))
						break
			await _return_to_map()
		"shop":
			match index:
				0: _show_shop_cards()
				1: _show_shop_remove()
				2: _show_shop_trinkets()
				_: await _return_to_map()
		"shop_trinkets":
			if index >= 0 and index < TrinketCatalog.IDS.size():
				var id: String = TrinketCatalog.IDS[index]
				var price: int = TrinketCatalog.info(id).price
				if not run.trinkets.has(id) and run.spend_gold(price): run.add_trinket(id)
			_show_shop()
		"rest":
			if index == 1: _show_upgrade_choices()
			else:
				if index == 0: run.heal(14)
				await _return_to_map()
		"event": await _resolve_event(index)
		"no_cards": await _return_to_map()
		"defeat", "complete": _show_character_select()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and _mode == "battle":
		view.restart()

