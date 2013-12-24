local MOAIAction = {}
MOAIAction.__index = MOAIAction
function MOAIAction.new()
  local o = {}
  setmetatable(o, MOAIAction)
  return o
end
function MOAIAction:start()
end
function MOAIAction:stop()
end
function MOAIAction:throttle(scale)
end
return MOAIAction
