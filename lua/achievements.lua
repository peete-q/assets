local util = require("util")
local device = require("device")
local analytics = require("analytics")
local gamecenter = require("gamecenter")
local math = math
local floor = math.floor
local min = math.min
local set_if_nil = util.set_if_nil
local profile = get_profile()
local _debug, _warn, _error = require("qlog").loggers("achievements")
local _M = {}
local defs = {}
local checklist = {}
function _M.get_defs()
  return defs
end
function _M.set(id, step, save)
  local def = defs[id]
  if def == nil then
    _error(id .. ": Does not exist.")
    return
  end
  set_if_nil(profile.achievements, id, {})
  set_if_nil(profile.achievements[id], "step", 0)
  set_if_nil(profile.achievements[id], "unlock", false)
  local profileDef = profile.achievements[id]
  profileDef.step = step
  if save then
    profile:save()
  end
end
function _M.update(id, step, checkAchieved, save)
  local def = defs[id]
  if def == nil then
    _error(id .. ": Does not exist.")
    return
  end
  set_if_nil(profile.achievements, id, {})
  set_if_nil(profile.achievements[id], "step", 0)
  set_if_nil(profile.achievements[id], "unlock", false)
  local profileDef = profile.achievements[id]
  profileDef.step = profileDef.step + step
  if checkAchieved then
    local achieved = profileDef.unlock
    local perc
    if not achieved then
      perc = 0
      perc = min(floor(profileDef.step / def.steps * 100), 100)
      if perc == 100 then
        profileDef.unlock = true
        popup_achievement_show(def, true)
      end
    end
  end
  if device.os == device.OS_IOS then
    local perc = min(floor(profileDef.step / def.steps * 100), 100)
    gamecenter.update(id, perc)
  end
  if save then
    profile:save()
  end
end
function _M.checklist_get(id)
  local def = defs[id]
  if def == nil then
    _error(id .. ": Does not exist.")
    return
  end
  return checklist[id]
end
function _M.checklist_set(id, value)
  local def = defs[id]
  if def == nil then
    _error(id .. ": Does not exist.")
    return
  end
  checklist[id] = value
end
function _M.checklist_check(id)
  local def = defs[id]
  if def == nil then
    _error(id .. ": Does not exist.")
    return
  end
  checklist[id] = true
end
function _M.checklist_fail(id)
  local def = defs[id]
  if def == nil then
    _error(id .. ": Does not exist.")
    return
  end
  checklist[id] = false
end
function _M.checklist_reset()
  checklist = {}
  checklist.nodamage = true
  checklist.turkey = true
  checklist.turkey_noomega = true
  checklist.turkey_plain = true
  checklist.fast_forward = true
end
function _M.init()
  local DEFS = require("ShipData-Achievements")
  for i, v in ipairs(DEFS) do
    defs[v.id] = DEFS[i]
  end
end
return _M
