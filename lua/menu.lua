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
local fb = require("fb")
local _debug, _warn, _error = require("qlog").loggers("menu")
local math = math
local random = math.random
local deg = math.deg
local atan2 = math.atan2
local normalize = math2d.normalize
local distance = math2d.distance
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
local _mainmenu_root, _menu_root, _victory_root, _defeat_root, _achievements_root, _galaxymap_root, _fleet_root, _shippurchase_root, _shipupgrade_root, _shipinfo_root, _starbank_root, _perks_root, _pause_root, _warpmenu_root, _warp_fleet_root, _leaderboard_root, curScreen
local screenHistory = {}
local screenAction = MOAITimer.new()
local menuMode, curGameMode, scrollAction, scrolling, startX, startY, lastX, lastY, diffX, diffY, scrollbar
local scrollbar_fadeInActions = {}
local scrollbar_fadeOutActions = {}
local buttonAction
endGameStats = {}
local levelGalaxyIndex, levelSystemIndex
local perks_inuse = {}
local showShopPopup, showPerkPopup, shipInfoDef
local function Button_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  if eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    ui.capture(nil)
    self._isdown = nil
  elseif eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    self:showPage("down")
    self._isdown = true
    ui.capture(self)
    soundmanager.onClick()
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE then
    if self._isdown and ui.treeCheck(x, y, self) then
      self:showPage("down")
    else
      self:showPage("up")
      self._isdown = nil
    end
  end
  return true
end
local function _foreach_def_of_type(_type, fn, ...)
  local tt = type(_type)
  if tt == "table" then
    for i, v in pairs(entitydef) do
      if _type[v.type] then
        local bail, value = fn(v, ...)
        if bail then
          return true, value
        end
      end
    end
  elseif tt == "function" then
    for i, v in pairs(entitydef) do
      if _type(v.type) then
        local bail, value = fn(v, ...)
        if bail then
          return true, value
        end
      end
    end
  elseif tt == "string" then
    for i, v in pairs(entitydef) do
      if v.type == _type then
        local bail, value = fn(v, ...)
        if bail then
          return true, value
        end
      end
    end
  elseif tt == "nil" then
    for i, v in pairs(entitydef) do
      local bail, value = fn(v, ...)
      if bail then
        return true, value
      end
    end
  else
    assert(false, "Invalid type discriminator: " .. tostring(tt))
  end
  return nil
end
local function _textbox_countup_number(actionset, textbox, start, goal, length, prefix, suffix, sound)
  prefix = prefix or ""
  suffix = suffix or ""
  local runtime = 0
  local num, prevNum, action
  action = actionset:run(function(dt)
    if runtime < length then
      runtime = runtime + dt
      if runtime > length then
        runtime = length
      end
      num = interpolate.lerp(start, goal, runtime / length)
      textbox:setString(prefix .. util.commasInNumbers(floor(num)) .. suffix)
      if prevNum ~= nil and floor(prevNum) ~= floor(num) then
        if sound and sound ~= false then
          soundmanager.onSFX(sound)
        elseif sound == nil then
          soundmanager.onSFX("onPointCount")
        end
      end
      prevNum = num
    else
      action:stop()
    end
  end)
end
local function _fillbar_seek_fill(actionset, fillbar, startValLeft, startValRight, endValLeft, endValRight, length, sound)
  local runtime = 0
  local leftNum, prevLeftNum, rightNum, prevRightNum, action
  action = actionset:run(function(dt)
    if runtime < length then
      runtime = runtime + dt
      if runtime > length then
        runtime = length
      end
      leftNum = interpolate.lerp(startValLeft, endValLeft, runtime / length)
      rightNum = interpolate.lerp(startValRight, endValRight, runtime / length)
      fillbar:setFill(leftNum, rightNum)
      if prevLeftNum ~= nil and floor(prevLeftNum * 100) ~= floor(leftNum * 100) or prevRightNum ~= nil and floor(prevRightNum * 100) ~= floor(rightNum * 100) then
        if sound and sound ~= false then
          soundmanager.onSFX(sound)
        elseif sound == nil then
          soundmanager.onSFX("onPointCount")
        end
      end
      prevLeftNum = leftNum
      prevRightNum = rightNum
    else
      action:stop()
    end
  end)
end
local function _get_last_completed_galaxy_system()
  local lastCompletedGalaxy = 0
  local lastCompletedSystem = 0
  local stop
  for i, galaxy in ipairs(profile.levels) do
    lastCompletedGalaxy = lastCompletedGalaxy + 1
    lastCompletedSystem = 0
    for j, system in ipairs(galaxy) do
      if system.stars ~= nil then
        lastCompletedSystem = lastCompletedSystem + 1
      else
        stop = true
        break
      end
    end
    if stop then
      break
    end
  end
  local lastCompletedIndex = (lastCompletedGalaxy - 1) * 40 + lastCompletedSystem
  if lastCompletedGalaxy > 1 then
    lastCompletedGalaxy = lastCompletedGalaxy - 1
    lastCompletedSystem = 40
    lastCompletedIndex = 40
  end
  return lastCompletedGalaxy, lastCompletedSystem, lastCompletedIndex
end
local _getFighterFrame = function(storeTag)
  if storeTag then
    if storeTag.interceptor then
      return "storeSelectorInterceptor"
    elseif storeTag.bomber then
      return "storeSelectorBomber"
    end
  end
  return "storeSelectorFighter"
end
local function forceStringBreak(words, font, max_width, max_height)
  local str
  for word in words:gmatch("%S+") do
    local tb = ui.TextBox.new(word, font, "ffffff", "center", max_width, max_height)
    local idx = word:len()
    local xMin, yMin, xMax, yMax = tb:getStringBounds(1, idx)
    local width = xMax - xMin
    if max_width < width then
      while max_width < width do
        idx = idx - 1
        xMin, yMin, xMax, yMax = tb:getStringBounds(1, idx)
        width = xMax - xMin
      end
      word = util.string_insert(word, " ", idx)
      word = forceStringBreak(word, font, max_width, max_height)
    end
    str = (str or "") .. word .. " "
  end
  return str
end
local startTouchX, startTouchY, curTouchX, curTouchY, lastTouchX, lastTouchY, dragStartWX, dragStartWY, camStartWX, camStartWY
local _clampToLevelBounds = function(x, y, margin)
  margin = margin or levelWidth / 2
  if x < -levelWidth + margin then
    x = -levelWidth + margin
  elseif x > levelWidth - margin then
    x = levelWidth - margin
  end
  if y < -levelHeight + margin then
    y = -levelHeight + margin
  elseif y > levelHeight - margin then
    y = levelHeight - margin
  end
  return x, y
end
local function _warpmenu_selectmodule_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  local TOUCH_ONE = ui.TOUCH_ONE
  if touchIdx ~= TOUCH_ONE then
    return
  end
  x, y = self._uilayer:worldToWnd(x, y)
  local wx, wy = camera:modelToWorld(uiLayer:wndToWorld(x, y))
  if eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    ui.capture(self)
    startTouchX = x
    startTouchY = y
    curTouchX, curTouchY = x, y
    camStartWX, camStartWY = camera:getLoc()
    return true
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE then
    if startTouchX ~= nil and startTouchY ~= nil then
      for i, v in ipairs(_warpmenu_root.modules) do
        local x, y = mothershipLayer:worldToWnd(v.x, v.y)
        x, y = _warpmenu_root._uilayer:wndToWorld(x, y)
        v:setLoc(x, y)
      end
      lastTouchX, lastTouchY = curTouchX, curTouchY
      curTouchX, curTouchY = x, y
      if dragStartWX == nil then
      elseif distance(x, y, startTouchX or x, startTouchY or y) >= ui.DRAG_THRESHOLD * 2 then
        dragStartWX, dragStartWY = camera:modelToWorld(uiLayer:wndToWorld(startTouchX, startTouchY))
        camera:setLoc(_clampToLevelBounds(dragStartWX - wx + camStartWX, dragStartWY - wy + camStartWY))
        return true
      end
    end
  elseif eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    ui.capture(nil)
    startTouchX = nil
    startTouchY = nil
    if dragStartWX == nil then
    else
      lastTouchX, lastTouchY = camera:modelToWorld(uiLayer:wndToWorld(lastTouchX, lastTouchY))
      local mag = distance(wx, wy, lastTouchX, lastTouchY) * 4
      local dirX, dirY = normalize(lastTouchX - wx, lastTouchY - wy)
      dirX = dirX * mag
      dirY = dirY * mag
      local camCurX, camCurY = camera:getLoc()
      if mag > 100 then
        local nx, ny = _clampToLevelBounds(camCurX + dirX, camCurY + dirY)
        camera:seekLoc(nx, ny, 1.5, MOAIEaseType.SHARP_EASE_IN)
        local diffX = camCurX + dirX - nx
        local diffY = camCurY + dirY - ny
        for i, v in ipairs(_warpmenu_root.modules) do
          local x, y = mothershipLayer:worldToWnd(v.x - dirX + diffX, v.y - dirY + diffY)
          x, y = _warpmenu_root._uilayer:wndToWorld(x, y)
          v:seekLoc(x, y, 1.5, MOAIEaseType.SHARP_EASE_IN)
        end
      end
      dragStartWX = nil
      dragStartWY = nil
      curTouchX = nil
      curTouchY = nil
      lastTouchX = nil
      lastTouchY = nil
    end
    return true
  end
end
local function _warpmenu_module_select(module)
  if module then
    if module.def.type == "capitalship" then
      local o = level_spawn_object("spawning_module", mothershipLayer)
      local x, y = module:getWorldLoc()
      o:setLoc(x, y)
      module:destroy()
      module = o
      achievements.checklist_check("warp_capship")
    end
    local def = _warpmenu_root.shipdef
    module.warpType = def._id
    module.def = def
    local cost = def.buildCost
    if cost ~= nil then
      local costStr = {}
      for rt, amount in pairs(cost) do
        scores[rt] = (scores[rt] or 0) - amount
        table_insert(costStr, tostring(-amount))
        if rt == "blue" then
          set_if_nil(gameSessionAnalytics, "currency", {})
          set_if_nil(gameSessionAnalytics.currency, "crystals", {})
          gameSessionAnalytics.currency.crystals.spent = (gameSessionAnalytics.currency.crystals.spent or 0) + amount
        end
      end
      local wx, wy = module:getWorldLoc()
      level_fx_floatie(wx, wy + MODULE_WORLD_SIZE * 0.25, table_concat(costStr, ", "))
      module:addInventoryCount(1)
    end
    local count = 0
    for i, v in ipairs(_warpmenu_root.modules) do
      if v.module.def.type == "capitalship" then
        count = count + 1
      end
    end
    if count == #_warpmenu_root.modules then
      achievements.checklist_check("warp_all")
      local maxed = true
      for i, v in ipairs(_warpmenu_root.modules) do
        local baseID = v.module.def._baseID
        local storeMaxUpgrade = 0
        for j, w in pairs(entitydef) do
          if w._baseID == baseID then
            storeMaxUpgrade = storeMaxUpgrade + 1
          end
        end
        if v.module.def._upgradeNum < storeMaxUpgrade - 1 then
          maxed = false
          break
        end
      end
      if maxed then
        achievements.checklist_check("warp_all_max")
      end
    end
    set_if_nil(gameSessionAnalytics, "warps", {})
    gameSessionAnalytics.warps[_warpmenu_root.shipdef._id] = (gameSessionAnalytics.warps[_warpmenu_root.shipdef._id] or 0) + 1
  end
  module = nil
  levelAS:resume()
  environmentAS:resume()
  warpmenu_close()
end
local function _warpmenu_create_module(self, root)
  if self == commandShip then
    return
  end
  local icon
  if self.def.type == "capitalship" then
    icon = "hud.atlas.png#warpSelectorSwap.png"
  else
    icon = "hud.atlas.png#warpSelector.png"
  end
  local warpSelector = root:add(ui.Button.new(icon))
  warpSelector._down:setScl(1.2, 1.2)
  warpSelector:setLoc(self:getLoc())
  warpSelector.x, warpSelector.y = self:getLoc()
  warpSelector.module = self
  warpSelector.handleTouch = Button_handleTouch
  function warpSelector.onClick()
    _warpmenu_module_select(self)
  end
  table_insert(root.modules, warpSelector)
end
local _warpmenu_selectmodule_close, _warpmenu_selectmodule_show, _warpmenu_selectship_close, _warpmenu_selectship_show
function _warpmenu_selectmodule_close()
  for i, v in ipairs(_warpmenu_root.modules) do
    v:remove()
  end
  _warpmenu_root.modules = nil
  _warpmenu_root.headerBox:remove()
  _warpmenu_root.headerBox = nil
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
end
function _warpmenu_selectmodule_show(def)
  _warpmenu_root.modules = {}
  camera:seekLoc(0, 0, 0.75, MOAIEaseType.SHARP_EASE_IN)
  local pickbox = _warpmenu_root:add(ui.PickBox.new(device.ui_width, device.ui_height))
  pickbox.handleTouch = _warpmenu_selectmodule_handleTouch
  level_foreach_object_of_type({warp_module = true, capitalship = true}, _warpmenu_create_module, _warpmenu_root)
  local uiBarHeight
  if gameMode == "galaxy" then
    uiBarHeight = UI_BAR_HEIGHT
  elseif gameMode == "survival" then
    uiBarHeight = UI_BAR_HEIGHT_SURVIVAL
  end
  local headerBox = _warpmenu_root:add(ui.NinePatch.new("boxPlain9p.lua", 600, 100))
  headerBox:setLoc(0, device.ui_height / 2 - uiBarHeight + 15 - 50)
  _warpmenu_root.headerBox = headerBox
  local backBtn = headerBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconBack.png"))
  backBtn._down:setColor(0.5, 0.5, 0.5)
  backBtn:setLoc(-250, 0)
  backBtn.handleTouch = Button_handleTouch
  local function backBtn_onClick()
    _warpmenu_selectmodule_close()
    _warpmenu_selectship_show()
  end
  backBtn.onClick = backBtn_onClick
  if device.os == device.OS_ANDROID then
    local function callback()
      backBtn_onClick()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local placeShipText = headerBox:add(ui.TextBox.new(_("Place Ship"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  placeShipText:setLoc(30, 0)
  _warpmenu_root.shipdef = def
end
local function _warpmenu_items_handleTouch(self, eventType, touchIdx, x, y, tapCount, exclude_capture)
  local submenu_height = 550
  local submenu_y = 0
  if eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    if 0 < math.max(self.items_group.numItems * 160 - submenu_height, 0) then
      if not exclude_capture then
        ui.capture(self)
      end
      scrolling = true
      lastX = x
      lastY = y
      diffX = 0
      diffY = 0
      if scrollbar == nil then
        scrollbar = ui.Group.new()
        do
          local scrollbar_fill = scrollbar:add(ui.Image.new("scrollbar_fill.png"))
          scrollbar_fill:setScl(1, 3.5)
          scrollbar.fill = scrollbar_fill
          local scrollbar_top = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_top:setLoc(0, 36)
          scrollbar.top = scrollbar_top
          local scrollbar_bot = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_bot:setLoc(0, -36)
          scrollbar_bot:setScl(1, -1)
          scrollbar.bot = scrollbar_bot
          local groupX, groupY = self.items_group:getLoc()
          local perc = groupY / (self.items_group.numItems * 160 - submenu_height)
          scrollbar:setLoc(287, submenu_height / 2 - 40 - perc * (submenu_height - 80) + submenu_y)
          scrollbar.fill:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.top:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.bot:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          self:add(scrollbar)
        end
      else
        if scrollbar_fadeOutActions.fill ~= nil and scrollbar_fadeOutActions.fill:isActive() then
          scrollbar_fadeOutActions.fill:stop()
          scrollbar_fadeOutActions.top:stop()
          scrollbar_fadeOutActions.bot:stop()
        end
        scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
      end
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
  elseif eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    if not exclude_capture then
      ui.capture(nil)
    end
    scrolling = false
    if scrollbar ~= nil and scrollbar.velocityY ~= nil then
      scrollbar.velocityY = scrollbar.velocityY + diffY
    elseif scrollbar ~= nil then
      scrollbar.velocityY = diffY
    end
    if scrollAction == nil then
      scrollAction = uiAS:wrap(function(dt)
        if scrollbar ~= nil then
          do
            local groupX, groupY = self.items_group:getLoc()
            local newY = util.clamp(groupY - scrollbar.velocityY, 0, math.max(self.items_group.numItems * 160 - submenu_height, 0))
            self.items_group:setLoc(0, util.roundNumber(newY))
            local groupX, groupY = self.items_group:getLoc()
            local perc = groupY / (self.items_group.numItems * 160 - submenu_height)
            scrollbar:setLoc(287, submenu_height / 2 - 40 - perc * (submenu_height - 80) + submenu_y)
            scrollbar.velocityY = scrollbar.velocityY + scrollbar.velocityY * -1 * dt * 0.03 * device.dpi
            if not scrolling and abs(scrollbar.velocityY) < 0.5 then
              scrollAction:stop()
              scrollAction = nil
            end
          end
        else
          scrollAction:stop()
          scrollAction = nil
        end
      end, function()
        if not scrolling and scrollbar ~= nil then
          if scrollbar_fadeInActions.fill ~= nil and scrollbar_fadeInActions.fill:isActive() then
            scrollbar_fadeInActions.fill:stop()
            scrollbar_fadeInActions.top:stop()
            scrollbar_fadeInActions.bot:stop()
          end
          scrollbar_fadeOutActions.fill = scrollbar.fill:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.top = scrollbar.top:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.bot = scrollbar.bot:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.fill:setListener(MOAITimer.EVENT_STOP, function()
            if not scrolling and self ~= nil then
              self:remove(scrollbar)
              scrollbar = nil
            end
          end)
        end
      end)
    end
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE and scrolling then
    diffY = lastY - y
    local groupX, groupY = self.items_group:getLoc()
    local newY = util.clamp(groupY - diffY, 0, math.max(self.items_group.numItems * 160 - submenu_height, 0))
    self.items_group:setLoc(0, util.roundNumber(newY))
    if scrollbar ~= nil then
      local groupX, groupY = self.items_group:getLoc()
      local perc = groupY / (self.items_group.numItems * 160 - submenu_height)
      scrollbar:setLoc(287, submenu_height / 2 - 40 - perc * (submenu_height - 80) + submenu_y)
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
    lastX = x
    lastY = y
  end
  return true
end
local function _warpmenu_item_button_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  if eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    ui.capture(nil)
  elseif eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    self._isdown = true
    ui.capture(self)
    startX, startY = self:modelToWorld(x, y)
    do
      local action
      action = uiAS:run(function(dt, t)
        if buttonAction == nil then
          if action ~= nil then
            action:stop()
          end
          action = nil
        end
        buttonAction.t = t
        if self._isdown and self.currentPageName == "up" and t > 0.2 then
          self:showPage("down")
        elseif t > 1 then
          self:showPage("up")
          self._isdown = nil
          buttonAction:stop()
          buttonAction = nil
        end
      end)
      buttonAction = action
      buttonAction.t = 0
    end
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE then
    if self._isdown and not ui.treeCheck(x, y, self) then
      self:showPage("up")
      self._isdown = nil
      if buttonAction ~= nil then
        buttonAction:stop()
        buttonAction = nil
      end
    end
    local wx, wy = self:modelToWorld(x, y)
    if self._isdown and abs(startY - wy) > 25 then
      self:showPage("up")
      self._isdown = nil
      if buttonAction ~= nil then
        buttonAction:stop()
        buttonAction = nil
      end
    end
  end
  if _warpmenu_root.warpmenuBG ~= nil then
    local wx, wy = self:modelToWorld(x, y)
    local mx, my = _warpmenu_root.warpmenuBG:worldToModel(wx, wy)
    _warpmenu_items_handleTouch(_warpmenu_root.warpmenuBG, eventType, touchIdx, mx, my, tapCount, true)
  end
  return true
end
local function _warpmenu_create_item(def, items)
  local upgradeNum = def._upgradeNum
  if upgradeNum ~= 0 then
    return false
  end
  if not def.storeTexture then
    return false
  end
  local baseID = def._baseID
  if profile.unlocks[baseID] == nil or not profile.unlocks[baseID].unlocked then
    return false
  end
  local filter = _warpmenu_root.filter
  local curDef = entitydef[baseID .. "_" .. profile.unlocks[baseID].currentUpgrade]
  if def.excludeWarpMenu then
    return false
  elseif filter ~= "all" then
    if not def.storeTags then
      return false
    end
    if filter == "fighters" then
      if not curDef.storeTags.fighter then
        return false
      end
    elseif filter == "interceptors" then
      if not curDef.storeTags.interceptor then
        return false
      end
    elseif filter == "bombers" then
      if not curDef.storeTags.bomber then
        return false
      end
    elseif filter == "defense" then
      if not curDef.storeTags.harvester then
        return false
      end
    elseif filter == "special" and not curDef.storeTags.cannon then
      return false
    end
  end
  local item = ui.Group.new()
  _warpmenu_root.warpmenuBG.items_group:add(item)
  local itemBG = item:add(ui.Button.new(ui.PickBox.new(592, 160, color.toHex(0.067059, 0.067059, 0.067059, 0.3)), ui.PickBox.new(592, 160, color.toHex(0.0335295, 0.0335295, 0.0335295, 0.3))))
  itemBG._up.handleTouch = nil
  itemBG._down.handleTouch = nil
  itemBG.handleTouch = _warpmenu_item_button_handleTouch
  function itemBG.onClick()
    soundmanager.onClick()
    _warpmenu_selectship_close()
    _warpmenu_selectmodule_show(curDef)
  end
  local ship = item:add(ui.Image.new(def.storeTexture[1]))
  ship:setLoc(-180, 15)
  ship:setScl(0.6, 0.6)
  ship:setRot(-90)
  local nameText = item:add(ui.TextBox.new(_(def.storeName .. " " .. def.storeClass), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  nameText:setColor(unpack(UI_COLOR_GRAY))
  nameText:setLoc(0, -55)
  local icon
  if baseID == "SPC" then
    icon = item:add(ui.Image.new("storeScreen.atlas.png#storeSelectorSPC.png"))
  else
    local subentityStr, queryStr = breakstr(def.subentities[1], "?")
    local subentity = entitydef[subentityStr]
    if subentity.type:find("cannon") then
      icon = item:add(ui.Image.new("storeScreen.atlas.png#gunshipTurretBasic.png"))
      icon:setColor(unpack(UI_SHIP_COLOR_SPECIAL))
    elseif subentity.type == "module" then
      local hangarentity = entitydef[subentity.hangarInventoryType]
      if hangarentity.type == "fighter" then
        icon = item:add(ui.Image.new(string.format("storeScreen.atlas.png#%s.png", _getFighterFrame(curDef.storeTags))))
        do
          local r, g, b = color.parse(subentity.pathColor)
          icon:setColor(r, g, b)
          local hangarship = icon:add(ui.Image.new(hangarentity.storeTexture))
          hangarship:clearAttrLink(MOAIColor.INHERIT_COLOR)
          hangarship:setRot(-90)
          icon.hangarship = hangarship
        end
      elseif hangarentity.type == "harvester" then
        icon = item:add(ui.Image.new("storeScreen.atlas.png#storeSelectorMiner.png"))
        local r, g, b = color.parse(subentity.pathColor)
        icon:setColor(r, g, b)
        local hangarship = icon:add(ui.Image.new(hangarentity.storeTexture))
        hangarship:clearAttrLink(MOAIColor.INHERIT_COLOR)
        hangarship:setRot(-90)
        icon.hangarship = hangarship
      end
    end
  end
  icon:setScl(0.6, 0.6)
  icon:setLoc(60, 15)
  local priceBox = item:add(ui.NinePatch.new("boxPlain9p.lua", 155, 90))
  priceBox:setLoc(200, 15)
  local iconCrystal = priceBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystal.png"))
  iconCrystal:setLoc(-35, 0)
  local priceText = priceBox:add(ui.TextBox.new("" .. curDef.buildCost.blue, FONT_MEDIUM, "ffffff", "center", nil, nil, true))
  priceText:setLoc(25, 0)
  local topBorder = item:add(ui.Image.new("menuTemplate.atlas.png#shipListItemTop.png"))
  topBorder:setScl(74, 1)
  topBorder:setLoc(0, 78)
  local bottomBorder = item:add(ui.Image.new("menuTemplate.atlas.png#shipListItemBottom.png"))
  bottomBorder:setScl(74, 1)
  bottomBorder:setLoc(0, -78)
  if curDef.buildCost.blue > scores.blue then
    itemBG.handleTouch = nil
    ship:setColor(0.5, 0.5, 0.5, 0.5)
    if baseID == "SPC" then
      icon:setColor(0.5, 0.5, 0.5, 0.5)
    else
      local subentityStr, queryStr = breakstr(def.subentities[1], "?")
      local subentity = entitydef[subentityStr]
      if subentity.type:find("cannon") then
        icon:setColor(0.5, 0.25, 0.07, 0.5)
      elseif subentity.type == "module" then
        local hangarentity = entitydef[subentity.hangarInventoryType]
        if hangarentity.type == "fighter" then
          do
            local r, g, b = color.parse(subentity.pathColor)
            icon:setColor(r / 2, g / 2, b / 2, 0.5)
            icon.hangarship:setColor(0.5, 0.5, 0.5, 0.5)
          end
        elseif hangarentity.type == "harvester" then
          local r, g, b = color.parse(subentity.pathColor)
          icon:setColor(r / 2, g / 2, b / 2, 0.5)
          icon.hangarship:setColor(0.5, 0.5, 0.5, 0.5)
        end
      end
    end
    iconCrystal:setColor(unpack(UI_COLOR_RED))
    priceText:setColor(unpack(UI_COLOR_RED))
  end
  item.def = curDef
  table_insert(items, item)
  return false
end
local function _warpmenu_items_compare(a, b)
  local aBaseID = a.def._baseID
  local bBaseID = b.def._baseID
  local aCurDef = entitydef[aBaseID .. "_" .. profile.unlocks[aBaseID].currentUpgrade]
  local bCurDef = entitydef[bBaseID .. "_" .. profile.unlocks[bBaseID].currentUpgrade]
  if aCurDef.buildCost.blue == bCurDef.buildCost.blue then
    return aCurDef.storeUnlockLevel < bCurDef.storeUnlockLevel
  else
    return aCurDef.buildCost.blue < bCurDef.buildCost.blue
  end
end
local function _warpmenu_refresh_filter(filter)
  local allBtn = _warpmenu_root.allBtn
  local fightersBtn = _warpmenu_root.fightersBtn
  local interceptorsBtn = _warpmenu_root.interceptorsBtn
  local bombersBtn = _warpmenu_root.bombersBtn
  local defenseBtn = _warpmenu_root.defenseBtn
  local specialBtn = _warpmenu_root.specialBtn
  local frame = _warpmenu_root.frame
  local filterTitleText = _warpmenu_root.filterTitleText
  _warpmenu_root.filter = filter
  allBtn._up:setColor(unpack(UI_SHIP_COLOR_ALL_DARKEN))
  allBtn._down:setColor(unpack(UI_SHIP_COLOR_ALL))
  allBtn.handleTouch = Button_handleTouch
  fightersBtn._up:setColor(unpack(UI_SHIP_COLOR_FIGHTERS_DARKEN))
  fightersBtn._down:setColor(unpack(UI_SHIP_COLOR_FIGHTERS))
  fightersBtn.handleTouch = Button_handleTouch
  interceptorsBtn._up:setColor(unpack(UI_SHIP_COLOR_INTERCEPTORS_DARKEN))
  interceptorsBtn._down:setColor(unpack(UI_SHIP_COLOR_INTERCEPTORS))
  interceptorsBtn.handleTouch = Button_handleTouch
  bombersBtn._up:setColor(unpack(UI_SHIP_COLOR_BOMBERS_DARKEN))
  bombersBtn._down:setColor(unpack(UI_SHIP_COLOR_BOMBERS))
  bombersBtn.handleTouch = Button_handleTouch
  defenseBtn._up:setColor(unpack(UI_SHIP_COLOR_DEFENSE_DARKEN))
  defenseBtn._down:setColor(unpack(UI_SHIP_COLOR_DEFENSE))
  defenseBtn.handleTouch = Button_handleTouch
  specialBtn._up:setColor(unpack(UI_SHIP_COLOR_SPECIAL_DARKEN))
  specialBtn._down:setColor(unpack(UI_SHIP_COLOR_SPECIAL))
  specialBtn.handleTouch = Button_handleTouch
  if filter == "all" then
    frame:setLoc(allBtn:getLoc())
    frame:setColor(unpack(UI_SHIP_COLOR_ALL))
    allBtn._up:setColor(unpack(UI_SHIP_COLOR_ALL))
    allBtn.handleTouch = nil
    filterTitleText:setString(_("All Available Ships"))
  elseif filter == "fighters" then
    frame:setLoc(fightersBtn:getLoc())
    frame:setColor(unpack(UI_SHIP_COLOR_FIGHTERS))
    fightersBtn._up:setColor(unpack(UI_SHIP_COLOR_FIGHTERS))
    fightersBtn.handleTouch = nil
    filterTitleText:setString(_("Fighters"))
  elseif filter == "interceptors" then
    frame:setLoc(interceptorsBtn:getLoc())
    frame:setColor(unpack(UI_SHIP_COLOR_INTERCEPTORS))
    interceptorsBtn._up:setColor(unpack(UI_SHIP_COLOR_INTERCEPTORS))
    interceptorsBtn.handleTouch = nil
    filterTitleText:setString(_("Interceptors"))
  elseif filter == "bombers" then
    frame:setLoc(bombersBtn:getLoc())
    frame:setColor(unpack(UI_SHIP_COLOR_BOMBERS))
    bombersBtn._up:setColor(unpack(UI_SHIP_COLOR_BOMBERS))
    bombersBtn.handleTouch = nil
    filterTitleText:setString(_("Bombers"))
  elseif filter == "defense" then
    frame:setLoc(defenseBtn:getLoc())
    frame:setColor(unpack(UI_SHIP_COLOR_DEFENSE))
    defenseBtn._up:setColor(unpack(UI_SHIP_COLOR_DEFENSE))
    defenseBtn.handleTouch = nil
    filterTitleText:setString(_("Miners"))
  elseif filter == "special" then
    frame:setLoc(specialBtn:getLoc())
    frame:setColor(unpack(UI_SHIP_COLOR_SPECIAL))
    specialBtn._up:setColor(unpack(UI_SHIP_COLOR_SPECIAL))
    specialBtn.handleTouch = nil
    filterTitleText:setString(_("Special Weapons"))
  end
  if _warpmenu_root.warpmenuBG.items_group ~= nil then
    _warpmenu_root.warpmenuBG.items_group:remove()
    _warpmenu_root.warpmenuBG.items_group = nil
  end
  local items_group = warpmenuLayer:add(ui.Group.new())
  _warpmenu_root.warpmenuBG.items_group = items_group
  local items = {}
  local bail, item = _foreach_def_of_type("capitalship", _warpmenu_create_item, items)
  table_sort(items, _warpmenu_items_compare)
  local y = 196
  for i, v in ipairs(items) do
    v:setLoc(0, y)
    y = y - 160
  end
  items_group.numItems = #items
  _warpmenu_root.items = items
end
function _warpmenu_selectship_close()
  _warpmenu_root.warpmenuBox:remove()
  _warpmenu_root.warpmenuBox = nil
  _warpmenu_root.warpmenuBG.items_group:remove()
  _warpmenu_root.warpmenuBG.items_group = nil
  _warpmenu_root.warpmenuBG:remove()
  _warpmenu_root.warpmenuBG = nil
  _warpmenu_root.subrootBox:remove()
  _warpmenu_root.subrootBox = nil
end
function _warpmenu_selectship_show()
  local warpmenuBox = _warpmenu_root:add(ui.NinePatch.new("boxWarpMenu9p.lua", 600, 770))
  _warpmenu_root.warpmenuBox = warpmenuBox
  local warpmenuBG = warpmenuLayer:add(ui.PickBox.new(600, 550))
  warpmenuBG.handleTouch = _warpmenu_items_handleTouch
  _warpmenu_root.warpmenuBG = warpmenuBG
  local subrootBox = _warpmenu_root.subroot:add(ui.Group.new())
  _warpmenu_root.subrootBox = subrootBox
  local fallbackPickBoxTop = subrootBox:add(ui.PickBox.new(600, device.ui_height - 550))
  fallbackPickBoxTop:setLoc(0, (device.ui_height - 550) / 2 + 270 - 85)
  function fallbackPickBoxTop.handleTouch()
    return true
  end
  local fallbackPickBoxBottom = subrootBox:add(ui.PickBox.new(600, device.ui_height - 550))
  fallbackPickBoxBottom:setLoc(0, -(device.ui_height - 550) / 2 - 278 - 85)
  function fallbackPickBoxBottom.handleTouch()
    return true
  end
  local closeBtn = subrootBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconClose.png"))
  closeBtn._down:setColor(0.5, 0.5, 0.5)
  closeBtn:setLoc(-250, 330)
  closeBtn.handleTouch = Button_handleTouch
  function closeBtn.onClick()
    levelAS:resume()
    environmentAS:resume()
    warpmenu_close()
  end
  local filterTitleText = subrootBox:add(ui.TextBox.new("Filter Title", FONT_XLARGE, "ffffff", "center", 500, nil, true))
  filterTitleText:setLoc(0, 325)
  _warpmenu_root.filterTitleText = filterTitleText
  local allBtn = subrootBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategoryAll.png"))
  allBtn:setLoc(-240, 235)
  function allBtn.onClick()
    _warpmenu_refresh_filter("all")
  end
  _warpmenu_root.allBtn = allBtn
  local fightersBtn = subrootBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategoryFighters.png"))
  fightersBtn:setLoc(-145, 235)
  function fightersBtn.onClick()
    _warpmenu_refresh_filter("fighters")
  end
  _warpmenu_root.fightersBtn = fightersBtn
  local interceptorsBtn = subrootBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategoryCounterBombers.png"))
  interceptorsBtn:setLoc(-50, 235)
  function interceptorsBtn.onClick()
    _warpmenu_refresh_filter("interceptors")
  end
  _warpmenu_root.interceptorsBtn = interceptorsBtn
  local bombersBtn = subrootBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategoryBombers.png"))
  bombersBtn:setLoc(50, 235)
  function bombersBtn.onClick()
    _warpmenu_refresh_filter("bombers")
  end
  _warpmenu_root.bombersBtn = bombersBtn
  local defenseBtn = subrootBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategoryDefense.png"))
  defenseBtn:setLoc(145, 235)
  function defenseBtn.onClick()
    _warpmenu_refresh_filter("defense")
  end
  _warpmenu_root.defenseBtn = defenseBtn
  local specialBtn = subrootBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategorySpecial.png"))
  specialBtn:setLoc(240, 235)
  function specialBtn.onClick()
    _warpmenu_refresh_filter("special")
  end
  _warpmenu_root.specialBtn = specialBtn
  local frame = subrootBox:add(ui.Image.new("menuTemplateShared.atlas.png#selectedIconFrame.png"))
  frame:setColor(0, 0, 0, 0)
  _warpmenu_root.frame = frame
  _warpmenu_refresh_filter("all")
  if gameMode == "survival" then
    local fleetBox = subrootBox:add(ui.NinePatch.new("boxPlain9p.lua", 600, 70))
    fleetBox:setLoc(-1, -425)
    local fleetBtn = fleetBox:add(ui.Button.new("menuTemplateShared.atlas.png#warpMenuStoreButton.png"))
    fleetBtn._up:setColor(unpack(UI_COLOR_YELLOW))
    fleetBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
    local fleetText = fleetBtn._up:add(ui.TextBox.new(_("Buy & Upgrade Ships"), FONT_MEDIUM_BOLD, "000000", "center"))
    fleetText:setColor(0, 0, 0)
    fleetText:setLoc(0, -2)
    local fleetText = fleetBtn._down:add(ui.TextBox.new(_("Buy & Upgrade Ships"), FONT_MEDIUM_BOLD, "000000", "center"))
    fleetText:setColor(0, 0, 0)
    fleetText:setLoc(0, -2)
    fleetBtn.handleTouch = Button_handleTouch
    function fleetBtn.onClick()
      if lootPickupTimer[ALLOY_NAME] ~= nil then
        profile_currency_txn(ALLOY_NAME, lootPickupTimer[ALLOY_NAME].resValue, "Salvage", true)
        lootPickupTimer[ALLOY_NAME] = nil
      end
      if lootPickupTimer[CREDS_NAME] ~= nil then
        profile_currency_txn(CREDS_NAME, lootPickupTimer[CREDS_NAME].resValue, "Salvage", true)
        lootPickupTimer[CREDS_NAME] = nil
      end
      warpmenu_close()
      if levelUI then
        levelUI.inStoreMenu = true
      end
      menu_show("fleet?mode=ingame", function()
        levelAS:resume()
        environmentAS:resume()
        if levelUI then
          levelUI.inStoreMenu = false
        end
        level_foreach_object_of_type("capitalship", function(self)
          local baseID = self.def._baseID
          local upgradeNum = self.def._upgradeNum
          local currentUpgrade = profile.unlocks[baseID].currentUpgrade
          if upgradeNum < currentUpgrade then
            levelAS:delaycall(0.1, function()
              local module = level_spawn_object("spawning_module", mothershipLayer)
              local x, y = self:getWorldLoc()
              local dam = 1 - self.hp / self.maxHp
              local newCommandShip
              if commandShip == self then
                newCommandShip = true
              end
              module:setLoc(x, y)
              if module then
                module.warpType = baseID .. "_" .. currentUpgrade
                module.warpDamage = dam
                module.warpCommandShip = newCommandShip
                module:addInventoryCount(1)
                levelAS:delaycall(0.3, function()
                  self:destroy()
                  level_update_max_dc()
                end)
              end
            end)
          end
        end)
      end)
    end
  end
end
function warpmenu_close()
  if levelUI then
    levelUI.inStoreMenu = false
  end
  uiLayer:remove(_warpmenu_root.bg)
  _warpmenu_root.bg = nil
  warpmenuLayer:clear()
  menuLayer:remove(_warpmenu_root.subroot)
  _warpmenu_root.subroot = nil
  submenuLayer:remove(_warpmenu_root)
  _warpmenu_root = nil
  levelui_unhide_hud_buttons()
end
function warpmenu_show()
  levelui_hide_hud_buttons()
  if levelUI then
    levelUI.inStoreMenu = true
  end
  _warpmenu_root = ui.Group.new()
  _warpmenu_root.subroot = ui.Group.new()
  local bg = uiLayer:add(ui.PickBox.new(device.ui_width, device.ui_height, color.toHex(0.15, 0.15, 0.15, 0.5)))
  function bg.handleTouch()
    return true
  end
  _warpmenu_root.bg = bg
  _warpmenu_selectship_show()
  submenuLayer:add(_warpmenu_root)
  menuLayer:add(_warpmenu_root.subroot)
end
local function _popup_close(self)
  self:remove()
  popups.finish()
  popups.check_queue()
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
end
local function _popup_survival_perks_show(showAd, perk)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 312
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  popupBox:setLoc(0, 0)
  local t
  if perk ~= nil then
    t = _("Would you like to renew this perk or modify your perk selections?")
  else
    t = _("Would you like to modify your perk selections?")
  end
  local text = popupBox:add(ui.TextBox.new(t, FONT_MEDIUM, "ffffff", "center", 516, nil, true))
  text:setLoc(0, 64)
  local closeBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconClose.png"))
  closeBtn._up:setColor(unpack(UI_COLOR_RED))
  closeBtn._down:setColor(unpack(UI_COLOR_RED_DARKEN))
  if perk ~= nil then
    closeBtn:setLoc(-popupWidth / 2 + 90, -popupHeight / 2 + 70)
  else
    closeBtn:setLoc(-popupWidth / 2 + 90, -popupHeight / 2 + 70)
  end
  closeBtn.handleTouch = Button_handleTouch
  function closeBtn.onClick()
    _popup_close(popup)
    levelAS:resume()
    uiAS:resume()
    environmentAS:resume()
  end
  local modifyBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
  modifyBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  modifyBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  if perk ~= nil then
    modifyBtn:setLoc(-110, -popupHeight / 2 + 70)
  else
    modifyBtn:setLoc(0, -popupHeight / 2 + 70)
  end
  local modifyBtnText = modifyBtn._up:add(ui.TextBox.new(_("Modify"), FONT_SMALL_BOLD, "000000", "center"))
  modifyBtnText:setColor(0, 0, 0)
  modifyBtnText:setLoc(0, -2)
  local modifyBtnText = modifyBtn._down:add(ui.TextBox.new(_("Modify"), FONT_SMALL_BOLD, "000000", "center"))
  modifyBtnText:setColor(0, 0, 0)
  modifyBtnText:setLoc(0, -2)
  modifyBtn.handleTouch = Button_handleTouch
  function modifyBtn.onClick()
    _popup_close(popup)
    uiAS:resume()
    local new_perks = {}
    perks_inuse = {}
    local perkdef = require("ShipData-Perks")
    for i, v in pairs(active_perks) do
      new_perks[v.order] = i
      perks_inuse[i] = v.startTime
    end
    active_perks = new_perks
    if levelUI then
      levelUI.inStoreMenu = true
    end
    menu_show("perks?mode=ingame", function()
      if levelUI then
        levelUI.inStoreMenu = false
      end
      levelAS:resume()
      uiAS:resume()
      environmentAS:resume()
      if #active_perks > 0 then
        gameSessionAnalytics.perks = {}
      end
      local new_perks = {}
      local perkdef = require("ShipData-Perks")
      for i, v in ipairs(active_perks) do
        new_perks[v] = util.table_copy(perkdef[v])
        new_perks[v].order = i
        gameSessionAnalytics.perks[i] = v
        if not gameSessionAnalytics[string.format("perks_%s", v)] then
          gameSessionAnalytics[string.format("perks_%s", v)] = 1
        else
          gameSessionAnalytics[string.format("perks_%s", v)] = gameSessionAnalytics[string.format("perks_%s", v)] + 1
        end
        if perks_inuse[v] ~= nil then
          new_perks[v].startTime = perks_inuse[v]
        end
      end
      active_perks = new_perks
      levelui_update_survival_perk(1)
      levelui_update_survival_perk(2)
      levelui_update_survival_perk(3)
    end)
  end
  if perk ~= nil then
    local refreshBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
    refreshBtn._up:setColor(unpack(UI_COLOR_GREEN))
    refreshBtn._down:setColor(unpack(UI_COLOR_GREEN_DARKEN))
    refreshBtn:setLoc(105, -popupHeight / 2 + 70)
    local refreshBtnText = refreshBtn._up:add(ui.TextBox.new(_("Refresh Perk ("), FONT_SMALL_BOLD, "000000", "center"))
    refreshBtnText:setColor(0, 0, 0)
    refreshBtnText:setLoc(-40, -2)
    local icon = refreshBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. PERKS_RESOURCE_TYPE:gsub("^%l", string.upper) .. "Med.png"))
    icon:setLoc(45, 0)
    local text = refreshBtn._up:add(ui.TextBox.new("" .. perk.cost .. ")", FONT_SMALL_BOLD, "000000", "left", 40))
    text:setColor(0, 0, 0)
    text:setLoc(85, -2)
    local refreshBtnText = refreshBtn._down:add(ui.TextBox.new(_("Refresh Perk ("), FONT_SMALL_BOLD, "000000", "center"))
    refreshBtnText:setColor(0, 0, 0)
    refreshBtnText:setLoc(-40, -2)
    local icon = refreshBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. PERKS_RESOURCE_TYPE:gsub("^%l", string.upper) .. "Med.png"))
    icon:setLoc(45, 0)
    local text = refreshBtn._down:add(ui.TextBox.new("" .. perk.cost .. ")", FONT_SMALL_BOLD, "000000", "left", 40))
    text:setColor(0, 0, 0)
    text:setLoc(85, -2)
    refreshBtn.handleTouch = Button_handleTouch
    function refreshBtn.onClick()
      _popup_close(popup)
      profile_currency_txn(PERKS_RESOURCE_TYPE, -perk.cost, "Survival Perks: " .. perk.id, true)
      local perkdef = require("ShipData-Perks")
      active_perks[perk.id] = util.table_copy(perkdef[perk.id])
      active_perks[perk.id].startTime = nil
      active_perks[perk.id].order = perk.order
      local perk = active_perks[perk.id]
      levelui_update_survival_perk(perk.order)
      levelAS:resume()
      uiAS:resume()
      environmentAS:resume()
    end
  end
  popups.insert_queue(popup)
  popups.check_queue()
  bucket.pop()
end
popup_survival_perks_show = _popup_survival_perks_show
local function _popup_survival_unlocked_show(showAd)
  if profile.popups.on_survival_unlock ~= nil then
    return false
  else
    profile.popups.on_survival_unlock = true
    profile:save()
  end
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 312
  local titleBG = popup:add(ui.Image.new("menuTemplateShared.atlas.png#popupTitleBG.png"))
  titleBG:setLoc(0, popupHeight / 2 - 24)
  local titleText = titleBG:add(ui.TextBox.new(_("Survival Mode Unlocked"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  titleText:setLoc(0, -4)
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  popupBox:setLoc(0, -62)
  local text = popupBox:add(ui.TextBox.new(_("Select the SURVIVAL tab on the right to play Strikefleet Omega in Survival Mode - survive as long as you can and compete for high scores!"), FONT_MEDIUM, "ffffff", "center", 516, nil, true))
  text:setLoc(0, 64)
  local continueBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
  continueBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  continueBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  continueBtn:setLoc(0, -popupHeight / 2 + 70)
  local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn.onClick()
    _popup_close(popup)
  end
  popups.insert_queue(popup)
  popups.check_queue()
  bucket.pop()
end
local function _popup_survival_locked_show(showAd)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 312
  local titleBG = popup:add(ui.Image.new("menuTemplateShared.atlas.png#popupTitleBG.png"))
  titleBG:setLoc(0, popupHeight / 2 - 24)
  local titleText = titleBG:add(ui.TextBox.new(_("Survival Mode Locked"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  titleText:setLoc(0, -4)
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  popupBox:setLoc(0, -62)
  local text = popupBox:add(ui.TextBox.new(string.format(_("Play the campaign through system %d to unlock survival mode."), SURVIVAL_MODE_UNLOCK_SYSTEM), FONT_MEDIUM, "ffffff", "center", 516, nil, true))
  text:setLoc(0, 64)
  local continueBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
  continueBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  continueBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  continueBtn:setLoc(0, -popupHeight / 2 + 70)
  local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn.onClick()
    _popup_close(popup)
  end
  popups.insert_queue(popup)
  popups.check_queue()
  bucket.pop()
end
local function _popup_intro_show(showAd)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  levelAS:pause()
  environmentAS:pause()
  local setPage
  local function popup_first_message()
    local popup = ui.Group.new()
    local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
    bg:setLoc(0, submenu_y)
    function bg.handleTouch()
      return true
    end
    if device.os == device.OS_ANDROID then
      local callback = function()
        return true
      end
      table_insert(android_back_button_queue, callback)
      MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
    end
    local popupWidth = 620
    local popupHeight = 312
    local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
    local image = popupBox:add(ui.Image.new("characters/commOfficerSurprise.png"))
    image:setLoc(-192, 64)
    local text = popupBox:add(ui.TextBox.new(_("Captain, urgent message coming in from Admiral Kerensky at Fleet Command!"), FONT_MEDIUM, "ffffff", "left", 350, popupHeight - 180, true))
    text:setLoc(80, 20)
    local name = popupBox:add(ui.TextBox.new(_("Comm Officer Joe \"Sparks\" DiNunzio "), FONT_SMALL_BOLD, "ffffff", "left", 350, nil, true))
    name:setColor(color.parse("bce0ee"))
    name:setLoc(80, popupHeight / 2 - 55)
    local continueBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
    continueBtn._up:setColor(unpack(UI_COLOR_YELLOW))
    continueBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
    continueBtn:setLoc(0, -popupHeight / 2 + 70)
    local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
    continueBtnText:setColor(0, 0, 0)
    continueBtnText:setLoc(0, -2)
    local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
    continueBtnText:setColor(0, 0, 0)
    continueBtnText:setLoc(0, -2)
    continueBtn.handleTouch = Button_handleTouch
    function continueBtn.onClick()
      soundmanager.onSFX("onMessageEnd")
      popupsLayer:remove(popup)
      setPage(1)
    end
    popupsLayer:add(popup)
    soundmanager.onSFX("onMessage")
  end
  popup_first_message()
  local pages = {}
  table_insert(pages, {
    image = "introBoom.png"
  })
  table_insert(pages, {
    image = "introQueen.png"
  })
  table_insert(pages, {
    image = "introBuoy.png"
  })
  table_insert(pages, {
    image = "introShipyard.png"
  })
  local curPage = 1
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, device.ui_height))
  function bg.handleTouch()
    return true
  end
  local image = popup:add(ui.Image.new("white.png"))
  if device.ui_assetrez == device.ASSET_MODE_LO then
    image:setScl(2, 2)
  end
  function setPage(pageNum)
    curPage = pageNum
    local page = pages[curPage]
    image:setImage(page.image)
    popupsLayer:add(popup)
    local message = popups.show("on_intro_" .. curPage, nil, function()
      popupsLayer:remove(popup)
      if curPage < #pages then
        setPage(curPage + 1)
      else
        levelAS:resume()
        environmentAS:resume()
        uiAS:resume()
        if device.os == device.OS_ANDROID then
          table_remove(android_back_button_queue, #android_back_button_queue)
          local callback = android_back_button_queue[#android_back_button_queue]
          MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
        end
      end
    end, function(self)
      self.popupBox:setLoc(0, device.ui_height / 2 - 100)
    end)
    message:setLoc(0, device.ui_height / 2 - 100)
  end
  bucket.pop()
end
popup_intro_show = _popup_intro_show
local function _popup_tutorial_show(showAd)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local pages = {}
  table_insert(pages, {
    title = _("Intercept the Enemy"),
    image = "tutorial/slide1Intercept.png",
    text = _("Tap and drag to path your fighters.")
  })
  table_insert(pages, {
    title = _("Artillery Barrage"),
    image = "tutorial/slide2Artillery.png",
    text = _("Tap the screen to fire artillery.")
  })
  table_insert(pages, {
    title = _("Warp in More Ships"),
    image = "tutorial/slide3Warp.png",
    text = _("Automatically gathered crystals allow you to warp in more ships.")
  })
  table_insert(pages, {
    title = _("Collect Repair Buoys"),
    image = "tutorial/slide7Repair.png",
    text = _("Use harvesters to collect buoys that repair your ships and can hold crystals.")
  })
  table_insert(pages, {
    title = _("Collect Alloy"),
    image = "tutorial/slide4Alloy.png",
    text = _("Tap to collect alloy used to buy and upgrade ships.")
  })
  table_insert(pages, {
    title = _("Collect Megacreds"),
    image = "tutorial/slide5Saucers.png",
    text = _("Tap to collect megacreds for perks, Death Blossom, and Omega-13 respawn.")
  })
  table_insert(pages, {
    title = _("Use the right fighters"),
    image = "tutorial/slide6RightShip.png",
    text = _("Some ships are more effective against certain enemies.")
  })
  local curPage = 1
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 440
  local titleBG = popup:add(ui.Image.new("menuTemplateShared.atlas.png#popupTitleBG.png"))
  titleBG:setLoc(0, popupHeight / 2 - 24)
  local titleText = titleBG:add(ui.TextBox.new("Title", FONT_XLARGE, "ffffff", "center", nil, nil, true))
  titleText:setLoc(0, -4)
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  popupBox:setLoc(0, -62)
  local image = popupBox:add(ui.Image.new("white.png"))
  image:setLoc(0, 90)
  local text = popupBox:add(ui.TextBox.new("Text", FONT_MEDIUM, "ffffff", "center", 516, nil, true))
  text:setLoc(0, -50)
  local pagesNumText = popupBox:add(ui.TextBox.new("0 / 0", FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  pagesNumText:setLoc(0, -popupHeight / 2 + 75)
  local leftPageBtn, rightPageBtn
  local function setPage(pageNum)
    curPage = pageNum
    local page = pages[curPage]
    titleText:setString(page.title, true)
    image:setImage(page.image)
    text:setString(page.text, true)
    pagesNumText:setString("" .. curPage .. "/" .. #pages, true)
    if curPage == 1 then
      leftPageBtn._up:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
      leftPageBtn.handleTouch = nil
    else
      leftPageBtn._up:setColor(unpack(UI_COLOR_YELLOW))
      leftPageBtn.handleTouch = Button_handleTouch
    end
    if curPage == #pages then
      rightPageBtn._up:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
      rightPageBtn.handleTouch = nil
    else
      rightPageBtn._up:setColor(unpack(UI_COLOR_YELLOW))
      rightPageBtn.handleTouch = Button_handleTouch
    end
  end
  leftPageBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#mapPrevious.png"))
  leftPageBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  leftPageBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  leftPageBtn:setLoc(-70, -popupHeight / 2 + 75)
  leftPageBtn.handleTouch = Button_handleTouch
  function leftPageBtn.onClick()
    setPage(curPage - 1)
  end
  rightPageBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#mapNext.png"))
  rightPageBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  rightPageBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  rightPageBtn:setLoc(70, -popupHeight / 2 + 75)
  rightPageBtn.handleTouch = Button_handleTouch
  function rightPageBtn.onClick()
    setPage(curPage + 1)
  end
  local closeBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconClose.png"))
  closeBtn._up:setColor(unpack(UI_COLOR_RED))
  closeBtn._down:setColor(unpack(UI_COLOR_RED_DARKEN))
  closeBtn:setLoc(popupWidth / 2 - 75, -popupHeight / 2 + 75)
  closeBtn.handleTouch = Button_handleTouch
  function closeBtn.onClick()
    popupsLayer:remove(popup)
    if device.os == device.OS_ANDROID then
      table_remove(android_back_button_queue, #android_back_button_queue)
      local callback = android_back_button_queue[#android_back_button_queue]
      MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
    end
  end
  setPage(1)
  popupsLayer:add(popup)
  bucket.pop()
end
local function _popup_achievement_show(def, showAd)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 312
  local titleBG = popup:add(ui.Image.new("menuTemplateShared.atlas.png#popupTitleBG.png"))
  titleBG:setLoc(0, popupHeight / 2 - 24)
  local titleText = titleBG:add(ui.TextBox.new(_("Achievement Unlocked"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  titleText:setLoc(0, -4)
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  popupBox:setLoc(0, -62)
  local text = popupBox:add(ui.TextBox.new(_(def.name), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
  text:setLoc(0, 105)
  local icon = popupBox:add(ui.Image.new(def.icon))
  icon:setLoc(0, 60)
  local description = popupBox:add(ui.TextBox.new(_(def.completed), FONT_MEDIUM, "ffffff", "center", 512, nil, true))
  description:setLoc(0, -5)
  local continueBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
  continueBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  continueBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  continueBtn:setLoc(0, -popupHeight / 2 + 70)
  local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn.onClick()
    _popup_close(popup)
  end
  popups.insert_queue(popup)
  popups.check_queue()
  bucket.pop()
end
popup_achievement_show = _popup_achievement_show
local function _popup_levelup_show(actionset, def, showAd)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 440
  local titleBG = popup:add(ui.Image.new("menuTemplateShared.atlas.png#popupTitleBG.png"))
  titleBG:setLoc(0, popupHeight / 2 - 24)
  local titleText = titleBG:add(ui.TextBox.new(_("Level Up!"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  titleText:setLoc(0, -4)
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  popupBox:setLoc(0, -62)
  local image = popupBox:add(ui.Image.new("characters/admiralCongratsTall.png"))
  image:setLoc(-192, 64)
  local text = popupBox:add(ui.TextBox.new(_("You're making excellent progress, Admiral. I'm transmitting additional funds. Spend them wisely."), FONT_MEDIUM, "ffffff", "left", 350, popupHeight - 180, true))
  text:setLoc(80, 20)
  local name = popupBox:add(ui.TextBox.new(_("Fleet Admiral Alexandre Kerensky"), FONT_SMALL_BOLD, "ffffff", "left", 350, nil, true))
  name:setColor(color.parse("bce0ee"))
  name:setLoc(80, popupHeight / 2 - 55)
  if def.bonusAlloy ~= 0 then
    local alloyText = popupBox:add(ui.TextBox.new("" .. def.bonusAlloy, FONT_LARGE, "ffffff", "center", nil, nil, true))
    alloyText:setLoc(80, -popupHeight / 2 + 180)
    local alloyIcon = popupBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconAlloyLarge.png"))
    alloyIcon:setLoc(80 - alloyText._width / 2 - 36, -popupHeight / 2 + 180)
  end
  local continueBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
  continueBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  continueBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  continueBtn:setLoc(0, -popupHeight / 2 + 70)
  local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn.onClick()
    _popup_close(popup)
    actionset:resume()
  end
  popups.insert_queue(popup)
  popups.check_queue()
  bucket.pop()
end
local function _popup_mainmenuconfirm_show(showAd)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 312
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  local text = popupBox:add(ui.TextBox.new(_([[
Do you want to return to the Main Menu?
You will lose all current mission progress.]]), FONT_MEDIUM, "ffffff", "center", 516, nil, true))
  text:setLoc(0, 64)
  local continueBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
  continueBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  continueBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  continueBtn:setLoc(80, -popupHeight / 2 + 70)
  local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn.onClick()
    popup:remove()
    popups.clear_queue()
    pause_close()
    clear_game("abandon")
    level_clear()
    mainmenu_show()
  end
  local cancelBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
  cancelBtn._up:setColor(unpack(UI_COLOR_RED))
  cancelBtn._down:setColor(unpack(UI_COLOR_RED_DARKEN))
  cancelBtn:setLoc(-130, -popupHeight / 2 + 70)
  local cancelBtnText = cancelBtn._up:add(ui.TextBox.new(_("Cancel"), FONT_SMALL_BOLD, "000000", "center"))
  cancelBtnText:setColor(0, 0, 0)
  cancelBtnText:setLoc(0, -2)
  local cancelBtnText = cancelBtn._down:add(ui.TextBox.new(_("Cancel"), FONT_SMALL_BOLD, "000000", "center"))
  cancelBtnText:setColor(0, 0, 0)
  cancelBtnText:setLoc(0, -2)
  cancelBtn.handleTouch = Button_handleTouch
  function cancelBtn.onClick()
    popup:remove()
  end
  popupsLayer:add(popup)
  bucket.pop()
end
local function _popup_restartconfirm_show(showAd)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 312
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  local text = popupBox:add(ui.TextBox.new(_([[
Do you wish to restart?
You will lose all current mission progress.]]), FONT_MEDIUM, "ffffff", "center", 516, nil, true))
  text:setLoc(0, 64)
  local continueBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
  continueBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  continueBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  continueBtn:setLoc(80, -popupHeight / 2 + 70)
  local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn.onClick()
    popup:remove()
    popups.clear_queue()
    pause_close()
    clear_game("restart")
    level_clear()
    local lastCompletedGalaxy, lastCompletedSystem = _get_last_completed_galaxy_system()
    if lastCompletedGalaxy == 1 and lastCompletedSystem == 0 then
      level_run(1, 1)
    else
      menu_show("galaxymap")
    end
  end
  local cancelBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
  cancelBtn._up:setColor(unpack(UI_COLOR_RED))
  cancelBtn._down:setColor(unpack(UI_COLOR_RED_DARKEN))
  cancelBtn:setLoc(-130, -popupHeight / 2 + 70)
  local cancelBtnText = cancelBtn._up:add(ui.TextBox.new(_("Cancel"), FONT_SMALL_BOLD, "000000", "center"))
  cancelBtnText:setColor(0, 0, 0)
  cancelBtnText:setLoc(0, -2)
  local cancelBtnText = cancelBtn._down:add(ui.TextBox.new(_("Cancel"), FONT_SMALL_BOLD, "000000", "center"))
  cancelBtnText:setColor(0, 0, 0)
  cancelBtnText:setLoc(0, -2)
  cancelBtn.handleTouch = Button_handleTouch
  function cancelBtn.onClick()
    popup:remove()
  end
  popupsLayer:add(popup)
  bucket.pop()
end
local function _popup_chooseperk_show(showAd)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 312
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  local t
  if menuMode ~= "ingame" then
    t = _("Start the mission without choosing perks?")
  else
    t = _("Continue the mission without choosing perks?")
  end
  local text = popupBox:add(ui.TextBox.new(t, FONT_MEDIUM, "ffffff", "center", 516, nil, true))
  text:setLoc(0, 64)
  local continueBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
  continueBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  continueBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  continueBtn:setLoc(80, -popupHeight / 2 + 70)
  local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Launch"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Launch"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn.onClick()
    _popup_close(popup)
    if #screenHistory > 0 then
      menu_close()
      level_run(levelGalaxyIndex, levelSystemIndex)
    else
      menu_close()
    end
    soundmanager.onSFX("onPageSwipeForward")
  end
  local cancelBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
  cancelBtn._up:setColor(unpack(UI_COLOR_RED))
  cancelBtn._down:setColor(unpack(UI_COLOR_RED_DARKEN))
  cancelBtn:setLoc(-130, -popupHeight / 2 + 70)
  local cancelBtnText = cancelBtn._up:add(ui.TextBox.new(_("Cancel"), FONT_SMALL_BOLD, "000000", "center"))
  cancelBtnText:setColor(0, 0, 0)
  cancelBtnText:setLoc(0, -2)
  local cancelBtnText = cancelBtn._down:add(ui.TextBox.new(_("Cancel"), FONT_SMALL_BOLD, "000000", "center"))
  cancelBtnText:setColor(0, 0, 0)
  cancelBtnText:setLoc(0, -2)
  cancelBtn.handleTouch = Button_handleTouch
  function cancelBtn.onClick()
    _popup_close(popup)
  end
  popups.insert_queue(popup)
  popups.check_queue()
  bucket.pop()
end
local function _popup_shippurchase_show(screen, def, showAd)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 312
  local titleBG = popup:add(ui.Image.new("menuTemplateShared.atlas.png#popupTitleBG.png"))
  titleBG:setLoc(0, popupHeight / 2 - 24)
  local titleText = titleBG:add(ui.TextBox.new(_("New Ship Purchased"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  titleText:setLoc(0, -4)
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  popupBox:setLoc(0, -62)
  local text = popupBox:add(ui.TextBox.new(_(def.storeName .. " " .. def.storeClass), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
  text:setLoc(0, 105)
  local ship = popupBox:add(ui.Image.new(def.storeTexture[1]))
  ship:setScl(0.75, 0.75)
  ship:setLoc(-80, 30)
  ship:setRot(-90)
  local icon
  if baseID == "SPC" then
    icon = popupBox:add(ui.Image.new("storeScreen.atlas.png#storeSelectorSPC.png"))
  else
    local subentityStr, queryStr = breakstr(def.subentities[1], "?")
    local subentity = entitydef[subentityStr]
    if subentity.type:find("cannon") then
      icon = popupBox:add(ui.Image.new("storeScreen.atlas.png#gunshipTurretBasic.png"))
      icon:setColor(unpack(UI_SHIP_COLOR_SPECIAL))
    elseif subentity.type == "module" then
      local hangarentity = entitydef[subentity.hangarInventoryType]
      if hangarentity.type == "fighter" then
        icon = popupBox:add(ui.Image.new(string.format("storeScreen.atlas.png#%s.png", _getFighterFrame(def.storeTags))))
        do
          local r, g, b = color.parse(subentity.pathColor)
          icon:setColor(r, g, b)
          local hangarship = icon:add(ui.Image.new(hangarentity.storeTexture))
          hangarship:clearAttrLink(MOAIColor.INHERIT_COLOR)
          hangarship:setRot(-90)
        end
      elseif hangarentity.type == "harvester" then
        icon = popupBox:add(ui.Image.new("storeScreen.atlas.png#storeSelectorMiner.png"))
        local r, g, b = color.parse(subentity.pathColor)
        icon:setColor(r, g, b)
        local hangarship = icon:add(ui.Image.new(hangarentity.storeTexture))
        hangarship:clearAttrLink(MOAIColor.INHERIT_COLOR)
        hangarship:setRot(-90)
      end
    end
  end
  icon:setScl(0.75, 0.75)
  icon:setLoc(150, 30)
  local continueBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
  continueBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  continueBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  continueBtn:setLoc(0, -popupHeight / 2 + 70)
  local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn.onClick()
    if not screenAction:isActive() then
      _popup_close(popup)
      shippurchase_close({back = true})
      local screen = table_remove(screenHistory)
      if screen == "fleet" then
        fleet_show({
          back = true,
          bottom_bar = true,
          store_filter = true
        })
      end
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  popups.insert_queue(popup)
  popups.check_queue()
  bucket.pop()
end
local function _popup_shipunlock_show(self, def, showAd)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 312
  local titleBG = popup:add(ui.Image.new("menuTemplateShared.atlas.png#popupTitleBG.png"))
  titleBG:setLoc(0, popupHeight / 2 - 24)
  local titleText = titleBG:add(ui.TextBox.new(_("New Ship Available"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  titleText:setLoc(0, -4)
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  popupBox:setLoc(0, -62)
  local text = popupBox:add(ui.TextBox.new(_(def.storeName .. " " .. def.storeClass), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
  text:setLoc(0, 105)
  local ship = popupBox:add(ui.Image.new(def.storeTexture[1]))
  ship:setScl(0.75, 0.75)
  ship:setLoc(-80, 30)
  ship:setRot(-90)
  local icon
  if baseID == "SPC" then
    icon = popupBox:add(ui.Image.new("storeScreen.atlas.png#storeSelectorSPC.png"))
  else
    local subentityStr, queryStr = breakstr(def.subentities[1], "?")
    local subentity = entitydef[subentityStr]
    if subentity.type:find("cannon") then
      icon = popupBox:add(ui.Image.new("storeScreen.atlas.png#gunshipTurretBasic.png"))
      icon:setColor(unpack(UI_SHIP_COLOR_SPECIAL))
    elseif subentity.type == "module" then
      local hangarentity = entitydef[subentity.hangarInventoryType]
      if hangarentity.type == "fighter" then
        icon = popupBox:add(ui.Image.new(string.format("storeScreen.atlas.png#%s.png", _getFighterFrame(def.storeTags))))
        do
          local r, g, b = color.parse(subentity.pathColor)
          icon:setColor(r, g, b)
          local hangarship = icon:add(ui.Image.new(hangarentity.storeTexture))
          hangarship:clearAttrLink(MOAIColor.INHERIT_COLOR)
          hangarship:setRot(-90)
        end
      elseif hangarentity.type == "harvester" then
        icon = popupBox:add(ui.Image.new("storeScreen.atlas.png#storeSelectorMiner.png"))
        local r, g, b = color.parse(subentity.pathColor)
        icon:setColor(r, g, b)
        local hangarship = icon:add(ui.Image.new(hangarentity.storeTexture))
        hangarship:clearAttrLink(MOAIColor.INHERIT_COLOR)
        hangarship:setRot(-90)
      end
    end
  end
  icon:setScl(0.75, 0.75)
  icon:setLoc(150, 30)
  local continueBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
  continueBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  continueBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  continueBtn:setLoc(0, -popupHeight / 2 + 70)
  local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn.onClick()
    if not screenAction:isActive() then
      _popup_close(popup)
    end
  end
  popups.insert_queue(popup)
  popups.check_queue()
  bucket.pop()
end
function _popup_creds_show(screen, showAd, callback, referer)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 312
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  local text = popupBox:add(ui.TextBox.new(_([[
You don't have enough MegaCreds.
Get more?]]), FONT_MEDIUM, "ffffff", "center", 516, nil, true))
  text:setLoc(0, 64)
  local getMoreBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
  getMoreBtn._up:setColor(unpack(UI_COLOR_GREEN))
  getMoreBtn._down:setColor(unpack(UI_COLOR_GREEN_DARKEN))
  getMoreBtn:setLoc(80, -popupHeight / 2 + 70)
  local getMoreBtnText = getMoreBtn._up:add(ui.TextBox.new(_("Get More!"), FONT_MEDIUM_BOLD, "000000", "center"))
  getMoreBtnText:setColor(0, 0, 0)
  getMoreBtnText:setLoc(0, -2)
  local getMoreBtnText = getMoreBtn._down:add(ui.TextBox.new(_("Get More!"), FONT_MEDIUM_BOLD, "000000", "center"))
  getMoreBtnText:setColor(0, 0, 0)
  getMoreBtnText:setLoc(0, -2)
  getMoreBtn.handleTouch = Button_handleTouch
  function getMoreBtn.onClick()
    if not screenAction:isActive() then
      table_insert(screenHistory, screen)
      _popup_close(popup)
      if callback then
        callback(true)
        return
      elseif screen == "shippurchase" then
        shippurchase_close({forward = true, bottom_bar = true})
      elseif screen == "shipupgrade" then
        shipupgrade_close({forward = true, bottom_bar = true})
      elseif screen == "perks" then
        perks_close({
          forward = true,
          bottom_bar = true,
          perks_bar = true
        })
      end
      starbank_show({forward = true}, "creds", true, referer)
      soundmanager.onSFX("onPageSwipeForward")
    end
  end
  local cancelBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
  cancelBtn._up:setColor(unpack(UI_COLOR_RED))
  cancelBtn._down:setColor(unpack(UI_COLOR_RED_DARKEN))
  cancelBtn:setLoc(-130, -popupHeight / 2 + 70)
  local cancelBtnText = cancelBtn._up:add(ui.TextBox.new(_("Cancel"), FONT_SMALL_BOLD, "000000", "center"))
  cancelBtnText:setColor(0, 0, 0)
  cancelBtnText:setLoc(0, -2)
  local cancelBtnText = cancelBtn._down:add(ui.TextBox.new(_("Cancel"), FONT_SMALL_BOLD, "000000", "center"))
  cancelBtnText:setColor(0, 0, 0)
  cancelBtnText:setLoc(0, -2)
  cancelBtn.handleTouch = Button_handleTouch
  function cancelBtn.onClick()
    if not screenAction:isActive() then
      _popup_close(popup)
      if callback then
        callback(false)
      end
    end
  end
  popups.insert_queue(popup)
  popups.check_queue()
  bucket.pop()
end
function _popup_alloy_show(screen, showAd, callback, referer)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local popupWidth = 620
  local popupHeight = 312
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  local text = popupBox:add(ui.TextBox.new(_([[
You don't have enough Alloy.
Get more?]]), FONT_MEDIUM, "ffffff", "center", 516, nil, true))
  text:setLoc(0, 64)
  local getMoreBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
  getMoreBtn._up:setColor(unpack(UI_COLOR_GREEN))
  getMoreBtn._down:setColor(unpack(UI_COLOR_GREEN_DARKEN))
  getMoreBtn:setLoc(80, -popupHeight / 2 + 70)
  local getMoreBtnText = getMoreBtn._up:add(ui.TextBox.new(_("Get More!"), FONT_MEDIUM_BOLD, "000000", "center"))
  getMoreBtnText:setColor(0, 0, 0)
  getMoreBtnText:setLoc(0, -2)
  local getMoreBtnText = getMoreBtn._down:add(ui.TextBox.new(_("Get More!"), FONT_MEDIUM_BOLD, "000000", "center"))
  getMoreBtnText:setColor(0, 0, 0)
  getMoreBtnText:setLoc(0, -2)
  getMoreBtn.handleTouch = Button_handleTouch
  function getMoreBtn.onClick()
    if not screenAction:isActive() then
      table_insert(screenHistory, screen)
      _popup_close(popup)
      if callback then
        callback(true)
        return
      elseif screen == "shippurchase" then
        shippurchase_close({forward = true, bottom_bar = true})
      elseif screen == "shipupgrade" then
        shipupgrade_close({forward = true, bottom_bar = true})
      elseif screen == "perks" then
        perks_close({
          forward = true,
          bottom_bar = true,
          perks_bar = true
        })
      end
      starbank_show({forward = true}, "alloy", true, referer)
      soundmanager.onSFX("onPageSwipeForward")
    end
  end
  local cancelBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
  cancelBtn._up:setColor(unpack(UI_COLOR_RED))
  cancelBtn._down:setColor(unpack(UI_COLOR_RED_DARKEN))
  cancelBtn:setLoc(-130, -popupHeight / 2 + 70)
  local cancelBtnText = cancelBtn._up:add(ui.TextBox.new(_("Cancel"), FONT_SMALL_BOLD, "000000", "center"))
  cancelBtnText:setColor(0, 0, 0)
  cancelBtnText:setLoc(0, -2)
  local cancelBtnText = cancelBtn._down:add(ui.TextBox.new(_("Cancel"), FONT_SMALL_BOLD, "000000", "center"))
  cancelBtnText:setColor(0, 0, 0)
  cancelBtnText:setLoc(0, -2)
  cancelBtn.handleTouch = Button_handleTouch
  function cancelBtn.onClick()
    if not screenAction:isActive() then
      _popup_close(popup)
      if callback then
        callback(false)
      end
    end
  end
  popups.insert_queue(popup)
  popups.check_queue()
  bucket.pop()
end
function _popup_currency_show(currencyType, screen, showAd, callback, referer)
  _G[string.format("_popup_%s_show", currencyType)](screen, showAd, callback, referer)
end
local _musicBtn_inactive_onClick, _musicBtn_active_onClick
function _musicBtn_inactive_onClick(self)
  profile.music = true
  profile:save()
  self._up:setColor(1, 1, 1)
  self._down:setColor(0.5, 0.5, 0.5)
  self._up:remove(self.iconOff)
  self.onClick = _musicBtn_active_onClick
  soundmanager.setMute(false, true)
end
function _musicBtn_active_onClick(self)
  profile.music = false
  profile:save()
  self._up:setColor(0.5, 0.5, 0.5)
  self._down:setColor(1, 1, 1)
  self.iconOff = self._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
  self.iconOff:setColor(2, 2, 2)
  self.onClick = _musicBtn_inactive_onClick
  soundmanager.setMute(true, true)
end
local _soundBtn_inactive_onClick, _soundBtn_active_onClick
function _soundBtn_inactive_onClick(self)
  profile.sound = true
  profile:save()
  self._up:setColor(1, 1, 1)
  self._down:setColor(0.5, 0.5, 0.5)
  self._up:remove(self.iconOff)
  self.onClick = _soundBtn_active_onClick
  soundmanager.setMute(false)
end
function _soundBtn_active_onClick(self)
  profile.sound = false
  profile:save()
  self._up:setColor(0.5, 0.5, 0.5)
  self._down:setColor(1, 1, 1)
  self.iconOff = self._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
  self.iconOff:setColor(2, 2, 2)
  self.onClick = _soundBtn_inactive_onClick
  soundmanager.setMute(true)
end
function pause_close()
  levelUI.pausing = false
  if _pause_root.paused then
    levelAS:resume()
    environmentAS:resume()
    uiAS:resume()
  end
  levelui_unhide_hud_buttons()
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  _pause_root:remove()
  _pause_root = nil
end
function pause_show(root)
  _pause_root = ui.Group.new()
  if not levelAS:isPaused() then
    levelAS:pause()
    environmentAS:pause()
    uiAS:pause()
    _pause_root.paused = true
  end
  levelUI.pausing = true
  levelui_hide_hud_buttons()
  root:add(_pause_root)
  local bg = _pause_root:add(ui.PickBox.new(device.ui_width, device.ui_height, color.toHex(0.111765, 0.111765, 0.111765, 0.5)))
  function bg.handleTouch()
    return true
  end
  local uiBarHeight
  if gameMode == "galaxy" then
    uiBarHeight = UI_BAR_HEIGHT
  elseif gameMode == "survival" then
    uiBarHeight = UI_BAR_HEIGHT_SURVIVAL
  end
  local pauseBtn = _pause_root:add(ui.Button.new("menuTemplateShared.atlas.png#iconPause.png"))
  pauseBtn._up:setColor(unpack(UI_CREDITS_TITLE_COLOR))
  pauseBtn._down:setColor(unpack(UI_COLOR_BLUE_DARKEN))
  pauseBtn:setLoc(device.ui_width / 2 - 36, device.ui_height / 2 - uiBarHeight / 2 + 26)
  pauseBtn.handleTouch = Button_handleTouch
  function pauseBtn.onClick()
    pause_close()
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      pause_close()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local pauseBox = _pause_root:add(ui.NinePatch.new("glassyBoxWithHeader9p.lua", 600, 280))
  pauseBox:setLoc(0, device.ui_height / 2 - 60 - (device.ui_height - 310) / 2)
  local galaxyIndex, systemIndex, idx = level_get_galaxy_system()
  local levelDef = GALAXY_DATA[idx]
  local gamePausedText
  if gameMode == "survival" then
    gamePausedText = pauseBox:add(ui.TextBox.new(_("Survival Mode (Paused)"), FONT_MEDIUM, "ffffff", "center"))
  else
    gamePausedText = pauseBox:add(ui.TextBox.new("" .. galaxyIndex .. "." .. systemIndex .. ": " .. _(levelDef["System Name"]) .. " " .. _("(Paused)"), FONT_MEDIUM, "ffffff", "center"))
  end
  gamePausedText:setColor(unpack(UI_CREDITS_TITLE_COLOR))
  gamePausedText:setLoc(0, 105)
  local resumeBtn = pauseBox:add(ui.Button.new("menuTemplateShared.atlas.png#largeButton.png"))
  resumeBtn._down:setColor(0.5, 0.5, 0.5)
  resumeBtn:setLoc(0, -90)
  local resumeBtnText = resumeBtn._up:add(ui.TextBox.new(_("Resume"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  resumeBtnText:setLoc(0, 0)
  local resumeBtnText = resumeBtn._down:add(ui.TextBox.new(_("Resume"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  resumeBtnText:setLoc(0, 0)
  resumeBtn.handleTouch = Button_handleTouch
  function resumeBtn.onClick()
    pause_close()
  end
  local restartBtn = pauseBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconRestart.png"))
  restartBtn._down:setColor(0.5, 0.5, 0.5)
  restartBtn:setLoc(-220, 15)
  restartBtn.handleTouch = Button_handleTouch
  function restartBtn.onClick()
    _popup_restartconfirm_show()
  end
  local mainmenuBtn = pauseBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconHome.png"))
  mainmenuBtn._down:setColor(0.5, 0.5, 0.5)
  mainmenuBtn:setLoc(-110, 15)
  mainmenuBtn.handleTouch = Button_handleTouch
  function mainmenuBtn.onClick()
    _popup_mainmenuconfirm_show()
  end
  local helpBtn = pauseBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconHelp.png"))
  helpBtn._down:setColor(0.5, 0.5, 0.5)
  helpBtn:setLoc(0, 15)
  helpBtn.handleTouch = Button_handleTouch
  function helpBtn.onClick()
    _popup_tutorial_show()
  end
  if profile.sound then
    do
      local soundBtn = pauseBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconSound.png"))
      soundBtn._up:setColor(1, 1, 1)
      soundBtn._down:setColor(0.5, 0.5, 0.5)
      soundBtn:setLoc(110, 15)
      soundBtn.handleTouch = Button_handleTouch
      soundBtn.onClick = _soundBtn_active_onClick
    end
  else
    local soundBtn = pauseBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconSound.png"))
    soundBtn._up:setColor(0.5, 0.5, 0.5)
    soundBtn._down:setColor(1, 1, 1)
    soundBtn:setLoc(110, 15)
    soundBtn.handleTouch = Button_handleTouch
    soundBtn.onClick = _soundBtn_inactive_onClick
    soundBtn.iconOff = soundBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
    soundBtn.iconOff:setColor(2, 2, 2)
  end
  if profile.music then
    do
      local musicBtn = pauseBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconMusic.png"))
      musicBtn._up:setColor(1, 1, 1)
      musicBtn._down:setColor(0.5, 0.5, 0.5)
      musicBtn:setLoc(220, 15)
      musicBtn.handleTouch = Button_handleTouch
      musicBtn.onClick = _musicBtn_active_onClick
    end
  else
    local musicBtn = pauseBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconMusic.png"))
    musicBtn._up:setColor(0.5, 0.5, 0.5)
    musicBtn._down:setColor(1, 1, 1)
    musicBtn:setLoc(220, 15)
    musicBtn.handleTouch = Button_handleTouch
    musicBtn.onClick = _musicBtn_inactive_onClick
    musicBtn.iconOff = musicBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
    musicBtn.iconOff:setColor(2, 2, 2)
  end
  local alloyBox = _pause_root:add(ui.NinePatch.new("glassyBoxWithHeader9p.lua", 196, 220))
  alloyBox:setLoc(-200, -device.ui_height / 2 + 130)
  local alloyText = alloyBox:add(ui.TextBox.new(_("Alloy"), FONT_MEDIUM, "ffffff", "center"))
  alloyText:setColor(unpack(UI_CREDITS_TITLE_COLOR))
  alloyText:setLoc(0, 75)
  local alloyThisSystemText = alloyBox:add(ui.TextBox.new(_("This System"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  alloyThisSystemText:setColor(unpack(UI_COLOR_GRAY))
  alloyThisSystemText:setLoc(0, 20)
  local alloyThisSystemNumText = alloyBox:add(ui.TextBox.new("" .. util.commasInNumbers(scores.alloy or 0), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
  alloyThisSystemNumText:setLoc(16, -10)
  local alloyThisSystemNumIcon = alloyThisSystemNumText:add(ui.Image.new("menuTemplateShared.atlas.png#iconAlloyMed.png"))
  alloyThisSystemNumIcon:setLoc(-alloyThisSystemNumText._width / 2 - 20, 2)
  local alloyTotalText = alloyBox:add(ui.TextBox.new(_("Total"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  alloyTotalText:setColor(unpack(UI_COLOR_GRAY))
  alloyTotalText:setLoc(0, -50)
  local alloyTotalNumText = alloyBox:add(ui.TextBox.new("" .. util.commasInNumbers(profile.alloy), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
  alloyTotalNumText:setLoc(16, -80)
  local alloyTotalNumIcon = alloyTotalNumText:add(ui.Image.new("menuTemplateShared.atlas.png#iconAlloyMed.png"))
  alloyTotalNumIcon:setLoc(-alloyTotalNumText._width / 2 - 20, 2)
  local credsBox = _pause_root:add(ui.NinePatch.new("glassyBoxWithHeader9p.lua", 196, 220))
  credsBox:setLoc(0, -device.ui_height / 2 + 130)
  local credsText = credsBox:add(ui.TextBox.new(_("MegaCreds"), FONT_MEDIUM, "ffffff", "center"))
  credsText:setColor(unpack(UI_CREDITS_TITLE_COLOR))
  credsText:setLoc(0, 75)
  local credsThisSystemText = credsBox:add(ui.TextBox.new(_("This System"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  credsThisSystemText:setColor(unpack(UI_COLOR_GRAY))
  credsThisSystemText:setLoc(0, 20)
  local credsThisSystemNumText = credsBox:add(ui.TextBox.new("" .. util.commasInNumbers(scores.creds or 0), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
  credsThisSystemNumText:setLoc(16, -10)
  local credsThisSystemNumIcon = credsThisSystemNumText:add(ui.Image.new("menuTemplateShared.atlas.png#iconCredsMed.png"))
  credsThisSystemNumIcon:setLoc(-credsThisSystemNumText._width / 2 - 20, 2)
  local credsTotalText = credsBox:add(ui.TextBox.new(_("Total"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  credsTotalText:setColor(unpack(UI_COLOR_GRAY))
  credsTotalText:setLoc(0, -50)
  local credsTotalNumText = credsBox:add(ui.TextBox.new("" .. util.commasInNumbers(profile.creds), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
  credsTotalNumText:setLoc(16, -80)
  local credsTotalNumIcon = credsTotalNumText:add(ui.Image.new("menuTemplateShared.atlas.png#iconCredsMed.png"))
  credsTotalNumIcon:setLoc(-credsTotalNumText._width / 2 - 20, 2)
  local xpBox = _pause_root:add(ui.NinePatch.new("glassyBoxWithHeader9p.lua", 196, 220))
  xpBox:setLoc(200, -device.ui_height / 2 + 130)
  local xpText = xpBox:add(ui.TextBox.new(_("XP"), FONT_MEDIUM, "ffffff", "center"))
  xpText:setColor(unpack(UI_CREDITS_TITLE_COLOR))
  xpText:setLoc(0, 75)
  local xpThisSystemText = xpBox:add(ui.TextBox.new(_("This System"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  xpThisSystemText:setColor(unpack(UI_COLOR_GRAY))
  xpThisSystemText:setLoc(0, 20)
  local xpThisSystemNumText = xpBox:add(ui.TextBox.new("" .. util.commasInNumbers((scores.xp or 0) .. " XP"), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
  xpThisSystemNumText:setLoc(0, -10)
  local xpTotalText = xpBox:add(ui.TextBox.new(string.format(_("LVL %02d"), profile.level), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  xpTotalText:setColor(unpack(UI_COLOR_GRAY))
  xpTotalText:setLoc(0, -50)
  local levelProgressFrame = xpBox:add(ui.Image.new("menuTemplateShared.atlas.png#levelProgressFrame.png"))
  levelProgressFrame:setLoc(0, -80)
  local xpDef = require("ShipData-ExpDef")
  local xpLevelDef = xpDef[profile.level]
  local xpToNextLevel, perc
  if xpLevelDef ~= nil then
    xpToNextLevel = xpLevelDef.xpToAdvance
  end
  if xpToNextLevel ~= nil and xpToNextLevel ~= 0 then
    perc = profile.xp / xpToNextLevel
  else
    perc = 1
  end
  local levelProgressFillbar = levelProgressFrame:add(ui.FillBar.new({110, 20}, "ffffff"))
  levelProgressFillbar:setFill(0, math.min(perc, 1))
end
local function _storemenu_refresh(exclude_store)
  local storeMenuBankArea = _menu_root.storeMenuBankArea
  local alloyText = _menu_root.alloyText
  local iconCreds = storeMenuBankArea.iconCreds
  local credsText = _menu_root.credsText
  local text = util.commasInNumbers(profile.alloy)
  alloyText:setString(text)
  local strLen = text:len()
  local xmin, ymin, xmax, ymax = alloyText:getStringBounds(1, strLen)
  local width1 = util.roundNumber(xmax - xmin)
  iconCreds:setLoc(-device.ui_width / 2 + 48 + width1 + 48, 6)
  text = util.commasInNumbers(profile.creds)
  credsText:setString(text)
  credsText:setLoc(48 + width1 + 64, 3)
  strLen = text:len()
  xmin, ymin, xmax, ymax = credsText:getStringBounds(1, strLen)
  local width2 = util.roundNumber(xmax - xmin)
  if not exclude_store then
    storeMenuBankArea:setLoc(-device.ui_width / 2 + 160 - 30 + width1 + width2, 0)
  else
    storeMenuBankArea:setLoc(-device.ui_width / 2 + 160 - 170 + width1 + width2, 0)
  end
end
local function _storemenu_close(move)
  if move == nil then
    move = {empty = true}
  end
  _menu_root.storeMenuBankArea.handleTouch = nil
  if move.store_menu then
    do
      local action = _menu_root.storeMenuBG:moveLoc(0, 70, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        if _menu_root then
          _menu_root:remove(_menu_root.storeMenuBG)
          _menu_root.storeMenuBG = nil
          _menu_root.storeMenuBankArea = nil
        end
      end)
    end
  else
    _menu_root:remove(_menu_root.storeMenuBG)
    _menu_root.storeMenuBG = nil
    _menu_root.storeMenuBankArea = nil
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
end
local function _storemenu_show(screen, exclude_store, move)
  if move == nil then
    move = {empty = true}
  end
  local storeMenuBG = _menu_root:add(ui.Image.new("menuTemplateShared.atlas.png#storeMenuBG.png"))
  if move.store_menu then
    if not profile.excludeAds then
      storeMenuBG:setLoc(0, device.ui_height / 2 - 234 + 70)
    else
      storeMenuBG:setLoc(0, device.ui_height / 2 - 134 + 70)
    end
    storeMenuBG:moveLoc(0, -70, 0.5, MOAIEaseType.EASE_IN)
  elseif not profile.excludeAds then
    storeMenuBG:setLoc(0, device.ui_height / 2 - 234)
  else
    storeMenuBG:setLoc(0, device.ui_height / 2 - 134)
  end
  _menu_root.storeMenuBG = storeMenuBG
  local storeMenuBGPickBox = storeMenuBG:add(ui.PickBox.new(device.ui_width, 60))
  storeMenuBGPickBox:setLoc(0, 8)
  local storeMenuBankArea = storeMenuBG:add(ui.Button.new("menuTemplateShared.atlas.png#storeMenuBankArea.png"))
  storeMenuBankArea._down:setColor(0.5, 0.5, 0.5)
  storeMenuBankArea.handleTouch = Button_handleTouch
  function storeMenuBankArea:onClick()
    if not screenAction:isActive() then
      if screen == "fleet" then
        table_insert(screenHistory, "fleet")
        fleet_close({
          forward = true,
          bottom_bar = true,
          store_filter = true
        })
      elseif screen == "shippurchase" then
        table_insert(screenHistory, "shippurchase")
        shippurchase_close({forward = true, bottom_bar = true})
      elseif screen == "shipupgrade" then
        table_insert(screenHistory, "shipupgrade")
        shipupgrade_close({forward = true, bottom_bar = true})
      elseif screen == "shipinfo" then
        table_insert(screenHistory, "shipinfo")
        shipinfo_close({forward = true})
      elseif screen == "perks" then
        table_insert(screenHistory, "perks")
        perks_close({
          forward = true,
          bottom_bar = true,
          perks_bar = true
        })
      end
      starbank_show({forward = true})
      soundmanager.onSFX("onPageSwipeForward")
    end
  end
  _menu_root.storeMenuBankArea = storeMenuBankArea
  local iconAlloy = storeMenuBG:add(ui.Image.new("menuTemplateShared.atlas.png#iconAlloy.png"))
  iconAlloy:setLoc(-device.ui_width / 2 + 32, 6)
  local alloyText = storeMenuBG:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "left", device.ui_width - 20, nil, true))
  alloyText:setLoc(50, 3)
  _menu_root.alloyText = alloyText
  local iconCreds = storeMenuBG:add(ui.Image.new("menuTemplateShared.atlas.png#iconCreds.png"))
  storeMenuBankArea.iconCreds = iconCreds
  local credsText = storeMenuBG:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "left", device.ui_width - 20, nil, true))
  _menu_root.credsText = credsText
  _storemenu_refresh(exclude_store)
  if not exclude_store then
    do
      local storeMenuBankBtn = storeMenuBankArea._up:add(ui.Image.new("menuTemplateShared.atlas.png#storeMenuBankButton.png"))
      storeMenuBankBtn:setLoc(85, 6)
      local storeText = storeMenuBankBtn:add(ui.TextBox.new(_("GET MORE"), FONT_SMALL_BOLD, "ffffff", "center"))
      storeText:setColor(0, 0, 0)
      storeText:setLoc(0, -3)
      local storeMenuBankBtn = storeMenuBankArea._down:add(ui.Image.new("menuTemplateShared.atlas.png#storeMenuBankButton.png"))
      storeMenuBankBtn:setLoc(85, 6)
      local storeText = storeMenuBankBtn:add(ui.TextBox.new(_("GET MORE"), FONT_SMALL_BOLD, "ffffff", "center"))
      storeText:setColor(0, 0, 0)
      storeText:setLoc(0, -3)
    end
  else
    storeMenuBankArea.handleTouch = nil
  end
  local levelText = storeMenuBG:add(ui.TextBox.new(string.format(_("LVL %02d"), profile.level), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  levelText:setLoc(device.ui_width / 2 - 175, 3)
  _menu_root.levelText = levelText
  local levelProgressFrame = storeMenuBG:add(ui.Image.new("menuTemplateShared.atlas.png#levelProgressFrame.png"))
  levelProgressFrame:setLoc(device.ui_width / 2 - 70, 6)
  local xpDef = require("ShipData-ExpDef")
  local xpLevelDef = xpDef[profile.level]
  local xpToNextLevel, perc
  if xpLevelDef ~= nil then
    xpToNextLevel = xpLevelDef.xpToAdvance
  end
  if xpToNextLevel ~= nil and xpToNextLevel ~= 0 then
    perc = profile.xp / xpToNextLevel
  else
    perc = 1
  end
  local levelProgressFillbar = levelProgressFrame:add(ui.FillBar.new({110, 20}, "ffffff"))
  levelProgressFillbar:setFill(0, math.min(perc, 1))
  _menu_root.levelProgressFillbar = levelProgressFillbar
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
end
local function _starbank_items_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  local submenu_height = device.ui_height - 100 - 60
  local submenu_y = -80
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local items_group = self.items_group
  if eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    if 0 < math.max(items_group.numItems * items_group.item_height - submenu_height, 0) then
      if not exclude_capture then
        ui.capture(self)
      end
      scrolling = true
      lastX = x
      lastY = y
      diffX = 0
      diffY = 0
      if scrollbar == nil then
        scrollbar = ui.Group.new()
        do
          local scrollbar_fill = scrollbar:add(ui.Image.new("scrollbar_fill.png"))
          scrollbar_fill:setScl(1, 3.5)
          scrollbar.fill = scrollbar_fill
          local scrollbar_top = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_top:setLoc(0, 36)
          scrollbar.top = scrollbar_top
          local scrollbar_bot = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_bot:setLoc(0, -36)
          scrollbar_bot:setScl(1, -1)
          scrollbar.bot = scrollbar_bot
          local groupX, groupY = items_group:getLoc()
          local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
          scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70))
          scrollbar.fill:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.top:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.bot:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          self:add(scrollbar)
        end
      else
        if scrollbar_fadeOutActions.fill ~= nil and scrollbar_fadeOutActions.fill:isActive() then
          scrollbar_fadeOutActions.fill:stop()
          scrollbar_fadeOutActions.top:stop()
          scrollbar_fadeOutActions.bot:stop()
        end
        scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
      end
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
  elseif eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    if not exclude_capture then
      ui.capture(nil)
    end
    scrolling = false
    if scrollbar ~= nil and scrollbar.velocityY ~= nil then
      scrollbar.velocityY = scrollbar.velocityY + diffY
    elseif scrollbar ~= nil then
      scrollbar.velocityY = diffY
    end
    if scrollAction == nil then
      scrollAction = uiAS:wrap(function(dt)
        if scrollbar ~= nil then
          do
            local groupX, groupY = items_group:getLoc()
            local newY = util.clamp(groupY - scrollbar.velocityY, 0, math.max(items_group.numItems * items_group.item_height - submenu_height, 0))
            items_group:setLoc(0, util.roundNumber(newY))
            local groupX, groupY = items_group:getLoc()
            local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
            scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70))
            scrollbar.velocityY = scrollbar.velocityY + scrollbar.velocityY * -1 * dt * 0.03 * device.dpi
            if not scrolling and abs(scrollbar.velocityY) < 0.5 then
              scrollAction:stop()
              scrollAction = nil
            end
          end
        else
          scrollAction:stop()
          scrollAction = nil
        end
      end, function()
        if not scrolling and scrollbar ~= nil then
          if scrollbar_fadeInActions.fill ~= nil and scrollbar_fadeInActions.fill:isActive() then
            scrollbar_fadeInActions.fill:stop()
            scrollbar_fadeInActions.top:stop()
            scrollbar_fadeInActions.bot:stop()
          end
          scrollbar_fadeOutActions.fill = scrollbar.fill:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.top = scrollbar.top:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.bot = scrollbar.bot:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.fill:setListener(MOAITimer.EVENT_STOP, function()
            if not scrolling and self ~= nil then
              self:remove(scrollbar)
              scrollbar = nil
            end
          end)
        end
      end)
    end
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE and scrolling then
    diffY = lastY - y
    local groupX, groupY = items_group:getLoc()
    local newY = util.clamp(groupY - diffY, 0, math.max(items_group.numItems * items_group.item_height - submenu_height, 0))
    items_group:setLoc(0, util.roundNumber(newY))
    if scrollbar ~= nil then
      local groupX, groupY = items_group:getLoc()
      local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
      scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70))
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
    lastX = x
    lastY = y
  end
  return true
end
local function _starbank_item_purchase(def, priceType, price, restore)
  local prodId = def.itemId
  local amount
  amount = tonumber(prodId:match("^alloy%.(%d+)$"))
  if amount ~= nil then
    if priceType ~= "$" then
      profile_currency_txn(priceType, -price, "Purchase: " .. prodId, true)
    end
    profile_currency_txn("alloy", amount, "Purchase: " .. prodId, true)
    _storemenu_refresh(true)
    return
  end
  amount = tonumber(prodId:match("^creds%.(%d+)$"))
  if amount ~= nil then
    if priceType ~= "$" then
      profile_currency_txn(priceType, -price, "Purchase: " .. prodId, true)
    end
    profile_currency_txn("creds", amount, "Purchase: " .. prodId, true)
    _storemenu_refresh(true)
    popups.show("on_cred_purchase")
    return
  end
  amount = tonumber(prodId:match("^ads%.(%d+)$"))
  if amount ~= nil then
    if not profile.excludeAds then
      if priceType ~= "$" then
        profile_currency_txn(priceType, -price, "Purchase: " .. prodId, true)
      end
      profile.excludeAds = true
      profile:save()
      if SixWaves and not restore then
        SixWaves.hideAdBanner()
      end
      if def.once then
        profile.purchases[prodId] = true
        profile:save()
      end
      if not restore then
        local tempHistory = {}
        for i, v in ipairs(screenHistory) do
          table_insert(tempHistory, v)
        end
        menu_close()
        menu_show("starbank")
        for i, v in ipairs(tempHistory) do
          table_insert(screenHistory, v)
        end
        tempHistory = nil
      end
    end
    return
  end
end
function _starbank_generate_store_id(sku)
  local newSku = sku
  if device.os == device.OS_ANDROID then
    if device.platform == device.PLATFORM_ANDROID_AMAZON then
      newSku = string.format("%s.%s.%s", ANDROID_PRODUCT_ID, AMAZON_STORE_PREFIX, sku)
    elseif sku == "creds.110" then
      newSku = string.format("%s.%s.%s_new", ANDROID_PRODUCT_ID, GOOGLE_STORE_PREFIX, sku)
    else
      newSku = string.format("%s.%s.%s", ANDROID_PRODUCT_ID, GOOGLE_STORE_PREFIX, sku)
    end
  elseif device.os == device.OS_IOS then
    newSku = string.format("%s.%s", ACU_BUNDLE_ID, sku)
  end
  return newSku
end
function _starbank_generate_local_id(sku)
  local newSku = sku
  if device.os == device.OS_IOS then
    local pattern = string.format("%s.(.*)", ACU_BUNDLE_ID)
    newSku = sku:match(pattern)
  end
  print("New sku is: ", newSku)
  return newSku
end
function _starbank_shop_restore(result, id, txn)
  local starbank_defs = require("ShipData-Starbank")
  local localId = _starbank_generate_local_id(id)
  local def
  for i, d in ipairs(starbank_defs) do
    if d.itemId == localId then
      def = d
      break
    end
  end
  _starbank_item_purchase(def, def.priceType, def.price, true)
end
local function _starbank_shop_purchase(def, priceType, price)
  local prodId = def.itemId
  local levelid = profile_get_level_id()
  analytics.gameShopPurchaseSuccess(prodId, priceType, price, levelid)
  if SixWaves then
    SixWaves.trackInGameItemPurchase(prodId, {
      price = price,
      category = "shop",
      priceType = priceType,
      leveid = leveid
    })
  end
  _starbank_item_purchase(def, priceType, price)
  soundmanager.onSFX("onPurchase")
end
local function _starbank_iap_complete(purchased, def, txn, priceType, price)
  local prodId = def.itemId
  local levelid = profile_get_level_id()
  if purchased then
    if txn.transactionState == storeiap.TXN_PURCHASED then
      analytics.storePurchaseSuccess(prodId, priceType, price, levelid)
      if SixWaves then
        local locale
        if type(txn) == "table" then
          locale = txn.priceLocale
        end
        local storeId = _starbank_generate_store_id(prodId)
        SixWaves.trackPurchaseEvent(storeId, price, locale)
      end
      soundmanager.onSFX("onPurchase")
    end
    _starbank_item_purchase(def, priceType, price)
    do
      local errstr = "Unhandled item purchase (" .. prodId .. ") for " .. tostring(device.udid)
      analytics.error("UNKNOWN_ITEM", errstr)
      _error(errstr)
      return
    end
  elseif txn.transactionState == storeiap.TXN_FAILED then
    analytics.storePurchaseFailed(prodId, tostring(txn.error))
  elseif txn.transactionState == storeiap.TXN_CANCELLED then
    analytics.storePurchaseCancel(prodId, priceType, price, levelid)
  else
    _error("Unknown transaction failure state: " .. tostring(txn.transactionState))
  end
end
local function _starbank_create_item(def, priceType, price, fromPopup)
  local itemId = def.itemId
  local icon = def.icon
  local name = def.name
  local description = def.description
  if def.once and profile.purchases[itemId] then
    return
  end
  local item = ui.Group.new()
  local itemBG = item:add(ui.PickBox.new(device.ui_width, 90, "00000033"))
  itemBG.handleTouch = nil
  local itemIcon = item:add(ui.Image.new(icon))
  itemIcon:setLoc(-device.ui_width / 2 + 65, 0)
  if name ~= "" then
    local nameText = item:add(ui.TextBox.new(_(name), FONT_MEDIUM_BOLD, "ffffff", "left", device.ui_width - 20, nil, true))
    nameText:setLoc(110, 20)
  end
  if description ~= "" then
    local descriptionText = item:add(ui.TextBox.new(_(description), FONT_MEDIUM, "ffffff", "left", device.ui_width - 20, nil, true))
    descriptionText:setColor(unpack(UI_COLOR_GRAY))
    descriptionText:setLoc(110, -20)
  end
  local postbuyfunc
  if fromPopup then
    function postbuyfunc()
      if #screenHistory > 0 then
        starbank_close({back = true})
        do
          local screen = table_remove(screenHistory)
          if screen == "fleet" then
            fleet_show({
              back = true,
              bottom_bar = true,
              store_filter = true
            })
          elseif screen == "shippurchase" then
            shippurchase_show({back = true, bottom_bar = true}, shipInfoDef)
          elseif screen == "shipupgrade" then
            shipupgrade_show({back = true, bottom_bar = true}, shipInfoDef)
          elseif screen == "shipinfo" then
            shipinfo_show({back = true}, shipInfoDef)
          elseif screen == "perks" then
            perks_show({
              back = true,
              bottom_bar = true,
              perks_bar = true
            })
          end
        end
      else
        menu_close()
      end
    end
  end
  local buyBtn = item:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
  buyBtn._up:setColor(unpack(UI_COLOR_GREEN))
  buyBtn._down:setColor(unpack(UI_COLOR_GREEN_DARKEN))
  buyBtn:setLoc(device.ui_width / 2 - 95, 0)
  buyBtn.handleTouch = Button_handleTouch
  function buyBtn:onClick()
    if not screenAction:isActive() then
      if priceType ~= "$" then
        if profile[priceType] < price then
          return
        end
        _starbank_shop_purchase(def, priceType, price)
        if postbuyfunc then
          postbuyfunc()
        end
      elseif DEBUG_STORE then
        _starbank_iap_complete(true, def, {
          transactionState = storeiap.TXN_PURCHASED
        }, priceType, price)
        if postbuyfunc then
          postbuyfunc()
        end
      else
        local storeId = _starbank_generate_store_id(def.itemId)
        storeiap.buy(storeId, function(result, id, txn)
          _starbank_iap_complete(result, def, txn, priceType, price)
          if postbuyfunc then
            postbuyfunc()
          end
        end)
      end
    end
  end
  if priceType == "$" then
    do
      local text = string.format("$%.2f", price)
      local buyText = buyBtn._up:add(ui.TextBox.new(text, FONT_MEDIUM_BOLD, "000000", "center"))
      buyText:setColor(0, 0, 0)
      buyText:setLoc(0, -2)
      local buyText = buyBtn._down:add(ui.TextBox.new(text, FONT_MEDIUM_BOLD, "000000", "center"))
      buyText:setColor(0, 0, 0)
      buyText:setLoc(0, -2)
    end
  else
    local buyIcon = buyBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. priceType:gsub("^%l", string.upper) .. "Med.png"))
    buyIcon:setLoc(-32, 0)
    local buyText = buyBtn._up:add(ui.TextBox.new(util.commasInNumbers(price), FONT_MEDIUM_BOLD, "000000", "center"))
    buyText:setColor(0, 0, 0)
    buyText:setLoc(16, -2)
    local buyIcon = buyBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. priceType:gsub("^%l", string.upper) .. "Med.png"))
    buyIcon:setLoc(-32, 0)
    local buyText = buyBtn._down:add(ui.TextBox.new(util.commasInNumbers(price), FONT_MEDIUM_BOLD, "000000", "center"))
    buyText:setColor(0, 0, 0)
    buyText:setLoc(16, -2)
  end
  local topBorder = item:add(ui.Image.new("menuTemplate.atlas.png#listItemTop.png"))
  topBorder:setScl(device.ui_width / 4, 1)
  topBorder:setLoc(0, 44)
  local bottomBorder = item:add(ui.Image.new("menuTemplate.atlas.png#listItemBottom.png"))
  bottomBorder:setScl(device.ui_width / 4, 1)
  bottomBorder:setLoc(0, -44)
  return item
end
function starbank_close(move)
  if move == nil then
    move = {empty = true}
  end
  _menu_root:remove(_menu_root.topBarBG)
  _menu_root.topBarBG = nil
  _storemenu_close()
  if move.forward then
    do
      local action = _starbank_root:seekLoc(-device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_starbank_root)
        _starbank_root = nil
      end)
    end
  elseif move.back then
    do
      local action = _starbank_root:seekLoc(device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_starbank_root)
        _starbank_root = nil
      end)
    end
  else
    submenuLayer:remove(_starbank_root)
    _starbank_root = nil
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  if scrollbar and scrollAction ~= nil then
    scrollAction:stop()
    scrollAction = nil
  end
  scrollbar = nil
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  curScreen = nil
end
function starbank_show(move, filter, fromPopup, referer)
  _debug("Starbank 1")
  if move == nil then
    move = {empty = true}
  end
  local submenu_height = device.ui_height - 100 - 60
  local submenu_y = -80
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  _debug("Starbank 2")
  _storemenu_show("starbank", true, nil, {
    store_menu = move.store_menu
  })
  local topBarBG = _menu_root:add(ui.Image.new("menuTopBars.atlas.png#topBarStarbank.png"))
  if not profile.excludeAds then
    topBarBG:setLoc(0, device.ui_height / 2 - 150)
  else
    topBarBG:setLoc(0, device.ui_height / 2 - 50)
  end
  _menu_root.topBarBG = topBarBG
  _debug("Starbank 3")
  local topBarBGPickBox = topBarBG:add(ui.PickBox.new(device.ui_width, 100))
  local topBarText = topBarBG:add(ui.TextBox.new(_("Starbank"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  topBarText:setLoc(0, -6)
  local backBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconBack.png"))
  backBtn._down:setColor(0.5, 0.5, 0.5)
  backBtn:setLoc(-device.ui_width / 2 + 42, 0)
  backBtn.handleTouch = Button_handleTouch
  local function backBtn_onClick()
    if not screenAction:isActive() then
      if #screenHistory > 0 then
        starbank_close({back = true})
        do
          local screen = table_remove(screenHistory)
          if screen == "fleet" then
            fleet_show({
              back = true,
              bottom_bar = true,
              store_filter = true
            })
          elseif screen == "shippurchase" then
            shippurchase_show({back = true, bottom_bar = true}, shipInfoDef)
          elseif screen == "shipupgrade" then
            shipupgrade_show({back = true, bottom_bar = true}, shipInfoDef)
          elseif screen == "shipinfo" then
            shipinfo_show({back = true}, shipInfoDef)
          elseif screen == "perks" then
            perks_show({
              back = true,
              bottom_bar = true,
              perks_bar = true
            })
          end
        end
      else
        menu_close()
      end
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  _debug("Starbank 4")
  backBtn.onClick = backBtn_onClick
  if device.os == device.OS_ANDROID then
    local function callback()
      backBtn_onClick()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  if #screenHistory > 0 and menuMode ~= "ingame" then
    local menuBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconHome.png"))
    menuBtn._down:setColor(0.5, 0.5, 0.5)
    menuBtn:setLoc(device.ui_width / 2 - 42, 0)
    menuBtn.handleTouch = Button_handleTouch
    function menuBtn:onClick()
      menu_close()
      mainmenu_show()
    end
  end
  _debug("Starbank 5")
  _starbank_root = ui.Group.new()
  if device.os ~= device.OS_ANDROID then
    analytics.storeVisited(referer)
  end
  local bg = _starbank_root:add(ui.PickBox.new(device.ui_width, submenu_height))
  bg:setLoc(0, submenu_y)
  bg.handleTouch = _starbank_items_handleTouch
  local items_group = _starbank_root:add(ui.Group.new())
  bg.items_group = items_group
  local starbank_defs = require("ShipData-Starbank")
  local item_defs = {}
  if filter ~= nil then
    filter = "^" .. filter .. "%."
  end
  _debug("Starbank 6")
  local items = {}
  local y = submenu_height / 2 + submenu_y - 44
  for i, d in ipairs(starbank_defs) do
    if not filter or d.itemId:find(filter) == 1 then
      local priceType = d.priceType
      local price = d.price
      local item = _starbank_create_item(d, priceType, price, fromPopup)
      if item then
        items_group:add(item)
        item:setLoc(0, y)
        y = y - 90
        table_insert(items, item)
      end
    end
  end
  items_group.numItems = #items
  items_group.item_height = 90
  _starbank_root.items = items
  if move.forward then
    _starbank_root:setLoc(device.ui_width * 2, 0)
    _starbank_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  elseif move.back then
    _starbank_root:setLoc(-device.ui_width * 2, 0)
    _starbank_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  _debug("Starbank 7")
  submenuLayer:add(_starbank_root)
  popups.show("on_show_starbank", true)
  _debug("Starbank 8")
  curScreen = "starbank"
end
local function _perks_items_handleTouch(self, eventType, touchIdx, x, y, tapCount, exclude_capture)
  local submenu_height = device.ui_height - 100 - 210 - 60
  local submenu_y = 25
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local items_group = self.items_group
  if eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    if 0 < math.max(items_group.numItems * items_group.item_height - submenu_height, 0) then
      if not exclude_capture then
        ui.capture(self)
      end
      scrolling = true
      lastX = x
      lastY = y
      diffX = 0
      diffY = 0
      if scrollbar == nil then
        scrollbar = ui.Group.new()
        do
          local scrollbar_fill = scrollbar:add(ui.Image.new("scrollbar_fill.png"))
          scrollbar_fill:setScl(1, 3.5)
          scrollbar.fill = scrollbar_fill
          local scrollbar_top = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_top:setLoc(0, 36)
          scrollbar.top = scrollbar_top
          local scrollbar_bot = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_bot:setLoc(0, -36)
          scrollbar_bot:setScl(1, -1)
          scrollbar.bot = scrollbar_bot
          local groupX, groupY = items_group:getLoc()
          local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
          scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70) + submenu_y)
          scrollbar.fill:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.top:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.bot:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          _perks_root:add(scrollbar)
        end
      else
        if scrollbar_fadeOutActions.fill ~= nil and scrollbar_fadeOutActions.fill:isActive() then
          scrollbar_fadeOutActions.fill:stop()
          scrollbar_fadeOutActions.top:stop()
          scrollbar_fadeOutActions.bot:stop()
        end
        scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
      end
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
  elseif eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    if not exclude_capture then
      ui.capture(nil)
    end
    scrolling = false
    if scrollbar ~= nil and scrollbar.velocityY ~= nil then
      scrollbar.velocityY = scrollbar.velocityY + diffY
    elseif scrollbar ~= nil then
      scrollbar.velocityY = diffY
    end
    if scrollAction == nil then
      scrollAction = uiAS:wrap(function(dt)
        if scrollbar ~= nil then
          do
            local groupX, groupY = items_group:getLoc()
            local newY = util.clamp(groupY - scrollbar.velocityY, 0, math.max(items_group.numItems * items_group.item_height - submenu_height, 0))
            items_group:setLoc(0, util.roundNumber(newY))
            local groupX, groupY = items_group:getLoc()
            local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
            scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70) + submenu_y)
            scrollbar.velocityY = scrollbar.velocityY + scrollbar.velocityY * -1 * dt * 0.03 * device.dpi
            if not scrolling and abs(scrollbar.velocityY) < 0.5 then
              scrollAction:stop()
              scrollAction = nil
            end
          end
        else
          scrollAction:stop()
          scrollAction = nil
        end
      end, function()
        if not scrolling and scrollbar ~= nil then
          if scrollbar_fadeInActions.fill ~= nil and scrollbar_fadeInActions.fill:isActive() then
            scrollbar_fadeInActions.fill:stop()
            scrollbar_fadeInActions.top:stop()
            scrollbar_fadeInActions.bot:stop()
          end
          scrollbar_fadeOutActions.fill = scrollbar.fill:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.top = scrollbar.top:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.bot = scrollbar.bot:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.fill:setListener(MOAITimer.EVENT_STOP, function()
            if not scrolling and _perks_root ~= nil then
              _perks_root:remove(scrollbar)
              scrollbar = nil
            end
          end)
        end
      end)
    end
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE and scrolling then
    diffY = lastY - y
    local groupX, groupY = items_group:getLoc()
    local newY = util.clamp(groupY - diffY, 0, math.max(items_group.numItems * items_group.item_height - submenu_height, 0))
    items_group:setLoc(0, util.roundNumber(newY))
    if scrollbar ~= nil then
      local groupX, groupY = items_group:getLoc()
      local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
      scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70) + submenu_y)
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
    lastX = x
    lastY = y
  end
  return true
end
local function _perks_item_button_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  if eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    ui.capture(nil)
    do
      local doclick
      doclick = self.currentPageName == "down"
      self:showPage("up")
      if not doclick and self._isdown and buttonAction ~= nil and buttonAction.t < 0.2 then
        doclick = true
      end
      if buttonAction ~= nil then
        buttonAction:stop()
        buttonAction = nil
      end
      self._isdown = nil
      if doclick then
        self:onClick(tapCount)
      end
    end
  elseif eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    self._isdown = true
    ui.capture(self)
    startX, startY = self:modelToWorld(x, y)
    do
      local action
      action = uiAS:run(function(dt, t)
        if buttonAction == nil then
          if action ~= nil then
            action:stop()
          end
          action = nil
        end
        buttonAction.t = t
        if self._isdown and self.currentPageName == "up" and t > 0.2 then
          self:showPage("down")
        elseif t > 1 then
          self:showPage("up")
          self._isdown = nil
          buttonAction:stop()
          buttonAction = nil
        end
      end)
      buttonAction = action
      buttonAction.t = 0
    end
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE then
    if self._isdown and not ui.treeCheck(x, y, self) then
      self:showPage("up")
      self._isdown = nil
      if buttonAction ~= nil then
        buttonAction:stop()
        buttonAction = nil
      end
    end
    local wx, wy = self:modelToWorld(x, y)
    if self._isdown and abs(startY - wy) > 25 then
      self:showPage("up")
      self._isdown = nil
      if buttonAction ~= nil then
        buttonAction:stop()
        buttonAction = nil
      end
    end
  end
  local wx, wy = self:modelToWorld(x, y)
  local mx, my = _perks_root.bg:worldToModel(wx, wy)
  _perks_items_handleTouch(_perks_root.bg, eventType, touchIdx, mx, my, tapCount, true)
  return true
end
local _perks_refresh, _perks_item_inactive_onClick, _perks_item_active_onClick
function _perks_item_inactive_onClick(self)
  if #active_perks < 3 then
    soundmanager.onSFX("onPerkSelect")
    table_insert(active_perks, self.id)
    _perks_refresh()
    self._up:setColor("00000077")
    self._down:setColor(color.toHex(0.3, 0.3, 0.3, 0.3))
    self.onClick = _perks_item_active_onClick
  end
end
function _perks_item_active_onClick(self)
  for i, v in ipairs(active_perks) do
    if v == self.id then
      soundmanager.onClick()
      local perk = table_remove(active_perks, i)
      _perks_refresh()
      self._up:setColor("00000033")
      self._down:setColor("00000077")
      self.onClick = _perks_item_inactive_onClick
      break
    end
  end
end
local function _perks_create_item_galaxy(def)
  if def.systemLevelUnlock ~= nil then
    local lastCompletedGalaxy, lastCompletedSystem, lastCompletedIndex = _get_last_completed_galaxy_system()
    if lastCompletedIndex < def.systemLevelUnlock then
      return false
    end
  end
  local id = def.id
  local icon = def.icon
  local name = def.title
  local description = def.text
  local item = ui.Group.new()
  local itemBG = item:add(ui.Button.new(ui.PickBox.new(device.ui_width, 90, "00000033"), ui.PickBox.new(device.ui_width, 90, "00000077")))
  itemBG._up.handleTouch = nil
  itemBG._down.handleTouch = nil
  itemBG.handleTouch = _perks_item_button_handleTouch
  local active
  for i, v in ipairs(active_perks) do
    if v == id then
      active = true
      break
    end
  end
  if not active then
    itemBG.onClick = _perks_item_inactive_onClick
  else
    itemBG._up:setColor("00000077")
    itemBG._down:setColor(color.toHex(0.3, 0.3, 0.3, 0.3))
    itemBG.onClick = _perks_item_active_onClick
  end
  itemBG.id = id
  item.itemBG = itemBG
  local iconPowerup = item:add(ui.Image.new(icon))
  iconPowerup:setLoc(-device.ui_width / 2 + 62, 0)
  local nameText = item:add(ui.TextBox.new(_(name), FONT_MEDIUM_BOLD, "ffffff", "left", device.ui_width - 20, nil, true))
  nameText:setLoc(105, 20)
  local descriptionText = item:add(ui.TextBox.new(_(description), FONT_MEDIUM, "ffffff", "left", device.ui_width - 20, nil, true))
  descriptionText:setColor(0.73, 0.73, 0.73)
  descriptionText:setLoc(105, -20)
  local topBorder = item:add(ui.Image.new("menuTemplate.atlas.png#listItemTop.png"))
  topBorder:setScl(device.ui_width / 4, 1)
  topBorder:setLoc(0, 44)
  local bottomBorder = item:add(ui.Image.new("menuTemplate.atlas.png#listItemBottom.png"))
  bottomBorder:setScl(device.ui_width / 4, 1)
  bottomBorder:setLoc(0, -44)
  item.id = id
  return item
end
local function _perks_create_item_survival(def)
  if def.systemLevelUnlock ~= nil then
    local lastCompletedGalaxy, lastCompletedSystem, lastCompletedIndex = _get_last_completed_galaxy_system()
    if lastCompletedIndex < def.systemLevelUnlock then
      return false
    end
  end
  local id = def.id
  local icon = def.icon
  local name = def.title
  local duration = def.duration
  local description = def.text
  local cost = def.cost
  local item = ui.Group.new()
  local itemBG = item:add(ui.Button.new(ui.PickBox.new(device.ui_width, 120, "00000033"), ui.PickBox.new(device.ui_width, 120, "00000077")))
  itemBG._up.handleTouch = nil
  itemBG._down.handleTouch = nil
  itemBG.handleTouch = _perks_item_button_handleTouch
  local active
  for i, v in ipairs(active_perks) do
    if v == id then
      active = true
      break
    end
  end
  if not active then
    itemBG.onClick = _perks_item_inactive_onClick
  else
    itemBG._up:setColor("00000077")
    itemBG._down:setColor(color.toHex(0.3, 0.3, 0.3, 0.3))
    itemBG.onClick = _perks_item_active_onClick
  end
  itemBG.id = id
  item.itemBG = itemBG
  local iconPowerup = item:add(ui.Image.new(icon))
  iconPowerup:setLoc(-device.ui_width / 2 + 62, 0)
  local nameText = item:add(ui.TextBox.new(_(name), FONT_MEDIUM_BOLD, "ffffff", "left", device.ui_width - 20, nil, true))
  nameText:setLoc(105, 35)
  local durationText = item:add(ui.TextBox.new(string.format(_("Duration: <c:e5b637>%d minutes"), duration), FONT_MEDIUM, "ffffff", "left", device.ui_width - 20, nil, true))
  durationText:setLoc(105, 0)
  local descriptionText = item:add(ui.TextBox.new(_(description), FONT_MEDIUM, "ffffff", "left", device.ui_width - 20, nil, true))
  descriptionText:setColor(0.73, 0.73, 0.73)
  descriptionText:setLoc(105, -35)
  local costBox = item:add(ui.NinePatch.new("boxPlainLight9p.lua", 120, 60))
  costBox:setLoc(device.ui_width / 2 - 90, 20)
  local costIcon = costBox:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. PERKS_RESOURCE_TYPE:gsub("^%l", string.upper) .. ".png"))
  costIcon:setLoc(-20, 0)
  local costText = costBox:add(ui.TextBox.new("" .. cost, FONT_MEDIUM_BOLD, "ffffff", "left", 50, nil, true))
  costText:setLoc(35, -2)
  local topBorder = item:add(ui.Image.new("menuTemplate.atlas.png#listItemTop.png"))
  topBorder:setScl(device.ui_width / 4, 1)
  topBorder:setLoc(0, 59)
  local bottomBorder = item:add(ui.Image.new("menuTemplate.atlas.png#listItemBottom.png"))
  bottomBorder:setScl(device.ui_width / 4, 1)
  bottomBorder:setLoc(0, -59)
  item.id = id
  return item
end
local function perksNavSlotCancel_onClick(self)
  local perk = table_remove(active_perks, self.num)
  _perks_refresh()
  for i, v in ipairs(_perks_root.items) do
    if v.id == perk then
      v.itemBG._up:setColor("00000033")
      v.itemBG._down:setColor("00000077")
      v.itemBG.onClick = _perks_item_inactive_onClick
      break
    end
  end
end
function _perks_refresh()
  local PerkDef = require("ShipData-Perks")
  local price = 0
  local perksNavBG = _menu_root.perksNavBG
  local perksCostText = perksNavBG.perksCostText
  local perksNavSlot1 = perksNavBG.perksNavSlot1
  local perksNavSlot1Icon = perksNavSlot1.icon
  local perksNavSlot1Cancel = perksNavSlot1.cancel
  local perksNavSlot2 = perksNavBG.perksNavSlot2
  local perksNavSlot2Icon = perksNavSlot2.icon
  local perksNavSlot2Cancel = perksNavSlot2.cancel
  local perksNavSlot3 = perksNavBG.perksNavSlot3
  local perksNavSlot3Icon = perksNavSlot3.icon
  local perksNavSlot3Cancel = perksNavSlot3.cancel
  if #active_perks == 0 then
    perksNavSlot1Icon:setImage("menuTemplate.atlas.png#perksNavSlot.png")
    perksNavSlot1Icon:setColor(1, 1, 1)
    perksNavSlot2Icon:setImage("menuTemplate.atlas.png#perksNavSlot.png")
    perksNavSlot2Icon:setColor(1, 1, 1)
    perksNavSlot3Icon:setImage("menuTemplate.atlas.png#perksNavSlot.png")
    perksNavSlot3Icon:setColor(1, 1, 1)
    if perksNavSlot1Cancel ~= nil then
      perksNavSlot1:remove(perksNavSlot1Cancel)
      perksNavSlot1.cancel = nil
    end
    if perksNavSlot2Cancel ~= nil then
      perksNavSlot2:remove(perksNavSlot2Cancel)
      perksNavSlot2.cancel = nil
    end
    if perksNavSlot3Cancel ~= nil then
      perksNavSlot3:remove(perksNavSlot3Cancel)
      perksNavSlot3.cancel = nil
    end
    if gameMode == "survival" then
      perksNavSlot1.costIcon:setColor(1, 1, 1, 1)
      perksNavSlot1.text:setColor(1, 1, 1, 1)
      perksNavSlot1.text:setString("0")
      perksNavSlot1.activeText:setColor(0, 0, 0, 0)
      perksNavSlot2.costIcon:setColor(1, 1, 1, 1)
      perksNavSlot2.text:setColor(1, 1, 1, 1)
      perksNavSlot2.text:setString("0")
      perksNavSlot2.activeText:setColor(0, 0, 0, 0)
      perksNavSlot3.costIcon:setColor(1, 1, 1, 1)
      perksNavSlot3.text:setColor(1, 1, 1, 1)
      perksNavSlot3.text:setString("0")
      perksNavSlot3.activeText:setColor(0, 0, 0, 0)
    end
    price = 0
  elseif #active_perks == 1 then
    perksNavSlot1Icon:setImage(PerkDef[active_perks[1]].icon)
    perksNavSlot1Icon:setColor(unpack(UI_COLOR_GOLD))
    perksNavSlot2Icon:setImage("menuTemplate.atlas.png#perksNavSlot.png")
    perksNavSlot2Icon:setColor(1, 1, 1)
    perksNavSlot3Icon:setImage("menuTemplate.atlas.png#perksNavSlot.png")
    perksNavSlot3Icon:setColor(1, 1, 1)
    if perksNavSlot1Cancel == nil then
      local perksNavSlot1Cancel = perksNavSlot1:add(ui.Button.new("menuTemplate.atlas.png#perksNavSlotCancel.png"))
      perksNavSlot1Cancel._down:setColor(0.5, 0.5, 0.5)
      perksNavSlot1Cancel:setLoc(-32, 32)
      perksNavSlot1Cancel.handleTouch = Button_handleTouch
      perksNavSlot1Cancel.onClick = perksNavSlotCancel_onClick
      perksNavSlot1Cancel.num = 1
      perksNavSlot1.cancel = perksNavSlot1Cancel
      local perksNavSlot1PickBox = perksNavSlot1Cancel:add(ui.PickBox.new(86, 86))
      perksNavSlot1PickBox:setLoc(32, -32)
      perksNavSlot1PickBox.handleTouch = nil
    end
    if perksNavSlot2Cancel ~= nil then
      perksNavSlot2:remove(perksNavSlot2Cancel)
      perksNavSlot2.cancel = nil
    end
    if perksNavSlot3Cancel ~= nil then
      perksNavSlot3:remove(perksNavSlot3Cancel)
      perksNavSlot3.cancel = nil
    end
    if gameMode == "galaxy" then
      price = PERKS_1_COST
    elseif gameMode == "survival" then
      if not perks_inuse[active_perks[1]] then
        perksNavSlot1.costIcon:setColor(1, 1, 1, 1)
        perksNavSlot1.text:setColor(1, 1, 1, 1)
        perksNavSlot1.text:setString("" .. PerkDef[active_perks[1]].cost)
        perksNavSlot1.activeText:setColor(0, 0, 0, 0)
        price = price + PerkDef[active_perks[1]].cost
      else
        perksNavSlot1.costIcon:setColor(0, 0, 0, 0)
        perksNavSlot1.text:setColor(0, 0, 0, 0)
        perksNavSlot1.activeText:setColor(1, 1, 1, 1)
      end
      perksNavSlot2.costIcon:setColor(1, 1, 1, 1)
      perksNavSlot2.text:setColor(1, 1, 1, 1)
      perksNavSlot2.text:setString("0")
      perksNavSlot2.activeText:setColor(0, 0, 0, 0)
      perksNavSlot3.costIcon:setColor(1, 1, 1, 1)
      perksNavSlot3.text:setColor(1, 1, 1, 1)
      perksNavSlot3.text:setString("0")
      perksNavSlot3.activeText:setColor(0, 0, 0, 0)
    end
  elseif #active_perks == 2 then
    perksNavSlot1Icon:setImage(PerkDef[active_perks[1]].icon)
    perksNavSlot1Icon:setColor(unpack(UI_COLOR_GOLD))
    perksNavSlot2Icon:setImage(PerkDef[active_perks[2]].icon)
    perksNavSlot2Icon:setColor(unpack(UI_COLOR_GOLD))
    perksNavSlot3Icon:setImage("menuTemplate.atlas.png#perksNavSlot.png")
    perksNavSlot3Icon:setColor(1, 1, 1)
    if perksNavSlot1Cancel == nil then
      local perksNavSlot1Cancel = perksNavSlot1:add(ui.Button.new("menuTemplate.atlas.png#perksNavSlotCancel.png"))
      perksNavSlot1Cancel._down:setColor(0.5, 0.5, 0.5)
      perksNavSlot1Cancel:setLoc(-32, 32)
      perksNavSlot1Cancel.handleTouch = Button_handleTouch
      perksNavSlot1Cancel.onClick = perksNavSlotCancel_onClick
      perksNavSlot1Cancel.num = 1
      perksNavSlot1.cancel = perksNavSlot1Cancel
      local perksNavSlot1PickBox = perksNavSlot1Cancel:add(ui.PickBox.new(86, 86))
      perksNavSlot1PickBox:setLoc(32, -32)
      perksNavSlot1PickBox.handleTouch = nil
    end
    if perksNavSlot2Cancel == nil then
      local perksNavSlot2Cancel = perksNavSlot2:add(ui.Button.new("menuTemplate.atlas.png#perksNavSlotCancel.png"))
      perksNavSlot2Cancel._down:setColor(0.5, 0.5, 0.5)
      perksNavSlot2Cancel:setLoc(-32, 32)
      perksNavSlot2Cancel.handleTouch = Button_handleTouch
      perksNavSlot2Cancel.onClick = perksNavSlotCancel_onClick
      perksNavSlot2Cancel.num = 2
      perksNavSlot2.cancel = perksNavSlot2Cancel
      local perksNavSlot2PickBox = perksNavSlot2Cancel:add(ui.PickBox.new(86, 86))
      perksNavSlot2PickBox:setLoc(32, -32)
      perksNavSlot2PickBox.handleTouch = nil
    end
    if perksNavSlot3Cancel ~= nil then
      perksNavSlot3:remove(perksNavSlot3Cancel)
      perksNavSlot3.cancel = nil
    end
    if gameMode == "galaxy" then
      price = PERKS_1_COST + PERKS_2_COST
    elseif gameMode == "survival" then
      if not perks_inuse[active_perks[1]] then
        perksNavSlot1.costIcon:setColor(1, 1, 1, 1)
        perksNavSlot1.text:setColor(1, 1, 1, 1)
        perksNavSlot1.text:setString("" .. PerkDef[active_perks[1]].cost)
        perksNavSlot1.activeText:setColor(0, 0, 0, 0)
        price = price + PerkDef[active_perks[1]].cost
      else
        perksNavSlot1.costIcon:setColor(0, 0, 0, 0)
        perksNavSlot1.text:setColor(0, 0, 0, 0)
        perksNavSlot1.activeText:setColor(1, 1, 1, 1)
      end
      if not perks_inuse[active_perks[2]] then
        perksNavSlot2.costIcon:setColor(1, 1, 1, 1)
        perksNavSlot2.text:setColor(1, 1, 1, 1)
        perksNavSlot2.text:setString("" .. PerkDef[active_perks[2]].cost)
        perksNavSlot2.activeText:setColor(0, 0, 0, 0)
        price = price + PerkDef[active_perks[2]].cost
      else
        perksNavSlot2.costIcon:setColor(0, 0, 0, 0)
        perksNavSlot2.text:setColor(0, 0, 0, 0)
        perksNavSlot2.activeText:setColor(1, 1, 1, 1)
      end
      perksNavSlot3.costIcon:setColor(1, 1, 1, 1)
      perksNavSlot3.text:setColor(1, 1, 1, 1)
      perksNavSlot3.text:setString("0")
      perksNavSlot3.activeText:setColor(0, 0, 0, 0)
    end
  elseif #active_perks == 3 then
    perksNavSlot1Icon:setImage(PerkDef[active_perks[1]].icon)
    perksNavSlot1Icon:setColor(unpack(UI_COLOR_GOLD))
    perksNavSlot2Icon:setImage(PerkDef[active_perks[2]].icon)
    perksNavSlot2Icon:setColor(unpack(UI_COLOR_GOLD))
    perksNavSlot3Icon:setImage(PerkDef[active_perks[3]].icon)
    perksNavSlot3Icon:setColor(unpack(UI_COLOR_GOLD))
    if perksNavSlot1Cancel == nil then
      local perksNavSlot1Cancel = perksNavSlot1:add(ui.Button.new("menuTemplate.atlas.png#perksNavSlotCancel.png"))
      perksNavSlot1Cancel._down:setColor(0.5, 0.5, 0.5)
      perksNavSlot1Cancel:setLoc(-32, 32)
      perksNavSlot1Cancel.handleTouch = Button_handleTouch
      perksNavSlot1Cancel.onClick = perksNavSlotCancel_onClick
      perksNavSlot1Cancel.num = 1
      perksNavSlot1.cancel = perksNavSlot1Cancel
      local perksNavSlot1PickBox = perksNavSlot1Cancel:add(ui.PickBox.new(86, 86))
      perksNavSlot1PickBox:setLoc(32, -32)
      perksNavSlot1PickBox.handleTouch = nil
    end
    if perksNavSlot2Cancel == nil then
      local perksNavSlot2Cancel = perksNavSlot2:add(ui.Button.new("menuTemplate.atlas.png#perksNavSlotCancel.png"))
      perksNavSlot2Cancel._down:setColor(0.5, 0.5, 0.5)
      perksNavSlot2Cancel:setLoc(-32, 32)
      perksNavSlot2Cancel.handleTouch = Button_handleTouch
      perksNavSlot2Cancel.onClick = perksNavSlotCancel_onClick
      perksNavSlot2Cancel.num = 2
      perksNavSlot2.cancel = perksNavSlot2Cancel
      local perksNavSlot2PickBox = perksNavSlot2Cancel:add(ui.PickBox.new(86, 86))
      perksNavSlot2PickBox:setLoc(32, -32)
      perksNavSlot2PickBox.handleTouch = nil
    end
    if perksNavSlot3Cancel == nil then
      local perksNavSlot3Cancel = perksNavSlot3:add(ui.Button.new("menuTemplate.atlas.png#perksNavSlotCancel.png"))
      perksNavSlot3Cancel._down:setColor(0.5, 0.5, 0.5)
      perksNavSlot3Cancel:setLoc(-32, 32)
      perksNavSlot3Cancel.handleTouch = Button_handleTouch
      perksNavSlot3Cancel.onClick = perksNavSlotCancel_onClick
      perksNavSlot3Cancel.num = 3
      perksNavSlot3.cancel = perksNavSlot3Cancel
      local perksNavSlot3PickBox = perksNavSlot3Cancel:add(ui.PickBox.new(86, 86))
      perksNavSlot3PickBox:setLoc(32, -32)
      perksNavSlot3PickBox.handleTouch = nil
    end
    if gameMode == "galaxy" then
      price = PERKS_1_COST + PERKS_2_COST + PERKS_3_COST
    elseif gameMode == "survival" then
      if not perks_inuse[active_perks[1]] then
        perksNavSlot1.costIcon:setColor(1, 1, 1, 1)
        perksNavSlot1.text:setColor(1, 1, 1, 1)
        perksNavSlot1.text:setString("" .. PerkDef[active_perks[1]].cost)
        perksNavSlot1.activeText:setColor(0, 0, 0, 0)
        price = price + PerkDef[active_perks[1]].cost
      else
        perksNavSlot1.costIcon:setColor(0, 0, 0, 0)
        perksNavSlot1.text:setColor(0, 0, 0, 0)
        perksNavSlot1.activeText:setColor(1, 1, 1, 1)
      end
      if not perks_inuse[active_perks[2]] then
        perksNavSlot2.costIcon:setColor(1, 1, 1, 1)
        perksNavSlot2.text:setColor(1, 1, 1, 1)
        perksNavSlot2.text:setString("" .. PerkDef[active_perks[2]].cost)
        perksNavSlot2.activeText:setColor(0, 0, 0, 0)
        price = price + PerkDef[active_perks[2]].cost
      else
        perksNavSlot2.costIcon:setColor(0, 0, 0, 0)
        perksNavSlot2.text:setColor(0, 0, 0, 0)
        perksNavSlot2.activeText:setColor(1, 1, 1, 1)
      end
      if not perks_inuse[active_perks[3]] then
        perksNavSlot3.costIcon:setColor(1, 1, 1, 1)
        perksNavSlot3.text:setColor(1, 1, 1, 1)
        perksNavSlot3.text:setString("" .. PerkDef[active_perks[3]].cost)
        perksNavSlot3.activeText:setColor(0, 0, 0, 0)
        price = price + PerkDef[active_perks[3]].cost
      else
        perksNavSlot3.costIcon:setColor(0, 0, 0, 0)
        perksNavSlot3.text:setColor(0, 0, 0, 0)
        perksNavSlot3.activeText:setColor(1, 1, 1, 1)
      end
    end
  end
  perksCostText:setString("" .. price)
  if price > profile[PERKS_RESOURCE_TYPE] then
    _menu_root[PERKS_RESOURCE_TYPE .. "Text"]:setColor(unpack(UI_COLOR_RED))
  else
    _menu_root[PERKS_RESOURCE_TYPE .. "Text"]:setColor(1, 1, 1)
  end
end
function perks_close(move)
  if move == nil then
    move = {empty = true}
  end
  if _perks_root.continueBtnGlowAction ~= nil then
    _perks_root.continueBtnGlowAction:stop()
    _perks_root.continueBtnGlowAction = nil
  end
  _menu_root:remove(_menu_root.topBarBG)
  _menu_root.topBarBG = nil
  _storemenu_close({
    store_menu = move.store_menu
  })
  if move.perks_bar then
    do
      local action = _menu_root.perksNavBG:seekLoc(0, -device.ui_height / 2 - 70, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        _menu_root:remove(_menu_root.perksNavBG)
        _menu_root.perksNavBG = nil
      end)
    end
  else
    _menu_root:remove(_menu_root.perksNavBG)
    _menu_root.perksNavBG = nil
  end
  if move.bottom_bar then
    do
      local action = _menu_root.bottomNavBG:seekLoc(0, -device.ui_height / 2 - 120, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        _menu_root:remove(_menu_root.bottomNavBG)
        _menu_root.bottomNavBG = nil
      end)
    end
  else
    _menu_root:remove(_menu_root.bottomNavBG)
    _menu_root.bottomNavBG = nil
  end
  if move.forward then
    do
      local action = _perks_root:seekLoc(-device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_perks_root)
        _perks_root = nil
      end)
    end
  elseif move.back then
    do
      local action = _perks_root:seekLoc(device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_perks_root)
        _perks_root = nil
      end)
    end
  else
    submenuLayer:remove(_perks_root)
    _perks_root = nil
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  if scrollbar and scrollAction ~= nil then
    scrollAction:stop()
    scrollAction = nil
  end
  scrollbar = nil
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  curScreen = nil
end
function perks_show(move)
  if move == nil then
    move = {empty = true}
  end
  local submenu_height = device.ui_height - 100 - 210 - 60
  local submenu_y = 25
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  _storemenu_show("perks", nil, nil, {
    store_menu = move.store_menu
  })
  local topBarBG = _menu_root:add(ui.Image.new("menuTopBars.atlas.png#topBarGalaxyMap.png"))
  if not profile.excludeAds then
    topBarBG:setLoc(0, device.ui_height / 2 - 150)
  else
    topBarBG:setLoc(0, device.ui_height / 2 - 50)
  end
  _menu_root.topBarBG = topBarBG
  local topBarBGPickBox = topBarBG:add(ui.PickBox.new(device.ui_width, 100))
  local topBarText = topBarBG:add(ui.TextBox.new(_("Perks"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  topBarText:setLoc(0, -6)
  if menuMode ~= "ingame" then
    do
      local backBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconBack.png"))
      backBtn._down:setColor(0.5, 0.5, 0.5)
      backBtn:setLoc(-device.ui_width / 2 + 42, 0)
      backBtn.handleTouch = Button_handleTouch
      local function backBtn_onClick()
        if not screenAction:isActive() then
          perks_close({back = true, perks_bar = true})
          local screen = table_remove(screenHistory)
          if screen == "fleet" then
            fleet_show({back = true, store_filter = true})
          end
          soundmanager.onSFX("onPageSwipeBack")
        end
      end
      backBtn.onClick = backBtn_onClick
      if device.os == device.OS_ANDROID then
        local function callback()
          backBtn_onClick()
          return true
        end
        table_insert(android_back_button_queue, callback)
        MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
      end
    end
  elseif device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  if menuMode ~= "ingame" then
    local menuBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconHome.png"))
    menuBtn._down:setColor(0.5, 0.5, 0.5)
    menuBtn:setLoc(device.ui_width / 2 - 42, 0)
    menuBtn.handleTouch = Button_handleTouch
    function menuBtn:onClick()
      menu_close()
      mainmenu_show()
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  _perks_root = ui.Group.new()
  submenuLayer:add(_perks_root)
  local bg = _perks_root:add(ui.PickBox.new(device.ui_width, submenu_height))
  bg:setLoc(0, submenu_y)
  bg.handleTouch = _perks_items_handleTouch
  _perks_root.bg = bg
  local items_group = _perks_root:add(ui.Group.new())
  bg.items_group = items_group
  local items = {}
  local y
  if gameMode == "galaxy" then
    y = submenu_height / 2 + submenu_y - 44
  elseif gameMode == "survival" then
    y = submenu_height / 2 + submenu_y - 59
  end
  local PerkDef = require("ShipData-Perks")
  for i, v in pairs(PerkDef) do
    local item
    if gameMode == "galaxy" then
      item = _perks_create_item_galaxy(v)
    elseif gameMode == "survival" then
      item = _perks_create_item_survival(v)
    end
    if item then
      items_group:add(item)
      item:setLoc(0, y)
      if gameMode == "galaxy" then
        y = y - 90
      elseif gameMode == "survival" then
        y = y - 120
      end
      table_insert(items, item)
    end
  end
  items_group.numItems = #items
  if gameMode == "galaxy" then
    items_group.item_height = 90
  elseif gameMode == "survival" then
    items_group.item_height = 120
  end
  _perks_root.items = items
  if move.forward then
    _perks_root:setLoc(device.ui_width * 2, 0)
    _perks_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  elseif move.back then
    _perks_root:setLoc(-device.ui_width * 2, 0)
    _perks_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  end
  local perksNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#perksNavBG.png"))
  if move.perks_bar then
    perksNavBG:setLoc(0, -device.ui_height / 2 - 70)
    perksNavBG:seekLoc(0, -device.ui_height / 2 + 155, 0.5, MOAIEaseType.EASE_IN)
  else
    perksNavBG:setLoc(0, -device.ui_height / 2 + 155)
  end
  _menu_root.perksNavBG = perksNavBG
  local perksNavBGPickBox = perksNavBG:add(ui.PickBox.new(device.ui_width, 130))
  perksNavBGPickBox:setLoc(0, -9)
  local choosePerksText = perksNavBG:add(ui.TextBox.new(_("Choose Perks!"), FONT_MEDIUM, "ffffff", "center", 60, 55, true))
  choosePerksText:setLoc(-230, 5)
  local costText = perksNavBG:add(ui.TextBox.new(_("COST"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  costText:setLoc(230, 20)
  local costIcon = perksNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. PERKS_RESOURCE_TYPE:gsub("^%l", string.upper) .. ".png"))
  costIcon:setLoc(205, -15)
  local perksCostText = perksNavBG:add(ui.TextBox.new("0", FONT_MEDIUM, "ffffff", "left", 40, nil, true))
  perksCostText:setLoc(255, -18)
  perksNavBG.perksCostText = perksCostText
  local perksNavSlot1 = perksNavBG:add(ui.Group.new())
  perksNavSlot1:setLoc(-100, 0)
  perksNavBG.perksNavSlot1 = perksNavSlot1
  local perksNavSlot1Icon = perksNavSlot1:add(ui.Image.new("menuTemplate.atlas.png#perksNavSlot.png"))
  perksNavSlot1.icon = perksNavSlot1Icon
  local perksNavSlot1BG = perksNavSlot1:add(ui.PickBox.new(78, 26, "000000aa"))
  perksNavSlot1BG.handleTouch = nil
  perksNavSlot1BG:setLoc(0, -26)
  if gameMode == "galaxy" then
    do
      local str = PERKS_1_COST
      if str == 0 then
        str = _("FREE!")
      else
        local perksNavSlot1Icon = perksNavSlot1BG:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. PERKS_RESOURCE_TYPE:gsub("^%l", string.upper) .. "Small.png"))
        perksNavSlot1Icon:setLoc(-15, 0)
      end
      local perksNavSlot1Text = perksNavSlot1BG:add(ui.TextBox.new("" .. str, FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
      perksNavSlot1Text:setLoc(0, -3)
    end
  elseif gameMode == "survival" then
    local perksNavSlot1Icon = perksNavSlot1BG:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. PERKS_RESOURCE_TYPE:gsub("^%l", string.upper) .. "Small.png"))
    perksNavSlot1Icon:setLoc(-15, 0)
    perksNavSlot1.costIcon = perksNavSlot1Icon
    local perksNavSlot1Text = perksNavSlot1BG:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "left", 20, nil, true))
    perksNavSlot1Text:setLoc(15, -3)
    perksNavSlot1.text = perksNavSlot1Text
    local perksNavSlot1Text = perksNavSlot1BG:add(ui.TextBox.new(_("Active"), FONT_SMALL_BOLD, "ffffff", "center", 30, nil, true))
    perksNavSlot1Text:setLoc(0, -3)
    perksNavSlot1.activeText = perksNavSlot1Text
  end
  local perksNavSlot2 = perksNavBG:add(ui.Group.new())
  perksNavSlot2:setLoc(0, 0)
  perksNavBG.perksNavSlot2 = perksNavSlot2
  local perksNavSlot2Icon = perksNavSlot2:add(ui.Image.new("menuTemplate.atlas.png#perksNavSlot.png"))
  perksNavSlot2.icon = perksNavSlot2Icon
  local perksNavSlot2BG = perksNavSlot2:add(ui.PickBox.new(78, 26, "000000aa"))
  perksNavSlot2BG.handleTouch = nil
  perksNavSlot2BG:setLoc(0, -26)
  if gameMode == "galaxy" then
    do
      local str = PERKS_2_COST
      if str == 0 then
        str = _("FREE!")
      else
        local perksNavSlot2Icon = perksNavSlot2BG:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. PERKS_RESOURCE_TYPE:gsub("^%l", string.upper) .. "Small.png"))
        perksNavSlot2Icon:setLoc(-15, 0)
      end
      local perksNavSlot2Text = perksNavSlot2BG:add(ui.TextBox.new("" .. str, FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
      perksNavSlot2Text:setLoc(8, -3)
    end
  elseif gameMode == "survival" then
    local perksNavSlot2Icon = perksNavSlot2BG:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. PERKS_RESOURCE_TYPE:gsub("^%l", string.upper) .. "Small.png"))
    perksNavSlot2Icon:setLoc(-15, 0)
    perksNavSlot2.costIcon = perksNavSlot2Icon
    local perksNavSlot2Text = perksNavSlot2BG:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "left", 20, nil, true))
    perksNavSlot2Text:setLoc(15, -3)
    perksNavSlot2.text = perksNavSlot2Text
    local perksNavSlot2Text = perksNavSlot2BG:add(ui.TextBox.new(_("Active"), FONT_SMALL_BOLD, "ffffff", "center", 30, nil, true))
    perksNavSlot2Text:setLoc(0, -3)
    perksNavSlot2.activeText = perksNavSlot2Text
  end
  local perksNavSlot3 = perksNavBG:add(ui.Group.new())
  perksNavSlot3:setLoc(100, 0)
  perksNavBG.perksNavSlot3 = perksNavSlot3
  local perksNavSlot3Icon = perksNavSlot3:add(ui.Image.new("menuTemplate.atlas.png#perksNavSlot.png"))
  perksNavSlot3.icon = perksNavSlot3Icon
  local perksNavSlot3BG = perksNavSlot3:add(ui.PickBox.new(78, 26, "000000aa"))
  perksNavSlot3BG.handleTouch = nil
  perksNavSlot3BG:setLoc(0, -26)
  if gameMode == "galaxy" then
    do
      local str = PERKS_3_COST
      if str == 0 then
        str = _("FREE!")
      else
        local perksNavSlot3Icon = perksNavSlot3BG:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. PERKS_RESOURCE_TYPE:gsub("^%l", string.upper) .. "Small.png"))
        perksNavSlot3Icon:setLoc(-15, 0)
      end
      local perksNavSlot3Text = perksNavSlot3BG:add(ui.TextBox.new("" .. str, FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
      perksNavSlot3Text:setLoc(10, -3)
    end
  elseif gameMode == "survival" then
    local perksNavSlot3Icon = perksNavSlot3BG:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. PERKS_RESOURCE_TYPE:gsub("^%l", string.upper) .. "Small.png"))
    perksNavSlot3Icon:setLoc(-15, 0)
    perksNavSlot3.costIcon = perksNavSlot3Icon
    local perksNavSlot3Text = perksNavSlot3BG:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "left", 20, nil, true))
    perksNavSlot3Text:setLoc(15, -3)
    perksNavSlot3.text = perksNavSlot3Text
    local perksNavSlot3Text = perksNavSlot3BG:add(ui.TextBox.new(_("Active"), FONT_SMALL_BOLD, "ffffff", "center", 30, nil, true))
    perksNavSlot3Text:setLoc(0, -3)
    perksNavSlot3.activeText = perksNavSlot3Text
  end
  _perks_refresh()
  local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
  if move.bottom_bar then
    bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
    bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
  else
    bottomNavBG:setLoc(0, -device.ui_height / 2 - 8)
  end
  _menu_root.bottomNavBG = bottomNavBG
  local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
  bottomNavBGPickBox:setLoc(0, -20)
  local continueBtnGlow = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#largeButtonGlow.png"))
  continueBtnGlow:setColor(0.25, 0.25, 0.25, 0)
  continueBtnGlow:setScl(0.995, 0.995)
  continueBtnGlow:setLoc(0, 45)
  _perks_root.continueBtnGlowAction = uiAS:repeatcall(0.5, function()
    if continueBtnGlow.active then
      continueBtnGlow:seekColor(0.25, 0.25, 0.25, 0, 0.5, MOAIEaseType.EASE_IN)
      continueBtnGlow.active = nil
      continueBtnGlow.wait = true
    elseif continueBtnGlow.wait then
      continueBtnGlow.wait = nil
    else
      continueBtnGlow:seekColor(1, 1, 1, 0, 0.5, MOAIEaseType.EASE_IN)
      continueBtnGlow.active = true
    end
  end)
  local continueBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#largeButton.png"))
  continueBtn._down:setColor(0.5, 0.5, 0.5)
  continueBtn:setLoc(0, 50)
  if menuMode ~= "ingame" then
    do
      local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Start Mission"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      continueBtnText:setLoc(35, 0)
      local continueBtnIcon = continueBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconStart.png"))
      continueBtnIcon:setLoc(-90, 0)
      local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Start Mission"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      continueBtnText:setLoc(35, 0)
      local continueBtnIcon = continueBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconStart.png"))
      continueBtnIcon:setLoc(-90, 0)
    end
  else
    local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Resume"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
    continueBtnText:setLoc(20, 0)
    local continueBtnIcon = continueBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconStart.png"))
    continueBtnIcon:setLoc(-65, 0)
    local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Resume"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
    continueBtnText:setLoc(20, 0)
    local continueBtnIcon = continueBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconStart.png"))
    continueBtnIcon:setLoc(-65, 0)
  end
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn:onClick()
    if #active_perks == 0 then
      _popup_chooseperk_show(true)
    else
      local price = 0
      if gameMode == "galaxy" then
        if #active_perks == 1 then
          price = PERKS_1_COST
        elseif #active_perks == 2 then
          price = PERKS_1_COST + PERKS_2_COST
        elseif #active_perks == 3 then
          price = PERKS_1_COST + PERKS_2_COST + PERKS_3_COST
        end
      elseif gameMode == "survival" then
        if #active_perks == 1 then
          if not perks_inuse[active_perks[1]] then
            price = price + PerkDef[active_perks[1]].cost
          end
        elseif #active_perks == 2 then
          if not perks_inuse[active_perks[1]] then
            price = price + PerkDef[active_perks[1]].cost
          end
          if not perks_inuse[active_perks[2]] then
            price = price + PerkDef[active_perks[2]].cost
          end
        elseif #active_perks == 3 then
          if not perks_inuse[active_perks[1]] then
            price = price + PerkDef[active_perks[1]].cost
          end
          if not perks_inuse[active_perks[2]] then
            price = price + PerkDef[active_perks[2]].cost
          end
          if not perks_inuse[active_perks[3]] then
            price = price + PerkDef[active_perks[3]].cost
          end
        end
      end
      if price > profile[PERKS_RESOURCE_TYPE] then
        _popup_currency_show(PERKS_RESOURCE_TYPE, "perks", true, nil, "perks")
      else
        if menuMode ~= "ingame" then
          menu_close()
          level_run(levelGalaxyIndex, levelSystemIndex)
          profile_currency_txn(PERKS_RESOURCE_TYPE, -price, "Perks: " .. #active_perks, true)
          set_if_nil(gameSessionAnalytics, "currency", {})
          set_if_nil(gameSessionAnalytics.currency, PERKS_RESOURCE_TYPE, {})
          gameSessionAnalytics.currency[PERKS_RESOURCE_TYPE].spent = (gameSessionAnalytics.currency[PERKS_RESOURCE_TYPE].spent or 0) + price
        else
          profile_currency_txn(PERKS_RESOURCE_TYPE, -price, "Perks: " .. #active_perks, true)
          set_if_nil(gameSessionAnalytics, "currency", {})
          set_if_nil(gameSessionAnalytics.currency, PERKS_RESOURCE_TYPE, {})
          gameSessionAnalytics.currency[PERKS_RESOURCE_TYPE].spent = (gameSessionAnalytics.currency[PERKS_RESOURCE_TYPE].spent or 0) + price
          menu_close()
        end
        soundmanager.onSFX("onPageSwipeForward")
      end
    end
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  curScreen = "perks"
  if showPerkPopup then
    popups.show("on_show_g" .. levelGalaxyIndex .. "_s" .. levelSystemIndex .. "_perks", true)
    showPerkPopup = false
  end
end
local function _shipinfo_item_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  local submenu_height = device.ui_height - 160
  local submenu_y = -80
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  if _menu_root.bottomNavBG and _menu_root.bottomNavBG.low then
    submenu_height = submenu_height - 90
    submenu_y = submenu_y + 45
  elseif _menu_root.bottomNavBG then
    submenu_height = submenu_height - 230
    submenu_y = submenu_y + 115
  end
  local items_group = self.items_group
  if eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    ui.capture(self)
    if 0 < math.max(items_group.item_height - submenu_height, 0) then
      scrolling = true
      lastX = x
      lastY = y
      diffX = 0
      diffY = 0
      if scrollbar == nil then
        scrollbar = ui.Group.new()
        do
          local scrollbar_fill = scrollbar:add(ui.Image.new("scrollbar_fill.png"))
          scrollbar_fill:setScl(1, 3.5)
          scrollbar.fill = scrollbar_fill
          local scrollbar_top = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_top:setLoc(0, 36)
          scrollbar.top = scrollbar_top
          local scrollbar_bot = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_bot:setLoc(0, -36)
          scrollbar_bot:setScl(1, -1)
          scrollbar.bot = scrollbar_bot
          local groupX, groupY = items_group:getLoc()
          local perc = groupY / (items_group.item_height - submenu_height)
          scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70))
          scrollbar.fill:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.top:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.bot:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          self:add(scrollbar)
        end
      else
        if scrollbar_fadeOutActions.fill ~= nil and scrollbar_fadeOutActions.fill:isActive() then
          scrollbar_fadeOutActions.fill:stop()
          scrollbar_fadeOutActions.top:stop()
          scrollbar_fadeOutActions.bot:stop()
        end
        scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
      end
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
  elseif eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    ui.capture(nil)
    scrolling = false
    if scrollbar ~= nil and scrollbar.velocityY ~= nil then
      scrollbar.velocityY = scrollbar.velocityY + diffY
    elseif scrollbar ~= nil then
      scrollbar.velocityY = diffY
    end
    if scrollAction == nil then
      scrollAction = uiAS:wrap(function(dt)
        if scrollbar ~= nil then
          do
            local groupX, groupY = items_group:getLoc()
            local newY = util.clamp(groupY - scrollbar.velocityY, 0, math.max(items_group.item_height - submenu_height, 0))
            items_group:setLoc(0, util.roundNumber(newY))
            local groupX, groupY = items_group:getLoc()
            local perc = groupY / (items_group.item_height - submenu_height)
            scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70))
            scrollbar.velocityY = scrollbar.velocityY + scrollbar.velocityY * -1 * dt * 0.03 * device.dpi
            if not scrolling and abs(scrollbar.velocityY) < 0.5 then
              scrollAction:stop()
              scrollAction = nil
            end
          end
        else
          scrollAction:stop()
          scrollAction = nil
        end
      end, function()
        if not scrolling and scrollbar ~= nil then
          if scrollbar_fadeInActions.fill ~= nil and scrollbar_fadeInActions.fill:isActive() then
            scrollbar_fadeInActions.fill:stop()
            scrollbar_fadeInActions.top:stop()
            scrollbar_fadeInActions.bot:stop()
          end
          scrollbar_fadeOutActions.fill = scrollbar.fill:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.top = scrollbar.top:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.bot = scrollbar.bot:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.fill:setListener(MOAITimer.EVENT_STOP, function()
            if not scrolling and self ~= nil then
              self:remove(scrollbar)
              scrollbar = nil
            end
          end)
        end
      end)
    end
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE and scrolling then
    diffY = lastY - y
    local groupX, groupY = items_group:getLoc()
    local newY = util.clamp(groupY - diffY, 0, math.max(items_group.item_height - submenu_height, 0))
    items_group:setLoc(0, util.roundNumber(newY))
    if scrollbar ~= nil then
      local groupX, groupY = items_group:getLoc()
      local perc = groupY / (items_group.item_height - submenu_height)
      scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70))
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
    lastX = x
    lastY = y
  end
  return true
end
local function _shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue)
  local shipStatBarBG = ui.Image.new("menuTemplate.atlas.png#shipStatBarBG.png")
  local shipStatBarEndMin = ui.Image.new("menuTemplate.atlas.png#shipStatBarEnd.png")
  shipStatBarEndMin:setScl(-1, 1)
  shipStatBarEndMin:setLoc(-82, 0)
  local shipStatBarEndMax = ui.Image.new("menuTemplate.atlas.png#shipStatBarEnd.png")
  local shipStatBarEndMaxPerc = (maxValue - overallMinValue) / (overallMaxValue - overallMinValue)
  if overallMaxValue == overallMinValue then
    shipStatBarEndMaxPerc = 1
  end
  shipStatBarEndMax:setLoc(-82 + shipStatBarEndMaxPerc * 164, 0)
  local w = -82 + shipStatBarEndMaxPerc * 164 - -82
  local shipStatBarTop = ui.PickBox.new(w, 3, "ffffff")
  shipStatBarTop:setLoc(-82 + w / 2, 8.5)
  local shipStatBarBottom = ui.PickBox.new(w, 3, "ffffff")
  shipStatBarBottom:setLoc(-82 + w / 2, -8.5)
  local shipStatBarFill = shipStatBarBG:add(ui.FillBar.new({w, 14}, "00000088"))
  shipStatBarFill:setFill(0, 1)
  shipStatBarFill:setLoc(-82 + w / 2, 0)
  if screen == "shipupgrade" then
    local shipStatBarFill = shipStatBarBG:add(ui.FillBar.new({w, 14}, color.toHex(0.449, 0.357, 0.1075, 0.5)))
    local perc = (nextValue - overallMinValue) / (maxValue - overallMinValue)
    if maxValue == overallMinValue then
      perc = 1
    end
    shipStatBarFill:setFill(0, perc)
    shipStatBarFill:setLoc(-82 + w / 2, 0)
  end
  local shipStatBarFill = shipStatBarBG:add(ui.FillBar.new({w, 14}, "ffffff"))
  local perc = (curValue - overallMinValue) / (maxValue - overallMinValue)
  if maxValue == overallMinValue then
    perc = 1
  end
  shipStatBarFill:setFill(0, perc)
  shipStatBarFill:setLoc(-82 + w / 2, 0)
  shipStatBarBG:add(shipStatBarEndMin)
  shipStatBarBG:add(shipStatBarEndMax)
  shipStatBarBG:add(shipStatBarTop)
  shipStatBarBG:add(shipStatBarBottom)
  if screen == "shipupgrade" and curValue < nextValue then
    local shipUpgradeMarker = shipStatBarBG:add(ui.Image.new("menuTemplate.atlas.png#shipUpgradeMarker.png"))
    shipUpgradeMarker:setColor(0.898, 0.714, 0.215)
    local perc = (nextValue - overallMinValue) / (overallMaxValue - overallMinValue)
    if overallMaxValue == overallMinValue then
      perc = 1
    end
    shipUpgradeMarker:setLoc(-82 + perc * 164 + 2, 0)
  end
  return shipStatBarBG
end
local function _shipinfo_create_item(def, screen)
  local baseID = def._baseID
  local storeMaxUpgrade = 0
  for i, v in pairs(entitydef) do
    if v._baseID == baseID then
      storeMaxUpgrade = storeMaxUpgrade + 1
    end
  end
  local curDef = def
  local nextDef = def
  local lastDef = entitydef[baseID .. "_" .. storeMaxUpgrade - 1]
  if profile.unlocks[baseID].unlocked then
    curDef = entitydef[baseID .. "_" .. profile.unlocks[baseID].currentUpgrade]
    nextDef = entitydef[baseID .. "_" .. profile.unlocks[baseID].currentUpgrade + 1]
    if storeMaxUpgrade <= profile.unlocks[baseID].currentUpgrade + 1 then
      nextDef = curDef
    end
  end
  local submenu_height = device.ui_height - 100 - 60
  local submenu_y = -80
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  if _menu_root.bottomNavBG and _menu_root.bottomNavBG.low then
    submenu_height = submenu_height - 90
    submenu_y = submenu_y + 45
  elseif _menu_root.bottomNavBG then
    submenu_height = submenu_height - 230
    submenu_y = submenu_y + 115
  end
  local item = ui.Group.new()
  local ship = item:add(ui.Image.new(def.storeTexture[1]))
  ship:setLoc(-device.ui_width / 2 + 160, submenu_height / 2 + submenu_y - 100)
  ship:setRot(-90)
  local shipInfoBox = item:add(ui.NinePatch.new("boxWithHeaderLight9p.lua", 288, 162))
  shipInfoBox:setLoc(device.ui_width / 2 - 165, submenu_height / 2 + submenu_y - 100)
  if screen == "shipupgrade" and storeMaxUpgrade > profile.unlocks[baseID].currentUpgrade + 1 then
    do
      local upgradeIcon = shipInfoBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconShipLevel.png"))
      upgradeIcon:setColor(0.898, 0.714, 0.215)
      upgradeIcon:setLoc(-100, 50)
      local upgradeCurrentText = shipInfoBox:add(ui.TextBox.new("" .. profile.unlocks[baseID].currentUpgrade + 1, FONT_MEDIUM, "ffffff", "right", 30, nil, true))
      upgradeCurrentText:setLoc(-35, 45)
      local upgradeLevelArrow = shipInfoBox:add(ui.Image.new("menuTemplate.atlas.png#shipUpgradeLevelArrow.png"))
      upgradeLevelArrow:setLoc(10, 49)
      local upgradeNextText = shipInfoBox:add(ui.TextBox.new("" .. profile.unlocks[baseID].currentUpgrade + 2, FONT_MEDIUM_BOLD, "ffffff", "right", 30, nil, true))
      upgradeNextText:setColor(0.898, 0.714, 0.215)
      upgradeNextText:setLoc(53, 45)
    end
  elseif screen == "shipupgrade" then
    do
      local upgradeIcon = shipInfoBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconShipLevel.png"))
      upgradeIcon:setLoc(-100, 50)
      local upgradeCurrentText = shipInfoBox:add(ui.TextBox.new("" .. profile.unlocks[baseID].currentUpgrade + 1, FONT_MEDIUM, "ffffff", "right", 30, nil, true))
      upgradeCurrentText:setLoc(53, 45)
    end
  elseif screen == "shippurchase" then
    local upgradeIcon = shipInfoBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconShipLevel.png"))
    upgradeIcon:setLoc(-100, 50)
    local upgradeCurrentText = shipInfoBox:add(ui.TextBox.new("1", FONT_MEDIUM, "ffffff", "right", 30, nil, true))
    upgradeCurrentText:setLoc(53, 45)
  end
  local upgradeMaxText = shipInfoBox:add(ui.TextBox.new("/" .. storeMaxUpgrade, FONT_MEDIUM, "ffffff", "left", 40, nil, true))
  upgradeMaxText:setLoc(90, 45)
  local healthText = shipInfoBox:add(ui.TextBox.new(_("Health"), FONT_MEDIUM, "ffffff", "left", 100, nil, true))
  healthText:setColor(0.73, 0.73, 0.73)
  healthText:setLoc(-75, -15)
  local overallMinValue, overallMaxValue
  for j, v in pairs(entitydef) do
    if v.type == "capitalship" and v.hp ~= "" then
      if not overallMinValue then
        overallMinValue = v.hp
      elseif overallMinValue > v.hp then
        overallMinValue = v.hp
      end
      if not overallMaxValue then
        overallMaxValue = v.hp
      elseif overallMaxValue < v.hp then
        overallMaxValue = v.hp
      end
    end
  end
  overallMinValue = overallMinValue * 0.9
  local minValue = def.hp
  local maxValue = lastDef.hp
  local curValue = curDef.hp
  local nextValue = nextDef.hp
  local shipStatBarBG = shipInfoBox:add(_shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue))
  shipStatBarBG:setLoc(50, -14)
  if def.startDC == nil then
    local warpText = shipInfoBox:add(ui.TextBox.new(_("Warp"), FONT_MEDIUM, "ffffff", "left", 100, nil, true))
    warpText:setColor(0.73, 0.73, 0.73)
    warpText:setLoc(-75, -51)
    local warpCostText = shipInfoBox:add(ui.TextBox.new("" .. nextDef.buildCost.blue, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
    warpCostText:setLoc(93, -51)
    local strLen = string.len("" .. nextDef.buildCost.blue)
    local xmin, ymin, xmax, ymax = warpCostText:getStringBounds(1, strLen)
    local width = util.roundNumber(xmax - xmin)
    local iconWarpCost = shipInfoBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystalMed.png"))
    iconWarpCost:setLoc(123 - width - 20, -49)
  end
  local y = submenu_height / 2 + submenu_y - 200
  local tempY = y
  if def.startDC ~= nil or def.maxDC ~= nil then
    tempY = y
    local shipInventoryBox = item:add(ui.NinePatch.new("boxPlainLight9p.lua"))
    if def.startDC ~= nil then
      y = y - 36
      local nameText = item:add(ui.TextBox.new(_("Starting Crystals"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
      nameText:setColor(0.73, 0.73, 0.73)
      nameText:setLoc(-5, y)
      if screen == "shipupgrade" and nextDef.startDC > curDef.startDC then
        do
          local dataText = item:add(ui.TextBox.new("" .. curDef.startDC .. "<c:e5b637>+" .. nextDef.startDC - curDef.startDC, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
          dataText:setLoc(245, y)
          local strLen = string.len("" .. curDef.startDC .. "<c:e5b637>+" .. nextDef.startDC - curDef.startDC)
          local xmin, ymin, xmax, ymax = dataText:getStringBounds(1, strLen)
          local width = util.roundNumber(xmax - xmin)
          local dataIcon = item:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystalMed.png"))
          dataIcon:setLoc(270 - width - 20, y + 2)
        end
      else
        local dataText = item:add(ui.TextBox.new("" .. curDef.startDC, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
        dataText:setLoc(245, y)
        local strLen = string.len("" .. curDef.startDC)
        local xmin, ymin, xmax, ymax = dataText:getStringBounds(1, strLen)
        local width = util.roundNumber(xmax - xmin)
        local dataIcon = item:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystalMed.png"))
        dataIcon:setLoc(270 - width - 20, y + 2)
      end
    end
    if def.maxDC ~= nil then
      y = y - 36
      local nameText = item:add(ui.TextBox.new(_("Crystal Capacity"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
      nameText:setColor(0.73, 0.73, 0.73)
      nameText:setLoc(-5, y)
      if screen == "shipupgrade" and nextDef.maxDC > curDef.maxDC then
        do
          local dataText = item:add(ui.TextBox.new("" .. curDef.maxDC .. "<c:e5b637>+" .. nextDef.maxDC - curDef.maxDC, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
          dataText:setLoc(245, y)
          local strLen = string.len("" .. curDef.maxDC .. "<c:e5b637>+" .. nextDef.maxDC - curDef.maxDC)
          local xmin, ymin, xmax, ymax = dataText:getStringBounds(1, strLen)
          local width = util.roundNumber(xmax - xmin)
          local dataIcon = item:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystalMed.png"))
          dataIcon:setLoc(270 - width - 20, y + 2)
        end
      else
        local dataText = item:add(ui.TextBox.new("" .. curDef.maxDC, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
        dataText:setLoc(245, y)
        local strLen = string.len("" .. curDef.maxDC)
        local xmin, ymin, xmax, ymax = dataText:getStringBounds(1, strLen)
        local width = util.roundNumber(xmax - xmin)
        local dataIcon = item:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystalMed.png"))
        dataIcon:setLoc(270 - width - 20, y + 2)
      end
    end
    y = y - 36
    shipInventoryBox:setSize(450, tempY - y)
    shipInventoryBox:setLoc(75, tempY + (y - tempY) / 2)
    y = y - 20
  end
  local icon, cannonModule, fighterModule, harvesterModule
  for i, v in ipairs(curDef.subentities) do
    local subentityStr, queryStr = breakstr(v, "?")
    local subentity = entitydef[subentityStr]
    local nextsubentityStr, queryStr = breakstr(nextDef.subentities[i], "?")
    local nextsubentity = entitydef[nextsubentityStr]
    local basesubentityStr, queryStr = breakstr(def.subentities[i], "?")
    local basesubentity = entitydef[basesubentityStr]
    local lastsubentityStr, queryStr = breakstr(lastDef.subentities[i], "?")
    local lastsubentity = entitydef[lastsubentityStr]
    if subentity.type == "cannon" then
      if cannonModule == nil then
        tempY = y
        do
          local shipInventoryBox = item:add(ui.NinePatch.new("boxWithSideSectionLight9p.lua"))
          y = y - 36
          cannonModule = {}
          local projectileentity = entitydef[subentity.cannonProjectileType]
          local nextprojectileentity = entitydef[nextsubentity.cannonProjectileType]
          local baseprojectileentity = entitydef[basesubentity.cannonProjectileType]
          local lastprojectileentity = entitydef[lastsubentity.cannonProjectileType]
          for i = 1, 4 do
            if i == 1 then
              do
                local nameText = item:add(ui.TextBox.new(_("Cannon Damage"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
                nameText:setColor(0.73, 0.73, 0.73)
                nameText:setLoc(-5, y)
                local overallMinValue, overallMaxValue
                for j, v in pairs(entitydef) do
                  if v.type == "missile" and v.weaponDamage ~= "" then
                    if not overallMinValue then
                      overallMinValue = v.weaponDamage
                    elseif overallMinValue > v.weaponDamage then
                      overallMinValue = v.weaponDamage
                    end
                    if not overallMaxValue then
                      overallMaxValue = v.weaponDamage
                    elseif overallMaxValue < v.weaponDamage then
                      overallMaxValue = v.weaponDamage
                    end
                  end
                end
                overallMinValue = overallMinValue * 0.9
                local minValue = baseprojectileentity.weaponDamage
                local maxValue = lastprojectileentity.weaponDamage
                local curValue = projectileentity.weaponDamage
                local nextValue = nextprojectileentity.weaponDamage
                local shipStatBarBG = item:add(_shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue))
                shipStatBarBG:setLoc(200, y)
              end
            elseif i == 2 then
              do
                local nameText = item:add(ui.TextBox.new(_("Area of Effect"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
                nameText:setColor(0.73, 0.73, 0.73)
                nameText:setLoc(-5, y - 2)
                local overallMinValue, overallMaxValue
                for j, v in pairs(entitydef) do
                  if v.type == "missile" and v.weaponRange ~= "" then
                    if not overallMinValue then
                      overallMinValue = v.weaponRange
                    elseif overallMinValue > v.weaponRange then
                      overallMinValue = v.weaponRange
                    end
                    if not overallMaxValue then
                      overallMaxValue = v.weaponRange
                    elseif overallMaxValue < v.weaponRange then
                      overallMaxValue = v.weaponRange
                    end
                  end
                end
                overallMinValue = overallMinValue * 0.9
                local minValue = baseprojectileentity.weaponRange
                local maxValue = lastprojectileentity.weaponRange
                local curValue = projectileentity.weaponRange
                local nextValue = nextprojectileentity.weaponRange
                local shipStatBarBG = item:add(_shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue))
                shipStatBarBG:setLoc(200, y)
              end
            elseif i == 3 then
              do
                local nameText = item:add(ui.TextBox.new(_("Rate of Fire"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
                nameText:setColor(0.73, 0.73, 0.73)
                nameText:setLoc(-5, y)
                local overallMinValue, overallMaxValue
                for j, v in pairs(entitydef) do
                  if v.type == "cannon" and v.cannonCooldown ~= "" then
                    if not overallMinValue then
                      overallMinValue = 1 / v.cannonCooldown
                    elseif overallMinValue > 1 / v.cannonCooldown then
                      overallMinValue = 1 / v.cannonCooldown
                    end
                    if not overallMaxValue then
                      overallMaxValue = 1 / v.cannonCooldown
                    elseif overallMaxValue < 1 / v.cannonCooldown then
                      overallMaxValue = 1 / v.cannonCooldown
                    end
                  end
                end
                overallMinValue = overallMinValue * 0.9
                local minValue = 1 / basesubentity.cannonCooldown
                local maxValue = 1 / lastsubentity.cannonCooldown
                local curValue = 1 / subentity.cannonCooldown
                local nextValue = 1 / nextsubentity.cannonCooldown
                local shipStatBarBG = item:add(_shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue))
                shipStatBarBG:setLoc(200, y)
              end
            elseif i == 4 then
              local nameText = item:add(ui.TextBox.new(_("# of Cannons"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
              nameText:setColor(0.73, 0.73, 0.73)
              nameText:setLoc(-5, y)
              cannonModule.numCannons = 1
              cannonModule.numCannonsText = item:add(ui.TextBox.new("" .. cannonModule.numCannons, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
              cannonModule.numCannonsText:setLoc(245, y)
            end
            y = y - 36
          end
          icon = item:add(ui.Image.new("storeScreen.atlas.png#gunshipTurretBasic.png"))
          icon:setColor(unpack(UI_SHIP_COLOR_SPECIAL))
          icon:setLoc(-220, y + 144 - 50)
          shipInventoryBox:setSize(600, tempY - y)
          shipInventoryBox:setLoc(0, tempY + (y - tempY) / 2)
          y = y - 20
        end
      else
        cannonModule.numCannons = cannonModule.numCannons + 1
        cannonModule.numCannonsText:setString("" .. cannonModule.numCannons)
      end
    elseif subentity.type == "tesla_cannon" then
      if cannonModule == nil then
        tempY = y
        do
          local shipInventoryBox = item:add(ui.NinePatch.new("boxWithSideSectionLight9p.lua"))
          y = y - 36
          cannonModule = {}
          local projectileentity = entitydef[subentity.cannonProjectileType]
          local nextprojectileentity = entitydef[nextsubentity.cannonProjectileType]
          local baseprojectileentity = entitydef[basesubentity.cannonProjectileType]
          local lastprojectileentity = entitydef[lastsubentity.cannonProjectileType]
          for i = 1, 4 do
            if i == 1 then
              do
                local nameText = item:add(ui.TextBox.new(_("Cannon Damage"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
                nameText:setColor(0.73, 0.73, 0.73)
                nameText:setLoc(-5, y)
                local overallMinValue, overallMaxValue
                for j, v in pairs(entitydef) do
                  if v.type == "missile" and v.weaponDamage ~= "" then
                    if not overallMinValue then
                      overallMinValue = v.weaponDamage
                    elseif overallMinValue > v.weaponDamage then
                      overallMinValue = v.weaponDamage
                    end
                    if not overallMaxValue then
                      overallMaxValue = v.weaponDamage
                    elseif overallMaxValue < v.weaponDamage then
                      overallMaxValue = v.weaponDamage
                    end
                  end
                end
                overallMinValue = overallMinValue * 0.9
                local minValue = baseprojectileentity.weaponDamage
                local maxValue = lastprojectileentity.weaponDamage
                local curValue = projectileentity.weaponDamage
                local nextValue = nextprojectileentity.weaponDamage
                local shipStatBarBG = item:add(_shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue))
                shipStatBarBG:setLoc(200, y)
              end
            elseif i == 2 then
              do
                local nameText = item:add(ui.TextBox.new(_("Recharge Rate"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
                nameText:setColor(0.73, 0.73, 0.73)
                nameText:setLoc(-5, y - 2)
                local overallMinValue, overallMaxValue
                for j, v in pairs(entitydef) do
                  if v.type == "missile" and v.teslaMode and v.teslaCooldown ~= "" then
                    if not overallMinValue then
                      overallMinValue = v.teslaCooldown
                    elseif overallMinValue > v.teslaCooldown then
                      overallMinValue = v.teslaCooldown
                    end
                    if not overallMaxValue then
                      overallMaxValue = v.teslaCooldown
                    elseif overallMaxValue < v.teslaCooldown then
                      overallMaxValue = v.teslaCooldown
                    end
                  end
                end
                overallMinValue = overallMinValue * 0.9
                local minValue = baseprojectileentity.teslaCooldown
                local maxValue = lastprojectileentity.teslaCooldown
                local curValue = projectileentity.teslaCooldown
                local nextValue = nextprojectileentity.teslaCooldown
                local shipStatBarBG = item:add(_shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue))
                shipStatBarBG:setLoc(200, y)
              end
            elseif i == 3 then
              local nameText = item:add(ui.TextBox.new(_("# of Cannons"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
              nameText:setColor(0.73, 0.73, 0.73)
              nameText:setLoc(-5, y)
              cannonModule.numCannons = 1
              cannonModule.numCannonsText = item:add(ui.TextBox.new("" .. cannonModule.numCannons, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
              cannonModule.numCannonsText:setLoc(245, y)
            end
            y = y - 36
          end
          icon = item:add(ui.Image.new("storeScreen.atlas.png#gunshipTurretBasic.png"))
          icon:setColor(unpack(UI_SHIP_COLOR_SPECIAL))
          icon:setLoc(-220, y + 144 - 50)
          shipInventoryBox:setSize(600, tempY - y)
          shipInventoryBox:setLoc(0, tempY + (y - tempY) / 2)
          y = y - 20
        end
      else
        cannonModule.numCannons = cannonModule.numCannons + 1
        cannonModule.numCannonsText:setString("" .. cannonModule.numCannons)
      end
    elseif subentity.type == "module" then
      local hangarentity = entitydef[subentity.hangarInventoryType]
      local nexthangarentity = entitydef[nextsubentity.hangarInventoryType]
      local basehangarentity = entitydef[basesubentity.hangarInventoryType]
      local lasthangarentity = entitydef[lastsubentity.hangarInventoryType]
      if hangarentity.type == "fighter" then
        if fighterModule == nil then
          tempY = y
          local shipInventoryBox = item:add(ui.NinePatch.new("boxWithSideSectionLight9p.lua"))
          y = y - 36
          fighterModule = {}
          for i = 1, 5 do
            if i == 1 then
              do
                local nameText = item:add(ui.TextBox.new(_("Max Fighters"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
                nameText:setColor(0.73, 0.73, 0.73)
                nameText:setLoc(-5, y)
                if screen == "shipupgrade" and nextsubentity.hangarCapacity > subentity.hangarCapacity then
                  do
                    local dataText = item:add(ui.TextBox.new("" .. subentity.hangarCapacity .. "<c:e5b637>+" .. nextsubentity.hangarCapacity - subentity.hangarCapacity, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
                    dataText:setLoc(245, y)
                  end
                else
                  local dataText = item:add(ui.TextBox.new("" .. subentity.hangarCapacity, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
                  dataText:setLoc(245, y)
                end
              end
            elseif i == 2 then
              do
                local nameText = item:add(ui.TextBox.new(_("Weapon Damage"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
                nameText:setColor(0.73, 0.73, 0.73)
                nameText:setLoc(-5, y)
                local overallMinValue, overallMaxValue
                for j, v in pairs(entitydef) do
                  if v.type == "fighter" and v.weaponDamage ~= "" and v.weaponPulses ~= "" and v.weaponPulseDelay and v.weaponCooldown ~= "" then
                    local val = v.weaponDamage * v.weaponPulses / (v.weaponPulses * v.weaponPulseDelay + v.weaponCooldown)
                    if not overallMinValue then
                      overallMinValue = val
                    elseif val < overallMinValue then
                      overallMinValue = val
                    end
                    if not overallMaxValue then
                      overallMaxValue = val
                    elseif val > overallMaxValue then
                      overallMaxValue = val
                    end
                  end
                end
                overallMinValue = overallMinValue * 0.9
                local minValue = basehangarentity.weaponDamage * basehangarentity.weaponPulses / (basehangarentity.weaponPulses * basehangarentity.weaponPulseDelay + basehangarentity.weaponCooldown)
                local maxValue = lasthangarentity.weaponDamage * lasthangarentity.weaponPulses / (lasthangarentity.weaponPulses * lasthangarentity.weaponPulseDelay + lasthangarentity.weaponCooldown)
                local curValue = hangarentity.weaponDamage * hangarentity.weaponPulses / (hangarentity.weaponPulses * hangarentity.weaponPulseDelay + hangarentity.weaponCooldown)
                local nextValue = nexthangarentity.weaponDamage * nexthangarentity.weaponPulses / (nexthangarentity.weaponPulses * nexthangarentity.weaponPulseDelay + nexthangarentity.weaponCooldown)
                local shipStatBarBG = item:add(_shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue))
                shipStatBarBG:setLoc(200, y)
              end
            elseif i == 3 then
              do
                local nameText = item:add(ui.TextBox.new(_("Weapon Range"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
                nameText:setColor(0.73, 0.73, 0.73)
                nameText:setLoc(-5, y)
                local overallMinValue, overallMaxValue
                for j, v in pairs(entitydef) do
                  if v.type == "fighter" and v.weaponRange ~= "" then
                    if not overallMinValue then
                      overallMinValue = v.weaponRange
                    elseif overallMinValue > v.weaponRange then
                      overallMinValue = v.weaponRange
                    end
                    if not overallMaxValue then
                      overallMaxValue = v.weaponRange
                    elseif overallMaxValue < v.weaponRange then
                      overallMaxValue = v.weaponRange
                    end
                  end
                end
                overallMinValue = overallMinValue * 0.9
                local minValue = basehangarentity.weaponRange
                local maxValue = lasthangarentity.weaponRange
                local curValue = hangarentity.weaponRange
                local nextValue = nexthangarentity.weaponRange
                local shipStatBarBG = item:add(_shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue))
                shipStatBarBG:setLoc(200, y)
              end
            elseif i == 4 then
              do
                local nameText = item:add(ui.TextBox.new(_("Fighter Speed"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
                nameText:setColor(0.73, 0.73, 0.73)
                nameText:setLoc(-5, y)
                local overallMinValue, overallMaxValue
                for j, v in pairs(entitydef) do
                  if v.type == "fighter" and v.maxspeed ~= "" then
                    if not overallMinValue then
                      overallMinValue = v.maxspeed
                    elseif overallMinValue > v.maxspeed then
                      overallMinValue = v.maxspeed
                    end
                    if not overallMaxValue then
                      overallMaxValue = v.maxspeed
                    elseif overallMaxValue < v.maxspeed then
                      overallMaxValue = v.maxspeed
                    end
                  end
                end
                overallMinValue = overallMinValue * 0.9
                local minValue = basehangarentity.maxspeed
                local maxValue = lasthangarentity.maxspeed
                local curValue = hangarentity.maxspeed
                local nextValue = nexthangarentity.maxspeed
                local shipStatBarBG = item:add(_shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue))
                shipStatBarBG:setLoc(200, y)
              end
            elseif i == 5 then
              local nameText = item:add(ui.TextBox.new(_("Fighter Health"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
              nameText:setColor(0.73, 0.73, 0.73)
              nameText:setLoc(-5, y)
              local overallMinValue, overallMaxValue
              for j, v in pairs(entitydef) do
                if v.type == "fighter" and v.hp ~= "" then
                  if not overallMinValue then
                    overallMinValue = v.hp
                  elseif overallMinValue > v.hp then
                    overallMinValue = v.hp
                  end
                  if not overallMaxValue then
                    overallMaxValue = v.hp
                  elseif overallMaxValue < v.hp then
                    overallMaxValue = v.hp
                  end
                end
              end
              overallMinValue = overallMinValue * 0.9
              local minValue = basehangarentity.hp
              local maxValue = lasthangarentity.hp
              local curValue = hangarentity.hp
              local nextValue = nexthangarentity.hp
              local shipStatBarBG = item:add(_shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue))
              shipStatBarBG:setLoc(200, y)
            end
            y = y - 36
          end
          icon = item:add(ui.Image.new(string.format("storeScreen.atlas.png#%s.png", _getFighterFrame(curDef.storeTags))))
          local r, g, b = color.parse(subentity.pathColor)
          icon:setColor(r, g, b)
          local hangarship = icon:add(ui.Image.new(hangarentity.storeTexture))
          hangarship:clearAttrLink(MOAIColor.INHERIT_COLOR)
          hangarship:setRot(-90)
          icon:setLoc(-220, y + 180 - 50)
          shipInventoryBox:setSize(600, tempY - y)
          shipInventoryBox:setLoc(0, tempY + (y - tempY) / 2)
          y = y - 20
        end
      elseif hangarentity.type == "harvester" then
        local lastCompletedGalaxy, lastCompletedSystem, lastCompletedIndex = _get_last_completed_galaxy_system()
        if baseID == "SPC" and lastCompletedIndex < TUT_MIN_HARVESTER_SYSTEM then
        elseif harvesterModule == nil then
          tempY = y
          local shipInventoryBox = item:add(ui.NinePatch.new("boxWithSideSectionLight9p.lua"))
          y = y - 36
          harvesterModule = {}
          for i = 1, 4 do
            if i == 1 then
              do
                local nameText = item:add(ui.TextBox.new(_("Max Harvesters"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
                nameText:setColor(0.73, 0.73, 0.73)
                nameText:setLoc(-5, y)
                if screen == "shipupgrade" and nextsubentity.hangarCapacity > subentity.hangarCapacity then
                  do
                    local dataText = item:add(ui.TextBox.new("" .. subentity.hangarCapacity .. "<c:e5b637>+" .. nextsubentity.hangarCapacity - subentity.hangarCapacity, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
                    dataText:setLoc(245, y)
                  end
                else
                  local dataText = item:add(ui.TextBox.new("" .. subentity.hangarCapacity, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
                  dataText:setLoc(245, y)
                end
              end
            elseif i == 2 then
              do
                local nameText = item:add(ui.TextBox.new(_("Harvester Capacity"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
                nameText:setColor(0.73, 0.73, 0.73)
                nameText:setLoc(-5, y)
                if screen == "shipupgrade" and nexthangarentity.towedObjectMax > hangarentity.towedObjectMax then
                  do
                    local dataText = item:add(ui.TextBox.new("" .. hangarentity.towedObjectMax .. "<c:e5b637>+" .. nexthangarentity.towedObjectMax - hangarentity.towedObjectMax, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
                    dataText:setLoc(245, y)
                  end
                else
                  local dataText = item:add(ui.TextBox.new("" .. hangarentity.towedObjectMax, FONT_MEDIUM, "ffffff", "right", 60, nil, true))
                  dataText:setLoc(245, y)
                end
              end
            elseif i == 3 then
              do
                local nameText = item:add(ui.TextBox.new(_("Harvester Health"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
                nameText:setColor(0.73, 0.73, 0.73)
                nameText:setLoc(-5, y)
                local overallMinValue, overallMaxValue
                for j, v in pairs(entitydef) do
                  if v.type == "harvester" and v.hp ~= "" then
                    if not overallMinValue then
                      overallMinValue = v.hp
                    elseif overallMinValue > v.hp then
                      overallMinValue = v.hp
                    end
                    if not overallMaxValue then
                      overallMaxValue = v.hp
                    elseif overallMaxValue < v.hp then
                      overallMaxValue = v.hp
                    end
                  end
                end
                overallMinValue = overallMinValue * 0.9
                local minValue = basehangarentity.hp
                local maxValue = lasthangarentity.hp
                local curValue = hangarentity.hp
                local nextValue = nexthangarentity.hp
                local shipStatBarBG = item:add(_shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue))
                shipStatBarBG:setLoc(200, y)
              end
            elseif i == 4 then
              local nameText = item:add(ui.TextBox.new(_("Harvester Speed"), FONT_MEDIUM, "ffffff", "left", 250, nil, true))
              nameText:setColor(0.73, 0.73, 0.73)
              nameText:setLoc(-5, y)
              local overallMinValue, overallMaxValue
              for j, v in pairs(entitydef) do
                if v.type == "harvester" and v.maxspeed ~= "" then
                  if not overallMinValue then
                    overallMinValue = v.maxspeed
                  elseif overallMinValue > v.maxspeed then
                    overallMinValue = v.maxspeed
                  end
                  if not overallMaxValue then
                    overallMaxValue = v.maxspeed
                  elseif overallMaxValue < v.maxspeed then
                    overallMaxValue = v.maxspeed
                  end
                end
              end
              overallMinValue = overallMinValue * 0.9
              local minValue = basehangarentity.maxspeed
              local maxValue = lasthangarentity.maxspeed
              local curValue = hangarentity.maxspeed
              local nextValue = nexthangarentity.maxspeed
              local shipStatBarBG = item:add(_shipinfo_item_create_fillbar(screen, overallMinValue, overallMaxValue, minValue, maxValue, curValue, nextValue))
              shipStatBarBG:setLoc(200, y)
            end
            y = y - 36
          end
          icon = item:add(ui.Image.new("storeScreen.atlas.png#storeSelectorMiner.png"))
          local r, g, b = color.parse(subentity.pathColor)
          icon:setColor(r, g, b)
          local hangarship = icon:add(ui.Image.new(hangarentity.storeTexture))
          hangarship:clearAttrLink(MOAIColor.INHERIT_COLOR)
          hangarship:setRot(-90)
          icon:setLoc(-220, y + 144 - 50)
          shipInventoryBox:setSize(600, tempY - y)
          shipInventoryBox:setLoc(0, tempY + (y - tempY) / 2)
          y = y - 20
        end
      end
    end
  end
  return item, -y + submenu_height / 2 + submenu_y
end
function shipinfo_close(move)
  if move == nil then
    move = {empty = true}
  end
  _menu_root:remove(_menu_root.topBarBG)
  _menu_root.topBarBG = nil
  _storemenu_close({
    store_menu = move.store_menu
  })
  if move.forward then
    do
      local action = _shipinfo_root:seekLoc(-device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_shipinfo_root)
        _shipinfo_root = nil
      end)
    end
  elseif move.back then
    do
      local action = _shipinfo_root:seekLoc(device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_shipinfo_root)
        _shipinfo_root = nil
      end)
    end
  else
    submenuLayer:remove(_shipinfo_root)
    _shipinfo_root = nil
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  if scrollbar and scrollAction ~= nil then
    scrollAction:stop()
    scrollAction = nil
  end
  scrollbar = nil
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  curScreen = nil
end
function shipinfo_show(move, def)
  if move == nil then
    move = {empty = true}
  end
  local baseID = def._baseID
  local storeMaxUpgrade = 0
  for i, v in pairs(entitydef) do
    if v._baseID == baseID then
      storeMaxUpgrade = storeMaxUpgrade + 1
    end
  end
  local submenu_height = device.ui_height - 100 - 60
  local submenu_y = -80
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  _storemenu_show("shipinfo", nil, def)
  local topBarBG = _menu_root:add(ui.Image.new("menuTopBars.atlas.png#topBarUpgradeShip.png"))
  if not profile.excludeAds then
    topBarBG:setLoc(0, device.ui_height / 2 - 150)
  else
    topBarBG:setLoc(0, device.ui_height / 2 - 50)
  end
  _menu_root.topBarBG = topBarBG
  local topBarBGPickBox = topBarBG:add(ui.PickBox.new(device.ui_width, 100))
  local topBarText = topBarBG:add(ui.TextBox.new(_("Ship Info"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  topBarText:setLoc(0, -6)
  local backBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconBack.png"))
  backBtn._down:setColor(0.5, 0.5, 0.5)
  backBtn:setLoc(-device.ui_width / 2 + 42, 0)
  backBtn.handleTouch = Button_handleTouch
  local function backBtn_onClick()
    if not screenAction:isActive() then
      shipinfo_close({back = true})
      local screen = table_remove(screenHistory)
      if screen == "fleet" then
        fleet_show({
          back = true,
          bottom_bar = true,
          store_filter = true
        })
      end
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  backBtn.onClick = backBtn_onClick
  if device.os == device.OS_ANDROID then
    local function callback()
      backBtn_onClick()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local menuBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconHome.png"))
  menuBtn._down:setColor(0.5, 0.5, 0.5)
  menuBtn:setLoc(device.ui_width / 2 - 42, 0)
  menuBtn.handleTouch = Button_handleTouch
  function menuBtn:onClick()
    menu_close()
    mainmenu_show()
    soundmanager.onSFX("onPageSwipeBack")
  end
  _shipinfo_root = ui.Group.new()
  local bg = _shipinfo_root:add(ui.PickBox.new(device.ui_width, submenu_height))
  bg:setLoc(0, submenu_y)
  bg.handleTouch = _shipinfo_item_handleTouch
  bg.def = def
  local items_group = _shipinfo_root:add(ui.Group.new())
  bg.items_group = items_group
  local item, item_height = _shipinfo_create_item(def, "shipinfo")
  items_group:add(item)
  items_group.item_height = item_height
  if move.forward then
    _shipinfo_root:setLoc(device.ui_width * 2, 0)
    _shipinfo_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  elseif move.back then
    _shipinfo_root:setLoc(-device.ui_width * 2, 0)
    _shipinfo_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  submenuLayer:add(_shipinfo_root)
  shipInfoDef = def
  curScreen = "shipinfo"
end
local function _shipupgrade_upgrade(def)
  local baseID = def._baseID
  local nextDef = entitydef[baseID .. "_" .. profile.unlocks[baseID].currentUpgrade + 1]
  local itemId = "ship." .. nextDef._id
  profile.unlocks[baseID].currentUpgrade = profile.unlocks[baseID].currentUpgrade + 1
  analytics.gameShopPurchaseSuccess(itemId, nextDef.storePurchaseType, nextDef.storePurchaseCost, profile_get_level_id())
  if SixWaves then
    SixWaves.trackInGameItemPurchase(itemId, {
      price = nextDef.storePurchaseCos,
      category = "ship_upgrade",
      priceType = nextDef.storePurchaseType,
      leveid = profile_get_level_id()
    })
  end
  profile_currency_txn(nextDef.storePurchaseType, -nextDef.storePurchaseCost, "Shop Upgrade: " .. itemId, true)
  _storemenu_refresh()
  soundmanager.onSFX("onUpgradeSelect")
end
function shipupgrade_close(move)
  if move == nil then
    move = {empty = true}
  end
  _menu_root:remove(_menu_root.topBarBG)
  _menu_root.topBarBG = nil
  _storemenu_close({
    store_menu = move.store_menu
  })
  if move.bottom_bar then
    if _menu_root.bottomNavBG then
      local action = _menu_root.bottomNavBG:seekLoc(0, -device.ui_height / 2 - 120, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        _menu_root:remove(_menu_root.bottomNavBG)
        _menu_root.bottomNavBG = nil
      end)
    end
  else
    _menu_root:remove(_menu_root.bottomNavBG)
    _menu_root.bottomNavBG = nil
  end
  if move.forward then
    do
      local action = _shipupgrade_root:seekLoc(-device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_shipupgrade_root)
        _shipupgrade_root = nil
      end)
    end
  elseif move.back then
    do
      local action = _shipupgrade_root:seekLoc(device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_shipupgrade_root)
        _shipupgrade_root = nil
      end)
    end
  else
    submenuLayer:remove(_shipupgrade_root)
    _shipupgrade_root = nil
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  if scrollbar and scrollAction ~= nil then
    scrollAction:stop()
    scrollAction = nil
  end
  scrollbar = nil
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  curScreen = nil
end
function shipupgrade_show(move, def)
  if move == nil then
    move = {empty = true}
  end
  local baseID = def._baseID
  local storeMaxUpgrade = 0
  for i, v in pairs(entitydef) do
    if v._baseID == baseID then
      storeMaxUpgrade = storeMaxUpgrade + 1
    end
  end
  local curDef = entitydef[baseID .. "_" .. profile.unlocks[baseID].currentUpgrade]
  local nextDef = entitydef[baseID .. "_" .. profile.unlocks[baseID].currentUpgrade + 1]
  if storeMaxUpgrade <= profile.unlocks[baseID].currentUpgrade + 1 then
    nextDef = curDef
  end
  local submenu_height = device.ui_height - 100 - 60
  local submenu_y = -80
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  if profile.level < nextDef.storeUnlockLevel then
    submenu_height = submenu_height - 90
    submenu_y = submenu_y + 45
  elseif storeMaxUpgrade > profile.unlocks[baseID].currentUpgrade + 1 then
    submenu_height = submenu_height - 230
    submenu_y = submenu_y + 115
  else
    submenu_height = submenu_height - 90
    submenu_y = submenu_y + 45
  end
  _storemenu_show("shipupgrade")
  local topBarBG = _menu_root:add(ui.Image.new("menuTopBars.atlas.png#topBarUpgradeShip.png"))
  if not profile.excludeAds then
    topBarBG:setLoc(0, device.ui_height / 2 - 150)
  else
    topBarBG:setLoc(0, device.ui_height / 2 - 50)
  end
  _menu_root.topBarBG = topBarBG
  local topBarBGPickBox = topBarBG:add(ui.PickBox.new(device.ui_width, 100))
  local topBarText = topBarBG:add(ui.TextBox.new(_("Upgrade Ship"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  topBarText:setLoc(0, -6)
  local backBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconBack.png"))
  backBtn._down:setColor(0.5, 0.5, 0.5)
  backBtn:setLoc(-device.ui_width / 2 + 42, 0)
  backBtn.handleTouch = Button_handleTouch
  local function backBtn_onClick()
    if not screenAction:isActive() then
      shipupgrade_close({back = true})
      local screen = table_remove(screenHistory)
      if screen == "fleet" then
        fleet_show({
          back = true,
          bottom_bar = true,
          store_filter = true
        })
      end
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  backBtn.onClick = backBtn_onClick
  if device.os == device.OS_ANDROID then
    local function callback()
      backBtn_onClick()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  if menuMode ~= "ingame" then
    local menuBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconHome.png"))
    menuBtn._down:setColor(0.5, 0.5, 0.5)
    menuBtn:setLoc(device.ui_width / 2 - 42, 0)
    menuBtn.handleTouch = Button_handleTouch
    function menuBtn:onClick()
      menu_close()
      mainmenu_show()
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  _shipupgrade_root = ui.Group.new()
  if storeMaxUpgrade > profile.unlocks[baseID].currentUpgrade + 1 then
    do
      local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
      if move.bottom_bar then
        bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
        bottomNavBG:seekLoc(0, -device.ui_height / 2 + 120, 0.5, MOAIEaseType.EASE_IN)
      else
        bottomNavBG:setLoc(0, -device.ui_height / 2 + 120)
      end
      _menu_root.bottomNavBG = bottomNavBG
      local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
      bottomNavBGPickBox:setLoc(0, -20)
      local upgradeForText = bottomNavBG:add(ui.TextBox.new(string.format(_("Upgrade %s for"), def.storeName), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      upgradeForText:setLoc(0, 60)
      local iconLarge = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. nextDef.storePurchaseType:gsub("^%l", string.upper) .. "Large.png"))
      iconLarge:setLoc(-40, 12)
      local purchaseCostText = bottomNavBG:add(ui.TextBox.new("" .. nextDef.storePurchaseCost .. "?", FONT_XLARGE, "ffffff", "left", 100, nil, true))
      purchaseCostText:setLoc(65, 7)
      local upgradeBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
      upgradeBtn._up:setColor(unpack(UI_COLOR_YELLOW))
      upgradeBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
      upgradeBtn:setLoc(80, -75)
      local upgradeBtnText = upgradeBtn._up:add(ui.TextBox.new(_("Upgrade!"), FONT_MEDIUM_BOLD, "000000", "center"))
      upgradeBtnText:setColor(0, 0, 0)
      upgradeBtnText:setLoc(0, -2)
      local upgradeBtnText = upgradeBtn._down:add(ui.TextBox.new(_("Upgrade!"), FONT_MEDIUM_BOLD, "000000", "center"))
      upgradeBtnText:setColor(0, 0, 0)
      upgradeBtnText:setLoc(0, -2)
      upgradeBtn.handleTouch = Button_handleTouch
      function upgradeBtn:onClick()
        if not screenAction:isActive() then
          if profile[nextDef.storePurchaseType] >= nextDef.storePurchaseCost then
            _shipupgrade_upgrade(def)
            do
              local val = MENU_BACK_FROM_UPGRADE_TO_SHOP or tostring(""):lower()
              if val == "yes" or val == "on" or val == "true" then
                shipupgrade_close({back = true})
                do
                  local screen = table_remove(screenHistory)
                  if screen == "fleet" then
                    fleet_show({
                      back = true,
                      bottom_bar = true,
                      store_filter = true
                    })
                  end
                end
              else
                shipupgrade_close()
                if profile.unlocks[baseID].currentUpgrade + 1 < storeMaxUpgrade then
                  shipupgrade_show(nil, def)
                else
                  shipupgrade_show({bottom_bar = true}, def)
                end
              end
            end
          else
            _popup_currency_show(nextDef.storePurchaseType, "shipupgrade", true, nil, "upgrade." .. nextDef._id)
          end
        end
      end
      if profile[nextDef.storePurchaseType] < nextDef.storePurchaseCost then
        _menu_root[nextDef.storePurchaseType .. "Text"]:setColor(unpack(UI_COLOR_RED))
      end
      local cancelBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
      cancelBtn._up:setColor(unpack(UI_COLOR_RED))
      cancelBtn._down:setColor(unpack(UI_COLOR_RED_DARKEN))
      cancelBtn:setLoc(-130, -75)
      local cancelBtnText = cancelBtn._up:add(ui.TextBox.new(_("Back"), FONT_SMALL_BOLD, "000000", "center"))
      cancelBtnText:setColor(0, 0, 0)
      cancelBtnText:setLoc(0, -2)
      local cancelBtnText = cancelBtn._down:add(ui.TextBox.new(_("Back"), FONT_SMALL_BOLD, "000000", "center"))
      cancelBtnText:setColor(0, 0, 0)
      cancelBtnText:setLoc(0, -2)
      cancelBtn.handleTouch = Button_handleTouch
      function cancelBtn:onClick()
        if not screenAction:isActive() then
          shipupgrade_close({back = true})
          local screen = table_remove(screenHistory)
          if screen == "fleet" then
            fleet_show({
              back = true,
              bottom_bar = true,
              store_filter = true
            })
          end
          soundmanager.onSFX("onPageSwipeBack")
        end
      end
    end
  else
    local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
    if move.bottom_bar then
      bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
      bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
    else
      bottomNavBG:setLoc(0, -device.ui_height / 2 - 8)
    end
    bottomNavBG.low = true
    _menu_root.bottomNavBG = bottomNavBG
    local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
    bottomNavBGPickBox:setLoc(0, -20)
    local fullyUpgradedText = bottomNavBG:add(ui.TextBox.new(_("Fully Upgraded"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
    fullyUpgradedText:setLoc(0, 50)
  end
  local bg = _shipupgrade_root:add(ui.PickBox.new(device.ui_width, submenu_height))
  bg:setLoc(0, submenu_y)
  bg.handleTouch = _shipinfo_item_handleTouch
  bg.def = def
  local items_group = _shipupgrade_root:add(ui.Group.new())
  bg.items_group = items_group
  local item, item_height = _shipinfo_create_item(def, "shipupgrade")
  items_group:add(item)
  items_group.item_height = item_height
  if move.forward then
    _shipupgrade_root:setLoc(device.ui_width * 2, 0)
    _shipupgrade_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  elseif move.back then
    _shipupgrade_root:setLoc(-device.ui_width * 2, 0)
    _shipupgrade_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  submenuLayer:add(_shipupgrade_root)
  shipInfoDef = def
  curScreen = "shipupgrade"
end
local function _shippurchase_purchase(def)
  local baseID = def._baseID
  local itemId = "ship." .. def._id
  profile.unlocks[baseID] = {
    unlocked = true,
    currentUpgrade = 0,
    popupUnlock = true
  }
  profile_currency_txn(def.storePurchaseType, -def.storePurchaseCost, "Shop: " .. itemId, true)
  analytics.gameShopPurchaseSuccess(itemId, def.storePurchaseType, def.storePurchaseCost, profile_get_level_id())
  if SixWaves then
    SixWaves.trackInGameItemPurchase(itemId, {
      price = def.storePurchaseCos,
      category = "ship_purchase",
      priceType = def.storePurchaseType,
      leveid = profile_get_level_id()
    })
  end
  _storemenu_refresh()
  soundmanager.onSFX("onPurchase")
end
function shippurchase_close(move)
  if move == nil then
    move = {empty = true}
  end
  _menu_root:remove(_menu_root.topBarBG)
  _menu_root.topBarBG = nil
  _storemenu_close({
    store_menu = move.store_menu
  })
  if move.bottom_bar then
    do
      local action = _menu_root.bottomNavBG:seekLoc(0, -device.ui_height / 2 - 120, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        _menu_root:remove(_menu_root.bottomNavBG)
        _menu_root.bottomNavBG = nil
      end)
    end
  else
    _menu_root:remove(_menu_root.bottomNavBG)
    _menu_root.bottomNavBG = nil
  end
  if move.forward then
    do
      local action = _shippurchase_root:seekLoc(-device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_shippurchase_root)
        _shippurchase_root = nil
      end)
    end
  elseif move.back then
    do
      local action = _shippurchase_root:seekLoc(device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_shippurchase_root)
        _shippurchase_root = nil
      end)
    end
  else
    submenuLayer:remove(_shippurchase_root)
    _shippurchase_root = nil
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  if scrollbar and scrollAction ~= nil then
    scrollAction:stop()
    scrollAction = nil
  end
  scrollbar = nil
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  curScreen = nil
end
function shippurchase_show(move, def)
  if move == nil then
    move = {empty = true}
  end
  local submenu_height = device.ui_height - 100 - 230 - 60
  local submenu_y = 35
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  _storemenu_show("shippurchase")
  local topBarBG = _menu_root:add(ui.Image.new("menuTopBars.atlas.png#topBarPurchaseShip.png"))
  if not profile.excludeAds then
    topBarBG:setLoc(0, device.ui_height / 2 - 150)
  else
    topBarBG:setLoc(0, device.ui_height / 2 - 50)
  end
  _menu_root.topBarBG = topBarBG
  local topBarBGPickBox = topBarBG:add(ui.PickBox.new(device.ui_width, 100))
  local topBarText = topBarBG:add(ui.TextBox.new(_("Purchase Ship"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  topBarText:setLoc(0, -6)
  local backBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconBack.png"))
  backBtn._down:setColor(0.5, 0.5, 0.5)
  backBtn:setLoc(-device.ui_width / 2 + 42, 0)
  backBtn.handleTouch = Button_handleTouch
  local function backBtn_onClick()
    if not screenAction:isActive() then
      shippurchase_close({back = true})
      local screen = table_remove(screenHistory)
      if screen == "fleet" then
        fleet_show({
          back = true,
          bottom_bar = true,
          store_filter = true
        })
      end
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  backBtn.onClick = backBtn_onClick
  if device.os == device.OS_ANDROID then
    local function callback()
      backBtn_onClick()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  if menuMode ~= "ingame" then
    local menuBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconHome.png"))
    menuBtn._down:setColor(0.5, 0.5, 0.5)
    menuBtn:setLoc(device.ui_width / 2 - 42, 0)
    menuBtn.handleTouch = Button_handleTouch
    function menuBtn:onClick()
      menu_close()
      mainmenu_show()
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  _shippurchase_root = ui.Group.new()
  local survivorWave = levelSurvivorWave or 0
  if survivorWave < profile.levelSurvivorWave then
    survivorWave = profile.levelSurvivorWave
  end
  if not (profile.level >= def.storeUnlockLevel) then
  elseif survivorWave >= (def.storeMinWave or 0) then
      do
        local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
        if move.bottom_bar then
          bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
          bottomNavBG:seekLoc(0, -device.ui_height / 2 + 120, 0.5, MOAIEaseType.EASE_IN)
        else
          bottomNavBG:setLoc(0, -device.ui_height / 2 + 120)
        end
        _menu_root.bottomNavBG = bottomNavBG
        local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
        bottomNavBGPickBox:setLoc(0, -20)
        local buyForText = bottomNavBG:add(ui.TextBox.new(string.format(_("Buy %s for"), def.storeName), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
        buyForText:setLoc(0, 60)
        local iconLarge = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. def.storePurchaseType:gsub("^%l", string.upper) .. "Large.png"))
        iconLarge:setLoc(-40, 12)
        local purchaseCostText = bottomNavBG:add(ui.TextBox.new("" .. def.storePurchaseCost .. "?", FONT_XLARGE, "ffffff", "left", 100, nil, true))
        purchaseCostText:setLoc(65, 7)
        local buyBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
        buyBtn._up:setColor(unpack(UI_COLOR_YELLOW))
        buyBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
        buyBtn:setLoc(80, -75)
        local buyBtnText = buyBtn._up:add(ui.TextBox.new(_("Buy Ship!"), FONT_MEDIUM_BOLD, "000000", "center"))
        buyBtnText:setColor(0, 0, 0)
        buyBtnText:setLoc(0, -2)
        local buyBtnText = buyBtn._down:add(ui.TextBox.new(_("Buy Ship!"), FONT_MEDIUM_BOLD, "000000", "center"))
        buyBtnText:setColor(0, 0, 0)
        buyBtnText:setLoc(0, -2)
        buyBtn.handleTouch = Button_handleTouch
        function buyBtn:onClick()
          if not screenAction:isActive() then
            if profile[def.storePurchaseType] >= def.storePurchaseCost then
              _shippurchase_purchase(def)
              _popup_shippurchase_show("shippurchase", def, true)
              do
                local baseID = def._id:gsub("_%d$", "")
                popups.show("on_ship_unlock_" .. baseID, true)
                achievements.update("first_purchase", 1, true, true)
              end
            else
              _popup_currency_show(def.storePurchaseType, "shippurchase", true, nil, "buy." .. def._id)
            end
          end
        end
        if profile[def.storePurchaseType] < def.storePurchaseCost then
          _menu_root[def.storePurchaseType .. "Text"]:setColor(unpack(UI_COLOR_RED))
        end
        local cancelBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
        cancelBtn._up:setColor(unpack(UI_COLOR_RED))
        cancelBtn._down:setColor(unpack(UI_COLOR_RED_DARKEN))
        cancelBtn:setLoc(-130, -75)
        local cancelBtnText = cancelBtn._up:add(ui.TextBox.new(_("Back"), FONT_SMALL_BOLD, "000000", "center"))
        cancelBtnText:setColor(0, 0, 0)
        cancelBtnText:setLoc(0, -2)
        local cancelBtnText = cancelBtn._down:add(ui.TextBox.new(_("Back"), FONT_SMALL_BOLD, "000000", "center"))
        cancelBtnText:setColor(0, 0, 0)
        cancelBtnText:setLoc(0, -2)
        cancelBtn.handleTouch = Button_handleTouch
        function cancelBtn:onClick()
          if not screenAction:isActive() then
            shippurchase_close({back = true})
            local screen = table_remove(screenHistory)
            if screen == "fleet" then
              fleet_show({
                back = true,
                bottom_bar = true,
                store_filter = true
              })
            end
            soundmanager.onSFX("onPageSwipeBack")
          end
        end
      end
  else
    local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
    if move.bottom_bar then
      bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
      bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
    else
      bottomNavBG:setLoc(0, -device.ui_height / 2 - 8)
    end
    bottomNavBG.low = true
    _menu_root.bottomNavBG = bottomNavBG
    local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
    bottomNavBGPickBox:setLoc(0, -20)
    if profile.level < def.storeUnlockLevel then
      if def.storeMinWave ~= nil then
      elseif survivorWave >= (def.storeMinWave or 0) then
        do
          local requiresLevelText = bottomNavBG:add(ui.TextBox.new(string.format(_("Requires Level %d"), def.storeUnlockLevel), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
          requiresLevelText:setColor(unpack(UI_COLOR_GRAY))
          requiresLevelText:setLoc(0, 45)
        end
      end
    elseif profile.level > def.storeUnlockLevel and def.storeMinWave ~= nil then
      if survivorWave < (def.storeMinWave or 0) then
        do
          local requiresLevelText = bottomNavBG:add(ui.TextBox.new(string.format(_("Requires Survival Wave %d"), def.storeMinWave), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
          requiresLevelText:setColor(unpack(UI_COLOR_GRAY))
          requiresLevelText:setLoc(0, 45)
        end
      end
    elseif profile.level < def.storeUnlockLevel and def.storeMinWave ~= nil then
      if survivorWave < (def.storeMinWave or 0) then
        local requiresLevelText = bottomNavBG:add(ui.TextBox.new(string.format(_("Requires Level %d or"), def.storeUnlockLevel), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
        requiresLevelText:setColor(unpack(UI_COLOR_GRAY))
        requiresLevelText:setLoc(0, 60)
        local requiresLevelText = bottomNavBG:add(ui.TextBox.new(string.format(_("Requires Survival Wave %d"), def.storeMinWave), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
        requiresLevelText:setColor(unpack(UI_COLOR_GRAY))
        requiresLevelText:setLoc(0, 30)
      end
    end
    local iconLockedLeft = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#iconLockedLarge.png"))
    iconLockedLeft:setColor(unpack(UI_COLOR_GRAY))
    iconLockedLeft:setLoc(-200, 45)
    local iconLockedRight = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#iconLockedLarge.png"))
    iconLockedRight:setColor(unpack(UI_COLOR_GRAY))
    iconLockedRight:setLoc(200, 45)
  end
  local bg = _shippurchase_root:add(ui.PickBox.new(device.ui_width, submenu_height))
  bg:setLoc(0, submenu_y)
  bg.handleTouch = _shipinfo_item_handleTouch
  bg.def = def
  local items_group = _shippurchase_root:add(ui.Group.new())
  bg.items_group = items_group
  local item, item_height = _shipinfo_create_item(def, "shippurchase")
  items_group:add(item)
  items_group.item_height = item_height
  if move.forward then
    _shippurchase_root:setLoc(device.ui_width * 2, 0)
    _shippurchase_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  elseif move.back then
    _shippurchase_root:setLoc(-device.ui_width * 2, 0)
    _shippurchase_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  submenuLayer:add(_shippurchase_root)
  shipInfoDef = def
  curScreen = "shippurchase"
end
local function _fleet_items_handleTouch(self, eventType, touchIdx, x, y, tapCount, exclude_capture)
  local submenu_height = device.ui_height - 100 - 90 - 60 - 104
  local submenu_y = -87
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local items_group = self.items_group
  if eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    if 0 < math.max(items_group.numItems * items_group.item_height - submenu_height, 0) then
      if not exclude_capture then
        ui.capture(self)
      end
      scrolling = true
      lastX = x
      lastY = y
      diffX = 0
      diffY = 0
      if scrollbar == nil then
        scrollbar = ui.Group.new()
        do
          local scrollbar_fill = scrollbar:add(ui.Image.new("scrollbar_fill.png"))
          scrollbar_fill:setScl(1, 3.5)
          scrollbar.fill = scrollbar_fill
          local scrollbar_top = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_top:setLoc(0, 36)
          scrollbar.top = scrollbar_top
          local scrollbar_bot = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_bot:setLoc(0, -36)
          scrollbar_bot:setScl(1, -1)
          scrollbar.bot = scrollbar_bot
          local groupX, groupY = items_group:getLoc()
          local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
          scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70) + submenu_y)
          scrollbar.fill:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.top:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.bot:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          _fleet_root:add(scrollbar)
        end
      else
        if scrollbar_fadeOutActions.fill ~= nil and scrollbar_fadeOutActions.fill:isActive() then
          scrollbar_fadeOutActions.fill:stop()
          scrollbar_fadeOutActions.top:stop()
          scrollbar_fadeOutActions.bot:stop()
        end
        scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
      end
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
  elseif eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    if not exclude_capture then
      ui.capture(nil)
    end
    scrolling = false
    if scrollbar ~= nil and scrollbar.velocityY ~= nil then
      scrollbar.velocityY = scrollbar.velocityY + diffY
    elseif scrollbar ~= nil then
      scrollbar.velocityY = diffY
    end
    if scrollAction == nil then
      scrollAction = uiAS:wrap(function(dt)
        if scrollbar ~= nil then
          do
            local groupX, groupY = items_group:getLoc()
            local newY = util.clamp(groupY - scrollbar.velocityY, 0, math.max(items_group.numItems * items_group.item_height - submenu_height, 0))
            items_group:setLoc(0, util.roundNumber(newY))
            _menu_root.fleet_items_group_y = util.roundNumber(newY)
            local groupX, groupY = items_group:getLoc()
            local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
            scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70) + submenu_y)
            scrollbar.velocityY = scrollbar.velocityY + scrollbar.velocityY * -1 * dt * 0.03 * device.dpi
            if not scrolling and abs(scrollbar.velocityY) < 0.5 then
              scrollAction:stop()
              scrollAction = nil
            end
          end
        else
          scrollAction:stop()
          scrollAction = nil
        end
      end, function()
        if not scrolling and scrollbar ~= nil then
          if scrollbar_fadeInActions.fill ~= nil and scrollbar_fadeInActions.fill:isActive() then
            scrollbar_fadeInActions.fill:stop()
            scrollbar_fadeInActions.top:stop()
            scrollbar_fadeInActions.bot:stop()
          end
          scrollbar_fadeOutActions.fill = scrollbar.fill:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.top = scrollbar.top:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.bot = scrollbar.bot:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.fill:setListener(MOAITimer.EVENT_STOP, function()
            if not scrolling and _fleet_root ~= nil then
              _fleet_root:remove(scrollbar)
              scrollbar = nil
            end
          end)
        end
      end)
    end
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE and scrolling then
    diffY = lastY - y
    local groupX, groupY = items_group:getLoc()
    local newY = util.clamp(groupY - diffY, 0, math.max(items_group.numItems * items_group.item_height - submenu_height, 0))
    items_group:setLoc(0, util.roundNumber(newY))
    _menu_root.fleet_items_group_y = util.roundNumber(newY)
    if scrollbar ~= nil then
      local groupX, groupY = items_group:getLoc()
      local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
      scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70) + submenu_y)
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
    lastX = x
    lastY = y
  end
  return true
end
local function _fleet_item_button_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  if eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    ui.capture(nil)
  elseif eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    self._isdown = true
    ui.capture(self)
    startX, startY = self:modelToWorld(x, y)
    do
      local action
      action = uiAS:run(function(dt, t)
        if buttonAction == nil then
          if action ~= nil then
            action:stop()
          end
          action = nil
        end
        buttonAction.t = t
        if self._isdown and self.currentPageName == "up" and t > 0.2 then
          self:showPage("down")
          self.textBG:showPage("down")
        elseif t > 1 then
          self:showPage("up")
          self.textBG:showPage("up")
          self._isdown = nil
          buttonAction:stop()
          buttonAction = nil
        end
      end)
      buttonAction = action
      buttonAction.t = 0
    end
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE then
    if self._isdown and not ui.treeCheck(x, y, self) then
      self:showPage("up")
      self.textBG:showPage("up")
      self._isdown = nil
      if buttonAction ~= nil then
        buttonAction:stop()
        buttonAction = nil
      end
    end
    local wx, wy = self:modelToWorld(x, y)
    if self._isdown and abs(startY - wy) > 25 then
      self:showPage("up")
      self.textBG:showPage("up")
      self._isdown = nil
      if buttonAction ~= nil then
        buttonAction:stop()
        buttonAction = nil
      end
    end
  end
  local wx, wy = self:modelToWorld(x, y)
  local mx, my = _fleet_root.bg:worldToModel(wx, wy)
  _fleet_items_handleTouch(_fleet_root.bg, eventType, touchIdx, mx, my, tapCount, true)
  return true
end
local function _fleet_create_item(def, items)
  local upgradeNum = def._upgradeNum
  if upgradeNum ~= 0 then
    return false
  end
  if not def.storeTexture then
    return false
  end
  local baseID = def._baseID
  local lastCompletedGalaxy, lastCompletedSystem, lastCompletedIndex = _get_last_completed_galaxy_system()
  if (profile.unlocks[baseID] == nil or not profile.unlocks[baseID].unlocked) and lastCompletedIndex < def.storeMinSystem then
    return false
  end
  local filter = _fleet_root.filter
  if filter ~= "all" then
    if not def.storeTags then
      return false
    end
    if filter == "fighters" then
      if not def.storeTags.fighter then
        return false
      end
    elseif filter == "interceptors" then
      if not def.storeTags.interceptor then
        return false
      end
    elseif filter == "bombers" then
      if not def.storeTags.bomber then
        return false
      end
    elseif filter == "defense" then
      if not def.storeTags.harvester then
        return false
      end
    elseif filter == "special" and not def.storeTags.cannon then
      return false
    end
  end
  local item = ui.Group.new()
  local itemBox = item:add(ui.NinePatch.new("boxStoreItem9p.lua", device.ui_width, 250))
  itemBox:setLoc(0, 1)
  local itemBG = item:add(ui.Button.new(ui.PickBox.new(device.ui_width, 250)))
  itemBG._up.handleTouch = nil
  itemBG._down.handleTouch = nil
  itemBG.handleTouch = _fleet_item_button_handleTouch
  local ship = item:add(ui.Image.new(def.storeTexture[1]))
  ship:setLoc(-device.ui_width / 2 + 160, 45)
  ship:setRot(-90)
  local textBG = item:add(ui.Button.new(ui.PickBox.new(device.ui_width, 90), ui.PickBox.new(device.ui_width, 90, "000000aa")))
  textBG:setLoc(0, -78)
  textBG._up.handleTouch = nil
  textBG._down.handleTouch = nil
  textBG.handleTouch = nil
  itemBG.textBG = textBG
  local nameText = textBG:add(ui.TextBox.new(_(def.storeName .. " " .. def.storeClass), FONT_MEDIUM_BOLD, "ffffff", "left", device.ui_width - 20, nil, true))
  nameText:setLoc(0, 18)
  local descriptionText = textBG:add(ui.TextBox.new(_(def.storeDescription), FONT_MEDIUM, "ffffff", "left", device.ui_width - 20, nil, true))
  descriptionText:setColor(unpack(UI_COLOR_GRAY))
  descriptionText:setLoc(0, -18)
  local menuNextPageIcon = textBG:add(ui.Image.new("menuTemplate.atlas.png#menuNextPageIcon.png"))
  menuNextPageIcon:setColor(unpack(UI_COLOR_GRAY))
  menuNextPageIcon:setLoc(device.ui_width / 2 - 32, 0)
  textBG.menuNextPageIcon = menuNextPageIcon
  local icon
  if baseID == "SPC" then
    icon = item:add(ui.Image.new("storeScreen.atlas.png#storeSelectorSPC.png"))
  else
    local subentityStr, queryStr = breakstr(def.subentities[1], "?")
    local subentity = entitydef[subentityStr]
    if subentity.type:find("cannon") then
      icon = item:add(ui.Image.new("storeScreen.atlas.png#gunshipTurretBasic.png"))
      icon:setColor(unpack(UI_SHIP_COLOR_SPECIAL))
    elseif subentity.type == "module" then
      local hangarentity = entitydef[subentity.hangarInventoryType]
      if hangarentity.type == "fighter" then
        icon = item:add(ui.Image.new(string.format("storeScreen.atlas.png#%s.png", _getFighterFrame(def.storeTags))))
        do
          local r, g, b = color.parse(subentity.pathColor)
          icon:setColor(r, g, b)
          local hangarship = icon:add(ui.Image.new(hangarentity.storeTexture))
          hangarship:clearAttrLink(MOAIColor.INHERIT_COLOR)
          hangarship:setRot(-90)
          icon.hangarship = hangarship
        end
      elseif hangarentity.type == "harvester" then
        icon = item:add(ui.Image.new("storeScreen.atlas.png#storeSelectorMiner.png"))
        local r, g, b = color.parse(subentity.pathColor)
        icon:setColor(r, g, b)
        local hangarship = icon:add(ui.Image.new(hangarentity.storeTexture))
        hangarship:clearAttrLink(MOAIColor.INHERIT_COLOR)
        hangarship:setRot(-90)
        icon.hangarship = hangarship
      end
    end
  end
  icon:setLoc(device.ui_width / 2 - 240, 45)
  if profile.unlocks[baseID] == nil then
    profile.unlocks[baseID] = {unlocked = false}
    profile:save()
  end
  if not profile.unlocks[baseID].unlocked then
    do
      local costBG = item:add(ui.Image.new("menuTemplate.atlas.png#storeItemInfoPanel.png"))
      costBG:setLoc(device.ui_width / 2 - 95, 74)
      local costIcon = costBG:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. def.storePurchaseType:gsub("^%l", string.upper) .. ".png"))
      costIcon:setLoc(-35, 2)
      local costText = costBG:add(ui.TextBox.new(util.commasInNumbers(def.storePurchaseCost), FONT_MEDIUM, "ffffff", "left", 60, nil, true))
      costText:setLoc(25, 0)
      local buyBtn = item:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
      buyBtn._up:setColor(unpack(UI_COLOR_YELLOW))
      buyBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
      buyBtn:setLoc(device.ui_width / 2 - 95, 6)
      local buyBtnText = buyBtn._up:add(ui.TextBox.new(_("BUY"), FONT_MEDIUM_BOLD, "000000", "center"))
      buyBtnText:setColor(0, 0, 0)
      buyBtnText:setLoc(0, -2)
      local buyBtnText = buyBtn._down:add(ui.TextBox.new(_("BUY"), FONT_MEDIUM_BOLD, "000000", "center"))
      buyBtnText:setColor(0, 0, 0)
      buyBtnText:setLoc(0, -2)
      buyBtn.handleTouch = Button_handleTouch
      function buyBtn:onClick()
        if not screenAction:isActive() then
          table_insert(screenHistory, "fleet")
          fleet_close({forward = true, store_filter = true})
          shippurchase_show({forward = true, bottom_bar = true}, def)
          soundmanager.onSFX("onPageSwipeForward")
        end
      end
      function itemBG:onClick()
        if not screenAction:isActive() then
          table_insert(screenHistory, "fleet")
          fleet_close({forward = true, store_filter = true})
          shippurchase_show({forward = true, bottom_bar = true}, def)
          soundmanager.onSFX("onPageSwipeForward")
        end
      end
      local survivorWave = levelSurvivorWave or 0
      if survivorWave < profile.levelSurvivorWave then
        survivorWave = profile.levelSurvivorWave
      end
      if not (profile.level < def.storeUnlockLevel) or def.storeMinWave ~= nil then
      elseif survivorWave < (def.storeMinWave or 0) then
        if profile.level < def.storeUnlockLevel then
          if def.storeMinWave ~= nil then
          elseif survivorWave >= (def.storeMinWave or 0) then
            do
              local lockedLevelBG = item:add(ui.Image.new("menuTemplate.atlas.png#storeItemLockedPanel.png"))
              lockedLevelBG:setLoc(0, 45)
              local lockedLevelText = lockedLevelBG:add(ui.TextBox.new(string.format(_("Level %d"), def.storeUnlockLevel), FONT_MEDIUM_BOLD, "ffffff", "left", 160, nil, true))
              lockedLevelText:setColor(unpack(UI_COLOR_GRAY))
              lockedLevelText:setLoc(70, 0)
            end
          end
        elseif profile.level > def.storeUnlockLevel and def.storeMinWave ~= nil then
          if survivorWave < (def.storeMinWave or 0) then
            do
              local lockedLevelBG = item:add(ui.Image.new("menuTemplate.atlas.png#storeItemLockedPanel.png"))
              lockedLevelBG:setLoc(0, 45)
              local lockedLevelText = lockedLevelBG:add(ui.TextBox.new(_("Survival Wave"), FONT_SMALL_BOLD, "ffffff", "left", 80, nil, true))
              lockedLevelText:setColor(unpack(UI_COLOR_GRAY))
              lockedLevelText:setLoc(30, 0)
              local lockedLevelNumText = lockedLevelBG:add(ui.TextBox.new("" .. def.storeMinWave, FONT_SMALL_BOLD, "ffffff", "left", 80, nil, true))
              lockedLevelNumText:setColor(unpack(UI_COLOR_GRAY))
              lockedLevelNumText:setLoc(115, 0)
            end
          end
        elseif profile.level < def.storeUnlockLevel and def.storeMinWave ~= nil then
          if survivorWave < (def.storeMinWave or 0) then
            local lockedLevelBG = item:add(ui.Image.new("menuTemplate.atlas.png#storeItemLockedPanel.png"))
            lockedLevelBG:setLoc(0, 45)
            local lockedLevelText = lockedLevelBG:add(ui.TextBox.new(string.format(_("Level %d or"), def.storeUnlockLevel), FONT_SMALL_BOLD, "ffffff", "left", 160, nil, true))
            lockedLevelText:setColor(unpack(UI_COLOR_GRAY))
            lockedLevelText:setLoc(70, 20)
            local lockedLevelText = lockedLevelBG:add(ui.TextBox.new(_("Survival Wave"), FONT_SMALL_BOLD, "ffffff", "left", 80, nil, true))
            lockedLevelText:setColor(unpack(UI_COLOR_GRAY))
            lockedLevelText:setLoc(30, -20)
            local lockedLevelNumText = lockedLevelBG:add(ui.TextBox.new("" .. def.storeMinWave, FONT_SMALL_BOLD, "ffffff", "left", 80, nil, true))
            lockedLevelNumText:setColor(unpack(UI_COLOR_GRAY))
            lockedLevelNumText:setLoc(115, -20)
          end
        end
        ship:setColor(0.5, 0.5, 0.5, 0.5)
        costBG:setColor(0.5, 0.5, 0.5, 0.5)
        buyBtn._up:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
        buyBtn.handleTouch = nil
        if baseID == "SPC" then
          icon:setColor(0.5, 0.5, 0.5, 0.5)
        else
          local subentityStr, queryStr = breakstr(def.subentities[1], "?")
          local subentity = entitydef[subentityStr]
          if subentity.type:find("cannon") then
            icon:setColor(0.5, 0.25, 0.07, 0.5)
          elseif subentity.type == "module" then
            local hangarentity = entitydef[subentity.hangarInventoryType]
            if hangarentity.type == "fighter" then
              do
                local r, g, b = color.parse(subentity.pathColor)
                icon:setColor(r / 2, g / 2, b / 2, 0.5)
                icon.hangarship:setColor(0.5, 0.5, 0.5, 0.5)
              end
            elseif hangarentity.type == "harvester" then
              local r, g, b = color.parse(subentity.pathColor)
              icon:setColor(r / 2, g / 2, b / 2, 0.5)
              icon.hangarship:setColor(0.5, 0.5, 0.5, 0.5)
            end
          end
        end
      end
      local survivorWave = levelSurvivorWave or 0
      if survivorWave < profile.levelSurvivorWave then
        survivorWave = profile.levelSurvivorWave
      end
      if not profile.unlocks[baseID].popupUnlock then
        if not (profile.level >= def.storeUnlockLevel) then
        elseif survivorWave >= (def.storeMinWave or 0) then
          uiAS:delaycall(0.5, _popup_shipunlock_show, _menu_root, def, true)
          profile.unlocks[baseID].popupUnlock = true
          profile:save()
        end
      end
    end
  else
    local storeMaxUpgrade = 0
    for i, v in pairs(entitydef) do
      if v.type == "capitalship" and v._id:sub(1, baseID:len()) == baseID then
        storeMaxUpgrade = storeMaxUpgrade + 1
      end
    end
    local curDef = entitydef[baseID .. "_" .. profile.unlocks[baseID].currentUpgrade]
    local nextDef = entitydef[baseID .. "_" .. profile.unlocks[baseID].currentUpgrade + 1]
    if storeMaxUpgrade <= profile.unlocks[baseID].currentUpgrade + 1 then
      nextDef = curDef
    end
    local storeItemOwned = item:add(ui.Image.new("menuTemplate.atlas.png#storeItemOwned.png"))
    storeItemOwned:setLoc(-device.ui_width / 2 + 40, 90)
    local upgradeNumText = storeItemOwned:add(ui.TextBox.new("" .. profile.unlocks[baseID].currentUpgrade + 1, FONT_MEDIUM_BOLD, "ffffff", "center"))
    upgradeNumText:setColor(0, 0, 0)
    upgradeNumText:setLoc(0, 5)
    local upgradeBG = item:add(ui.Image.new("menuTemplate.atlas.png#storeItemInfoPanel.png"))
    upgradeBG:setLoc(device.ui_width / 2 - 95, 74)
    local upgradeBtn
    if storeMaxUpgrade > profile.unlocks[baseID].currentUpgrade + 1 then
      do
        local costIcon = upgradeBG:add(ui.Image.new("menuTemplateShared.atlas.png#icon" .. nextDef.storePurchaseType:gsub("^%l", string.upper) .. ".png"))
        costIcon:setLoc(-35, 2)
        local costText = upgradeBG:add(ui.TextBox.new(util.commasInNumbers(nextDef.storePurchaseCost), FONT_MEDIUM, "ffffff", "left", 60, nil, true))
        costText:setLoc(25, 0)
        upgradeBtn = item:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
        upgradeBtn._up:setColor(unpack(UI_COLOR_YELLOW))
        upgradeBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
        upgradeBtn:setLoc(device.ui_width / 2 - 95, 6)
        local upgradeBtnText = upgradeBtn._up:add(ui.TextBox.new(_("Upgrade"), FONT_SMALL_BOLD, "000000", "center"))
        upgradeBtnText:setColor(0, 0, 0)
        upgradeBtnText:setLoc(0, -2)
        local upgradeBtnText = upgradeBtn._down:add(ui.TextBox.new(_("Upgrade"), FONT_SMALL_BOLD, "000000", "center"))
        upgradeBtnText:setColor(0, 0, 0)
        upgradeBtnText:setLoc(0, -2)
        upgradeBtn.handleTouch = Button_handleTouch
        function upgradeBtn:onClick()
          if not screenAction:isActive() then
            table_insert(screenHistory, "fleet")
            fleet_close({forward = true, store_filter = true})
            shipupgrade_show({forward = true, bottom_bar = true}, def)
            soundmanager.onSFX("onUpgradeAnticipation")
          end
        end
      end
    else
      local maxText = upgradeBG:add(ui.TextBox.new(_("MAX"), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
      upgradeBtn = item:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
      upgradeBtn._up:setColor(unpack(UI_COLOR_YELLOW))
      upgradeBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
      upgradeBtn:setLoc(device.ui_width / 2 - 95, 6)
      local upgradeBtnText = upgradeBtn._up:add(ui.TextBox.new(_("Info"), FONT_MEDIUM_BOLD, "000000", "center"))
      upgradeBtnText:setColor(0, 0, 0)
      upgradeBtnText:setLoc(0, -2)
      local upgradeBtnText = upgradeBtn._down:add(ui.TextBox.new(_("Info"), FONT_MEDIUM_BOLD, "000000", "center"))
      upgradeBtnText:setColor(0, 0, 0)
      upgradeBtnText:setLoc(0, -2)
      upgradeBtn.handleTouch = Button_handleTouch
      function upgradeBtn:onClick()
        if not screenAction:isActive() then
          table_insert(screenHistory, "fleet")
          fleet_close({forward = true, store_filter = true})
          shipupgrade_show({forward = true, bottom_bar = true}, def)
          soundmanager.onSFX("onUpgradeAnticipation")
        end
      end
    end
    function itemBG:onClick()
      if not screenAction:isActive() then
        table_insert(screenHistory, "fleet")
        fleet_close({forward = true, store_filter = true})
        shipupgrade_show({forward = true, bottom_bar = true}, def)
        soundmanager.onSFX("onUpgradeAnticipation")
      end
    end
  end
  if not popups.show("on_show_" .. baseID .. "_shop", true) then
    popups.show("on_show_shop", true)
  end
  item.def = def
  table_insert(items, item)
  return false
end
local function _fleet_items_compare(a, b)
  local aBaseID = a.def._baseID
  local bBaseID = b.def._baseID
  local aProfile = profile.unlocks[aBaseID]
  local bProfile = profile.unlocks[bBaseID]
  local aBaseDef = entitydef[aBaseID .. "_0"]
  local bBaseDef = entitydef[bBaseID .. "_0"]
  if gameMode == "galaxy" then
    if aBaseDef.storeUnlockLevel == bBaseDef.storeUnlockLevel then
      if aBaseDef.storePurchaseType == bBaseDef.storePurchaseType then
        return aBaseDef.storePurchaseCost < bBaseDef.storePurchaseCost
      elseif aBaseDef.storePurchaseType == "creds" then
        return true
      elseif bBaseDef.storePurchaseType == "creds" then
        return false
      end
    else
      return aBaseDef.storeUnlockLevel < bBaseDef.storeUnlockLevel
    end
  elseif gameMode == "survival" then
    if aBaseDef.storeUnlockLevel == bBaseDef.storeUnlockLevel then
      if aBaseDef.storePurchaseType == bBaseDef.storePurchaseType then
        return aBaseDef.storePurchaseCost < bBaseDef.storePurchaseCost
      elseif aBaseDef.storePurchaseType == "creds" then
        return true
      elseif bBaseDef.storePurchaseType == "creds" then
        return false
      end
    else
      return aBaseDef.storeUnlockLevel < bBaseDef.storeUnlockLevel
    end
  end
end
local function _fleet_refresh_filter(filter)
  local submenu_height = device.ui_height - 100 - 90 - 60 - 104
  local submenu_y = -87
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local storeFiltersBG = _menu_root.storeFiltersBG
  local allBtn = storeFiltersBG.allBtn
  local fightersBtn = storeFiltersBG.fightersBtn
  local interceptorsBtn = storeFiltersBG.interceptorsBtn
  local bombersBtn = storeFiltersBG.bombersBtn
  local defenseBtn = storeFiltersBG.defenseBtn
  local specialBtn = storeFiltersBG.specialBtn
  local frame = storeFiltersBG.frame
  _fleet_root.filter = filter
  _menu_root.fleet_filter = filter
  allBtn._up:setColor(unpack(UI_SHIP_COLOR_ALL_DARKEN))
  allBtn._down:setColor(unpack(UI_SHIP_COLOR_ALL))
  allBtn.handleTouch = Button_handleTouch
  fightersBtn._up:setColor(unpack(UI_SHIP_COLOR_FIGHTERS_DARKEN))
  fightersBtn._down:setColor(unpack(UI_SHIP_COLOR_FIGHTERS))
  fightersBtn.handleTouch = Button_handleTouch
  interceptorsBtn._up:setColor(unpack(UI_SHIP_COLOR_INTERCEPTORS_DARKEN))
  interceptorsBtn._down:setColor(unpack(UI_SHIP_COLOR_INTERCEPTORS))
  interceptorsBtn.handleTouch = Button_handleTouch
  bombersBtn._up:setColor(unpack(UI_SHIP_COLOR_BOMBERS_DARKEN))
  bombersBtn._down:setColor(unpack(UI_SHIP_COLOR_BOMBERS))
  bombersBtn.handleTouch = Button_handleTouch
  defenseBtn._up:setColor(unpack(UI_SHIP_COLOR_DEFENSE_DARKEN))
  defenseBtn._down:setColor(unpack(UI_SHIP_COLOR_DEFENSE))
  defenseBtn.handleTouch = Button_handleTouch
  specialBtn._up:setColor(unpack(UI_SHIP_COLOR_SPECIAL_DARKEN))
  specialBtn._down:setColor(unpack(UI_SHIP_COLOR_SPECIAL))
  specialBtn.handleTouch = Button_handleTouch
  if filter == "all" then
    frame:setLoc(allBtn:getLoc())
    frame:setColor(unpack(UI_SHIP_COLOR_ALL))
    allBtn._up:setColor(unpack(UI_SHIP_COLOR_ALL))
    allBtn.handleTouch = nil
  elseif filter == "fighters" then
    frame:setLoc(fightersBtn:getLoc())
    frame:setColor(unpack(UI_SHIP_COLOR_FIGHTERS))
    fightersBtn._up:setColor(unpack(UI_SHIP_COLOR_FIGHTERS))
    fightersBtn.handleTouch = nil
  elseif filter == "interceptors" then
    frame:setLoc(interceptorsBtn:getLoc())
    frame:setColor(unpack(UI_SHIP_COLOR_INTERCEPTORS))
    interceptorsBtn._up:setColor(unpack(UI_SHIP_COLOR_INTERCEPTORS))
    interceptorsBtn.handleTouch = nil
  elseif filter == "bombers" then
    frame:setLoc(bombersBtn:getLoc())
    frame:setColor(unpack(UI_SHIP_COLOR_BOMBERS))
    bombersBtn._up:setColor(unpack(UI_SHIP_COLOR_BOMBERS))
    bombersBtn.handleTouch = nil
  elseif filter == "defense" then
    frame:setLoc(defenseBtn:getLoc())
    frame:setColor(unpack(UI_SHIP_COLOR_DEFENSE))
    defenseBtn._up:setColor(unpack(UI_SHIP_COLOR_DEFENSE))
    defenseBtn.handleTouch = nil
  elseif filter == "special" then
    frame:setLoc(specialBtn:getLoc())
    frame:setColor(unpack(UI_SHIP_COLOR_SPECIAL))
    specialBtn._up:setColor(unpack(UI_SHIP_COLOR_SPECIAL))
    specialBtn.handleTouch = nil
  end
  local bg = _fleet_root.bg
  if bg.items_group ~= nil then
    bg.items_group:remove()
    bg.items_group = nil
  end
  local items_group = _fleet_root:add(ui.Group.new())
  bg.items_group = items_group
  local items = {}
  local bail, item = _foreach_def_of_type("capitalship", _fleet_create_item, items)
  table_sort(items, _fleet_items_compare)
  local y = submenu_height / 2 + submenu_y - 124
  local def_y
  for i, v in ipairs(items) do
    items_group:add(v)
    v:setLoc(0, y)
    v:forceUpdate()
    if def ~= nil and v.def._baseID == def._baseID then
      def_y = -y - (submenu_height / 2 + submenu_y - 124)
    end
    y = y - 250
  end
  _fleet_root.def_y = def_y
  items_group.numItems = #items
  items_group.item_height = 250
  _fleet_root.items = items
  if items_group.numItems == 0 then
    local filterText = items_group:add(ui.TextBox.new("No Ships Available", FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
    filterText:setLoc(0, y + 80)
    if filter == "all" then
      filterText:setString(_("No Ships Available"), true)
    elseif filter == "fighters" then
      filterText:setString(_("No Fighter Carriers Available"), true)
    elseif filter == "interceptors" then
      filterText:setString(_("No Interceptor Carriers Available"), true)
    elseif filter == "bombers" then
      filterText:setString(_("No Bomber Carriers Available"), true)
    elseif filter == "defense" then
      filterText:setString(_("No Mining Ships Available"), true)
    elseif filter == "special" then
      filterText:setString(_("No Special Weapon Ships Available"), true)
    end
  end
end
local function _fleet_show_filter(move)
  local storeFiltersBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#storeFiltersBG.png"))
  if move.store_filter then
    if not profile.excludeAds then
      storeFiltersBG:setLoc(0, device.ui_height / 2 - 170)
      storeFiltersBG:seekLoc(0, device.ui_height / 2 - 314, 0.5, MOAIEaseType.EASE_IN)
    else
      storeFiltersBG:setLoc(0, device.ui_height / 2 - 70)
      storeFiltersBG:seekLoc(0, device.ui_height / 2 - 214, 0.5, MOAIEaseType.EASE_IN)
    end
  elseif not profile.excludeAds then
    storeFiltersBG:setLoc(0, device.ui_height / 2 - 314)
  else
    storeFiltersBG:setLoc(0, device.ui_height / 2 - 214)
  end
  _menu_root.storeFiltersBG = storeFiltersBG
  local storeFiltersBGPickBox = storeFiltersBG:add(ui.PickBox.new(device.ui_width, 105))
  storeFiltersBGPickBox:setLoc(0, 5)
  local divider = storeFiltersBG:add(ui.Image.new("menuTemplate.atlas.png#storeFiltersDivider.png"))
  divider:setLoc(-318, 0)
  local allBtn = storeFiltersBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategoryAll.png"))
  allBtn:setLoc(-265, 5)
  function allBtn.onClick()
    _fleet_refresh_filter("all")
  end
  storeFiltersBG.allBtn = allBtn
  local divider = storeFiltersBG:add(ui.Image.new("menuTemplate.atlas.png#storeFiltersDivider.png"))
  divider:setLoc(-212, 0)
  local fightersBtn = storeFiltersBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategoryFighters.png"))
  fightersBtn:setLoc(-160, 5)
  function fightersBtn.onClick()
    _fleet_refresh_filter("fighters")
  end
  storeFiltersBG.fightersBtn = fightersBtn
  local divider = storeFiltersBG:add(ui.Image.new("menuTemplate.atlas.png#storeFiltersDivider.png"))
  divider:setLoc(-107, 0)
  local interceptorsBtn = storeFiltersBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategoryCounterBombers.png"))
  interceptorsBtn:setLoc(-55, 5)
  function interceptorsBtn.onClick()
    _fleet_refresh_filter("interceptors")
  end
  storeFiltersBG.interceptorsBtn = interceptorsBtn
  local divider = storeFiltersBG:add(ui.Image.new("menuTemplate.atlas.png#storeFiltersDivider.png"))
  divider:setLoc(0, 0)
  local bombersBtn = storeFiltersBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategoryBombers.png"))
  bombersBtn:setLoc(55, 5)
  function bombersBtn.onClick()
    _fleet_refresh_filter("bombers")
  end
  storeFiltersBG.bombersBtn = bombersBtn
  local divider = storeFiltersBG:add(ui.Image.new("menuTemplate.atlas.png#storeFiltersDivider.png"))
  divider:setLoc(107, 0)
  local defenseBtn = storeFiltersBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategoryDefense.png"))
  defenseBtn:setLoc(160, 5)
  function defenseBtn.onClick()
    _fleet_refresh_filter("defense")
  end
  storeFiltersBG.defenseBtn = defenseBtn
  local divider = storeFiltersBG:add(ui.Image.new("menuTemplate.atlas.png#storeFiltersDivider.png"))
  divider:setLoc(212, 0)
  local specialBtn = storeFiltersBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconCategorySpecial.png"))
  specialBtn:setLoc(265, 5)
  function specialBtn.onClick()
    _fleet_refresh_filter("special")
  end
  storeFiltersBG.specialBtn = specialBtn
  local divider = storeFiltersBG:add(ui.Image.new("menuTemplate.atlas.png#storeFiltersDivider.png"))
  divider:setLoc(318, 0)
  local frame = storeFiltersBG:add(ui.Image.new("menuTemplateShared.atlas.png#selectedIconFrame.png"))
  frame:setColor(0, 0, 0, 0)
  storeFiltersBG.frame = frame
end
function fleet_close(move)
  if move == nil then
    move = {empty = true}
  end
  if _fleet_root.continueBtnGlowAction ~= nil then
    _fleet_root.continueBtnGlowAction:stop()
    _fleet_root.continueBtnGlowAction = nil
  end
  if _menu_root.storeFiltersBG ~= nil then
    if move.store_filter then
      if not profile.excludeAds then
        do
          local action = _menu_root.storeFiltersBG:seekLoc(0, device.ui_height / 2 - 170, 0.5, MOAIEaseType.EASE_IN)
          action:setListener(MOAITimer.EVENT_STOP, function()
            _menu_root:remove(_menu_root.storeFiltersBG)
            _menu_root.storeFiltersBG = nil
          end)
        end
      else
        local action = _menu_root.storeFiltersBG:seekLoc(0, device.ui_height / 2 - 70, 0.5, MOAIEaseType.EASE_IN)
        action:setListener(MOAITimer.EVENT_STOP, function()
          _menu_root:remove(_menu_root.storeFiltersBG)
          _menu_root.storeFiltersBG = nil
        end)
      end
    end
  else
    _menu_root:remove(_menu_root.storeFiltersBG)
    _menu_root.storeFiltersBG = nil
  end
  _menu_root:remove(_menu_root.topBarBG)
  _menu_root.topBarBG = nil
  _storemenu_close({
    store_menu = move.store_menu
  })
  if move.bottom_bar then
    do
      local action = _menu_root.bottomNavBG:seekLoc(0, -device.ui_height / 2 - 120, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        _menu_root:remove(_menu_root.bottomNavBG)
        _menu_root.bottomNavBG = nil
      end)
    end
  else
    _menu_root:remove(_menu_root.bottomNavBG)
    _menu_root.bottomNavBG = nil
  end
  if move.forward then
    do
      local action = _fleet_root:seekLoc(-device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_fleet_root)
        _fleet_root = nil
      end)
    end
  elseif move.back then
    do
      local action = _fleet_root:seekLoc(device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_fleet_root)
        _fleet_root = nil
      end)
    end
  else
    submenuLayer:remove(_fleet_root)
    _fleet_root = nil
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  if scrollbar and scrollAction ~= nil then
    scrollAction:stop()
    scrollAction = nil
  end
  scrollbar = nil
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  curScreen = nil
end
function fleet_show(move)
  if move == nil then
    move = {empty = true}
  end
  local submenu_height = device.ui_height - 100 - 90 - 60 - 104
  local submenu_y = -87
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  _fleet_show_filter(move)
  _storemenu_show("fleet", nil, nil, {
    store_menu = move.store_menu
  })
  local topBarBG = _menu_root:add(ui.Image.new("menuTopBars.atlas.png#topBarFleetCommand.png"))
  if not profile.excludeAds then
    topBarBG:setLoc(0, device.ui_height / 2 - 150)
  else
    topBarBG:setLoc(0, device.ui_height / 2 - 50)
  end
  _menu_root.topBarBG = topBarBG
  local topBarBGPickBox = topBarBG:add(ui.PickBox.new(device.ui_width, 100))
  local topBarText = topBarBG:add(ui.TextBox.new(_("Fleet Command"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  topBarText:setLoc(0, -6)
  if menuMode ~= "ingame" then
    do
      local backBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconBack.png"))
      backBtn._down:setColor(0.5, 0.5, 0.5)
      backBtn:setLoc(-device.ui_width / 2 + 42, 0)
      backBtn.handleTouch = Button_handleTouch
      local function backBtn_onClick()
        if not screenAction:isActive() then
          fleet_close({back = true, store_filter = true})
          local screen = table_remove(screenHistory)
          if screen == "galaxymap" then
            galaxymap_show({back = true})
          end
          soundmanager.onSFX("onPageSwipeBack")
        end
      end
      backBtn.onClick = backBtn_onClick
      if device.os == device.OS_ANDROID then
        local function callback()
          backBtn_onClick()
          return true
        end
        table_insert(android_back_button_queue, callback)
        MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
      end
    end
  elseif device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  if menuMode ~= "ingame" then
    local menuBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconHome.png"))
    menuBtn._down:setColor(0.5, 0.5, 0.5)
    menuBtn:setLoc(device.ui_width / 2 - 42, 0)
    menuBtn.handleTouch = Button_handleTouch
    function menuBtn:onClick()
      menu_close()
      mainmenu_show()
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  _fleet_root = ui.Group.new()
  local bg = _fleet_root:add(ui.PickBox.new(device.ui_width, submenu_height))
  bg:setLoc(0, submenu_y)
  bg.handleTouch = _fleet_items_handleTouch
  _fleet_root.bg = bg
  if _menu_root.fleet_filter == nil then
    _menu_root.fleet_filter = "all"
  end
  _fleet_refresh_filter(_menu_root.fleet_filter)
  if _fleet_root.def_y ~= nil then
    _menu_root.fleet_items_group_y = util.clamp(def_y, 0, math.max(items_group.numItems * items_group.item_height - submenu_height, 0))
    _fleet_root.def_y = nil
  end
  if _menu_root.fleet_items_group_y == nil then
    _menu_root.fleet_items_group_y = 0
  end
  bg.items_group:setLoc(0, _menu_root.fleet_items_group_y)
  if move.forward then
    _fleet_root:setLoc(device.ui_width * 2, 0)
    _fleet_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  elseif move.back then
    _fleet_root:setLoc(-device.ui_width * 2, 0)
    _fleet_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  end
  local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
  if move.bottom_bar then
    bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
    bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
  else
    bottomNavBG:setLoc(0, -device.ui_height / 2 - 8)
  end
  _menu_root.bottomNavBG = bottomNavBG
  local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
  bottomNavBGPickBox:setLoc(0, -20)
  local continueBtnGlow = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#largeButtonGlow.png"))
  continueBtnGlow:setColor(0.25, 0.25, 0.25, 0)
  continueBtnGlow:setScl(0.995, 0.995)
  continueBtnGlow:setLoc(0, 45)
  _fleet_root.continueBtnGlowAction = uiAS:repeatcall(0.5, function()
    if continueBtnGlow.active then
      continueBtnGlow:seekColor(0.25, 0.25, 0.25, 0, 0.5, MOAIEaseType.EASE_IN)
      continueBtnGlow.active = nil
      continueBtnGlow.wait = true
    elseif continueBtnGlow.wait then
      continueBtnGlow.wait = nil
    else
      continueBtnGlow:seekColor(1, 1, 1, 0, 0.5, MOAIEaseType.EASE_IN)
      continueBtnGlow.active = true
    end
  end)
  local continueBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#largeButton.png"))
  continueBtn._down:setColor(0.5, 0.5, 0.5)
  continueBtn:setLoc(0, 50)
  if menuMode ~= "ingame" then
    do
      local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      continueBtnText:setLoc(-15, 0)
      local continueBtnIcon = continueBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
      continueBtnIcon:setLoc(70, 0)
      local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      continueBtnText:setLoc(-15, 0)
      local continueBtnIcon = continueBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
      continueBtnIcon:setLoc(70, 0)
    end
  else
    local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Resume"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
    continueBtnText:setLoc(20, 0)
    local continueBtnIcon = continueBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconStart.png"))
    continueBtnIcon:setLoc(-65, 0)
    local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Resume"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
    continueBtnText:setLoc(20, 0)
    local continueBtnIcon = continueBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconStart.png"))
    continueBtnIcon:setLoc(-65, 0)
  end
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn:onClick()
    if not screenAction:isActive() then
      if menuMode ~= "ingame" then
        table_insert(screenHistory, "fleet")
        fleet_close({forward = true, store_filter = true})
        perks_show({forward = true, perks_bar = true})
        soundmanager.onSFX("onPageSwipeForward")
      else
        menu_close()
      end
    end
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  submenuLayer:add(_fleet_root)
  if showShopPopup then
    popups.show("on_show_g" .. levelGalaxyIndex .. "_s" .. levelSystemIndex .. "_shop", true)
    showShopPopup = false
  end
  curScreen = "fleet"
end
local function _galaxymap_item_handleTouch(self, eventType, touchIdx, x, y, tapCount, exclude_capture)
  local submenu_height = device.ui_height - 100 - 90 - 60 - 70
  local submenu_y = -70
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  if eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    if not exclude_capture then
      ui.capture(self)
    end
    scrolling = true
    lastX = x
    lastY = y
    diffX = 0
    diffY = 0
    scrollbar = {}
    if scrollAction ~= nil then
      scrollbar.velocityX = nil
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
  elseif eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    if not exclude_capture then
      ui.capture(nil)
    end
    if scrolling then
      if scrollbar ~= nil and scrollbar.velocityX ~= nil and scrollbar.velocityY ~= nil then
        scrollbar.velocityX = scrollbar.velocityX + diffX
        scrollbar.velocityY = scrollbar.velocityY + diffY
      elseif scrollbar ~= nil then
        scrollbar.velocityX = diffX
        scrollbar.velocityY = diffY
      end
      if scrollAction == nil then
        scrollAction = uiAS:wrap(function(dt)
          if scrollbar ~= nil and scrollbar.velocityX ~= nil and scrollbar.velocityY ~= nil and _galaxymap_root.camera ~= nil and _galaxymap_root.minY ~= nil and _galaxymap_root.maxY ~= nil then
            do
              local cameraX, cameraY = _galaxymap_root.camera:getLoc()
              local lastLevelDef = GALAXY_DATA[(_galaxymap_root.galaxyIndex - 1) * 40 + 40]
              local newX = util.clamp(cameraX + scrollbar.velocityX, -lastLevelDef["Galaxy Map X"] / 2 - device.ui_width / 4, lastLevelDef["Galaxy Map X"] / 2 + device.ui_width / 4)
              local newY = util.clamp(cameraY + scrollbar.velocityY, _galaxymap_root.minY - submenu_height / 4 - submenu_y, _galaxymap_root.maxY + submenu_height / 4 - submenu_y)
              _galaxymap_root.camera:setLoc(util.roundNumber(newX), util.roundNumber(newY))
              scrollbar.velocityX = scrollbar.velocityX + scrollbar.velocityX * -1 * dt * 0.03 * device.dpi
              scrollbar.velocityY = scrollbar.velocityY + scrollbar.velocityY * -1 * dt * 0.03 * device.dpi
              if not scrolling and abs(scrollbar.velocityX) < 0.5 and abs(scrollbar.velocityY) < 0.5 then
                scrollAction:stop()
                scrollAction = nil
                scrollbar = nil
              end
            end
          else
            scrollAction:stop()
            scrollAction = nil
            scrollbar = nil
          end
        end)
      end
    end
    scrolling = false
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE and scrolling then
    diffX = (lastX - x) * 2
    diffY = (lastY - y) * 2
    local cameraX, cameraY = _galaxymap_root.camera:getLoc()
    local lastLevelDef = GALAXY_DATA[(_galaxymap_root.galaxyIndex - 1) * 40 + 40]
    local newX = util.clamp(cameraX + diffX, -lastLevelDef["Galaxy Map X"] / 2 - device.ui_width / 4, lastLevelDef["Galaxy Map X"] / 2 + device.ui_width / 4)
    local newY = util.clamp(cameraY + diffY, _galaxymap_root.minY - submenu_height / 4 - submenu_y, _galaxymap_root.maxY + submenu_height / 4 - submenu_y)
    _galaxymap_root.camera:setLoc(newX, newY)
    if scrollAction ~= nil then
      scrollbar.velocityX = nil
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
    lastX = x
    lastY = y
  end
  return true
end
local function _galaxymap_system_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  local clickdone
  if eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    ui.capture(nil)
  elseif eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    self._isdown = true
    ui.capture(self)
    startX, startY = self:modelToWorld(x, y)
    do
      local action
      action = uiAS:run(function(dt, t)
        if buttonAction == nil then
          if action ~= nil then
            action:stop()
          end
          action = nil
        end
        buttonAction.t = t
        if self._isdown and self.currentPageName == "up" and t > 0.2 then
          self:showPage("down")
        elseif t > 1 then
          self:showPage("up")
          self._isdown = nil
          buttonAction:stop()
          buttonAction = nil
        end
      end)
      buttonAction = action
      buttonAction.t = 0
    end
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE then
    if self._isdown and not ui.treeCheck(x, y, self) then
      self:showPage("up")
      self._isdown = nil
      if buttonAction ~= nil then
        buttonAction:stop()
        buttonAction = nil
      end
    end
    local wx, wy = self:modelToWorld(x, y)
    if self._isdown and (abs(startX - wx) > 25 or abs(startY - wy) > 25) then
      self:showPage("up")
      self._isdown = nil
      if buttonAction ~= nil then
        buttonAction:stop()
        buttonAction = nil
      end
    end
  end
  if not clickdone then
    local wx, wy = self:modelToWorld(x, y)
    local wndX, wndY = self._uilayer:worldToWnd(wx, wy)
    wx, wy = _galaxymap_root.mapPickBox._uilayer:wndToWorld(wndX, wndY)
    local mx, my = _galaxymap_root.mapPickBox:worldToModel(wx, wy)
    _galaxymap_item_handleTouch(_galaxymap_root.mapPickBox, eventType, touchIdx, mx, my, tapCount, true)
  end
  return true
end
local function _galaxymap_refresh_galaxy(systemIndex)
  for i, v in ipairs(_galaxymap_root.systems) do
    v.mapSystemActive._up:setColor(0, 0, 0, 0)
    v.mapSystemSelector:setColor(1, 1, 1, 1)
    v:setScl(0.75, 0.75)
    v:setColor(0.75, 0.75, 0.75, 0.75)
  end
  local selectedSystem = _galaxymap_root.systems[systemIndex]
  selectedSystem.mapSystemActive._up:setColor(unpack(UI_COLOR_GOLD))
  selectedSystem.mapSystemSelector:setColor(unpack(UI_COLOR_GOLD))
  selectedSystem:setScl(1, 1)
  selectedSystem:setColor(1, 1, 1, 1)
end
local function _galaxymap_close_galaxy()
  _galaxymap_root.root1:remove()
  _galaxymap_root.root1 = nil
  _galaxymap_root.root2:remove()
  _galaxymap_root.root2 = nil
  galaxymapLayer1:clear()
  galaxymapLayer2:clear()
  _galaxymap_root.maxY = nil
  _galaxymap_root.minY = nil
  _galaxymap_root.camera = nil
  _galaxymap_root.systems = nil
end
local _galaxymap_close_item, _galaxymap_create_item
local function _galaxymap_create_galaxy(galaxyIndex)
  local lastCompletedGalaxy, lastCompletedSystem, lastCompletedIndex = _get_last_completed_galaxy_system()
  local root1 = galaxymapLayer1:add(ui.Group.new())
  local root2 = galaxymapLayer2:add(ui.Group.new())
  local camera = MOAITransform.new()
  camera:setLoc(0, 0)
  camera:setScl(1, 1)
  galaxymapLayer1:setCamera(camera)
  galaxymapLayer1:setParallax(GALAXYMAP1_PARALLAX, GALAXYMAP1_PARALLAX)
  galaxymapLayer2:setCamera(camera)
  galaxymapLayer2:setParallax(GALAXYMAP2_PARALLAX, GALAXYMAP2_PARALLAX)
  local mapBG = gfxutil.createTilingBG("galaxy0" .. galaxyIndex .. "MapBG.png")
  local bgScale = 1.5
  if device.ui_assetrez == device.ASSET_MODE_LO or device.ui_assetrez == device.ASSET_MODE_X_HI then
    bgScale = bgScale * 2
  end
  mapBG:setScl(bgScale, bgScale)
  mapBG:setLoc(-mapBG.width / 2 * bgScale, mapBG.height / 2 * bgScale)
  root1:add(mapBG)
  local mapPickBox = root1:add(ui.PickBox.new(device.ui_width, device.ui_height))
  mapPickBox:setScl(2, 2)
  mapPickBox.handleTouch = _galaxymap_item_handleTouch
  _galaxymap_root.mapPickBox = mapPickBox
  local prop = MOAIProp2D.new()
  local fmt = MOAIVertexFormat.new()
  if MOAI_VERSION >= MOAI_VERSION_1_0 then
    fmt:declareCoord(1, MOAIVertexFormat.GL_FLOAT, 2)
  else
    fmt:declareCoord(MOAIVertexFormat.GL_FLOAT, 2)
  end
  local vbo = MOAIVertexBuffer.new()
  vbo:setPenWidth(3)
  vbo:setFormat(fmt)
  vbo:setPrimType(MOAIVertexBuffer.GL_LINE_STRIP)
  vbo:reserveVerts(40)
  local mesh = MOAIMesh.new()
  mesh:setVertexBuffer(vbo)
  prop:setDeck(mesh)
  prop:clearAttrLink(MOAIColor.INHERIT_COLOR)
  prop:setShader(resource.shader(color.toHex(0.25, 0.25, 0.25, 0.25)))
  root2:add(prop)
  local mapGridSquare = gfxutil.createTilingBG("mapGridSquare.png")
  mapGridSquare:clearAttrLink(MOAIColor.INHERIT_COLOR)
  mapGridSquare:setColor(0.15, 0.15, 0.15, 0.15)
  if device.fill == device.FILL_RATE_HI then
    root2:add(mapGridSquare)
  end
  local systems = {}
  local maxY, minY
  local lastLevelDef = GALAXY_DATA[(galaxyIndex - 1) * 40 + 40]
  for i = (galaxyIndex - 1) * 40 + 1, (galaxyIndex - 1) * 40 + 40 do
    do
      local levelDef = GALAXY_DATA[i]
      local systemIndex = i - (galaxyIndex - 1) * 40
      local x = levelDef["Galaxy Map X"] - lastLevelDef["Galaxy Map X"] / 2
      local y = levelDef["Galaxy Map Y"]
      if maxY == nil then
        maxY = y
      elseif y > maxY then
        maxY = y
      end
      if minY == nil then
        minY = y
      elseif y < minY then
        minY = y
      end
      local galaxyStarSystem = root2:add(ui.Image.new("galaxyStarSystems.atlas.png#system" .. levelDef["Galaxy Map Image"]:upper() .. ".png"))
      galaxyStarSystem:setScl(0.75, 0.75)
      galaxyStarSystem:setLoc(x, y)
      if lastCompletedIndex >= i - 1 then
        table_insert(systems, galaxyStarSystem)
        do
          local mapSystemActive = galaxyStarSystem:add(ui.Button.new("menuTemplate.atlas.png#mapSystemActive.png"))
          mapSystemActive._up:setColor(0, 0, 0, 0)
          mapSystemActive.handleTouch = _galaxymap_system_handleTouch
          function mapSystemActive.onClick()
            _galaxymap_close_item()
            local item = _galaxymap_create_item(galaxyIndex, systemIndex)
            _galaxymap_root:add(item)
            _galaxymap_root.item = item
          end
          galaxyStarSystem.mapSystemActive = mapSystemActive
          local mapSystemSelector = galaxyStarSystem:add(ui.Image.new("menuTemplate.atlas.png#mapSystemSelector.png"))
          galaxyStarSystem.mapSystemSelector = mapSystemSelector
          local systemNumText = mapSystemSelector:add(ui.TextBox.new("" .. systemIndex, FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
          systemNumText:setLoc(-55, -4)
          local levelsGalaxy = profile.levels[galaxyIndex]
          local levelsSystem
          if levelsGalaxy ~= nil then
            levelsSystem = levelsGalaxy[systemIndex]
            if levelsSystem ~= nil and levelsSystem.stars ~= nil then
              if levelsSystem.stars == 1 then
                do
                  local mapStar1 = mapSystemSelector:add(ui.Image.new("menuTemplate.atlas.png#mapStar.png"))
                  mapStar1:setLoc(52, 0)
                  local mapStar2 = mapSystemSelector:add(ui.Image.new("menuTemplate.atlas.png#mapStarEmpty.png"))
                  mapStar2:setLoc(77, 0)
                  local mapStar3 = mapSystemSelector:add(ui.Image.new("menuTemplate.atlas.png#mapStarEmpty.png"))
                  mapStar3:setLoc(102, 0)
                end
              elseif levelsSystem.stars == 2 then
                do
                  local mapStar1 = mapSystemSelector:add(ui.Image.new("menuTemplate.atlas.png#mapStar.png"))
                  mapStar1:setLoc(52, 0)
                  local mapStar2 = mapSystemSelector:add(ui.Image.new("menuTemplate.atlas.png#mapStar.png"))
                  mapStar2:setLoc(77, 0)
                  local mapStar3 = mapSystemSelector:add(ui.Image.new("menuTemplate.atlas.png#mapStarEmpty.png"))
                  mapStar3:setLoc(102, 0)
                end
              elseif levelsSystem.stars == 3 then
                local mapStar1 = mapSystemSelector:add(ui.Image.new("menuTemplate.atlas.png#mapStar.png"))
                mapStar1:setLoc(52, 0)
                local mapStar2 = mapSystemSelector:add(ui.Image.new("menuTemplate.atlas.png#mapStar.png"))
                mapStar2:setLoc(77, 0)
                local mapStar3 = mapSystemSelector:add(ui.Image.new("menuTemplate.atlas.png#mapStar.png"))
                mapStar3:setLoc(102, 0)
              end
            else
              local newText = mapSystemSelector:add(ui.TextBox.new(_("(NEW)"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
              newText:setLoc(75, -4)
            end
          end
          vbo:writeFloat(x, y)
        end
      else
        local lock = galaxyStarSystem:add(ui.Image.new("menuTemplateShared.atlas.png#iconLockedLarge.png"))
        lock:setColor(unpack(UI_COLOR_GRAY))
      end
    end
  end
  vbo:bless()
  _galaxymap_root.root1 = root1
  _galaxymap_root.root2 = root2
  _galaxymap_root.maxY = maxY
  _galaxymap_root.minY = minY
  _galaxymap_root.camera = camera
  _galaxymap_root.systems = systems
end
function _galaxymap_close_item()
  if _galaxymap_root.item ~= nil then
    _galaxymap_root.item:remove()
  end
end
function _galaxymap_create_item(galaxyIndex, systemIndex)
  local submenu_height = device.ui_height - 100 - 90 - 60 - 70
  local submenu_y = -70
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local lastCompletedGalaxy, lastCompletedSystem, lastCompletedIndex = _get_last_completed_galaxy_system()
  local idx = (galaxyIndex - 1) * 40 + systemIndex
  assert(GALAXY_DATA[idx] ~= nil, "Invalid galaxy index: " .. tostring(galaxyIndex) .. "." .. tostring(systemIndex))
  local levelDef = GALAXY_DATA[idx]
  local item = ui.Group.new()
  local mapSystemBox = item:add(ui.NinePatch.new("boxHeaderOnly9p.lua", 600, 70))
  mapSystemBox:setLoc(0, submenu_height / 2 + submenu_y - 45)
  local systemNameText = mapSystemBox:add(ui.TextBox.new("" .. galaxyIndex .. "." .. systemIndex .. ": " .. _(levelDef["System Name"]), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  systemNameText:setColor(unpack(UI_COLOR_GOLD))
  systemNameText:setLoc(0, 0)
  local systemPreviousBtn = mapSystemBox:add(ui.Button.new("menuTemplateShared.atlas.png#mapPrevious.png"))
  systemPreviousBtn._up:setColor(unpack(UI_COLOR_GOLD))
  systemPreviousBtn._down:setColor(unpack(UI_COLOR_GOLD_DARKEN))
  systemPreviousBtn:setLoc(-270, 0)
  local systemNextBtn = mapSystemBox:add(ui.Button.new("menuTemplateShared.atlas.png#mapNext.png"))
  systemNextBtn._up:setColor(unpack(UI_COLOR_GOLD))
  systemNextBtn._down:setColor(unpack(UI_COLOR_GOLD_DARKEN))
  systemNextBtn:setLoc(270, 0)
  if systemIndex > 1 then
    function systemPreviousBtn.onClick()
      _galaxymap_close_item()
      local item = _galaxymap_create_item(galaxyIndex, systemIndex - 1)
      _galaxymap_root:add(item)
      _galaxymap_root.item = item
    end
  else
    systemPreviousBtn._up:setColor(UI_COLOR_GOLD_DARKEN[1], UI_COLOR_GOLD_DARKEN[2], UI_COLOR_GOLD_DARKEN[3], 0.5)
    systemPreviousBtn.handleTouch = nil
  end
  if lastCompletedIndex >= idx and systemIndex < 40 then
    function systemNextBtn.onClick()
      _galaxymap_close_item()
      local item = _galaxymap_create_item(galaxyIndex, systemIndex + 1)
      _galaxymap_root:add(item)
      _galaxymap_root.item = item
    end
  else
    systemNextBtn._up:setColor(UI_COLOR_GOLD_DARKEN[1], UI_COLOR_GOLD_DARKEN[2], UI_COLOR_GOLD_DARKEN[3], 0.5)
    systemNextBtn.handleTouch = nil
  end
  local mapSystemInfoBox
  for i = 1, 3 do
    if levelDef["System Warning " .. i] and levelDef["System Warning " .. i] ~= "" then
      if mapSystemInfoBox == nil then
        mapSystemInfoBox = item:add(ui.NinePatch.new("boxPlain9p.lua", 600, 144))
        mapSystemInfoBox:setLoc(0, -submenu_height / 2 + submenu_y + 90)
      end
      local systemWarningText = mapSystemInfoBox:add(ui.TextBox.new(_(levelDef["System Warning " .. i]), FONT_MEDIUM, "ffffff", "center", 580, nil, true))
      if i == 1 then
        systemWarningText:setLoc(0, 35)
      elseif i == 2 then
        systemWarningText:setLoc(0, 0)
      elseif i == 3 then
        systemWarningText:setLoc(0, -35)
      end
    end
  end
  _galaxymap_refresh_galaxy(systemIndex)
  local x, y = _galaxymap_root.systems[systemIndex]:getLoc()
  if _galaxymap_root.camera.action == nil then
    _galaxymap_root.camera:setLoc(x, y - submenu_y)
  end
  if _galaxymap_root.camera.action ~= nil and _galaxymap_root.camera.action:isActive() then
    _galaxymap_root.camera.action:stop()
  end
  _galaxymap_root.camera.action = _galaxymap_root.camera:seekLoc(x, y - submenu_y, 0.5, MOAIEaseType.EASE_IN)
  _galaxymap_root.galaxyIndex = galaxyIndex
  levelGalaxyIndex = galaxyIndex
  levelSystemIndex = systemIndex
  soundmanager.onSFX("onSystemSelect")
  return item
end
local function _galaxymap_animate_item(galaxyIndex, systemIndex)
  local submenu_height = device.ui_height - 100 - 90 - 60 - 70
  local submenu_y = -70
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local forward
  local item = _galaxymap_root:add(ui.Group.new())
  _galaxymap_root.item = item
  local pickbox = item:add(ui.PickBox.new(device.ui_width, submenu_height + 90))
  pickbox:setLoc(0, submenu_y - 45)
  function pickbox.onClick()
    forward = true
  end
  local x, y = _galaxymap_root.systems[systemIndex - 1]:getLoc()
  local goalX, goalY = _galaxymap_root.systems[systemIndex]:getLoc()
  _galaxymap_root.camera:setLoc(x, y - submenu_y)
  local mapShipIcon = _galaxymap_root.root2:add(ui.Image.new("menuTemplate.atlas.png#mapShipIcon.png"))
  local goalXN, goalYN = normalize(goalX - x, goalY - y)
  local goalRot = deg(atan2(goalYN, goalXN))
  mapShipIcon:setRot(goalRot - 90)
  mapShipIcon:setLoc(x, y)
  _galaxymap_root.animateThread = MOAIThread.new()
  _galaxymap_root.animateThread:run(function()
    local AS = actionset.new()
    local action
    action = MOAIEaseDriver.new()
    action:setLength(0.5)
    AS:wrap(action:start())
    while action:isActive() do
      if forward and not AS:isPaused() then
        AS:throttle(10)
        forward = nil
      end
      coroutine.yield()
    end
    action = mapShipIcon:seekLoc(goalX, goalY, 2, MOAIEaseType.EASE_IN)
    _galaxymap_root.camera:seekLoc(goalX, goalY - submenu_y, 2, MOAIEaseType.EASE_IN)
    while action:isActive() do
      if forward and not AS:isPaused() then
        AS:throttle(10)
        forward = nil
      end
      coroutine.yield()
    end
    action = MOAIEaseDriver.new()
    action:setLength(0.5)
    AS:wrap(action:start())
    while action:isActive() do
      if forward and not AS:isPaused() then
        AS:throttle(10)
        forward = nil
      end
      coroutine.yield()
    end
    AS:throttle(1)
    AS:stop()
    AS = nil
    item:remove()
    local item = _galaxymap_create_item(galaxyIndex, systemIndex)
    _galaxymap_root:add(item)
    item:setLoc(device.width, 0)
    item:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
    _galaxymap_root.item = item
    local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
    bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
    bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
    _menu_root.bottomNavBG = bottomNavBG
    local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
    bottomNavBGPickBox:setLoc(0, -20)
    local continueBtnGlow = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#largeButtonGlow.png"))
    continueBtnGlow:setColor(0.25, 0.25, 0.25, 0)
    continueBtnGlow:setScl(0.995, 0.995)
    continueBtnGlow:setLoc(0, 45)
    _galaxymap_root.continueBtnGlowAction = uiAS:repeatcall(0.5, function()
      if continueBtnGlow.active then
        continueBtnGlow:seekColor(0.25, 0.25, 0.25, 0, 0.5, MOAIEaseType.EASE_IN)
        continueBtnGlow.active = nil
        continueBtnGlow.wait = true
      elseif continueBtnGlow.wait then
        continueBtnGlow.wait = nil
      else
        continueBtnGlow:seekColor(1, 1, 1, 0, 0.5, MOAIEaseType.EASE_IN)
        continueBtnGlow.active = true
      end
    end)
    local continueBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#largeButton.png"))
    continueBtn._down:setColor(0.5, 0.5, 0.5)
    continueBtn:setLoc(0, 50)
    local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
    continueBtnText:setLoc(-15, 0)
    local continueBtnIcon = continueBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
    continueBtnIcon:setLoc(70, 0)
    local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
    continueBtnText:setLoc(-15, 0)
    local continueBtnIcon = continueBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
    continueBtnIcon:setLoc(70, 0)
    continueBtn.handleTouch = Button_handleTouch
    function continueBtn:onClick()
      if not screenAction:isActive() then
        table_insert(screenHistory, "galaxymap")
        galaxymap_close({forward = true})
        showShopPopup = true
        showPerkPopup = true
        fleet_show({forward = true, store_filter = true})
        soundmanager.onSFX("onPageSwipeForward")
      end
    end
  end)
  levelGalaxyIndex = galaxyIndex
  levelSystemIndex = systemIndex
end
local function _galaxymap_mode_survival_close()
  _galaxymap_root.root1:remove()
  _galaxymap_root.root1 = nil
  _galaxymap_root.root2:remove()
  _galaxymap_root.root2 = nil
  galaxymapLayer1:clear()
  galaxymapLayer2:clear()
  _galaxymap_root.camera = nil
  _galaxymap_root.item:remove()
  _galaxymap_root.item = nil
end
local function _galaxymap_mode_survival_show(galaxyIndex)
  local submenu_height = device.ui_height - 100 - 90 - 60 - 70
  local submenu_y = -70
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local root1 = galaxymapLayer1:add(ui.Group.new())
  local root2 = galaxymapLayer2:add(ui.Group.new())
  local camera = MOAITransform.new()
  camera:setLoc(0, 0)
  camera:setScl(1, 1)
  galaxymapLayer1:setCamera(camera)
  galaxymapLayer1:setParallax(GALAXYMAP1_PARALLAX, GALAXYMAP1_PARALLAX)
  galaxymapLayer2:setCamera(camera)
  galaxymapLayer2:setParallax(GALAXYMAP2_PARALLAX, GALAXYMAP2_PARALLAX)
  local mapBG = gfxutil.createTilingBG("galaxy0" .. galaxyIndex .. "MapBG.png")
  local bgScale = 1.5
  if device.ui_assetrez == device.ASSET_MODE_LO then
    bgScale = bgScale * 2
  end
  mapBG:setScl(bgScale, bgScale)
  mapBG:setLoc(-mapBG.width / 2 * bgScale, mapBG.height / 2 * bgScale)
  root1:add(mapBG)
  local mapGridSquare = gfxutil.createTilingBG("mapGridSquare.png")
  mapGridSquare:clearAttrLink(MOAIColor.INHERIT_COLOR)
  mapGridSquare:setColor(0.15, 0.15, 0.15, 0.15)
  if device.fill == device.FILL_RATE_HI then
    root2:add(mapGridSquare)
  end
  _galaxymap_root.root1 = root1
  _galaxymap_root.root2 = root2
  _galaxymap_root.camera = camera
  local item = _galaxymap_root:add(ui.Group.new())
  _galaxymap_root.item = item
  local image = item:add(ui.Image.new("characters/techOfficerSurvival.png"))
  local w, h = image:getSize()
  image:setLoc(-device.ui_width / 2 + 80, submenu_y - 200)
  local descriptionBox = item:add(ui.NinePatch.new("boxPlainLight9p.lua", 430, 150))
  descriptionBox:setLoc(90, submenu_y - 30 + 110 + 5 + 75)
  local text = _("Experimental warp is online! We can warp you past known space into the Brood's domain. Their forces may be infinite...")
  local descriptionText = descriptionBox:add(ui.TextBox.new(text, FONT_MEDIUM, "ffffff", "left", 390, 120, true))
  local instructionsBox = item:add(ui.NinePatch.new("boxWithHeaderLight9p.lua", 430, 220))
  instructionsBox:setLoc(90, submenu_y - 30)
  local instructionsText = instructionsBox:add(ui.TextBox.new(_("Instructions"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  instructionsText:setColor(unpack(UI_COLOR_GOLD))
  instructionsText:setLoc(0, 75)
  local text = _(SURVIVAL_MODE_INSTRUCTIONS)
  local instructionsText = instructionsBox:add(ui.TextBox.new(text, FONT_SMALL_BOLD, "ffffff", "left", 390, nil, true))
  instructionsText:setLoc(0, -30)
  descriptionBox:setLoc(90, submenu_y + 110 + 5 + 75)
  instructionsBox:setLoc(90, submenu_y)
  local scoreBox = item:add(ui.NinePatch.new("boxPlainLight9p.lua", 430, 130))
  scoreBox:setLoc(90, submenu_y - 110 - 5 - 65)
  local leaderboardBtn = scoreBox:add(ui.Button.new("menuTemplateShared.atlas.png#warpMenuStoreButton.png"))
  leaderboardBtn._down:setColor(0.5, 0.5, 0.5)
  leaderboardBtn:setLoc(0, 28)
  local leaderboardBtnText = leaderboardBtn._up:add(ui.TextBox.new(_("View Leaderboards"), FONT_MEDIUM_BOLD, "ffffff", "center"))
  leaderboardBtnText:setColor(0, 0, 0)
  leaderboardBtnText:setLoc(0, -2)
  local leaderboardBtnText = leaderboardBtn._down:add(ui.TextBox.new(_("View Leaderboards"), FONT_MEDIUM_BOLD, "ffffff", "center"))
  leaderboardBtnText:setColor(0, 0, 0)
  leaderboardBtnText:setLoc(0, -2)
  leaderboardBtn.handleTouch = Button_handleTouch
  function leaderboardBtn.onClick()
    if not screenAction:isActive() then
      table_insert(screenHistory, "galaxymap")
      galaxymap_close({forward = true})
      leaderboard_show({forward = true})
      soundmanager.onSFX("onPageSwipeForward")
    end
  end
  local highScoreText = scoreBox:add(ui.TextBox.new(_("YOUR ALL-TIME HIGH SCORE"), FONT_SMALL_BOLD, "ffffff", "left", 390, nil, true))
  highScoreText:setColor(unpack(UI_COLOR_GOLD))
  highScoreText:setLoc(0, -20)
  local scoreText = scoreBox:add(ui.TextBox.new(util.commasInNumbers(profile.survivalHighScore), FONT_SMALL_BOLD, "ffffff", "right", 390, nil, true))
  scoreText:setLoc(0, -20)
  local highWaveText = scoreBox:add(ui.TextBox.new(_("YOUR HIGHEST WAVE"), FONT_SMALL_BOLD, "ffffff", "left", 390, nil, true))
  highWaveText:setColor(unpack(UI_COLOR_GOLD))
  highWaveText:setLoc(0, -47)
  local waveText = scoreBox:add(ui.TextBox.new(util.commasInNumbers(profile.survivalHighScoreWave), FONT_SMALL_BOLD, "ffffff", "right", 390, nil, true))
  waveText:setLoc(0, -47)
end
local _galaxymap_mode_campaign_active, _galaxymap_mode_campaign_inactive, _galaxymap_mode_survival_active, _galaxymap_mode_survival_inactive
function _galaxymap_mode_campaign_active()
  gameModeBG = _menu_root.gameModeBG
  if gameModeBG.campaignBox ~= nil then
    gameModeBG.campaignBox:remove()
    gameModeBG.campaignBox = nil
  end
  local campaignBox = gameModeBG:add(ui.NinePatch.new("boxPlainSelected9p.lua", device.ui_width / 2 - 15, 55))
  campaignBox:setLoc(-device.ui_width / 4, -10)
  gameModeBG.campaignBox = campaignBox
  local campaignBtn = campaignBox:add(ui.Button.new(ui.PickBox.new(device.ui_width / 2 - 15, 55), ui.PickBox.new(device.ui_width / 2 - 15, 55)))
  campaignBtn._up.handleTouch = nil
  campaignBtn._down.handleTouch = nil
  local campaignBtnText = campaignBtn._up:add(ui.TextBox.new(_("CAMPAIGN"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  campaignBtnText:setLoc(0, -4)
  campaignBtn._up.text = campaignBtnText
  local campaignBtnText = campaignBtn._down:add(ui.TextBox.new(_("CAMPAIGN"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  campaignBtnText:setColor(0.5, 0.5, 0.5)
  campaignBtnText:setLoc(0, -4)
  campaignBtn._down.text = campaignBtnText
  campaignBtn.handleTouch = nil
end
function _galaxymap_mode_campaign_inactive()
  gameModeBG = _menu_root.gameModeBG
  if gameModeBG.campaignBox ~= nil then
    gameModeBG.campaignBox:remove()
    gameModeBG.campaignBox = nil
  end
  local campaignBox = gameModeBG:add(ui.NinePatch.new("boxPlain9p.lua", device.ui_width / 2 - 15, 55))
  campaignBox:setLoc(-device.ui_width / 4, -10)
  gameModeBG.campaignBox = campaignBox
  local campaignBtn = campaignBox:add(ui.Button.new(ui.PickBox.new(device.ui_width / 2 - 15, 55), ui.PickBox.new(device.ui_width / 2 - 15, 55)))
  campaignBtn._up.handleTouch = nil
  campaignBtn._down.handleTouch = nil
  local campaignBtnText = campaignBtn._up:add(ui.TextBox.new(_("CAMPAIGN"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  campaignBtnText:setLoc(0, -4)
  campaignBtn._up.text = campaignBtnText
  local campaignBtnText = campaignBtn._down:add(ui.TextBox.new(_("CAMPAIGN"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  campaignBtnText:setColor(0.5, 0.5, 0.5)
  campaignBtnText:setLoc(0, -4)
  campaignBtn._down.text = campaignBtnText
  campaignBtn.handleTouch = Button_handleTouch
  function campaignBtn.onClick()
    _galaxymap_mode_campaign_active()
    _galaxymap_mode_survival_inactive()
    _galaxymap_mode_survival_close()
    _galaxymap_create_galaxy(levelGalaxyIndex)
    local item = _galaxymap_create_item(levelGalaxyIndex, levelSystemIndex)
    _galaxymap_root:add(item)
    _galaxymap_root.item = item
    gameMode = "galaxy"
  end
end
function _galaxymap_mode_survival_active()
  gameModeBG = _menu_root.gameModeBG
  if gameModeBG.survivalBox ~= nil then
    gameModeBG.survivalBox:remove()
    gameModeBG.survivalBox = nil
  end
  local survivalBox = gameModeBG:add(ui.NinePatch.new("boxPlainSelected9p.lua", device.ui_width / 2 - 15, 55))
  survivalBox:setLoc(device.ui_width / 4, -10)
  gameModeBG.survivalBox = survivalBox
  local survivalBtn = survivalBox:add(ui.Button.new(ui.PickBox.new(device.ui_width / 2 - 15, 55), ui.PickBox.new(device.ui_width / 2 - 15, 55)))
  survivalBtn._up.handleTouch = nil
  survivalBtn._down.handleTouch = nil
  local survivalBtnText = survivalBtn._up:add(ui.TextBox.new(_("SURVIVAL"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  survivalBtnText:setLoc(0, -4)
  survivalBtn._up.text = survivalBtnText
  local survivalBtnText = survivalBtn._down:add(ui.TextBox.new(_("SURVIVAL"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  survivalBtnText:setColor(0.5, 0.5, 0.5)
  survivalBtnText:setLoc(0, -4)
  survivalBtn._down.text = survivalBtnText
  survivalBtn.handleTouch = nil
end
function _galaxymap_mode_survival_inactive()
  gameModeBG = _menu_root.gameModeBG
  if gameModeBG.survivalBox ~= nil then
    gameModeBG.survivalBox:remove()
    gameModeBG.survivalBox = nil
  end
  local survivalBox = gameModeBG:add(ui.NinePatch.new("boxPlain9p.lua", device.ui_width / 2 - 15, 55))
  survivalBox:setLoc(device.ui_width / 4, -10)
  gameModeBG.survivalBox = survivalBox
  local survivalBtn = survivalBox:add(ui.Button.new(ui.PickBox.new(device.ui_width / 2 - 15, 55), ui.PickBox.new(device.ui_width / 2 - 15, 55)))
  survivalBtn._up.handleTouch = nil
  survivalBtn._down.handleTouch = nil
  local survivalBtnText = survivalBtn._up:add(ui.TextBox.new(_("SURVIVAL"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  survivalBtnText:setLoc(0, -4)
  survivalBtn._up.text = survivalBtnText
  local survivalBtnText = survivalBtn._down:add(ui.TextBox.new(_("SURVIVAL"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  survivalBtnText:setColor(0.5, 0.5, 0.5)
  survivalBtnText:setLoc(0, -4)
  survivalBtn._down.text = survivalBtnText
  survivalBtn.handleTouch = Button_handleTouch
  function survivalBtn.onClick()
    if _galaxymap_root.animateThread ~= nil then
      _galaxymap_root.animateThread:stop()
      _galaxymap_root.animateThread = nil
      _galaxymap_root.item:remove()
    end
    if _menu_root.bottomNavBG == nil then
      do
        local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
        bottomNavBG:setLoc(0, -device.ui_height / 2 - 8)
        _menu_root.bottomNavBG = bottomNavBG
        local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
        bottomNavBGPickBox:setLoc(0, -20)
        local continueBtnGlow = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#largeButtonGlow.png"))
        continueBtnGlow:setColor(0.25, 0.25, 0.25, 0)
        continueBtnGlow:setScl(0.995, 0.995)
        continueBtnGlow:setLoc(0, 45)
        _galaxymap_root.continueBtnGlowAction = uiAS:repeatcall(0.5, function()
          if continueBtnGlow.active then
            continueBtnGlow:seekColor(0.25, 0.25, 0.25, 0, 0.5, MOAIEaseType.EASE_IN)
            continueBtnGlow.active = nil
            continueBtnGlow.wait = true
          elseif continueBtnGlow.wait then
            continueBtnGlow.wait = nil
          else
            continueBtnGlow:seekColor(1, 1, 1, 0, 0.5, MOAIEaseType.EASE_IN)
            continueBtnGlow.active = true
          end
        end)
        local continueBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#largeButton.png"))
        continueBtn._down:setColor(0.5, 0.5, 0.5)
        continueBtn:setLoc(0, 50)
        local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
        continueBtnText:setLoc(-15, 0)
        local continueBtnIcon = continueBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
        continueBtnIcon:setLoc(70, 0)
        local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
        continueBtnText:setLoc(-15, 0)
        local continueBtnIcon = continueBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
        continueBtnIcon:setLoc(70, 0)
        continueBtn.handleTouch = Button_handleTouch
        function continueBtn:onClick()
          if not screenAction:isActive() then
            table_insert(screenHistory, "galaxymap")
            galaxymap_close({forward = true})
            showShopPopup = true
            showPerkPopup = true
            fleet_show({forward = true, store_filter = true})
            soundmanager.onSFX("onPageSwipeForward")
          end
        end
      end
    end
    _galaxymap_mode_campaign_inactive()
    _galaxymap_mode_survival_active()
    _galaxymap_close_galaxy()
    _galaxymap_close_item()
    _galaxymap_mode_survival_show(levelGalaxyIndex)
    gameMode = "survival"
  end
  local lastCompletedGalaxy, lastCompletedSystem, lastCompletedIndex = _get_last_completed_galaxy_system()
  if lastCompletedIndex >= SURVIVAL_MODE_UNLOCK_SYSTEM then
    _popup_survival_unlocked_show(true)
  else
    survivalBtn._up.text:setColor(unpack(UI_COLOR_GRAY))
    survivalBtn._down.text:setColor(unpack(UI_COLOR_GRAY_DARKEN))
    function survivalBtn.onClick()
      _popup_survival_locked_show(true)
    end
    survivalLock = survivalBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconLockedLarge.png"))
    survivalLock:setColor(unpack(UI_COLOR_GRAY))
    survivalLock:setLoc(-(device.ui_width / 2 - 15) / 2 + 35, 0)
  end
end
local function _galaxymap_show_mode(mode)
  local gameModeBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#storeFiltersBG.png"))
  if not profile.excludeAds then
    gameModeBG:setLoc(0, device.ui_height / 2 - 170)
    gameModeBG:seekLoc(0, device.ui_height / 2 - 280, 0.5, MOAIEaseType.EASE_IN)
  else
    gameModeBG:setLoc(0, device.ui_height / 2 - 70)
    gameModeBG:seekLoc(0, device.ui_height / 2 - 180, 0.5, MOAIEaseType.EASE_IN)
  end
  _menu_root.gameModeBG = gameModeBG
  local gameModeBGPickBox = gameModeBG:add(ui.PickBox.new(device.ui_width, 105))
  gameModeBGPickBox:setLoc(0, 5)
  if mode == "galaxy" then
    _galaxymap_mode_campaign_active()
    _galaxymap_mode_survival_inactive()
  elseif mode == "survival" then
    _galaxymap_mode_campaign_inactive()
    _galaxymap_mode_survival_active()
  end
end
function galaxymap_close(move)
  if move == nil then
    move = {empty = true}
  end
  if _galaxymap_root.continueBtnGlowAction ~= nil then
    _galaxymap_root.continueBtnGlowAction:stop()
    _galaxymap_root.continueBtnGlowAction = nil
  end
  if _galaxymap_root.animateThread ~= nil then
    _galaxymap_root.animateThread:stop()
    _galaxymap_root.animateThread = nil
  end
  if _menu_root.gameModeBG ~= nil then
    if not profile.excludeAds then
      do
        local action = _menu_root.gameModeBG:seekLoc(0, device.ui_height / 2 - 170, 0.5, MOAIEaseType.EASE_IN)
        action:setListener(MOAITimer.EVENT_STOP, function()
          if _menu_root ~= nil then
            _menu_root:remove(_menu_root.gameModeBG)
            _menu_root.gameModeBG = nil
          end
        end)
      end
    else
      local action = _menu_root.gameModeBG:seekLoc(0, device.ui_height / 2 - 70, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        if _menu_root ~= nil then
          _menu_root:remove(_menu_root.gameModeBG)
          _menu_root.gameModeBG = nil
        end
      end)
    end
  end
  _menu_root:remove(_menu_root.topBarBG)
  _menu_root.topBarBG = nil
  _storemenu_close({
    store_menu = move.store_menu
  })
  if move.bottom_bar and _menu_root.bottomNavBG ~= nil then
    do
      local action = _menu_root.bottomNavBG:seekLoc(0, -device.ui_height / 2 - 120, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        if _menu_root ~= nil then
          _menu_root:remove(_menu_root.bottomNavBG)
          _menu_root.bottomNavBG = nil
        end
      end)
    end
  elseif _menu_root.bottomNavBG ~= nil and _menu_root ~= nil then
    _menu_root:remove(_menu_root.bottomNavBG)
    _menu_root.bottomNavBG = nil
  end
  if move.forward then
    do
      local action = _galaxymap_root:seekLoc(-device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_galaxymap_root)
        _galaxymap_root = nil
      end)
    end
  elseif move.back then
    do
      local action = _galaxymap_root:seekLoc(device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_galaxymap_root)
        _galaxymap_root = nil
      end)
    end
  else
    submenuLayer:remove(_galaxymap_root)
    _galaxymap_root = nil
  end
  galaxymapLayer1:clear()
  galaxymapLayer2:clear()
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  if scrollbar and scrollAction ~= nil then
    scrollAction:stop()
    scrollAction = nil
  end
  scrollbar = nil
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  curScreen = nil
end
local galaxymap_animate
local function _galaxymap_show(move)
  if move == nil then
    move = {empty = true}
  end
  local submenu_height = device.ui_height - 100 - 90 - 60 - 70
  local submenu_y = -70
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  _galaxymap_show_mode(gameMode)
  _storemenu_show("galaxymap", true, nil, {
    store_menu = move.store_menu
  })
  local topBarBG = _menu_root:add(ui.Image.new("menuTopBars.atlas.png#topBarGalaxyMap.png"))
  if not profile.excludeAds then
    topBarBG:setLoc(0, device.ui_height / 2 - 150)
  else
    topBarBG:setLoc(0, device.ui_height / 2 - 50)
  end
  _menu_root.topBarBG = topBarBG
  local topBarBGPickBox = topBarBG:add(ui.PickBox.new(device.ui_width, 100))
  local topBarText = topBarBG:add(ui.TextBox.new(_("Galaxy Map"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  topBarText:setLoc(0, -6)
  if #screenHistory > 0 then
    do
      local backBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconBack.png"))
      backBtn._down:setColor(0.5, 0.5, 0.5)
      backBtn:setLoc(-device.ui_width / 2 + 42, 0)
      backBtn.handleTouch = Button_handleTouch
      local function backBtn_onClick()
        if not screenAction:isActive() then
          galaxymap_close({back = true})
          local screen = table_remove(screenHistory)
          if screen == "achievements" then
            achievements_show({back = true})
          elseif screen == "defeat" then
            defeat_show({back = true})
          elseif screen == "leaderboard" then
            leaderboard_show({back = true})
          end
          soundmanager.onSFX("onPageSwipeBack")
        end
      end
      backBtn.onClick = backBtn_onClick
      if device.os == device.OS_ANDROID then
        local function callback()
          backBtn_onClick()
          return true
        end
        table_insert(android_back_button_queue, callback)
        MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
      end
    end
  elseif device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local menuBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconHome.png"))
  menuBtn._down:setColor(0.5, 0.5, 0.5)
  menuBtn:setLoc(device.ui_width / 2 - 42, 0)
  menuBtn.handleTouch = Button_handleTouch
  function menuBtn:onClick()
    menu_close()
    mainmenu_show()
    soundmanager.onSFX("onPageSwipeBack")
  end
  _galaxymap_root = ui.Group.new()
  if gameMode == "galaxy" then
    if move.forward then
      _galaxymap_root:setLoc(device.ui_width * 2, 0)
      _galaxymap_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
    elseif move.back then
      _galaxymap_root:setLoc(-device.ui_width * 2, 0)
      _galaxymap_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
    end
    do
      local lastCompletedGalaxy, lastCompletedSystem, lastCompletedIndex = _get_last_completed_galaxy_system()
      local lastLevelGalaxyIndex, lastLevelSystemIndex = level_get_galaxy_system()
      if move.animate and lastLevelSystemIndex ~= 1 and lastLevelSystemIndex ~= 41 then
        _galaxymap_create_galaxy(lastLevelGalaxyIndex or levelGalaxyIndex or lastCompletedGalaxy)
        _galaxymap_animate_item(lastLevelGalaxyIndex or levelGalaxyIndex or lastCompletedGalaxy, math.min(lastLevelSystemIndex or levelSystemIndex or lastCompletedSystem + 1, 40))
      elseif lastLevelSystemIndex == 1 or lastLevelSystemIndex == 41 then
        _galaxymap_create_galaxy(lastLevelGalaxyIndex or levelGalaxyIndex or lastCompletedGalaxy)
        do
          local item = _galaxymap_create_item(lastLevelGalaxyIndex or levelGalaxyIndex or lastCompletedGalaxy, math.min(lastLevelSystemIndex or levelSystemIndex or lastCompletedSystem + 1, 40))
          _galaxymap_root:add(item)
          _galaxymap_root.item = item
        end
      else
        _galaxymap_create_galaxy(levelGalaxyIndex or lastLevelGalaxyIndex or lastCompletedGalaxy)
        local item = _galaxymap_create_item(levelGalaxyIndex or lastLevelGalaxyIndex or lastCompletedGalaxy, math.min(levelSystemIndex or lastLevelSystemIndex or lastCompletedSystem + 1, 40))
        _galaxymap_root:add(item)
        _galaxymap_root.item = item
      end
      if not move.animate or lastLevelSystemIndex == 1 or lastLevelSystemIndex == 41 then
        do
          local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
          if move.bottom_bar then
            bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
            bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
          else
            bottomNavBG:setLoc(0, -device.ui_height / 2 - 8)
          end
          _menu_root.bottomNavBG = bottomNavBG
          local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
          bottomNavBGPickBox:setLoc(0, -20)
          local continueBtnGlow = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#largeButtonGlow.png"))
          continueBtnGlow:setColor(0.25, 0.25, 0.25, 0)
          continueBtnGlow:setScl(0.995, 0.995)
          continueBtnGlow:setLoc(0, 45)
          _galaxymap_root.continueBtnGlowAction = uiAS:repeatcall(0.5, function()
            if continueBtnGlow.active then
              continueBtnGlow:seekColor(0.25, 0.25, 0.25, 0, 0.5, MOAIEaseType.EASE_IN)
              continueBtnGlow.active = nil
              continueBtnGlow.wait = true
            elseif continueBtnGlow.wait then
              continueBtnGlow.wait = nil
            else
              continueBtnGlow:seekColor(1, 1, 1, 0, 0.5, MOAIEaseType.EASE_IN)
              continueBtnGlow.active = true
            end
          end)
          local continueBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#largeButton.png"))
          continueBtn._down:setColor(0.5, 0.5, 0.5)
          continueBtn:setLoc(0, 50)
          local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
          continueBtnText:setLoc(-15, 0)
          local continueBtnIcon = continueBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
          continueBtnIcon:setLoc(70, 0)
          local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
          continueBtnText:setLoc(-15, 0)
          local continueBtnIcon = continueBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
          continueBtnIcon:setLoc(70, 0)
          continueBtn.handleTouch = Button_handleTouch
          function continueBtn:onClick()
            if not screenAction:isActive() then
              table_insert(screenHistory, "galaxymap")
              galaxymap_close({forward = true})
              showShopPopup = true
              showPerkPopup = true
              fleet_show({forward = true, store_filter = true})
              soundmanager.onSFX("onPageSwipeForward")
            end
          end
        end
      end
    end
  elseif gameMode == "survival" then
    _galaxymap_mode_survival_show(levelGalaxyIndex)
    do
      local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
      if move.bottom_bar then
        bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
        bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
      else
        bottomNavBG:setLoc(0, -device.ui_height / 2 - 8)
      end
      _menu_root.bottomNavBG = bottomNavBG
      local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
      bottomNavBGPickBox:setLoc(0, -20)
      local continueBtnGlow = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#largeButtonGlow.png"))
      continueBtnGlow:setColor(0.25, 0.25, 0.25, 0)
      continueBtnGlow:setScl(0.995, 0.995)
      continueBtnGlow:setLoc(0, 45)
      _galaxymap_root.continueBtnGlowAction = uiAS:repeatcall(0.5, function()
        if continueBtnGlow.active then
          continueBtnGlow:seekColor(0.25, 0.25, 0.25, 0, 0.5, MOAIEaseType.EASE_IN)
          continueBtnGlow.active = nil
          continueBtnGlow.wait = true
        elseif continueBtnGlow.wait then
          continueBtnGlow.wait = nil
        else
          continueBtnGlow:seekColor(1, 1, 1, 0, 0.5, MOAIEaseType.EASE_IN)
          continueBtnGlow.active = true
        end
      end)
      local continueBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#largeButton.png"))
      continueBtn._down:setColor(0.5, 0.5, 0.5)
      continueBtn:setLoc(0, 50)
      local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      continueBtnText:setLoc(-15, 0)
      local continueBtnIcon = continueBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
      continueBtnIcon:setLoc(70, 0)
      local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      continueBtnText:setLoc(-15, 0)
      local continueBtnIcon = continueBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
      continueBtnIcon:setLoc(70, 0)
      continueBtn.handleTouch = Button_handleTouch
      function continueBtn:onClick()
        if not screenAction:isActive() then
          table_insert(screenHistory, "galaxymap")
          galaxymap_close({forward = true})
          showShopPopup = true
          showPerkPopup = true
          fleet_show({forward = true, store_filter = true})
          soundmanager.onSFX("onPageSwipeForward")
        end
      end
    end
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  submenuLayer:add(_galaxymap_root)
  if levelSystemIndex == 1 then
    popups.show("on_g" .. levelGalaxyIndex .. "_start", true)
  end
  popups.show("on_g" .. levelGalaxyIndex .. "_s" .. levelSystemIndex .. "_map", true)
  curScreen = "galaxymap"
end
function galaxymap_show(move)
  update.apply(function()
    _galaxymap_show(move)
  end)
  if not profile.excludeAds then
    update.spinnerSetLoc(device.ui_width / 2 - 100, device.ui_height / 2 - 150)
  else
    update.spinnerSetLoc(device.ui_width / 2 - 100, device.ui_height / 2 - 50)
  end
end
local function _achievements_items_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  local submenu_height = device.ui_height - 100 - 60
  local submenu_y = -80
  if _menu_root.bottomNavBG ~= nil then
    submenu_height = submenu_height - 90
    submenu_y = submenu_y + 45
  end
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local items_group = self.items_group
  if eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    if 0 < math.max(items_group.numItems * items_group.item_height - submenu_height, 0) then
      if not exclude_capture then
        ui.capture(self)
      end
      scrolling = true
      lastX = x
      lastY = y
      diffX = 0
      diffY = 0
      if scrollbar == nil then
        scrollbar = ui.Group.new()
        do
          local scrollbar_fill = scrollbar:add(ui.Image.new("scrollbar_fill.png"))
          scrollbar_fill:setScl(1, 3.5)
          scrollbar.fill = scrollbar_fill
          local scrollbar_top = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_top:setLoc(0, 36)
          scrollbar.top = scrollbar_top
          local scrollbar_bot = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_bot:setLoc(0, -36)
          scrollbar_bot:setScl(1, -1)
          scrollbar.bot = scrollbar_bot
          local groupX, groupY = items_group:getLoc()
          local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
          scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70))
          scrollbar.fill:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.top:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.bot:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          self:add(scrollbar)
        end
      else
        if scrollbar_fadeOutActions.fill ~= nil and scrollbar_fadeOutActions.fill:isActive() then
          scrollbar_fadeOutActions.fill:stop()
          scrollbar_fadeOutActions.top:stop()
          scrollbar_fadeOutActions.bot:stop()
        end
        scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
      end
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
  elseif eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    if not exclude_capture then
      ui.capture(nil)
    end
    scrolling = false
    if scrollbar ~= nil and scrollbar.velocityY ~= nil then
      scrollbar.velocityY = scrollbar.velocityY + diffY
    elseif scrollbar ~= nil then
      scrollbar.velocityY = diffY
    end
    if scrollAction == nil then
      scrollAction = uiAS:wrap(function(dt)
        if scrollbar ~= nil then
          do
            local groupX, groupY = items_group:getLoc()
            local newY = util.clamp(groupY - scrollbar.velocityY, 0, math.max(items_group.numItems * items_group.item_height - submenu_height, 0))
            items_group:setLoc(0, util.roundNumber(newY))
            local groupX, groupY = items_group:getLoc()
            local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
            scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70))
            scrollbar.velocityY = scrollbar.velocityY + scrollbar.velocityY * -1 * dt * 0.03 * device.dpi
            if not scrolling and abs(scrollbar.velocityY) < 0.5 then
              scrollAction:stop()
              scrollAction = nil
            end
          end
        else
          scrollAction:stop()
          scrollAction = nil
        end
      end, function()
        if not scrolling and scrollbar ~= nil then
          if scrollbar_fadeInActions.fill ~= nil and scrollbar_fadeInActions.fill:isActive() then
            scrollbar_fadeInActions.fill:stop()
            scrollbar_fadeInActions.top:stop()
            scrollbar_fadeInActions.bot:stop()
          end
          scrollbar_fadeOutActions.fill = scrollbar.fill:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.top = scrollbar.top:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.bot = scrollbar.bot:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.fill:setListener(MOAITimer.EVENT_STOP, function()
            if not scrolling and self ~= nil then
              self:remove(scrollbar)
              scrollbar = nil
            end
          end)
        end
      end)
    end
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE and scrolling then
    diffY = lastY - y
    local groupX, groupY = items_group:getLoc()
    local newY = util.clamp(groupY - diffY, 0, math.max(items_group.numItems * items_group.item_height - submenu_height, 0))
    items_group:setLoc(0, util.roundNumber(newY))
    if scrollbar ~= nil then
      local groupX, groupY = items_group:getLoc()
      local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
      scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70))
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
    lastX = x
    lastY = y
  end
  return true
end
local function _achievements_create_item(def)
  local id = def.id
  local icon = def.icon
  local name = def.name
  local steps = def.steps
  if not profile.achievements[id] then
    local profileDef = {step = 0, unlock = false}
  end
  local achieved = profileDef.unlock
  local perc
  if not achieved then
    perc = 0
    perc = min(floor(profileDef.step / steps * 100), 100)
    if device.os == device.OS_IOS then
      gamecenter.update(id, perc)
    end
    if perc == 100 then
      profileDef.unlock = true
      profile:save()
      achieved = true
      _popup_achievement_show(def, true)
    end
  end
  local description
  if achieved then
    description = def.completed
  else
    description = def.toComplete
  end
  local item = ui.Group.new()
  local itemBG = item:add(ui.PickBox.new(device.ui_width, 100, "00000033"))
  itemBG.handleTouch = nil
  if achieved then
    local achievedBox = item:add(ui.NinePatch.new("boxAchievement9p.lua", device.ui_width - 40, 94))
    achievedBox:setLoc(0, 1)
  end
  local itemIcon = item:add(ui.Image.new(icon))
  itemIcon:setLoc(-device.ui_width / 2 + 65, 0)
  if achieved then
    itemIcon:setColor(unpack(UI_COLOR_GOLD))
  else
    itemIcon:setColor(unpack(UI_COLOR_GRAY_DARKEN))
    local percText = itemIcon:add(ui.TextBox.new("" .. perc .. "%", FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
    percText._textbox:clearAttrLink(MOAIColor.INHERIT_COLOR)
    percText:setLoc(0, -2)
  end
  if name ~= "" then
    local nameText = item:add(ui.TextBox.new(_(name), FONT_MEDIUM_BOLD, "ffffff", "left", device.ui_width - 20, nil, true))
    nameText:setLoc(110, 27)
    if achieved then
      nameText:setColor(1, 0.862745, 0.4745)
    end
  end
  if description ~= "" then
    local descriptionText = item:add(ui.TextBox.new(_(description), FONT_MEDIUM, "ffffff", "left", device.ui_width - 140, nil, true))
    descriptionText:setColor(unpack(UI_COLOR_GRAY))
    descriptionText:setLoc(50, -13)
    if achieved then
      descriptionText:setColor(unpack(UI_COLOR_GOLD))
    end
  end
  local topBorder = item:add(ui.Image.new("menuTemplate.atlas.png#listItemTop.png"))
  topBorder:setScl(device.ui_width / 4, 1)
  topBorder:setLoc(0, 49)
  local bottomBorder = item:add(ui.Image.new("menuTemplate.atlas.png#listItemBottom.png"))
  bottomBorder:setScl(device.ui_width / 4, 1)
  bottomBorder:setLoc(0, -49)
  return item
end
function achievements_close(move)
  if move == nil then
    move = {empty = true}
  end
  if _achievements_root.continueBtnGlowAction ~= nil then
    _achievements_root.continueBtnGlowAction:stop()
    _achievements_root.continueBtnGlowAction = nil
  end
  _menu_root:remove(_menu_root.topBarBG)
  _menu_root.topBarBG = nil
  _storemenu_close({
    store_menu = move.store_menu
  })
  if _menu_root.bottomNavBG ~= nil then
    if move.bottom_bar then
      do
        local action = _menu_root.bottomNavBG:seekLoc(0, -device.ui_height / 2 - 120, 0.5, MOAIEaseType.EASE_IN)
        action:setListener(MOAITimer.EVENT_STOP, function()
          _menu_root:remove(_menu_root.bottomNavBG)
          _menu_root.bottomNavBG = nil
        end)
      end
    else
      _menu_root:remove(_menu_root.bottomNavBG)
      _menu_root.bottomNavBG = nil
    end
  end
  if move.forward then
    do
      local action = _achievements_root:seekLoc(-device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_achievements_root)
        _achievements_root = nil
      end)
    end
  elseif move.back then
    do
      local action = _achievements_root:seekLoc(device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_achievements_root)
        _achievements_root = nil
      end)
    end
  else
    submenuLayer:remove(_achievements_root)
    _achievements_root = nil
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  if scrollbar and scrollAction ~= nil then
    scrollAction:stop()
    scrollAction = nil
  end
  scrollbar = nil
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  curScreen = nil
end
function achievements_show(move)
  if move == nil then
    move = {empty = true}
  end
  local submenu_height = device.ui_height - 100 - 60
  local submenu_y = -80
  if #screenHistory > 0 then
    submenu_height = submenu_height - 90
    submenu_y = submenu_y + 45
  end
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  _storemenu_show("achievements", true, nil, {
    store_menu = move.store_menu
  })
  local topBarBG = _menu_root:add(ui.Image.new("menuTopBars.atlas.png#topBarAchievements.png"))
  if not profile.excludeAds then
    topBarBG:setLoc(0, device.ui_height / 2 - 150)
  else
    topBarBG:setLoc(0, device.ui_height / 2 - 50)
  end
  _menu_root.topBarBG = topBarBG
  local topBarBGPickBox = topBarBG:add(ui.PickBox.new(device.ui_width, 100))
  local topBarText = topBarBG:add(ui.TextBox.new(_("Achievements"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  topBarText:setLoc(0, -6)
  local backBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconBack.png"))
  backBtn._down:setColor(0.5, 0.5, 0.5)
  backBtn:setLoc(-device.ui_width / 2 + 42, 0)
  backBtn.handleTouch = Button_handleTouch
  local function backBtn_onClick()
    if not screenAction:isActive() then
      if #screenHistory > 0 then
        achievements_close({back = true})
        do
          local screen = table_remove(screenHistory)
          if screen == "victory" then
            victory_show({back = true})
          elseif screen == "defeat" then
            defeat_show({back = true})
          elseif screen == "leaderboard" then
            leaderboard_show({back = true})
          end
        end
      else
        menu_close()
        mainmenu_show()
      end
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  backBtn.onClick = backBtn_onClick
  if device.os == device.OS_ANDROID then
    local function callback()
      backBtn_onClick()
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  if #screenHistory > 0 then
    local menuBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconHome.png"))
    menuBtn._down:setColor(0.5, 0.5, 0.5)
    menuBtn:setLoc(device.ui_width / 2 - 42, 0)
    menuBtn.handleTouch = Button_handleTouch
    function menuBtn:onClick()
      menu_close()
      mainmenu_show()
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  _achievements_root = ui.Group.new()
  local bg = _achievements_root:add(ui.PickBox.new(device.ui_width, submenu_height))
  bg:setLoc(0, submenu_y)
  bg.handleTouch = _achievements_items_handleTouch
  local items_group = _achievements_root:add(ui.Group.new())
  bg.items_group = items_group
  local DEFS = require("ShipData-Achievements")
  local items = {}
  local y = submenu_height / 2 + submenu_y - 49
  for i, def in ipairs(DEFS) do
    local item = items_group:add(_achievements_create_item(def))
    item:setLoc(0, y)
    y = y - 100
    table_insert(items, item)
  end
  items_group.numItems = #items
  items_group.item_height = 100
  _achievements_root.items = items
  if move.forward then
    _achievements_root:setLoc(device.ui_width * 2, 0)
    _achievements_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  elseif move.back then
    _achievements_root:setLoc(-device.ui_width * 2, 0)
    _achievements_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  end
  if #screenHistory > 0 then
    do
      local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
      if move.bottom_bar then
        bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
        bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
      else
        bottomNavBG:setLoc(0, -device.ui_height / 2 - 8)
      end
      _menu_root.bottomNavBG = bottomNavBG
      local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
      bottomNavBGPickBox:setLoc(0, -20)
      local continueBtnGlow = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#largeButtonGlow.png"))
      continueBtnGlow:setColor(0.25, 0.25, 0.25, 0)
      continueBtnGlow:setScl(0.995, 0.995)
      continueBtnGlow:setLoc(0, 45)
      _achievements_root.continueBtnGlowAction = uiAS:repeatcall(0.5, function()
        if continueBtnGlow.active then
          continueBtnGlow:seekColor(0.25, 0.25, 0.25, 0, 0.5, MOAIEaseType.EASE_IN)
          continueBtnGlow.active = nil
          continueBtnGlow.wait = true
        elseif continueBtnGlow.wait then
          continueBtnGlow.wait = nil
        else
          continueBtnGlow:seekColor(1, 1, 1, 0, 0.5, MOAIEaseType.EASE_IN)
          continueBtnGlow.active = true
        end
      end)
      local continueBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#largeButton.png"))
      continueBtn._down:setColor(0.5, 0.5, 0.5)
      continueBtn:setLoc(0, 50)
      local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      continueBtnText:setLoc(-15, 0)
      local continueBtnIcon = continueBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
      continueBtnIcon:setLoc(70, 0)
      local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      continueBtnText:setLoc(-15, 0)
      local continueBtnIcon = continueBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
      continueBtnIcon:setLoc(70, 0)
      continueBtn.handleTouch = Button_handleTouch
      function continueBtn:onClick()
        if not screenAction:isActive() then
          table_insert(screenHistory, "achievements")
          if galaxymap_animate == nil then
            achievements_close({forward = true})
            galaxymap_show({forward = true})
          else
            galaxymap_animate = nil
            local lastLevelGalaxyIndex, lastLevelSystemIndex = level_get_galaxy_system()
            if lastLevelSystemIndex ~= 1 and lastLevelSystemIndex ~= 41 then
              achievements_close({forward = true, bottom_bar = true})
            else
              achievements_close({forward = true})
            end
            galaxymap_show({animate = true})
          end
          soundmanager.onSFX("onPageSwipeForward")
        end
      end
    end
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  submenuLayer:add(_achievements_root)
  curScreen = "achievements"
end
local function _defeat_create_item(animate)
  local submenu_height = device.ui_height - 100 - 90 - 60 - 60
  local submenu_y = -65
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local item = ui.Group.new()
  local systemBox = item:add(ui.NinePatch.new("boxPlain9p.lua", device.ui_width + 20, 60))
  systemBox:setLoc(0, (submenu_height + 60) / 2 + submenu_y + 6)
  if curGameMode == "galaxy" then
    levelGalaxyIndex = levelGalaxyIndex or 1
    levelSystemIndex = levelSystemIndex or 1
    do
      local idx = (levelGalaxyIndex - 1) * 40 + levelSystemIndex
      local levelDef = GALAXY_DATA[idx]
      local systemText = systemBox:add(ui.TextBox.new("" .. levelGalaxyIndex .. "." .. levelSystemIndex .. ": " .. _(levelDef["System Name"]), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      systemText:setLoc(0, -2)
    end
  elseif curGameMode == "survival" then
    local systemText = systemBox:add(ui.TextBox.new(_("Survival Mode"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
    systemText:setLoc(0, -2)
  end
  if animate then
    do
      local pickbox = item:add(ui.PickBox.new(device.ui_width, submenu_height + 90))
      pickbox:setLoc(0, submenu_y - 45)
      function pickbox.onClick()
        _defeat_root.forward = true
      end
      _menu_root.alloyText:setString("" .. util.commasInNumbers(endGameStats.baseAlloy + (endGameStats.plusAlloy or 0)))
      _menu_root.levelText:setString(string.format(_("LVL %02d"), endGameStats.baseLevel))
      local xpDef = require("ShipData-ExpDef")
      local xpLevelDef = xpDef[endGameStats.baseLevel]
      local baseXPToNextLevel, basePerc
      if xpLevelDef ~= nil then
        baseXPToNextLevel = xpLevelDef.xpToAdvance
      end
      if baseXPToNextLevel ~= nil and baseXPToNextLevel ~= 0 then
        basePerc = endGameStats.baseXP / baseXPToNextLevel
      else
        basePerc = 1
      end
      _menu_root.levelProgressFillbar:setFill(0, basePerc)
      local resultsKillBox, defeatEmblem
      if curGameMode == "galaxy" then
        resultsKillBox = item:add(ui.Image.new("menuTemplate.atlas.png#resultsKillBox.png"))
        resultsKillBox:setScl(0, 1)
        resultsKillBox:setLoc(0, submenu_y + 125)
        defeatEmblem = item:add(ui.Image.new("menuTemplate2.atlas.png#defeatEmblem.png"))
        defeatEmblem:setLoc(0, submenu_y + 125)
      elseif curGameMode == "survival" then
        resultsKillBox = item:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxSurvival.png"))
        resultsKillBox:setLoc(0, submenu_y + 145)
      end
      _defeat_root.animateThread = MOAIThread.new()
      _defeat_root.animateThread:run(function()
        local AS = actionset.new()
        local action
        action = MOAIEaseDriver.new()
        action:setLength(0.5)
        AS:wrap(action:start())
        while action:isActive() do
          if _defeat_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _defeat_root.forward = nil
          end
          coroutine.yield()
        end
        if curGameMode == "galaxy" then
          action = AS:wrap(defeatEmblem:seekLoc(-140, submenu_y + 125, 1, MOAIEaseType.EASE_IN))
          AS:wrap(resultsKillBox:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN))
          AS:wrap(resultsKillBox:seekLoc(40, submenu_y + 125, 1, MOAIEaseType.EASE_IN))
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
          do
            local wavesCompletedText = resultsKillBox:add(ui.TextBox.new(_("Waves Completed"), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
            wavesCompletedText:setColor(0, 0, 0, 0)
            action = AS:wrap(wavesCompletedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            wavesCompletedText:setLoc(110, 75)
            local numWavesText = resultsKillBox:add(ui.TextBox.new("0" .. "/" .. endGameStats.levelSpawns, FONT_XLARGE, "ffffff", "center", nil, nil, true))
            numWavesText:setColor(0, 0, 0, 0)
            AS:wrap(numWavesText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            numWavesText:setLoc(110, 20)
            while action:isActive() do
              if _defeat_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _defeat_root.forward = nil
              end
              coroutine.yield()
            end
            local text = numWavesText
            local start = 0
            local goal = min(endGameStats.levelWave - 1, endGameStats.levelSpawns - 1)
            local length = 0.75
            local prefix = ""
            local suffix = "/" .. endGameStats.levelSpawns
            _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
            if start ~= goal then
              action = MOAIEaseDriver.new()
              action:setLength(length + 0.25)
              AS:wrap(action:start())
              while action:isActive() do
                if _defeat_root.forward and not AS:isPaused() then
                  AS:throttle(10)
                  _defeat_root.forward = nil
                end
                coroutine.yield()
              end
            end
            local enemyKillValueText = resultsKillBox:add(ui.TextBox.new(_("Enemy Kill Value"), FONT_SMALL_BOLD, "ffffff", "left", 260, nil, true))
            enemyKillValueText:setColor(0, 0, 0, 0)
            action = AS:wrap(enemyKillValueText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            enemyKillValueText:setLoc(100, -40)
            local enemyKillValueNumText = resultsKillBox:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "right", 260, nil, true))
            enemyKillValueNumText:setColor(0, 0, 0, 0)
            AS:wrap(enemyKillValueNumText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            enemyKillValueNumText:setLoc(100, -40)
            while action:isActive() do
              if _defeat_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _defeat_root.forward = nil
              end
              coroutine.yield()
            end
            local text = enemyKillValueNumText
            local start = 0
            local goal = endGameStats.baseScore
            local length = 0.75
            local prefix = ""
            local suffix = ""
            _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
            if start ~= goal then
              action = MOAIEaseDriver.new()
              action:setLength(length + 0.25)
              AS:wrap(action:start())
              while action:isActive() do
                if _defeat_root.forward and not AS:isPaused() then
                  AS:throttle(10)
                  _defeat_root.forward = nil
                end
                coroutine.yield()
              end
            end
            local unusedWarpCrystalText = resultsKillBox:add(ui.TextBox.new(_("Unused"), FONT_SMALL_BOLD, "ffffff", "left", 260, nil, true))
            unusedWarpCrystalText:setColor(0, 0, 0, 0)
            action = AS:wrap(unusedWarpCrystalText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            unusedWarpCrystalText:setLoc(100, -70)
            local unusedWarpCrystalsIcon = resultsKillBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystalMed.png"))
            unusedWarpCrystalsIcon:setColor(0, 0, 0, 0)
            AS:wrap(unusedWarpCrystalsIcon:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            unusedWarpCrystalsIcon:setLoc(60, -68)
            local unusedWarpCrystalNumText = resultsKillBox:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 260, nil, true))
            unusedWarpCrystalNumText:setColor(0, 0, 0, 0)
            AS:wrap(unusedWarpCrystalNumText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            unusedWarpCrystalNumText:setLoc(100, -70)
            while action:isActive() do
              if _defeat_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _defeat_root.forward = nil
              end
              coroutine.yield()
            end
            local text = unusedWarpCrystalNumText
            local start = 0
            local goal = endGameStats.plusScoreCrystals
            local length = 0.75
            local prefix = "+ "
            local suffix = ""
            _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
            if start ~= goal then
              action = MOAIEaseDriver.new()
              action:setLength(length + 0.25)
              AS:wrap(action:start())
              while action:isActive() do
                if _defeat_root.forward and not AS:isPaused() then
                  AS:throttle(10)
                  _defeat_root.forward = nil
                end
                coroutine.yield()
              end
            end
            local finalScoreText = resultsKillBox:add(ui.TextBox.new(_("Final Score"), FONT_SMALL_BOLD, "ffffff", "left", 260, nil, true))
            finalScoreText:clearAttrLink(MOAIColor.INHERIT_COLOR)
            finalScoreText:setColor(0, 0, 0, 0)
            action = AS:wrap(finalScoreText:seekColor(UI_COLOR_GOLD[1], UI_COLOR_GOLD[2], UI_COLOR_GOLD[3], 1, 0.5, MOAIEaseType.EASE_IN))
            finalScoreText:setLoc(100, -100)
            local finalScoreNumText = resultsKillBox:add(ui.TextBox.new("= 0", FONT_SMALL_BOLD, "ffffff", "right", 260, nil, true))
            finalScoreNumText:clearAttrLink(MOAIColor.INHERIT_COLOR)
            finalScoreNumText:setColor(0, 0, 0, 0)
            AS:wrap(finalScoreNumText:seekColor(UI_COLOR_GOLD[1], UI_COLOR_GOLD[2], UI_COLOR_GOLD[3], 1, 0.5, MOAIEaseType.EASE_IN))
            finalScoreNumText:setLoc(100, -100)
            while action:isActive() do
              if _defeat_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _defeat_root.forward = nil
              end
              coroutine.yield()
            end
            local text = finalScoreNumText
            local start = 0
            local goal = scores.score
            local length = 0.75
            local prefix = "= "
            local suffix = ""
            _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
            if start ~= goal then
              action = MOAIEaseDriver.new()
              action:setLength(length + 0.25)
              AS:wrap(action:start())
              while action:isActive() do
                if _defeat_root.forward and not AS:isPaused() then
                  AS:throttle(10)
                  _defeat_root.forward = nil
                end
                coroutine.yield()
              end
            end
            AS:throttle(1)
          end
        elseif curGameMode == "survival" then
          local wavesCompletedText = resultsKillBox:add(ui.TextBox.new(_("Waves Completed"), FONT_SMALL_BOLD, "ffffff", "left", 320, nil, true))
          wavesCompletedText:setColor(0, 0, 0, 0)
          action = AS:wrap(wavesCompletedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          wavesCompletedText:setLoc(100, 65)
          local wavesCompletedNumText = resultsKillBox:add(ui.TextBox.new("0 * " .. SURVIVAL_MODE_SCORE_WAVE_MULTIPLIER, FONT_SMALL_BOLD, "ffffff", "right", 320, nil, true))
          wavesCompletedNumText:setColor(0, 0, 0, 0)
          AS:wrap(wavesCompletedNumText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          wavesCompletedNumText:setLoc(100, 65)
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
          local text = wavesCompletedNumText
          local start = 0
          local goal = endGameStats.levelWave
          local length = 0.75
          local prefix = ""
          local suffix = " * " .. SURVIVAL_MODE_SCORE_WAVE_MULTIPLIER
          _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
          if start ~= goal then
            action = MOAIEaseDriver.new()
            action:setLength(length + 0.25)
            AS:wrap(action:start())
            while action:isActive() do
              if _defeat_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _defeat_root.forward = nil
              end
              coroutine.yield()
            end
          end
          local enemyKillValueText = resultsKillBox:add(ui.TextBox.new(_("Enemy Kill Value"), FONT_SMALL_BOLD, "ffffff", "left", 320, nil, true))
          enemyKillValueText:setColor(0, 0, 0, 0)
          action = AS:wrap(enemyKillValueText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          enemyKillValueText:setLoc(100, 35)
          local enemyKillValueNumText = resultsKillBox:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "right", 320, nil, true))
          enemyKillValueNumText:setColor(0, 0, 0, 0)
          AS:wrap(enemyKillValueNumText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          enemyKillValueNumText:setLoc(100, 35)
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
          local text = enemyKillValueNumText
          local start = 0
          local goal = endGameStats.baseScore
          local length = 0.75
          local prefix = "+ "
          local suffix = ""
          _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
          if start ~= goal then
            action = MOAIEaseDriver.new()
            action:setLength(length + 0.25)
            AS:wrap(action:start())
            while action:isActive() do
              if _defeat_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _defeat_root.forward = nil
              end
              coroutine.yield()
            end
          end
          local spentWarpCrystalText = resultsKillBox:add(ui.TextBox.new(_("Spent"), FONT_SMALL, "ffffff", "left", 320, nil, true))
          spentWarpCrystalText:setColor(0, 0, 0, 0)
          action = AS:wrap(spentWarpCrystalText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          spentWarpCrystalText:setLoc(100, 5)
          local spentWarpCrystalsIcon = resultsKillBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystalMed.png"))
          spentWarpCrystalsIcon:setColor(0, 0, 0, 0)
          AS:wrap(spentWarpCrystalsIcon:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          spentWarpCrystalsIcon:setLoc(15, 7)
          local spentWarpCrystalNumText = resultsKillBox:add(ui.TextBox.new("- 0", FONT_SMALL_BOLD, "ffffff", "right", 320, nil, true))
          spentWarpCrystalNumText:setColor(0, 0, 0, 0)
          AS:wrap(spentWarpCrystalNumText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          spentWarpCrystalNumText:setLoc(100, 5)
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
          local text = spentWarpCrystalNumText
          local start = 0
          local goal = endGameStats.spentScoreCrystals
          local length = 0.75
          local prefix = "- "
          local suffix = ""
          _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
          if start ~= goal then
            action = MOAIEaseDriver.new()
            action:setLength(length + 0.25)
            AS:wrap(action:start())
            while action:isActive() do
              if _defeat_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _defeat_root.forward = nil
              end
              coroutine.yield()
            end
          end
          local finalScoreText = resultsKillBox:add(ui.TextBox.new(_("Final Score"), FONT_XLARGE, "ffffff", "left", 520, nil, true))
          finalScoreText:setColor(0, 0, 0, 0)
          action = AS:wrap(finalScoreText:seekColor(UI_COLOR_GOLD[1], UI_COLOR_GOLD[2], UI_COLOR_GOLD[3], 1, 0.5, MOAIEaseType.EASE_IN))
          finalScoreText:setLoc(0, -70)
          local finalScoreNumText = resultsKillBox:add(ui.TextBox.new("0", FONT_XLARGE, "ffffff", "right", 520, nil, true))
          finalScoreNumText:setColor(0, 0, 0, 0)
          AS:wrap(finalScoreNumText:seekColor(UI_COLOR_GOLD[1], UI_COLOR_GOLD[2], UI_COLOR_GOLD[3], 1, 0.5, MOAIEaseType.EASE_IN))
          finalScoreNumText:setLoc(0, -70)
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
          local text = finalScoreNumText
          local start = 0
          local goal = scores.score
          local length = 0.75
          local prefix = ""
          local suffix = ""
          _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
          if start ~= goal then
            action = MOAIEaseDriver.new()
            action:setLength(length + 0.25)
            AS:wrap(action:start())
            while action:isActive() do
              if _defeat_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _defeat_root.forward = nil
              end
              coroutine.yield()
            end
          end
          if profile.survivalHighScore > endGameStats.baseHighScore then
            do
              local highScoreText = resultsKillBox:add(ui.TextBox.new(_("New High Score!"), FONT_MEDIUM_BOLD, "ffffff", "center", 520, nil, true))
              highScoreText:setColor(0, 0, 0, 0)
              action = AS:wrap(highScoreText:seekColor(UI_COLOR_GOLD[1], UI_COLOR_GOLD[2], UI_COLOR_GOLD[3], 1, 0.5, MOAIEaseType.EASE_IN))
              highScoreText:setLoc(0, -130)
            end
          else
            local highScoreText = resultsKillBox:add(ui.TextBox.new(string.format(_("Your All-Time High Score: %s"), util.commasInNumbers(profile.survivalHighScore)), FONT_SMALL_BOLD, "ffffff", "center", 520, nil, true))
            highScoreText:setColor(0, 0, 0, 0)
            action = AS:wrap(highScoreText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            highScoreText:setLoc(0, -130)
          end
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
          AS:throttle(1)
        end
        local alloyResultsBoxBG = item:add(ui.PickBox.new(2, 2))
        alloyResultsBoxBG:setColor(0, 0, 0, 0)
        action = AS:wrap(alloyResultsBoxBG:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        alloyResultsBoxBG:setScl(0.025, 1)
        alloyResultsBoxBG:setLoc(0, submenu_y - 92)
        alloyResultsBoxBG.handleTouch = nil
        local alloyResultsBoxBGLeft = alloyResultsBoxBG:add(ui.PickBox.new(370, 92, color.toHex(0, 0, 0, 0.34)))
        alloyResultsBoxBGLeft:setLoc(-113, 1)
        alloyResultsBoxBGLeft.handleTouch = nil
        local alloyResultsBoxBGLeftBorder = alloyResultsBoxBG:add(ui.PickBox.new(370, 2, color.toHex(0, 0, 0, 0.5)))
        alloyResultsBoxBGLeftBorder:setLoc(-113, -45)
        alloyResultsBoxBGLeftBorder.handleTouch = nil
        local alloyResultsBoxBGRight = alloyResultsBoxBG:add(ui.PickBox.new(226, 92, color.toHex(0, 0, 0, 0.45)))
        alloyResultsBoxBGRight:setLoc(185, 1)
        alloyResultsBoxBGRight.handleTouch = nil
        local alloyResultsBoxBGRightBorder = alloyResultsBoxBG:add(ui.PickBox.new(226, 2, color.toHex(0, 0, 0, 0.7)))
        alloyResultsBoxBGRightBorder:setLoc(185, -45)
        alloyResultsBoxBGRightBorder.handleTouch = nil
        local alloyResultsBoxBracketL = item:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketL.png"))
        alloyResultsBoxBracketL:setColor(0, 0, 0, 0)
        AS:wrap(alloyResultsBoxBracketL:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        alloyResultsBoxBracketL:setLoc(-5, submenu_y - 90)
        local alloyResultsBoxBracketR = item:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketR.png"))
        alloyResultsBoxBracketR:setColor(0, 0, 0, 0)
        AS:wrap(alloyResultsBoxBracketR:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        alloyResultsBoxBracketR:setLoc(5, submenu_y - 90)
        AS:wrap(alloyResultsBoxBG:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN))
        AS:wrap(alloyResultsBoxBracketL:seekLoc(-295, submenu_y - 90, 0.5, MOAIEaseType.EASE_IN))
        AS:wrap(alloyResultsBoxBracketR:seekLoc(295, submenu_y - 90, 0.5, MOAIEaseType.EASE_IN))
        while action:isActive() do
          if _defeat_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _defeat_root.forward = nil
          end
          coroutine.yield()
        end
        local PlusAlloyPerkUsed = false
        if curGameMode == "galaxy" and gameSessionAnalytics.perks ~= nil then
          for k, v in pairs(gameSessionAnalytics.perks) do
            if v == "plusAlloy" then
              PlusAlloyPerkUsed = true
              break
            end
          end
        end
        local AlloyCollectedText = alloyResultsBoxBG:add(ui.TextBox.new(_("Alloy Collected"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
        AlloyCollectedText:setColor(0, 0, 0, 0)
        action = AS:wrap(AlloyCollectedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        AlloyCollectedText:setLoc(-125, 32)
        local CollectedText = alloyResultsBoxBG:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
        CollectedText:setColor(0, 0, 0, 0)
        AS:wrap(CollectedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        CollectedText:setLoc(-25, 32)
        if PlusAlloyPerkUsed == false then
          CollectedText:setLoc(-25, 18)
          AlloyCollectedText:setLoc(-125, 18)
        end
        while action:isActive() do
          if _defeat_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _defeat_root.forward = nil
          end
          coroutine.yield()
        end
        local text = plusSurvivorBonusText
        local start = 0
        local goal = gameSessionAnalytics.currency.alloy.earned or 0
        local length = 0.75
        local prefix = "+ "
        local suffix = ""
        if PlusAlloyPerkUsed ~= false then
          goal = goal / 2
        end
        _textbox_countup_number(AS, CollectedText, start, goal, length, prefix, suffix, "onAlloyCount")
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
        end
        if curGameMode == "galaxy" then
          do
            local bonusText = alloyResultsBoxBG:add(ui.TextBox.new(_("Star Rating Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
            bonusText:setColor(0, 0, 0, 0)
            action = AS:wrap(bonusText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            bonusText:setLoc(-125, -1)
            local plusBonusText = alloyResultsBoxBG:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
            plusBonusText:setColor(0, 0, 0, 0)
            AS:wrap(plusBonusText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            plusBonusText:setLoc(-25, -1)
            if PlusAlloyPerkUsed == false then
              plusBonusText:setLoc(-25, -20)
              bonusText:setLoc(-125, -20)
            end
            while action:isActive() do
              if _defeat_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _defeat_root.forward = nil
              end
              coroutine.yield()
            end
            local text = plusBonusText
            local start = 0
            local goal = 0
            local length = 0.75
            local prefix = "+ "
            local suffix = ""
            _textbox_countup_number(AS, text, start, goal, length, prefix, suffix, "onAlloyCount")
            if start ~= goal then
              action = MOAIEaseDriver.new()
              action:setLength(length + 0.25)
              AS:wrap(action:start())
              while action:isActive() do
                if _defeat_root.forward and not AS:isPaused() then
                  AS:throttle(10)
                  _defeat_root.forward = nil
                end
                coroutine.yield()
              end
            end
          end
        elseif curGameMode == "survival" then
          local survivorBonusText = alloyResultsBoxBG:add(ui.TextBox.new(_("Survivor Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
          survivorBonusText:setColor(0, 0, 0, 0)
          action = AS:wrap(survivorBonusText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          survivorBonusText:setLoc(-125, -1)
          local plusSurvivorBonusText = alloyResultsBoxBG:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
          plusSurvivorBonusText:setColor(0, 0, 0, 0)
          AS:wrap(plusSurvivorBonusText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          plusSurvivorBonusText:setLoc(-25, -1)
          if PlusAlloyPerkUsed == false then
            plusSurvivorBonusText:setLoc(-25, -20)
            survivorBonusText:setLoc(-125, -20)
          end
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
          local text = plusSurvivorBonusText
          local start = 0
          local goal = endGameStats.survivalBonusAlloy or 0
          local length = 0.75
          local prefix = "+ "
          local suffix = ""
          _textbox_countup_number(AS, text, start, goal, length, prefix, suffix, "onAlloyCount")
          if start ~= goal then
            action = MOAIEaseDriver.new()
            action:setLength(length + 0.25)
            AS:wrap(action:start())
            while action:isActive() do
              if _defeat_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _defeat_root.forward = nil
              end
              coroutine.yield()
            end
          end
        end
        if PlusAlloyPerkUsed ~= false then
          local AlloyCollectedText = alloyResultsBoxBG:add(ui.TextBox.new(_("Perk Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
          AlloyCollectedText:setColor(0, 0, 0, 0)
          action = AS:wrap(AlloyCollectedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          AlloyCollectedText:setLoc(-125, -34)
          local CollectedText = alloyResultsBoxBG:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
          CollectedText:setColor(0, 0, 0, 0)
          AS:wrap(CollectedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          CollectedText:setLoc(-25, -34)
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
          local text = plusSurvivorBonusText
          local start = 0
          local goal = gameSessionAnalytics.currency.alloy.earned or 0
          local length = 0.75
          local prefix = "+ "
          local suffix = ""
          goal = goal / 2
          _textbox_countup_number(AS, CollectedText, start, goal, length, prefix, suffix, "onAlloyCount")
          if start ~= goal then
            action = MOAIEaseDriver.new()
            action:setLength(length + 0.25)
            AS:wrap(action:start())
            while action:isActive() do
              if _defeat_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _defeat_root.forward = nil
              end
              coroutine.yield()
            end
          end
        end
        local plusAlloyText = alloyResultsBoxBG:add(ui.TextBox.new(util.commasInNumbers(endGameStats.plusAlloy), FONT_XLARGE, "ffffff", "center", nil, nil, true))
        plusAlloyText:setString("0")
        plusAlloyText:setColor(0.898, 0.714, 0.215, 0)
        action = AS:wrap(plusAlloyText:seekColor(0.898, 0.714, 0.215, 1, 0.5, MOAIEaseType.EASE_IN))
        plusAlloyText:setLoc(220, -2)
        local iconAlloy = alloyResultsBoxBG:add(ui.Image.new("menuTemplateShared.atlas.png#iconAlloyLarge.png"))
        iconAlloy:setColor(0.898, 0.714, 0.215, 0)
        AS:wrap(iconAlloy:seekColor(0.898, 0.714, 0.215, 1, 0.5, MOAIEaseType.EASE_IN))
        iconAlloy:setLoc(220 - plusAlloyText._width / 2 - 40, 0)
        while action:isActive() do
          if _defeat_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _defeat_root.forward = nil
          end
          coroutine.yield()
        end
        local text = plusAlloyText
        local start = 0
        local goal = (endGameStats.plusAlloy or 0) + (gameSessionAnalytics.currency.alloy.earned or 0)
        local length = 0.75
        local prefix = ""
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix, "onAlloyCount")
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
        end
        local text = _menu_root.alloyText
        local start = (endGameStats.baseAlloy or 0) + (endGameStats.plusAlloy or 0)
        local goal = (endGameStats.baseAlloy or 0) + (endGameStats.plusAlloy or 0)
        local length = 0.75
        local prefix = ""
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix, "onAlloyCount")
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
        end
        AS:throttle(1)
        local xpResultsBoxBG = item:add(ui.PickBox.new(2, 2))
        xpResultsBoxBG:setColor(0, 0, 0, 0)
        action = AS:wrap(xpResultsBoxBG:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        xpResultsBoxBG:setScl(0.025, 1)
        xpResultsBoxBG:setLoc(0, submenu_y - 207)
        xpResultsBoxBG.handleTouch = nil
        local xpResultsBoxBGLeft = xpResultsBoxBG:add(ui.PickBox.new(370, 92, color.toHex(0, 0, 0, 0.34)))
        xpResultsBoxBGLeft:setLoc(-113, 1)
        xpResultsBoxBGLeft.handleTouch = nil
        local xpResultsBoxBGLeftBorder = xpResultsBoxBG:add(ui.PickBox.new(370, 2, color.toHex(0, 0, 0, 0.5)))
        xpResultsBoxBGLeftBorder:setLoc(-113, -45)
        xpResultsBoxBGLeftBorder.handleTouch = nil
        local xpResultsBoxBGRight = xpResultsBoxBG:add(ui.PickBox.new(226, 92, color.toHex(0, 0, 0, 0.45)))
        xpResultsBoxBGRight:setLoc(185, 1)
        xpResultsBoxBGRight.handleTouch = nil
        local xpResultsBoxBGRightBorder = xpResultsBoxBG:add(ui.PickBox.new(226, 2, color.toHex(0, 0, 0, 0.7)))
        xpResultsBoxBGRightBorder:setLoc(185, -45)
        xpResultsBoxBGRightBorder.handleTouch = nil
        local xpResultsBoxBracketL = item:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketL.png"))
        xpResultsBoxBracketL:setColor(0, 0, 0, 0)
        AS:wrap(xpResultsBoxBracketL:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        xpResultsBoxBracketL:setLoc(-5, submenu_y - 205)
        local xpResultsBoxBracketR = item:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketR.png"))
        xpResultsBoxBracketR:setColor(0, 0, 0, 0)
        AS:wrap(xpResultsBoxBracketR:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        xpResultsBoxBracketR:setLoc(5, submenu_y - 205)
        AS:wrap(xpResultsBoxBG:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN))
        AS:wrap(xpResultsBoxBracketL:seekLoc(-295, submenu_y - 205, 0.5, MOAIEaseType.EASE_IN))
        AS:wrap(xpResultsBoxBracketR:seekLoc(295, submenu_y - 205, 0.5, MOAIEaseType.EASE_IN))
        while action:isActive() do
          if _defeat_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _defeat_root.forward = nil
          end
          coroutine.yield()
        end
        local xpEarnedText = xpResultsBoxBG:add(ui.TextBox.new(_("XP Earned"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
        xpEarnedText:setColor(0, 0, 0, 0)
        action = AS:wrap(xpEarnedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        xpEarnedText:setLoc(-125, 0)
        local plusXPEarnedText = xpResultsBoxBG:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
        plusXPEarnedText:setColor(0, 0, 0, 0)
        AS:wrap(plusXPEarnedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        plusXPEarnedText:setLoc(-25, 0)
        if endGameStats.perkBonusXP ~= nil then
          xpEarnedText:setLoc(-125, 20)
          plusXPEarnedText:setLoc(-25, 20)
        end
        while action:isActive() do
          if _defeat_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _defeat_root.forward = nil
          end
          coroutine.yield()
        end
        local text = plusXPEarnedText
        local start = 0
        local goal = endGameStats.basePlusXP or 0
        local length = 0.75
        local prefix = "+ "
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
        end
        if endGameStats.perkBonusXP ~= nil then
          local perkBonusText = xpResultsBoxBG:add(ui.TextBox.new(_("Perk Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
          perkBonusText:setColor(0, 0, 0, 0)
          action = AS:wrap(perkBonusText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          perkBonusText:setLoc(-125, -18)
          local plusPerkBonusText = xpResultsBoxBG:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
          plusPerkBonusText:setColor(0, 0, 0, 0)
          AS:wrap(plusPerkBonusText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          plusPerkBonusText:setLoc(-25, -18)
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
          local text = plusPerkBonusText
          local start = 0
          local goal = endGameStats.perkBonusXP or 0
          local length = 0.75
          local prefix = "+ "
          local suffix = ""
          _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
          if start ~= goal then
            action = MOAIEaseDriver.new()
            action:setLength(length + 0.25)
            AS:wrap(action:start())
            while action:isActive() do
              if _defeat_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _defeat_root.forward = nil
              end
              coroutine.yield()
            end
          end
        end
        local plusXPText = xpResultsBoxBG:add(ui.TextBox.new(util.commasInNumbers(scores.xp), FONT_XLARGE, "ffffff", "center", nil, nil, true))
        plusXPText:setString("0")
        plusXPText:setColor(0.898, 0.714, 0.215, 0)
        action = AS:wrap(plusXPText:seekColor(0.898, 0.714, 0.215, 1, 0.5, MOAIEaseType.EASE_IN))
        plusXPText:setLoc(220, -2)
        local iconXP = xpResultsBoxBG:add(ui.Image.new("menuTemplateShared.atlas.png#iconPlayerLevelLarge.png"))
        iconXP:setColor(0.898, 0.714, 0.215, 0)
        AS:wrap(iconXP:seekColor(0.898, 0.714, 0.215, 1, 0.5, MOAIEaseType.EASE_IN))
        iconXP:setLoc(220 - plusXPText._width / 2 - 40, 0)
        while action:isActive() do
          if _defeat_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _defeat_root.forward = nil
          end
          coroutine.yield()
        end
        local text = plusXPText
        local start = 0
        local goal = scores.xp or 0
        local length = 0.75
        local prefix = ""
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _defeat_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _defeat_root.forward = nil
            end
            coroutine.yield()
          end
        end
        local numLevelUps = profile.level - endGameStats.baseLevel + 1
        local level = endGameStats.baseLevel
        local xp = endGameStats.baseXP + scores.xp
        local menu_root_alloyText = (endGameStats.baseAlloy or 0) + (endGameStats.plusAlloy or 0)
        for i = 1, numLevelUps do
          local xpLevelDef = xpDef[level]
          local xpToNextLevel
          if xpLevelDef ~= nil then
            xpToNextLevel = xpLevelDef.xpToAdvance
          end
          if xpToNextLevel ~= nil and xpToNextLevel ~= 0 then
            if xp >= xpToNextLevel then
              level = level + 1
              xp = xp - xpToNextLevel
              do
                local fillbar = _menu_root.levelProgressFillbar
                local startValLeft = 0
                local startValRight = basePerc
                local endValLeft = 0
                local endValRight = 1
                local length = 0.75
                _fillbar_seek_fill(AS, fillbar, startValLeft, startValRight, endValLeft, endValRight, length)
                if startValLeft ~= endValLeft or startValRight ~= endValRight then
                  action = MOAIEaseDriver.new()
                  action:setLength(length + 0.25)
                  AS:wrap(action:start())
                  while action:isActive() do
                    if _defeat_root.forward and not AS:isPaused() then
                      AS:throttle(10)
                      _defeat_root.forward = nil
                    end
                    coroutine.yield()
                  end
                end
                basePerc = 0
                _menu_root.levelText:setString(string.format(_("LVL %02d"), level))
                AS:pause()
                if not popups.show("on_levelup_" .. level, true, function()
                  AS:resume()
                end) then
                  _popup_levelup_show(AS, xpLevelDef, true)
                  soundmanager.onSFX("onLevelUp")
                end
                while AS:isPaused() do
                  coroutine.yield()
                end
                local text = _menu_root.alloyText
                local start = menu_root_alloyText or 0
                local goal = menu_root_alloyText + xpLevelDef.bonusAlloy or 0
                local length = 0.75
                local prefix = ""
                local suffix = ""
                _textbox_countup_number(AS, text, start, goal, length, prefix, suffix, "onAlloyCount")
                if start ~= goal then
                  action = MOAIEaseDriver.new()
                  action:setLength(length + 0.25)
                  AS:wrap(action:start())
                  while action:isActive() do
                    if _defeat_root.forward and not AS:isPaused() then
                      AS:throttle(10)
                      _defeat_root.forward = nil
                    end
                    coroutine.yield()
                  end
                end
                AS:throttle(1)
                menu_root_alloyText = menu_root_alloyText + xpLevelDef.bonusAlloy
              end
            else
              local perc = xp / xpToNextLevel
              local fillbar = _menu_root.levelProgressFillbar
              local startValLeft = 0
              local startValRight = basePerc
              local endValLeft = 0
              local endValRight = perc
              local length = 0.75
              _fillbar_seek_fill(AS, fillbar, startValLeft, startValRight, endValLeft, endValRight, length)
              if startValLeft ~= endValLeft or startValRight ~= endValRight then
                action = MOAIEaseDriver.new()
                action:setLength(length + 0.25)
                AS:wrap(action:start())
                while action:isActive() do
                  if _defeat_root.forward and not AS:isPaused() then
                    AS:throttle(10)
                    _defeat_root.forward = nil
                  end
                  coroutine.yield()
                end
              end
            end
          end
        end
        AS:throttle(1)
        AS:stop()
        AS = nil
        pickbox:remove()
        _menu_root.bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
      end)
    end
  else
    if curGameMode == "galaxy" then
      do
        local resultsKillBox = item:add(ui.Image.new("menuTemplate.atlas.png#resultsKillBox.png"))
        resultsKillBox:setLoc(40, submenu_y + 125)
        local wavesCompletedText = resultsKillBox:add(ui.TextBox.new(_("Waves Completed"), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
        wavesCompletedText:setLoc(110, 75)
        local numWavesText = resultsKillBox:add(ui.TextBox.new("" .. min(endGameStats.levelWave - 1, endGameStats.levelSpawns - 1) .. "/" .. endGameStats.levelSpawns, FONT_XLARGE, "ffffff", "center", nil, nil, true))
        numWavesText:setLoc(110, 20)
        local enemyKillValueText = resultsKillBox:add(ui.TextBox.new(_("Enemy Kill Value"), FONT_SMALL, "ffffff", "left", 260, nil, true))
        enemyKillValueText:setLoc(100, -40)
        local enemyKillValueNumText = resultsKillBox:add(ui.TextBox.new(util.commasInNumbers(endGameStats.baseScore), FONT_SMALL_BOLD, "ffffff", "right", 260, nil, true))
        enemyKillValueNumText:setLoc(100, -40)
        local unusedWarpCrystalText = resultsKillBox:add(ui.TextBox.new(_("Unused"), FONT_SMALL, "ffffff", "left", 260, nil, true))
        unusedWarpCrystalText:setLoc(100, -70)
        local unusedWarpCrystalsIcon = resultsKillBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystalMed.png"))
        unusedWarpCrystalsIcon:setLoc(60, -68)
        local unusedWarpCrystalNumText = resultsKillBox:add(ui.TextBox.new(util.commasInNumbers(endGameStats.plusScoreCrystals), FONT_SMALL_BOLD, "ffffff", "right", 260, nil, true))
        unusedWarpCrystalNumText:setLoc(100, -70)
        local finalScoreText = resultsKillBox:add(ui.TextBox.new(_("Final Score"), FONT_SMALL_BOLD, "ffffff", "left", 260, nil, true))
        finalScoreText:clearAttrLink(MOAIColor.INHERIT_COLOR)
        finalScoreText:setColor(unpack(UI_COLOR_GOLD))
        finalScoreText:setLoc(100, -100)
        local finalScoreNumText = resultsKillBox:add(ui.TextBox.new("= " .. util.commasInNumbers(scores.score), FONT_SMALL_BOLD, "ffffff", "right", 260, nil, true))
        finalScoreNumText:clearAttrLink(MOAIColor.INHERIT_COLOR)
        finalScoreNumText:setColor(unpack(UI_COLOR_GOLD))
        finalScoreNumText:setLoc(100, -100)
        local defeatEmblem = item:add(ui.Image.new("menuTemplate2.atlas.png#defeatEmblem.png"))
        defeatEmblem:setLoc(-140, submenu_y + 125)
      end
    elseif curGameMode == "survival" then
      local resultsKillBox = item:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxSurvival.png"))
      resultsKillBox:setLoc(0, submenu_y + 145)
      local wavesCompletedText = resultsKillBox:add(ui.TextBox.new(_("Waves Completed"), FONT_SMALL_BOLD, "ffffff", "left", 320, nil, true))
      wavesCompletedText:setLoc(100, 65)
      local wavesCompletedNumText = resultsKillBox:add(ui.TextBox.new(util.commasInNumbers(endGameStats.levelWave) .. " * " .. SURVIVAL_MODE_SCORE_WAVE_MULTIPLIER, FONT_SMALL_BOLD, "ffffff", "right", 320, nil, true))
      wavesCompletedNumText:setLoc(100, 65)
      local enemyKillValueText = resultsKillBox:add(ui.TextBox.new(_("Enemy Kill Value"), FONT_SMALL_BOLD, "ffffff", "left", 320, nil, true))
      enemyKillValueText:setLoc(100, 35)
      local enemyKillValueNumText = resultsKillBox:add(ui.TextBox.new("+ " .. util.commasInNumbers(endGameStats.baseScore), FONT_SMALL_BOLD, "ffffff", "right", 320, nil, true))
      enemyKillValueNumText:setLoc(100, 35)
      local spentWarpCrystalText = resultsKillBox:add(ui.TextBox.new(_("Spent"), FONT_SMALL, "ffffff", "left", 320, nil, true))
      spentWarpCrystalText:setLoc(100, 5)
      local spentWarpCrystalsIcon = resultsKillBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystalMed.png"))
      spentWarpCrystalsIcon:setLoc(15, 7)
      local spentWarpCrystalNumText = resultsKillBox:add(ui.TextBox.new("- " .. util.commasInNumbers(endGameStats.spentScoreCrystals), FONT_SMALL_BOLD, "ffffff", "right", 320, nil, true))
      spentWarpCrystalNumText:setLoc(100, 5)
      local finalScoreText = resultsKillBox:add(ui.TextBox.new(_("Final Score"), FONT_XLARGE, "ffffff", "left", 520, nil, true))
      finalScoreText:setColor(unpack(UI_COLOR_GOLD))
      finalScoreText:setLoc(0, -70)
      local finalScoreNumText = resultsKillBox:add(ui.TextBox.new(util.commasInNumbers(scores.score), FONT_XLARGE, "ffffff", "right", 520, nil, true))
      finalScoreNumText:setColor(unpack(UI_COLOR_GOLD))
      finalScoreNumText:setLoc(0, -70)
      if profile.survivalHighScore > endGameStats.baseHighScore then
        do
          local highScoreText = resultsKillBox:add(ui.TextBox.new(_("New High Score!"), FONT_MEDIUM_BOLD, "ffffff", "center", 520, nil, true))
          highScoreText:setColor(unpack(UI_COLOR_GOLD))
          highScoreText:setLoc(0, -130)
        end
      else
        local highScoreText = resultsKillBox:add(ui.TextBox.new(string.format(_("Your All-Time High Score: %s"), util.commasInNumbers(profile.survivalHighScore)), FONT_SMALL_BOLD, "ffffff", "center", 520, nil, true))
        highScoreText:setLoc(0, -130)
      end
    end
    local alloyResultsBoxBG = item:add(ui.PickBox.new(2, 2))
    alloyResultsBoxBG:setLoc(0, submenu_y - 92)
    alloyResultsBoxBG.handleTouch = nil
    local alloyResultsBoxBGLeft = alloyResultsBoxBG:add(ui.PickBox.new(370, 92, color.toHex(0, 0, 0, 0.34)))
    alloyResultsBoxBGLeft:setLoc(-113, 1)
    alloyResultsBoxBGLeft.handleTouch = nil
    local alloyResultsBoxBGLeftBorder = alloyResultsBoxBG:add(ui.PickBox.new(370, 2, color.toHex(0, 0, 0, 0.5)))
    alloyResultsBoxBGLeftBorder:setLoc(-113, -45)
    alloyResultsBoxBGLeftBorder.handleTouch = nil
    local alloyResultsBoxBGRight = alloyResultsBoxBG:add(ui.PickBox.new(226, 92, color.toHex(0, 0, 0, 0.45)))
    alloyResultsBoxBGRight:setLoc(185, 1)
    alloyResultsBoxBGRight.handleTouch = nil
    local alloyResultsBoxBGRightBorder = alloyResultsBoxBG:add(ui.PickBox.new(226, 2, color.toHex(0, 0, 0, 0.7)))
    alloyResultsBoxBGRightBorder:setLoc(185, -45)
    alloyResultsBoxBGRightBorder.handleTouch = nil
    local alloyResultsBoxBracketL = alloyResultsBoxBG:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketL.png"))
    alloyResultsBoxBracketL:setLoc(-295, 2)
    local alloyResultsBoxBracketR = alloyResultsBoxBG:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketR.png"))
    alloyResultsBoxBracketR:setLoc(295, 2)
    local PlusAlloyPerkUsed = false
    if curGameMode == "galaxy" and gameSessionAnalytics.perks ~= nil then
      for k, v in pairs(gameSessionAnalytics.perks) do
        if v == "plusAlloy" then
          PlusAlloyPerkUsed = true
          break
        end
      end
    end
    local AlloyCollectedText = alloyResultsBoxBG:add(ui.TextBox.new(_("Alloy Collected"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
    AlloyCollectedText:setLoc(-125, 32)
    local coltol = gameSessionAnalytics.currency.alloy.earned or 0
    if PlusAlloyPerkUsed ~= false then
      coltol = coltol / 2
    end
    local CollectedText = alloyResultsBoxBG:add(ui.TextBox.new("+ " .. util.commasInNumbers(coltol), FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
    CollectedText:setLoc(-25, 32)
    if PlusAlloyPerkUsed == false then
      CollectedText:setLoc(-25, 18)
      AlloyCollectedText:setLoc(-125, 18)
    end
    if curGameMode == "galaxy" then
      do
        local bonusText = alloyResultsBoxBG:add(ui.TextBox.new(_("Star Rating Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
        bonusText:setLoc(-125, -1)
        local plusBonusText = alloyResultsBoxBG:add(ui.TextBox.new("+ " .. util.commasInNumbers(0), FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
        plusBonusText:setLoc(-25, -1)
        if PlusAlloyPerkUsed == false then
          plusBonusText:setLoc(-25, -20)
          bonusText:setLoc(-125, -20)
        end
      end
    elseif curGameMode == "survival" then
      local survivorBonusText = alloyResultsBoxBG:add(ui.TextBox.new(_("Survivor Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
      survivorBonusText:setLoc(-125, -1)
      local plusSurvivorBonusText = alloyResultsBoxBG:add(ui.TextBox.new("+ " .. util.commasInNumbers(endGameStats.survivalBonusAlloy), FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
      plusSurvivorBonusText:setLoc(-25, -1)
      if PlusAlloyPerkUsed == false then
        plusSurvivorBonusText:setLoc(-25, -20)
        survivorBonusText:setLoc(-125, -20)
      end
    end
    if PlusAlloyPerkUsed ~= false then
      local pertol = gameSessionAnalytics.currency.alloy.earned or 0
      pertol = pertol / 2
      local AlloyCollectedText = alloyResultsBoxBG:add(ui.TextBox.new(_("Perk Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
      AlloyCollectedText:setLoc(-125, -34)
      local CollectedText = alloyResultsBoxBG:add(ui.TextBox.new("+ " .. pertol, FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
      CollectedText:setLoc(-25, -34)
    end
    local finalcoltol = gameSessionAnalytics.currency.alloy.earned or 0
    local plusAlloyText = alloyResultsBoxBG:add(ui.TextBox.new(util.commasInNumbers(endGameStats.plusAlloy + finalcoltol), FONT_XLARGE, "ffffff", "center", nil, nil, true))
    plusAlloyText:setColor(0.898, 0.714, 0.215)
    plusAlloyText:setLoc(220, -2)
    local iconAlloy = alloyResultsBoxBG:add(ui.Image.new("menuTemplateShared.atlas.png#iconAlloyLarge.png"))
    iconAlloy:setColor(0.898, 0.714, 0.215)
    iconAlloy:setLoc(220 - plusAlloyText._width / 2 - 40, 0)
    local xpResultsBoxBG = item:add(ui.PickBox.new(2, 2))
    xpResultsBoxBG:setLoc(0, submenu_y - 207)
    xpResultsBoxBG.handleTouch = nil
    local xpResultsBoxBGLeft = xpResultsBoxBG:add(ui.PickBox.new(370, 92, color.toHex(0, 0, 0, 0.34)))
    xpResultsBoxBGLeft:setLoc(-113, 1)
    xpResultsBoxBGLeft.handleTouch = nil
    local xpResultsBoxBGLeftBorder = xpResultsBoxBG:add(ui.PickBox.new(370, 2, color.toHex(0, 0, 0, 0.5)))
    xpResultsBoxBGLeftBorder:setLoc(-113, -45)
    xpResultsBoxBGLeftBorder.handleTouch = nil
    local xpResultsBoxBGRight = xpResultsBoxBG:add(ui.PickBox.new(226, 92, color.toHex(0, 0, 0, 0.45)))
    xpResultsBoxBGRight:setLoc(185, 1)
    xpResultsBoxBGRight.handleTouch = nil
    local xpResultsBoxBGRightBorder = xpResultsBoxBG:add(ui.PickBox.new(226, 2, color.toHex(0, 0, 0, 0.7)))
    xpResultsBoxBGRightBorder:setLoc(185, -45)
    xpResultsBoxBGRightBorder.handleTouch = nil
    local xpResultsBoxBracketL = xpResultsBoxBG:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketL.png"))
    xpResultsBoxBracketL:setLoc(-295, 2)
    local xpResultsBoxBracketR = xpResultsBoxBG:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketR.png"))
    xpResultsBoxBracketR:setLoc(295, 2)
    local xpEarnedText = xpResultsBoxBG:add(ui.TextBox.new(_("XP Earned"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
    xpEarnedText:setLoc(-125, 0)
    local plusXPEarnedText = xpResultsBoxBG:add(ui.TextBox.new("+ " .. util.commasInNumbers(endGameStats.basePlusXP), FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
    plusXPEarnedText:setLoc(-25, 0)
    if endGameStats.perkBonusXP ~= nil then
      local perkBonusText = xpResultsBoxBG:add(ui.TextBox.new(_("Perk Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
      perkBonusText:setLoc(-125, -18)
      local plusPerkBonusText = xpResultsBoxBG:add(ui.TextBox.new("+ " .. util.commasInNumbers(endGameStats.perkBonusXP), FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
      plusPerkBonusText:setLoc(-25, -18)
      xpEarnedText:setLoc(-125, 20)
      plusXPEarnedText:setLoc(-25, 20)
    end
    local plusXPText = xpResultsBoxBG:add(ui.TextBox.new(util.commasInNumbers(scores.xp), FONT_XLARGE, "ffffff", "center", nil, nil, true))
    plusXPText:setColor(0.898, 0.714, 0.215)
    plusXPText:setLoc(220, -2)
    local iconXP = xpResultsBoxBG:add(ui.Image.new("menuTemplateShared.atlas.png#iconPlayerLevelLarge.png"))
    iconXP:setColor(0.898, 0.714, 0.215)
    iconXP:setLoc(220 - plusXPText._width / 2 - 40, 0)
  end
  return item
end
function defeat_close(move)
  if move == nil then
    move = {empty = true}
  end
  if _defeat_root.continueBtnGlowAction ~= nil then
    _defeat_root.continueBtnGlowAction:stop()
    _defeat_root.continueBtnGlowAction = nil
  end
  _menu_root:remove(_menu_root.topBarBG)
  _menu_root.topBarBG = nil
  _storemenu_close({
    store_menu = move.store_menu
  })
  if move.bottom_bar then
    do
      local action = _menu_root.bottomNavBG:seekLoc(0, -device.ui_height / 2 - 120, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        _menu_root:remove(_menu_root.bottomNavBG)
        _menu_root.bottomNavBG = nil
      end)
    end
  else
    _menu_root:remove(_menu_root.bottomNavBG)
    _menu_root.bottomNavBG = nil
  end
  if _defeat_root.animateThread ~= nil then
    _defeat_root.animateThread:stop()
    _defeat_root.animateThread = nil
  end
  if move.forward then
    do
      local action = _defeat_root:seekLoc(-device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_defeat_root)
        _defeat_root = nil
      end)
    end
  elseif move.back then
    do
      local action = _defeat_root:seekLoc(device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_defeat_root)
        _defeat_root = nil
      end)
    end
  else
    submenuLayer:remove(_defeat_root)
    _defeat_root = nil
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  if scrollbar and scrollAction ~= nil then
    scrollAction:stop()
    scrollAction = nil
  end
  scrollbar = nil
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  curScreen = nil
end
function defeat_show(move)
  if move == nil then
    move = {empty = true}
  end
  _storemenu_show("defeat", true, nil, {
    store_menu = move.store_menu or move.animate
  })
  local topBarBG = _menu_root:add(ui.Image.new("menuTopBars.atlas.png#topBarDefeat.png"))
  if not profile.excludeAds then
    topBarBG:setLoc(0, device.ui_height / 2 - 150)
  else
    topBarBG:setLoc(0, device.ui_height / 2 - 50)
  end
  _menu_root.topBarBG = topBarBG
  local topBarBGPickBox = topBarBG:add(ui.PickBox.new(device.ui_width, 100))
  if curGameMode == "galaxy" then
    do
      local topBarText = topBarBG:add(ui.TextBox.new(_("Defeat!"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
      topBarText:setLoc(0, -6)
    end
  elseif curGameMode == "survival" then
    local topBarText = topBarBG:add(ui.TextBox.new(_("Game Over"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
    topBarText:setLoc(0, -6)
  end
  if device.os == device.OS_ANDROID then
    local function callback()
      _defeat_root.forward = true
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local menuBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconHome.png"))
  menuBtn._down:setColor(0.5, 0.5, 0.5)
  menuBtn:setLoc(device.ui_width / 2 - 42, 0)
  menuBtn.handleTouch = Button_handleTouch
  function menuBtn:onClick()
    menu_close()
    mainmenu_show()
    soundmanager.onSFX("onPageSwipeBack")
  end
  _defeat_root = ui.Group.new()
  _defeat_root:add(_defeat_create_item(move.animate, scores.alloy, scores.xp))
  if move.forward then
    _defeat_root:setLoc(device.ui_width * 2, 0)
    _defeat_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  elseif move.back then
    _defeat_root:setLoc(-device.ui_width * 2, 0)
    _defeat_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  end
  local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
  if move.bottom_bar then
    bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
    bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
  elseif move.animate then
    bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
  else
    bottomNavBG:setLoc(0, -device.ui_height / 2 - 8)
  end
  _menu_root.bottomNavBG = bottomNavBG
  local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
  bottomNavBGPickBox:setLoc(0, -20)
  local continueBtnGlow = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#largeButtonGlow.png"))
  continueBtnGlow:setColor(0.25, 0.25, 0.25, 0)
  continueBtnGlow:setScl(0.995, 0.995)
  continueBtnGlow:setLoc(0, 45)
  _defeat_root.continueBtnGlowAction = uiAS:repeatcall(0.5, function()
    if continueBtnGlow.active then
      continueBtnGlow:seekColor(0.25, 0.25, 0.25, 0, 0.5, MOAIEaseType.EASE_IN)
      continueBtnGlow.active = nil
      continueBtnGlow.wait = true
    elseif continueBtnGlow.wait then
      continueBtnGlow.wait = nil
    else
      continueBtnGlow:seekColor(1, 1, 1, 0, 0.5, MOAIEaseType.EASE_IN)
      continueBtnGlow.active = true
    end
  end)
  local continueBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#largeButton.png"))
  continueBtn._down:setColor(0.5, 0.5, 0.5)
  continueBtn:setLoc(0, 50)
  local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  continueBtnText:setLoc(-15, 0)
  local continueBtnIcon = continueBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
  continueBtnIcon:setLoc(70, 0)
  local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  continueBtnText:setLoc(-15, 0)
  local continueBtnIcon = continueBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
  continueBtnIcon:setLoc(70, 0)
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn:onClick()
    if not screenAction:isActive() then
      local lastCompletedGalaxy, lastCompletedSystem = _get_last_completed_galaxy_system()
      if lastCompletedGalaxy == 1 and lastCompletedSystem == 0 then
        menu_close()
        level_run(1, 1)
      else
        table_insert(screenHistory, "defeat")
        defeat_close({forward = true})
        if curGameMode == "galaxy" then
          achievements_show({forward = true})
        elseif curGameMode == "survival" then
          leaderboard_show({forward = true})
        end
      end
      soundmanager.onSFX("onPageSwipeForward")
    end
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  submenuLayer:add(_defeat_root)
  curScreen = "defeat"
end
local function _victory_create_item(animate)
  local submenu_height = device.ui_height - 100 - 90 - 60 - 60
  local submenu_y = -65
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local item = ui.Group.new()
  local systemBox = item:add(ui.NinePatch.new("boxPlain9p.lua", device.ui_width + 20, 60))
  systemBox:setLoc(0, (submenu_height + 60) / 2 + submenu_y + 6)
  if curGameMode == "galaxy" then
    levelGalaxyIndex = levelGalaxyIndex or 1
    levelSystemIndex = levelSystemIndex or 1
    do
      local idx = (levelGalaxyIndex - 1) * 40 + levelSystemIndex
      local levelDef = GALAXY_DATA[idx]
      local systemText = systemBox:add(ui.TextBox.new("" .. levelGalaxyIndex .. "." .. levelSystemIndex .. ": " .. _(levelDef["System Name"]), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      systemText:setLoc(0, -2)
    end
  elseif curGameMode == "survival" then
    local systemText = systemBox:add(ui.TextBox.new(_("Survival Mode"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
    systemText:setLoc(0, -2)
  end
  if animate then
    do
      local pickbox = item:add(ui.PickBox.new(device.ui_width, submenu_height + 90))
      pickbox:setLoc(0, submenu_y - 45)
      function pickbox.onClick()
        _debug("Menu Victory Pickbox On Touch")
        _victory_root.forward = true
      end
      _menu_root.alloyText:setString("" .. util.commasInNumbers(endGameStats.baseAlloy + (endGameStats.plusAlloy or 0)))
      _menu_root.levelText:setString(string.format(_("LVL %02d"), endGameStats.baseLevel))
      local xpDef = require("ShipData-ExpDef")
      local xpLevelDef = xpDef[endGameStats.baseLevel]
      local baseXPToNextLevel, basePerc
      if xpLevelDef ~= nil then
        baseXPToNextLevel = xpLevelDef.xpToAdvance
      end
      if baseXPToNextLevel ~= nil and baseXPToNextLevel ~= 0 then
        basePerc = endGameStats.baseXP / baseXPToNextLevel
      else
        basePerc = 1
      end
      _menu_root.levelProgressFillbar:setFill(0, basePerc)
      local resultsKillBox = item:add(ui.Image.new("menuTemplate.atlas.png#resultsKillBox.png"))
      resultsKillBox:setColor(0.898, 0.714, 0.215)
      resultsKillBox:setScl(0, 1)
      resultsKillBox:setLoc(0, submenu_y + 125)
      local victoryStarSlot1 = resultsKillBox:add(ui.Image.new("menuTemplate.atlas.png#victoryStarSlot.png"))
      victoryStarSlot1:setColor(0.5, 0.5, 0.5)
      victoryStarSlot1:setLoc(25, 60)
      local victoryStarSlot2 = resultsKillBox:add(ui.Image.new("menuTemplate.atlas.png#victoryStarSlot.png"))
      victoryStarSlot2:setColor(0.5, 0.5, 0.5)
      victoryStarSlot2:setLoc(110, 60)
      local victoryStarSlot3 = resultsKillBox:add(ui.Image.new("menuTemplate.atlas.png#victoryStarSlot.png"))
      victoryStarSlot3:setColor(0.5, 0.5, 0.5)
      victoryStarSlot3:setLoc(195, 60)
      local victoryEmblem = item:add(ui.Image.new("menuTemplate2.atlas.png#victoryEmblem.png"))
      victoryEmblem:setLoc(0, submenu_y + 125)
      _victory_root.animateThread = MOAIThread.new()
      _victory_root.animateThread:run(function()
        local AS = actionset.new()
        local action
        action = MOAIEaseDriver.new()
        action:setLength(0.5)
        AS:wrap(action:start())
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        action = AS:wrap(victoryEmblem:seekLoc(-140, submenu_y + 125, 1, MOAIEaseType.EASE_IN))
        AS:wrap(resultsKillBox:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN))
        AS:wrap(resultsKillBox:seekLoc(40, submenu_y + 125, 1, MOAIEaseType.EASE_IN))
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        local stars = endGameStats.stars
        local idx = (levelGalaxyIndex - 1) * 40 + levelSystemIndex
        local levelDef = GALAXY_DATA[idx]
        if stars == 1 then
          do
            local victoryStar1 = victoryStarSlot1:add(ui.Image.new("menuTemplate.atlas.png#victoryStar.png"))
            victoryStar1:clearAttrLink(MOAIColor.INHERIT_COLOR)
            victoryStar1:setColor(1, 1, 1, 0.25)
            action = AS:wrap(victoryStar1:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            victoryStar1:setScl(2, 2)
            AS:wrap(victoryStar1:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN))
            soundmanager.onSFX("onStar")
            while action:isActive() do
              if _victory_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _victory_root.forward = nil
              end
              coroutine.yield()
            end
            local victoryStar2 = victoryStarSlot2:add(ui.TextBox.new(util.commasInNumbers(levelDef["2 Star Score"]), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
            victoryStar2:clearAttrLink(MOAIColor.INHERIT_COLOR)
            victoryStar2:setColor(0, 0, 0, 0)
            victoryStar2:setLoc(0, -10)
            action = AS:wrap(victoryStar2:seekColor(UI_COLOR_GRAY[1], UI_COLOR_GRAY[2], UI_COLOR_GRAY[3], 1, 0.5, MOAIEaseType.EASE_IN))
            while action:isActive() do
              if _victory_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _victory_root.forward = nil
              end
              coroutine.yield()
            end
            local victoryStar3 = victoryStarSlot3:add(ui.TextBox.new(util.commasInNumbers(levelDef["3 Star Score"]), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
            victoryStar3:clearAttrLink(MOAIColor.INHERIT_COLOR)
            victoryStar3:setColor(0, 0, 0, 0)
            victoryStar3:setLoc(0, -10)
            action = AS:wrap(victoryStar3:seekColor(UI_COLOR_GRAY[1], UI_COLOR_GRAY[2], UI_COLOR_GRAY[3], 1, 0.5, MOAIEaseType.EASE_IN))
            while action:isActive() do
              if _victory_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _victory_root.forward = nil
              end
              coroutine.yield()
            end
            local victoryText = resultsKillBox:add(ui.TextBox.new(_("Marginal Victory"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
            victoryText:setColor(0, 0, 0, 0)
            action = AS:wrap(victoryText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            victoryText:setLoc(110, 0)
            while action:isActive() do
              if _victory_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _victory_root.forward = nil
              end
              coroutine.yield()
            end
          end
        elseif stars == 2 then
          do
            local victoryStar1 = victoryStarSlot1:add(ui.Image.new("menuTemplate.atlas.png#victoryStar.png"))
            victoryStar1:clearAttrLink(MOAIColor.INHERIT_COLOR)
            victoryStar1:setColor(1, 1, 1, 0.25)
            action = AS:wrap(victoryStar1:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            victoryStar1:setScl(2, 2)
            AS:wrap(victoryStar1:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN))
            soundmanager.onSFX("onStar")
            while action:isActive() do
              if _victory_root.forward then
                AS:throttle(10)
                _victory_root.forward = nil
              end
              coroutine.yield()
            end
            local victoryStar2 = victoryStarSlot2:add(ui.Image.new("menuTemplate.atlas.png#victoryStar.png"))
            victoryStar2:clearAttrLink(MOAIColor.INHERIT_COLOR)
            victoryStar2:setColor(1, 1, 1, 0.25)
            action = AS:wrap(victoryStar2:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            victoryStar2:setScl(2, 2)
            AS:wrap(victoryStar2:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN))
            soundmanager.onSFX("onStar")
            while action:isActive() do
              if _victory_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _victory_root.forward = nil
              end
              coroutine.yield()
            end
            local victoryStar3 = victoryStarSlot3:add(ui.TextBox.new(util.commasInNumbers(levelDef["3 Star Score"]), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
            victoryStar3:clearAttrLink(MOAIColor.INHERIT_COLOR)
            victoryStar3:setColor(0, 0, 0, 0)
            victoryStar3:setLoc(0, -10)
            action = AS:wrap(victoryStar3:seekColor(UI_COLOR_GRAY[1], UI_COLOR_GRAY[2], UI_COLOR_GRAY[3], 1, 0.5, MOAIEaseType.EASE_IN))
            while action:isActive() do
              if _victory_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _victory_root.forward = nil
              end
              coroutine.yield()
            end
            local victoryText = resultsKillBox:add(ui.TextBox.new(_("Tactical Victory"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
            victoryText:setColor(0, 0, 0, 0)
            action = AS:wrap(victoryText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
            victoryText:setLoc(110, 0)
            while action:isActive() do
              if _victory_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _victory_root.forward = nil
              end
              coroutine.yield()
            end
          end
        elseif stars == 3 then
          local victoryStar1 = victoryStarSlot1:add(ui.Image.new("menuTemplate.atlas.png#victoryStar.png"))
          victoryStar1:clearAttrLink(MOAIColor.INHERIT_COLOR)
          victoryStar1:setColor(1, 1, 1, 0.25)
          action = AS:wrap(victoryStar1:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          victoryStar1:setScl(2, 2)
          AS:wrap(victoryStar1:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN))
          soundmanager.onSFX("onStar")
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
          local victoryStar2 = victoryStarSlot2:add(ui.Image.new("menuTemplate.atlas.png#victoryStar.png"))
          victoryStar2:clearAttrLink(MOAIColor.INHERIT_COLOR)
          victoryStar2:setColor(1, 1, 1, 0.25)
          action = AS:wrap(victoryStar2:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          victoryStar2:setScl(2, 2)
          AS:wrap(victoryStar2:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN))
          soundmanager.onSFX("onStar")
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
          local victoryStar3 = victoryStarSlot3:add(ui.Image.new("menuTemplate.atlas.png#victoryStar.png"))
          victoryStar3:clearAttrLink(MOAIColor.INHERIT_COLOR)
          victoryStar3:setColor(1, 1, 1, 0.25)
          action = AS:wrap(victoryStar3:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          victoryStar3:setScl(2, 2)
          AS:wrap(victoryStar3:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN))
          soundmanager.onSFX("onStar")
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
          local victoryText = resultsKillBox:add(ui.TextBox.new(_("Decisive Victory!"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
          victoryText:setColor(0, 0, 0, 0)
          action = AS:wrap(victoryText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          victoryText:setLoc(110, 0)
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
        end
        local enemyKillValueText = resultsKillBox:add(ui.TextBox.new(_("Enemy Kill Value"), FONT_SMALL_BOLD, "ffffff", "left", 260, nil, true))
        enemyKillValueText:clearAttrLink(MOAIColor.INHERIT_COLOR)
        enemyKillValueText:setColor(0, 0, 0, 0)
        action = AS:wrap(enemyKillValueText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        enemyKillValueText:setLoc(100, -40)
        local enemyKillValueNumText = resultsKillBox:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "right", 260, nil, true))
        enemyKillValueNumText:clearAttrLink(MOAIColor.INHERIT_COLOR)
        enemyKillValueNumText:setColor(0, 0, 0, 0)
        AS:wrap(enemyKillValueNumText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        enemyKillValueNumText:setLoc(100, -40)
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        local text = enemyKillValueNumText
        local start = 0
        local goal = endGameStats.baseScore
        local length = 0.75
        local prefix = ""
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
        end
        local unusedWarpCrystalsText = resultsKillBox:add(ui.TextBox.new(_("Unused"), FONT_SMALL_BOLD, "ffffff", "left", 260, nil, true))
        unusedWarpCrystalsText:clearAttrLink(MOAIColor.INHERIT_COLOR)
        unusedWarpCrystalsText:setColor(0, 0, 0, 0)
        action = AS:wrap(unusedWarpCrystalsText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        unusedWarpCrystalsText:setLoc(100, -70)
        local unusedWarpCrystalsIcon = resultsKillBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystalMed.png"))
        unusedWarpCrystalsIcon:clearAttrLink(MOAIColor.INHERIT_COLOR)
        unusedWarpCrystalsIcon:setColor(0, 0, 0, 0)
        AS:wrap(unusedWarpCrystalsIcon:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        unusedWarpCrystalsIcon:setLoc(60, -68)
        local unusedWarpCrystalsNumText = resultsKillBox:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 260, nil, true))
        unusedWarpCrystalsNumText:clearAttrLink(MOAIColor.INHERIT_COLOR)
        unusedWarpCrystalsNumText:setColor(0, 0, 0, 0)
        AS:wrap(unusedWarpCrystalsNumText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        unusedWarpCrystalsNumText:setLoc(100, -70)
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        local text = unusedWarpCrystalsNumText
        local start = 0
        local goal = endGameStats.plusScoreCrystals
        local length = 0.75
        local prefix = "+ "
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
        end
        local finalScoreText = resultsKillBox:add(ui.TextBox.new(_("Final Score"), FONT_SMALL_BOLD, "ffffff", "left", 260, nil, true))
        finalScoreText:clearAttrLink(MOAIColor.INHERIT_COLOR)
        finalScoreText:setColor(0, 0, 0, 0)
        action = AS:wrap(finalScoreText:seekColor(UI_COLOR_GOLD[1], UI_COLOR_GOLD[2], UI_COLOR_GOLD[3], 1, 0.5, MOAIEaseType.EASE_IN))
        finalScoreText:setLoc(100, -100)
        local finalScoreNumText = resultsKillBox:add(ui.TextBox.new("= 0", FONT_SMALL_BOLD, "ffffff", "right", 260, nil, true))
        finalScoreNumText:clearAttrLink(MOAIColor.INHERIT_COLOR)
        finalScoreNumText:setColor(0, 0, 0, 0)
        AS:wrap(finalScoreNumText:seekColor(UI_COLOR_GOLD[1], UI_COLOR_GOLD[2], UI_COLOR_GOLD[3], 1, 0.5, MOAIEaseType.EASE_IN))
        finalScoreNumText:setLoc(100, -100)
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        local text = finalScoreNumText
        local start = 0
        local goal = scores.score
        local length = 0.75
        local prefix = "= "
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
        end
        AS:throttle(1)
        local alloyResultsBoxBG = item:add(ui.PickBox.new(2, 2))
        alloyResultsBoxBG:setColor(0, 0, 0, 0)
        action = AS:wrap(alloyResultsBoxBG:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        alloyResultsBoxBG:setScl(0.025, 1)
        alloyResultsBoxBG:setLoc(0, submenu_y - 92)
        alloyResultsBoxBG.handleTouch = nil
        local alloyResultsBoxBGLeft = alloyResultsBoxBG:add(ui.PickBox.new(370, 92, color.toHex(0, 0, 0, 0.34)))
        alloyResultsBoxBGLeft:setLoc(-113, 1)
        alloyResultsBoxBGLeft.handleTouch = nil
        local alloyResultsBoxBGLeftBorder = alloyResultsBoxBG:add(ui.PickBox.new(370, 2, color.toHex(0, 0, 0, 0.5)))
        alloyResultsBoxBGLeftBorder:setLoc(-113, -45)
        alloyResultsBoxBGLeftBorder.handleTouch = nil
        local alloyResultsBoxBGRight = alloyResultsBoxBG:add(ui.PickBox.new(226, 92, color.toHex(0, 0, 0, 0.45)))
        alloyResultsBoxBGRight:setLoc(185, 1)
        alloyResultsBoxBGRight.handleTouch = nil
        local alloyResultsBoxBGRightBorder = alloyResultsBoxBG:add(ui.PickBox.new(226, 2, color.toHex(0, 0, 0, 0.7)))
        alloyResultsBoxBGRightBorder:setLoc(185, -45)
        alloyResultsBoxBGRightBorder.handleTouch = nil
        local alloyResultsBoxBracketL = item:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketL.png"))
        alloyResultsBoxBracketL:setColor(0, 0, 0, 0)
        AS:wrap(alloyResultsBoxBracketL:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        alloyResultsBoxBracketL:setLoc(-5, submenu_y - 90)
        local alloyResultsBoxBracketR = item:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketR.png"))
        alloyResultsBoxBracketR:setColor(0, 0, 0, 0)
        AS:wrap(alloyResultsBoxBracketR:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        alloyResultsBoxBracketR:setLoc(5, submenu_y - 90)
        AS:wrap(alloyResultsBoxBG:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN))
        AS:wrap(alloyResultsBoxBracketL:seekLoc(-295, submenu_y - 90, 0.5, MOAIEaseType.EASE_IN))
        AS:wrap(alloyResultsBoxBracketR:seekLoc(295, submenu_y - 90, 0.5, MOAIEaseType.EASE_IN))
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        local PlusAlloyPerkUsed = false
        if gameSessionAnalytics.perks ~= nil then
          for k, v in pairs(gameSessionAnalytics.perks) do
            if v == "plusAlloy" then
              PlusAlloyPerkUsed = true
              break
            end
          end
        end
        local AlloyCollectedText = alloyResultsBoxBG:add(ui.TextBox.new(_("Alloy Collected"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
        AlloyCollectedText:setColor(0, 0, 0, 0)
        action = AS:wrap(AlloyCollectedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        AlloyCollectedText:setLoc(-125, 32)
        local CollectedText = alloyResultsBoxBG:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
        CollectedText:setColor(0, 0, 0, 0)
        AS:wrap(CollectedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        CollectedText:setLoc(-25, 32)
        if PlusAlloyPerkUsed == false then
          CollectedText:setLoc(-25, 18)
          AlloyCollectedText:setLoc(-125, 18)
        end
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        local text = plusSurvivorBonusText
        local start = 0
        local goal = gameSessionAnalytics.currency.alloy.earned or 0
        local length = 0.75
        local prefix = "+ "
        local suffix = ""
        if PlusAlloyPerkUsed ~= false then
          goal = goal / 2
        end
        _textbox_countup_number(AS, CollectedText, start, goal, length, prefix, suffix, "onAlloyCount")
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
        end
        local victoryBonusText = alloyResultsBoxBG:add(ui.TextBox.new(_("Star Rating Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
        victoryBonusText:setColor(0, 0, 0, 0)
        action = AS:wrap(victoryBonusText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        victoryBonusText:setLoc(-125, -1)
        local plusVictoryBonusText = alloyResultsBoxBG:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
        plusVictoryBonusText:setColor(0, 0, 0, 0)
        AS:wrap(plusVictoryBonusText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        plusVictoryBonusText:setLoc(-25, -1)
        if PlusAlloyPerkUsed == false then
          plusVictoryBonusText:setLoc(-25, -20)
          victoryBonusText:setLoc(-125, -20)
        end
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        local text = plusVictoryBonusText
        local start = 0
        local goal = endGameStats.victoryBonusAlloy or 0
        local length = 0.75
        local prefix = "+ "
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix, "onAlloyCount")
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
        end
        if PlusAlloyPerkUsed ~= false then
          local AlloyCollectedText = alloyResultsBoxBG:add(ui.TextBox.new(_("Perk Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
          AlloyCollectedText:setColor(0, 0, 0, 0)
          action = AS:wrap(AlloyCollectedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          AlloyCollectedText:setLoc(-125, -34)
          local CollectedText = alloyResultsBoxBG:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
          CollectedText:setColor(0, 0, 0, 0)
          AS:wrap(CollectedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          CollectedText:setLoc(-25, -34)
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
          local text = plusSurvivorBonusText
          local start = 0
          local goal = gameSessionAnalytics.currency.alloy.earned or 0
          local length = 0.75
          local prefix = "+ "
          local suffix = ""
          goal = goal / 2
          _textbox_countup_number(AS, CollectedText, start, goal, length, prefix, suffix, "onAlloyCount")
          if start ~= goal then
            action = MOAIEaseDriver.new()
            action:setLength(length + 0.25)
            AS:wrap(action:start())
            while action:isActive() do
              if _victory_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _victory_root.forward = nil
              end
              coroutine.yield()
            end
          end
        end
        local plusAlloyText = alloyResultsBoxBG:add(ui.TextBox.new(util.commasInNumbers(endGameStats.plusAlloy), FONT_XLARGE, "ffffff", "center", nil, nil, true))
        plusAlloyText:setString("0")
        plusAlloyText:setColor(0.898, 0.714, 0.215, 0)
        action = AS:wrap(plusAlloyText:seekColor(0.898, 0.714, 0.215, 1, 0.5, MOAIEaseType.EASE_IN))
        plusAlloyText:setLoc(220, -2)
        local iconAlloy = alloyResultsBoxBG:add(ui.Image.new("menuTemplateShared.atlas.png#iconAlloyLarge.png"))
        iconAlloy:setColor(0.898, 0.714, 0.215, 0)
        AS:wrap(iconAlloy:seekColor(0.898, 0.714, 0.215, 1, 0.5, MOAIEaseType.EASE_IN))
        iconAlloy:setLoc(220 - plusAlloyText._width / 2 - 40, 0)
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        local text = plusAlloyText
        local start = 0
        local goal = (endGameStats.plusAlloy or 0) + (gameSessionAnalytics.currency.alloy.earned or 0)
        local length = 0.75
        local prefix = ""
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix, "onAlloyCount")
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
        end
        local text = _menu_root.alloyText
        local start = (endGameStats.baseAlloy or 0) + (endGameStats.plusAlloy or 0)
        local goal = (endGameStats.baseAlloy or 0) + (endGameStats.plusAlloy or 0)
        local length = 0.75
        local prefix = ""
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix, "onAlloyCount")
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
        end
        AS:throttle(1)
        local xpResultsBoxBG = item:add(ui.PickBox.new(2, 2))
        xpResultsBoxBG:setColor(0, 0, 0, 0)
        action = AS:wrap(xpResultsBoxBG:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        xpResultsBoxBG:setScl(0.025, 1)
        xpResultsBoxBG:setLoc(0, submenu_y - 207)
        xpResultsBoxBG.handleTouch = nil
        local xpResultsBoxBGLeft = xpResultsBoxBG:add(ui.PickBox.new(370, 92, color.toHex(0, 0, 0, 0.34)))
        xpResultsBoxBGLeft:setLoc(-113, 1)
        xpResultsBoxBGLeft.handleTouch = nil
        local xpResultsBoxBGLeftBorder = xpResultsBoxBG:add(ui.PickBox.new(370, 2, color.toHex(0, 0, 0, 0.5)))
        xpResultsBoxBGLeftBorder:setLoc(-113, -45)
        xpResultsBoxBGLeftBorder.handleTouch = nil
        local xpResultsBoxBGRight = xpResultsBoxBG:add(ui.PickBox.new(226, 92, color.toHex(0, 0, 0, 0.45)))
        xpResultsBoxBGRight:setLoc(185, 1)
        xpResultsBoxBGRight.handleTouch = nil
        local xpResultsBoxBGRightBorder = xpResultsBoxBG:add(ui.PickBox.new(226, 2, color.toHex(0, 0, 0, 0.7)))
        xpResultsBoxBGRightBorder:setLoc(185, -45)
        xpResultsBoxBGRightBorder.handleTouch = nil
        local xpResultsBoxBracketL = item:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketL.png"))
        xpResultsBoxBracketL:setColor(0, 0, 0, 0)
        AS:wrap(xpResultsBoxBracketL:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        xpResultsBoxBracketL:setLoc(-5, submenu_y - 205)
        local xpResultsBoxBracketR = item:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketR.png"))
        xpResultsBoxBracketR:setColor(0, 0, 0, 0)
        AS:wrap(xpResultsBoxBracketR:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        xpResultsBoxBracketR:setLoc(5, submenu_y - 205)
        AS:wrap(xpResultsBoxBG:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN))
        AS:wrap(xpResultsBoxBracketL:seekLoc(-295, submenu_y - 205, 0.5, MOAIEaseType.EASE_IN))
        AS:wrap(xpResultsBoxBracketR:seekLoc(295, submenu_y - 205, 0.5, MOAIEaseType.EASE_IN))
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        local xpEarnedText = xpResultsBoxBG:add(ui.TextBox.new(_("XP Earned"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
        xpEarnedText:setColor(0, 0, 0, 0)
        action = AS:wrap(xpEarnedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        xpEarnedText:setLoc(-125, 20)
        local plusXPEarnedText = xpResultsBoxBG:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
        plusXPEarnedText:setColor(0, 0, 0, 0)
        AS:wrap(plusXPEarnedText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        plusXPEarnedText:setLoc(-25, 20)
        if endGameStats.perkBonusXP ~= nil then
          xpEarnedText:setLoc(-125, 30)
          plusXPEarnedText:setLoc(-25, 30)
        end
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        local text = plusXPEarnedText
        local start = 0
        local goal = endGameStats.basePlusXP or 0
        local length = 0.75
        local prefix = "+ "
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
        end
        local victoryBonusText = xpResultsBoxBG:add(ui.TextBox.new(_("Star Rating Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
        victoryBonusText:setColor(0, 0, 0, 0)
        action = AS:wrap(victoryBonusText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        victoryBonusText:setLoc(-125, -18)
        local plusVictoryBonusText = xpResultsBoxBG:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
        plusVictoryBonusText:setColor(0, 0, 0, 0)
        AS:wrap(plusVictoryBonusText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
        plusVictoryBonusText:setLoc(-25, -18)
        if endGameStats.perkBonusXP ~= nil then
          victoryBonusText:setLoc(-125, -3)
          plusVictoryBonusText:setLoc(-25, -3)
        end
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        local text = plusVictoryBonusText
        local start = 0
        local goal = endGameStats.victoryBonusXP or 0
        local length = 0.75
        local prefix = "+ "
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
        end
        if endGameStats.perkBonusXP ~= nil then
          local perkBonusText = xpResultsBoxBG:add(ui.TextBox.new(_("Perk Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
          perkBonusText:setColor(0, 0, 0, 0)
          action = AS:wrap(perkBonusText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          perkBonusText:setLoc(-125, -35)
          local plusPerkBonusText = xpResultsBoxBG:add(ui.TextBox.new("+ 0", FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
          plusPerkBonusText:setColor(0, 0, 0, 0)
          AS:wrap(plusPerkBonusText:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN))
          plusPerkBonusText:setLoc(-25, -35)
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
          local text = plusPerkBonusText
          local start = 0
          local goal = endGameStats.perkBonusXP or 0
          local length = 0.75
          local prefix = "+ "
          local suffix = ""
          _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
          if start ~= goal then
            action = MOAIEaseDriver.new()
            action:setLength(length + 0.25)
            AS:wrap(action:start())
            while action:isActive() do
              if _victory_root.forward and not AS:isPaused() then
                AS:throttle(10)
                _victory_root.forward = nil
              end
              coroutine.yield()
            end
          end
        end
        local plusXPText = xpResultsBoxBG:add(ui.TextBox.new("" .. util.commasInNumbers(scores.xp), FONT_XLARGE, "ffffff", "center", nil, nil, true))
        plusXPText:setString("0")
        plusXPText:setColor(0.898, 0.714, 0.215, 0)
        action = AS:wrap(plusXPText:seekColor(0.898, 0.714, 0.215, 1, 0.5, MOAIEaseType.EASE_IN))
        plusXPText:setLoc(220, -2)
        local iconXP = xpResultsBoxBG:add(ui.Image.new("menuTemplateShared.atlas.png#iconPlayerLevelLarge.png"))
        iconXP:setColor(0.898, 0.714, 0.215, 0)
        AS:wrap(iconXP:seekColor(0.898, 0.714, 0.215, 1, 0.5, MOAIEaseType.EASE_IN))
        iconXP:setLoc(220 - plusXPText._width / 2 - 40, 0)
        while action:isActive() do
          if _victory_root.forward and not AS:isPaused() then
            AS:throttle(10)
            _victory_root.forward = nil
          end
          coroutine.yield()
        end
        local text = plusXPText
        local start = 0
        local goal = scores.xp or 0
        local length = 0.75
        local prefix = ""
        local suffix = ""
        _textbox_countup_number(AS, text, start, goal, length, prefix, suffix)
        if start ~= goal then
          action = MOAIEaseDriver.new()
          action:setLength(length + 0.25)
          AS:wrap(action:start())
          while action:isActive() do
            if _victory_root.forward and not AS:isPaused() then
              AS:throttle(10)
              _victory_root.forward = nil
            end
            coroutine.yield()
          end
        end
        local numLevelUps = profile.level - endGameStats.baseLevel + 1
        local level = endGameStats.baseLevel
        local xp = endGameStats.baseXP + scores.xp
        local menu_root_alloyText = (endGameStats.baseAlloy or 0) + (endGameStats.plusAlloy or 0)
        for i = 1, numLevelUps do
          local xpLevelDef = xpDef[level]
          local xpToNextLevel
          if xpLevelDef ~= nil then
            xpToNextLevel = xpLevelDef.xpToAdvance
          end
          if xpToNextLevel ~= nil and xpToNextLevel ~= 0 then
            if xp >= xpToNextLevel then
              level = level + 1
              xp = xp - xpToNextLevel
              do
                local fillbar = _menu_root.levelProgressFillbar
                local startValLeft = 0
                local startValRight = basePerc
                local endValLeft = 0
                local endValRight = 1
                local length = 0.75
                _fillbar_seek_fill(AS, fillbar, startValLeft, startValRight, endValLeft, endValRight, length)
                if startValLeft ~= endValLeft or startValRight ~= endValRight then
                  action = MOAIEaseDriver.new()
                  action:setLength(length + 0.25)
                  AS:wrap(action:start())
                  while action:isActive() do
                    if _victory_root.forward and not AS:isPaused() then
                      AS:throttle(10)
                      _victory_root.forward = nil
                    end
                    coroutine.yield()
                  end
                end
                basePerc = 0
                _menu_root.levelText:setString(string.format(_("LVL %02d"), level))
                AS:pause()
                if not popups.show("on_levelup_" .. level, true, function()
                  AS:resume()
                end) then
                  _popup_levelup_show(AS, xpLevelDef, true)
                  soundmanager.onSFX("onLevelUp")
                end
                while AS:isPaused() do
                  coroutine.yield()
                end
                local text = _menu_root.alloyText
                local start = menu_root_alloyText or 0
                local goal = menu_root_alloyText + xpLevelDef.bonusAlloy or 0
                local length = 0.75
                local prefix = ""
                local suffix = ""
                _textbox_countup_number(AS, text, start, goal, length, prefix, suffix, "onAlloyCount")
                if start ~= goal then
                  action = MOAIEaseDriver.new()
                  action:setLength(length + 0.25)
                  AS:wrap(action:start())
                  while action:isActive() do
                    if _victory_root.forward and not AS:isPaused() then
                      AS:throttle(10)
                      _victory_root.forward = nil
                    end
                    coroutine.yield()
                  end
                end
                AS:throttle(1)
                menu_root_alloyText = menu_root_alloyText + xpLevelDef.bonusAlloy
              end
            else
              local perc = xp / xpToNextLevel
              local fillbar = _menu_root.levelProgressFillbar
              local startValLeft = 0
              local startValRight = basePerc
              local endValLeft = 0
              local endValRight = perc
              local length = 0.75
              _fillbar_seek_fill(AS, fillbar, startValLeft, startValRight, endValLeft, endValRight, length)
              if startValLeft ~= endValLeft or startValRight ~= endValRight then
                action = MOAIEaseDriver.new()
                action:setLength(length + 0.25)
                AS:wrap(action:start())
                while action:isActive() do
                  if _victory_root.forward and not AS:isPaused() then
                    AS:throttle(10)
                    _victory_root.forward = nil
                  end
                  coroutine.yield()
                end
              end
            end
          end
        end
        AS:throttle(1)
        AS:stop()
        AS = nil
        if levelSystemIndex == 40 then
          popups.show("on_g" .. levelGalaxyIndex .. "_end", true)
        end
        pickbox:remove()
        _menu_root.bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
      end)
    end
  else
    local resultsKillBox = item:add(ui.Image.new("menuTemplate.atlas.png#resultsKillBox.png"))
    resultsKillBox:setColor(0.898, 0.714, 0.215)
    resultsKillBox:setLoc(40, submenu_y + 125)
    local victoryStarSlot1 = resultsKillBox:add(ui.Image.new("menuTemplate.atlas.png#victoryStarSlot.png"))
    victoryStarSlot1:setColor(0.5, 0.5, 0.5)
    victoryStarSlot1:setLoc(25, 60)
    local victoryStarSlot2 = resultsKillBox:add(ui.Image.new("menuTemplate.atlas.png#victoryStarSlot.png"))
    victoryStarSlot2:setColor(0.5, 0.5, 0.5)
    victoryStarSlot2:setLoc(110, 60)
    local victoryStarSlot3 = resultsKillBox:add(ui.Image.new("menuTemplate.atlas.png#victoryStarSlot.png"))
    victoryStarSlot3:setColor(0.5, 0.5, 0.5)
    victoryStarSlot3:setLoc(195, 60)
    local stars = endGameStats.stars
    local idx = (levelGalaxyIndex - 1) * 40 + levelSystemIndex
    local levelDef = GALAXY_DATA[idx]
    if stars == 1 then
      do
        local victoryStar1 = victoryStarSlot1:add(ui.Image.new("menuTemplate.atlas.png#victoryStar.png"))
        victoryStar1:clearAttrLink(MOAIColor.INHERIT_COLOR)
        local victoryStar2 = victoryStarSlot2:add(ui.TextBox.new(util.commasInNumbers(levelDef["2 Star Score"]), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
        victoryStar2:clearAttrLink(MOAIColor.INHERIT_COLOR)
        victoryStar2:setColor(UI_COLOR_GRAY[1], UI_COLOR_GRAY[2], UI_COLOR_GRAY[3])
        victoryStar2:setLoc(0, -10)
        local victoryStar3 = victoryStarSlot3:add(ui.TextBox.new(util.commasInNumbers(levelDef["3 Star Score"]), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
        victoryStar3:clearAttrLink(MOAIColor.INHERIT_COLOR)
        victoryStar3:setColor(UI_COLOR_GRAY[1], UI_COLOR_GRAY[2], UI_COLOR_GRAY[3])
        victoryStar3:setLoc(0, -10)
        local victoryText = resultsKillBox:add(ui.TextBox.new(_("Marginal Victory"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
        victoryText:setLoc(110, -5)
      end
    elseif stars == 2 then
      do
        local victoryStar1 = victoryStarSlot1:add(ui.Image.new("menuTemplate.atlas.png#victoryStar.png"))
        victoryStar1:clearAttrLink(MOAIColor.INHERIT_COLOR)
        local victoryStar2 = victoryStarSlot2:add(ui.Image.new("menuTemplate.atlas.png#victoryStar.png"))
        victoryStar2:clearAttrLink(MOAIColor.INHERIT_COLOR)
        local victoryStar3 = victoryStarSlot3:add(ui.TextBox.new(util.commasInNumbers(levelDef["3 Star Score"]), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
        victoryStar3:clearAttrLink(MOAIColor.INHERIT_COLOR)
        victoryStar3:setColor(UI_COLOR_GRAY[1], UI_COLOR_GRAY[2], UI_COLOR_GRAY[3])
        victoryStar3:setLoc(0, -10)
        local victoryText = resultsKillBox:add(ui.TextBox.new(_("Tactical Victory"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
        victoryText:setLoc(110, -5)
      end
    elseif stars == 3 then
      local victoryStar1 = victoryStarSlot1:add(ui.Image.new("menuTemplate.atlas.png#victoryStar.png"))
      victoryStar1:clearAttrLink(MOAIColor.INHERIT_COLOR)
      local victoryStar2 = victoryStarSlot2:add(ui.Image.new("menuTemplate.atlas.png#victoryStar.png"))
      victoryStar2:clearAttrLink(MOAIColor.INHERIT_COLOR)
      local victoryStar3 = victoryStarSlot3:add(ui.Image.new("menuTemplate.atlas.png#victoryStar.png"))
      victoryStar3:clearAttrLink(MOAIColor.INHERIT_COLOR)
      local victoryText = resultsKillBox:add(ui.TextBox.new(_("Decisive Victory!"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      victoryText:setLoc(110, -5)
    end
    local enemyKillValueText = resultsKillBox:add(ui.TextBox.new(_("Enemy Kill Value"), FONT_SMALL, "ffffff", "left", 260, nil, true))
    enemyKillValueText:clearAttrLink(MOAIColor.INHERIT_COLOR)
    enemyKillValueText:setLoc(100, -40)
    local enemyKillValueNumText = resultsKillBox:add(ui.TextBox.new(util.commasInNumbers(endGameStats.baseScore), FONT_SMALL_BOLD, "ffffff", "right", 260, nil, true))
    enemyKillValueNumText:clearAttrLink(MOAIColor.INHERIT_COLOR)
    enemyKillValueNumText:setLoc(100, -40)
    local unusedWarpCrystalsText = resultsKillBox:add(ui.TextBox.new(_("Unused"), FONT_SMALL, "ffffff", "left", 260, nil, true))
    unusedWarpCrystalsText:clearAttrLink(MOAIColor.INHERIT_COLOR)
    unusedWarpCrystalsText:setLoc(100, -70)
    local unusedWarpCrystalsIcon = resultsKillBox:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystalMed.png"))
    unusedWarpCrystalsIcon:clearAttrLink(MOAIColor.INHERIT_COLOR)
    unusedWarpCrystalsIcon:setLoc(60, -68)
    local unusedWarpCrystalsNumText = resultsKillBox:add(ui.TextBox.new("+ " .. util.commasInNumbers(endGameStats.plusScoreCrystals), FONT_SMALL_BOLD, "ffffff", "right", 260, nil, true))
    unusedWarpCrystalsNumText:clearAttrLink(MOAIColor.INHERIT_COLOR)
    unusedWarpCrystalsNumText:setLoc(100, -70)
    local finalScoreText = resultsKillBox:add(ui.TextBox.new(_("Final Score"), FONT_SMALL_BOLD, "ffffff", "left", 260, nil, true))
    finalScoreText:clearAttrLink(MOAIColor.INHERIT_COLOR)
    finalScoreText:setColor(unpack(UI_COLOR_GOLD))
    finalScoreText:setLoc(100, -100)
    local finalScoreNumText = resultsKillBox:add(ui.TextBox.new("= " .. util.commasInNumbers(scores.score), FONT_SMALL_BOLD, "ffffff", "right", 260, nil, true))
    finalScoreNumText:clearAttrLink(MOAIColor.INHERIT_COLOR)
    finalScoreNumText:setColor(unpack(UI_COLOR_GOLD))
    finalScoreNumText:setLoc(100, -100)
    local victoryEmblem = item:add(ui.Image.new("menuTemplate2.atlas.png#victoryEmblem.png"))
    victoryEmblem:setLoc(-140, submenu_y + 125)
    local alloyResultsBoxBG = item:add(ui.PickBox.new(2, 2))
    alloyResultsBoxBG:setLoc(0, submenu_y - 92)
    alloyResultsBoxBG.handleTouch = nil
    local alloyResultsBoxBGLeft = alloyResultsBoxBG:add(ui.PickBox.new(370, 92, color.toHex(0, 0, 0, 0.34)))
    alloyResultsBoxBGLeft:setLoc(-113, 1)
    alloyResultsBoxBGLeft.handleTouch = nil
    local alloyResultsBoxBGLeftBorder = alloyResultsBoxBG:add(ui.PickBox.new(370, 2, color.toHex(0, 0, 0, 0.5)))
    alloyResultsBoxBGLeftBorder:setLoc(-113, -45)
    alloyResultsBoxBGLeftBorder.handleTouch = nil
    local alloyResultsBoxBGRight = alloyResultsBoxBG:add(ui.PickBox.new(226, 92, color.toHex(0, 0, 0, 0.45)))
    alloyResultsBoxBGRight:setLoc(185, 1)
    alloyResultsBoxBGRight.handleTouch = nil
    local alloyResultsBoxBGRightBorder = alloyResultsBoxBG:add(ui.PickBox.new(226, 2, color.toHex(0, 0, 0, 0.7)))
    alloyResultsBoxBGRightBorder:setLoc(185, -45)
    alloyResultsBoxBGRightBorder.handleTouch = nil
    local alloyResultsBoxBracketL = alloyResultsBoxBG:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketL.png"))
    alloyResultsBoxBracketL:setLoc(-295, 2)
    local alloyResultsBoxBracketR = alloyResultsBoxBG:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketR.png"))
    alloyResultsBoxBracketR:setLoc(295, 2)
    local PlusAlloyPerkUsed = false
    if gameSessionAnalytics.perks ~= nil then
      for k, v in pairs(gameSessionAnalytics.perks) do
        if v == "plusAlloy" then
          PlusAlloyPerkUsed = true
          break
        end
      end
    end
    local AlloyCollectedText = alloyResultsBoxBG:add(ui.TextBox.new(_("Alloy Collected"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
    AlloyCollectedText:setLoc(-125, 32)
    local coltol = gameSessionAnalytics.currency.alloy.earned or 0
    if PlusAlloyPerkUsed ~= false then
      coltol = coltol / 2
    end
    local CollectedText = alloyResultsBoxBG:add(ui.TextBox.new("+ " .. util.commasInNumbers(coltol), FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
    CollectedText:setLoc(-25, 32)
    if PlusAlloyPerkUsed == false then
      CollectedText:setLoc(-25, 18)
      AlloyCollectedText:setLoc(-125, 18)
    end
    local victoryBonusText = alloyResultsBoxBG:add(ui.TextBox.new(_("Star Rating Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
    victoryBonusText:setLoc(-125, -1)
    local plusVictoryBonusText = alloyResultsBoxBG:add(ui.TextBox.new("+ " .. util.commasInNumbers(endGameStats.victoryBonusAlloy), FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
    plusVictoryBonusText:setLoc(-25, -1)
    if PlusAlloyPerkUsed == false then
      plusVictoryBonusText:setLoc(-25, -20)
      victoryBonusText:setLoc(-125, -20)
    end
    if PlusAlloyPerkUsed ~= false then
      local pertol = gameSessionAnalytics.currency.alloy.earned or 0
      pertol = pertol / 2
      local AlloyCollectedText = alloyResultsBoxBG:add(ui.TextBox.new(_("Perk Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
      AlloyCollectedText:setLoc(-125, -34)
      local CollectedText = alloyResultsBoxBG:add(ui.TextBox.new("+ " .. pertol, FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
      CollectedText:setLoc(-25, -34)
    end
    local finalcoltol = gameSessionAnalytics.currency.alloy.earned or 0
    local plusAlloyText = alloyResultsBoxBG:add(ui.TextBox.new(util.commasInNumbers(endGameStats.plusAlloy + finalcoltol), FONT_XLARGE, "ffffff", "center", nil, nil, true))
    plusAlloyText:setColor(0.898, 0.714, 0.215)
    plusAlloyText:setLoc(220, -2)
    local iconAlloy = alloyResultsBoxBG:add(ui.Image.new("menuTemplateShared.atlas.png#iconAlloyLarge.png"))
    iconAlloy:setColor(0.898, 0.714, 0.215)
    iconAlloy:setLoc(220 - plusAlloyText._width / 2 - 40, 0)
    local xpResultsBoxBG = item:add(ui.PickBox.new(2, 2))
    xpResultsBoxBG:setLoc(0, submenu_y - 207)
    xpResultsBoxBG.handleTouch = nil
    local xpResultsBoxBGLeft = xpResultsBoxBG:add(ui.PickBox.new(370, 92, color.toHex(0, 0, 0, 0.34)))
    xpResultsBoxBGLeft:setLoc(-113, 1)
    xpResultsBoxBGLeft.handleTouch = nil
    local xpResultsBoxBGLeftBorder = xpResultsBoxBG:add(ui.PickBox.new(370, 2, color.toHex(0, 0, 0, 0.5)))
    xpResultsBoxBGLeftBorder:setLoc(-113, -45)
    xpResultsBoxBGLeftBorder.handleTouch = nil
    local xpResultsBoxBGRight = xpResultsBoxBG:add(ui.PickBox.new(226, 92, color.toHex(0, 0, 0, 0.45)))
    xpResultsBoxBGRight:setLoc(185, 1)
    xpResultsBoxBGRight.handleTouch = nil
    local xpResultsBoxBGRightBorder = xpResultsBoxBG:add(ui.PickBox.new(226, 2, color.toHex(0, 0, 0, 0.7)))
    xpResultsBoxBGRightBorder:setLoc(185, -45)
    xpResultsBoxBGRightBorder.handleTouch = nil
    local xpResultsBoxBracketL = xpResultsBoxBG:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketL.png"))
    xpResultsBoxBracketL:setLoc(-295, 2)
    local xpResultsBoxBracketR = xpResultsBoxBG:add(ui.Image.new("menuTemplate.atlas.png#resultsBoxBracketR.png"))
    xpResultsBoxBracketR:setLoc(295, 2)
    local xpEarnedText = xpResultsBoxBG:add(ui.TextBox.new(_("XP Earned"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
    xpEarnedText:setLoc(-125, 20)
    local plusXPEarnedText = xpResultsBoxBG:add(ui.TextBox.new("+ " .. util.commasInNumbers(endGameStats.basePlusXP), FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
    plusXPEarnedText:setLoc(-25, 20)
    local victoryBonusText = xpResultsBoxBG:add(ui.TextBox.new(_("Star Rating Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
    victoryBonusText:setLoc(-125, -18)
    local plusVictoryBonusText = xpResultsBoxBG:add(ui.TextBox.new("+ " .. util.commasInNumbers(endGameStats.victoryBonusXP), FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
    plusVictoryBonusText:setLoc(-25, -18)
    if endGameStats.perkBonusXP ~= nil then
      local perkBonusText = xpResultsBoxBG:add(ui.TextBox.new(_("Perk Bonus"), FONT_SMALL_BOLD, "ffffff", "left", 300, nil, true))
      perkBonusText:setLoc(-125, -35)
      local plusPerkBonusText = xpResultsBoxBG:add(ui.TextBox.new("+ " .. util.commasInNumbers(endGameStats.perkBonusXP), FONT_SMALL_BOLD, "ffffff", "right", 150, nil, true))
      plusPerkBonusText:setLoc(-25, -35)
      victoryBonusText:setLoc(-125, -3)
      plusVictoryBonusText:setLoc(-25, -3)
      xpEarnedText:setLoc(-125, 30)
      plusXPEarnedText:setLoc(-25, 30)
    end
    local plusXPText = xpResultsBoxBG:add(ui.TextBox.new(util.commasInNumbers(scores.xp), FONT_XLARGE, "ffffff", "center", nil, nil, true))
    plusXPText:setColor(0.898, 0.714, 0.215)
    plusXPText:setLoc(220, -2)
    local iconXP = xpResultsBoxBG:add(ui.Image.new("menuTemplateShared.atlas.png#iconPlayerLevelLarge.png"))
    iconXP:setColor(0.898, 0.714, 0.215)
    iconXP:setLoc(220 - plusXPText._width / 2 - 40, 0)
  end
  return item
end
function victory_close(move)
  if move == nil then
    move = {empty = true}
  end
  if _victory_root.continueBtnGlowAction ~= nil then
    _victory_root.continueBtnGlowAction:stop()
    _victory_root.continueBtnGlowAction = nil
  end
  _menu_root:remove(_menu_root.topBarBG)
  _menu_root.topBarBG = nil
  _storemenu_close({
    store_menu = move.store_menu
  })
  if move.bottom_bar then
    do
      local action = _menu_root.bottomNavBG:seekLoc(0, -device.ui_height / 2 - 120, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        _menu_root:remove(_menu_root.bottomNavBG)
        _menu_root.bottomNavBG = nil
      end)
    end
  else
    _menu_root:remove(_menu_root.bottomNavBG)
    _menu_root.bottomNavBG = nil
  end
  if _victory_root.animateThread ~= nil then
    _victory_root.animateThread:stop()
    _victory_root.animateThread = nil
  end
  if move.forward then
    do
      local action = _victory_root:seekLoc(-device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_victory_root)
        _victory_root = nil
      end)
    end
  elseif move.back then
    do
      local action = _victory_root:seekLoc(device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_victory_root)
        _victory_root = nil
      end)
    end
  else
    submenuLayer:remove(_victory_root)
    _victory_root = nil
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  if scrollbar and scrollAction ~= nil then
    scrollAction:stop()
    scrollAction = nil
  end
  scrollbar = nil
  if device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  curScreen = nil
end
function victory_show(move)
  if move == nil then
    move = {empty = true}
  end
  _storemenu_show("victory", true, nil, {
    store_menu = move.store_menu or move.animate
  })
  local topBarBG = _menu_root:add(ui.Image.new("menuTopBars.atlas.png#topBarVictory.png"))
  if not profile.excludeAds then
    topBarBG:setLoc(0, device.ui_height / 2 - 150)
  else
    topBarBG:setLoc(0, device.ui_height / 2 - 50)
  end
  _menu_root.topBarBG = topBarBG
  local topBarBGPickBox = topBarBG:add(ui.PickBox.new(device.ui_width, 100))
  local topBarText = topBarBG:add(ui.TextBox.new(_("Victory!"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  topBarText:setLoc(0, -6)
  if device.os == device.OS_ANDROID then
    local function callback()
      _victory_root.forward = true
      return true
    end
    table_insert(android_back_button_queue, callback)
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
  local menuBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconHome.png"))
  menuBtn._down:setColor(0.5, 0.5, 0.5)
  menuBtn:setLoc(device.ui_width / 2 - 42, 0)
  menuBtn.handleTouch = Button_handleTouch
  function menuBtn:onClick()
    menu_close()
    mainmenu_show()
    soundmanager.onSFX("onPageSwipeBack")
  end
  _victory_root = ui.Group.new()
  _victory_root:add(_victory_create_item(move.animate, scores.alloy, scores.xp))
  if move.forward then
    _victory_root:setLoc(device.ui_width * 2, 0)
    _victory_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  elseif move.back then
    _victory_root:setLoc(-device.ui_width * 2, 0)
    _victory_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  end
  local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
  if move.bottom_bar then
    bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
    bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
  elseif move.animate then
    bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
  else
    bottomNavBG:setLoc(0, -device.ui_height / 2 - 8)
  end
  _menu_root.bottomNavBG = bottomNavBG
  local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
  bottomNavBGPickBox:setLoc(0, -20)
  local continueBtnGlow = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#largeButtonGlow.png"))
  continueBtnGlow:setColor(0.25, 0.25, 0.25, 0)
  continueBtnGlow:setScl(0.995, 0.995)
  continueBtnGlow:setLoc(0, 45)
  _victory_root.continueBtnGlowAction = uiAS:repeatcall(0.5, function()
    if continueBtnGlow.active then
      continueBtnGlow:seekColor(0.25, 0.25, 0.25, 0, 0.5, MOAIEaseType.EASE_IN)
      continueBtnGlow.active = nil
      continueBtnGlow.wait = true
    elseif continueBtnGlow.wait then
      continueBtnGlow.wait = nil
    else
      continueBtnGlow:seekColor(1, 1, 1, 0, 0.5, MOAIEaseType.EASE_IN)
      continueBtnGlow.active = true
    end
  end)
  local continueBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#largeButton.png"))
  continueBtn._down:setColor(0.5, 0.5, 0.5)
  continueBtn:setLoc(0, 50)
  local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  continueBtnText:setLoc(-15, 0)
  local continueBtnIcon = continueBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
  continueBtnIcon:setLoc(70, 0)
  local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
  continueBtnText:setLoc(-15, 0)
  local continueBtnIcon = continueBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
  continueBtnIcon:setLoc(70, 0)
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn:onClick()
    if not screenAction:isActive() then
      table_insert(screenHistory, "victory")
      victory_close({forward = true})
      achievements_show({forward = true})
      soundmanager.onSFX("onPageSwipeForward")
    end
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  if move.animate then
    galaxymap_animate = "victory"
  end
  submenuLayer:add(_victory_root)
  curScreen = "victory"
end
local spinner = ui.Anim.new("downloadSpinner.atlas.png")
local function _enable_spinner(value)
  if spinner._uilayer == nil and value then
    debugLayer:add(spinner)
    spinner:loop("spinnerAnim")
  elseif spinner._uilayer ~= nil and not value then
    spinner:remove()
    spinner:stop()
  end
end
local function _clearLeaderboard()
  if _leaderboard_root.bg and _leaderboard_root.bg.items_group then
    _leaderboard_root.bg.items_group:remove()
    _leaderboard_root.bg.items_group = _leaderboard_root:add(ui.Group.new())
    _leaderboard_root.bg.items_group.numItems = 0
  end
  if _leaderboard_root.playerBarGroup then
    _leaderboard_root.playerBarGroup:remove()
    _leaderboard_root.playerBarGroup = nil
  end
end
function leaderboard_close(move)
  if move == nil then
    move = {empty = true}
  end
  _clearLeaderboard()
  if _leaderboard_root.continueBtnGlowAction ~= nil then
    _leaderboard_root.continueBtnGlowAction:stop()
    _leaderboard_root.continueBtnGlowAction = nil
  end
  _menu_root:remove(_menu_root.topBarBG)
  _menu_root.topBarBG = nil
  _storemenu_close({
    store_menu = move.store_menu
  })
  if _leaderboard_root.tabBar then
    _leaderboard_root.tabBar:remove()
  end
  if _menu_root.bottomNavBG ~= nil then
    if move.bottom_bar then
      do
        local action = _menu_root.bottomNavBG:seekLoc(0, -device.ui_height / 2 - 120, 0.5, MOAIEaseType.EASE_IN)
        action:setListener(MOAITimer.EVENT_STOP, function()
          _menu_root:remove(_menu_root.bottomNavBG)
          _menu_root.bottomNavBG = nil
        end)
      end
    else
      _menu_root:remove(_menu_root.bottomNavBG)
      _menu_root.bottomNavBG = nil
    end
  end
  if move.forward then
    do
      local action = _leaderboard_root:seekLoc(-device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_leaderboard_root)
        _leaderboard_root = nil
      end)
    end
  elseif move.back then
    do
      local action = _leaderboard_root:seekLoc(device.ui_width * 2, 0, 0.5, MOAIEaseType.EASE_IN)
      action:setListener(MOAITimer.EVENT_STOP, function()
        submenuLayer:remove(_leaderboard_root)
        _leaderboard_root = nil
      end)
    end
  else
    submenuLayer:remove(_leaderboard_root)
    _leaderboard_root = nil
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  if scrollbar and scrollAction ~= nil then
    scrollAction:stop()
    scrollAction = nil
  end
  scrollbar = nil
  curScreen = nil
  _enable_spinner(nil)
  cloud.setLeaderboardCallback(nil)
  cloud.setPostLeaderboardCallback(nil)
end
local function _leaderboard_items_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  local submenu_height = device.ui_height - 100 - 60 - 125
  local submenu_y = -80
  if _menu_root.bottomNavBG ~= nil then
    submenu_height = submenu_height - 90
    submenu_y = submenu_y + 45
  end
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  if _leaderboard_root.playerBarGroup then
    submenu_height = submenu_height - 50
    submenu_y = submenu_y + 25
  end
  local items_group = self.items_group
  if items_group.numItems == 0 then
    return
  end
  if eventType == ui.TOUCH_DOWN and touchIdx == ui.TOUCH_ONE then
    if 0 < math.max(items_group.numItems * items_group.item_height - submenu_height, 0) then
      if not exclude_capture then
        ui.capture(self)
      end
      scrolling = true
      lastX = x
      lastY = y
      diffX = 0
      diffY = 0
      if scrollbar == nil then
        scrollbar = ui.Group.new()
        do
          local scrollbar_fill = scrollbar:add(ui.Image.new("scrollbar_fill.png"))
          scrollbar_fill:setScl(1, 3.5)
          scrollbar.fill = scrollbar_fill
          local scrollbar_top = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_top:setLoc(0, 36)
          scrollbar.top = scrollbar_top
          local scrollbar_bot = scrollbar:add(ui.Image.new("scrollbar_end.png"))
          scrollbar_bot:setLoc(0, -36)
          scrollbar_bot:setScl(1, -1)
          scrollbar.bot = scrollbar_bot
          local groupX, groupY = items_group:getLoc()
          local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
          scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70))
          scrollbar.fill:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.top:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          scrollbar.bot:setColor(0, 0, 0, 0)
          scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
          self:add(scrollbar)
        end
      else
        if scrollbar_fadeOutActions.fill ~= nil and scrollbar_fadeOutActions.fill:isActive() then
          scrollbar_fadeOutActions.fill:stop()
          scrollbar_fadeOutActions.top:stop()
          scrollbar_fadeOutActions.bot:stop()
        end
        scrollbar_fadeInActions.fill = scrollbar.fill:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.top = scrollbar.top:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
        scrollbar_fadeInActions.bot = scrollbar.bot:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
      end
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
  elseif eventType == ui.TOUCH_UP and touchIdx == ui.TOUCH_ONE then
    if not exclude_capture then
      ui.capture(nil)
    end
    scrolling = false
    if scrollbar ~= nil and scrollbar.velocityY ~= nil then
      scrollbar.velocityY = scrollbar.velocityY + diffY
    elseif scrollbar ~= nil then
      scrollbar.velocityY = diffY
    end
    if scrollAction == nil then
      scrollAction = uiAS:wrap(function(dt)
        if scrollbar ~= nil then
          do
            local groupX, groupY = items_group:getLoc()
            local newY = util.clamp(groupY - scrollbar.velocityY, 0, math.max(items_group.numItems * items_group.item_height - submenu_height, 0))
            items_group:setLoc(0, util.roundNumber(newY))
            local groupX, groupY = items_group:getLoc()
            local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
            scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70))
            scrollbar.velocityY = scrollbar.velocityY + scrollbar.velocityY * -1 * dt * 0.03 * device.dpi
            if not scrolling and abs(scrollbar.velocityY) < 0.5 then
              scrollAction:stop()
              scrollAction = nil
            end
          end
        else
          scrollAction:stop()
          scrollAction = nil
        end
      end, function()
        if not scrolling and scrollbar ~= nil then
          if scrollbar_fadeInActions.fill ~= nil and scrollbar_fadeInActions.fill:isActive() then
            scrollbar_fadeInActions.fill:stop()
            scrollbar_fadeInActions.top:stop()
            scrollbar_fadeInActions.bot:stop()
          end
          scrollbar_fadeOutActions.fill = scrollbar.fill:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.top = scrollbar.top:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.bot = scrollbar.bot:seekColor(0, 0, 0, 0, 0.5, MOAIEaseType.EASE_IN)
          scrollbar_fadeOutActions.fill:setListener(MOAITimer.EVENT_STOP, function()
            if not scrolling and self ~= nil then
              self:remove(scrollbar)
              scrollbar = nil
            end
          end)
        end
      end)
    end
  elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE and scrolling then
    diffY = lastY - y
    local groupX, groupY = items_group:getLoc()
    local newY = util.clamp(groupY - diffY, 0, math.max(items_group.numItems * items_group.item_height - submenu_height, 0))
    items_group:setLoc(0, util.roundNumber(newY))
    if scrollbar ~= nil then
      local groupX, groupY = items_group:getLoc()
      local perc = groupY / (items_group.numItems * items_group.item_height - submenu_height)
      scrollbar:setLoc(device.ui_width / 2 - 10, submenu_height / 2 - 35 - perc * (submenu_height - 70))
    end
    if scrollAction ~= nil then
      scrollbar.velocityY = nil
      scrollAction:stop()
      scrollAction = nil
    end
    lastX = x
    lastY = y
  end
  return true
end
local function _leaderboard_create_lastweek_item(def)
  local item = ui.Group.new()
  local itemBG = item:add(ui.PickBox.new(device.ui_width, 76, "00000033"))
  local topBorder = item:add(ui.Image.new("menuTemplate.atlas.png#listItemTop.png"))
  topBorder:setScl(device.ui_width / 4, 1)
  topBorder:setLoc(0, 38)
  local bottomBorder = item:add(ui.Image.new("menuTemplate.atlas.png#listItemBottom.png"))
  bottomBorder:setScl(device.ui_width / 4, 1)
  bottomBorder:setLoc(0, -38)
  local str = def.username
  local xmin, ymin, xmax, ymax
  local DEFAULT_FONT_CHARCODES = " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.:,;'\"(!?)+-=*/@#$%^&_[]<>`~\\{}|"
  str = str:gsub(".", function(c)
    if c ~= "[" and c ~= "]" and c ~= "(" then
      if c == ")" then
      elseif not DEFAULT_FONT_CHARCODES:find(c) then
        return "?"
      end
    end
  end)
  local playerName = item:add(ui.TextBox.new(str, FONT_MEDIUM_BOLD, "ffffff", "left", nil, nil, true))
  xmin, ymin, xmax, ymax = playerName:getStringBounds(1, str:len())
  local maxWidth = 310
  local overrun = false
  while maxWidth < xmax - xmin do
    str = str:sub(1, str:len() - 1)
    playerName:setString(str)
    xmin, ymin, xmax, ymax = playerName:getStringBounds(1, str:len())
    overrun = true
  end
  if overrun then
    str = str .. "..."
    playerName:setString(str)
    xmin, ymin, xmax, ymax = playerName:getStringBounds(1, str:len())
    local width = xmax - xmin + 5
    local height = playerName._height
    playerName._textbox:setRect(-width / 2, -height / 2, width / 2, height / 2)
    playerName._shadow:setRect(-width / 2, -height / 2, width / 2, height / 2)
    playerName._width = width
  end
  playerName:setLoc(-device.ui_width / 2 + (xmax - xmin) / 2 + 95, 10)
  str = "Last Week's Winner!"
  local deviceName = item:add(ui.TextBox.new(str, FONT_SMALL_BOLD, "ffffff", "left", nil, nil, true))
  xmin, ymin, xmax, ymax = deviceName:getStringBounds(1, str:len())
  deviceName:setColor(unpack(UI_COLOR_BLUE))
  deviceName:setLoc(-device.ui_width / 2 + (xmax - xmin) / 2 + 95, -20)
  local wave = def.wave or 0
  str = string.format("%s %d", _("Wave"), wave)
  local waveTxt = item:add(ui.TextBox.new(str, FONT_SMALL_BOLD, "ffffff", "right", nil, nil, true))
  xmin, ymin, xmax, ymax = waveTxt:getStringBounds(1, str:len())
  waveTxt:setColor(unpack(UI_COLOR_BLUE))
  waveTxt:setLoc(device.ui_width / 2 - (xmax - xmin) / 2 - 20, -20)
  local score = def.score
  if score > 1000000 then
    str = string.format("%.2f mil", score / 1000000)
  else
    str = util.commasInNumbers(score)
  end
  local scoreTxt = item:add(ui.TextBox.new(str, FONT_MEDIUM_BOLD, "ffffff", "right", nil, nil, true))
  xmin, ymin, xmax, ymax = scoreTxt:getStringBounds(1, str:len())
  scoreTxt:setLoc(device.ui_width / 2 - (xmax - xmin) / 2 - 20, 10)
  local rankBG = item:add(ui.NinePatch.new("boxPlain9p.lua", 68, 68))
  rankBG:setLoc(-device.ui_width / 2 + 50, 0)
  local starIcon = rankBG:add(ui.Image.new("menuIconsAchievements.atlas.png#achievementIcon-officerondeck-1.png"))
  starIcon:clearAttrLink(MOAIColor.INHERIT_COLOR)
  starIcon:setColor(unpack(UI_COLOR_BLUE))
  starIcon:setScl(0.92, 0.92)
  playerName:setColor(unpack(UI_COLOR_GOLD))
  scoreTxt:setColor(unpack(UI_COLOR_GOLD))
  return item
end
local function _leaderboard_create_item(def)
  local item = ui.Group.new()
  local itemBG = item:add(ui.PickBox.new(device.ui_width, 76, "00000033"))
  itemBG.handleTouch = nil
  if def.userid and device.udid == def.userid then
    local achievedBox = item:add(ui.NinePatch.new("boxAchievement9p.lua", device.ui_width - 10, 76))
    achievedBox:setLoc(0, 1)
  end
  local rankBG = item:add(ui.NinePatch.new("boxPlain9p.lua", 68, 68))
  rankBG:setLoc(-device.ui_width / 2 + 50, 0)
  local rank = def.rank
  local font
  if rank > 99 then
    font = FONT_SMALL_BOLD
  elseif rank > 10 then
    font = FONT_MEDIUM_BOLD
  else
    font = FONT_XLARGE
  end
  local str, xmin, ymin, xmax, ymax
  local rankName = rankBG:add(ui.TextBox.new(string.format("%d", rank), font, "ffffff", "center", nil, nil, true))
  rankName:setLoc(0, -5)
  str = def.username
  local DEFAULT_FONT_CHARCODES = " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.:,;'\"(!?)+-=*/@#$%^&_[]<>`~\\{}|"
  str = str:gsub(".", function(c)
    if c ~= "[" and c ~= "]" and c ~= "(" then
      if c == ")" then
      elseif not DEFAULT_FONT_CHARCODES:find(c) then
        return "?"
      end
    end
  end)
  local playerName = item:add(ui.TextBox.new(str, FONT_MEDIUM_BOLD, "ffffff", "left", nil, nil, true))
  xmin, ymin, xmax, ymax = playerName:getStringBounds(1, str:len())
  local maxWidth = 310
  local overrun = false
  while maxWidth < xmax - xmin do
    str = str:sub(1, str:len() - 1)
    playerName:setString(str)
    xmin, ymin, xmax, ymax = playerName:getStringBounds(1, str:len())
    overrun = true
  end
  if overrun then
    str = str .. "..."
    playerName:setString(str)
    xmin, ymin, xmax, ymax = playerName:getStringBounds(1, str:len())
    local width = xmax - xmin + 5
    local height = playerName._height
    playerName._textbox:setRect(-width / 2, -height / 2, width / 2, height / 2)
    playerName._shadow:setRect(-width / 2, -height / 2, width / 2, height / 2)
    playerName._width = width
  end
  playerName:setLoc(-device.ui_width / 2 + (xmax - xmin) / 2 + 95, 10)
  str = def.displayName or _("Device")
  local deviceName = item:add(ui.TextBox.new(str, FONT_SMALL_BOLD, "ffffff", "left", nil, nil, true))
  xmin, ymin, xmax, ymax = deviceName:getStringBounds(1, str:len())
  deviceName:setColor(unpack(UI_COLOR_GRAY))
  deviceName:setLoc(-device.ui_width / 2 + (xmax - xmin) / 2 + 95, -20)
  local wave = def.wave or 0
  str = string.format("%s %d", _("Wave"), wave)
  local waveTxt = item:add(ui.TextBox.new(str, FONT_SMALL_BOLD, "ffffff", "right", nil, nil, true))
  xmin, ymin, xmax, ymax = waveTxt:getStringBounds(1, str:len())
  waveTxt:setColor(unpack(UI_COLOR_GRAY))
  waveTxt:setLoc(device.ui_width / 2 - (xmax - xmin) / 2 - 20, -20)
  local score = def.score
  if score > 1000000 then
    str = string.format("%.2f mil", score / 1000000)
  else
    str = util.commasInNumbers(score)
  end
  local scoreTxt = item:add(ui.TextBox.new(str, FONT_MEDIUM_BOLD, "ffffff", "right", nil, nil, true))
  xmin, ymin, xmax, ymax = scoreTxt:getStringBounds(1, str:len())
  scoreTxt:setLoc(device.ui_width / 2 - (xmax - xmin) / 2 - 20, 10)
  local x, y = scoreTxt:getLoc()
  xmin = x + xmin - 20
  if def.omega and 0 < def.omega then
    local omega13Icn = item:add(ui.Image.new("menuTemplateShared.atlas.png#iconOmega13Med.png"))
    omega13Icn:setColor(unpack(UI_FILL_RED_COLOR))
    omega13Icn:setLoc(xmin, 12)
    xmin = xmin - 32
  end
  if def.blossoms and 0 < def.blossoms then
    local blossomIcn = item:add(ui.Image.new("menuTemplateShared.atlas.png#iconDeathBlossomMed.png"))
    blossomIcn:setColor(unpack(UI_FILL_RED_COLOR))
    blossomIcn:setLoc(xmin, 12)
  end
  local topBorder = item:add(ui.Image.new("menuTemplate.atlas.png#listItemTop.png"))
  topBorder:setScl(device.ui_width / 4, 1)
  topBorder:setLoc(0, 38)
  local bottomBorder = item:add(ui.Image.new("menuTemplate.atlas.png#listItemBottom.png"))
  bottomBorder:setScl(device.ui_width / 4, 1)
  bottomBorder:setLoc(0, -38)
  return item
end
local lbFetchTimer
local function killLeaderboardTimer()
  _enable_spinner(nil)
  if not MOAIApp or not MOAIApp.showDialog then
    return
  end
  MOAIApp.showDialog(_("Connection Timeout"), _("Trouble communicating with the Leaderboards. Please try again later."), nil, nil, _("Okay"), false, nil, nil)
end
local function startLeaderBoardTimer()
  if lbFetchTimer then
    lbFetchTimer:stop()
  end
  lbFetchTimer = uiAS:delaycall(LEADERBOARD_TIMEOUT or 10, killLeaderboardTimer)
end
local function _onPostLeaderboard()
  if not _leaderboard_root or not _leaderboard_root.curboard then
    return
  end
  _clearLeaderboard()
  local board = _leaderboard_root.curboard
  if board == "top" then
    if _leaderboard_root.curfilter == "all" then
      cloud.fetchLeaderboards()
    else
      cloud.fetchWeeklyLeaderboard()
    end
  elseif board == "fb" then
    if _leaderboard_root.curfilter == "all" then
      cloud.fetchFBLeaderboard()
    else
      cloud.fetchWeeklyFBLeaderboard()
    end
  elseif board == "gc" then
    if _leaderboard_root.curfilter == "all" then
      cloud.fetchGCLeaderboard()
    else
      cloud.fetchWeeklyGCLeaderboard()
    end
  end
end
local function _onLeaderboardFetched(reqType, response)
  if _leaderboard_root.curboard == "top" and _leaderboard_root.curfilter == "all" and reqType == "GetLeaderboard_Top" or _leaderboard_root.curboard == "gc" and _leaderboard_root.curfilter == "all" and reqType == "GetLeaderboard_GC" or _leaderboard_root.curboard == "fb" and _leaderboard_root.curfilter == "all" and reqType == "GetLeaderboard_FB" or _leaderboard_root.curboard == "top" and _leaderboard_root.curfilter == "week" and reqType == "GetLeaderboard_WTop" or _leaderboard_root.curboard == "gc" and _leaderboard_root.curfilter == "week" and reqType == "GetLeaderboard_WGC" or _leaderboard_root.curboard == "fb" and _leaderboard_root.curfilter == "week" and reqType == "GetLeaderboard_WFB" then
    _enable_spinner(nil)
    if lbFetchTimer then
      lbFetchTimer:stop()
      lbFetchTimer = nil
    end
    do
      local submenu_height = device.ui_height - 100 - 60 - 125
      local submenu_y = -80
      if #screenHistory > 0 then
        submenu_height = submenu_height - 90
        submenu_y = submenu_y + 45
      end
      if not profile.excludeAds then
        submenu_height = submenu_height - 100
        submenu_y = submenu_y - 50
      end
      local items = {}
      local items_group = _leaderboard_root.bg.items_group
      local y = submenu_height / 2 + submenu_y - 45
      if _leaderboard_root.curfilter == "week" then
        local lastWinner
        if _leaderboard_root.curboard == "top" then
          lastWinner = cloud.getLeaderboardWinner()
        elseif _leaderboard_root.curboard == "gc" then
          lastWinner = cloud.getGCLeaderboardWinner()
        elseif _leaderboard_root.curboard == "fb" then
          lastWinner = cloud.getFBLeaderboardWinner()
        end
        if lastWinner and lastWinner[1] then
          local item = items_group:add(_leaderboard_create_lastweek_item(lastWinner[1]))
          item:setLoc(0, y)
          y = y - 78
          table_insert(items, item)
        end
      end
      local maxRank = LEADERBOARD_MAX_SCORES_TOP or 10
      if _leaderboard_root.curboard == "gc" or _leaderboard_root.curboard == "fb" then
        maxRank = LEADERBOARD_MAX_SCORES_FRIEND or maxRank
      end
      local player
      local count = #response
      local outSeq = {}
      for i, def in pairs(response) do
        if type(i) ~= "number" or i > count then
          outSeq[#outSeq + 1] = def
        end
      end
      for i, def in ipairs(outSeq) do
        response[#response + 1] = def
      end
      for i, def in ipairs(response) do
        if def.userid and (device.udid == def.userid or maxRank >= def.rank) then
          if maxRank >= def.rank then
            local item = items_group:add(_leaderboard_create_item(def))
            item:setLoc(0, y)
            y = y - 78
            table_insert(items, item)
          end
          if def.userid and device.udid == def.userid then
            player = def
          end
        end
      end
      items_group.numItems = #items
      items_group.item_height = 78
      _leaderboard_root.items = items
      local localScore = false
      local postFilter
      if _leaderboard_root.curfilter == "week" then
        if not player or player.score < profile.survivalWHighScore then
          player = {}
          player.score = profile.survivalWHighScore
          player.wave = profile.survivalWHighScoreWave
          player.omega = profile.survivalWOmega13
          player.blossoms = profile.survivalWDeathBlossom
          postFilter = "all"
          localScore = true
        end
      elseif not player or player.score < profile.survivalHighScore then
        player = {}
        player.score = profile.survivalHighScore
        player.wave = profile.survivalHighScoreWave
        player.omega = profile.survivalOmega13
        player.blossoms = profile.survivalDeathBlossom
        postFilter = "week"
        localScore = true
      end
      if localScore and player.score == 0 then
        player = nil
      end
      if player then
        local playerBarGroup = _menu_root:add(ui.Group.new())
        _leaderboard_root.playerBarGroup = playerBarGroup
        local playerBarBG = playerBarGroup:add(ui.Image.new("menuTemplate2.atlas.png#storeFiltersBG.png"))
        playerBarBG:setScl(1, -1)
        playerBarBG:setPriority(-1)
        if #screenHistory > 0 and screenHistory[#screenHistory] ~= "galaxymap" then
          if _leaderboard_root.bottom_bar then
            playerBarBG:setLoc(0, -device.ui_height / 2 - 120)
            playerBarBG:seekLoc(0, -device.ui_height / 2 + 140, 0.5, MOAIEaseType.EASE_IN)
          else
            playerBarBG:setLoc(0, -device.ui_height / 2 + 140)
          end
        elseif _leaderboard_root.bottom_bar then
          playerBarBG:setLoc(0, -device.ui_height / 2 - 120)
          playerBarBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
        else
          playerBarBG:setLoc(0, -device.ui_height / 2 + 40)
        end
        local barBGGroup = playerBarBG:add(ui.Group.new())
        barBGGroup:setScl(1, -1)
        local str, xmin, ymin, xmax, yma
        if localScore then
          do
            local leaderboardBtn = barBGGroup:add(ui.Button.new("menuTemplateShared.atlas.png#warpMenuStoreButton.png"))
            leaderboardBtn._down:setColor(0.5, 0.5, 0.5)
            leaderboardBtn:setLoc(-device.ui_width / 2 + 180, 10)
            local leaderboardBtnText = leaderboardBtn._up:add(ui.TextBox.new(_("Post High Score"), FONT_MEDIUM_BOLD, "ffffff", "center"))
            leaderboardBtnText:setColor(0, 0, 0)
            leaderboardBtnText:setLoc(0, -2)
            local leaderboardBtnText = leaderboardBtn._down:add(ui.TextBox.new(_("Post High Score"), FONT_MEDIUM_BOLD, "ffffff", "center"))
            leaderboardBtnText:setColor(0, 0, 0)
            leaderboardBtnText:setLoc(0, -2)
            leaderboardBtn.handleTouch = Button_handleTouch
            _leaderboard_root.leaderboardBtn = leaderboardBtn
            function leaderboardBtn.onClick()
              PromptUserForHighScore(player.score, player.omega, player.blossom, player.wave, true, postFilter)
            end
          end
        else
          local str = string.format("%s #%s", _("Your Rank:"), util.commasInNumbers(player.rank))
          local playerRankTxt = barBGGroup:add(ui.TextBox.new(str, FONT_MEDIUM_BOLD, "ffffff", "left", nil, nil, true))
          xmin, ymin, xmax, ymax = playerRankTxt:getStringBounds(1, str:len())
          playerRankTxt:setColor(unpack(UI_COLOR_GOLD))
          playerRankTxt:setLoc(-device.ui_width / 2 + (xmax - xmin) / 2 + 20, 20)
        end
        str = util.commasInNumbers(player.score)
        local scoreTxt = barBGGroup:add(ui.TextBox.new(str, FONT_MEDIUM_BOLD, "ffffff", "right", nil, nil, true))
        xmin, ymin, xmax, ymax = scoreTxt:getStringBounds(1, str:len())
        scoreTxt:setColor(unpack(UI_COLOR_GOLD))
        scoreTxt:setLoc(device.ui_width / 2 - (xmax - xmin) / 2 - 20, 20)
        local wave = player.wave or 0
        str = string.format("%s %d", _("Wave"), wave)
        waveTxt = barBGGroup:add(ui.TextBox.new(str, FONT_SMALL_BOLD, "ffffff", "right", nil, nil, true))
        local xmin, ymin, xmax, ymax = waveTxt:getStringBounds(1, str:len())
        waveTxt:setColor(unpack(UI_COLOR_GRAY))
        waveTxt:setLoc(device.ui_width / 2 - (xmax - xmin) / 2 - 20, -10)
        if _leaderboard_root.curboard ~= "top" and not localScore then
          local noun = _("friends")
          if _leaderboard_root.curboard == "top" then
            noun = _("players")
          end
          str = string.format("%s %s %s", _("out of"), util.commasInNumbers(items_group.numItems), noun)
          local totRankTxt = barBGGroup:add(ui.TextBox.new(str, FONT_SMALL_BOLD, "ffffff", "left", nil, nil, true))
          xmin, ymin, xmax, ymax = totRankTxt:getStringBounds(1, str:len())
          totRankTxt:setColor(unpack(UI_COLOR_GRAY))
          totRankTxt:setLoc(-device.ui_width / 2 + (xmax - xmin) / 2 + 20, -10)
        end
        xmin, ymin, xmax, ymax = scoreTxt:getStringBounds(1, str:len())
        local x, y = scoreTxt:getLoc()
        xmin = x + xmin - 20
        if player.omega and 0 < player.omega then
          local omega13Icn = barBGGroup:add(ui.Image.new("menuTemplateShared.atlas.png#iconOmega13Med.png"))
          omega13Icn:setColor(unpack(UI_FILL_RED_COLOR))
          omega13Icn:setLoc(xmin, 24)
          omega13Icn:setScl(0.5, 0.5)
          xmin = xmin - 32
        end
        if player.blossoms and 0 < player.blossoms then
          local blossomIcn = barBGGroup:add(ui.Image.new("menuTemplateShared.atlas.png#iconDeathBlossomMed.png"))
          blossomIcn:setColor(unpack(UI_FILL_RED_COLOR))
          blossomIcn:setLoc(xmin, 24)
          blossomIcn:setScl(0.5, 0.5)
        end
      end
    end
  end
end
LB_FADE_VAL = 0.6
LB_FADE_VAL_TABLE = {
  LB_FADE_VAL,
  LB_FADE_VAL,
  LB_FADE_VAL,
  LB_FADE_VAL
}
local function _leaderboardFilter_onClick(self)
  if self.board and self.board == _leaderboard_root.curboard or self.filter and self.filter == _leaderboard_root.curfilter then
    return
  end
  _clearLeaderboard()
  startLeaderBoardTimer()
  if self.board then
    if _leaderboard_root.curboard == "top" then
      _leaderboard_root.topBtn._up:setColor(unpack(LB_FADE_VAL_TABLE))
      _leaderboard_root.topBtn._down:setColor(1, 1, 1, 1)
      _leaderboard_root.topBtnGrp:setColor(unpack(LB_FADE_VAL_TABLE))
    elseif _leaderboard_root.curboard == "fb" then
      _leaderboard_root.fbBtn._up:setColor(unpack(LB_FADE_VAL_TABLE))
      _leaderboard_root.fbBtn._down:setColor(1, 1, 1, 1)
      _leaderboard_root.fbBtnGrp:setColor(unpack(LB_FADE_VAL_TABLE))
    elseif _leaderboard_root.curboard == "gc" then
      _leaderboard_root.gcBtn._up:setColor(unpack(LB_FADE_VAL_TABLE))
      _leaderboard_root.gcBtn._down:setColor(1, 1, 1, 1)
      _leaderboard_root.gcBtnGrp:setColor(unpack(LB_FADE_VAL_TABLE))
    end
    if self.board == "top" then
      _leaderboard_root.topBtn._up:setColor(1, 1, 1, 1)
      _leaderboard_root.topBtn._down:setColor(1, 1, 1, 1)
      _leaderboard_root.topBtnGrp:setColor(1, 1, 1, 1)
    elseif self.board == "fb" then
      _leaderboard_root.fbBtn._up:setColor(1, 1, 1, 1)
      _leaderboard_root.fbBtn._down:setColor(1, 1, 1, 1)
      _leaderboard_root.fbBtnGrp:setColor(1, 1, 1, 1)
    elseif self.board == "gc" then
      _leaderboard_root.gcBtn._up:setColor(1, 1, 1, 1)
      _leaderboard_root.gcBtn._down:setColor(1, 1, 1, 1)
      _leaderboard_root.gcBtnGrp:setColor(1, 1, 1, 1)
    end
    _leaderboard_root.curboard = self.board
  elseif self.filter then
    if _leaderboard_root.curfilter == "all" then
      _leaderboard_root.allBtn._up:setColor(unpack(LB_FADE_VAL_TABLE))
      _leaderboard_root.allBtn._down:setColor(1, 1, 1, 1)
    elseif _leaderboard_root.curfilter == "week" then
      _leaderboard_root.weeklyBtn._up:setColor(unpack(LB_FADE_VAL_TABLE))
      _leaderboard_root.weeklyBtn._down:setColor(1, 1, 1, 1)
    end
    if self.filter == "all" then
      _leaderboard_root.allBtn._up:setColor(1, 1, 1, 1)
      _leaderboard_root.allBtn._down:setColor(1, 1, 1, 1)
      _leaderboard_root.allBtnGrp:setColor(unpack(UI_COLOR_GRAY_DARKEN))
    elseif self.filter == "week" then
      _leaderboard_root.weeklyBtn._up:setColor(1, 1, 1, 1)
      _leaderboard_root.weeklyBtn._down:setColor(1, 1, 1, 1)
      _leaderboard_root.weeklyBtnGrp:setColor(unpack(UI_COLOR_GRAY_DARKEN))
    end
    _leaderboard_root.curfilter = self.filter
  end
  if _leaderboard_root.curboard == "top" then
    if _leaderboard_root.curfilter == "all" then
      cloud.fetchLeaderboards()
    else
      cloud.fetchWeeklyLeaderboard()
    end
  elseif _leaderboard_root.curboard == "fb" then
    if not fb.isLoggedIn() then
      fb.setListener(function(event, data)
        if event == fb.EVENT_FRIENDSLIST_READY then
          fb.setListener(nil)
          cloud.mapFacebookAccount()
          if _leaderboard_root.curfilter == "all" then
            cloud.fetchFBLeaderboard()
          else
            cloud.fetchWeeklyFBLeaderboard()
          end
        end
      end)
      fb.login()
    elseif _leaderboard_root.curfilter == "all" then
      cloud.fetchFBLeaderboard()
    else
      cloud.fetchWeeklyFBLeaderboard()
    end
  elseif _leaderboard_root.curboard == "gc" then
    if not gamecenter.isLoggedIn() then
      gamecenter.setFriendsListCallback(function()
        cloud.mapGameCenterAccount()
        if _leaderboard_root.curfilter == "all" then
          cloud.fetchGCLeaderboard()
        else
          cloud.fetchWeeklyGCLeaderboard()
        end
        gamecenter.setFriendsListCallback(nil)
      end)
      gamecenter.login()
    elseif _leaderboard_root.curfilter == "all" then
      cloud.fetchGCLeaderboard()
    else
      cloud.fetchWeeklyGCLeaderboard()
    end
  end
  _enable_spinner(100)
  cloud.setLeaderboardCallback(_onLeaderboardFetched)
  cloud.setPostLeaderboardCallback(_onPostLeaderboard)
  profile.lastLeaderboardBtn = _leaderboard_root.curboard
  profile.lastLeaderboardFilterBtn = _leaderboard_root.curfilter
  profile:save()
end
function leaderboard_show(move)
  if move == nil then
    move = {empty = true}
  end
  local submenu_height = device.ui_height - 100 - 60 - 125
  local submenu_y = -80
  if #screenHistory > 0 then
    submenu_height = submenu_height - 90
    submenu_y = submenu_y + 45
  end
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local tabBar = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#storeFiltersBG.png"))
  if not profile.excludeAds then
    tabBar:setLoc(0, device.ui_height / 2 - 280)
  else
    tabBar:setLoc(0, device.ui_height / 2 - 180)
  end
  tabBar:setPriority(-2)
  local btnGroup = tabBar:add(ui.Group.new())
  btnGroup:setLoc(0, -16)
  local btnLoc = 70
  local allScoresBtn = btnGroup:add(ui.Button.new("menuTemplateShared.atlas.png#navTabSmall.png"))
  allScoresBtn:setLoc(-device.ui_width / 2 + btnLoc, 3)
  allScoresBtn.board = "top"
  allScoresBtn.handleTouch = Button_handleTouch
  allScoresBtn.onClick = _leaderboardFilter_onClick
  allScoresBtn._up:setPriority(-1)
  allScoresBtn._down:setPriority(-1)
  allScoresBtnGroup = allScoresBtn:add(ui.new(MOAIProp2D.new()))
  allScoresBtn._up:setColor(unpack(LB_FADE_VAL_TABLE))
  allScoresBtn._down:setColor(1, 1, 1, 1)
  allScoresBtnGroup:setColor(unpack(LB_FADE_VAL_TABLE))
  btnLoc = btnLoc + 140
  local allScoresText = allScoresBtnGroup:add(ui.TextBox.new(_("Top Players"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  allScoresText:setLoc(0, -2)
  local fbScoresBtn = btnGroup:add(ui.Button.new("menuTemplateShared.atlas.png#navTabSmall.png"))
  fbScoresBtn:setLoc(-device.ui_width / 2 + btnLoc, 3)
  fbScoresBtn.board = "fb"
  fbScoresBtn.handleTouch = Button_handleTouch
  fbScoresBtn.onClick = _leaderboardFilter_onClick
  fbScoresBtn._up:setPriority(-1)
  fbScoresBtn._down:setPriority(-1)
  fbScoresBtnGroup = fbScoresBtn:add(ui.new(MOAIProp2D.new()))
  fbScoresBtn._up:setColor(unpack(LB_FADE_VAL_TABLE))
  fbScoresBtn._down:setColor(1, 1, 1, 1)
  fbScoresBtnGroup:setColor(unpack(LB_FADE_VAL_TABLE))
  btnLoc = btnLoc + 140
  local fbIcn = fbScoresBtnGroup:add(ui.Image.new("menuTemplateShared.atlas.png#iconFacebookMed.png"))
  fbIcn:setLoc(-35, 0)
  local fbScoresTxt = fbScoresBtnGroup:add(ui.TextBox.new(_("Friends"), FONT_SMALL_BOLD, "ffffff", "left", nil, nil, true))
  fbScoresTxt:setLoc(18, -2)
  local gcScoresBtn
  if device.os == device.OS_IOS then
    gcScoresBtn = btnGroup:add(ui.Button.new("menuTemplateShared.atlas.png#navTabSmall.png"))
    gcScoresBtn:setLoc(-device.ui_width / 2 + btnLoc, 3)
    gcScoresBtn.board = "gc"
    gcScoresBtn.handleTouch = Button_handleTouch
    gcScoresBtn.onClick = _leaderboardFilter_onClick
    gcScoresBtn._up:setPriority(-1)
    gcScoresBtn._down:setPriority(-1)
    gcScoresBtnGroup = gcScoresBtn:add(ui.new(MOAIProp2D.new()))
    gcScoresBtn._up:setColor(unpack(LB_FADE_VAL_TABLE))
    gcScoresBtn._down:setColor(1, 1, 1, 1)
    gcScoresBtnGroup:setColor(unpack(LB_FADE_VAL_TABLE))
    local gcIcn = gcScoresBtnGroup:add(ui.Image.new("menuTemplateShared.atlas.png#iconGameCenterMed.png"))
    gcIcn:setLoc(-35, 0)
    local gcScoresTxt = gcScoresBtnGroup:add(ui.TextBox.new(_("Friends"), FONT_SMALL_BOLD, "ffffff", "left", nil, nil, true))
    gcScoresTxt:setLoc(18, -2)
  end
  local allTimeMenuBtn = btnGroup:add(ui.Button.new("menuTemplateShared.atlas.png#toggleSide.png"))
  allTimeMenuBtn:setLoc(device.ui_width / 2 - 50, 4)
  allTimeMenuBtn._up:setPriority(-1)
  allTimeMenuBtn._down:setPriority(-1)
  allTimeMenuBtn.handleTouch = Button_handleTouch
  allTimeMenuBtn.onClick = _leaderboardFilter_onClick
  allTimeMenuBtn.filter = "all"
  allTimeMenuBtnGroup = allTimeMenuBtn:add(ui.new(MOAIProp2D.new()))
  local allTimeMenuTxt = allTimeMenuBtnGroup:add(ui.TextBox.new(_("All-Time"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, false))
  allTimeMenuTxt:setLoc(0, -2)
  local wkMenuBtn = btnGroup:add(ui.Button.new("menuTemplateShared.atlas.png#toggleSide.png"))
  wkMenuBtn:setLoc(device.ui_width / 2 - 142, 4)
  wkMenuBtn:setScl(-1, 1)
  wkMenuBtn._up:setPriority(-1)
  wkMenuBtn._down:setPriority(-1)
  wkMenuBtn.handleTouch = Button_handleTouch
  wkMenuBtn.onClick = _leaderboardFilter_onClick
  wkMenuBtn.filter = "week"
  wkMenuBtnGroup = wkMenuBtn:add(ui.new(MOAIProp2D.new()))
  local wkMenuTxt = wkMenuBtnGroup:add(ui.TextBox.new(_("Week"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, false))
  wkMenuTxt:setScl(-1, 1)
  wkMenuTxt:setLoc(0, -2)
  _storemenu_show("leaderboard", true, nil, {
    store_menu = move.store_menu
  })
  local topBarBG = _menu_root:add(ui.Image.new("menuTopBars.atlas.png#topBarGalaxyMap.png"))
  if not profile.excludeAds then
    topBarBG:setLoc(0, device.ui_height / 2 - 150)
  else
    topBarBG:setLoc(0, device.ui_height / 2 - 50)
  end
  _menu_root.topBarBG = topBarBG
  local topBarBGPickBox = topBarBG:add(ui.PickBox.new(device.ui_width, 100))
  local topBarText = topBarBG:add(ui.TextBox.new(_("Leaderboards"), FONT_XLARGE, "ffffff", "center", nil, nil, true))
  topBarText:setLoc(0, -6)
  local backBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconBack.png"))
  backBtn._down:setColor(0.5, 0.5, 0.5)
  backBtn:setLoc(-device.ui_width / 2 + 42, 0)
  backBtn.handleTouch = Button_handleTouch
  local function backBtn_onClick()
    if not screenAction:isActive() then
      if #screenHistory > 0 then
        leaderboard_close({back = true})
        do
          local screen = table_remove(screenHistory)
          if screen == "victory" then
            victory_show({back = true})
          elseif screen == "defeat" then
            defeat_show({back = true})
          elseif screen == "galaxymap" then
            galaxymap_show({back = true})
          end
        end
      else
        menu_close()
        mainmenu_show()
      end
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  backBtn.onClick = backBtn_onClick
  if device.os == device.OS_ANDROID then
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, function()
      backBtn_onClick()
      return true
    end)
  end
  if #screenHistory > 0 then
    local menuBtn = topBarBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconHome.png"))
    menuBtn._down:setColor(0.5, 0.5, 0.5)
    menuBtn:setLoc(device.ui_width / 2 - 42, 0)
    menuBtn.handleTouch = Button_handleTouch
    function menuBtn:onClick()
      menu_close()
      mainmenu_show()
      soundmanager.onSFX("onPageSwipeBack")
    end
  end
  _leaderboard_root = ui.Group.new()
  _leaderboard_root.tabBar = tabBar
  _leaderboard_root.topBtn = allScoresBtn
  _leaderboard_root.topBtnGrp = allScoresBtnGroup
  _leaderboard_root.fbBtn = fbScoresBtn
  _leaderboard_root.fbBtnGrp = fbScoresBtnGroup
  _leaderboard_root.gcBtn = gcScoresBtn
  _leaderboard_root.gcBtnGrp = gcScoresBtnGroup
  _leaderboard_root.allBtn = allTimeMenuBtn
  _leaderboard_root.allBtnGrp = allTimeMenuBtnGroup
  _leaderboard_root.weeklyBtn = wkMenuBtn
  _leaderboard_root.weeklyBtnGrp = wkMenuBtnGroup
  local bg = _leaderboard_root:add(ui.PickBox.new(device.ui_width, submenu_height))
  bg:setLoc(0, submenu_y)
  bg.handleTouch = _leaderboard_items_handleTouch
  local items_group = _leaderboard_root:add(ui.Group.new())
  bg.items_group = items_group
  _leaderboard_root.bg = bg
  if move.forward then
    _leaderboard_root:setLoc(device.ui_width * 2, 0)
    _leaderboard_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  elseif move.back then
    _leaderboard_root:setLoc(-device.ui_width * 2, 0)
    _leaderboard_root:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  end
  if move.bottom_bar then
    _leaderboard_root.bottom_bar = true
  end
  if #screenHistory > 0 and screenHistory[#screenHistory] ~= "galaxymap" then
    do
      local bottomNavBG = _menu_root:add(ui.Image.new("menuTemplate2.atlas.png#bottomNavBG.png"))
      if move.bottom_bar then
        bottomNavBG:setLoc(0, -device.ui_height / 2 - 120)
        bottomNavBG:seekLoc(0, -device.ui_height / 2 - 8, 0.5, MOAIEaseType.EASE_IN)
      else
        bottomNavBG:setLoc(0, -device.ui_height / 2 - 8)
      end
      _menu_root.bottomNavBG = bottomNavBG
      local bottomNavBGPickBox = bottomNavBG:add(ui.PickBox.new(device.ui_width, 230))
      bottomNavBGPickBox:setLoc(0, -20)
      local continueBtnGlow = bottomNavBG:add(ui.Image.new("menuTemplateShared.atlas.png#largeButtonGlow.png"))
      continueBtnGlow:setColor(0.25, 0.25, 0.25, 0)
      continueBtnGlow:setScl(0.995, 0.995)
      continueBtnGlow:setLoc(0, 45)
      _leaderboard_root.continueBtnGlowAction = uiAS:repeatcall(0.5, function()
        if continueBtnGlow.active then
          continueBtnGlow:seekColor(0.25, 0.25, 0.25, 0, 0.5, MOAIEaseType.EASE_IN)
          continueBtnGlow.active = nil
          continueBtnGlow.wait = true
        elseif continueBtnGlow.wait then
          continueBtnGlow.wait = nil
        else
          continueBtnGlow:seekColor(1, 1, 1, 0, 0.5, MOAIEaseType.EASE_IN)
          continueBtnGlow.active = true
        end
      end)
      local continueBtn = bottomNavBG:add(ui.Button.new("menuTemplateShared.atlas.png#largeButton.png"))
      continueBtn._down:setColor(0.5, 0.5, 0.5)
      continueBtn:setLoc(0, 50)
      local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      continueBtnText:setLoc(-15, 0)
      local continueBtnIcon = continueBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
      continueBtnIcon:setLoc(70, 0)
      local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Continue"), FONT_MEDIUM_BOLD, "ffffff", "center", nil, nil, true))
      continueBtnText:setLoc(-15, 0)
      local continueBtnIcon = continueBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconNext.png"))
      continueBtnIcon:setLoc(70, 0)
      continueBtn.handleTouch = Button_handleTouch
      function continueBtn:onClick()
        if not screenAction:isActive() then
          table_insert(screenHistory, "leaderboard")
          leaderboard_close({forward = true})
          achievements_show({forward = true})
          soundmanager.onSFX("onPageSwipeForward")
        end
      end
    end
  end
  if not move.empty then
    screenAction:setSpan(0.55)
    screenAction:start()
  end
  submenuLayer:add(_leaderboard_root)
  curScreen = "leaderboard"
  if profile.lastLeaderboardFilterBtn == "week" then
    _leaderboard_root.curfilter = "week"
  else
    _leaderboard_root.curfilter = "all"
  end
  if profile.lastLeaderboardBtn == "fb" then
    fbScoresBtn:onClick()
  elseif profile.lastLeaderboardBtn == "gc" then
    gcScoresBtn:onClick()
  else
    allScoresBtn:onClick()
  end
  _leaderboard_root.allBtn._up:setColor(unpack(LB_FADE_VAL_TABLE))
  _leaderboard_root.allBtn._down:setColor(1, 1, 1, 1)
  _leaderboard_root.weeklyBtn._up:setColor(unpack(LB_FADE_VAL_TABLE))
  _leaderboard_root.weeklyBtn._down:setColor(1, 1, 1, 1)
  _leaderboard_root.allBtnGrp:setColor(unpack(UI_COLOR_GRAY_DARKEN))
  _leaderboard_root.weeklyBtnGrp:setColor(unpack(UI_COLOR_GRAY_DARKEN))
  if _leaderboard_root.curfilter == "all" then
    _leaderboard_root.allBtn._up:setColor(1, 1, 1, 1)
  elseif _leaderboard_root.curfilter == "week" then
    _leaderboard_root.weeklyBtn._up:setColor(1, 1, 1, 1)
  end
end
function menu_close()
  if curScreen == "victory" then
    victory_close()
  elseif curScreen == "defeat" then
    defeat_close()
  elseif curScreen == "achievements" then
    achievements_close()
  elseif curScreen == "galaxymap" then
    galaxymap_close()
  elseif curScreen == "fleet" then
    fleet_close()
  elseif curScreen == "shippurchase" then
    shippurchase_close()
  elseif curScreen == "shipupgrade" then
    shipupgrade_close()
  elseif curScreen == "starbank" then
    starbank_close()
  elseif curScreen == "perks" then
    perks_close()
  elseif curScreen == "leaderboard" then
    leaderboard_close()
  end
  screenHistory = {}
  if _menu_root.callback then
    _menu_root.callback()
  end
  if not profile.excludeAds and SixWaves then
    SixWaves.hideAdBanner()
  end
  uiLayer:remove(_menu_root.bg)
  menuLayer:remove(_menu_root)
  _menu_root = nil
  if levelUI then
    levelUI:setLoc(0, 0)
  end
  mothershipLayer:setCamera(camera)
  mainLayer:setCamera(camera)
  hudLayer:setCamera(camera)
  bucket.pop()
  bucket.release("MENU")
  bucket.release("POPUPS")
end
function menu_show(screen, callback)
  bucket.push("MENU")
  if levelUI then
    levelUI:setLoc(OFFSCREEN_LOC, OFFSCREEN_LOC)
  end
  mothershipLayer:setCamera(offscreen)
  mainLayer:setCamera(offscreen)
  hudLayer:setCamera(offscreen)
  local submenu_height = device.ui_height - 100
  local submenu_y = -50
  if not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  _menu_root = menuLayer:add(ui.Group.new())
  _menu_root.callback = callback
  local bg = uiLayer:add(ui.PickBox.new(device.ui_width, device.ui_height))
  function bg.handleTouch()
    return true
  end
  _menu_root.bg = bg
  local menuBG = bg:add(ui.Image.new("menuTemplate.atlas.png#menuBG.png"))
  menuBG:setScl(2, 2)
  menuBG:setLoc(0, submenu_height / 2 + submenu_y - 449)
  if not profile.excludeAds then
    local adBG = _menu_root:add(ui.PickBox.new(device.width, 100, "000000"))
    adBG:setLoc(0, device.ui_height / 2 - 50)
    if SixWaves then
      SixWaves.showAdBanner()
    else
      local ad = _menu_root:add(ui.Image.new("menuPlaceholders.atlas.png#adMockup.png"))
      ad:setLoc(0, device.ui_height / 2 - 50)
      _menu_root.ad = ad
    end
  end
  local screenStr, queryStr = breakstr(screen, "?")
  menuMode = nil
  if queryStr ~= nil then
    local q = url.parse_query(queryStr)
    if q.mode ~= nil then
      menuMode = q.mode
    end
  end
  curGameMode = gameMode
  if screenStr == "victory" then
    victory_show({animate = true})
  elseif screenStr == "defeat" then
    defeat_show({animate = true})
  elseif screenStr == "achievements" then
    achievements_show()
  elseif screenStr == "galaxymap" then
    galaxymap_show({bottom_bar = true, store_menu = true})
  elseif screenStr == "fleet" then
    fleet_show({
      bottom_bar = true,
      store_menu = true,
      store_filter = true
    })
  elseif screenStr == "starbank" then
    do
      local filter
      local fromPopup = true
      if queryStr ~= nil then
        local q = url.parse_query(queryStr)
        if q.filter ~= nil then
          filter = q.filter
        end
        if q.refresh ~= nil then
          fromPopup = nil
        end
      end
      starbank_show({store_menu = true}, filter, fromPopup)
    end
  elseif screenStr == "perks" then
    perks_show({
      bottom_bar = true,
      store_menu = true,
      perks_bar = true
    })
  elseif screenStr == "leaderboard" then
    leaderboard_show()
  end
end
local function _mainmenu_settings_close()
  local settingsBG = _mainmenu_root.settingsBG
  local soundBtn = settingsBG.soundBtn
  local musicBtn = settingsBG.musicBtn
  local gamecenterBtn = settingsBG.gamecenterBtn
  local facebookBtn = settingsBG.facebookBtn
  local settingsBtn = _mainmenu_root.settingsBtn
  settingsBtn._up:setColor(1, 1, 1, 1)
  settingsBtn._down:setColor(0.5, 0.5, 0.5, 1)
  settingsBtn:seekRot(0, 0.5, MOAIEaseType.EASE_IN)
  settingsBG:seekScl(1, 0, 0.5, MOAIEaseType.EASE_IN)
  settingsBG:moveLoc(0, -155 - abs(settingsBG.offset or 0), 0.5, MOAIEaseType.EASE_IN)
  soundBtn._up:seekColor(0, 0, 0, 0, 0.25, MOAIEaseType.EASE_IN)
  musicBtn._up:seekColor(0, 0, 0, 0, 0.25, MOAIEaseType.EASE_IN)
  if gamecenterBtn ~= nil then
    gamecenterBtn._up:seekColor(0, 0, 0, 0, 0.25, MOAIEaseType.EASE_IN)
  end
  if facebookBtn ~= nil then
    facebookBtn._up:seekColor(0, 0, 0, 0, 0.25, MOAIEaseType.EASE_IN)
  end
  screenAction:setSpan(0.55)
  screenAction:start()
  settingsBtn.active = nil
end
local function _mainmenu_settings_show()
  local settingsBG = _mainmenu_root.settingsBG
  local soundBtn = settingsBG.soundBtn
  local musicBtn = settingsBG.musicBtn
  local gamecenterBtn = settingsBG.gamecenterBtn
  local facebookBtn = settingsBG.facebookBtn
  local settingsBtn = _mainmenu_root.settingsBtn
  settingsBtn._up:setColor(unpack(UI_COLOR_GOLD))
  settingsBtn._down:setColor(unpack(UI_COLOR_GOLD_DARKEN))
  settingsBtn:seekRot(-146, 0.5, MOAIEaseType.EASE_IN)
  settingsBG:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN)
  settingsBG:moveLoc(0, 155 + abs(settingsBG.offset or 0), 0.5, MOAIEaseType.EASE_IN)
  if profile.sound then
    soundBtn._up:setColor(0, 0, 0, 0)
    soundBtn._up:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
  else
    soundBtn._up:setColor(0, 0, 0, 0)
    soundBtn._up:seekColor(0.5, 0.5, 0.5, 1, 0.5, MOAIEaseType.EASE_IN)
  end
  if profile.music then
    musicBtn._up:setColor(0, 0, 0, 0)
    musicBtn._up:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
  else
    musicBtn._up:setColor(0, 0, 0, 0)
    musicBtn._up:seekColor(0.5, 0.5, 0.5, 1, 0.5, MOAIEaseType.EASE_IN)
  end
  if gamecenterBtn ~= nil then
    if gamecenter.isLoggedIn() then
      if gamecenterBtn.off then
        gamecenterBtn._up:remove(gamecenterBtn._up.off)
        gamecenterBtn._down:remove(gamecenterBtn._down.off)
        gamecenterBtn.off = nil
      end
      function gamecenterBtn.onClick()
        gamecenter.openGC()
      end
    else
      if not gamecenterBtn.off then
        gamecenterBtn._up.off = gamecenterBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
        gamecenterBtn._down.off = gamecenterBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
        gamecenterBtn.off = true
      end
      function gamecenterBtn.onClick()
        gamecenter.login()
      end
    end
    gamecenterBtn._up:setColor(0, 0, 0, 0)
    gamecenterBtn._up:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
  end
  if facebookBtn ~= nil then
    if fb.isLoggedIn() then
      if facebookBtn.off then
        facebookBtn._up:remove(facebookBtn._up.off)
        facebookBtn._down:remove(facebookBtn._down.off)
        facebookBtn.off = nil
      end
      function facebookBtn.onClick()
        PromptUserForFacebookLogout()
      end
    else
      if not facebookBtn.off then
        facebookBtn._up.off = facebookBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
        facebookBtn._down.off = facebookBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
        facebookBtn.off = true
      end
      function facebookBtn.onClick()
        fb.setListener(function(event, data)
          if event == fb.EVENT_FRIENDSLIST_READY then
            cloud.mapFacebookAccount()
          end
        end)
        fb.login()
      end
    end
    facebookBtn._up:setColor(0, 0, 0, 0)
    facebookBtn._up:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.EASE_IN)
  end
  screenAction:setSpan(0.55)
  screenAction:start()
  settingsBtn.active = true
end
local function _mainmenu_appInfo_close()
  _mainmenu_root.appInfo:remove()
  _mainmenu_root.appInfo = nil
end
local function _mainmenu_appInfo_show()
  local text
  local appInfo = _mainmenu_root:add(ui.Group.new())
  _mainmenu_root.appInfo = appInfo
  local appInfoBG = appInfo:add(ui.PickBox.new(device.ui_width, device.ui_height, color.toHex(0.178824, 0.178824, 0.178824, 0.8)))
  function appInfoBG.handleTouch()
    return true
  end
  local versionBox = appInfo:add(ui.NinePatch.new("boxHeaderOnly9p.lua", device.ui_width - 40, 160))
  local userIDLabel = versionBox:add(ui.TextBox.new(_("ID:"), FONT_SMALL_BOLD, "ffffff", "left", device.ui_width - 80, nil, true))
  userIDLabel:setLoc(0, 30)
  text = "" .. device.udid
  text = forceStringBreak(text, FONT_SMALL_BOLD, device.ui_width - 80 - 150)
  text = text:sub(1, text:len() - 1)
  local userIDText = versionBox:add(ui.TextBox.new(text, FONT_SMALL_BOLD, "ffffff", "right", device.ui_width - 80 - 150, nil, true))
  userIDText:setLoc(75, 30)
  local versionAppLabel = versionBox:add(ui.TextBox.new(_("App Version:"), FONT_SMALL_BOLD, "ffffff", "left", device.ui_width - 80, nil, true))
  versionAppLabel:setLoc(0, -10)
  text = "" .. VERSION
  text = forceStringBreak(text, FONT_SMALL_BOLD, device.ui_width - 80 - 150)
  text = text:sub(1, text:len() - 1)
  local versionAppText = versionBox:add(ui.TextBox.new(text, FONT_SMALL_BOLD, "ffffff", "right", device.ui_width - 80 - 150, nil, true))
  versionAppText:setLoc(75, -10)
  local versionACULabel = versionBox:add(ui.TextBox.new(_("Data Version:"), FONT_SMALL_BOLD, "ffffff", "left", device.ui_width - 80, nil, true))
  versionACULabel:setLoc(0, -50)
  text = "" .. string.format("%s", update.debugStatus())
  text = forceStringBreak(text, FONT_SMALL_BOLD, device.ui_width - 80 - 150)
  text = text:sub(1, text:len() - 1)
  local versionACUText = versionBox:add(ui.TextBox.new(text, FONT_SMALL_BOLD, "ffffff", "right", device.ui_width - 80 - 150, nil, true))
  versionACUText:setLoc(75, -50)
  if DISPLAY_DEBUG_INFO then
    local resLabel = versionBox:add(ui.TextBox.new(_("Res Type:"), FONT_SMALL_BOLD, "ffffff", "left", device.ui_width - 80, nil, true))
    resLabel:setLoc(0, -75)
    text = string.format("%s (%d x %d)", device.ui_assetrez, device.height, device.width)
    local resText = versionBox:add(ui.TextBox.new(text, FONT_SMALL_BOLD, "ffffff", "right", device.ui_width - 80 - 150, nil, true))
    resText:setLoc(75, -75)
  end
  local closeBtn = versionBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconClose.png"))
  closeBtn._down:setColor(0.5, 0.5, 0.5)
  closeBtn:setLoc((device.ui_width - 40) / 2 - 4, 76)
  closeBtn.handleTouch = Button_handleTouch
  function closeBtn.onClick()
    _mainmenu_appInfo_close()
  end
end
local function _mainmenu_about_close()
  _mainmenu_root.about.action:stop()
  _mainmenu_root.about.action = nil
  _mainmenu_root.about:remove()
  _mainmenu_root.about = nil
  creditsLayer:clear()
  if SixWaves then
    SixWaves.showCrossSellBtn()
  end
end
local function _mainmenu_about_show()
  if _mainmenu_root.settingsBtn.active then
    _mainmenu_settings_close()
  end
  local about = _mainmenu_root:add(ui.Group.new())
  _mainmenu_root.about = about
  local aboutBG = about:add(ui.PickBox.new(device.ui_width, device.ui_height, color.toHex(0.178824, 0.178824, 0.178824, 0.8)))
  function aboutBG.handleTouch()
    return true
  end
  local aboutBtn = about:add(ui.Button.new("menuTemplateShared.atlas.png#iconAbout.png"))
  aboutBtn._up:setColor(unpack(UI_COLOR_GOLD))
  aboutBtn._down:setColor(unpack(UI_COLOR_GOLD_DARKEN))
  aboutBtn:setLoc(device.ui_width / 2 - 55, -device.ui_height / 2 + 56)
  aboutBtn.handleTouch = Button_handleTouch
  function aboutBtn:onClick()
    _mainmenu_about_close()
  end
  local aboutBox = about:add(ui.NinePatch.new("boxAboutPage9p.lua", 598, 826))
  aboutBox:setLoc(0, device.ui_height / 2 - (device.ui_height - 110) / 2)
  local hbsLogo = aboutBox:add(ui.Image.new("menuMain.atlas.png#hbsLogo.png"))
  hbsLogo:setLoc(0, 260)
  local websiteBtn = aboutBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconWebsite.png"))
  websiteBtn._down:setColor(0.5, 0.5, 0.5)
  websiteBtn:setLoc(-230, 150)
  local websiteText = websiteBtn._up:add(ui.TextBox.new(_("Website"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  websiteText:setLoc(0, -45)
  local websiteText = websiteBtn._down:add(ui.TextBox.new(_("Website"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  websiteText:setLoc(0, -45)
  websiteBtn.handleTouch = Button_handleTouch
  function websiteBtn.onClick()
    MOAIApp.openURL("http://www.harebrained-schemes.com")
  end
  local facebookBtn = aboutBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconFacebook.png"))
  facebookBtn._down:setColor(0.5, 0.5, 0.5)
  facebookBtn:setLoc(230, 150)
  local facebookText = facebookBtn._up:add(ui.TextBox.new(_("Facebook"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  facebookText:setLoc(0, -45)
  local facebookText = facebookBtn._down:add(ui.TextBox.new(_("Facebook"), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
  facebookText:setLoc(0, -45)
  facebookBtn.handleTouch = Button_handleTouch
  function facebookBtn.onClick()
    MOAIApp.openURL("http://www.facebook.com/HarebrainedSchemes")
  end
  local credits = creditsLayer:add(ui.Group.new())
  local y = 0
  local creditsDef = require("credits")
  for i, v in ipairs(creditsDef) do
    if v.title ~= nil then
      local text = credits:add(ui.TextBox.new(_(v.title), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
      text:setColor(unpack(UI_CREDITS_TITLE_COLOR))
      text:setLoc(0, y)
    end
    if v.names ~= nil then
      if v.title ~= nil then
        y = y - 14
      end
      for j, w in ipairs(v.names) do
        local text = credits:add(ui.TextBox.new(_(w), FONT_MEDIUM, "ffffff", "center", 550, nil, true))
        text:setLoc(0, y - util.roundNumber(text._height / 2))
        y = y - util.roundNumber(text._height)
      end
    end
    if v.smallprint ~= nil then
      if v.title ~= nil then
        y = y - 14
      end
      if v.names ~= nil then
        y = y - 14
      end
      for j, w in ipairs(v.smallprint) do
        local text = credits:add(ui.TextBox.new(_(w), FONT_SMALL, "ffffff", "center", 550, nil, true))
        text:setLoc(0, y - util.roundNumber(text._height / 2))
        y = y - util.roundNumber(text._height)
      end
    end
    if v.image ~= nil then
      local image = credits:add(ui.Image.new(v.image))
      local width, height = image:getSize()
      local scl = image:getScl()
      image:setLoc(0, y - util.roundNumber(height / 2 * scl))
      y = y - util.roundNumber(height * scl)
    end
    y = y - 16
  end
  local seekY = 282
  about.action = uiAS:wrap(function(dt)
    if seekY > y - 250 then
      credits:setLoc(0, util.roundNumber(-seekY))
      seekY = seekY - dt * 64
    else
      seekY = 282
    end
  end)
  local appInfoBtn
  if device.os == device.OS_IOS then
    appInfoBtn = about:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
    appInfoBtn._up:setColor(unpack(UI_COLOR_YELLOW))
    appInfoBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
    appInfoBtn:setLoc(-230, -device.ui_height / 2 + 50)
    appInfoBtnText = appInfoBtn._up:add(ui.TextBox.new(_("App Info"), FONT_SMALL_BOLD, "ffffff", "center"))
    appInfoBtnText:setColor(0, 0, 0)
    appInfoBtnText = appInfoBtn._down:add(ui.TextBox.new(_("App Info"), FONT_SMALL_BOLD, "ffffff", "center"))
    appInfoBtnText:setColor(0, 0, 0)
    appInfoBtn.handleTouch = Button_handleTouch
    function appInfoBtn.onClick()
      _mainmenu_about_close()
      _mainmenu_appInfo_show()
    end
  else
    appInfoBtn = about:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
    appInfoBtn._up:setColor(unpack(UI_COLOR_YELLOW))
    appInfoBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
    appInfoBtn:setLoc(-160, -device.ui_height / 2 + 50)
    appInfoBtnText = appInfoBtn._up:add(ui.TextBox.new(_("App Info"), FONT_MEDIUM_BOLD, "ffffff", "center"))
    appInfoBtnText:setColor(0, 0, 0)
    appInfoBtnText = appInfoBtn._down:add(ui.TextBox.new(_("App Info"), FONT_MEDIUM_BOLD, "ffffff", "center"))
    appInfoBtnText:setColor(0, 0, 0)
    appInfoBtn.handleTouch = Button_handleTouch
    function appInfoBtn.onClick()
      _mainmenu_about_close()
      _mainmenu_appInfo_show()
    end
  end
  local restorePurchaseBtn
  if device.os == device.OS_IOS then
    restorePurchaseBtn = about:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
    restorePurchaseBtn._up:setColor(unpack(UI_COLOR_YELLOW))
    restorePurchaseBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
    restorePurchaseBtn:setLoc(-5, -device.ui_height / 2 + 50)
    restorePurchaseBtnText = restorePurchaseBtn._up:add(ui.TextBox.new(_("Restore Purchases"), FONT_SMALL_BOLD, "ffffff", "center"))
    restorePurchaseBtnText:setColor(0, 0, 0)
    restorePurchaseBtnText = restorePurchaseBtn._down:add(ui.TextBox.new(_("Restore Purchases"), FONT_SMALL_BOLD, "ffffff", "center"))
    restorePurchaseBtnText:setColor(0, 0, 0)
    restorePurchaseBtn.handleTouch = Button_handleTouch
    function restorePurchaseBtn.onClick()
      _mainmenu_about_close()
      _restore_purchases_show()
    end
  end
  if SixWaves then
    SixWaves.hideCrossSellBtn()
  end
end
function _restore_purchases_show()
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  local popup = ui.Group.new()
  local bg = popup:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
  bg:setLoc(0, submenu_y)
  function bg.handleTouch()
    return true
  end
  local popupWidth = 620
  local popupHeight = 312
  local popupBox = popup:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
  local t = RESTORE_PURCHASES_TEXT or "If you previously purchased \"Remove Ads\" on this device or another device with the same AppStore account, you may RESTORE the purchase by clicking the button below."
  local text = popupBox:add(ui.TextBox.new(t, FONT_SMALL, "ffffff", "center", 516, nil, true))
  text:setLoc(0, 44)
  local continueBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#doubleButton.png"))
  continueBtn._up:setColor(unpack(UI_COLOR_YELLOW))
  continueBtn._down:setColor(unpack(UI_COLOR_YELLOW_DARKEN))
  continueBtn:setLoc(80, -popupHeight / 2 + 70)
  local continueBtnText = continueBtn._up:add(ui.TextBox.new(_("Restore"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  local continueBtnText = continueBtn._down:add(ui.TextBox.new(_("Restore"), FONT_MEDIUM_BOLD, "000000", "center"))
  continueBtnText:setColor(0, 0, 0)
  continueBtnText:setLoc(0, -2)
  continueBtn.handleTouch = Button_handleTouch
  function continueBtn.onClick()
    _popup_close(popup)
    storeiap.restore(_starbank_shop_restore, function()
      MOAIApp.showDialog(_("Restore Complete"), _("Your items have been restored."), nil, nil, _("Okay"), false, nil)
    end)
    soundmanager.onSFX("onPageSwipeForward")
  end
  local cancelBtn = popupBox:add(ui.Button.new("menuTemplateShared.atlas.png#defaultButton.png"))
  cancelBtn._up:setColor(unpack(UI_COLOR_RED))
  cancelBtn._down:setColor(unpack(UI_COLOR_RED_DARKEN))
  cancelBtn:setLoc(-130, -popupHeight / 2 + 70)
  local cancelBtnText = cancelBtn._up:add(ui.TextBox.new(_("Cancel"), FONT_SMALL_BOLD, "000000", "center"))
  cancelBtnText:setColor(0, 0, 0)
  cancelBtnText:setLoc(0, -2)
  local cancelBtnText = cancelBtn._down:add(ui.TextBox.new(_("Cancel"), FONT_SMALL_BOLD, "000000", "center"))
  cancelBtnText:setColor(0, 0, 0)
  cancelBtnText:setLoc(0, -2)
  cancelBtn.handleTouch = Button_handleTouch
  function cancelBtn.onClick()
    _popup_close(popup)
  end
  popups.insert_queue(popup)
  popups.check_queue()
  bucket.pop()
end
function mainmenu_close()
  if SixWaves then
    SixWaves.hideCrossSellBtn()
  end
  _mainmenu_root.playBtnGlowAction:stop()
  _mainmenu_root.playBtnGlowAction = nil
  uiLayer:remove(_mainmenu_root.bg)
  menuLayer:remove(_mainmenu_root)
  _mainmenu_root = nil
end
function mainmenu_active()
  return _mainmenu_root ~= nil and _mainmenu_root._uilayer ~= nil
end
function mainmenu_show()
  update.check()
  update.spinnerSetLoc(device.ui_width / 2 - 32, device.ui_height / 2 - 90)
  cloud.checkForUserDataUpdates()
  _mainmenu_root = ui.Group.new()
  menuLayer:add(_mainmenu_root)
  local bg = uiLayer:add(ui.PickBox.new(device.ui_width, device.ui_height))
  function bg.handleTouch()
    return true
  end
  _mainmenu_root.bg = bg
  local mainMenuBG = _mainmenu_root:add(ui.Image.new("menuMainBG.png"))
  local mainMenuLogo = _mainmenu_root:add(ui.Image.new("menuMain.atlas.png#mainMenuLogo.png"))
  mainMenuLogo:setLoc(0, device.ui_height / 2 - 110)
  local playBtn = _mainmenu_root:add(ui.Button.new("menuMain.atlas.png#playButton.png"))
  playBtn._down:setColor(0.5, 0.5, 0.5)
  playBtn._down:setScl(0.95, 0.95)
  playBtn:setLoc(0, -device.ui_height / 2 + 190)
  playBtn.handleTouch = Button_handleTouch
  function playBtn.onClick()
    local lastCompletedGalaxy, lastCompletedSystem = _get_last_completed_galaxy_system()
    if lastCompletedGalaxy == 1 and lastCompletedSystem == 0 then
      mainmenu_close()
      level_run(1, 1)
    else
      mainmenu_close()
      menu_show("galaxymap")
    end
    soundmanager.onSFX("onPageSwipeForward")
  end
  local playBtnGlow = playBtn:add(ui.Image.new("menuMain.atlas.png#playButtonGlow.png"))
  playBtnGlow:setColor(0.25, 0.25, 0.25, 0)
  _mainmenu_root.playBtnGlowAction = uiAS:repeatcall(0.5, function()
    if playBtnGlow.active then
      playBtnGlow:seekColor(0.25, 0.25, 0.25, 0, 0.5, MOAIEaseType.EASE_IN)
      playBtnGlow:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN)
      playBtnGlow.active = nil
      playBtnGlow.wait = true
    elseif playBtnGlow.wait then
      playBtnGlow.wait = nil
    else
      playBtnGlow:seekColor(1, 1, 1, 0, 0.5, MOAIEaseType.EASE_IN)
      playBtnGlow:seekScl(1.025, 1.025, 0.5, MOAIEaseType.EASE_IN)
      playBtnGlow.active = true
    end
  end)
  local settingsBG
  local offset = 0
  if device.os == device.OS_IOS then
    settingsBG = _mainmenu_root:add(ui.NinePatch.new("glassyBoxPlain9p.lua", 80, 400))
    settingsBG:setLoc(-device.ui_width / 2 + 55, -device.ui_height / 2 + 55)
    offset = -45
    settingsBG.offset = offset
  else
    settingsBG = _mainmenu_root:add(ui.NinePatch.new("glassyBoxPlain9p.lua", 80, 310))
    settingsBG:setLoc(-device.ui_width / 2 + 55, -device.ui_height / 2 + 55)
  end
  settingsBG:setScl(1, 0)
  _mainmenu_root.settingsBG = settingsBG
  if profile.sound then
    do
      local soundBtn = settingsBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconSound.png"))
      soundBtn._up:setColor(1, 1, 1)
      soundBtn._down:setColor(0.5, 0.5, 0.5)
      soundBtn:setLoc(0, 25 + offset)
      soundBtn.handleTouch = Button_handleTouch
      soundBtn.onClick = _soundBtn_active_onClick
      settingsBG.soundBtn = soundBtn
    end
  else
    local soundBtn = settingsBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconSound.png"))
    soundBtn._up:setColor(0.5, 0.5, 0.5)
    soundBtn._down:setColor(1, 1, 1)
    soundBtn:setLoc(0, 25 + offset)
    soundBtn.handleTouch = Button_handleTouch
    soundBtn.onClick = _soundBtn_inactive_onClick
    soundBtn.iconOff = soundBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
    soundBtn.iconOff:setColor(2, 2, 2)
    settingsBG.soundBtn = soundBtn
  end
  if profile.music then
    do
      local musicBtn = settingsBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconMusic.png"))
      musicBtn._up:setColor(1, 1, 1)
      musicBtn._down:setColor(0.5, 0.5, 0.5)
      musicBtn:setLoc(0, -60 + offset)
      musicBtn.handleTouch = Button_handleTouch
      musicBtn.onClick = _musicBtn_active_onClick
      settingsBG.musicBtn = musicBtn
    end
  else
    local musicBtn = settingsBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconMusic.png"))
    musicBtn._up:setColor(0.5, 0.5, 0.5)
    musicBtn._down:setColor(1, 1, 1)
    musicBtn:setLoc(0, -60 + offset)
    musicBtn.handleTouch = Button_handleTouch
    musicBtn.onClick = _musicBtn_inactive_onClick
    musicBtn.iconOff = musicBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
    musicBtn.iconOff:setColor(2, 2, 2)
    settingsBG.musicBtn = musicBtn
  end
  if device.os == device.OS_IOS then
    local gamecenterBtn = settingsBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconGameCenter.png"))
    gamecenterBtn._down:setColor(0.5, 0.5, 0.5)
    gamecenterBtn:setLoc(0, 115 + offset)
    gamecenterBtn.handleTouch = Button_handleTouch
    settingsBG.gamecenterBtn = gamecenterBtn
  end
  if device.os == device.OS_IOS or device.os == device.OS_ANDROID then
    local facebookBtn = settingsBG:add(ui.Button.new("menuTemplateShared.atlas.png#iconFacebook.png"))
    facebookBtn._down:setColor(0.5, 0.5, 0.5)
    if device.os == device.OS_ANDROID then
      facebookBtn:setLoc(0, 115)
    else
      facebookBtn:setLoc(0, 205 + offset)
    end
    facebookBtn.handleTouch = Button_handleTouch
    settingsBG.facebookBtn = facebookBtn
  end
  local settingsBtn = _mainmenu_root:add(ui.Button.new("menuTemplateShared.atlas.png#iconSettings.png"))
  settingsBtn._down:setColor(0.5, 0.5, 0.5)
  settingsBtn:setLoc(-device.ui_width / 2 + 55, -device.ui_height / 2 + 50)
  settingsBtn.handleTouch = Button_handleTouch
  function settingsBtn:onClick()
    if not screenAction:isActive() then
      if self.active then
        _mainmenu_settings_close()
      else
        _mainmenu_settings_show()
      end
    end
  end
  _mainmenu_root.settingsBtn = settingsBtn
  local helpBtnBox = _mainmenu_root:add(ui.NinePatch.new("glassyBoxPlain9p.lua", 88, 82))
  helpBtnBox:setLoc(-92, -device.ui_height / 2 + 50)
  local helpBtn = helpBtnBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconHelp.png"))
  helpBtn._down:setColor(0.5, 0.5, 0.5)
  helpBtn:setLoc(0, 0)
  helpBtn.handleTouch = Button_handleTouch
  function helpBtn.onClick()
    _popup_tutorial_show()
  end
  if device.platform ~= device.PLATFORM_ANDROID_AMAZON then
    local moreGamesBtnBox = _mainmenu_root:add(ui.NinePatch.new("glassyBoxPlain9p.lua", 88, 82))
    moreGamesBtnBox:setLoc(0, -device.ui_height / 2 + 50)
    local moreGamesBtn = moreGamesBtnBox:add(ui.Button.new(ui.PickBox.new(96, 96), ui.PickBox.new(96, 96)))
    moreGamesBtn._up.handleTouch = nil
    moreGamesBtn._down.handleTouch = nil
    local moreGamesBtnText = moreGamesBtn._up:add(ui.TextBox.new(_("MORE GAMES"), FONT_SMALL_BOLD, "ffffff", "center", 96, 96, true))
    moreGamesBtnText:setLoc(0, -26)
    local moreGamesBtnText = moreGamesBtn._down:add(ui.TextBox.new(_("MORE GAMES"), FONT_SMALL_BOLD, "ffffff", "center", 96, 96, true))
    moreGamesBtnText:setColor(0.5, 0.5, 0.5)
    moreGamesBtnText:setLoc(0, -26)
    moreGamesBtn.handleTouch = Button_handleTouch
    function moreGamesBtn.onClick()
      if SixWaves then
        SixWaves.crossSell()
      end
    end
  end
  local achievementsBtnBox = _mainmenu_root:add(ui.NinePatch.new("glassyBoxPlain9p.lua", 88, 82))
  achievementsBtnBox:setLoc(92, -device.ui_height / 2 + 50)
  local achievementsBtn = achievementsBtnBox:add(ui.Button.new("menuTemplateShared.atlas.png#iconAchievements.png"))
  achievementsBtn._down:setColor(0.5, 0.5, 0.5)
  achievementsBtn:setLoc(0, 0)
  achievementsBtn.handleTouch = Button_handleTouch
  function achievementsBtn.onClick()
    mainmenu_close()
    menu_show("achievements")
  end
  local aboutBtn = _mainmenu_root:add(ui.Button.new("menuTemplateShared.atlas.png#iconAbout.png"))
  aboutBtn._down:setColor(0.5, 0.5, 0.5)
  aboutBtn:setLoc(device.ui_width / 2 - 55, -device.ui_height / 2 + 56)
  aboutBtn.handleTouch = Button_handleTouch
  function aboutBtn.onClick()
    _mainmenu_about_show()
  end
  if device.platform == device.PLATFORM_ANDROID_AMAZON then
    helpBtnBox:addLoc(44, 0)
    achievementsBtnBox:addLoc(-44, 0)
  end
  if device.os == device.OS_ANDROID then
    android_back_button_queue = {}
    android_pause_queue = {}
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, nil)
    MOAIApp.setListener(MOAIApp.ON_PAUSE_CALLED, nil)
  end
  if device.os == device.OS_IOS then
    gamecenter.setLoginFailedCallback(PromptUserGCLoginFailed)
    gamecenter.autologin()
  end
  if SixWaves then
    SixWaves.showCrossSellBtn()
  end
  if device.os == device.OS_IOS and SixWaves and not profile.excludeAds then
    local forcexsell = false
    if not profile.iosxselltime then
      profile.iosxselldate = os.date("%x")
      profile.iosxselltime = os.date("%X")
      profile:save()
    else
      local hour, minute, second = profile.iosxselltime:match("^(%d+):(%d+):(%d+)$")
      local prevtime = tonumber(hour) * 3600 + tonumber(minute) * 60 + tonumber(second)
      hour, minute, second = os.date("%X"):match("^(%d+):(%d+):(%d+)$")
      local nowtime = tonumber(hour) * 3600 + tonumber(minute) * 60 + tonumber(second)
      local months, days, years = profile.iosxselldate:match("^(%d+)/(%d+)/(%d+)$")
      local cM, cD, cY = os.date("%x"):match("^(%d+)/(%d+)/(%d+)$")
      local DAY_TIME_HOURS = 86400
      local MONTH_TIME_HOURS = DAY_TIME_HOURS * 30
      local YEAR_TIME_HOURS = MONTH_TIME_HOURS * 12
      nowtime = nowtime + (cM - months) * MONTH_TIME_HOURS + (cD - days) * DAY_TIME_HOURS + (cY - years) * YEAR_TIME_HOURS
      local wait_hours = XSELL_WAIT_HOURS or 12
      local wait_minutes = XSELL_WAIT_MINUTES or 0
      local wait_seconds = XSELL_WAIT_SECONDS or 0
      local dailyHours = wait_hours * 3600 + wait_minutes * 60 + wait_seconds
      if dailyHours <= nowtime - prevtime then
        forcexsell = true
      end
    end
    if forcexsell then
      profile.iosxselldate = os.date("%x")
      profile.iosxselltime = os.date("%X")
      profile:save()
      SixWaves.crossSell()
    end
  end
end
function VersionCheck(version)
  if version == nil or version == VERSION then
    return
  end
  if profile.lastVersionAnnounced ~= version then
    profile.lastVersionAnnounced = version
    profile:save()
    if not MOAIApp or not MOAIApp.showDialog then
      return
    end
    MOAIApp.showDialog(_("New Version!"), _("There is a new version of this game available for download. Would you like to get it?"), _("Download It!"), nil, _("No Thanks"), false, function(idx)
      if idx == MOAIApp.DIALOG_RESULT_POSITIVE then
        MOAIApp.openURL(device.storeURL)
      end
    end)
  end
end
function UserDataGift(gift)
  if not MOAIApp or not MOAIApp.showDialog then
    return
  end
  local curText
  if gift.cur == "creds" then
    curText = _("MegaCreds")
  elseif gift.cur == "alloy" then
    curText = _("Alloy")
  else
    return
  end
  MOAIApp.showDialog(_("Gift"), string.format(_("You have received a gift of %s %s!"), tostring(gift.amt), curText), nil, nil, _("Dismiss"), false)
end
_androidRateCheck = nil
_isRateResponse = nil
_rateResponse = false
function _androidRateCheckFunc()
  if _isRateResponse then
    _debug("RATE RESPONSE")
    if _rateResponse == MOAIApp.DIALOG_RESULT_POSITIVE then
      profile.rated = true
      profile:save()
      MOAIApp.openURL(device.storeURL)
    else
      profile.rateRemind = 5
      profile:save()
    end
    _isRateResponse = nil
    _rateResponse = false
    _androidRateCheck:stop()
  end
end
function PromptUserForAppStoreRating()
  if not MOAIApp or not MOAIApp.showDialog then
    return
  end
  if device.os == device.OS_ANDROID then
    _androidRateCheck = androidAS:repeatcall(0.5, _androidRateCheckFunc)
  end
  MOAIApp.showDialog(_("Like this App?"), _("Please help us by giving us a positive rating in the store!"), _("Rate It!"), nil, _("Remind Me Later"), false, function(idx)
    if device.os == device.OS_ANDROID then
      _isRateResponse = true
      _rateResponse = idx
    elseif idx == MOAIApp.DIALOG_RESULT_POSITIVE then
      profile.rated = true
      profile:save()
      analytics.rateAppRequest(true)
      MOAIApp.openURL(device.storeURL)
    else
      profile.rateRemind = 5
      profile:save()
      analytics.rateAppRequest(false)
    end
  end)
end
function RateAppCheck()
  if profile.rated == false then
    profile.rateRemind = (profile.rateRemind or 0) - 1
    profile:save()
    if profile.rateRemind <= 0 then
      PromptUserForAppStoreRating()
    end
  end
end
function PromptUserForHighScore(score, omega13, deathBlossom, wave, inLeaderboard, filter)
  if not MOAIApp or not MOAIApp.showDialog then
    return
  end
  local postString = _("You Have a High Score!")
  if inLeaderboard then
    postString = _("Posting High Score")
  end
  if device.os == device.OS_ANDROID then
    MOAIApp.showDialog(postString, _("How do you want it to display?"), _("Use Facebook Name"), nil, _("Don't Post"), false, function(idx)
      if idx == MOAIApp.DIALOG_RESULT_POSITIVE then
        if fb.isLoggedIn() then
          profile.hsAlias = fb.getFullName()
          profile:save()
          cloud.postNewHighScore(score, profile.hsAlias, omega13, deathBlossom, wave, filter)
        else
          fb.setListener(function(event, data)
            if event == fb.EVENT_FRIENDSLIST_READY then
              profile.hsAlias = fb.getFullName()
              profile:save()
              cloud.postNewHighScore(score, profile.hsAlias, omega13, deathBlossom, wave, filter)
              fb.setListener(nil)
            elseif event == fb.EVENT_LOGIN_FAILED then
              fb.setListener(nil)
            end
          end)
          fb.login()
        end
        if inLeaderboard and _leaderboard_root and _leaderboard_root.leaderboardBtn then
          _leaderboard_root.leaderboardBtn:remove()
          startLeaderBoardTimer()
        end
      else
        profile.excludeScore = true
        profile:save()
      end
    end)
  else
    MOAIApp.showDialog(postString, _("How do you want it to display?"), _("Use Facebook Name"), _("Use Gamecenter Alias"), _("Don't Post"), false, function(idx)
      if idx == MOAIApp.DIALOG_RESULT_POSITIVE then
        if fb.isLoggedIn() then
          profile.hsAlias = fb.getFullName()
          profile:save()
          cloud.postNewHighScore(score, profile.hsAlias, omega13, deathBlossom, wave, filter)
        else
          fb.setListener(function(event, data)
            if event == fb.EVENT_FRIENDSLIST_READY then
              profile.hsAlias = fb.getFullName()
              profile:save()
              cloud.postNewHighScore(score, profile.hsAlias, omega13, deathBlossom, wave, filter)
              fb.setListener(nil)
            elseif event == fb.EVENT_LOGIN_FAILED then
              fb.setListener(nil)
            end
          end)
          fb.login()
        end
        if inLeaderboard and _leaderboard_root and _leaderboard_root.leaderboardBtn then
          _leaderboard_root.leaderboardBtn:remove()
        end
      elseif idx == MOAIApp.DIALOG_RESULT_NEUTRAL then
        if gamecenter.isLoggedIn() then
          profile.hsAlias = gamecenter.getAlias()
          profile:save()
          cloud.postNewHighScore(score, profile.hsAlias, omega13, deathBlossom, wave, filter)
        else
          gamecenter.setFriendsListCallback(function()
            profile.hsAlias = gamecenter.getAlias()
            profile:save()
            cloud.postNewHighScore(score, profile.hsAlias, omega13, deathBlossom, wave, filter)
            gamecenter.setFriendsListCallback(nil)
          end)
          gamecenter.login()
        end
        if inLeaderboard and _leaderboard_root and _leaderboard_root.leaderboardBtn then
          _leaderboard_root.leaderboardBtn:remove()
          _enable_spinner(100)
        end
      else
        profile.excludeScore = true
        profile:save()
      end
    end)
  end
end
function PromptUserForFacebookLogout()
  MOAIApp.showDialog(_("Unlink Facebook?"), _("Unlink Facebook from Strikefleet Omega?"), _("Unlink"), nil, _("No Thanks"), false, function(idx)
    if idx == MOAIApp.DIALOG_RESULT_POSITIVE then
      cloud.unmapFacebookAccount()
      fb.unlink()
      if _mainmenu_root and _mainmenu_root.settingsBG then
        do
          local facebookBtn = _mainmenu_root.settingsBG.facebookBtn
          if facebookBtn then
            facebookBtn._up.off = facebookBtn._up:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
            facebookBtn._down.off = facebookBtn._down:add(ui.Image.new("menuTemplateShared.atlas.png#iconOff.png"))
            facebookBtn.off = true
            function facebookBtn.onClick()
              fb.setListener(function(event, data)
                if event == fb.EVENT_FRIENDSLIST_READY then
                  cloud.mapFacebookAccount()
                end
              end)
              fb.login()
            end
          end
        end
      end
    end
  end)
end
function PromptUserGCLoginFailed()
  MOAIApp.showDialog(_("Cannot Connect to Game Center"), _("Please launch the Game Center App, sign in, and come back."), nil, nil, _("Okay"), false, function(idx)
    gamecenter.onLoginFailedDismissed()
  end)
end
