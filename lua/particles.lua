local compat = require("moai.compat")
local util = require("util")
local url = require("url")
local breakstr = util.breakstr

local Particle = {}
Particle.__index = Particle
function Particle.new(path, aset, layer)
  local newpath, queryStr = breakstr(path, "?")
  local self = ParticleSystem.new(newpath)
  self.layer = layer
  layer:insertProp(self)
  
  if self._duration == -1 then
    self.looping = true
  end
  if queryStr ~= nil then
    local q = url.parse_query(queryStr)
    self.duration = q.duration
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
    self._action = self.aset:delaycall(self.duration or self._duration, function()
      self:stopEmitters()
      self._action = self.aset:delaycall(self._lifespan, function()
        self._action = nil
		if self.onDestroy then
			self.onDestroy()
		end
		self:destroy()
      end)
    end)
  end
end
function Particle:begin(onDestroy)
  self.onDestroy = onDestroy
  if self._delayAction then
    self._delayAction:setListener(MOAITimer.EVENT_TIMER_END_SPAN, nil)
    self._delayAction:stop()
    self._delayAction = nil
  end
  if self._action then
    self._action:setListener(MOAITimer.EVENT_TIMER_END_SPAN, nil)
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
    self._delayAction:setListener(MOAITimer.EVENT_TIMER_END_SPAN, nil)
    self._delayAction:stop()
    self._delayAction = nil
  end
  if self._action then
    self._action:setListener(MOAITimer.EVENT_TIMER_END_SPAN, nil)
    self._action:stop()
    self._action = nil
  end
  self:stopSystem()
end
function Particle:update()
end
function Particle:destroy()
	self:cancel()
	if self.layer then
		self.layer:removeProp(self)
	end
	self.aset = nil
end
function Particle:noop()
end

return Particle