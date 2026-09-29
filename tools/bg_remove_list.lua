-- 批量抠背景（按角落采样颜色，去掉纯色背景 → 透明）
-- 运行：aseprite.exe -b --script tools/bg_remove_list.lua
--
-- 注意：序列帧不能裁剪（要保留帧网格），所以这里只抠背景，不裁剪。

local function unpack_px(c)
	if type(c) == "number" then
		return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c),
		       app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c)
	end
	return c.red, c.green, c.blue, c.alpha
end

-- { 文件, 容差 }
local JOBS = {
	{ "assets/art/characters/song_mei/battle_512x384.png", 45 },
	{ "assets/art/characters/shen_mingyan/battle_clean_512x256.png", 45 },
}

for _, job in ipairs(JOBS) do
	local path, tol = job[1], job[2]
	local spr = app.open(path)
	local img = spr.cels[1].image
	local W, H = spr.width, spr.height

	local r0, g0, b0, a0 = unpack_px(img:getPixel(2, 2))
	print(string.format("── %s (%dx%d)  背景 RGB=%d,%d,%d A=%d  容差=%d",
		path, W, H, r0, g0, b0, a0, tol))

	if a0 < 50 then
		print("   背景已是透明，跳过")
	else
		local removed = 0
		for y = 0, H - 1 do
			for x = 0, W - 1 do
				local r, g, b = unpack_px(img:getPixel(x, y))
				local d = math.abs(r - r0) + math.abs(g - g0) + math.abs(b - b0)
				if d < tol then
					img:putPixel(x, y, Color(0, 0, 0, 0))
					removed = removed + 1
				end
			end
		end
		print(string.format("   已抠掉 %d 个像素 (%.1f%%)", removed, removed / (W * H) * 100))
		spr:saveAs(path)
		print("   → 已保存")
	end
end
print("全部完成")
