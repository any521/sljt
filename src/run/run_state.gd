extends RefCounted
class_name RunState

var db
var character_rules: CharacterRules
var seed_value: int
var rows: Array[Array]
var deck: Array[CardData] = []
var hp := CombatManager.PLAYER_MAX_HP
var gold := 60
var battles_won := 0
var remove_count := 0
var trinkets: Array[String] = []
var floor_index := -1
var lane := 2
var path: Array[Dictionary] = []
var selected_room: Dictionary = {}
var completed := false

func _init(p_seed: int, starter: Array[CardData], p_db: Node, p_character_id: String = CharacterRules.SHEN_MING) -> void:
	db = p_db
	character_rules = CharacterRules.new(p_character_id)
	seed_value = p_seed
	rows = RouteMap.generate(seed_value)
	for card in starter:
		deck.append(card.duplicate_card())

func available_rooms() -> Array[Dictionary]:
	if completed or hp <= 0 or floor_index >= RouteMap.FLOOR_COUNT - 1:
		return []
	return RouteMap.next_rooms(rows, floor_index, lane)

func choose_room(next_floor: int, next_lane: int) -> Dictionary:
	for room in available_rooms():
		if room.floor == next_floor and room.lane == next_lane:
			floor_index = next_floor
			lane = next_lane
			selected_room = room
			path.append(room)
			return room
	return {}

func heal(amount: int) -> void:
	hp = mini(CombatManager.PLAYER_MAX_HP, hp + amount)

func add_card(card: CardData) -> void:
	deck.append(card.duplicate_card())

func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount: return false
	gold -= amount
	return true

func add_trinket(id: String) -> bool:
	if not TrinketCatalog.IDS.has(id) or trinkets.has(id): return false
	trinkets.append(id)
	return true

func remove_card_at(index: int) -> bool:
	if index < 0 or index >= deck.size() or deck.size() <= 1: return false
	deck.remove_at(index)
	remove_count += 1
	return true

func lose_hp_percent(percent: float) -> int:
	var loss := maxi(1, ceili(float(CombatManager.PLAYER_MAX_HP) * percent))
	hp = maxi(1, hp - loss)
	return loss

func first_upgradeable() -> int:
	for i in deck.size():
		if not deck[i].upgraded and db.cards.has(deck[i].id + "_plus"):
			return i
	return -1

func upgrade_at(index: int) -> bool:
	if index < 0 or index >= deck.size() or deck[index].upgraded:
		return false
	if not db.cards.has(deck[index].id + "_plus"):
		return false
	var old_maintenance_level := deck[index].maintenance_level
	var upgraded: CardData = db.get_card(deck[index].id + "_plus")
	deck[index] = upgraded.duplicate_card()
	for i in old_maintenance_level:
		deck[index].maintain_damage()
	return true

func maintain_damage_at(index: int) -> bool:
	if index < 0 or index >= deck.size():
		return false
	return deck[index].maintain_damage()

