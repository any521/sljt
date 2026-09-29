extends Control
## UI 小 demo —— 按"像素密度统一"的新规格把整套战斗界面画出来，供判断视觉可行性。
##
## 规格依据：docs/太空站尖塔-全量复刻计划-v1.0.md §1
##   虚拟网格 4×4：世界层 ×4、卡牌层 ×2，任何资产在屏幕上都是整数倍
##   卡牌 128×192 美术 → 屏上 256×384；卡内插图 64×96 → 128×192
##
## 绘制方式：全部走 _draw()（不新增节点，遵守预制体规范）；
## 数据取自项目真实的 CardDB / CardArt，不是占位符。
## 托盘是真实预制体（scenes/ui/hand_tray.tscn），z_index = -1 保证画在卡牌下面。

@export_range(1, 10) var hand_count := 5   ## 演示几张手牌（改这个看自适应版式）
@export var show_beam := true              ## 是否演示指向光束

# ── 锁定色板（美术基调 §2）──────────────────────────────
const C_BASE := Color("0A0E14")
const C_PANEL := Color("111620")
const C_STRUCT := Color("1E3A52")
const C_MAIN := Color("3A82B2")
const C_BRIGHT := Color("6BC7FF")
const C_HILITE := Color("B2E8FF")
const C_WARN := Color("E8A830")
const C_HOT := Color("FFDC82")
const C_DANGER := Color("D64440")
const C_TEXT := Color("E0E8F0")
const C_SUB := Color("8592A0")
const C_BORDER := Color("2A303C")
const C_BIO := Color("C7479E")

const CARD := Vector2(256, 384)      # 屏幕上：128×192 美术 ×2
const ART := Vector2(128, 192)       # 卡面插图区


func _ready() -> void:
	# 真实托盘：宽度按当前手牌行自适应，这里给一个演示值
	var tray := get_node_or_null("Tray")
	if tray != null and tray.has_method("set_fan"):
		tray.set_fan(880.0, 14.0, 1280.0, false)


func _cards() -> Array:
	var db: Node = Engine.get_main_loop().root.get_node_or_null("CardDB")
	var out: Array = []
	if db == null:
		return out
	var ids: Array = db.starter_deck
	for i in mini(hand_count, ids.size()):
		out.append(db.get_card(ids[i]))
	return out


## 像素风面板：硬边 + 2px 描边 + 四角刻线
func _panel(rect: Rect2, fill: Color, border: Color = C_BORDER, ticks := true) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, 2.0)
	if not ticks:
		return
	var t := 10.0
	for corner in [[rect.position, Vector2(1, 1)], [Vector2(rect.end.x, rect.position.y), Vector2(-1, 1)],
			[Vector2(rect.position.x, rect.end.y), Vector2(1, -1)], [rect.end, Vector2(-1, -1)]]:
		var o: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_line(o, o + Vector2(t * d.x, 0), C_MAIN, 3.0, true)
		draw_line(o, o + Vector2(0, t * d.y), C_MAIN, 3.0, true)


func _text(pos: Vector2, text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var font := get_theme_default_font()
	draw_string(font, pos, text, align, width, size, color)


func _bar(rect: Rect2, ratio: float, fill: Color, bg := Color("0B0E14")) -> void:
	draw_rect(rect, bg, true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), fill, true)
	draw_rect(rect, C_BORDER, false, 2.0)


## 意图图标：剑=攻击（按伤害分档换大小）、盾=格挡、漩涡=减益/增益
func _intent(center: Vector2, kind: String, value: int) -> void:
	var box := Rect2(center - Vector2(34, 34), Vector2(68, 68))
	draw_rect(box, Color(C_BASE, 0.85), true)
	draw_rect(box, C_MAIN if kind != "debuff" else C_BIO, false, 2.0)
	match kind:
		"attack":
			var scale := 1.0 if value < 12 else 1.35
			var blade := PackedVector2Array([center + Vector2(0, -18 * scale), center + Vector2(7, 6),
					center + Vector2(0, 14), center + Vector2(-7, 6)])
			draw_colored_polygon(blade, C_DANGER if value >= 12 else C_TEXT)
			draw_line(center + Vector2(-11, 12), center + Vector2(11, 12), C_HOT, 3.0, true)
		"block":
			var shield := PackedVector2Array([center + Vector2(0, -16), center + Vector2(14, -7),
					center + Vector2(10, 14), center + Vector2(0, 18), center + Vector2(-10, 14), center + Vector2(-14, -7)])
			draw_colored_polygon(shield, C_BRIGHT)
			draw_polyline(shield, C_HILITE, 2.0, true)
		_:
			draw_arc(center, 15, 0.0, TAU * 0.86, 24, C_BIO, 4.0, true)
			draw_arc(center, 8, PI, PI + TAU * 0.7, 20, C_BIO, 3.0, true)
	_text(center + Vector2(0, 58), str(value), 26, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 60)
	# 数字底衬
	draw_rect(Rect2(center + Vector2(-30, 38), Vector2(60, 40)), Color(C_BASE, 0.0))


## 新规格卡牌：名字条 / 插图区 64×96(×2=128×192) / 类型条 / 描述区 / 归属条
func _card(origin: Vector2, data, angle := 0.0) -> void:
	var accent: Color = data.faction_color() if data.has_method("faction_color") else C_MAIN
	var upgraded: bool = data.upgraded
	var frame := C_WARN if upgraded else accent
	var root := origin + CARD * 0.5
	draw_set_transform(root, angle, Vector2.ONE)
	var rect := Rect2(-CARD * 0.5, CARD)
	# 卡体
	draw_rect(rect, Color(C_PANEL, 0.97), true)
	draw_rect(rect, C_BASE, false, 4.0)
	draw_rect(rect.grow(-4.0), frame, false, 3.0)
	# 名字条 0–40
	draw_rect(Rect2(rect.position, Vector2(CARD.x, 40)), Color(accent, 0.22), true)
	draw_line(Vector2(rect.position.x, rect.position.y + 40), Vector2(rect.end.x, rect.position.y + 40), frame, 2.0, true)
	_text(Vector2(rect.position.x + 20, rect.position.y + 28), str(data.display_name), 22, C_TEXT)
	# 费用宝石：悬出卡外（尖塔式）
	var gem := Vector2(rect.position.x - 8, rect.position.y - 8)
	draw_circle(gem, 30, C_BASE)
	draw_circle(gem, 26, C_WARN)
	draw_circle(gem, 21, Color(C_BASE, 0.9))
	_text(gem + Vector2(0, 10), str(data.cost), 28, C_HOT, HORIZONTAL_ALIGNMENT_CENTER, 0.0)
	# 插图区 40–232（64×96 美术 ×2）
	var art_rect := Rect2(Vector2(rect.position.x + (CARD.x - ART.x) * 0.5, rect.position.y + 40), ART)
	draw_rect(art_rect, Color(C_BASE, 0.9), true)
	var art_db: Node = Engine.get_main_loop().root.get_node_or_null("CardArt")
	var texture: Texture2D = art_db.get_card_texture(data.id) if art_db != null else null
	if texture != null:
		draw_texture_rect(texture, art_rect, false)
	else:
		draw_rect(art_rect.grow(-20.0), Color(accent, 0.35), true)
	draw_rect(art_rect, C_BORDER, false, 2.0)
	# 类型条 232–256
	draw_rect(Rect2(Vector2(rect.position.x, rect.position.y + 232), Vector2(CARD.x, 24)), Color(accent, 0.32), true)
	_text(Vector2(rect.position.x + 18, rect.position.y + 250), "%s · %s" % [data.faction_name(), data.type_name()], 16, C_TEXT)
	# 描述区 256–352
	var desc := str(data.description)
	if desc == "":
		desc = data.build_description()
	_text(Vector2(rect.position.x + 18, rect.position.y + 284), desc, 20, C_TEXT if not upgraded else C_HOT, HORIZONTAL_ALIGNMENT_LEFT, CARD.x - 36)
	# 归属条 352–384
	draw_rect(Rect2(Vector2(rect.position.x, rect.position.y + 352), Vector2(CARD.x, 32)), Color(accent, 0.5), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 指向光束（简化预览：锥形多层 + 金色箭头 + 金色刻度）
func _beam(from: Vector2, to: Vector2) -> void:
	var mid := (from + to) * 0.5 + Vector2(0, -70)
	var steps := 22
	var layers := [
		{"w": 30.0, "c": Color("0A0E14", 0.0), "a": 0.0},
		{"w": 22.0, "c": Color("0f2f6b"), "a": 0.5},
		{"w": 13.0, "c": Color("1f5fc4"), "a": 0.7},
		{"w": 5.0, "c": Color("c8e6ff"), "a": 0.95},
	]
	for layer in layers:
		if float(layer["a"]) <= 0.0:
			continue
		var poly := PackedVector2Array()
		var back := PackedVector2Array()
		for i in steps + 1:
			var t := float(i) / float(steps)
			var p := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
			var ahead := from.lerp(mid, minf(t + 0.04, 1.0)).lerp(mid.lerp(to, minf(t + 0.04, 1.0)), minf(t + 0.04, 1.0))
			var n := Vector2(-(ahead - p).normalized().y, (ahead - p).normalized().x)
			var taper := (0.28 + 0.72 * pow(t, 0.85)) * (1.0 - 0.7 * maxf(t - 0.62, 0.0) / 0.38)
			var w: float = float(layer["w"]) * taper
			poly.append(p + n * w)
			back.append(p - n * w)
		back.reverse()
		poly.append_array(back)
		draw_colored_polygon(poly, Color(layer["c"], float(layer["a"])))
	# 金色刻度
	for k in 7:
		var t := fmod(float(k) / 7.0 + 0.12, 1.0)
		var p := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		var ahead := from.lerp(mid, minf(t + 0.04, 1.0)).lerp(mid.lerp(to, minf(t + 0.04, 1.0)), minf(t + 0.04, 1.0))
		var n := Vector2(-(ahead - p).normalized().y, (ahead - p).normalized().x)
		var w: float = 22.0 * (0.28 + 0.72 * pow(t, 0.85)) * (1.0 - 0.7 * maxf(t - 0.62, 0.0) / 0.38)
		var alpha := minf(t / 0.14, 1.0) * minf((1.0 - t) / 0.2, 1.0)
		if alpha > 0.02:
			draw_line(p - n * w * 0.9, p + n * w * 0.9, Color(C_WARN, alpha * 0.9), 2.6, true)
	# 箭头
	var dir := (to - mid).normalized()
	var head := PackedVector2Array([to + dir * 26.0, to - dir * 10.0 + Vector2(-dir.y, dir.x) * 20.0,
			to - dir * 4.0, to - dir * 10.0 - Vector2(-dir.y, dir.x) * 20.0])
	draw_colored_polygon(head, Color(C_WARN, 0.95))
	draw_polyline(head, C_HOT, 2.0, true)


func _draw() -> void:
	# ① 底 + 舱壁
	draw_rect(Rect2(Vector2.ZERO, size), C_BASE, true)
	draw_rect(Rect2(0, 0, size.x, 620), Color("0c1219"), true)
	for i in 9:
		var x := 60.0 + i * 210.0
		draw_rect(Rect2(x, 120, 26, 420), Color(C_STRUCT, 0.55), true)
		draw_rect(Rect2(x + 6, 132, 14, 396), Color(C_PANEL, 0.7), true)
	draw_rect(Rect2(0, 596, size.x, 12), C_STRUCT, true)
	draw_rect(Rect2(0, 608, size.x, 10), Color(C_BASE, 1.0), true)
	# 观景窗
	draw_rect(Rect2(560, 150, 800, 330), Color("071018"), true)
	draw_rect(Rect2(560, 150, 800, 330), C_STRUCT, false, 4.0)
	draw_circle(Vector2(1180, 430), 190, Color("123a5e"))
	draw_circle(Vector2(1160, 410), 150, Color("1c5c8a"))
	draw_circle(Vector2(1130, 380), 90, Color("2a86bd"))
	draw_arc(Vector2(1180, 430), 190, PI, TAU, 40, C_MAIN, 3.0, true)
	# ② 顶栏
	_panel(Rect2(0, 0, size.x, 40), Color(C_PANEL, 0.95), C_BORDER, false)
	_text(Vector2(24, 28), "ARKHAM // 07 生物实验舱", 20, C_BRIGHT)
	_text(Vector2(size.x - 424, 28), "第 7 层  ·  种子 4A9C2F  ·  记录   规则   设置", 18, C_SUB, HORIZONTAL_ALIGNMENT_RIGHT, 400.0)
	# ③ 左：乘员面板
	for i in 2:
		var rect := Rect2(20, 52 + i * 100, 320, 92)
		_panel(rect, Color(C_PANEL, 0.92))
		draw_rect(Rect2(rect.position + Vector2(10, 10), Vector2(56, 56)), Color(C_STRUCT, 0.9), true)
		draw_rect(Rect2(rect.position + Vector2(10, 10), Vector2(56, 56)), C_MAIN, false, 2.0)
		_text(rect.position + Vector2(80, 34), "沈明砚" if i == 0 else "宋梅", 20, C_TEXT)
		_bar(Rect2(rect.position + Vector2(80, 44), Vector2(210, 16)), (70.0 - i * 12) / 70.0, C_DANGER)
		_text(rect.position + Vector2(80, 78), "%d / 70" % (70 - i * 12), 16, C_SUB)
		_text(rect.position + Vector2(200, 78), "格挡 %d" % (i * 6), 16, C_BRIGHT)
	# ④ 右：敌人 + 意图
	for i in 2:
		var center := Vector2(1180 + i * 360, 560)
		# 躯体
		draw_rect(Rect2(center.x - 46, center.y - 120, 92, 120), Color(C_STRUCT, 0.85), true)
		draw_rect(Rect2(center.x - 34, center.y - 152, 68, 40), Color(C_PANEL, 0.9), true)
		draw_rect(Rect2(center.x - 34, center.y - 152, 68, 40), C_MAIN, false, 2.0)
		draw_circle(Vector2(center.x - 12, center.y - 132), 6, C_BIO)
		draw_circle(Vector2(center.x + 12, center.y - 132), 6, C_BIO)
		# 血色藤蔓
		for k in 4:
			draw_line(Vector2(center.x - 40 + k * 26, center.y - 100), Vector2(center.x - 60 + k * 34, center.y - 20), Color(C_BIO, 0.5), 3.0, true)
		_intent(center + Vector2(0, -196), "attack" if i == 0 else "block", 6 + i * 5)
		# 名牌 + 血条
		var plate := Rect2(center.x - 90, center.y + 6, 180, 46)
		_panel(plate, Color(C_PANEL, 0.92), C_BORDER, false)
		_text(plate.position + Vector2(10, 24), "眷族织体" if i == 0 else "眷族宿主", 18, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, 104.0)
		_bar(Rect2(plate.position + Vector2(10, 30), Vector2(160, 10)), 1.0 - i * 0.4, C_DANGER)
		_text(plate.position + Vector2(10, 24), "%d / %d" % [30 - i * 12, 30], 16, C_SUB, HORIZONTAL_ALIGNMENT_RIGHT, 160.0)
	# ⑤ 手牌（托盘是真实预制体，在下面一层）
	var hand := _cards()
	var count := hand.size()
	if count > 0:
		var tray_rect := Rect2(260, 790, 1400, 252)
		# 允许轻微重叠（像"一把牌"），同时保证整排不越过托盘两端
		var slot: float = CARD.x * 0.94
		if count > 1:
			slot = minf(slot, (tray_rect.size.x - 180.0 - CARD.x) / float(count - 1))
		var span := slot * float(count - 1)
		var start := tray_rect.get_center().x - span * 0.5
		var middle := float(count - 1) * 0.5
		var lift: float = 0.0
		for i in count:
			var n := 0.0 if middle == 0.0 else (float(i) - middle) / middle
			var origin := Vector2(start + i * slot - CARD.x * 0.5, 600.0 + absf(n) * 16.0)
			_card(origin, hand[i], deg_to_rad(n * 7.0))
			if absf(float(i) - middle) < 0.6:
				lift = origin.x + CARD.x * 0.5
		# ⑥ 指向光束：从中间那张牌指向第一个敌人
		if show_beam:
			_beam(Vector2(lift, 636.0), Vector2(1180, 520))
	# ⑦ 左：能量球
	draw_circle(Vector2(96, 900), 62, C_BASE)
	draw_circle(Vector2(96, 900), 56, C_STRUCT)
	draw_circle(Vector2(96, 900), 48, C_MAIN)
	draw_circle(Vector2(96, 900), 36, Color(C_BASE, 0.75))
	_text(Vector2(96, 916), "3", 46, C_HOT, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(96, 986), "能量", 18, C_SUB, HORIZONTAL_ALIGNMENT_CENTER)
	# ⑧ 右：结束回合
	var end_rect := Rect2(1700, 880, 196, 96)
	_panel(end_rect, Color(C_WARN, 0.18), C_WARN)
	_text(end_rect.position + Vector2(98, 58), "结束回合", 26, C_HOT, HORIZONTAL_ALIGNMENT_CENTER)
	# ⑨ 牌堆
	_panel(Rect2(300, 800, 132, 40), Color(C_PANEL, 0.9), C_BORDER, false)
	_text(Vector2(366, 826), "抽牌堆 5", 18, C_SUB, HORIZONTAL_ALIGNMENT_CENTER)
	_panel(Rect2(1490, 800, 132, 40), Color(C_PANEL, 0.9), C_BORDER, false)
	_text(Vector2(1556, 826), "弃牌堆 0", 18, C_SUB, HORIZONTAL_ALIGNMENT_CENTER)
	# ⑩ 底部提示
	_text(Vector2(size.x * 0.5, 1046), "点击卡牌拿起  ·  光标找目标后点击出牌  ·  再点同一张取消", 18, C_SUB, HORIZONTAL_ALIGNMENT_CENTER)
