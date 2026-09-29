-- 精确裁剪：把图片裁到"真正有内容"的范围（去掉多余的透明边）
-- 用法：aseprite.exe -b --script tools/tight_crop.lua <输入> <输出> <阈值比例>
-- 例：  aseprite.exe -b --script tools/tight_crop.lua in.png out.png 0.35

local args = app.params or {}
local SRC = args[1] or "assets/art/characters/shen_mingyan/sprite_infected_512.png"
local OUT = args[2] or SRC
local RATIO = tonumber(args[3] or "0.35")

local function unpack_px(c)
	if type(c) == "number" then
		return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c),
		       app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c)
	end
	return c.red, c.green, c.blue, c.alpha
end

local spr = app.open(SRC)
local img = spr.cels[1].image
local W, H = spr.width, spr.height
print("输入: " .. SRC .. "  " .. W .. "x" .. H)

local row_count, col_count = {}, {}
for y = 0, H - 1 do row_count[y] = 0 end
for x = 0, W - 1 do col_count[x] = 0 end

local max_row, max_col = 0, 0
for y = 0, H - 1 do
	for x = 0, W - 1 do
		local _, _, _, a = unpack_px(img:getPixel(x, y))
		if a > 0 then
			row_count[y] = row_count[y] + 1
			col_count[x] = col_count[x] + 1
			if row_count[y] > max_row then max_row = row_count[y] end
			if col_count[x] > max_col then max_col = col_count[x] end
		end
	end
end

local row_th = math.max(2, math.floor(max_row * RATIO))
local col_th = math.max(2, math.floor(max_col * RATIO))

local y0, y1, x0, x1 = -1, -1, -1, -1
for y = 0, H - 1 do
	if row_count[y] >= row_th then
		if y0 < 0 then y0 = y end
		y1 = y
	end
end
for x = 0, W - 1 do
	if col_count[x] >= col_th then
		if x0 < 0 then x0 = x end
		x1 = x
	end
end

print(string.format("密度峰值: 行=%d 列=%d   阈值(%d%%): 行>=%d 列>=%d",
	max_row, max_col, math.floor(RATIO * 100), row_th, col_th))
print(string.format("内容包围盒: x=%d..%d  y=%d..%d", x0, x1, y0, y1))

if x0 < 0 or y0 < 0 then
	print("!! 未找到内容，未裁剪")
	app.exit()
end

local PAD = 4
x0 = math.max(0, x0 - PAD)
y0 = math.max(0, y0 - PAD)
x1 = math.min(W - 1, x1 + PAD)
y1 = math.min(H - 1, y1 + PAD)

local cw, ch = x1 - x0 + 1, y1 - y0 + 1
print(string.format("裁剪后: %dx%d   比例 1:%.2f", cw, ch, ch / cw))

local out = Sprite(cw, ch, ColorMode.RGB)
local oimg = out.cels[1].image
for y = 0, ch - 1 do
	for x = 0, cw - 1 do
		oimg:putPixel(x, y, img:getPixel(x0 + x, y0 + y))
	end
end
out:saveAs(OUT)
print("已保存: " .. OUT)
