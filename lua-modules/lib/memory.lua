local util = require("util")
local MOAISim = MOAISim
local collectgarbage = collectgarbage
local printfln = util.printfln
local memory = {}
function memory.usage(unit)
  unit = unit or "m"
  return MOAISim.getMemoryUsage("m")._sys_rss or 0
end
function memory.fullgc()
  local mem0 = collectgarbage("count")
  collectgarbage("collect")
  local mem1 = collectgarbage("count")
  printfln("Lua Memory Usage: %d KB (collected %d KB via fullgc)", mem1, mem0 - mem1)
end
return memory
