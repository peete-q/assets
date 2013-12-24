local PersistentTable = {}
PersistentTable.__index = PersistentTable
local file = require("file")
local util = require("util")
local device = require("device")
local crypto = require("crypto")
local setmetatable = setmetatable
local getmetatable = getmetatable
local pcall = pcall
local dofile = dofile
local assert = assert
local os = os
local util = util
local file = file
function PersistentTable.new(filename, basePath, keystore)
  if basePath == true then
    filename = device.getDocumentsPath(filename .. ".lua")
  elseif basePath == false then
    basePath = device.getCachePath(filename .. ".lua")
  elseif basePath ~= nil then
    basePath = basePath .. "/" .. filename .. ".lua"
  end
  local mt = {}
  mt.__index = mt
  mt.file = filename
  function mt.__newindex(t, key, value)
    rawset(t, key, value)
    t:save()
  end
  if type(keystore) == "string" then
    mt.hmac = filename .. ".sha1"
    mt.key = keystore
  end
  setmetatable(mt, PersistentTable)
  local success, t = pcall(function()
    return dofile(filename)
  end)
  if success and mt.hmac then
    local sha = file.read(mt.hmac)
    local hmac = crypto.hmac.new("sha1", keystore)
    local data = hmac:digest(file.read(filename))
    if sha ~= data then
      success = false
    end
  end
  if not success or type(t) ~= "table" then
    t = {}
  end
  setmetatable(t, mt)
  return t
end
function PersistentTable:save()
  local mt = getmetatable(self)
  local data = "return " .. util.tostr(self)
  file.write(mt.file, data, true)
  if mt.hmac then
    local hmac = crypto.hmac.new("sha1", mt.key)
    file.write(mt.hmac, hmac:digest(data))
  end
end
function PersistentTable:append(value)
  table.insert(self, value)
  self:save()
end
function PersistentTable:prepend(value)
  table.insert(self, 1, value)
  self:save()
end
function PersistentTable:remove(n)
  if n == nil then
    n = #self
  end
  local result = self[n]
  table.remove(self, n)
  self:save()
  return result
end
function PersistentTable:pop()
  return self:remove(nil)
end
function PersistentTable:push(value)
  return self:append(value)
end
function PersistentTable:put(key, value)
  self[key] = value
  self:save()
end
return PersistentTable
