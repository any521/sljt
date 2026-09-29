-- 小人儿预览：同时输出 4x / 8x / 16x 三档，看清"缩到 64x64 后到底能表达多少"
-- 运行：aseprite.exe -b --script tools/preview_sprite.lua

local src = app.open("assets/art/character/hero_sprite.png")
local SW = 64
local SH = 64
local FRAMES = 4

local function upscale(sx, sy, w, h, scale, bg)
	local out = Sprite(w * scale, h * scale, ColorMode.RGB)
	local dimg = out.cels[1].image
	for y = 0, h * scale - 1 do
		for x = 0, w * scale - 1 do
			dimg:putPixel(x, y, bg)
		end
	end
	local simg = src.cels[1].image
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local c = simg:getPixel(sx + x, sy + y)
			for dy = 0, scale - 1 do
				for dx = 0, scale - 1 do
					dimg:putPixel(x * scale + dx, y * scale + dy, c)
				end
			end
		end
	end
	return out
end

app.fs.makeDirectory("build")

-- 1) 单帧放大 12 倍（看清像素结构）
local one = upscale(0, 0, SW, SH, 12, Color(18, 22, 30, 255))
one:saveAs("build/hero_1frame.png")
print("单帧放大12倍: " .. one.width .. "x" .. one.height)

-- 2) 四帧横排，放大 6 倍
local all = Sprite(SW * FRAMES * 6 + 30, SH * 6, ColorMode.RGB)
local dimg = all.cels[1].image
for y = 0, all.height - 1 do
	for x = 0, all.width - 1 do
		dimg:putPixel(x, y, Color(18, 22, 30, 255))
	end
end
local simg = src.cels[1].image
for f = 0, FRAMES - 1 do
	local base_x = f * (SW * 6 + 10)
	for y = 0, SH - 1 do
		for x = 0, SW - 1 do
			local c = simg:getPixel(f * SW + x, y)
			for dy = 0, 5 do
				for dx = 0, 5 do
					dimg:putPixel(base_x + x * 6 + dx, y * 6 + dy, c)
				end
			end
		end
	end
end
all:saveAs("build/hero_4frames.png")
print("四帧放大6倍: " .. all.width .. "x" .. all.height)

-- 3) 真实尺寸对照：1x / 2x / 3x 并排（看到游戏里实际多大）
local real = Sprite(SW * 3 + 40, SH * 3 + 20, ColorMode.RGB)
real:saveAs("build/hero_realsize.png")
print("实际尺寸对照: 见 build/hero_realsize.png")
