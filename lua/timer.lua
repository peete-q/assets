
local util = require("util")
local pack2 = util.pack2
local unpack2 = util.unpack2

local timer = {}

function timer.new(span, func, parent)
	local self = MOAITimer.new()
	self.pause = timer.pause
	self.resume = timer.resume
	self.isPaused = timer.isPaused
	self.throttle = timer.throttle
	self.whenStop = timer.whenStop
	self.whenLoop = timer.whenLoop
	self.run = timer.run
	self.runn = timer.runn
	if span then
		self:run(span, func, parent)
	end
	return self
end

function timer.run(self, span, func, parent)
	if span <= 0 then
		func()
		return nil
	end
	self:setSpan(span)
	self:setMode(MOAITimer.LOOP)
	self:whenLoop(func)
	self:start(parent)
	return self
end

function timer.runn(self, span, n, func, parent)
	if span <= 0 then
		func()
		return nil
	end
	self:setMode(MOAITimer.LOOP)
	self:whenLoop(function()
		if self:getTimesExecuted() > n then
			self:stop()
			return
		end
		func()
	end)
	self:start(parent)
	return self
end

function timer.start(self, parent)
	if not parent then
		local mt = getmetatable(getmetatable(self))
		mt.start(self)
	else
		self:attach(parent)
	end
end

function timer.pause(self)
	self.pauseTime = self:getTime()
	local throttleValue = self.throttleValue
	self:throttle(0)
	self.throttleValue = throttleValue
end

function timer.resume(self)
	if self.pauseTime ~= nil then
		self:setTime(self.pauseTime)
		self.pauseTime = nil
		self:throttle(self.throttleValue or 1)
	end
end

function timer.isPaused(self)
	return self.pauseTime ~= nil
end

function timer.throttle(self, value)
	if value > 0 then
		self.pauseTime = nil
	end
	self.throttleValue = value
	local mt = getmetatable(getmetatable(self))
	mt.throttle(self, value)
end

function timer.whenLoop(self, func)
	self:setListener(MOAITimer.EVENT_TIMER_LOOP, func)
end

function timer.whenStop(self, func)
	self:setListener(MOAITimer.EVENT_STOP, func)
end

return timer