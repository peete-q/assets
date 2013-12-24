local device = require("device")
local file = require("file")
local _M = {}
_M.__index = _M
local _itemPath = function(self, n)
  return string.format("%s/%010d.dat", self.basePath, n)
end
local function _save(self)
  if self.idx == nil then
    file.remove(self.basePath .. "/index.lua")
  else
    file.serialize(self.basePath .. "/index.lua", self.idx, true)
  end
end
function _M.new(name, basePath)
  if basePath == nil or basePath == true then
    basePath = device.getDocumentsPath("_Q/" .. name)
  elseif basePath == false then
    basePath = device.getCachePath("_Q/" .. name)
  else
    basePath = basePath .. "/" .. name
  end
  local self = {
    basePath = basePath,
    idx = file.deserialize(basePath .. "/index.lua")
  }
  setmetatable(self, _M)
  return self
end
function _M:empty()
  return self.idx == nil
end
function _M:len()
  local idx = self.idx
  if idx == nil then
    return 0
  end
  return idx.tail - idx.head
end
function _M:remove(withResult)
  if self.idx == nil then
    return nil
  end
  local h = self.idx.head
  local f = _itemPath(self, h)
  local result
  if withResult == nil or withResult then
    result = file.deserialize(f)
  end
  file.remove(f)
  h = h + 1
  if h == self.idx.tail then
    self.idx = nil
  else
    self.idx.head = h
  end
  _save(self)
  return result
end
function _M:peek(n)
  if self.idx == nil then
    return nil
  end
  if n == nil then
    n = 1
  end
  local i = self.idx.head + n - 1
  if i >= self.idx.tail then
    return nil
  end
  return file.deserialize(_itemPath(self, i))
end
function _M:add(value)
  if value == nil then
    return
  end
  if self.idx == nil then
    self.idx = {head = 1, tail = 1}
  end
  file.serialize(_itemPath(self, self.idx.tail), value, true)
  self.idx.tail = self.idx.tail + 1
  _save(self)
end
function _M:delete()
  file.remove(self.basePath, true)
end
return _M
