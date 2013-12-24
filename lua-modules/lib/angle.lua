local _M = {}
local math = require("math")
local PI = math.pi
local TWO_PI = math.pi * 2
local modf = math.modf
_M.TWO_PI = TWO_PI
function _M.capradian(r)
  local ip, fp = modf(r / TWO_PI)
  return fp * TWO_PI
end
function _M.diff(a0, a1)
  local delta = a1 - a0
  if delta > PI then
    return delta - TWO_PI
  end
  if delta < -PI then
    return delta + TWO_PI
  end
  return delta
end
function _M.absdiff(a0, a1)
  local d1 = a0 - a1
  if d1 < 0 then
    d1 = -d1
  end
  if a0 > PI then
    a0 = a0 - TWO_PI
  end
  if a1 > PI then
    a1 = a1 - TWO_PI
  end
  local d2 = a0 - a1
  if d2 < 0 then
    d2 = -d2
  end
  if d1 < d2 then
    return d1
  else
    return d2
  end
end
return _M
