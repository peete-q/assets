require("constants")
local device = require("device")
local util = require("util")
local ui = require("ui")
local actionset = require("actionset")
local resource = require("resource")
local memory = require("memory")
local timerutil = require("timerutil")
local appcache = require("appcache")
local keys = require("keys")
local bucket = resource.bucket
local update = require("update")
local environment = require("environment")
local qlog = require("qlog")
local fb = require("fb")
local randutil = require("randutil")
randutil.randomseed()
fb.init()
if os.getenv("NO_SOUND") then
  MOAIUntzSystem = nil
end
local gettext = require("gettext.gettext")
if os.getenv("I18N_TEST") then
  gettext.setlang("*")
else
  gettext.setlang(PREFERRED_LANGUAGES, "mo/?.mo")
end
local cloud = require("cloud")
cloud.init(MOAI_CLOUD_CLIENT_KEY, MOAI_CLOUD_CLIENT_SECRET)
MOAISim.openWindow(_("SBC"), device.width, device.height)
ui.init()
camera = MOAITransform.new()
camera:setLoc(0, 0)
camera:setScl(WORLD_SCL, WORLD_SCL)
offscreen = MOAITransform.new()
offscreen:setLoc(OFFSCREEN_LOC, OFFSCREEN_LOC)
stageHeight = device.ui_height
stageWidth = device.ui_width
qlog.logger().debug(string.format("Stage: %d x %d", stageWidth, stageHeight))
levelWidth = DEFAULT_LEVEL_SIZE
levelHeight = levelWidth
stage = MOAIProp2D.new()
viewport = MOAIViewport.new()
viewport:setScale(stageWidth, stageHeight)
viewport:setSize(0, 0, device.width, device.height)
bgLayer1 = ui.Layer.new(viewport)
bgLayer1:setCamera(camera)
bgLayer1:setParallax(BG1_PARALLAX, BG1_PARALLAX)
bgLayer1._uiname = "bg1"
junkLayer = ui.Layer.new(viewport)
junkLayer:setCamera(camera)
junkLayer:setParallax(JUNK_PARALLAX, JUNK_PARALLAX)
junkLayer._uiname = "junk"
mothershipLayer = ui.Layer.new(viewport)
mothershipLayer:setCamera(camera)
mothershipLayer._uiname = "mothership"
bgLayer2 = ui.Layer.new(viewport)
bgLayer2:setCamera(camera)
bgLayer2:setParallax(BG2_PARALLAX, BG2_PARALLAX)
bgLayer2._uiname = "bg2"
mainLayer = ui.Layer.new(viewport)
mainLayer:setCamera(camera)
mainLayer._uiname = "main"
hudLayer = ui.Layer.new(viewport)
hudLayer:setCamera(camera)
hudLayer._uiname = "hud"
uiLayer = ui.Layer.new(nil, true)
uiLayer._uiname = "ui"
galaxymapLayer1 = ui.Layer.new(nil, true)
galaxymapLayer1._uiname = "galaxymap1"
galaxymapLayer2 = ui.Layer.new(nil, true)
galaxymapLayer2._uiname = "galaxymap2"
submenuLayer = ui.Layer.new(nil, true)
submenuLayer._uiname = "submenu"
warpmenuLayer = ui.Layer.new({
  left = device.width / 2 - 298 / device.ui_scale,
  top = device.height / 2 + -186 / device.ui_scale,
  right = device.width / 2 + 300 / device.ui_scale,
  bottom = device.height / 2 + 363 / device.ui_scale
}, true)
warpmenuLayer._uiname = "warpmenu"
menuLayer = ui.Layer.new(nil, true)
menuLayer._uiname = "menu"
creditsLayer = ui.Layer.new({
  left = device.width / 2 - 297 / device.ui_scale,
  top = device.height / 2 + (-(device.height / 2 - (device.height - 110) / 2) - 413 + 324) / device.ui_scale,
  right = device.width / 2 + 299 / device.ui_scale,
  bottom = device.height / 2 + (-(device.height / 2 - (device.height - 110) / 2) - 413 + 326 + 500) / device.ui_scale
}, true)
creditsLayer._uiname = "credits"
popupsLayer = ui.Layer.new(nil, true)
popupsLayer._uiname = "popups"
debugLayer = ui.Layer.new(nil, true)
debugLayer._uiname = "debug"
score = 0
active_perks = {}
environmentAS = actionset.new()
levelAS = actionset.new()
uiAS = actionset.new()
androidAS = actionset.new()
if device.os == device.OS_ANDROID then
  android_back_button_queue = {}
  android_pause_queue = {}
end
activePathCapturer = nil
update.init()
local math2d = require("math2d")
if DISPLAY_DEBUG_INFO then
  bucket.push("DEBUG")
  do
    local memText = debugLayer:add(ui.TextBox.new("0", FONT_SMALL, "ff0000", "right", device.ui_width - 20, 40))
    memText:setLoc(-200, -device.ui_height / 2 + 10)
    local fpsText = debugLayer:add(ui.TextBox.new("0", FONT_SMALL, "ff0000", "right", device.ui_width - 20, 40))
    fpsText:setLoc(-200, -device.ui_height / 2 + 30)
    timerutil.repeatcall(1, function()
      local mem = memory.usage()
      local colorstr
      if mem > 50 then
        colorstr = "<c:ff0000>"
      elseif mem > 35 then
        colorstr = "<c:ffff00>"
      else
        colorstr = ""
      end
      memText:setString(string.format("%s %s%.1fM", update.debugStatus(), colorstr, mem))
      local fps = math.floor(MOAISim:getPerformance())
      if fps < 28 then
        colorstr = "<c:ff0000>"
      elseif fps < 55 then
        colorstr = "<c:ffff00>"
      else
        colorstr = ""
      end
      local ocount = level_count_objects_of_type(nil)
      local dcount
      if MOAISim.getPerformanceDrawCount then
        dcount = MOAISim.getPerformanceDrawCount()
      end
      fpsText:setString("(" .. VERSION .. ") " .. colorstr .. tostring(fps))
    end)
    bucket.pop()
  end
end
require("ShipData-Variables")
GALAXY_DATA = require("ShipData-GalaxyLevels")
require("profile")
profile_init()
local soundmanager = require("soundmanager")
local SoundInstance = require("SoundInstance")
soundmanager:init()
ambient = SoundInstance.new("game_ambientloop_01", false, true)
if ambient then
  levelAS:delaycall(2, function()
    ambient:loop()
  end)
end
local achievements = require("achievements")
achievements.init()
require("level")
ui.setDefaultTouchCallback(level_default_touch)
ui.setTouchFilter(level_touch_filter)
require("environment")
require("menu")
local storeiap = require("storeiap")
storeiap.init()
local session_start_string = string.format("Session Start: Version - %s, Platform - %s", VERSION, device.platform)
profile_currency_txn(ALLOY_NAME, 0, session_start_string, false)
environment_load(1, 1)
mainmenu_show()
if DISPLAY_DEBUG_INFO then
  local debug_vars = require("debug_vars")
  debug_vars.init()
end
