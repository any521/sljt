-- 生成卡牌拼装预览（修正比例版）
-- ★ 关键修正：卡面按等比缩放贴进正方形插画窗，绝不拉伸
-- 运行：aseprite.exe -b --script tools/preview_assets.lua

local FRAME_W, FRAME_H = 103, 175
local ART_X, ART_Y, ART_SIZE = 11, 30, 81   -- 与卡框脚本保持一致
local SCALE = 4
local GAP = 12
local COLS = 4

local frames = app.open("assets/art/cards/frames.png")
local arts = app.open("assets/art/cards/cards_art.png")

local total_w = (FRAME_W * COLS + GAP * (COLS + 1)) * SCALE
local total_h = (FRAME_H + GAP * 2) * SCALE

local out = Sprite(total_w, total_h, ColorMode.RGB)
local img = out.cels[1].image

local function px(x, y, c)
	if x >= 0 and x < total_w and y >= 0 and y < total_h then
		img:putPixel(x, y, c)
	end
end

local function blit_scaled(src_img, sx, sy, sw, sh, dx, dy, scale)
	for y = 0, sh - 1 do
		for x = 0, sw - 1 do
			local c = src_img:getPixel(sx + x, sy + y)
			for yy = 0, scale - 1 do
				for xx = 0, scale - 1 do
					px(dx + x * scale + xx, dy + y * scale + yy, c)
				end
			end
		end
	end
end

-- 卡面在精灵表中的位置
local art_pos = {
	calibrate_shot = { 0, 0 },
	precision_strike = { 32, 0 },
	force_shield = { 64, 0 },
	framework_scan = { 96, 0 },
	overclock = { 128, 0 },
	lacerate = { 160, 0 },
	parasite_spore = { 192, 0 },
	flesh_reshape = { 224, 0 },
	abyss_gaze = { 0, 32 },
	sacrifice_blood = { 32, 32 },
	emergency_medkit = { 64, 32 },
	logic_lock = { 96, 32 },
	precision_strike_plus = { 128, 32 },
	lacerate_plus = { 160, 32 },
	force_shield_plus = { 192, 32 },
	framework_scan_plus = { 224, 32 },
	calibrate_shot_plus = { 0, 64 },
	logic_lock_plus = { 32, 64 },
	flesh_reshape_plus = { 64, 64 },
}

-- 背景
for y = 0, total_h - 1 do
	for x = 0, total_w - 1 do
		px(x, y, Color(11, 14, 20, 255))
	end
end

local fimg = frames.cels[1].image
local aimg = arts.cels[1].image

local cards = {
	{ fi = 0, art = "calibrate_shot" },
	{ fi = 1, art = "lacerate" },
	{ fi = 2, art = "logic_lock" },
	{ fi = 3, art = "precision_strike_plus" },
}

local slot = 0
for _, card in ipairs(cards) do
	local gx = GAP + slot * (FRAME_W + GAP)
	local gy = GAP

	-- 1) 卡框
	blit_scaled(fimg, card.fi * FRAME_W, 0, FRAME_W, FRAME_H, gx * SCALE, gy * SCALE, SCALE)

	-- 2) 卡面：★ 等比缩放贴入正方形窗口
	--    源 32x32，目标 81x81 → 放大系数 81/32 = 2.53125
	--    为保证像素清晰，用 2.5 倍：32 * 2.5 = 80，居中放置（留 0.5 像素误差由取整吸收）
	local ap = art_pos[card.art]
	if ap then
		local zoom = 2.0                       -- 每个源像素放大成 zoom 个逻辑像素
		local draw_size = math.floor(32 * zoom) -- 64
		local pad = math.floor((ART_SIZE - draw_size) / 2)  -- 居中留白
		for sy = 0, 31 do
			for sx = 0, 31 do
				local c = aimg:getPixel(ap[1] + sx, ap[2] + sy)
				for zy = 0, zoom - 1 do
					for zx = 0, zoom - 1 do
						local lx = ART_X + pad + sx * zoom + zx
						local ly = ART_Y + pad + sy * zoom + zy
						local dx = (gx + lx) * SCALE
						local dy = (gy + ly) * SCALE
						for yy = 0, SCALE - 1 do
							for xx = 0, SCALE - 1 do
								px(dx + xx, dy + yy, c)
							end
						end
					end
				end
			end
		end
	end
	slot = slot + 1
end

app.fs.makeDirectory("build")
out:saveAs("build/art_review.png")
print("拼装预览已生成: build/art_review.png (" .. out.width .. "x" .. out.height .. ")")
print("卡面缩放: 32x32 -> " .. math.floor(32 * 2.0) .. "x" .. math.floor(32 * 2.0) ..
	"（等比，居中留白 " .. math.floor((81 - 64) / 2) .. "px）")
