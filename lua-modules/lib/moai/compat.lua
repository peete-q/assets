local metatable = require("metatable")
local _M = {}
_M.mock = {}
local _G = _G
local function mockIfNecessary(name)
  if _G[name] == nil then
    _M.mock[name] = true
    _G[name] = require("moai.mock." .. name)
  end
end
mockIfNecessary("MOAISim")
mockIfNecessary("MOAIApp")
mockIfNecessary("MOAIInputMgr")
mockIfNecessary("MOAIHttpTask")
mockIfNecessary("MOAIThread")
mockIfNecessary("MOAIEnvironment")
mockIfNecessary("MOAIAction")
mockIfNecessary("MOAIActionMgr")
mockIfNecessary("MOAITouchSensor")
if _G.crypto == nil then
  _G.crypto = {
    evp = {
      digest = function()
      end
    }
  }
  package.loaded.crypto = _G.crypto
end
if _G.socket == nil then
  _G.socket = {
    core = {}
  }
  package.loaded.socket = _G.socket
  package.loaded["socket.core"] = _G.socket.core
end
MOAI_VERSION_0_4 = 400
MOAI_VERSION_1_0 = 10000
if MOAIThread.new ~= nil and MOAIThread.new().getClass ~= nil then
  MOAI_VERSION = MOAI_VERSION_1_0
else
  MOAI_VERSION = MOAI_VERSION_0_4
end
if _G.os ~= nil then
  if MOAI_VERSION >= MOAI_VERSION_1_0 then
    _G.os.clock = _G.MOAISim.getDeviceTime
  else
    _G.os.clock = _G.MOAISim.getTime
  end
end
function _M:injectMetatable(newmt)
  assert(type(self) == "userdata", "can only extend MOAI userdata")
  assert(type(newmt) == "table", "invalid metatable: " .. tostring(newmt))
  local membert = getmetatable(self)
  if membert._m ~= nil then
    metatable.inject(membert._m, newmt)
  else
    metatable.inject(self, newmt)
  end
  assert(type(membert) == "table", "malformed MOAI userdata instance?")
  return self
end
function _M:clearInjectedMetatables()
  local membert = getmetatable(self)._m
  if membert ~= nil then
    setmetatable(membert, nil)
  end
  return self
end
return _M
