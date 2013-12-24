local device = require("device")
local ui = require("ui")
local color = require("color")
local actionset = require("actionset")
local soundmanager = require("soundmanager")
local bucket = resource.bucket
local profile = get_profile()
local table_insert = table.insert
local table_remove = table.remove
local _debug, _warn, _error = require("qlog").loggers("popups")
local popupsQueue = {}
local curPopup
local popupsSession = {}
local _M = {}
local function Button_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  if eventType == ui.TOUCH_UP then
    ui.capture(nil)
    self._isdown = nil
  elseif eventType == ui.TOUCH_DOWN then
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
function _M.clear_queue()
  popupsQueue = {}
  curPopup = nil
end
function _M.finish()
  curPopup = nil
end
function _M.check_queue(force)
  _debug("CHECKING POPUP QUEUE: ", #popupsQueue, curPopup)
  if #popupsQueue > 0 and curPopup == nil then
    curPopup = popupsLayer:add(table_remove(popupsQueue))
    soundmanager.onSFX("onMessage")
    local captureElement = ui.getCaptureElement()
    if captureElement == nil then
      return curPopup.popupBox
    end
    if levelUI ~= nil then
      if levelUI.ffbtn == captureElement then
        levelUI.ffbtn:showPage("up")
        ui.capture(nil)
        return curPopup.popupBox
      end
      if levelUI.pausebtn == captureElement then
        levelUI.pausebtn:showPage("up")
        ui.capture(nil)
        return curPopup.popupBox
      end
      if levelUI.buildBtn == captureElement then
        levelUI.buildBtn:showPage("up")
        ui.capture(nil)
        return curPopup.popupBox
      end
    end
    return curPopup.popupBox
  end
end
function _M:insert_queue()
  table_insert(popupsQueue, self)
end
local _popup_advance, _popup_remove, _popup_new
function _popup_advance(self)
  local def = self.popupDef
  if self.androidBackBtn and device.os == device.OS_ANDROID then
    table_remove(android_back_button_queue, #android_back_button_queue)
    local callback = android_back_button_queue[#android_back_button_queue]
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
    table_remove(android_pause_queue, #android_pause_queue)
    local pause_callback = android_pause_queue[#android_pause_queue]
    MOAIApp.setListener(MOAIApp.ON_PAUSE_CALLED, pause_callback)
  end
  if self.popupPage < #def.pages then
    _popup_remove(self)
    do
      local popup = popupsLayer:add(_popup_new(def, self.popupPage + 1, self.showAd, self.callback, self.perPageCallback))
      soundmanager.onSFX("onMessagePage")
      local perPageCallback = self.perPageCallback
      if perPageCallback ~= nil then
        perPageCallback(popup)
      end
    end
  else
    _popup_remove(self)
    _M.finish()
    soundmanager.onSFX("onMessageEnd")
    if def.pause then
      levelAS:resume()
      environmentAS:resume()
      uiAS:resume()
    end
    local callback = self.callback
    if callback ~= nil then
      callback(self)
    end
    _M.check_queue()
  end
end
function _popup_remove(self)
  if self.messageContinueIndicatorActionSet ~= nil then
    self.messageContinueIndicatorAction:stop()
    self.messageContinueIndicatorAction = nil
    self.messageContinueIndicatorActionSet:stop()
    self.messageContinueIndicatorActionSet = nil
  end
  self:remove()
end
function _popup_new(def, pageNum, showAd, callback, perPageCallback)
  bucket.push("POPUPS")
  local submenu_height = device.ui_height
  local submenu_y = 0
  if showAd and not profile.excludeAds then
    submenu_height = submenu_height - 100
    submenu_y = submenu_y - 50
  end
  local o = ui.Group.new()
  o.popupDef = def
  o.popupPage = pageNum or 1
  o.showAd = showAd
  o.callback = callback
  o.perPageCallback = perPageCallback
  local pageDef = def.pages[o.popupPage]
  if def.type == "fS" or def.type == "fL" then
    do
      local bg = o:add(ui.PickBox.new(device.ui_width, submenu_height, "00000088"))
      bg:setLoc(0, submenu_y)
      function bg.handleTouch()
        _debug("Touching Popup BG")
        return true
      end
      if device.os == device.OS_ANDROID then
        local callback = function()
          return true
        end
        table_insert(android_back_button_queue, callback)
        MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
        o.androidBackBtn = true
        local pause_callback = function()
          return
        end
        table_insert(android_pause_queue, pause_callback)
        MOAIApp.setListener(MOAIApp.ON_PAUSE_CALLED, pause_callback)
      end
      local titleBG
      if def.title ~= nil then
        titleBG = o:add(ui.Image.new("menuTemplateShared.atlas.png#popupTitleBG.png"))
        local titleText = titleBG:add(ui.TextBox.new(_(def.title), FONT_XLARGE, "ffffff", "center", nil, nil, true))
        titleText:setLoc(0, -4)
      end
      local popupWidth = 620
      local popupHeight = 0
      if def.type == "fS" then
        popupHeight = 312
      elseif def.type == "fL" then
        popupHeight = 440
      end
      local popupBox = o:add(ui.NinePatch.new("popupBox9p.lua", popupWidth, popupHeight))
      if def.title ~= nil then
        titleBG:setLoc(0, popupHeight / 2 - 24)
        popupBox:setLoc(0, -62)
      end
      if pageDef.charL ~= nil then
        do
          local charL = popupBox:add(ui.Image.new(pageDef.charL))
          charL:setLoc(-192, 64)
          local text = popupBox:add(ui.TextBox.new(_(pageDef.text), FONT_MEDIUM, "ffffff", "left", 350, popupHeight - 180, true))
          text:setLoc(80, 20)
          if pageDef.charName ~= nil then
            local name = popupBox:add(ui.TextBox.new(_(pageDef.charName), FONT_SMALL_BOLD, "ffffff", "left", 350, nil, true))
            name:setColor(color.parse("bce0ee"))
            name:setLoc(80, popupHeight / 2 - 55)
          end
        end
      elseif pageDef.charR ~= nil then
        do
          local charR = popupBox:add(ui.Image.new(pageDef.charR))
          charR:setScl(-1, 1)
          charR:setLoc(192, 64)
          local text = popupBox:add(ui.TextBox.new(_(pageDef.text), FONT_MEDIUM, "ffffff", "left", 350, popupHeight - 180, true))
          text:setLoc(-80, 20)
          if pageDef.charName ~= nil then
            local name = popupBox:add(ui.TextBox.new(_(pageDef.charName), FONT_SMALL_BOLD, "ffffff", "left", 350, nil, true))
            name:setColor(color.parse("bce0ee"))
            name:setLoc(-80, popupHeight / 2 - 55)
          end
        end
      else
        local text = popupBox:add(ui.TextBox.new(_(pageDef.text), FONT_MEDIUM, "ffffff", "center", 516, nil, true))
        text:setLoc(0, 64)
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
        _popup_advance(o)
      end
    end
  elseif def.type == "s" or def.type == "l" then
    do
      local popupWidth = 612
      local popupHeight = 0
      if def.type == "s" then
        popupHeight = 162
      elseif def.type == "l" then
        popupHeight = 312
      end
      local uiBarHeight
      if gameMode == "galaxy" then
        uiBarHeight = UI_BAR_HEIGHT
      elseif gameMode == "survival" then
        uiBarHeight = UI_BAR_HEIGHT_SURVIVAL
      end
      if def.pause then
        local bg = o:add(ui.PickBox.new(device.ui_width, submenu_height, color.toHex(0.0558825, 0.0558825, 0.0558825, 0.25)))
        bg:setLoc(0, submenu_y)
        function bg.onClick()
          _debug("Touching Popup BG 2")
          return true
        end
        if not showAd then
          local pauseBtn = o:add(ui.Button.new("menuTemplateShared.atlas.png#iconPause.png"))
          pauseBtn._down:setColor(unpack(UI_CREDITS_TITLE_COLOR))
          pauseBtn:setLoc(device.ui_width / 2 - 36, device.ui_height / 2 - uiBarHeight / 2 + 26)
          pauseBtn.handleTouch = Button_handleTouch
          function pauseBtn.onClick()
            pause_show(o)
          end
          if device.os == device.OS_ANDROID then
            local function callback()
              pause_show(o)
              return true
            end
            table_insert(android_back_button_queue, callback)
            MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
            o.androidBackBtn = true
            local pause_callback = function()
              return
            end
            table_insert(android_pause_queue, pause_callback)
            MOAIApp.setListener(MOAIApp.ON_PAUSE_CALLED, pause_callback)
          end
        end
      end
      local popupBox = o:add(ui.NinePatch.new("messageBox9p.lua", popupWidth, popupHeight))
      popupBox:setLoc(0, device.ui_height / 2 - (uiBarHeight - 15 + popupHeight / 2))
      o.popupBox = popupBox
      local pickbox = popupBox:add(ui.PickBox.new(popupWidth, popupHeight))
      function pickbox.onClick()
        _popup_advance(o)
      end
      local messageContinueIndicator = popupBox:add(ui.Image.new("menuTemplateShared.atlas.png#messageContinueIndicator.png"))
      messageContinueIndicator:setColor(0, 0, 0, 0)
      messageContinueIndicator:setLoc(270, -popupHeight / 2 + 16)
      o.messageContinueIndicatorActionSet = actionset.new()
      o.messageContinueIndicatorAction = o.messageContinueIndicatorActionSet:repeatcall(0.3, function()
        if messageContinueIndicator.active then
          messageContinueIndicator:seekColor(0, 0, 0, 0, 0.3, MOAIEaseType.EASE_IN)
          messageContinueIndicator.active = nil
        else
          messageContinueIndicator:seekColor(1, 1, 1, 1, 0.3, MOAIEaseType.EASE_IN)
          messageContinueIndicator.active = true
        end
      end)
      if pageDef.charL ~= nil then
        do
          local charL = popupBox:add(ui.Image.new(pageDef.charL))
          charL:setLoc(-221, 22)
          if pageDef.text ~= nil then
            local text = popupBox:add(ui.TextBox.new(_(pageDef.text), FONT_MEDIUM, "ffffff", "left", 350, nil, true))
            text:setLoc(85, 5)
          end
        end
      elseif pageDef.charR ~= nil then
        do
          local charR = popupBox:add(ui.Image.new(pageDef.charR))
          charR:setScl(-1, 1)
          charR:setLoc(221, 22)
          if pageDef.text ~= nil then
            local text = popupBox:add(ui.TextBox.new(_(pageDef.text), FONT_MEDIUM, "ffffff", "left", 350, nil, true))
            text:setLoc(-85, 5)
          end
          messageContinueIndicator:setLoc(100, -popupHeight / 2 + 16)
        end
      elseif pageDef.imgL == nil and pageDef.imgR == nil and pageDef.text ~= nil then
        local text = popupBox:add(ui.TextBox.new(_(pageDef.text), FONT_MEDIUM, "ffffff", "center", 516, nil, true))
        text:setLoc(0, 5)
      end
      if pageDef.imgL ~= nil then
        local imgL = popupBox:add(ui.Image.new(pageDef.imgL))
        imgL:setLoc(-140, 20)
        local captionL
        if pageDef.captionL ~= nil then
          captionL = popupBox:add(ui.TextBox.new(_(pageDef.captionL), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
          captionL:setLoc(-140, -popupHeight / 2 + 30)
        end
        if pageDef.text ~= nil then
          local text = popupBox:add(ui.TextBox.new(_(pageDef.text), FONT_MEDIUM, "ffffff", "left", 350, nil, true))
          text:setLoc(85, 5)
          imgL:setLoc(-220, 20)
          if captionL then
            captionL:setLoc(-220, -popupHeight / 2 + 30)
          end
        end
      end
      if pageDef.imgR ~= nil then
        local imgR = popupBox:add(ui.Image.new(pageDef.imgR))
        imgR:setLoc(140, 20)
        local captionR
        if pageDef.captionR ~= nil then
          captionR = popupBox:add(ui.TextBox.new(_(pageDef.captionR), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
          captionR:setLoc(140, -popupHeight / 2 + 30)
        end
        if pageDef.text ~= nil then
          local text = popupBox:add(ui.TextBox.new(_(pageDef.text), FONT_MEDIUM, "ffffff", "left", 350, nil, true))
          text:setLoc(-85, 5)
          imgR:setLoc(220, 20)
          if captionR then
            captionR:setLoc(220, -popupHeight / 2 + 30)
          end
          messageContinueIndicator:setLoc(100, -popupHeight / 2 + 16)
        end
      end
      if pageDef.imgC ~= nil then
        local imgC = popupBox:add(ui.Image.new(pageDef.imgC))
        imgC:setLoc(0, 20)
      end
      if pageDef.caption ~= nil then
        local caption = popupBox:add(ui.TextBox.new(_(pageDef.caption), FONT_SMALL_BOLD, "ffffff", "center", nil, nil, true))
        caption:setLoc(0, -popupHeight / 2 + 30)
      end
    end
  end
  bucket.pop()
  return o
end
function _M.show(id, showAd, callback, perPageCallback)
  local DEFS = require("ShipData-PopupDefs")
  local def = DEFS[id]
  if def == nil then
    return nil
  end
  if def.disable then
    return false
  end
  if def.once then
    if profile.popups[id] ~= nil then
      return false
    else
      profile.popups[id] = true
      profile:save()
    end
  end
  if def.onceSession then
    if popupsSession[id] ~= nil then
      return false
    else
      popupsSession[id] = true
    end
  end
  if def.pause then
    levelAS:pause()
    environmentAS:pause()
    uiAS:pause()
  end
  _debug("Showing popup: " .. id, def.pause)
  _M.insert_queue(_popup_new(def, nil, showAd, callback, perPageCallback))
  return _M.check_queue() or true
end
return _M
