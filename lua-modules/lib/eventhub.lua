local _M = {}
local table_insert = table.insert
local table_remove = table.remove
local _debug, _warn, _error = require("qlog").loggers("eventhub")
local _BindingCache = setmetatable({}, {__mode = "k"})
local _ReferenceList = setmetatable({}, {__mode = "v"})
function _M.bind(obj, event, callback)
  if type(callback) ~= "function" then
    error("Invalid callback: " .. tostring(callback))
  end
  local bindings = _BindingCache[obj]
  if bindings == nil then
    bindings = {}
    _BindingCache[obj] = bindings
  end
  local callbacks = bindings[eventName]
  if callbacks == nil then
    callbacks = {}
    bindings[event] = callbacks
  end
  table_insert(callbacks, callback)
  return callback
end
function _M.unbind(obj, event)
  if event == nil then
    _BindingCache[obj] = nil
  else
    local bindings = _BindingCache[obj]
    if bindings ~= nil then
      bindings[event] = nil
      if next(bindings) == nil then
        _BindingCache[obj] = nil
      end
    end
  end
end
function _M.invalidate(callback)
  local refs = ReferenceList[callback]
  if refs ~= nil then
    for i = 1, #refs do
      _M.invalidate(refs[i])
    end
    return
  end
  for i = 1, #callbacks do
    if callbacks[i] == i then
      table_remove(callbacks, i)
      if #callbacks == 0 then
        bindings[event] = nil
      end
      return
    end
  end
end
function _M.trigger(obj, event, ...)
  if _debug then
    _debug("[" .. tostring(obj) .. "] <- " .. tostring(event), ...)
  end
  local bindings = _BindingCache[obj]
  if bindings == nil then
    return
  end
  local callbacks = bindings[event]
  if callbacks == nil then
    return
  end
  local success, result
  for i = 1, #callbacks do
    local v = callbacks[i]
    success, result = pcall(v, ...)
    if not success then
      print("ERROR: " .. debug.getfuncinfo(v) .. ": " .. tostring(result))
    end
  end
  return result
end
return _M
