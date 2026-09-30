extends RefCounted
class_name RouteMap
## Seeded paths first, room types second. Fixed rests and shortcuts bound the run to 11–13 rooms.

const FLOOR_COUNT := 13
const LANES := 5
const ROOM_BANDS := [
	["battle"],
	["medicine", "tools", "event", "exchange"],
	["battle"],
	["battle", "elite", "event"],
	["medicine", "maintenance", "shop", "tools"],
	["rest"],
	["event", "medicine", "tools", "exchange"],
	["battle"],
	["battle", "elite", "event"],
	["medicine", "shop", "maintenance", "exchange"],
	["battle"],
	["rest"],
	["boss"],
]

static func generate(seed_value: int) -> Array[Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rows: Array[Array] = []
	for floor_index in FLOOR_COUNT:
		var row: Array[Dictionary] = []
		for lane in LANES:
			row.append({"floor": floor_index, "lane": lane, "type": "empty",
				"id": "%02d_%d" % [floor_index, lane], "next": [], "active": false})
		rows.append(row)
	# Several random walks create branches and merges. The center path
	# guarantees every stage remains reachable and hosts the two visible skips.
	for walk_index in 6:
		var lane := 2 if walk_index == 0 else rng.randi_range(0, LANES - 1)
		rows[0][lane].active = true
		for floor_index in FLOOR_COUNT - 1:
			var target := 2 if walk_index == 0 else clampi(lane + rng.randi_range(-1, 1), 0, LANES - 1)
			if floor_index >= 9:
				var remaining := 11 - floor_index
				if abs(target - 2) > remaining:
					target += -1 if target > 2 else 1
			if floor_index == 11: target = 2
			target = _avoid_crossing(rows, floor_index, lane, target)
			_add_edge(rows, floor_index, lane, floor_index + 1, target)
			lane = target
	for floor_index in [1, 7]:
		_add_edge(rows, floor_index, 2, floor_index + 2, 2)
	for floor_index in FLOOR_COUNT:
		var pool: Array = ROOM_BANDS[floor_index].duplicate()
		_shuffle(pool, rng)
		var active_index := 0
		for lane in LANES:
			if not rows[floor_index][lane].active: continue
			rows[floor_index][lane].type = pool[active_index % pool.size()]
			active_index += 1
	# One reachable optional merchant is guaranteed; the second late merchant is seeded.
	rows[4][2].type = "shop"
	return rows

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp

static func _avoid_crossing(rows: Array[Array], floor_index: int, lane: int, target: int) -> int:
	for other_lane in LANES:
		if other_lane == lane: continue
		for edge in rows[floor_index][other_lane].next:
			if edge.floor != floor_index + 1: continue
			if (lane < other_lane and target > edge.lane) or (lane > other_lane and target < edge.lane):
				target = edge.lane
	return target

static func _add_edge(rows: Array[Array], from_floor: int, from_lane: int, to_floor: int, to_lane: int) -> void:
	var connection := {"floor": to_floor, "lane": to_lane}
	if not rows[from_floor][from_lane].next.has(connection):
		rows[from_floor][from_lane].next.append(connection)
	rows[from_floor][from_lane].active = true
	rows[to_floor][to_lane].active = true

static func next_rooms(rows: Array[Array], current_floor: int, current_lane: int) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if current_floor < 0:
		for room in rows[0]:
			if room.active: targets.append(room)
		return targets
	for connection in rows[current_floor][current_lane].next:
		targets.append(rows[connection.floor][connection.lane])
	return targets
