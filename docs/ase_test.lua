-- Aseprite Lua test: 512x512 dark background + cyan crosshair
local W, H = 512, 512
local spr = Sprite(W, H)
local img = spr.layers[1]:cel(1).image

local function rgba(r, g, b, a)
  return app.pixelColor.rgba(r, g, b, a or 255)
end

local DARK = rgba(17, 22, 32)      -- #111620
local CYAN = rgba(107, 199, 255)   -- #6BC7FF
local BLUE = rgba(58, 130, 178)    -- #3A82B2

-- fill background
for y = 0, H - 1 do
  for x = 0, W - 1 do
    img:drawPixel(x, y, DARK)
  end
end

-- crosshair: vertical line
for y = 200, 311 do
  img:drawPixel(255, y, CYAN)
end
-- horizontal line
for x = 200, 311 do
  img:drawPixel(x, 255, CYAN)
end
-- center dot
for y = 250, 261 do
  for x = 250, 261 do
    img:drawPixel(x, y, BLUE)
  end
end
-- corner brackets (4 corners of a 64x64 box around center)
local c, s = 224, 64  -- corner start, span
for i = 0, s - 1 do
  img:drawPixel(c + i, c, CYAN)          -- top
  img:drawPixel(c + i, c + s, CYAN)      -- bottom
  img:drawPixel(c, c + i, CYAN)          -- left
  img:drawPixel(c + s, c + i, CYAN)      -- right
end

spr:saveAs("D:/Huailxgame/docs/ase_test.png")
print("saved ok")
