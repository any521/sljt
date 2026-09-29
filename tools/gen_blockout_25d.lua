-- 2.5D（HD-2D）战斗场景结构参考图
-- 与普通 blockout 的区别：标出【纵深层次】与【清晰/虚化分区】，
-- 以及【体积光束】的来向和落点。这是 HD-2D 的组织方式。
--
-- 运行：aseprite.exe -b --script tools/gen_blockout_25d.lua
-- 输出：build/blockout_25d.png (1280x720)

local W, H = 1280, 720

local spr = Sprite(W, H, ColorMode.RGB)
local img = spr.cels[1].image

local function C(r, g, b, a)
	return Color(r, g, b, a or 255)
end

local function put(x, y, c)
	if x >= 0 and x < W and y >= 0 and y < H then
		img:putPixel(x, y, c)
	end
end

local function fill(x0, y0, x1, y1, c)
	for y = math.max(0, y0), math.min(H - 1, y1) do
		for x = math.max(0, x0), math.min(W - 1, x1) do
			put(x, y, c)
		end
	end
end

local function frame(x0, y0, x1, y1, c)
	for x = x0, x1 do
		put(x, y0, c); put(x, y1, c)
	end
	for y = y0, y1 do
		put(x0, y, c); put(x1, y, c)
	end
end

local function line(x0, y0, x1, y1, c)
	local dx = math.abs(x1 - x0)
	local dy = math.abs(y1 - y0)
	local sx = (x0 < x1) and 1 or -1
	local sy = (y0 < y1) and 1 or -1
	local err = dx - dy
	local x, y = x0, y0
	while true do
		put(x, y, c)
		if x == x1 and y == y1 then break end
		local e2 = 2 * err
		if e2 > -dy then err = err - dy; x = x + sx end
		if e2 < dx then err = err + dx; y = y + sy end
	end
end

-- 虚线框
local function dash_box(x0, y0, x1, y1, c, d)
	local x = x0
	while x <= x1 do
		for i = 0, d - 1 do
			put(math.min(x + i, x1), y0, c)
			put(math.min(x + i, x1), y1, c)
		end
		x = x + d * 2
	end
	local y = y0
	while y <= y1 do
		for i = 0, d - 1 do
			put(x0, math.min(y + i, y1), c)
			put(x1, math.min(y + i, y1), c)
		end
		y = y + d * 2
	end
end

-- 斜面四边形（用于体积光束）
local function quad(p1, p2, p3, p4, c)
	-- 用扫描线近似填充：按 y 插值左右边界
	local ymin = math.min(p1[2], p2[2], p3[2], p4[2])
	local ymax = math.max(p1[2], p2[2], p3[2], p4[2])
	for y = ymin, ymax do
		local xs = {}
		local edges = { { p1, p2 }, { p2, p3 }, { p3, p4 }, { p4, p1 } }
		for _, e in ipairs(edges) do
			local a, b = e[1], e[2]
			local y1, y2 = a[2], b[2]
			if y1 ~= y2 and y >= math.min(y1, y2) and y <= math.max(y1, y2) then
				local t = (y - y1) / (y2 - y1)
				table.insert(xs, math.floor(a[1] + (b[1] - a[1]) * t))
			end
		end
		if #xs >= 2 then
			table.sort(xs)
			for x = xs[1], xs[#xs] do
				put(x, y, c)
			end
		end
	end
end

-- ============================================================
-- 配色
-- ============================================================
local BG        = C(9, 11, 16)
local WIRE      = C(110, 138, 168)
local WIRE_D    = C(52, 68, 90)
local FILL_FAR  = C(16, 21, 32)
local FILL_MID  = C(22, 29, 42)
local FILL_NEAR = C(11, 14, 21)

local BEAM      = C(38, 66, 92)      -- 体积光束（半透明感：用暗青表示）
local ZONE_CHAR = C(107, 199, 255)
local ZONE_ENEM = C(224, 87, 95)
local ZONE_CARD = C(232, 168, 48)
local BAND_LINE = C(150, 170, 195)

-- ============================================================
-- 1) 铺底
-- ============================================================
fill(0, 0, W - 1, H - 1, BG)

-- ============================================================
-- 2) 三个纵深带（HD-2D 的核心组织方式）
--    远景 y 90..300 / 中景 y 300..560 / 前景 y 560..720
-- ============================================================
fill(0, 90, W - 1, 299, FILL_FAR)     -- 远景：后墙区
fill(0, 300, W - 1, 559, FILL_MID)    -- 中景：开阔地板（角色战斗区）
fill(0, 560, W - 1, H - 1, FILL_NEAR) -- 前景：遮挡物 + 虚化

-- 分带虚线
for x = 0, W - 1, 16 do
	put(x, 300, BAND_LINE)
	put(x, 560, BAND_LINE)
end

-- ============================================================
-- 3) 空间结构（后墙 + 地板透视）
-- ============================================================
local bx0, by0, bx1, by1 = 340, 120, 940, 300
fill(bx0 + 1, by0 + 1, bx1 - 1, by1 - 1, C(20, 27, 40))
frame(bx0, by0, bx1, by1, WIRE)

-- 天花板斜线 + 侧墙斜线（连到画面四角）
line(0, 0, bx0, by0, WIRE_D)
line(W - 1, 0, bx1, by0, WIRE_D)
line(0, H - 1, bx0, by1, WIRE_D)
line(W - 1, H - 1, bx1, by1, WIRE_D)

-- 地板透视网格（近疏远密）
for i = 1, 6 do
	local t = i / 7.0
	local e = t * t
	local y = math.floor(by1 + (H - 1 - by1) * e)
	local xl = math.floor(bx0 + (0 - bx0) * e)
	local xr = math.floor(bx1 + (W - 1 - bx1) * e)
	line(xl, y, xr, y, WIRE_D)
end
-- 地板纵向放射线
for i = 0, 10 do
	local t = i / 10.0
	local xb = math.floor(bx0 + (bx1 - bx0) * t)
	local xf = math.floor(0 + (W - 1) * t)
	line(xb, by1, xf, H - 1, WIRE_D)
end

-- 后墙上的舱门 + 两侧设备
frame(600, 190, 700, 300, WIRE)
frame(360, 160, 450, 300, WIRE_D)
frame(830, 160, 920, 300, WIRE_D)

-- 左侧储物柜（前景偏中）
frame(60, 340, 200, 520, WIRE)
line(60, 340, 30, 318, WIRE)
line(200, 340, 172, 318, WIRE)
line(30, 318, 172, 318, WIRE)
line(30, 318, 30, 498, WIRE)
line(172, 318, 172, 498, WIRE)
line(30, 498, 60, 520, WIRE)
line(172, 498, 200, 520, WIRE)

-- 右侧管道
frame(1080, 150, 1160, 470, WIRE_D)
line(1080, 150, 1040, 128, WIRE_D)
line(1160, 150, 1120, 128, WIRE_D)
line(1040, 128, 1120, 128, WIRE_D)

-- 前景遮挡（底部一条护栏 + 一个箱子角）
frame(0, 660, W - 1, 700, C(70, 86, 110))
frame(900, 580, 1080, 690, C(70, 86, 110))
line(900, 580, 950, 556, C(70, 86, 110))
line(1080, 580, 1130, 556, C(70, 86, 110))
line(950, 556, 1130, 556, C(70, 86, 110))

-- ============================================================
-- 4) 体积光束（HD-2D 的灵魂）
--    从天花板斜射到中景地板，形成可见的光柱
-- ============================================================
quad({ 300, 90 }, { 420, 90 }, { 560, 470 }, { 400, 470 }, BEAM)
quad({ 780, 90 }, { 880, 90 }, { 900, 430 }, { 760, 430 }, BEAM)

-- 光束落到地板上的光斑（亮一点）
line(400, 470, 560, 470, C(90, 150, 190))
line(760, 430, 900, 430, C(90, 150, 190))

-- ============================================================
-- 5) 先保存「干净版」——只有结构，没有虚线标注
--    这一版是给 AI 当参考图用的（避免 AI 把虚线也画进场景）
-- ============================================================
app.fs.makeDirectory("build")
spr:saveAs("build/blockout_25d_clean.png")
print("干净版（给 AI 参考）: build/blockout_25d_clean.png")

-- ============================================================
-- 6) 再叠加游戏占用区标注，保存「带标注版」——给人看的
-- ============================================================
dash_box(30, 380, 300, 660, ZONE_CHAR, 7)      -- 角色站位（左，中景）
dash_box(820, 140, 1240, 380, ZONE_ENEM, 7)    -- 敌人站位（右，远景偏中）
dash_box(400, 590, 900, 710, ZONE_CARD, 7)     -- 卡牌区（底部中央）
dash_box(920, 470, 1270, 700, C(140, 150, 165), 7)  -- UI（右下）

spr:saveAs("build/blockout_25d.png")
print("带标注版（给人看）: build/blockout_25d.png")
print("")
print("图例：")
print("  浅蓝横线  y=300  远景/中景 分界")
print("  浅蓝横线  y=560  中景/前景 分界")
print("  暗青光柱          体积光束（从天花板射到中景地板）")
print("  青色虚线框        角色站位")
print("  红色虚线框        敌人站位")
print("  黄色虚线框        卡牌区")
print("  灰色虚线框        UI 区")
