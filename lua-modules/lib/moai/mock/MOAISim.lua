local MOAISim = {}
MOAISim.getTime = os.clock
MOAISim.getDeviceTime = os.clock
MOAISim.getElapsedTime = os.clock
MOAISim.getSimTime = os.clock
function MOAISim.getDeviceSize()
  return 640, 480
end
function MOAISim.getMemoryUsage()
  return {_sys_rss = 0}
end
return MOAISim
