-- 将原始序列帧的纯色背景做“从画布边缘连通区域”抠图。
-- 保留 512x384 / 4x3 网格，不裁剪，供 Godot SpriteFrames 直接切帧。

local JOBS = {
  {
    src = "assets/art/incoming_0927/沈明拔枪射击序列帧.png",
    out = "assets/art/characters/shen_mingyan/battle_skill_2_512x384.png",
    tolerance = 62,
    -- 新版沈明待机帧约 50px 高；拔枪原图也按同一高度、同一脚底对齐。
    -- 旧值放大 2 倍后会让拔枪瞬间变成两倍高。
    normalize_scale = 1,
    target_center_x = 64,
    target_bottom_y = 91,
  },
  {
    src = "assets/art/incoming_0927/眷族1号小人战斗待机.png",
    out = "assets/art/enemies/kin_idle_512x384.png",
    tolerance = 34,
  },
}

local function rgba(c)
  if type(c) == "number" then
    return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c),
           app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c)
  end
  return c.red, c.green, c.blue, c.alpha
end

local function close_to_background(pixel, br, bg, bb, tolerance)
  local r, g, b, a = rgba(pixel)
  if a == 0 then return true end
  return math.abs(r - br) + math.abs(g - bg) + math.abs(b - bb) <= tolerance
end

for _, job in ipairs(JOBS) do
  local spr = app.open(job.src)
  local image = spr.cels[1].image
  local width, height = spr.width, spr.height
  local br, bg, bb = rgba(image:getPixel(2, 2))
  local seen = {}
  local qx, qy = {}, {}
  local head, tail = 1, 0

  local function push(x, y)
    if x < 0 or y < 0 or x >= width or y >= height then return end
    local key = y * width + x
    if seen[key] then return end
    if not close_to_background(image:getPixel(x, y), br, bg, bb, job.tolerance) then return end
    seen[key] = true
    tail = tail + 1
    qx[tail], qy[tail] = x, y
  end

  for x = 0, width - 1 do
    push(x, 0)
    push(x, height - 1)
  end
  for y = 0, height - 1 do
    push(0, y)
    push(width - 1, y)
  end

  while head <= tail do
    local x, y = qx[head], qy[head]
    head = head + 1
    image:putPixel(x, y, Color(0, 0, 0, 0))
    push(x - 1, y)
    push(x + 1, y)
    push(x, y - 1)
    push(x, y + 1)
  end

  -- 按统一中心与脚底重新对齐；scale=1 时只做定位，不改变像素密度。
  if job.normalize_scale then
    local normalized = Image(width, height, ColorMode.RGB)
    for frame = 0, 11 do
      local ox = (frame % 4) * 128
      local oy = math.floor(frame / 4) * 128
      local minx, miny, maxx, maxy = 128, 128, -1, -1
      for y = 0, 127 do
        for x = 0, 127 do
          local _, _, _, a = rgba(image:getPixel(ox + x, oy + y))
          if a > 0 then
            minx, miny = math.min(minx, x), math.min(miny, y)
            maxx, maxy = math.max(maxx, x), math.max(maxy, y)
          end
        end
      end
      if maxx >= minx then
        local source_w, source_h = maxx - minx + 1, maxy - miny + 1
        local scale = job.normalize_scale
        local left = math.floor(job.target_center_x - source_w * scale * 0.5)
        local top = job.target_bottom_y - source_h * scale + 1
        for sy = 0, source_h - 1 do
          for sx = 0, source_w - 1 do
            local pixel = image:getPixel(ox + minx + sx, oy + miny + sy)
            for dy = 0, scale - 1 do
              for dx = 0, scale - 1 do
                normalized:putPixel(ox + left + sx * scale + dx,
                  oy + top + sy * scale + dy, pixel)
              end
            end
          end
        end
      end
    end
    spr.cels[1].image = normalized
  end

  spr:saveAs(job.out)
  print(string.format("已生成 %s，去除 %d 个背景像素", job.out, tail))
  spr:close()
end

print("角色序列帧处理完成")
