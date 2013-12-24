local _M = {}
function _M.bresenham(x0, y0, x1, y1, f, inc)
  inc = 1
  local w = x1 - x0
  local h = y1 - y0
  local dx1 = 0
  local dy1 = 0
  local dx2 = 0
  local dy2 = 0
  if w < 0 then
    dx1 = -1
  elseif w > 0 then
    dx1 = 1
  end
  if h < 0 then
    dy1 = -1
  elseif h > 0 then
    dy1 = 1
  end
  if w < 0 then
    dx2 = -1
  elseif w > 0 then
    dx2 = 1
  end
  local longest = math.abs(w / inc)
  local shortest = math.abs(h / inc)
  if not (longest > shortest) then
    longest = math.abs(h / inc)
    shortest = math.abs(w / inc)
    if h < 0 then
      dy2 = -1
    elseif h > 0 then
      dy2 = 1
    end
    dx2 = 0
  end
  local numerator = math.floor(longest / 2)
  for i = 0, longest do
    if f(x0, y0) == false then
      return false
    end
    numerator = numerator + shortest
    if not (longest > numerator) then
      numerator = numerator - longest
      x0 = x0 + dx1 * inc
      y0 = y0 + dy1 * inc
    else
      x0 = x0 + dx2 * inc
      y0 = y0 + dy2 * inc
    end
  end
  return true
end
return _M
