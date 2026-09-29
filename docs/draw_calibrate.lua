-- 《阿卡姆号》卡面：「校准射击」(工程系/气质A) — 分步绘制
-- 用法: ASE_STEP=<1..5> aseprite -b --script draw_calibrate.lua
local STEP = tonumber(os.getenv("ASE_STEP")) or 5

local W, H = 512, 512
local spr = Sprite(W, H)
local img = spr.layers[1]:cel(1).image

local function rgba(r, g, b, a)
  return app.pixelColor.rgba(r, g, b, a or 255)
end

-- ==== 色板（工程系，32色内）====
local DARK    = rgba(17, 22, 32)      -- #111620 深蓝黑
local PANEL   = rgba(24, 30, 44)      -- 面板
local PANEL2  = rgba(30, 38, 56)      -- 亮面板
local DEEP    = rgba(12, 16, 24)      -- 更暗
local CYAN    = rgba(107, 199, 255)   -- #6BC7FF 冷青
local STEEL   = rgba(58, 130, 178)    -- #3A82B2 钢蓝
local PALE    = rgba(165, 220, 255)   -- 淡青高光
local WHITE   = rgba(230, 245, 255)   -- 近白
local ORANGE  = rgba(255, 158, 80)    -- 警告橙(少量)
local GRAY    = rgba(70, 82, 100)     -- 灰蓝

-- ==== 工具函数 ====
local function fill(c)
  for y = 0, H - 1 do
    for x = 0, W - 1 do img:drawPixel(x, y, c) end
  end
end

local function rect(x0, y0, x1, y1, c)
  for y = y0, y1 do
    for x = x0, x1 do img:drawPixel(x, y, c) end
  end
end

local function recto(x0, y0, x1, y1, c)  -- outline only
  for x = x0, x1 do img:drawPixel(x, y0, c) img:drawPixel(x, y1, c) end
  for y = y0, y1 do img:drawPixel(x0, y, c) img:drawPixel(x1, y, c) end
end

local function hline(x0, x1, y, c)
  for x = x0, x1 do img:drawPixel(x, y, c) end
end

local function vline(y0, y1, x, c)
  for y = y0, y1 do img:drawPixel(x, y, c) end
end

-- ============ 第1步：背景 ============
local function draw_bg()
  fill(DEEP)
  -- 大范围底色
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      if x < 46 or x > 465 or y < 46 or y > 465 then
        img:drawPixel(x, y, DARK)
      end
    end
  end
  -- 顶部暗带
  rect(0, 0, 511, 24, DEEP)
  rect(0, 25, 511, 40, DARK)
  -- 底部面板区
  rect(40, 440, 471, 505, PANEL)
  rect(46, 446, 465, 499, PANEL2)
  -- 左下小面板
  rect(30, 300, 90, 360, PANEL)
  recto(30, 300, 90, 360, DARK3_ or DARK)
  -- 右上小面板
  rect(421, 140, 481, 200, PANEL)
  -- 机械网格线(极淡, 稀疏)
  for gx = 56, 456, 40 do
    if gx ~= 256 then vline(56, 456, gx, DARK2_) end
  end
  for gy = 56, 456, 40 do
    if gy ~= 256 then hline(56, 456, gy, DARK2_) end
  end
end

local DARK2_ = rgba(21, 27, 39)
local DARK3_ = rgba(21, 27, 39)

-- ============ 第2步：准星主体 ============
local function draw_crosshair()
  -- 十字主线 (2px 宽)
  rect(255, 96, 256, 415, CYAN)
  rect(96, 255, 415, 256, CYAN)
  -- 中心方块 (钢蓝填 + 青色边)
  rect(244, 244, 267, 267, STEEL)
  recto(240, 240, 271, 271, CYAN)
  -- 外圈方框(淡, 点状)
  for i = 0, 47 do
    local d = i % 4
    if d < 2 then
      img:drawPixel(208 + i, 208, PALE)
      img:drawPixel(208 + i, 303, PALE)
      img:drawPixel(208, 208 + i, PALE)
      img:drawPixel(303, 208 + i, PALE)
    end
  end
  -- 十字加粗内段
  rect(248, 160, 263, 351, STEEL)
  rect(160, 248, 351, 263, STEEL)
end

-- ============ 第3步：四角扫描定位框 ============
local function draw_brackets()
  -- 四角 L 形定位框 (每角两条短线)
  local bx = {96, 384, 96, 384}
  local by = {96, 96, 384, 384}
  local len = 44
  for k = 1, 4 do
    local x0, y0 = bx[k], by[k]
    local dx = (x0 < 256) and 1 or -1
    local dy = (y0 < 256) and 1 or -1
    hline(x0, x0 + dx * len, y0, CYAN)
    hline(x0, x0 + dx * len, y0 + dy * len, CYAN)
    vline(y0, y0 + dy * len, x0, CYAN)
    vline(y0, y0 + dy * len, x0 + dx * len, CYAN)
    -- 角端点亮块
    rect(x0 - 2, y0 - 2, x0 + 2 + dx * 0, y0 + 2 + dy * 0, PALE)
  end
  -- 四角内侧小标记
  img:drawPixel(208, 96, ORANGE)
  img:drawPixel(303, 96, ORANGE)
  img:drawPixel(208, 415, ORANGE)
  img:drawPixel(303, 415, ORANGE)
  img:drawPixel(96, 208, ORANGE)
  img:drawPixel(96, 303, ORANGE)
  img:drawPixel(415, 208, ORANGE)
  img:drawPixel(415, 303, ORANGE)
end

-- ============ 第4步：刻度与细节 ============
local function draw_ticks()
  -- 十字线周围的刻度短线
  for t = 0, 3 do
    local p = 112 + t * 48
    hline(p - 5, p + 5, 84, CYAN_D or STEEL)
    hline(p - 5, p + 5, 427, CYAN_D or STEEL)
    vline(84 - 0, 84 + 10, p, CYAN_D or STEEL)
    vline(427 - 10, 427, p, CYAN_D or STEEL)
  end
  -- 底部面板: 指示灯
  rect(120, 452, 150, 460, DEEP)
  rect(156, 452, 186, 460, DEEP)
  rect(192, 452, 222, 460, DEEP)
  img:drawPixel(135, 456, CYAN)
  img:drawPixel(171, 456, ORANGE)
  img:drawPixel(207, 456, GRAY)
  -- 面板刻度条
  for i = 0, 7 do
    img:drawPixel(280 + i * 16, 460, PALE)
    img:drawPixel(280 + i * 16, 462, PALE)
  end
  -- 螺栓点 (四角)
  local bxy = {56, 56, 455, 56, 56, 455, 455, 455}
  for k = 1, 4 do
    img:drawPixel(bxy[k * 2 - 1], bxy[k * 2], STEEL)
  end
  -- 左侧小面板: 竖线仪表
  vline(310, 350, 60, CYAN_D or STEEL)
  vline(314, 350, 74, CYAN_D or STEEL)
  hline(56, 78, 322, PALE)
  hline(56, 78, 338, PALE)
end

local CYAN_D = rgba(58, 130, 178)

-- ============ 第5步：高光收尾 ============
local function draw_highlight()
  -- 中心亮点
  rect(253, 253, 258, 258, WHITE)
  img:drawPixel(256, 256, WHITE)
  -- 中心方块内十字暗痕
  img:drawPixel(256, 246, DEEP)
  img:drawPixel(256, 265, DEEP)
  img:drawPixel(246, 256, DEEP)
  img:drawPixel(265, 256, DEEP)
  -- 十字线端部箭头
  img:drawPixel(256, 92, PALE) img:drawPixel(255, 92, PALE)
  img:drawPixel(256, 419, PALE)
  img:drawPixel(92, 256, PALE)
  img:drawPixel(419, 256, PALE)
  -- 十字线内侧淡青过渡段
  rect(253, 150, 258, 170, PALE)
  rect(253, 341, 258, 361, PALE)
  rect(150, 253, 170, 258, PALE)
  rect(341, 253, 361, 258, PALE)
  -- 外圈方框亮角
  img:drawPixel(208, 208, WHITE)
  img:drawPixel(303, 208, WHITE)
  img:drawPixel(208, 303, WHITE)
  img:drawPixel(303, 303, WHITE)
  -- 警告小标记(右下角)
  img:drawPixel(470, 480, ORANGE)
  img:drawPixel(474, 480, ORANGE)
  img:drawPixel(480, 474, ORANGE)
  img:drawPixel(480, 470, ORANGE)
  -- 扫描框内侧细横线
  hline(140, 180, 370, STEEL)
  hline(331, 371, 140, STEEL)
end

-- ==== 按步骤执行 ====
draw_bg()
if STEP >= 2 then draw_crosshair() end
if STEP >= 3 then draw_brackets() end
if STEP >= 4 then draw_ticks() end
if STEP >= 5 then draw_highlight() end

local out = "D:/Huailxgame/docs/calibrate_step" .. STEP .. ".png"
spr:saveAs(out)
print("step " .. STEP .. " saved -> " .. out)
