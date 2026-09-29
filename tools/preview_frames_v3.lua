-- 卡框 v3 放大预览 + 三张并排（模拟手牌效果）
-- 运行：aseprite.exe -b --script tools/preview_frames_v3.lua

local W, H = 103, 175
local SCALE = 5
local GAP = 14

local src = app.open("assets/art/cards/frames_v3.png")
local simg = src.cels[1].image

local n = 3
local out_w = (W * n + GAP * (n + 1)) * SCALE
local out_h = (H + GAP * 2) * SCALE

local out = Sprite(out_w, out_h, ColorMode.RGB)
local dimg = out.cels[1].image

-- 深色背景
for y = 0, out_h - 1 do
	for x = 0, out_w - 1 do
		dimg:putPixel(x, y, Color(14, 17, 24, 255))
	end
end

-- 放入三张不同归属的卡框：规程 / 异化 / 中立
local which = { 0, 1, 2 }
for i = 1, n do
	local fx = which[i] * W
	local dx0 = (GAP + (i - 1) * (W + GAP)) * SCALE
	local dy0 = GAP * SCALE
	for ly = 0, H - 1 do
		for lx = 0, W - 1 do
			local c = simg:getPixel(fx + lx, ly)
			for sy = 0, SCALE - 1 do
				for sx = 0, SCALE - 1 do
					dimg:putPixel(dx0 + lx * SCALE + sx, dy0 + ly * SCALE + sy, c)
				end
			end
		end
	end
end

app.fs.makeDirectory("build")
out:saveAs("build/frames_v3_preview.png")
print("卡框 v3 预览: build/frames_v3_preview.png (" .. out.width .. "x" .. out.height .. ")")
