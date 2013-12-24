local _M = {}
local print = print
local format = string.format
local write = io.write
local flush = io.flush
local rawget = rawget
local tostring = tostring
local function _log(level, name, ...)
  if name ~= nil then
    print(format("%-5s [%s] ", level, name), ...)
  else
    print(format("%-5s ", level), ...)
  end
  flush()
end
local function _newlogger(name)
  return {
    debug = function(...)
      return _log("DEBUG", name, ...)
    end,
    warn = function(...)
      return _log("WARN", name, ...)
    end,
    error = function(...)
      return _log("ERROR", name, ...)
    end,
    fatal = function(...)
      _log("FATAL", name, ...)
      os.exit(1)
    end
  }
end
local _rootlogger = _newlogger()
local _loggers = setmetatable({}, {
  __mode = "v",
  __index = function(t, k)
    if k == nil then
      return _rootlogger
    end
    local l = rawget(t, k)
    if l == nil then
      l = _newlogger(k)
      t[k] = l
    end
    return l
  end
})
function _M.debug(name, ...)
  return _loggers[name].debug(...)
end
function _M.warn(name, ...)
  return _loggers[name].warn(...)
end
function _M.error(name, ...)
  return _loggers[name].error(...)
end
function _M.fatal(name, ...)
  return _loggers[name].fatal(...)
end
function _M.exists(name)
  return rawget(_loggers, name) ~= nil
end
function _M.logger(name)
  return _loggers[name]
end
function _M.loggers(name)
  local l = _loggers[name]
  return l.debug, l.warn, l.error, l.fatal
end
return _M
