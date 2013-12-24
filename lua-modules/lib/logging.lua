local type, table, string, _tostring, tonumber = type, table, string, tostring, tonumber
local select = select
local error = error
local format = string.format
module("logging")
_COPYRIGHT = "Copyright (C) 2004-2011 Kepler Project"
_DESCRIPTION = "A simple API to use logging features in Lua"
_VERSION = "LuaLogging 1.1.4"
DEBUG = "DEBUG"
INFO = "INFO"
WARN = "WARN"
ERROR = "ERROR"
FATAL = "FATAL"
local LEVEL = {
  "DEBUG",
  "INFO",
  "WARN",
  "ERROR",
  "FATAL"
}
local MAX_LEVELS = #LEVEL
for i = 1, MAX_LEVELS do
  LEVEL[LEVEL[i]] = i
end
local function LOG_MSG(self, level, fmt, ...)
  local f_type = type(fmt)
  if f_type == "string" then
    if select("#", ...) > 0 then
      return self:append(level, format(fmt, ...))
    else
      return self:append(level, fmt)
    end
  elseif f_type == "function" then
    return self:append(level, fmt(...))
  end
  return self:append(level, tostring(fmt))
end
local LEVEL_FUNCS = {}
for i = 1, MAX_LEVELS do
  do
    local level = LEVEL[i]
    LEVEL_FUNCS[i] = function(self, ...)
      return LOG_MSG(self, level, ...)
    end
  end
end
local disable_level = function()
end
local function assert(exp, ...)
  if exp then
    return exp, ...
  end
  error(format(...), 2)
end
function new(append)
  if type(append) ~= "function" then
    return nil, "Appender must be a function."
  end
  local logger = {}
  logger.append = append
  function logger:setLevel(level)
    local order = LEVEL[level]
    assert(order, "undefined level `%s'", _tostring(level))
    self.level = level
    self.level_order = order
    for i = 1, MAX_LEVELS do
      local name = LEVEL[i]:lower()
      if order <= i then
        self[name] = LEVEL_FUNCS[i]
      else
        self[name] = disable_level
      end
    end
  end
  function logger:log(level, ...)
    local order = LEVEL[level]
    assert(order, "undefined level `%s'", _tostring(level))
    if order < self.level_order then
      return
    end
    return LOG_MSG(self, level, ...)
  end
  logger:setLevel(DEBUG)
  return logger
end
function prepareLogMsg(pattern, dt, level, message)
  local logMsg = pattern or "%date %level %message\n"
  message = string.gsub(message, "%%", "%%%%")
  logMsg = string.gsub(logMsg, "%%date", dt)
  logMsg = string.gsub(logMsg, "%%level", level)
  logMsg = string.gsub(logMsg, "%%message", message)
  return logMsg
end
function tostring(value)
  local str = ""
  if type(value) ~= "table" then
    if type(value) == "string" then
      str = string.format("%q", value)
    else
      str = _tostring(value)
    end
  else
    do
      local auxTable = {}
      table.foreach(value, function(i, v)
        if tonumber(i) ~= i then
          table.insert(auxTable, i)
        else
          table.insert(auxTable, tostring(i))
        end
      end)
      table.sort(auxTable)
      str = str .. "{"
      local separator = ""
      local entry = ""
      table.foreachi(auxTable, function(i, fieldName)
        if tonumber(fieldName) and tonumber(fieldName) > 0 then
          entry = tostring(value[tonumber(fieldName)])
        else
          entry = fieldName .. " = " .. tostring(value[fieldName])
        end
        str = str .. separator .. entry
        separator = ", "
      end)
      str = str .. "}"
    end
  end
  return str
end
