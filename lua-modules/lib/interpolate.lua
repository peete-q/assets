local _M = {}
local math = require("math")
local modf = math.modf
local fmod = math.fmod
function _M.lerp(x0, x1, t)
  return (x1 - x0) * t + x0
end
function _M.lerp2d(x0, y0, x1, y1, t)
  return (x1 - x0) * t + x0, (y1 - y0) * t + y0
end
function _M.lerprot(a0, a1, t)
  if a0 < a1 then
    while a1 - a0 > 180 do
      a1 = a1 - 360
    end
  else
    while a1 - a0 < -180 do
      a1 = a1 + 360
    end
  end
  return (a1 - a0) * t + a0
end
function _M.loop(t, len)
  local ip, fp = modf(t / len)
  return fp * len, 1
end
function _M.pingpong(t, len)
  local ip, fp = modf(t / len)
  if ip % 2 == 1 then
    return len * (1 - fp), -1
  else
    return len * fp, 1
  end
end
function _M.catmullrom(x0, y0, x1, y1, x2, y2, x3, y3, t)
  local t2 = t * t
  local t3 = t2 * t
  local x = 0.5 * (2 * x1 + (-x0 + x2) * t + (2 * x0 - 5 * x1 + 4 * x2 - x3) * t2 + (-x0 + 3 * x1 - 3 * x2 + x3) * t3)
  local y = 0.5 * (2 * y1 + (-y0 + y2) * t + (2 * y0 - 5 * y1 + 4 * y2 - y3) * t2 + (-y0 + 3 * y1 - 3 * y2 + y3) * t3)
  return x, y
end
function _M.catmullrom_slope(x0, y0, x1, y1, x2, y2, x3, y3, t)
  local t2 = t * t
  local dx = 0.5 * (-x0 + x2 + (2 * x0 - 5 * x1 + 4 * x2 - x3) * 2 * t + (-x0 + 3 * x1 - 3 * x2 + x3) * 3 * t2)
  local dy = 0.5 * (-y0 + y2 + (2 * y0 - 5 * y1 + 4 * y2 - y3) * 2 * t + (-y0 + 3 * y1 - 3 * y2 + y3) * 3 * t2)
  return dx, dy
end
function _M.hermite(x0, y0, tanx0, tany0, x1, y1, tanx1, tany1, t)
  local t2 = t * t
  local t3 = t2 * t
  local h1 = 2 * t3 - 3 * t2 + 1
  local h2 = -2 * t3 + 3 * t2
  local h3 = t3 - 2 * t2 + t
  local h4 = t3 - t2
  local d1 = 6 * t2 - 6 * t
  local d2 = -6 * t2 + 6 * t
  local d3 = 3 * t2 - 4 * t + 1
  local d4 = 3 * t2 - 2 * t
  return h1 * x0 + h2 * x1 + h3 * tanx0 + h4 * tanx1, h1 * y0 + h2 * y1 + h3 * tany0 + h4 * tany1, d1 * x0 + d2 * x1 + d3 * tanx0 + d4 * tanx1, d1 * y0 + d2 * y1 + d3 * tany0 + d4 * tany1
end
function _M.bezier(x0, y0, x1, y1, x2, y2, x3, y3, t)
  local t2 = t * t
  local t3 = t2 * t
  local h1 = -t3 + 3 * t2 - 3 * t + 1
  local h2 = 3 * t3 - 6 * t2 + 3 * t
  local h3 = -3 * t3 + 3 * t2
  local h4 = t3
  local d1 = -3 * t2 + 6 * t - 3
  local d2 = 9 * t2 - 12 * t + 3
  local d3 = -9 * t2 + 6 * t
  local d4 = 3 * t2
  return h1 * x0 + h2 * x1 + h3 * x2 + h4 * x3, h1 * y0 + h2 * y1 + h3 * y2 + h4 * y3, d1 * x0 + d2 * x1 + d3 * x2 + d4 * x3, d1 * y0 + d2 * y1 + d3 * y2 + d4 * y3
end
return _M
