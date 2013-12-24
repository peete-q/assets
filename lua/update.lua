require("constants")
local appcache = require("appcache")
local keys = require("keys")
local ui = require("ui")
local file = require("file")
local pkgutil = require("pkgutil")
local device = require("device")
local timerutil = require("timerutil")
local csv = require("csv")
local pkg_dep_loaders = require("pkg_dep_loaders")
local cache, cacheUI, cacheStatus, spinner, showTime
local initialSwap = true
local LOCAL_ACU_CACHE = "acu/core-ShipData/"
local MIN_OVERLAY_TIME = 1.5
local _debug, _warn, _error = require("qlog").loggers("update")
local function _replace_pkg(f, _file, loader)
  local pname = pkgutil.pkgname(f)
  _debug("\treplacing package[" .. pname .. "] with " .. _file)
  pkgutil.replace(pname, _file, loader)
end
local function _replace_pkgs(groupName, localPath, files)
  _debug("")
  _debug("Updating !!! " .. groupName)
  _debug("")
  local err
  for f, sig in pairs(files) do
    _debug("\tchecking replace of " .. f)
    if not file.exists(localPath .. f) then
      return false
    end
    local deploader = pkg_dep_loaders[f]
    if deploader ~= nil then
      deploader(localPath .. f)
    elseif f:find(".lua$") and not f:find("[.][^.]+.lua$") then
      _replace_pkg(f, localPath .. f, deploader)
    end
  end
  _debug("")
  return true
end
local _noop = function(groupName, localPath, files)
end
local GROUP_READY_HANDLERS = {
  ["core-ShipData"] = _replace_pkgs
}
local _M = {}
local function _enable_spinner(value)
  if spinner._uilayer == nil and value then
    _debug("Spinner = " .. tostring(value))
    debugLayer:add(spinner)
    spinner:loop("spinnerAnim")
  elseif spinner._uilayer ~= nil and not value then
    _debug("Spinner = " .. tostring(value))
    spinner:remove()
    spinner:stop()
  end
end
local function _enable_overlay(value)
  local fadeTime = 1
  if value and cacheUI._uilayer == nil then
    _debug("Overlay = " .. tostring(value))
    debugLayer:add(cacheUI)
    showTime = os.clock()
  elseif not value and cacheUI._uilayer ~= nil then
    _debug("Overlay = " .. tostring(value))
    showTime = nil
    cacheUI:remove()
  end
end
local function _csv_with_nums(modname)
  return csv.file_totable(modname .. ".csv", nil, true)
end
function _M.init()
  if cache ~= nil then
    return
  end
  local function _setup_dep(f)
    local loader = pkg_dep_loaders[f]
    assert(loader ~= nil, "custom loader not found: " .. f)
    loader(f)
  end
  _setup_dep("ShipData-GalaxyLevels.csv")
  _setup_dep("ShipData-ShipStats.csv")
  _debug("AppCache URL: " .. APPCACHE_URL)
  cache = appcache.new(APPCACHE_URL, keys)
  cacheUI = ui.PickBox.new(device.ui_width, device.ui_height, "#000a")
  function cacheUI.onClick()
    _debug("Touching Update BG")
    if not cache:busy() then
      _enable_overlay(false)
    end
  end
  cacheStatus = cacheUI:add(ui.TextBox.new(_("Updating Files..."), FONT_MEDIUM, nil, "center", device.ui_width, 100, true))
  spinner = ui.Anim.new("downloadSpinner.atlas.png")
  function cache.onChecking(cache)
    cache.lastErr = nil
    _enable_spinner(true)
    cacheStatus:setString(_("Checking for updates..."))
  end
  function cache.onProgress(cache)
    local n = cache:queueSize()
    if n > 1 then
      cacheStatus:setString(string.format(_("Updating %d files..."), n))
    else
      cacheStatus:setString(_("Updating 1 file..."))
    end
  end
  function cache.onNoUpdate(cache)
    _enable_spinner(false)
    _enable_overlay(false)
  end
  function cache.onUpdateReady(cache)
    _enable_spinner(false)
    cacheStatus:setString("Update is ready.")
    if mainmenu_active() then
      cacheStatus:setString("Updating files...")
      cache:swap()
    end
  end
  function cache.onObsolete(cache)
    _enable_overlay(false)
  end
  function cache.onError(cache, err)
    cache.lastErr = err
    cacheStatus:setString("<c:ff0000>Error: " .. err)
  end
  function cache.onGroupReady(cache, groupName, localPath, files)
    local handler
    local INIT_LUA = "__init__.lua"
    if files[INIT_LUA] ~= nil then
      local success, result = pcall(dofile, localPath .. INIT_LUA)
      if success then
        handler = result
        if handler ~= nil and type(handler) ~= "function" then
          _error(string.format("Group[%q]/%s did not return function: %s", groupName, INIT_LUA, tostring(handler)))
          return
        end
      else
        _error(string.format("Group[%q]/%s encountered an error: ", groupName, INIT_LUA, tostring(result)))
        return
      end
    end
    if handler == nil then
      handler = GROUP_READY_HANDLERS[groupName]
    end
    if handler == nil then
      _debug(string.format("Group[%q] using default ready handler", groupName))
      handler = _replace_pkgs
    end
    local success, result = pcall(handler, groupName, localPath, files)
    if not success then
      _error(string.format("Group[%q] had error in ready handler: %s", groupName, tostring(result)))
    end
    if not result and localPath ~= LOCAL_ACU_CACHE then
      cache.onGroupReady(cache, groupName, LOCAL_ACU_CACHE, files)
    end
  end
  function cache.onSwapStarted(cache)
    _enable_spinner(true)
    cacheStatus:setString("Updating files...")
    if not initialSwap then
      _enable_overlay(true)
    end
    initialSwap = false
  end
  function cache.onSwapComplete(cache)
    cacheStatus:setString("Update complete.")
    local callback = cache.updateApplyCallback
    if callback ~= nil then
      cache.updateApplyCallback = nil
      callback()
    end
  end
  function cache.onIdle(cache)
    _enable_spinner(false)
    if cache.lastErr ~= nil then
      _warn("There was an error. Probably it couldn't find the server")
    elseif showTime ~= nil then
      local t = os.clock() - showTime
      if t >= MIN_OVERLAY_TIME then
        _enable_overlay(false)
      else
        timerutil.delaycall(MIN_OVERLAY_TIME - t, _enable_overlay, false)
      end
    end
  end
  cache:ready("acu")
  cache:update()
end
function _M.queueSize()
  return cache:queueSize()
end
function _M.busy()
  return cache:busy()
end
function _M.check()
  cache:update()
end
function _M.lastUpdateTag()
  return cache:lastUpdateTag()
end
function _M.debugStatus()
  if cache.lastErr ~= nil then
    return "(UPDATE ERR)"
  end
  local status = cache:status()
  if not cache:busy() and cache.lastUpdate ~= nil then
    return cache:lastUpdateTag()
  else
    return string.format("(%s)", cache:status())
  end
end
function _M.retain(groupName)
  cache:retain(groupName)
end
function _M.apply(callback)
  if callback ~= nil then
    assert(cache.updateApplyCallback == nil, "clobbering existing update callback")
    cache.updateApplyCallback = callback
  end
  cacheStatus:setString("Updating files...")
  if not cache:swap() then
    print("No updates ready, skipping")
    cache.updateApplyCallback = nil
    cacheStatus:setString("Update complete.")
    if callback ~= nil then
      callback()
    end
  end
end
function _M.update()
  cache:update()
end
function _M.forceUpdate(roll)
  cache.lastUpdate = 0
  cache.lastUpdateCheck = 0
  cache.etag = nil
  cache:update(roll)
end
function _M.spinnerSetLoc(x, y)
  spinner:setLoc(x, y)
end
return _M
