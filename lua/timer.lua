

local timer = {}
timer.__index = timer

function timer.new(span, cb)
	local self = MOAITimer.new()
	self:setSpan(span)
	self:setMode(MOAITimer.LOOP)
	self:setListener(MOAITimer.EVENT_TIMER_END_SPAN, cb)
	self:start()
	return self
end

return timer