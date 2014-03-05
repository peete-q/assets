
local _M = {}
local _debug, _warn, _error = require("qlog").loggers("pkgutil")
function _M.pkgname(filename)
  return filename:gsub("[.][^.]+$", ""):gsub("/", ".")
end
local util = require("util")
function _M.replace(pkgname, source, loader)
  if pkgname == nil then
    pkgname = _M.pkgname(source)
  end
  if loader == nil then
    loader = dofile
  end
  local reloaded = false
  local t = package.loaded[pkgname]
  if t ~= nil then
    do
      local newt = loader(source, pkgname)
      if type(t) == "table" and type(newt) == "table" then
        if _debug then
          _debug(string.format("REPLACE package.loaded[%q] contents with %s(%s)", pkgname, debug.getfuncinfo(loader), tostring(source)))
        end
        for k, v in pairs(t) do
          t[k] = nil
        end
        for k, v in pairs(newt) do
          t[k] = v
        end
        setmetatable(t, getmetatable(newt))
      elseif newt == nil then
        if _debug then
          _debug(string.format("ASSIGN package.loaded[%q] = true", pkgname))
        end
        package.loaded[pkgname] = true
      else
        if _debug then
          _debug(string.format("ASSIGN package.loaded[%q] = %s", pkgname, tostring(newt)))
        end
        package.loaded[pkgname] = newt
      end
      reloaded = true
    end
  else
    if _debug then
      _debug(string.format("ASSIGN package.preload[%q] = %s", pkgname, debug.getfuncinfo(loader)))
    end
    package.preload[pkgname] = function(modname)
      return loader(source, modname)
    end
  end
  return reloaded
end
return _M
