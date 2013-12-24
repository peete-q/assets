local device = require("device")
local ui = require("ui")
local url = require("url")
local resource = require("resource")
local math2d = require("math2d")
local gfxutil = require("gfxutil")
local util = require("util")
local interpolate = require("interpolate")
local entitydef = require("entitydef")
local color = require("color")
local actionset = require("actionset")
local timerutil = require("timerutil")
local soundmanager = require("soundmanager")
local util = require("util")
local gfxutil = require("gfxutil")
local update = require("update")
local popups = require("popups")
local analytics = require("analytics")
local achievements = require("achievements")
local gamecenter = require("gamecenter")
local storeiap = require("storeiap")
local cloud = require("cloud")
local file = require("file")
local _debug, _warn, _error = require("qlog").loggers("menu")
local math = math
local random = math.random
local deg = math.deg
local sqrt = math.sqrt
local atan2 = math.atan2
local normalize = math2d.normalize
local distance = math2d.distance
local dot = math2d.dot
local dot = math2d.dot
local PI = math.pi
local cos = math.cos
local sin = math.sin
local floor = math.floor
local ceil = math.ceil
local abs = math.abs
local min = math.min
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local table_concat = table.concat
local breakstr = util.breakstr
local set_if_nil = util.set_if_nil
local bucket = resource.bucket
local profile = get_profile()
local _M = {}
local _debug_root, debugBtn
local function _max_player_level()
  profile.level = 25
  profile:save()
end
local function _unlock_all_levels()
  if not GALAXY_DATA then
    return
  end
  local galaxy = 1
  local levelSystem
  while GALAXY_DATA[(galaxy - 1) * 40 + 1] do
    levelSystem = 1
    set_if_nil(profile.levels, galaxy, {})
    set_if_nil(profile.levels[galaxy], "kills", 0)
    while levelSystem <= 40 do
      set_if_nil(profile.levels[galaxy], levelSystem, {})
      local profileLevelDef = profile.levels[galaxy][levelSystem]
      if profileLevelDef.stars == nil then
        profileLevelDef.stars = 0
      end
      levelSystem = levelSystem + 1
    end
    galaxy = galaxy + 1
    break
  end
  profile:save()
end
local function _unlock_all_ships()
  for i, def in pairs(entitydef) do
    if def.type == "capitalship" then
      local upgradeNum = def._upgradeNum
      local baseID = def._baseID
      if upgradeNum == 0 and def.storeTexture and not def.excludeWarpMenu and (not profile.unlocks[baseID] or not profile.unlocks[baseID].unlocked) then
        local itemId = "ship." .. def._id
        profile.unlocks[baseID] = {
          unlocked = true,
          currentUpgrade = 0,
          popupUnlock = true
        }
      end
    end
  end
  profile:save()
end
local _vincible_ships = function()
  level_foreach_object_of_type("capitalship", function(self)
    self.unkillable = nil
  end)
end
local _invincible_ships = function()
  level_foreach_object_of_type("capitalship", function(self)
    self.unkillable = true
  end)
end
local _max_crystals = function()
  scores.blue = maxDC
end
local function _win_level()
  popups.clear_queue()
  end_game(true)
  level_clear()
  menu_show("victory")
end
local _lose_level = function()
  end_game()
  level_clear()
  menu_show("defeat")
end
local function _hide_hud()
  DEBUG_HIDE_HUD = true
  debugBtn._up:setColor(0, 0, 0, 0)
end
local survival_mode_debug, survival_mode_debug_action
local function _survival_mode_debug()
  if survival_mode_debug == nil then
    survival_mode_debug = debugLayer:add(ui.Group.new())
    do
      local survivalmodeText = survival_mode_debug:add(ui.TextBox.new("Survival Mode", FONT_SMALL_BOLD, "ffffff", "left", device.ui_width - 20, nil, true))
      survivalmodeText:setLoc(0, device.ui_height / 2 - UI_BAR_HEIGHT - 8 + 15)
      local sessionArcText = survival_mode_debug:add(ui.TextBox.new("Session Arc: " .. (DEBUG_SURVIVAL_ARC or 0), FONT_SMALL_BOLD, "ffffff", "left", device.ui_width - 20, nil, true))
      sessionArcText:setLoc(0, device.ui_height / 2 - UI_BAR_HEIGHT - 8 + 15 - 25)
      local sessionWaveText = survival_mode_debug:add(ui.TextBox.new("Session Wave: " .. (DEBUG_SURVIVAL_WAVE or 0), FONT_SMALL_BOLD, "ffffff", "left", device.ui_width - 20, nil, true))
      sessionWaveText:setLoc(0, device.ui_height / 2 - UI_BAR_HEIGHT - 8 + 15 - 50)
      local sessionStrengthText = survival_mode_debug:add(ui.TextBox.new("Session Strength: " .. (curLevelGalaxyStrength or 0), FONT_SMALL_BOLD, "ffffff", "left", device.ui_width - 20, nil, true))
      sessionStrengthText:setLoc(0, device.ui_height / 2 - UI_BAR_HEIGHT - 8 + 15 - 75)
      survival_mode_debug_action = timerutil.repeatcall(1, function()
        sessionArcText:setString("Session Arc: " .. (DEBUG_SURVIVAL_ARC or 0))
        sessionWaveText:setString("Session Wave: " .. (DEBUG_SURVIVAL_WAVE or 0))
        sessionStrengthText:setString("Session Strength: " .. (curLevelGalaxyStrength or 0))
      end)
    end
  else
    survival_mode_debug_action:stop()
    survival_mode_debug_action = nil
    survival_mode_debug:remove()
    survival_mode_debug = nil
  end
end
local _survival_mode_next_iteration = function()
  survival_next_iteration()
end
local function _AB_test_A()
  if not update:busy() then
    update.forceUpdate(0)
  end
end
local function _AB_test_B()
  if not update:busy() then
    update.forceUpdate(1)
  end
end
local function _debug_close()
  _debug_root:remove()
  _debug_root = nil
end
local function _debug_show()
  _debug_root = debugLayer:add(ui.Group.new())
  local debugBG = _debug_root:add(ui.PickBox.new(device.ui_width, device.ui_height, color.toHex(0.178824, 0.178824, 0.178824, 0.8)))
  function debugBG.handleTouch()
    return true
  end
  local debugBtn = _debug_root:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategoryAll.png"))
  debugBtn._down:setColor(0.5, 0.5, 0.5)
  debugBtn:setScl(0.5, 0.5)
  debugBtn:setLoc(-device.ui_width / 2 + 24, device.ui_height / 2 - 24)
  function debugBtn.onClick()
    _debug_close()
  end
  local width = 500
  local height = 850
  local y = -50
  local yOffset = -80
  local debugBox = _debug_root:add(ui.NinePatch.new("boxPlain9p.lua", width, height))
  local label = debugBox:add(ui.TextBox.new("Max Player Level", FONT_MEDIUM, "ffffff", "left", 460, nil, true))
  label:setLoc(0, height / 2 + y)
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(210, height / 2 + y)
  function btn.onClick()
    _max_player_level()
  end
  y = y + yOffset
  local label = debugBox:add(ui.TextBox.new("Unlock All Levels", FONT_MEDIUM, "ffffff", "left", 460, nil, true))
  label:setLoc(0, height / 2 + y)
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(210, height / 2 + y)
  function btn.onClick()
    _unlock_all_levels()
  end
  y = y + yOffset
  local label = debugBox:add(ui.TextBox.new("Unlock All Ships", FONT_MEDIUM, "ffffff", "left", 460, nil, true))
  label:setLoc(0, height / 2 + y)
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(210, height / 2 + y)
  function btn.onClick()
    _unlock_all_ships()
  end
  y = y + yOffset
  local label = debugBox:add(ui.TextBox.new("Invincible Ships", FONT_MEDIUM, "ffffff", "left", 460, nil, true))
  label:setLoc(0, height / 2 + y)
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(110, height / 2 + y)
  function btn.onClick()
    _invincible_ships()
  end
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  btn:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(210, height / 2 + y)
  function btn.onClick()
    _vincible_ships()
  end
  y = y + yOffset
  local label = debugBox:add(ui.TextBox.new("Max Warp Crystals", FONT_MEDIUM, "ffffff", "left", 460, nil, true))
  label:setLoc(0, height / 2 + y)
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(210, height / 2 + y)
  function btn.onClick()
    _max_crystals()
  end
  y = y + yOffset
  local label = debugBox:add(ui.TextBox.new("Win Level", FONT_MEDIUM, "ffffff", "left", 460, nil, true))
  label:setLoc(0, height / 2 + y)
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(110, height / 2 + y)
  function btn.onClick()
    _win_level()
  end
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  btn:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(210, height / 2 + y)
  function btn.onClick()
    _lose_level()
  end
  y = y + yOffset
  local label = debugBox:add(ui.TextBox.new("Hide Game HUD", FONT_MEDIUM, "ffffff", "left", 460, nil, true))
  label:setLoc(0, height / 2 + y)
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(210, height / 2 + y)
  function btn.onClick()
    _hide_hud()
  end
  y = y + yOffset
  local label = debugBox:add(ui.TextBox.new("Show Survival Mode Debug", FONT_MEDIUM, "ffffff", "left", 460, nil, true))
  label:setLoc(0, height / 2 + y)
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(210, height / 2 + y)
  function btn.onClick()
    _survival_mode_debug()
  end
  y = y + yOffset
  local label = debugBox:add(ui.TextBox.new("Survival Mode Next Iteration", FONT_MEDIUM, "ffffff", "left", 460, nil, true))
  label:setLoc(0, height / 2 + y)
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(210, height / 2 + y)
  function btn.onClick()
    _survival_mode_next_iteration()
  end
  y = y + yOffset
  local label = debugBox:add(ui.TextBox.new("AB Testing", FONT_MEDIUM, "ffffff", "left", 460, nil, true))
  label:setLoc(0, height / 2 + y)
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  local text = btn:add(ui.TextBox.new("A", FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  text:setLoc(-40, 0)
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(110, height / 2 + y)
  function btn.onClick()
    _AB_test_A()
  end
  local btn = debugBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconStart.png"))
  local text = btn:add(ui.TextBox.new("B", FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  text:setLoc(-40, 0)
  btn._down:setColor(0.5, 0.5, 0.5)
  btn:setLoc(210, height / 2 + y)
  function btn.onClick()
    _AB_test_B()
  end
  y = y + yOffset
end
function _M.init()
  debugBtn = debugLayer:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategoryAll.png"))
  debugBtn._down:setColor(0.5, 0.5, 0.5)
  debugBtn:setScl(0.5, 0.5)
  debugBtn:setLoc(-device.ui_width / 2 + 24, device.ui_height / 2 - 24)
  function debugBtn.onClick()
    _debug_show()
  end
end
return _M
