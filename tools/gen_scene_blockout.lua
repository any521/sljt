-- 战斗场景结构参考图（blockout 灰盒）
-- 用途：给 AI 当构图参考（img2img / ControlNet），或给美术当布局依据
-- 运行：aseprite.exe -b --script tools/gen_scene_blockout.lua
-- 输出：build/scene_blockout.png (1280x720)

local W, H = 1280, 720

local spr = Sprite(W, H, ColorMode.RGB)
local img = spr.cels[1].image

local function C(r, g, b)
	return Color(r, g, b, 255)
end

local function put(x, y, c)
	if x >= 0 and x < W and y >= 0 and y < H then
		img:putPixel(x, y, c)
	end
end

local function rect(x0, y0, x1, y1, c, filled)
	for y = math.min(y0, y1), math.max(y0, y1) do
		for x = math.min(x0, x1), math.max(x0, x1) do
			if filled then
				put(x, y, c)
			else
				if x == x0 or x == x1 or y == y0 or y == y1 then
					put(x, y, c)
				end
			end
		end
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

-- ============================================================
-- 配色
-- ============================================================
local BG      = C(10, 13, 19)
local WIRE    = C(110, 138, 168)     -- 主结构线
local WIRE_D  = C(58, 74, 96)        -- 次级结构线（地板网格）
local WIRE_F  = C(30, 40, 54)        -- 填充（暗面）

local ZONE_CHAR = C(107, 199, 255)   -- 角色站位区（青）
local ZONE_ENEM = C(224, 87, 95)     -- 敌人站位区（红）
local ZONE_CARD = C(232, 168, 48)    -- 卡牌区（黄）
local ZONE_UI   = C(140, 150, 165)   -- UI 区（灰）

-- ============================================================
-- 1) 铺底
-- ============================================================
rect(0, 0, W - 1, H - 1, BG, true)

-- ============================================================
-- 2) 一点透视的房间
--    后墙矩形 + 四条角线连到画面四角 → 形成走廊/舱室
-- ============================================================
local bx0, by0, bx1, by1 = 400, 210, 880, 510   -- 后墙

-- 后墙填充（略亮，表示是墙的正面）
rect(bx0, by0, bx1, by1, WIRE_F, true)
rect(bx0, by0, bx1, by1, WIRE, false)

-- 四条角线
line(0, 0, bx0, by0, WIRE)          -- 左上：天花板与左墙交界
line(W - 1, 0, bx1, by0, WIRE)      -- 右上
line(0, H - 1, bx0, by1, WIRE)      -- 左下：地板与左墙交界
line(W - 1, H - 1, bx1, by1, WIRE)  -- 右下

-- ============================================================
-- 3) 地板透视网格（横线：近疏远密）
-- ============================================================
for i = 1, 7 do
	local t = i / 8.0
	local e = t * t                      -- 近大远小的近似
	local y = math.floor(by1 + (H - 1 - by1) * e)
	local xl = math.floor(bx0 + (0 - bx0) * e)
	local xr = math.floor(bx1 + (W - 1 - bx1) * e)
	line(xl, y, xr, y, WIRE_D)
end

-- 地板纵向线（从后墙底边放射到画面底边）
for i = 0, 8 do
	local t = i / 8.0
	local xb = math.floor(bx0 + (bx1 - bx0) * t)
	local xf = math.floor(0 + (W - 1) * t)
	line(xb, by1, xf, H - 1, WIRE_D)
end

-- ============================================================
-- 4) 结构体块（灰盒）
-- ============================================================
-- 左侧储物柜组
rect(120, 300, 240, 520, WIRE, false)
line(120, 300, 80, 280, WIRE)
line(240, 300, 210, 280, WIRE)
line(80, 280, 210, 280, WIRE)
line(80, 280, 80, 500, WIRE)
line(210, 280, 210, 500, WIRE)
line(80, 500, 120, 520, WIRE)
line(210, 500, 240, 520, WIRE)

-- 右侧管道
rect(1000, 150, 1090, 470, WIRE_D, false)
line(1000, 150, 960, 130, WIRE_D)
line(1090, 150, 1050, 130, WIRE_D)
line(960, 130, 1050, 130, WIRE_D)

-- 后墙上的舱门
rect(590, 300, 700, 470, WIRE, false)
rect(600, 310, 690, 460, WIRE_D, false)

-- 地板上的一个箱子
rect(760, 560, 860, 630, WIRE, false)
line(760, 560, 800, 540, WIRE)
line(860, 560, 900, 540, WIRE)
line(800, 540, 900, 540, WIRE)
line(800, 540, 800, 610, WIRE_D)
line(900, 540, 900, 610, WIRE_D)
line(800, 610, 860, 630, WIRE_D)

-- ============================================================
-- 5) 游戏占用区标注（虚线框，告诉 AI 这些地方要留空/压暗）
-- ============================================================
local function dashed_rect(x0, y0, x1, y1, c, dash)
	local x = x0
	while x <= x1 do
		for i = 0, dash - 1 do
			put(x + i, y0, c)
			put(x + i, y1, c)
		end
		x = x + dash * 2
	end
	local y = y0
	while y <= y1 do
		for i = 0, dash - 1 do
			put(x0, y + i, c)
			put(x1, y + i, c)
		end
		y = y + dash * 2
	end
end

-- 角色站位区（左下）
dashed_rect(20, 500, 330, 700, ZONE_CHAR, 6)
-- 敌人站位区（右上）
dashed_rect(760, 120, 1180, 420, ZONE_ENEM, 6)
-- 卡牌区（底部中央）
dashed_rect(420, 560, 1080, 700, ZONE_CARD, 6)
-- UI 区（左上 / 左中 / 右下）
dashed_rect(10, 10, 240, 330, ZONE_UI, 6)
dashed_rect(10, 345, 240, 520, ZONE_UI, 6)
dashed_rect(1080, 460, 1270, 700, ZONE_UI, 6)

app.fs.makeDirectory("build")
spr:saveAs("build/scene_blockout.png")
print("结构参考图已生成: build/scene_blockout.png (" .. W .. "x" .. H .. ")")
print("青框=角色站位  红框=敌人站位  黄框=卡牌区  灰框=UI区")
