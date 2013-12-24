require("moai.compat")
local clock = os.clock
local MOAITimer = MOAITimer
local coroutine = coroutine
local util = require("util")
local pack2 = util.pack2
local unpack2 = util.unpack2
local timerutil = {}
local ui_get_moai_mt = function(o)
  return getmetatable(getmetatable(o))
end
function timerutil.pause(timer)
  timer.pauseTime = timer:getTime()
  local throttleNum = timer.throttleNum
  timer:throttle(0)
  timer.throttleNum = throttleNum
end
function timerutil.resume(timer)
  if timer.pauseTime ~= nil then
    timer:setTime(timer.pauseTime)
    timer.pauseTime = nil
    timer:throttle(timer.throttleNum or 1)
  end
end
function timerutil.isPaused(timer)
  return timer.pauseTime ~= nil
end
function timerutil.throttle(timer, throttle)
  if throttle > 0 then
    timer.pauseTime = nil
  end
  timer.throttleNum = throttle
  local mt = getmetatable(getmetatable(timer))
  mt.throttle(timer, throttle)
end
function timerutil.delaycall(delay, func, ...)
  if delay == nil then
    print(debug.traceback())
  end
  if delay <= 0 then
    func(...)
    return nil
  end
  local args = pack2(...)
  local timer = MOAITimer.new()
  timer:setSpan(delay)
  timer:setMode(MOAITimer.LOOP)
  timer:setListener(MOAITimer.EVENT_TIMER_LOOP, function()
    if timer ~= nil then
      timer:stop()
      timer = nil
      func(unpack2(args))
    end
  end)
  timer:start()
  return timer
end
function timerutil.repeatcall(period, func, ...)
  local timer = MOAITimer.new()
  timer:setSpan(period)
  timer:setMode(MOAITimer.LOOP)
  timer:setListener(MOAITimer.EVENT_TIMER_LOOP, func, ...)
  timer:start()
  return timer
end
function timerutil.repeatcalln(period, n, func, ...)
  if period <= 0 then
    for i = 1, n do
      func(...)
    end
    return nil
  end
  local args = pack2(...)
  local timer = MOAITimer.new()
  timer:setSpan(period)
  timer:setMode(MOAITimer.LOOP)
  timer:setListener(MOAITimer.EVENT_TIMER_LOOP, function()
    if timer:getTimesExecuted() > n then
      timer:stop()
      return
    end
    func(unpack2(args))
  end)
  timer:start()
  return timer
end
function timerutil.cancel(timer)
  timer:stop()
end
function timerutil.spinwait(duration)
  local t0 = clock()
  while true do
    repeat
    until duration > clock() - t0
  end
end
function timerutil.yieldwait(duration)
  local t0 = clock()
  while duration > clock() - t0 do
    coroutine.yield()
  end
end
function timerutil.blockwait(duration)
  local timer = MOAITimer.new()
  timer:setSpan(duration)
  timer:start()
  MOAIThread.blockOnAction(timer)
end
function timerutil.onstop(action, func, ...)
  local args = pack2(...)
  action:setListener(MOAITimer.EVENT_STOP, function()
    func(unpack2(args))
  end)
end
return timerutil
