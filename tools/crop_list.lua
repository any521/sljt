-- 批量精确裁剪（路径写死在表里，避免命令行参数问题）
-- 运行：aseprite.exe -b --script tools/crop_list.lua
--
-- 说明：app.params 在命令行下不生效，所以用固定清单。
-- 加新任务只需在 JOBS 里加一行。

local function unpack_px(c)
	if type(c) == "number" then
		return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c),
		       app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c)
	end
	return c.red, c.green, c.blue, c.alpha
end

-- { 源文件, 输出文件, 密度阈值比例 }
local JOBS = {
	{ "assets/art/characters/enemy/kin_attached_raw.png",
	  "assets/art/characters/enemy/kin_attached_512.png", 0.30 },
}

local function process(src, dst, ratio)
	local spr = app.open(src)
	local img = spr.cels[1].image
	local W, H = spr.width, spr.height
	print("── " .. src .. "  (" .. W .. "x" .. H .. ")")

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

	local row_th = math.max(2, math.floor(max_row * ratio))
	local col_th = math.max(2, math.floor(max_col * ratio))

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

	if x0 < 0 or y0 < 0 then
		print("  !! 未找到内容，跳过")
		return
	end

	local PAD = 4
	x0 = math.max(0, x0 - PAD)
	y0 = math.max(0, y0 - PAD)
	x1 = math.min(W - 1, x1 + PAD)
	y1 = math.min(H - 1, y1 + PAD)

	local cw, ch = x1 - x0 + 1, y1 - y0 + 1
	print(string.format("  包围盒 x=%d..%d y=%d..%d  →  裁剪 %dx%d (1:%.2f)",
		x0, x1, y0, y1, cw, ch, ch / cw))

	local out = Sprite(cw, ch, ColorMode.RGB)
	local oimg = out.cels[1].image
	for y = 0, ch - 1 do
		for x = 0, cw - 1 do
			oimg:putPixel(x, y, img:getPixel(x0 + x, y0 + y))
		end
	end
	out:saveAs(dst)
	print("  → 已保存 " .. dst)
end

for _, job in ipairs(JOBS) do
	process(job[1], job[2], job[3])
end
print("全部完成")
