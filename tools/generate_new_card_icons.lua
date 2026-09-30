-- Adds ten original 32x32 card icons to the existing atlas.
-- Run with: aseprite.exe --batch --script tools/generate_new_card_icons.lua

local root = "D:/Huailxgame1/"
local source = root .. "assets/art/cards/cards_art.png"
local output = root .. "assets/art/cards/cards_art.png"

local old = app.open(source)
local oldImage = old.cels[1].image:clone()
local sprite = Sprite(256, 128, ColorMode.RGB)
local layer = sprite.layers[1]
layer.name = "card_icons"
local image = Image(256, 128, ColorMode.RGB)
image:drawImage(oldImage, Point(0, 0))

local bg = Color{r=5,g=16,b=25,a=255}
local cyan = Color{r=73,g=197,b=244,a=255}
local pale = Color{r=178,g=232,b=255,a=255}
local deep = Color{r=26,g=91,b=126,a=255}
local magenta = Color{r=199,g=71,b=158,a=255}
local pink = Color{r=255,g=145,b=216,a=255}
local violet = Color{r=125,g=68,b=166,a=255}
local amber = Color{r=244,g=178,b=68,a=255}

local function px(x,y,c)
  if x >= 0 and x < image.width and y >= 0 and y < image.height then image:putPixel(x,y,c) end
end

local function fill(x,y,w,h,c)
  for yy=y,y+h-1 do for xx=x,x+w-1 do px(xx,yy,c) end end
end

local function line(x0,y0,x1,y1,c)
  local dx, sx = math.abs(x1-x0), (x0 < x1 and 1 or -1)
  local dy, sy = -math.abs(y1-y0), (y0 < y1 and 1 or -1)
  local err = dx + dy
  while true do
    px(x0,y0,c)
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2*err
    if e2 >= dy then err=err+dy; x0=x0+sx end
    if e2 <= dx then err=err+dx; y0=y0+sy end
  end
end

local function rect(x,y,w,h,c)
  line(x,y,x+w-1,y,c); line(x,y+h-1,x+w-1,y+h-1,c)
  line(x,y,x,y+h-1,c); line(x+w-1,y,x+w-1,y+h-1,c)
end

local function diamond(cx,cy,r,c)
  line(cx,cy-r,cx+r,cy,c); line(cx+r,cy,cx,cy+r,c)
  line(cx,cy+r,cx-r,cy,c); line(cx-r,cy,cx,cy-r,c)
end

local function ring(cx,cy,r,c)
  for yy=-r,r do for xx=-r,r do
    local d=xx*xx+yy*yy
    if d >= (r-1)*(r-1) and d <= r*r+1 then px(cx+xx,cy+yy,c) end
  end end
end

local function cell(col,row,drawer)
  local ox,oy=col*32,row*32
  fill(ox,oy,32,32,bg)
  drawer(ox,oy)
end

-- Phase Register
cell(4,1,function(x,y)
  ring(x+16,y+16,10,deep); ring(x+16,y+16,7,cyan)
  for _,p in ipairs({{16,5},{25,18},{9,23}}) do fill(x+p[1]-1,y+p[2]-1,3,3,pale) end
  fill(x+14,y+13,5,6,violet); px(x+16,y+15,pink)
end)

-- Redundant Cache
cell(3,2,function(x,y)
  rect(x+7,y+7,15,10,cyan); rect(x+10,y+15,15,10,pale)
  for i=0,3 do fill(x+9+i*4,y+5,2,2,deep); fill(x+12+i*3,y+25,1,2,deep) end
  diamond(x+18,y+20,3,amber)
end)

-- Memory Tumor
cell(4,2,function(x,y)
  fill(x+10,y+9,12,14,violet); fill(x+7,y+12,5,8,magenta); fill(x+20,y+11,5,10,magenta)
  fill(x+12,y+6,4,4,pink); fill(x+17,y+7,5,4,magenta); fill(x+11,y+22,5,4,magenta)
  diamond(x+16,y+16,3,cyan); px(x+16,y+16,pale)
end)

-- Cross Calibration
cell(5,2,function(x,y)
  ring(x+16,y+16,9,deep); ring(x+16,y+16,4,cyan)
  line(x+4,y+16,x+28,y+16,pale); line(x+16,y+4,x+16,y+28,pale)
  line(x+7,y+7,x+25,y+25,cyan); line(x+25,y+7,x+7,y+25,cyan)
  fill(x+15,y+15,3,3,amber)
end)

-- Inverse Discharge
cell(6,2,function(x,y)
  diamond(x+16,y+16,8,amber); fill(x+14,y+14,5,5,Color{r=255,g=221,b=115,a=255})
  line(x+4,y+10,x+10,y+13,cyan); line(x+4,y+22,x+10,y+19,cyan)
  line(x+28,y+10,x+22,y+13,pale); line(x+28,y+22,x+22,y+19,pale)
  px(x+6,y+8,magenta); px(x+26,y+24,magenta)
end)

-- Inhibitor Injection
cell(7,2,function(x,y)
  line(x+7,y+24,x+23,y+8,pale); line(x+9,y+26,x+25,y+10,cyan)
  rect(x+7,y+20,6,5,deep); fill(x+20,y+7,6,4,cyan)
  fill(x+16,y+17,8,7,magenta); fill(x+18,y+19,4,3,violet)
  line(x+12,y+21,x+25,y+21,amber)
end)

-- Threshold Puncture
cell(0,3,function(x,y)
  ring(x+16,y+16,10,cyan); diamond(x+16,y+16,7,deep)
  line(x+5,y+25,x+25,y+6,violet); line(x+7,y+26,x+27,y+7,pink)
  fill(x+14,y+14,5,5,magenta); px(x+16,y+16,amber)
end)

-- Rehearsal Process
cell(1,3,function(x,y)
  rect(x+6,y+9,8,12,deep); rect(x+18,y+11,8,12,cyan)
  line(x+10,y+6,x+23,y+6,pale); line(x+23,y+6,x+26,y+9,pale)
  line(x+22,y+26,x+9,y+26,cyan); line(x+9,y+26,x+6,y+23,cyan)
  fill(x+11,y+14,3,3,amber); fill(x+20,y+16,3,3,amber)
end)

-- Sample Archive
cell(2,3,function(x,y)
  rect(x+7,y+6,18,21,deep); line(x+10,y+23,x+22,y+23,cyan)
  rect(x+12,y+8,8,5,pale); fill(x+13,y+13,7,10,magenta)
  fill(x+15,y+16,3,4,pink); px(x+17,y+14,amber)
  line(x+5,y+10,x+5,y+24,cyan); line(x+27,y+10,x+27,y+24,cyan)
end)

-- Hard Reboot
cell(3,3,function(x,y)
  ring(x+16,y+16,10,deep)
  line(x+16,y+5,x+16,y+15,pale)
  line(x+9,y+9,x+6,y+14,cyan); line(x+6,y+14,x+8,y+22,cyan)
  line(x+8,y+22,x+14,y+27,cyan); line(x+14,y+27,x+21,y+25,cyan)
  line(x+19,y+7,x+14,y+17,amber); line(x+14,y+17,x+19,y+17,amber); line(x+19,y+17,x+14,y+26,amber)
end)

-- Insulation Barrier
cell(4,3,function(x,y)
  diamond(x+16,y+16,11,deep); diamond(x+16,y+16,8,cyan)
  rect(x+12,y+10,8,12,pale); fill(x+14,y+12,4,8,bg)
  line(x+9,y+7,x+9,y+25,amber); line(x+23,y+7,x+23,y+25,amber)
end)

-- Symbiotic Shell
cell(5,3,function(x,y)
  ring(x+16,y+16,10,violet); ring(x+16,y+16,7,magenta)
  line(x+8,y+21,x+16,y+7,pink); line(x+16,y+7,x+24,y+21,pink)
  line(x+10,y+22,x+22,y+22,magenta); fill(x+14,y+14,5,6,cyan)
  px(x+16,y+16,pale)
end)

sprite:newCel(layer, 1, image, Point(0,0))
sprite:saveAs(output)
old:close()
sprite:close()
