local ui = require("ui")
local device = require("device")
local file = require("file")
local resource = require("resource")
local compat = require("moai.compat")
local util = require("util")
local url = require("url")
local breakstr = util.breakstr
local Particle = {}
Particle.__index = Particle
function Particle.new(path, aset, override)
  local newpath, queryStr = breakstr(path, "?")
  local self
  if device.perf == device.CPU_LO and (device.cpu == device.CPU_LO or not override) then
    if file.exists("particles_lo/" .. newpath) then
      self = ui.ParticleSystem.new("particles_lo/" .. newpath)
    else
      self = ui.new(MOAIProp2D.new())
      self.startSystem = Particle.noop
      self.stopEmitters = Particle.noop
      self.stopSystem = Particle.noop
      self.surgeSystem = Particle.noop
      self.updateSystem = Particle.noop
      self.begin = Particle.noop
      self.cancel = Particle.noop
      self.startAction = Particle.noop
      self.update = Particle.noop
      self.destroy = Particle.noop
      self.clearSprites = Particle.noop
      self._uiname = newpath
      return self
    end
  else
    self = ui.ParticleSystem.new("particles/" .. newpath)
  end
  if self._duration == -1 then
    self.looping = true
  end
  if queryStr ~= nil then
    local q = url.parse_query(queryStr)
    self.dur = q.dur
    self.looping = q.looping
    self.delay = q.delay
  end
  self.aset = aset
  self.begin = Particle.begin
  self.cancel = Particle.cancel
  self.startAction = Particle.startAction
  self.update = Particle.update
  self.destroy = Particle.destroy
  self._uiname = newpath
  return self
end
function Particle:startAction()
  local aset = self.aset
  if aset then
    aset:wrap(self)
    for k, v in pairs(self.emitters) do
      aset:wrap(v)
    end
  else
    self:startSystem()
  end
  if not self.looping then
    self._action = self.aset:delaycall(self.dur or self._duration, function()
      self:stopEmitters()
      self._action = self.aset:delaycall(self._lifespan, function()
        self._action = nil
        if self.destroyAtEnd then
          self:destroy()
        else
          self:cancel()
        end
      end)
    end)
  end
end
function Particle:begin(destroyAtEnd)
  self.destroyAtEnd = destroyAtEnd
  if self._delayAction then
    self._delayAction:setListener(MOAITimer.EVENT_TIMER_LOOP, nil)
    self._delayAction:stop()
    self._delayAction = nil
  end
  if self._action then
    self._action:setListener(MOAITimer.EVENT_TIMER_LOOP, nil)
    self._action:stop()
    self._action = nil
  end
  if self.delay then
    self._delayAction = self.aset:delayCall(self.delay, self.startAction, self)
  else
    self:startAction()
  end
end
function Particle:cancel()
  if self._delayAction then
    self._delayAction:setListener(MOAITimer.EVENT_TIMER_LOOP, nil)
    self._delayAction:stop()
    self._delayAction = nil
  end
  if self._action then
    self._action:setListener(MOAITimer.EVENT_TIMER_LOOP, nil)
    self._action:stop()
    self._action = nil
  end
  self:stopSystem()
end
function Particle:update()
end
function Particle:destroy()
  self:cancel()
  self:remove()
  self.aset = nil
end
function Particle:noop()
end
return Particle
