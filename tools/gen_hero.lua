-- ============================================================
-- 《阿卡姆号》主角立绘生成脚本
-- 沈越 —— 半眷化空间站操作员
--
-- 设计核心：左半边是人（冷青科幻），右半边在被吞（品红异化）
-- 铁律：强制不对称；分界线是"被从内部撑开的接缝"
-- 依据：docs/阿卡姆号-美术基调-v1.0.md
--
-- 输出：assets/art/character/shen_yue.png（3 帧横排，每帧 64x64）
-- 运行：aseprite.exe -b --script tools/gen_hero.lua
-- ============================================================

local CELL = 64
local FRAMES = 3

local spr = Sprite(CELL * FRAMES, CELL, ColorMode.RGB)
local img = spr.cels[1].image

-- ---------- 工具 ----------
local function C(r, g, b)
	return Color(r, g, b, 255)
end

local function put(ox, cell_y, lx, ly, col)
	if lx < 0 or lx >= CELL or ly < 0 or ly >= CELL then return end
	img:putPixel(ox + lx, cell_y + ly, col)
end

local function fill_rect(ox, oy, x0, y0, x1, y1, col)
	for ly = math.min(y0, y1), math.max(y0, y1) do
		for lx = math.min(x0, x1), math.max(x0, x1) do
			put(ox, oy, lx, ly, col)
		end
	end
end

local function hline(ox, oy, x0, x1, y, col)
	for x = math.min(x0, x1), math.max(x0, x1) do
		put(ox, oy, x, y, col)
	end
end

local function vline(ox, oy, x, y0, y1, col)
	for y = math.min(y0, y1), math.max(y0, y1) do
		put(ox, oy, x, y, col)
	end
end

-- ---------- 配色（严格取自美术基调）----------
-- 人类侧：工程系冷青
local H_OUT   = C(8, 10, 15)
local H_SUIT  = C(26, 34, 48)
local H_SUIT2 = C(38, 48, 66)
local H_SUIT3 = C(52, 64, 84)
local H_METAL = C(58, 130, 178)
local H_METAL_L = C(107, 199, 255)
local H_GLOW  = C(178, 232, 255)
-- 感染侧：异化系品红
local M_DARK  = C(26, 8, 24)
local M_TISSUE = C(72, 18, 58)
local M_FLESH = C(140, 42, 112)
local M_GLOW  = C(199, 71, 158)
local M_BRIGHT = C(255, 158, 220)
-- 通用
local SKIN    = C(198, 158, 128)
local SKIN_SH = C(150, 112, 88)
local VISOR   = C(20, 26, 36)
local VISOR_L = C(90, 170, 200)
local WHITE   = C(240, 246, 250)
local AMBER   = C(232, 168, 48)

-- ============================================================
-- 基础人形（站姿，正面偏侧 3/4）
-- ============================================================
local function draw_body(ox, oy, corruption)
	-- corruption: 0.0 = 完全人类, 1.0 = 深度异化

	-- 1) 腿部（靴子 + 护腿）
	fill_rect(ox, oy, 22, 50, 29, 60, H_SUIT)     -- 左腿
	fill_rect(ox, oy, 35, 50, 42, 60, H_SUIT)     -- 右腿
	fill_rect(ox, oy, 21, 59, 30, 62, H_SUIT2)    -- 左靴
	fill_rect(ox, oy, 34, 59, 43, 62, H_SUIT2)    -- 右靴
	-- 膝盖护甲
	fill_rect(ox, oy, 22, 53, 29, 54, H_SUIT3)
	fill_rect(ox, oy, 35, 53, 42, 54, H_SUIT3)

	-- 2) 躯干主体
	fill_rect(ox, oy, 21, 28, 43, 50, H_SUIT)
	-- 躯干亮面（左侧受光）
	fill_rect(ox, oy, 22, 29, 27, 49, H_SUIT2)
	-- 躯干暗面（右侧）
	fill_rect(ox, oy, 39, 29, 42, 49, H_OUT)

	-- 3) 胸前护甲板
	fill_rect(ox, oy, 25, 31, 39, 40, H_SUIT3)
	fill_rect(ox, oy, 26, 32, 38, 39, H_SUIT2)
	-- 胸口指示灯（冷青）
	fill_rect(ox, oy, 30, 34, 34, 36, H_METAL)
	fill_rect(ox, oy, 31, 35, 33, 35, H_GLOW)

	-- 4) 腰带
	fill_rect(ox, oy, 21, 47, 43, 49, H_SUIT2)
	fill_rect(ox, oy, 31, 46, 33, 50, H_METAL)

	-- 5) 肩甲（左肩金属，右肩……）
	fill_rect(ox, oy, 17, 26, 24, 33, H_METAL)
	fill_rect(ox, oy, 18, 27, 23, 32, H_METAL_L)
	fill_rect(ox, oy, 18, 27, 19, 32, H_GLOW)

	-- 6) 双臂
	-- 左臂（人类，垂下）
	fill_rect(ox, oy, 15, 33, 20, 45, H_SUIT)
	fill_rect(ox, oy, 15, 33, 16, 45, H_SUIT2)
	fill_rect(ox, oy, 15, 45, 20, 49, SKIN)      -- 手
	fill_rect(ox, oy, 15, 45, 16, 49, SKIN_SH)

	-- 7) 头部
	-- 脖子
	fill_rect(ox, oy, 29, 24, 35, 28, H_SUIT2)
	-- 头/头盔
	fill_rect(ox, oy, 26, 12, 39, 25, H_SUIT3)
	fill_rect(ox, oy, 27, 13, 38, 24, H_SUIT2)
	-- 面罩
	fill_rect(ox, oy, 28, 15, 37, 22, VISOR)
	-- 面罩反光（左上）
	fill_rect(ox, oy, 29, 16, 31, 17, VISOR_L)
	put(ox, oy, 32, 16, VISOR_L)
	-- 头盔顶部高光
	hline(ox, oy, 28, 37, 12, H_SUIT2)

	-- 8) 右侧感染区（随 corruption 增强）
	if corruption > 0.0 then
		-- 右臂完全异化
		fill_rect(ox, oy, 44, 32, 49, 46, M_TISSUE)
		fill_rect(ox, oy, 45, 33, 48, 45, M_FLESH)
		-- 手臂上的发光脉络
		vline(ox, oy, 46, 34, 44, M_GLOW)
		put(ox, oy, 47, 38, M_BRIGHT)
		put(ox, oy, 46, 42, M_BRIGHT)
		-- 异化的手（爪状）
		fill_rect(ox, oy, 44, 46, 50, 50, M_TISSUE)
		put(ox, oy, 45, 51, M_FLESH)
		put(ox, oy, 47, 51, M_FLESH)
		put(ox, oy, 49, 51, M_FLESH)
		put(ox, oy, 48, 50, M_GLOW)

		-- 右肩的异化隆起
		fill_rect(ox, oy, 40, 24, 47, 33, M_TISSUE)
		fill_rect(ox, oy, 41, 25, 46, 32, M_FLESH)
		put(ox, oy, 43, 27, M_BRIGHT)
		put(ox, oy, 45, 30, M_GLOW)

		-- 面罩上的裂纹与内透光
		vline(ox, oy, 36, 15, 22, M_DARK)
		put(ox, oy, 36, 17, M_FLESH)
		put(ox, oy, 36, 19, M_GLOW)

		-- 躯干右侧的感染蔓延（"被从内部撑开的接缝"）
		for i = 0, 14 do
			local y = 30 + i
			local wobble = (i % 3 == 0) and 1 or 0
			put(ox, oy, 38 - wobble, y, M_DARK)
			put(ox, oy, 39 - wobble, y, M_TISSUE)
			if i % 2 == 0 then
				put(ox, oy, 40 - wobble, y, M_FLESH)
			end
		end
		-- 接缝上的发光点
		put(ox, oy, 39, 33, M_BRIGHT)
		put(ox, oy, 38, 39, M_BRIGHT)
		put(ox, oy, 39, 44, M_GLOW)
	end
end

-- ============================================================
-- 三帧：人类态 / 半眷化（默认）/ 深度异化
-- ============================================================

-- 帧 1：人类态（用于回忆 / 开场日常）
draw_body(0 * CELL, 0, 0.0)

-- 帧 2：半眷化（游戏内默认形象）
draw_body(1 * CELL, 0, 0.5)

-- 帧 3：深度异化（隔离值高时的形态）
draw_body(2 * CELL, 0, 1.0)
do
	local ox = 2 * CELL
	-- 头部进一步异化：面罩破裂，露出异化的脸
	fill_rect(ox, 0, 28, 15, 37, 22, M_DARK)
	fill_rect(ox, 0, 29, 16, 34, 21, M_TISSUE)
	-- 一只发光的眼
	fill_rect(ox, 0, 30, 17, 33, 19, M_BRIGHT)
	fill_rect(ox, 0, 31, 18, 32, 18, WHITE)
	-- 眼周脉络
	put(ox, 0, 29, 16, M_GLOW)
	put(ox, 0, 34, 16, M_GLOW)
	-- 颈部感染蔓延
	fill_rect(ox, 0, 29, 24, 35, 28, M_TISSUE)
	put(ox, 0, 31, 26, M_GLOW)
	-- 左臂也开始转化（指甲变尖）
	put(ox, 0, 15, 49, M_FLESH)
	put(ox, 0, 17, 49, M_FLESH)
	put(ox, 0, 19, 49, M_FLESH)
	-- 躯干更多组织
	for i = 0, 20 do
		local y = 28 + i
		if y < 50 then
			local w = math.floor(i / 4)
			fill_rect(ox, 0, 30 - w, y, 31 - w, y, M_DARK)
		end
	end
end

-- ---------- 导出 ----------
app.fs.makeDirectory("assets/art/character")
spr:saveAs("assets/art/character/shen_yue.png")
print("主角立绘生成完成 -> assets/art/character/shen_yue.png (" .. spr.width .. "x" .. spr.height .. ")")
print("三帧：1=人类态  2=半眷化（默认）  3=深度异化")
