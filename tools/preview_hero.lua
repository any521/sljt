-- 主角立绘放大预览
-- 运行：aseprite.exe -b --script tools/preview_hero.lua

local src = app.open("assets/art/character/shen_yue.png")
local SCALE = 8

local out = Sprite(src.width * SCALE, src.height * SCALE, ColorMode.RGB)
local simg = src.cels[1].image
local dimg = out.cels[1].image

-- 深色背景，方便看清轮廓
for y = 0, out.height - 1 do
	for x = 0, out.width - 1 do
		dimg:putPixel(x, y, Color(18, 22, 30, 255))
	end
end

for y = 0, src.height - 1 do
	for x = 0, src.width - 1 do
		local c = simg:getPixel(x, y)
		for dy = 0, SCALE - 1 do
			for dx = 0, SCALE - 1 do
				dimg:putPixel(x * SCALE + dx, y * SCALE + dy, c)
			end
		end
	end
end

-- 帧之间加分隔线
for f = 1, 2 do
	local sx = f * 64 * SCALE
	for y = 0, out.height - 1 do
		dimg:putPixel(sx, y, Color(60, 70, 90, 255))
		dimg:putPixel(sx + 1, y, Color(60, 70, 90, 255))
	end
end

app.fs.makeDirectory("build")
out:saveAs("build/review_hero.png")
print("主角预览已生成: build/review_hero.png (" .. out.width .. "x" .. out.height .. ")")
