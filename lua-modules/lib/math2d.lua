local math = math
local _M = {}
local cos = math.cos
local sin = math.sin
local atan2 = math.atan2
local sqrt = math.sqrt
local random = math.random
local min = math.min
local max = math.max
local LENGTH_NUDGE = 1.0E-10
function _M.distance(x0, y0, x1, y1)
  local dx = x1 - x0
  local dy = y1 - y0
  return sqrt(dx * dx + dy * dy)
end
local _distance = _M.distance
function _M.distanceSq(x0, y0, x1, y1)
  local dx = x1 - x0
  local dy = y1 - y0
  return dx * dx + dy * dy
end
local _distanceSq = _M.distanceSq
function _M.length(dx, dy)
  return sqrt(dx * dx + dy * dy)
end
local _length = _M.length
function _M.lengthSq(dx, dy)
  return dx * dx + dy * dy
end
local _lengthSq = _M.lengthSq
function _M.dot(x0, y0, x1, y1)
  return x0 * x1 + y0 * y1
end
function _M.normalize(dx, dy)
  local len = sqrt(dx * dx + dy * dy) + LENGTH_NUDGE
  return dx / len, dy / len, len
end
function _M.randomPointInCircle(centerX, centerY, radius)
  return centerX + random(-radius, radius), centerY + random(-radius, radius)
end
function _M.randomPointInRect(centerX, centerY, halfX, halfY)
  return centerX + random(-halfX, halfX), centerY + random(-halfY, halfY)
end
function _M.polar(x, y)
  return atan2(y, x), sqrt(x * x + y * y)
end
function _M.cartesian(theta, r)
  return cos(theta) * r, sin(theta) * r
end
function _M.segmentsIntersect(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
  local dx_a = ax1 - ax0
  local dy_a = ay1 - ay0
  local dx_b = bx1 - bx0
  local dy_b = by1 - by0
  local delta = dx_b * dy_a - dy_b * dx_a
  if delta == 0 then
    return false
  end
  local s = (dx_a * (by0 - ay0) + dy_a * (ax0 - bx0)) / delta
  local t = (dx_b * (ay0 - by0) + dy_b * (bx0 - ax0)) / -delta
  return s >= 0 and s <= 1 and t >= 0 and t <= 1
end
local _segmentsIntersect = _M.segmentsIntersect
function _M.pointSegmentDistanceSq(px, py, x0, y0, x1, y1)
  local dx = x1 - x0
  local dy = y1 - y0
  if dx == dy and dx == 0 then
    return _distance(px, py, x0, y0)
  end
  local t = ((px - x0) * dx + (py - y0) * dy) / (dx * dx + dy * dy)
  if t < 0 then
    dx = px - x0
    dy = py - y0
  elseif t > 1 then
    dx = px - x1
    dy = py - y1
  else
    local nearx = x0 + t * dx
    local neary = y0 + t * dy
    dx = px - nearx
    dy = py - neary
  end
  return dx * dx + dy * dy
end
local _pointSegmentDistanceSq = _M.pointSegmentDistanceSq
function _M.pointSegmentDistance(px, py, x0, y0, x1, y1)
  return sqrt(_pointSegmentDistanceSq(px, py, x0, y0, x1, y1))
end
local _pointSegmentDistance = _M.pointSegmentDistance
function _M.segmentsDistance(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
  if _segmentsIntersect(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1) then
    return 0
  end
  local d
  d = _pointSegmentDistance(ax0, ay0, bx0, by0, bx1, by1)
  d = min(d, _pointSegmentDistance(ax1, ay1, bx0, by0, bx1, by1))
  d = min(d, _pointSegmentDistance(bx0, by0, ax0, ay0, ax1, ay1))
  d = min(d, _pointSegmentDistance(bx1, by1, ax0, ay0, ax1, ay1))
  return d
end
return _M
