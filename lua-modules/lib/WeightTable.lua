local _M = {}
_M.__index = _M
_M.__mode = "k"
function _M.new(tt)
  tt = tt or {}
  setmetatable(tt, _M)
  return tt
end
function _M:set(item, w)
  if item ~= nil then
    self[item] = w
  end
end
function _M:add(item, w)
  if item ~= nil then
    local _w = self[item]
    self[item] = (_w or 0) + w
  end
end
function _M:mul(item, w)
  if item ~= nil then
    local _w = self[item]
    self[item] = (_w or 1) * w
  end
end
function _M:reset()
  for k, v in pairs(self) do
    self[k] = nil
  end
end
function _M:lowest()
  local item, best
  for i, w in pairs(self) do
    if item == nil or w < best then
      item = i
      best = w
    end
  end
  return item, best
end
function _M:highest()
  local item, best
  for i, w in pairs(self) do
    if item == nil or best < w then
      item = i
      best = w
    end
  end
  return item, best
end
return _M
