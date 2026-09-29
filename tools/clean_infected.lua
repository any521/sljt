-- 处理「感染后沈明砚」大图：
--   1) 扣掉紫色背景 → 透明
--   2) 按行列像素密度找出角色包围盒（自动排除右下角的 AI 水印）
--   3) 裁剪并保存
-- 运行：aseprite.exe -b --script tools/clean_infected.lua
--
-- 注意：本版 Aseprite 的 getPixel 返回打包整数，不是 Color 对象，
--       所以统一用 unpack_px() 解包。

local SRC = "assets/art/characters/shen_mingyan/sprite_infected_raw.png"
local OUT = "assets/art/characters/shen_mingyan/sprite_infected_512.png"

-- 兼容：getPixel 可能返回 Color 也可能返回打包整数
local function unpack_px(c)
	if type(c) == "number" then
		return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c),
		       app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c)
	end
	return c.red, c.green, c.blue, c.alpha
end

local spr = app.open(SRC)
local img = spr.cels[1].image
local W = spr.width
local H = spr.height

print("源图: " .. W .. "x" .. H)

-- ---------- 1) 探测背景色 ----------
local r0, g0, b0 = unpack_px(img:getPixel(3, 3))
print(string.format("背景色推测: R=%d G=%d B=%d", r0, g0, b0))

local TOL = 70

-- ---------- 2) 扣背景 ----------
local removed = 0
for y = 0, H - 1 do
	for x = 0, W - 1 do
		local r, g, b = unpack_px(img:getPixel(x, y))
		local d = math.abs(r - r0) + math.abs(g - g0) + math.abs(b - b0)
		if d < TOL then
			img:putPixel(x, y, Color(0, 0, 0, 0))
			removed = removed + 1
		end
	end
end
print("已扣背景像素: " .. removed)

-- ---------- 3) 按密度找角色包围盒 ----------
local row_count = {}
local col_count = {}
for y = 0, H - 1 do row_count[y] = 0 end
for x = 0, W - 1 do col_count[x] = 0 end

local max_row = 0
local max_col = 0
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

-- 阈值：只保留"像素密度高"的行列 → 水印这种稀疏元素会被排除
local row_th = math.max(3, math.floor(max_row * 0.15))
local col_th = math.max(3, math.floor(max_col * 0.15))

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

print(string.format("密度阈值: 行>=%d 列>=%d", row_th, col_th))
print(string.format("角色包围盒: x=%d..%d  y=%d..%d", x0, x1, y0, y1))

if x0 < 0 or y0 < 0 then
	print("!! 未找到角色，保存未裁剪版本")
	spr:saveAs(OUT)
	app.exit()
end

-- 留一点边距
local PAD = 6
x0 = math.max(0, x0 - PAD)
y0 = math.max(0, y0 - PAD)
x1 = math.min(W - 1, x1 + PAD)
y1 = math.min(H - 1, y1 + PAD)

local cw = x1 - x0 + 1
local ch = y1 - y0 + 1
print(string.format("裁剪后尺寸: %dx%d   比例 1:%.2f", cw, ch, ch / cw))

-- ---------- 4) 裁剪到新图 ----------
local out = Sprite(cw, ch, ColorMode.RGB)
local oimg = out.cels[1].image
for y = 0, ch - 1 do
	for x = 0, cw - 1 do
		oimg:putPixel(x, y, img:getPixel(x0 + x, y0 + y))
	end
end

app.fs.makeDirectory("assets/art/characters/shen_mingyan")
out:saveAs(OUT)
print("已保存: " .. OUT)
