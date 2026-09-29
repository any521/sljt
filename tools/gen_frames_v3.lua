-- ============================================================
-- 《阿卡姆号》卡框 —— 程序生成（精确比例版）
--
-- 卡框逻辑尺寸 103x175（比例 1:1.70，标准卡牌比例）
-- 游戏内放大 2 倍使用：206x350
--
-- 结构分区（逻辑像素）：
--   标题栏 + 费用位   y 4..22
--   插画窗口          y 26..120   (94px，占卡高 54%)
--   文字面板          y 126..166  (40px，占卡高 23%)
--
-- 输出：assets/art/cards/frames_v3.png（4 种归属横排）
-- 运行：aseprite.exe -b --script tools/gen_frames_v3.lua
-- ============================================================

local W = 103
local H = 175
local COLS = 4
local ROUND = 4

local spr = Sprite(W * COLS, H, ColorMode.RGB)
local img = spr.cels[1].image

local function C(r, g, b)
	return Color(r, g, b, 255)
end

local function put(ox, lx, ly, col)
	if lx < 0 or lx >= W or ly < 0 or ly >= H then return end
	img:putPixel(ox + lx, ly, col)
end

local function rect(ox, x0, y0, x1, y1, col)
	for ly = math.min(y0, y1), math.max(y0, y1) do
		for lx = math.min(x0, x1), math.max(x0, x1) do
			put(ox, lx, ly, col)
		end
	end
end

local function circle(ox, cx, cy, r, fill_col, edge_col)
	for ly = cy - r - 1, cy + r + 1 do
		for lx = cx - r - 1, cx + r + 1 do
			local dx = lx - cx
			local dy = ly - cy
			local d = math.sqrt(dx * dx + dy * dy)
			if d <= r - 1 then
				put(ox, lx, ly, fill_col)
			elseif d <= r + 0.2 then
				put(ox, lx, ly, edge_col)
			end
		end
	end
end

-- ---------- 通用色 ----------
local OUTLINE  = C(9, 12, 19)
local BODY     = C(30, 38, 56)
local BODY_LIT = C(38, 48, 70)
local ART_BG   = C(10, 13, 19)
local TEXT_BG  = C(22, 28, 43)
local EDGE_HI  = C(58, 74, 102)

-- ---------- 归属色 ----------
local FACTIONS = {
	{ dark = C(26, 58, 82),  base = C(58, 130, 178),  light = C(107, 199, 255) },
	{ dark = C(66, 16, 54),  base = C(140, 42, 112),  light = C(199, 71, 158) },
	{ dark = C(46, 53, 61),  base = C(96, 106, 114),  light = C(160, 170, 178) },
	{ dark = C(112, 88, 28), base = C(214, 176, 70),  light = C(255, 224, 140) },
}

-- ---------- 分区常量 ----------
local GEM_CX, GEM_CY, GEM_R = 17, 14, 9
local BAND_X0, BAND_Y0, BAND_X1, BAND_Y1 = 27, 8, 96, 19
local AW_X0, AW_Y0, AW_X1, AW_Y1 = 8, 26, 94, 120
local TP_X0, TP_Y0, TP_X1, TP_Y1 = 8, 126, 94, 166

local function inside_round(lx, ly)
	local cx = math.min(math.max(lx, ROUND), W - 1 - ROUND)
	local cy = math.min(math.max(ly, ROUND), H - 1 - ROUND)
	local dx, dy = lx - cx, ly - cy
	return dx * dx + dy * dy <= ROUND * ROUND
end

local function draw_frame(ox, pal)
	-- 1) 卡体（圆角 + 描边）
	for ly = 0, H - 1 do
		for lx = 0, W - 1 do
			if inside_round(lx, ly) then
				local edge = math.min(math.min(lx, W - 1 - lx), math.min(ly, H - 1 - ly))
				local col = BODY
				if edge <= 1 then col = OUTLINE
				elseif edge == 2 then col = pal.dark
				elseif edge == 3 then col = pal.base
				elseif edge == 4 then col = EDGE_HI
				end
				put(ox, lx, ly, col)
			end
		end
	end

	-- 2) 左上加粗 + 右侧受光（打破均匀厚度）
	rect(ox, 5, 5, 6, H - 6, BODY_LIT)
	rect(ox, W - 6, 5, W - 5, H - 6, EDGE_HI)

	-- 3) 四角装饰
	local b = 9
	rect(ox, 3, 3, 3 + b, 4, pal.light)
	rect(ox, 3, 3, 4, 3 + b, pal.light)
	rect(ox, W - 4 - b, 3, W - 4, 4, pal.light)
	rect(ox, W - 5, 3, W - 4, 3 + b, pal.light)
	rect(ox, 3, H - 5, 3 + b, H - 4, pal.light)
	rect(ox, 3, H - 4 - b, 4, H - 4, pal.light)
	rect(ox, W - 4 - b, H - 5, W - 4, H - 4, pal.light)
	rect(ox, W - 5, H - 4 - b, W - 4, H - 4, pal.light)

	-- 4) 标题色带
	rect(ox, BAND_X0, BAND_Y0, BAND_X1, BAND_Y1, pal.dark)
	rect(ox, BAND_X0, BAND_Y0 + 2, BAND_X1, BAND_Y1 - 2, pal.base)
	rect(ox, BAND_X0, BAND_Y0 + 3, BAND_X1, BAND_Y0 + 4, pal.light)
	rect(ox, BAND_X0, BAND_Y1 - 1, BAND_X1, BAND_Y1, pal.dark)

	-- 5) 费用位（圆形，内部用中等灰蓝，方便叠金色数字）
	circle(ox, GEM_CX, GEM_CY, GEM_R, C(58, 74, 102), C(9, 12, 19))
	circle(ox, GEM_CX, GEM_CY, GEM_R - 2, C(38, 48, 70), pal.base)

	-- 6) 插画窗口（占卡高 54%）
	rect(ox, AW_X0 + 1, AW_Y0 + 1, AW_X1 - 1, AW_Y1 - 1, ART_BG)
	rect(ox, AW_X0, AW_Y0, AW_X1, AW_Y0 + 1, OUTLINE)
	rect(ox, AW_X0, AW_Y1 - 1, AW_X1, AW_Y1, OUTLINE)
	rect(ox, AW_X0, AW_Y0, AW_X0 + 1, AW_Y1, OUTLINE)
	rect(ox, AW_X1 - 1, AW_Y0, AW_X1, AW_Y1, OUTLINE)
	-- 左上内嵌高光
	rect(ox, AW_X0 + 1, AW_Y0 + 1, AW_X1 - 1, AW_Y0 + 1, EDGE_HI)

	-- 7) 文字面板（占卡高 23%）
	rect(ox, TP_X0 + 1, TP_Y0 + 1, TP_X1 - 1, TP_Y1 - 1, TEXT_BG)
	rect(ox, TP_X0, TP_Y0, TP_X1, TP_Y0 + 1, EDGE_HI)
	rect(ox, TP_X0, TP_Y1 - 1, TP_X1, TP_Y1, OUTLINE)
	rect(ox, TP_X0, TP_Y0, TP_X0 + 1, TP_Y1, EDGE_HI)
	rect(ox, TP_X1 - 1, TP_Y0, TP_X1, TP_Y1, OUTLINE)

	-- 8) 侧边点缀
	rect(ox, 1, 55, 2, 88, pal.base)
	rect(ox, W - 3, 55, W - 2, 88, pal.base)
end

for i = 1, 4 do
	draw_frame((i - 1) * W, FACTIONS[i])
end

app.fs.makeDirectory("assets/art/cards")
spr:saveAs("assets/art/cards/frames_v3.png")
print("卡框 v3 生成完成 -> assets/art/cards/frames_v3.png (" .. spr.width .. "x" .. spr.height .. ")")
print("比例: " .. W .. "x" .. H .. " = 1:" .. string.format("%.2f", H / W))
print("插画窗口高度占比: " .. string.format("%.0f%%", (AW_Y1 - AW_Y0) / H * 100))
print("文字面板高度占比: " .. string.format("%.0f%%", (TP_Y1 - TP_Y0) / H * 100))
