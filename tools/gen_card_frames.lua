-- ============================================================
-- 《阿卡姆号》卡框生成脚本 v2 —— 修正比例问题
--
-- v1 的错误：插画窗口 87x37（长方形），把 32x32 的正方形卡面
--             非等比拉伸进去，画面被压扁。
-- v2 的修正：插画窗口改为严格的 80x80 正方形，
--             32x32 卡面按 2.5 倍整数放大，绝不拉伸。
--
-- 卡牌游戏内尺寸 206x350。卡框按 2x 像素密度绘制：103x175 逻辑像素。
-- 所有颜色遵守 docs/阿卡姆号-美术基调-v1.0.md
-- 运行：aseprite.exe -b --script tools/gen_card_frames.lua
-- ============================================================

local W = 103
local H = 175
local COLS = 4
local ROWS = 2

local spr = Sprite(W * COLS, H * ROWS, ColorMode.RGB)
local img = spr.cels[1].image

-- ============================================================
-- 绘制工具
-- ============================================================
local function C(r, g, b)
	return Color(r, g, b, 255)
end

local function put(cell_x, cell_y, local_x, local_y, col)
	if type(local_x) ~= "number" or type(local_y) ~= "number" then
		return
	end
	if local_x < 0 or local_x >= W or local_y < 0 or local_y >= H then
		return
	end
	img:putPixel(cell_x + local_x, cell_y + local_y, col)
end

local function fill_rect(cell_x, cell_y, x0, y0, x1, y1, col)
	for ly = math.min(y0, y1), math.max(y0, y1) do
		for lx = math.min(x0, x1), math.max(x0, x1) do
			put(cell_x, cell_y, lx, ly, col)
		end
	end
end

-- ============================================================
-- 配色（提高对比度：卡体提亮、面板压暗，两个区域才分得开）
-- ============================================================
local C_OUTLINE = C(8, 10, 15)      -- 最外描边
local C_BODY    = C(22, 27, 38)     -- 卡体（提亮）
local C_PANEL   = C(10, 13, 19)     -- 内嵌面板（压暗）
local C_DIVIDER = C(38, 46, 60)     -- 分割线

local PROTOCOL = { dark = C(26, 58, 82),  base = C(58, 130, 178),  light = C(107, 199, 255) }
local MUTATION = { dark = C(66, 16, 54),  base = C(140, 42, 112),  light = C(199, 71, 158) }
local NEUTRAL  = { dark = C(46, 53, 61),  base = C(96, 106, 114),  light = C(160, 170, 178) }
local UPGRADED = { dark = C(112, 88, 28), base = C(214, 176, 70),  light = C(255, 224, 140) }

-- ============================================================
-- 卡牌分区（逻辑像素坐标）
-- ============================================================
local R = 6                      -- 圆角半径
local ART_X, ART_Y = 11, 30      -- 插画窗口左上角
local ART_SIZE = 81              -- 插画窗口边长（正方形！）
local NAME_Y = 16                -- 名称条
local TEXT_Y0, TEXT_Y1 = 118, 166 -- 文字面板

local function inside_round_rect(x, y)
	local cx = math.min(math.max(x, R), W - 1 - R)
	local cy = math.min(math.max(y, R), H - 1 - R)
	local dx = x - cx
	local dy = y - cy
	return (dx * dx + dy * dy) <= (R * R)
end

-- ============================================================
-- 卡框绘制
-- ============================================================
local function draw_frame(cell_x, cell_y, pal)
	-- 1) 卡体（圆角 + 边缘分层）
	for ly = 0, H - 1 do
		for lx = 0, W - 1 do
			if inside_round_rect(lx, ly) then
				local edge = math.min(math.min(lx, W - 1 - lx), math.min(ly, H - 1 - ly))
				local col = C_BODY
				if edge <= 1 then
					col = C_OUTLINE
				elseif edge == 2 then
					col = pal.dark
				elseif edge == 3 then
					col = pal.base
				elseif edge == 4 then
					col = C(14, 18, 26)
				end
				put(cell_x, cell_y, lx, ly, col)
			end
		end
	end

	-- 2) 四角装饰括号
	local br = 9
	fill_rect(cell_x, cell_y, 3, 3, 3 + br, 4, pal.light)
	fill_rect(cell_x, cell_y, 3, 3, 4, 3 + br, pal.light)
	fill_rect(cell_x, cell_y, W - 4 - br, 3, W - 4, 4, pal.light)
	fill_rect(cell_x, cell_y, W - 5, 3, W - 4, 3 + br, pal.light)
	fill_rect(cell_x, cell_y, 3, H - 5, 3 + br, H - 4, pal.light)
	fill_rect(cell_x, cell_y, 3, H - 4 - br, 4, H - 4, pal.light)
	fill_rect(cell_x, cell_y, W - 4 - br, H - 5, W - 4, H - 4, pal.light)
	fill_rect(cell_x, cell_y, W - 5, H - 4 - br, W - 4, H - 4, pal.light)

	-- 3) 顶部归属色条
	fill_rect(cell_x, cell_y, 7, 5, W - 8, 9, pal.dark)
	fill_rect(cell_x, cell_y, 7, 6, W - 8, 8, pal.base)
	fill_rect(cell_x, cell_y, 7, 6, W - 8, 6, pal.light)

	-- 4) 名称条（插画上方的一道浅色分隔）
	fill_rect(cell_x, cell_y, 8, NAME_Y, W - 9, NAME_Y, C_DIVIDER)
	fill_rect(cell_x, cell_y, 8, NAME_Y + 1, W - 9, NAME_Y + 1, C(16, 20, 28))

	-- 5) 插画窗口（★ 严格正方形，绝不拉伸）
	--    内部填纯黑，作为卡面的底
	fill_rect(cell_x, cell_y, ART_X, ART_Y, ART_X + ART_SIZE - 1, ART_Y + ART_SIZE - 1, C(6, 8, 12))
	-- 外框：内暗外亮，做出内嵌感
	fill_rect(cell_x, cell_y, ART_X - 2, ART_Y - 2, ART_X + ART_SIZE + 1, ART_Y - 1, C_OUTLINE)
	fill_rect(cell_x, cell_y, ART_X - 2, ART_Y + ART_SIZE, ART_X + ART_SIZE + 1, ART_Y + ART_SIZE + 1, C_OUTLINE)
	fill_rect(cell_x, cell_y, ART_X - 2, ART_Y - 2, ART_X - 1, ART_Y + ART_SIZE + 1, C_OUTLINE)
	fill_rect(cell_x, cell_y, ART_X + ART_SIZE, ART_Y - 2, ART_X + ART_SIZE + 1, ART_Y + ART_SIZE + 1, C_OUTLINE)
	-- 内侧一条亮的细节线（左上）
	fill_rect(cell_x, cell_y, ART_X - 1, ART_Y - 1, ART_X + ART_SIZE, ART_Y - 1, pal.dark)
	fill_rect(cell_x, cell_y, ART_X - 1, ART_Y - 1, ART_X - 1, ART_Y + ART_SIZE, pal.dark)

	-- 6) 文字面板
	fill_rect(cell_x, cell_y, 9, TEXT_Y0, W - 10, TEXT_Y1, C_PANEL)
	fill_rect(cell_x, cell_y, 9, TEXT_Y0, W - 10, TEXT_Y0 + 1, C_DIVIDER)
	fill_rect(cell_x, cell_y, 9, TEXT_Y1 - 1, W - 10, TEXT_Y1, C(30, 36, 48))
	fill_rect(cell_x, cell_y, 9, TEXT_Y0, 10, TEXT_Y1, C(30, 36, 48))
	fill_rect(cell_x, cell_y, W - 11, TEXT_Y0, W - 10, TEXT_Y1, C(30, 36, 48))

	-- 7) 左右侧边归属点缀
	fill_rect(cell_x, cell_y, 1, 50, 2, 76, pal.base)
	fill_rect(cell_x, cell_y, W - 3, 50, W - 2, 76, pal.base)
end

local palettes = { PROTOCOL, MUTATION, NEUTRAL, UPGRADED }
for i = 1, 4 do
	local col = (i - 1) % COLS
	local row = math.floor((i - 1) / COLS)
	draw_frame(col * W, row * H, palettes[i])
end

-- ============================================================
-- 费用宝石（32x32，第 2 行第 1 格居中）
-- ============================================================
do
	local gx = 0 * W
	local gy = 1 * H
	local size = 32
	local ox = math.floor((W - size) / 2)
	local oy = math.floor((H - size) / 2)
	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local d = math.abs(x - 15.5) + math.abs(y - 15.5)
			if d <= 15.5 then
				local col
				if d >= 13.5 then
					col = C(45, 54, 68)
				elseif d >= 12 then
					col = C(90, 104, 122)
				elseif d >= 10 then
					col = C(176, 134, 36)
				elseif d >= 7.5 then
					col = C(232, 186, 60)
				elseif d >= 5 then
					col = C(255, 214, 110)
				else
					col = C(255, 236, 172)
				end
				put(gx, gy, ox + x, oy + y, col)
			end
		end
	end
	local bolt = {
		{ 0, -8 }, { 1, -8 }, { 2, -8 },
		{ -2, -6 }, { -1, -6 }, { 0, -6 }, { 1, -6 },
		{ -1, -4 }, { 0, -4 }, { 1, -4 }, { 2, -4 }, { 3, -4 },
		{ 0, -2 }, { 1, -2 }, { 2, -2 },
		{ -1, 0 }, { 0, 0 }, { 1, 0 },
		{ -2, 2 }, { -1, 2 }, { 0, 2 },
		{ -3, 4 }, { -2, 4 }, { -1, 4 },
		{ -4, 6 }, { -3, 6 }, { -2, 6 },
	}
	for _, p in ipairs(bolt) do
		put(gx, gy, ox + 16 + p[1], oy + 16 + p[2], C(58, 38, 8))
	end
end

-- ============================================================
-- 归属菱形图标（第 2 行第 2 格，三个横排）
-- ============================================================
do
	local gx = 1 * W
	local gy = 1 * H
	local icons = { PROTOCOL, MUTATION, NEUTRAL }
	for i = 1, 3 do
		local pal = icons[i]
		local cx = 20 + (i - 1) * 32
		local cy = math.floor(H / 2)
		local r = 11
		for dy = -r, r do
			for dx = -r, r do
				local d = math.abs(dx) + math.abs(dy)
				if d <= r then
					local col
					if d >= r - 1 then
						col = pal.light
					elseif d >= r - 4 then
						col = pal.base
					elseif d >= r - 7 then
						col = pal.dark
					else
						col = pal.light
					end
					put(gx, gy, cx + dx, cy + dy, col)
				end
			end
		end
	end
end

-- ============================================================
-- 导出
-- ============================================================
app.fs.makeDirectory("assets/art/cards")
spr:saveAs("assets/art/cards/frames.png")

print("卡框 v2 生成完成 -> assets/art/cards/frames.png (" .. spr.width .. "x" .. spr.height .. ")")
print("卡框尺寸: " .. W .. "x" .. H .. " 逻辑像素（游戏内 " .. (W * 2) .. "x" .. (H * 2) .. "）")
print("★ 插画窗口: " .. ART_SIZE .. "x" .. ART_SIZE .. " 严格正方形，32x32 卡面按 2.5 倍等比放大")
print("  插画窗内边距: 左 " .. ART_X .. " / 右 " .. (W - ART_X - ART_SIZE) ..
	" / 上 " .. ART_Y .. " / 下 " .. (H - ART_Y - ART_SIZE))
