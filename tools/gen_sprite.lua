-- ============================================================
-- 《阿卡姆号》主角小人儿 —— 64x64 像素精灵
-- 沈越：露脸、深色装甲、只有右手异化
--
-- 设计原则（像素预算优先）：
--   全身高约 60px，头约 10px，脸约 8x8px
--   16 色以内，大面积平涂，不画 64x64 下看不清的细节
--   全身唯一视觉焦点 = 品红色的异化右手
--
-- 输出：assets/art/character/hero_sprite.png（4 帧横排，每帧 64x64）
-- 运行：aseprite.exe -b --script tools/gen_sprite.lua
-- ============================================================

local CELL = 64
local FRAMES = 4

local spr = Sprite(CELL * FRAMES, CELL, ColorMode.RGB)
local img = spr.cels[1].image

local function C(r, g, b)
	return Color(r, g, b, 255)
end

local function put(ox, lx, ly, col)
	if lx < 0 or lx >= CELL or ly < 0 or ly >= CELL then return end
	img:putPixel(ox + lx, ly, col)
end

local function box(ox, x0, y0, x1, y1, col)
	for ly = math.min(y0, y1), math.max(y0, y1) do
		for lx = math.min(x0, x1), math.max(x0, x1) do
			put(ox, lx, ly, col)
		end
	end
end

-- ============================================================
-- 16 色调色板
-- ============================================================
-- 装甲（4 阶）
local A_DARK  = C(9, 12, 19)      -- 最暗（背光/轮廓）
local A_BASE  = C(30, 38, 56)     -- 装甲主体
local A_LIT   = C(50, 62, 86)     -- 装甲受光
local A_EDGE  = C(74, 90, 118)    -- 装甲高光边
-- 皮肤（3 阶）
local S_DARK  = C(126, 90, 68)
local S_BASE  = C(198, 158, 128)
local S_LIT   = C(232, 200, 172)
-- 头发
local HAIR    = C(22, 26, 36)
-- 冷青点缀
local CYAN    = C(107, 199, 255)
local CYAN_D  = C(58, 130, 178)
-- ★ 异化（4 阶，最亮最饱和）
local M_DARK  = C(72, 18, 58)
local M_BASE  = C(140, 42, 112)
local M_LIT   = C(199, 71, 158)
local M_GLOW  = C(255, 158, 220)

-- ============================================================
-- 绘制人形
-- 垂直分区：头发 4-11 / 脸 12-16 / 脖子 17-18 / 躯干 19-38 / 腿 39-58
-- 水平中心：32
-- ============================================================
local function draw_hero(ox, pose)
	-- pose: "idle" / "walk" / "attack" / "hurt"

	local lean = 0
	if pose == "attack" then lean = 2 end
	if pose == "hurt" then lean = -2 end

	-- ---------- 腿 ----------
	if pose == "walk" then
		box(ox, 25, 39, 30, 56, A_BASE)      -- 左腿（前）
		box(ox, 25, 39, 26, 56, A_LIT)
		box(ox, 24, 56, 31, 58, A_DARK)      -- 左靴（前）
		box(ox, 34, 39, 39, 54, A_BASE)      -- 右腿（后）
		box(ox, 37, 39, 39, 54, A_DARK)
		box(ox, 33, 54, 40, 55, A_DARK)      -- 右靴（后）
	else
		box(ox, 25, 39, 30, 56, A_BASE)
		box(ox, 25, 39, 26, 56, A_LIT)
		box(ox, 24, 56, 31, 58, A_DARK)
		box(ox, 34, 39, 39, 56, A_BASE)
		box(ox, 37, 39, 39, 56, A_DARK)
		box(ox, 33, 56, 40, 58, A_DARK)
	end
	-- 膝盖高光（1px 就够）
	put(ox, 27, 47, A_EDGE)
	put(ox, 36, 47, A_EDGE)

	-- ---------- 躯干 ----------
	local tx0, tx1 = 23 + lean, 40 + lean
	box(ox, tx0, 19, tx1, 38, A_BASE)
	box(ox, tx0, 19, tx0 + 3, 38, A_LIT)     -- 左侧受光
	box(ox, tx1 - 3, 19, tx1, 38, A_DARK)    -- 右侧背光
	-- 胸甲层次：一条横向分界
	box(ox, tx0, 27, tx1, 28, A_DARK)
	-- 领口
	box(ox, 29 + lean, 19, 35 + lean, 20, A_DARK)

	-- 胸口能量灯（唯一允许的装甲细节，1-2 px）
	put(ox, 31 + lean, 24, CYAN)
	put(ox, 32 + lean, 24, CYAN)

	-- ---------- 左臂（人类，深色装甲 + 肤色的手）----------
	if pose == "hurt" then
		-- 受击：左臂抬起护脸
		box(ox, 18 + lean, 20, 22 + lean, 24, A_BASE)
		box(ox, 17 + lean, 18, 21 + lean, 22, A_LIT)
		box(ox, 16 + lean, 16, 20 + lean, 20, S_BASE)
	else
		box(ox, 18 + lean, 20, 22 + lean, 36, A_BASE)
		box(ox, 18 + lean, 20, 19 + lean, 36, A_LIT)
		box(ox, 18 + lean, 37, 22 + lean, 41, S_BASE)   -- 手
		put(ox, 19 + lean, 39, S_DARK)
	end

	-- ---------- 右臂：上段装甲 → 中段断裂 → 异化 ----------
	box(ox, 41 + lean, 20, 45 + lean, 32, A_BASE)
	box(ox, 44 + lean, 20, 45 + lean, 32, A_DARK)
	-- 断裂处：一条暗线，说明护甲到这里就没了
	box(ox, 41 + lean, 32, 45 + lean, 33, A_DARK)

	-- ★ 异化前臂 + 爪（全身最亮的部分）
	box(ox, 40 + lean, 34, 46 + lean, 44, M_BASE)
	box(ox, 41 + lean, 35, 45 + lean, 43, M_LIT)
	-- 发光脉络
	put(ox, 42 + lean, 37, M_GLOW)
	put(ox, 43 + lean, 40, M_GLOW)
	put(ox, 44 + lean, 38, M_GLOW)
	-- 爪状手（靠剪影，不画手指细节）
	if pose == "attack" then
		-- 攻击：爪向前伸
		box(ox, 46 + lean, 36, 53 + lean, 42, M_BASE)
		box(ox, 47 + lean, 37, 52 + lean, 41, M_LIT)
		put(ox, 52 + lean, 36, M_GLOW)
		put(ox, 54 + lean, 37, M_GLOW)
		put(ox, 52 + lean, 42, M_GLOW)
		put(ox, 54 + lean, 41, M_GLOW)
	else
		box(ox, 41 + lean, 44, 47 + lean, 49, M_BASE)
		box(ox, 42 + lean, 45, 46 + lean, 48, M_LIT)
		put(ox, 41 + lean, 50, M_GLOW)
		put(ox, 44 + lean, 50, M_GLOW)
		put(ox, 47 + lean, 50, M_GLOW)
	end
	-- 异化边缘的暗描边，加强剪影
	put(ox, 46 + lean, 34, M_DARK)
	put(ox, 46 + lean, 43, M_DARK)

	-- ---------- 脖子 ----------
	box(ox, 29 + lean, 17, 34 + lean, 18, S_DARK)

	-- ---------- 头部（约 10px 高）----------
	-- 脸（8x6）
	box(ox, 28 + lean, 11, 35 + lean, 16, S_BASE)
	box(ox, 28 + lean, 11, 29 + lean, 16, S_LIT)   -- 左侧受光
	box(ox, 34 + lean, 14, 35 + lean, 16, S_DARK)  -- 右下阴影
	-- 头发（盖住上半）
	box(ox, 27 + lean, 5, 36 + lean, 10, HAIR)
	box(ox, 27 + lean, 10, 28 + lean, 13, HAIR)    -- 鬓角
	box(ox, 35 + lean, 10, 36 + lean, 12, HAIR)
	-- 头顶高光
	box(ox, 29 + lean, 5, 33 + lean, 6, C(40, 46, 62))
	-- 眼睛（各 1px）
	put(ox, 30 + lean, 13, A_DARK)
	put(ox, 33 + lean, 13, A_DARK)
	-- 耳麦（左耳一个小装置）
	put(ox, 27 + lean, 13, CYAN_D)
	put(ox, 27 + lean, 14, CYAN_D)
end

-- ============================================================
-- 四帧
-- ============================================================
draw_hero(0 * CELL, "idle")
draw_hero(1 * CELL, "walk")
draw_hero(2 * CELL, "attack")
draw_hero(3 * CELL, "hurt")

app.fs.makeDirectory("assets/art/character")
spr:saveAs("assets/art/character/hero_sprite.png")
print("小人儿精灵图生成完成 -> assets/art/character/hero_sprite.png (" .. spr.width .. "x" .. spr.height .. ")")
print("四帧：待机 / 行走 / 攻击 / 受击")
