
local _floor = math.floor

--- Extend <code>math.floor</code> to take the number of decimal places.
-- @param n number
-- @param p number of decimal places to truncate to (default: 0)
-- @return <code>n</code> truncated to <code>p</code> decimal places
function math.floor (n, p)
  if p and p ~= 0 then
    local e = 10 ^ p
    return _floor (n * e) / e
  else
    return _floor (n)
  end
end

--- Round a number to a given number of decimal places
-- @param n number
-- @param p number of decimal places to round to (default: 0)
-- @return <code>n</code> rounded to <code>p</code> decimal places
function math.round (n, p)
  local e = 10 ^ (p or 0)
  return _floor (n * e + 0.5) / e
end

function math.clamp(val, minVal, maxVal)
	return math.min(math.max(val, minVal), maxVal)
end