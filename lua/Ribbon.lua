local device = require("device")
local file = require("file")
local ui = require("ui")
local url = require("url")
local util = require("util")
local particleSystemNew = ui.ParticleSystem.new
local header = "particles/"
local headerlo = "particles_lo/"
local breakstr = util.breakstr
local Ribbon = {}
Ribbon.__index = Ribbon
function Ribbon.new(ribbonFile)
  local ribbonTex, queryStr = breakstr(ribbonFile, "?")
  local x, y
  if queryStr ~= nil then
    q = url.parse_query(queryStr)
    if q.loc ~= nil then
      x, y = breakstr(q.loc, ",")
      x = tonumber(x)
      y = tonumber(y)
    end
    loop = q.looping
  end
  local system
  if device.perf == device.CPU_LO and file.exists(headerlo .. ribbonTex .. ".lua") then
    system = particleSystemNew(headerlo .. ribbonTex .. ".lua")
  else
    system = particleSystemNew(header .. ribbonTex .. ".lua")
  end
  if not system then
    return
  end
  o = ui.new(MOAIProp2D.new())
  o.system = o:add(system)
  if x then
    o:setLoc(x, y)
  end
  o.destroy = Ribbon.destroy
  o.system:startSystem()
  return o
end
function Ribbon:destroy()
  self.system:stopSystem()
  self:remove()
end
return Ribbon
