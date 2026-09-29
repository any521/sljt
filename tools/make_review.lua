-- 把美术资产放大供人工审阅（仅用于查看，不参与游戏）
-- 运行：aseprite.exe -b --script tools/make_review.lua
-- 输出：build/review_*.png

local OUT = "build/"

-- 最近邻放大
local function upscale(src, scale)
	local w = src.width * scale
	local h = src.height * scale
	local dst = Sprite(w, h, ColorMode.RGB)
	local simg = src.cels[1].image
	local dimg = dst.cels[1].image
	for y = 0, src.height - 1 do
		for x = 0, src.width - 1 do
			local c = simg:getPixel(x, y)
			for dy = 0, scale - 1 do
				for dx = 0, scale - 1 do
					dimg:putPixel(x * scale + dx, y * scale + dy, c)
				end
			end
		end
	end
	return dst
end

app.fs.makeDirectory(OUT)

-- 1) 卡面精灵表：放大 10 倍（320x240 -> 3200x2400）
local arts = app.open("assets/art/cards/cards_art.png")
local big_arts = upscale(arts, 10)
big_arts:saveAs(OUT .. "review_card_art.png")
print("卡面大图: " .. big_arts.width .. "x" .. big_arts.height)

-- 2) 卡框：放大 6 倍（412x286 -> 2472x1716）
local frames = app.open("assets/art/cards/frames.png")
local big_frames = upscale(frames, 6)
big_frames:saveAs(OUT .. "review_frames.png")
print("卡框大图: " .. big_frames.width .. "x" .. big_frames.height)

-- 3) 卡牌效果预览：放大 2 倍
local review = app.open("build/art_review.png")
local big_review = upscale(review, 2)
big_review:saveAs(OUT .. "review_card_mockup.png")
print("卡牌预览大图: " .. big_review.width .. "x" .. big_review.height)

print("全部完成，输出目录: " .. OUT)
