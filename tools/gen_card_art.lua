-- ============================================================
-- 《回声号》卡面美术生成脚本
-- 用途：在 Aseprite 中程序化生成 19 张卡牌的 32x32 像素插画
-- 运行：aseprite.exe -b --script tools/gen_card_art.lua
-- 输出：assets/art/cards/cards_art.png（8 列 x 3 行精灵表）
--       assets/art/cards/cards_art.json（帧索引）
--
-- 设计约定：所有立绘统一 32x32、深色底 + 荧光主色，
-- 风格对应三个归属：规程=冷青蓝 / 变异=品红紫 / 中立=中性灰
-- ============================================================

local COLS = 8
local ROWS = 3
local CELL = 32

local spr = Sprite(CELL * COLS, CELL * ROWS, ColorMode.RGB)
local img = spr.cels[1].image

-- ---------- 绘制工具 ----------
local function C(r, g, b, a)
	return Color(r, g, b, a or 255)
end

local function px(ox, oy, x, y, c)
	if x >= 0 and x < CELL and y >= 0 and y < CELL then
		img:putPixel(ox + x, oy + y, c)
	end
end

local function fill(ox, oy, c)
	for y = 0, CELL - 1 do
		for x = 0, CELL - 1 do
			px(ox, oy, x, y, c)
		end
	end
end

-- 填充矩形。参数：格子原点(ox, oy)、矩形(x0,y0)-(x1,y1)、颜色 c
local function rect(ox, oy, x0, y0, x1, y1, c)
	for yy = math.min(y0, y1), math.max(y0, y1) do
		for xx = math.min(x0, x1), math.max(x0, x1) do
			px(ox, oy, xx, yy, c)
		end
	end
end

local function hline(ox, oy, x0, x1, y, c)
	for x = math.min(x0, x1), math.max(x0, x1) do
		px(ox, oy, x, y, c)
	end
end

local function vline(ox, oy, x, y0, y1, c)
	for y = math.min(y0, y1), math.max(y0, y1) do
		px(ox, oy, x, y, c)
	end
end

-- 中点画圆（只画圆环，用极坐标采样保证对称）
local function circle(ox, oy, cx, cy, r, c, filled)
	if filled then
		for y = -r, r do
			for x = -r, r do
				if x * x + y * y <= r * r then
					px(ox, oy, cx + x, cy + y, c)
				end
			end
		end
	else
		local steps = math.max(24, r * 12)
		for i = 0, steps - 1 do
			local a = (i / steps) * math.pi * 2
			px(ox, oy, math.floor(cx + math.cos(a) * r + 0.5),
				math.floor(cy + math.sin(a) * r + 0.5), c)
		end
	end
end

local function diamond(ox, oy, cx, cy, r, c, filled)
	for y = -r, r do
		for x = -r, r do
			local d = math.abs(x) + math.abs(y)
			if (filled and d <= r) or (not filled and d == r) then
				px(ox, oy, cx + x, cy + y, c)
			end
		end
	end
end

local function line(ox, oy, x0, y0, x1, y1, c)
	local dx = math.abs(x1 - x0)
	local dy = math.abs(y1 - y0)
	local sx = (x0 < x1) and 1 or -1
	local sy = (y0 < y1) and 1 or -1
	local err = dx - dy
	local x, y = x0, y0
	while true do
		px(ox, oy, x, y, c)
		if x == x1 and y == y1 then break end
		local e2 = 2 * err
		if e2 > -dy then err = err - dy; x = x + sx end
		if e2 < dx then err = err + dx; y = y + sy end
	end
end

local function ring(ox, oy, cx, cy, r, c)
	local steps = math.max(20, r * 10)
	for i = 0, steps - 1 do
		local a = (i / steps) * math.pi * 2
		local rr = r + ((i % 2 == 0) and 0 or 0.35)
		px(ox, oy, math.floor(cx + math.cos(a) * rr + 0.5),
			math.floor(cy + math.sin(a) * rr + 0.5), c)
	end
end

-- ---------- 调色板 ----------
-- 规程系（冷青蓝）
local P_DARK   = C(10, 20, 30)
local P_BASE   = C(30, 68, 96)
local P_MID    = C(58, 130, 178)
local P_LIGHT  = C(107, 199, 255)
local P_GLOW   = C(178, 232, 255)
-- 变异系（品红紫）
local M_DARK   = C(26, 8, 24)
local M_BASE   = C(72, 18, 58)
local M_MID    = C(140, 42, 112)
local M_LIGHT  = C(199, 71, 158)
local M_GLOW   = C(255, 158, 220)
-- 中立系（中性灰蓝）
local N_DARK   = C(16, 20, 24)
local N_BASE   = C(52, 60, 68)
local N_MID    = C(96, 106, 114)
local N_LIGHT  = C(160, 170, 178)
local N_GLOW   = C(214, 222, 228)
-- 强调色
local AMBER    = C(232, 168, 48)
local AMBER_HI = C(255, 220, 130)
local RED      = C(214, 68, 62)
local RED_HI   = C(255, 150, 140)
local WHITE    = C(240, 246, 250)
local GREEN    = C(70, 180, 110)

-- ============================================================
-- 19 张卡的绘制函数
-- ============================================================
local drawers = {}

-- 01 校准射击 —— 十字准星 + 扫描线
drawers.calibrate_shot = function(ox, oy)
	fill(ox, oy, P_DARK)
	circle(ox, oy, 16, 16, 10, P_MID, false)
	circle(ox, oy, 16, 16, 6, P_BASE, false)
	-- 十字准星
	hline(ox, oy, 4, 28, 16, P_LIGHT)
	vline(ox, oy, 16, 4, 28, P_LIGHT)
	-- 中心点
	diamond(ox, oy, 16, 16, 2, P_GLOW, true)
	-- 刻度
	for i = 0, 3 do
		local x = 8 + i * 5
		px(ox, oy, x, 12, P_MID)
		px(ox, oy, x, 20, P_MID)
	end
	-- 四角扫描框
	rect(ox, oy, 3, 3, 7, 4, P_BASE)
	rect(ox, oy, 24, 3, 28, 4, P_BASE)
	rect(ox, oy, 3, 27, 7, 28, P_BASE)
	rect(ox, oy, 24, 27, 28, 28, P_BASE)
end

-- 02 精准打击 —— 弹道轨迹 + 命中爆点
drawers.precision_strike = function(ox, oy)
	fill(ox, oy, P_DARK)
	-- 弹道（从右上到左下）
	for i = 0, 20 do
		local x = 26 - i
		local y = 6 + i
		px(ox, oy, x, y, P_MID)
		if i % 3 == 0 then
			px(ox, oy, x + 1, y, P_BASE)
			px(ox, oy, x, y + 1, P_BASE)
		end
	end
	-- 命中爆点
	circle(ox, oy, 9, 23, 5, P_LIGHT, true)
	circle(ox, oy, 9, 23, 7, P_MID, false)
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2
		line(ox, oy, 9 + math.floor(math.cos(a) * 6 + 0.5),
			23 + math.floor(math.sin(a) * 6 + 0.5),
			9 + math.floor(math.cos(a) * 9 + 0.5),
			23 + math.floor(math.sin(a) * 9 + 0.5), P_GLOW)
	end
	px(ox, oy, 9, 23, WHITE)
end

-- 03 力场护罩 —— 六边形力场
drawers.force_shield = function(ox, oy)
	fill(ox, oy, P_DARK)
	-- 外圈六边形
	local hx = { 16, 26, 26, 16, 6, 6 }
	local hy = { 4, 10, 22, 28, 22, 10 }
	for i = 1, 6 do
		local j = (i % 6) + 1
		line(ox, oy, hx[i], hy[i], hx[j], hy[j], P_MID)
	end
	-- 内圈六边形
	local ix = { 16, 22, 22, 16, 10, 10 }
	local iy = { 9, 13, 19, 23, 19, 13 }
	for i = 1, 6 do
		local j = (i % 6) + 1
		line(ox, oy, ix[i], iy[i], ix[j], iy[j], P_LIGHT)
	end
	-- 中心护盾核心
	diamond(ox, oy, 16, 16, 3, P_GLOW, true)
	-- 力场纹路
	hline(ox, oy, 10, 22, 16, P_BASE)
	px(ox, oy, 16, 5, P_GLOW)
	px(ox, oy, 16, 27, P_GLOW)
end

-- 04 框架分析 —— 数据网格 + 高亮节点
drawers.framework_scan = function(ox, oy)
	fill(ox, oy, P_DARK)
	-- 网格
	for x = 5, 27, 4 do
		vline(ox, oy, x, 5, 27, P_BASE)
	end
	for y = 5, 27, 4 do
		hline(ox, oy, 5, 27, y, P_BASE)
	end
	-- 高亮节点
	local nodes = { { 9, 9 }, { 21, 13 }, { 13, 21 }, { 25, 25 }, { 17, 17 } }
	for i, n in ipairs(nodes) do
		px(ox, oy, n[1], n[2], P_GLOW)
		px(ox, oy, n[1] + 1, n[2], P_LIGHT)
		px(ox, oy, n[1], n[2] + 1, P_LIGHT)
	end
	-- 连接线
	line(ox, oy, 9, 9, 17, 17, P_MID)
	line(ox, oy, 17, 17, 21, 13, P_MID)
	line(ox, oy, 17, 17, 13, 21, P_MID)
	-- 外框
	rect(ox, oy, 4, 4, 28, 5, P_MID)
	rect(ox, oy, 4, 27, 28, 28, P_MID)
	rect(ox, oy, 4, 4, 5, 28, P_MID)
	rect(ox, oy, 27, 4, 28, 28, P_MID)
end

-- 05 超频运转 —— 能量核心 + 电弧
drawers.overclock = function(ox, oy)
	fill(ox, oy, C(28, 14, 8))
	-- 核心
	circle(ox, oy, 16, 16, 7, C(180, 90, 20), true)
	circle(ox, oy, 16, 16, 4, AMBER, true)
	circle(ox, oy, 16, 16, 2, AMBER_HI, true)
	-- 反应圈
	ring(ox, oy, 16, 16, 10, C(140, 80, 30))
	-- 电弧（四条）
	local bolts = {
		{ 16, 6, 20, 11, 18, 14 },
		{ 26, 16, 21, 20, 24, 24 },
		{ 16, 26, 12, 21, 14, 18 },
		{ 6, 16, 11, 12, 8, 8 },
	}
	for _, b in ipairs(bolts) do
		line(ox, oy, b[1], b[2], b[3], b[4], AMBER_HI)
		line(ox, oy, b[3], b[4], b[5], b[6], AMBER)
	end
	-- 过载警告点
	px(ox, oy, 4, 4, RED)
	px(ox, oy, 27, 27, RED)
end

-- 06 撕裂 —— 三条爪痕
drawers.lacerate = function(ox, oy)
	fill(ox, oy, M_DARK)
	-- 背景肉块
	circle(ox, oy, 16, 16, 12, C(48, 12, 40), true)
	circle(ox, oy, 13, 14, 6, C(60, 16, 46), true)
	-- 三条撕痕
	local slashes = { { 8, 4, 12, 28 }, { 15, 3, 19, 29 }, { 22, 5, 26, 27 } }
	for _, s in ipairs(slashes) do
		line(ox, oy, s[1], s[2], s[3], s[4], M_LIGHT)
		line(ox, oy, s[1] + 1, s[2], s[3] + 1, s[4], M_MID)
		line(ox, oy, s[1] - 1, s[2], s[3] - 1, s[4], M_MID)
	end
	-- 溅出的血
	local drops = { { 6, 10 }, { 25, 9 }, { 9, 24 }, { 24, 22 }, { 16, 30 } }
	for _, d in ipairs(drops) do
		px(ox, oy, d[1], d[2], M_GLOW)
	end
end

-- 07 寄生孢子 —— 孢子囊 + 飘散孢子
drawers.parasite_spore = function(ox, oy)
	fill(ox, oy, M_DARK)
	-- 主囊
	circle(ox, oy, 16, 20, 8, M_BASE, true)
	circle(ox, oy, 16, 20, 6, M_MID, true)
	circle(ox, oy, 14, 18, 2, M_GLOW, true)
	-- 囊柄
	vline(ox, oy, 16, 26, 29, M_BASE)
	-- 飘散孢子
	local spores = {
		{ 7, 10 }, { 12, 6 }, { 20, 5 }, { 25, 9 }, { 9, 15 }, { 23, 14 }, { 16, 11 }
	}
	for i, s in ipairs(spores) do
		local r = (i % 2 == 0) and 1 or 2
		circle(ox, oy, s[1], s[2], r, M_LIGHT, true)
		px(ox, oy, s[1], s[2], M_GLOW)
	end
	circle(ox, oy, 16, 20, 10, M_MID, false)
end

-- 08 血肉重塑 —— 组织再生漩涡
drawers.flesh_reshape = function(ox, oy)
	fill(ox, oy, M_DARK)
	-- 螺旋组织
	for i = 0, 40 do
		local t = i / 40
		local a = t * math.pi * 4
		local r = 3 + t * 11
		local x = math.floor(16 + math.cos(a) * r + 0.5)
		local y = math.floor(16 + math.sin(a) * r + 0.5)
		px(ox, oy, x, y, M_MID)
		px(ox, oy, x, y - 1, M_BASE)
	end
	-- 核心
	circle(ox, oy, 16, 16, 3, M_LIGHT, true)
	px(ox, oy, 16, 16, M_GLOW)
	-- 生长的肉芽
	local buds = { { 5, 16 }, { 27, 16 }, { 16, 5 }, { 16, 27 } }
	for _, b in ipairs(buds) do
		circle(ox, oy, b[1], b[2], 2, M_LIGHT, true)
		line(ox, oy, 16, 16, b[1], b[2], C(90, 24, 70))
	end
end

-- 09 深渊凝视 —— 一只睁开的眼
drawers.abyss_gaze = function(ox, oy)
	fill(ox, oy, M_DARK)
	-- 眼白
	for x = -11, 11 do
		local h = math.floor(math.sqrt(math.max(0, 121 - x * x)) * 0.62 + 0.5)
		vline(ox, oy, 16 + x, 16 - h, 16 + h, M_GLOW)
	end
	-- 眼白上阴影
	for x = -11, 11 do
		local h = math.floor(math.sqrt(math.max(0, 121 - x * x)) * 0.62 + 0.5)
		px(ox, oy, 16 + x, 16 - h, M_LIGHT)
	end
	-- 虹膜
	circle(ox, oy, 16, 16, 5, M_MID, true)
	circle(ox, oy, 16, 16, 4, M_LIGHT, true)
	-- 瞳孔（竖瞳）
	for y = -4, 4 do
		local w = 2 - math.floor(math.abs(y) / 3)
		hline(ox, oy, 16 - w, 16 + w, 16 + y, C(8, 0, 8))
	end
	-- 高光
	px(ox, oy, 14, 14, WHITE)
	px(ox, oy, 15, 14, WHITE)
	-- 血丝
	line(ox, oy, 6, 14, 10, 16, M_LIGHT)
	line(ox, oy, 26, 15, 22, 17, M_LIGHT)
	-- 眼睑
	line(ox, oy, 4, 16, 28, 16, C(40, 10, 34))
end

-- 10 献祭之血 —— 血滴落入掌心
drawers.sacrifice_blood = function(ox, oy)
	fill(ox, oy, M_DARK)
	-- 血滴（上方）
	circle(ox, oy, 16, 10, 4, M_LIGHT, true)
	vline(ox, oy, 16, 4, 6, M_LIGHT)
	px(ox, oy, 16, 3, M_GLOW)
	px(ox, oy, 14, 8, M_GLOW)
	-- 下落轨迹
	for y = 15, 20 do
		px(ox, oy, 16, y, M_MID)
		if y % 2 == 0 then
			px(ox, oy, 15, y, M_BASE)
			px(ox, oy, 17, y, M_BASE)
		end
	end
	-- 手掌（简化）
	rect(ox, oy, 7, 24, 25, 27, C(120, 80, 60))
	rect(ox, oy, 9, 22, 11, 24, C(120, 80, 60))
	rect(ox, oy, 14, 21, 18, 24, C(120, 80, 60))
	rect(ox, oy, 21, 22, 23, 24, C(120, 80, 60))
	-- 掌心血光
	circle(ox, oy, 16, 26, 3, M_MID, true)
	px(ox, oy, 16, 26, M_GLOW)
end

-- 11 应急医疗 —— 注射器
drawers.emergency_medkit = function(ox, oy)
	fill(ox, oy, N_DARK)
	-- 针筒
	rect(ox, oy, 12, 8, 20, 22, N_LIGHT)
	rect(ox, oy, 13, 9, 19, 21, C(210, 220, 226))
	-- 药液
	rect(ox, oy, 13, 14, 19, 21, GREEN)
	-- 刻度
	for y = 15, 20, 2 do
		hline(ox, oy, 13, 15, y, N_DARK)
	end
	-- 推杆
	rect(ox, oy, 14, 4, 18, 8, N_MID)
	rect(ox, oy, 12, 2, 20, 4, N_LIGHT)
	-- 针头
	vline(ox, oy, 16, 22, 29, N_GLOW)
	px(ox, oy, 16, 30, WHITE)
	-- 红十字标记
	hline(ox, oy, 22, 27, 10, RED)
	vline(ox, oy, 24, 8, 12, RED)
	px(ox, oy, 24, 10, RED_HI)
end

-- 12 逻辑锁 —— 锁 + 逻辑门
drawers.logic_lock = function(ox, oy)
	fill(ox, oy, N_DARK)
	-- 锁体
	rect(ox, oy, 9, 14, 23, 27, N_MID)
	rect(ox, oy, 10, 15, 22, 26, N_BASE)
	-- 锁梁
	for x = 0, 0 do end
	rect(ox, oy, 12, 6, 13, 14, N_LIGHT)
	rect(ox, oy, 19, 6, 20, 14, N_LIGHT)
	rect(ox, oy, 13, 5, 19, 6, N_LIGHT)
	-- 锁孔
	circle(ox, oy, 16, 20, 2, N_GLOW, true)
	vline(ox, oy, 16, 21, 24, N_GLOW)
	-- 电路纹路
	hline(ox, oy, 4, 9, 18, P_MID)
	hline(ox, oy, 23, 28, 22, P_MID)
	px(ox, oy, 4, 18, P_LIGHT)
	px(ox, oy, 28, 22, P_LIGHT)
	-- 数据点
	px(ox, oy, 6, 10, P_LIGHT)
	px(ox, oy, 26, 27, P_LIGHT)
end

-- ============================================================
-- 升级版（用同一套图形，加一层金色描边 + 角标区分）
-- 这里先各自画一次基础图形，再叠加角标
-- ============================================================
local upgrades = {
	"calibrate_shot_plus",
	"lacerate_plus",
	"force_shield_plus",
	"framework_scan_plus",
	"precision_strike_plus",
	"logic_lock_plus",
	"flesh_reshape_plus",
}

local order_art = {
	"calibrate_shot", "precision_strike", "force_shield", "framework_scan", "overclock",
	"lacerate", "parasite_spore", "flesh_reshape", "abyss_gaze", "sacrifice_blood",
	"emergency_medkit", "logic_lock",
}

-- ---------- 先画 12 张基础卡 ----------
local placed = {}
local index = 0
for _, name in ipairs(order_art) do
	local col = index % COLS
	local row = math.floor(index / COLS)
	local ox = col * CELL
	local oy = row * CELL
	drawers[name](ox, oy)
	placed[name] = { x = ox, y = oy }
	index = index + 1
end

-- ---------- 再画 7 张升级版（基础图形 + 金色角标）----------
local upgrade_base = {
	calibrate_shot_plus = "calibrate_shot",
	lacerate_plus = "lacerate",
	force_shield_plus = "force_shield",
	framework_scan_plus = "framework_scan",
	precision_strike_plus = "precision_strike",
	logic_lock_plus = "logic_lock",
	flesh_reshape_plus = "flesh_reshape",
}

for _, up_name in ipairs(upgrades) do
	local base = upgrade_base[up_name]
	local col = index % COLS
	local row = math.floor(index / COLS)
	local ox = col * CELL
	local oy = row * CELL
	drawers[base](ox, oy)
	-- 四角金标
	local GOLD = C(240, 196, 88)
	rect(ox, oy, 1, 1, 4, 2, GOLD)
	rect(ox, oy, 27, 1, 30, 2, GOLD)
	rect(ox, oy, 1, 29, 4, 30, GOLD)
	rect(ox, oy, 27, 29, 30, 30, GOLD)
	-- 右上角升级箭头
	px(ox, oy, 26, 6, GOLD)
	px(ox, oy, 25, 5, GOLD)
	px(ox, oy, 27, 5, GOLD)
	placed[up_name] = { x = ox, y = oy }
	index = index + 1
end

-- ============================================================
-- 导出
-- ============================================================
local out_dir = "assets/art/cards/"
app.fs.makeDirectory(out_dir)
spr:saveAs(out_dir .. "cards_art.png")

-- 写一份 JSON 索引，供 Godot 读取
local f = io.open(out_dir .. "cards_art.json", "w")
f:write("{\n")
f:write("  \"cell\": " .. CELL .. ",\n")
f:write("  \"cols\": " .. COLS .. ",\n")
f:write("  \"rows\": " .. ROWS .. ",\n")
f:write("  \"frames\": {\n")
local first = true
for name, p in pairs(placed) do
	if not first then f:write(",\n") end
	first = false
	f:write(string.format("    \"%s\": {\"x\": %d, \"y\": %d}", name, p.x, p.y))
end
f:write("\n  }\n}\n")
f:close()

print("生成完成：共 " .. index .. " 张卡面 -> " .. out_dir .. "cards_art.png")
