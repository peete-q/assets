local device = require("device")
local ui = require("ui")
local color = require("color")
local gfxutil = require("gfxutil")
local behavior = require("behavior")
local soundmanager = require("soundmanager")
local util = require("util")
local update = require("update")
local Particle = require("Particle")
local popups = require("popups")
local achievements = require("achievements")
local table_insert = table.insert
local table_remove = table.remove
local set_if_nil = util.set_if_nil
local bucket = resource.bucket
local profile = get_profile()
local PI = math.pi
local TWO_PI = PI * 2
local HALF_PI = PI / 2
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
local function _fastforward_onClick(self)
  if (levelUI.resetting or levelUI.blossomActive or levelUI.inStoreMenu) and not levelUI.ffing then
    return
  end
  if not levelUI.resetting and not levelUI.blossomActive then
    soundmanager:onClick()
  end
  levelUI.ffing = not levelUI.ffing
  if levelUI.ffing then
    levelAS:throttle(4)
    levelUI.ffbtn._up:setColor(unpack(UI_CREDITS_TITLE_COLOR))
    if gameMode == "survival" then
      popups.show("on_survival_ff")
    end
  else
    levelAS:throttle(1)
    if DEBUG_HIDE_HUD then
      levelUI.ffbtn._up:setColor(0, 0, 0, 0)
    else
      levelUI.ffbtn._up:setColor(1, 1, 1, 1)
    end
    if not levelUI.resetting then
      achievements.checklist_fail("fast_forward")
    end
  end
end
local function _pauseBtn_onClick(self)
  if (levelUI.resetting or levelUI.blossomActive or levelUI.inStoreMenu) and not levelUI.pausing then
    return
  end
  if not levelUI.resetting and not levelUI.blossomActive then
    soundmanager:onClick()
  end
  if not levelUI.pausing then
    pause_show(levelUI)
  else
    pause_close()
  end
end
local function _buildBtn_onClick(self)
  if not levelUI.resetting then
    soundmanager:onClick()
  end
  levelUI.inStoreMenu = true
  levelAS:pause()
  environmentAS:pause()
  warpmenu_show()
end
local _respawnTick = function(dt)
  levelUI.curRespawnTime = levelUI.curRespawnTime + dt
  if levelUI.curRespawnTime >= levelUI.respawnExpiration then
    for k, v in pairs(commandShipParts) do
      v:destroy()
    end
    commandShipParts = nil
    levelUI.respawnAction:stop()
    return
  end
  local lerp = 1 - levelUI.curRespawnTime / levelUI.respawnExpiration
  for k, v in pairs(commandShipParts) do
    local curRot = v._resStartRot * lerp
    local curX = v._resStartX * lerp
    local curY = v._resStartY * lerp
    v:setLoc(curX, curY)
    v:setRot(curRot)
  end
end
local function _onOmegaEnd(reset)
  if levelUI.omegaAction then
    levelUI.omegaAction:stop()
    levelUI.omegaAction = nil
  end
  levelUI.omega:remove()
  levelUI.pauseScreen:remove()
  if reset then
    do
      local profile = get_profile()
      local cost = levelUI.omegaCost
      cost = math.max(cost - (scores[OMEGA_RESOURCE_TYPE] or 0), 0)
      if scores[OMEGA_RESOURCE_TYPE] then
        scores[OMEGA_RESOURCE_TYPE] = math.max(scores[OMEGA_RESOURCE_TYPE] - levelUI.omegaCost, 0)
      end
      if cost > 0 then
        omegaUsed = (omegaUsed or 0) + 1
        profile_currency_txn(OMEGA_RESOURCE_TYPE, -cost, string.format("Used: omega13.%d", omegaUsed), true)
        set_if_nil(gameSessionAnalytics, "currency", {})
        set_if_nil(gameSessionAnalytics.currency, OMEGA_RESOURCE_TYPE, {})
        gameSessionAnalytics.currency[OMEGA_RESOURCE_TYPE].spent = (gameSessionAnalytics.currency[OMEGA_RESOURCE_TYPE].spent or 0) + cost
      end
      popups.show("on_cred_purchase")
      level_fx_explosion(0, 20, 1, mainLayer, "omega13CapitalShipSmoke.pex")
      level_fx_explosion(0, 20, 1, mainLayer, "omega13CapitalShipCloud.pex")
      level_fx_explosion(0, 20, 1, mainLayer, "omega13CapitalShipSparks.pex")
      levelUI.respawnAction = uiAS:run(_respawnTick)
      for k, v in pairs(commandShipParts) do
        v.tickfn = nil
        v.spawnExpirationTime = nil
        v._resStartRot = v:getRot()
        v._resStartX, v._resStartY = v:getLoc()
        levelAS:wrap(v.sprite:seekColor(1, 1, 1, 1, 0.5, MOAIEaseType.LINEAR))
      end
      levelAS:throttle(1)
      levelUI.respawnExpiration = 0.5
      levelUI.curRespawnTime = 0
      levelui_unhide_hud_buttons()
      levelAS:delaycall(0.5, function()
        commandShip = level_spawn_object(string.format("SPC_%d", profile.unlocks.SPC.currentUpgrade), mothershipLayer, 0, 0)
        if active_perks.regenShip then
          commandShip.regenPerSecond = 1 / active_perks.regenShip.modifier
          commandShip.tickfn = behavior.spc_regen
        end
        levelAS:resume()
        environmentAS:resume()
        resetting = nil
        levelUI.resetting = false
        start_death_blossom(true)
        level_update_max_dc()
      end)
      soundmanager.onSFX("onCapShipRebirth")
      achievements.checklist_fail("turkey_noomega")
      achievements.checklist_fail("turkey_plain")
      set_if_nil(gameSessionAnalytics, "specialAbilities", {})
      gameSessionAnalytics.specialAbilities.omega = (gameSessionAnalytics.specialAbilities.omega or 0) + 1
    end
  else
    uiAS:delaycall(0.01, start_game_over_ui)
    environmentAS:resume()
  end
end
local function _omega_tick(dt)
  if levelUI.inStoreMenu then
    return
  end
  local time = math.max(levelUI.omegaTime - dt, 0)
  if math.ceil(time) ~= levelUI.omegaLastTime then
    soundmanager.onSFX("onCountdown")
    uiAS:wrap(levelUI.omegaTimeTxtL:seekColor(UI_FILL_RED_COLOR[1], UI_FILL_RED_COLOR[2], UI_FILL_RED_COLOR[3], UI_FILL_RED_COLOR[4], 0.5), function()
      uiAS:wrap(levelUI.omegaTimeTxtL:seekColor(0, 0, 0, 0, 0.4))
    end)
    uiAS:wrap(levelUI.omegaTimeTxtR:seekColor(UI_FILL_RED_COLOR[1], UI_FILL_RED_COLOR[2], UI_FILL_RED_COLOR[3], UI_FILL_RED_COLOR[4], 0.5), function()
      uiAS:wrap(levelUI.omegaTimeTxtR:seekColor(0, 0, 0, 0, 0.4))
    end)
    uiAS:wrap(levelUI.omegaGlow:seekColor(1, 1, 1, 1, 0.5), function()
      levelUI.omegaGlow:seekColor(0.25, 0.25, 0.25, 0.25, 0.4)
    end)
  end
  levelUI.omegaLastTime = math.ceil(time)
  levelUI.omegaTime = time
  local timeString = string.format("%d", math.ceil(levelUI.omegaLastTime))
  levelUI.omegaTimeTxtL:setString(timeString)
  levelUI.omegaTimeTxtR:setString(timeString)
  if time <= 0 then
    _onOmegaEnd(false)
  end
end
local function activeBlossom_onTouch(self, eventType, touchIdx, x, y, tapCount)
  if touchIdx ~= ui.TOUCH_ONE or levelUI.blossomActive then
    return true
  end
  local touchDone = false
  local hw = self.halfwidth
  local hh = self.halfheight
  if eventType == ui.TOUCH_DOWN then
    if x < -hw or x > hw or y < -hh or y > hh then
      touchDone = true
    end
  elseif eventType == ui.TOUCH_MOVE then
    if x < -hw or x > hw or y < -hh or y > hh then
      touchDone = true
    end
  elseif eventType == ui.TOUCH_UP then
    if x < -hw or x > hw or y < -hh or y > hh then
      touchDone = true
    else
      start_death_blossom_ui()
      ui.capture(nil, self)
    end
  end
  if touchDone then
    self:remove()
    levelUI.blossomGroup:add(levelUI.blossomBtn)
    levelUI.blossomBtn:showPage("down")
    levelUI.blossomBtn:showPage("up")
    ui.capture(nil, self)
    return false
  end
  return true
end
function initialize_level_ui()
  if not levelUI then
    bucket.push("LEVEL_UI")
    levelUI = uiLayer:add(ui.new(MOAIProp2D.new()))
    local uiScl = device.ui_scale
    local deviceWidth = device.width * uiScl
    local deviceHeight = device.height * uiScl
    local uiBarHeight
    if gameMode == "galaxy" then
      uiBarHeight = UI_BAR_HEIGHT
    elseif gameMode == "survival" then
      uiBarHeight = UI_BAR_HEIGHT_SURVIVAL
    end
    if device.fill == device.FILL_RATE_HI then
      local screenLeft = levelUI:add(ui.Image.new("hud.atlas.png#vignetteSide.png"))
      local w, h = screenLeft:getSize()
      screenLeft:setScl(2, (deviceHeight + 2) / h)
      screenLeft:setLoc(-deviceWidth / 2 + w - 1, 0)
      screenLeft:setPriority(-5)
      local screenRight = levelUI:add(ui.Image.new("hud.atlas.png#vignetteSide.png"))
      screenRight:setScl(-2, (deviceHeight + 2) / h)
      screenRight:setLoc(deviceWidth / 2 - w + 1, 0)
      screenRight:setPriority(-5)
    end
    levelUI.pauseScreen = ui.PickBox.new(deviceWidth, deviceHeight, UI_TOP_BAR_COLOR)
    levelUI.pauseScreen:setPriority(-2)
    local barStartPos = device.ui_height / 2 - uiBarHeight / 2
    if not DEBUG_HIDE_HUD then
      local displayBar = levelUI:add(ui.NinePatch.new("hudTopBar9p.lua", device.ui_width + 2, uiBarHeight))
      displayBar:setLoc(0, barStartPos)
      if gameMode == "galaxy" then
        do
          local bottomBar = levelUI:add(ui.NinePatch.new("hudBottomBar9p.lua", device.ui_width + 2, 116))
          bottomBar:setLoc(0, -device.ui_height / 2 + 58)
          levelUI.bottomBar = bottomBar
        end
      elseif gameMode == "survival" then
        local bottomBar = levelUI:add(ui.NinePatch.new("hudBottomBarSurvival9p.lua", device.ui_width + 2, 116))
        bottomBar:setLoc(0, -device.ui_height / 2 + 58)
        levelUI.bottomBar = bottomBar
      end
    end
    local boxWidth = 140
    local resourceAreaBox = levelUI:add(ui.NinePatch.new("hudTopBarDark9p.lua", 64 + boxWidth, uiBarHeight))
    resourceAreaBox:setLoc(-device.ui_width / 2 + (64 + boxWidth) / 2, barStartPos)
    levelUI.resourceAreaBox = resourceAreaBox
    local crystal = levelUI:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystal.png"))
    crystal:setColor(unpack(UI_CREDITS_TITLE_COLOR))
    crystal:setLoc(-deviceWidth / 2 + 38, barStartPos + 26)
    local resourceText = levelUI:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "left", boxWidth, nil, true))
    resourceText:setLoc(-deviceWidth / 2 + 64 + boxWidth / 2, barStartPos + 24)
    levelUI.resourceText = resourceText
    local alloyIcon = levelUI:add(ui.Image.new("menuTemplateShared.atlas.png#iconAlloy.png"))
    alloyIcon:setLoc(-device.ui_width / 2 + 64 + boxWidth + 32, barStartPos + 26)
    levelUI.alloyIcon = alloyIcon
    local x, y = alloyIcon:getLoc()
    local alloyText = levelUI:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "left", 90, nil, true))
    alloyText:setLoc(x + 26 + 45, barStartPos + 24)
    levelUI.alloyText = alloyText
    local xmin, ymin, xmax, ymax = alloyText:getStringBounds(1, 1)
    local width = util.roundNumber(xmax - xmin)
    local x, y = alloyText:getLoc()
    local credsIcon = levelUI:add(ui.Image.new("menuTemplateShared.atlas.png#iconCreds.png"))
    credsIcon:setLoc(x + width / 2 + 16, barStartPos + 26)
    levelUI.credsIcon = credsIcon
    local x, y = credsIcon:getLoc()
    local credsText = levelUI:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "left", 90, nil, true))
    credsText:setLoc(x + 26 + 45, barStartPos + 24)
    levelUI.credsText = credsText
    local progressFill = levelUI:add(ui.FillBar.new({
      device.ui_width - 16,
      24
    }, color.toHex(0.70236, 0.31059000000000003, 0.045899999999999996, 0.65)))
    progressFill:setFill(0, 0)
    progressFill:setLoc(0, barStartPos - 17)
    levelUI.progressFill = progressFill
    if gameMode == "galaxy" then
      do
        local waveText = levelUI:add(ui.TextBox.new("0", FONT_SMALL_BOLD, "ffffff", "center", boxWidth, nil, true))
        waveText:setColor(1, 1, 1, 0.65)
        waveText:setLoc(0, barStartPos - 20)
        levelUI.waveText = waveText
      end
    elseif gameMode == "survival" then
      local text = string.format(_("<c:a6a6a6>WAVE <c:ffffff>%d"), 0)
      local waveText = levelUI:add(ui.TextBox.new(text, FONT_SMALL_BOLD, "ffffff", "left", boxWidth, nil, true))
      waveText:setLoc(-device.ui_width / 2 + boxWidth / 2 + 20, barStartPos - 20)
      levelUI.waveText = waveText
      local xmin, ymin, xmax, ymax = waveText:getStringBounds(1, text:len())
      local width = xmax - xmin
      local scoreText = levelUI:add(ui.TextBox.new(string.format(_("<c:a6a6a6>SCORE <c:ffffff>%s"), util.commasInNumbers(0)), FONT_SMALL_BOLD, "ffffff", "left", device.ui_width - 20, nil, true))
      scoreText:setLoc(width + 24, barStartPos - 20)
      levelUI.scoreText = scoreText
      local highScoreText = levelUI:add(ui.TextBox.new(string.format(_("<c:a6a6a6>HIGH SCORE <c:ffffff>%s"), util.commasInNumbers(0)), FONT_SMALL_BOLD, "ffffff", "right", device.ui_width - 20, nil, true))
      highScoreText:setLoc(-10, barStartPos - 20)
      levelUI.highScoreText = highScoreText
    end
    levelUI.ffing = false
    local ffbtn = levelUI:add(ui.Button.new("menuTemplateShared.atlas.png#iconFastForward.png"))
    ffbtn._down:setColor(unpack(UI_CREDITS_TITLE_COLOR))
    ffbtn:setLoc(deviceWidth / 2 - 108, barStartPos + 26)
    ffbtn.onClick = _fastforward_onClick
    levelUI.ffbtn = ffbtn
    levelUI.pausing = false
    local pausebtn = levelUI:add(ui.Button.new("menuTemplateShared.atlas.png#iconPause.png"))
    pausebtn._down:setColor(unpack(UI_CREDITS_TITLE_COLOR))
    pausebtn:setLoc(deviceWidth / 2 - 36, barStartPos + 26)
    pausebtn.onClick = _pauseBtn_onClick
    levelUI.pausebtn = pausebtn
    if device.os == device.OS_ANDROID then
      local function callback()
        _pauseBtn_onClick()
        return true
      end
      table_insert(android_back_button_queue, callback)
      MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
      local function pause_callback()
        if levelUI.pausing then
          return
        end
        _pauseBtn_onClick()
      end
      table_insert(android_pause_queue, pause_callback)
      MOAIApp.setListener(MOAIApp.ON_PAUSE_CALLED, pause_callback)
    end
    levelUI.cannonGroup = levelUI:add(ui.Group.new())
    if gameMode == "survival" then
      local btn = levelUI.cannonGroup:add(ui.Button.new("perksIconMask.png"))
      btn._up:setColor(0, 0, 0, 0)
      btn._down:setColor(0, 0, 0, 0)
      btn:setLoc(-72, -device.ui_height / 2 + 48)
      btn.icon = icon
      levelUI.perk1Btn = btn
      levelui_update_survival_perk(1)
      local btn = levelUI.cannonGroup:add(ui.Button.new("perksIconMask.png"))
      btn._up:setColor(0, 0, 0, 0)
      btn._down:setColor(0, 0, 0, 0)
      btn:setLoc(0, -device.ui_height / 2 + 48)
      btn.icon = icon
      levelUI.perk2Btn = btn
      levelui_update_survival_perk(2)
      local btn = levelUI.cannonGroup:add(ui.Button.new("perksIconMask.png"))
      btn._up:setColor(0, 0, 0, 0)
      btn._down:setColor(0, 0, 0, 0)
      btn:setLoc(72, -device.ui_height / 2 + 48)
      btn.icon = icon
      levelUI.perk3Btn = btn
      levelui_update_survival_perk(3)
    end
    local buildBtn = levelUI.cannonGroup:add(ui.Button.new("hud.atlas.png#iconWarpMenu.png"))
    buildBtn._down:setColor(unpack(UI_CREDITS_TITLE_COLOR))
    buildBtn.onClick = _buildBtn_onClick
    buildBtn:setLoc(deviceWidth / 2 - 86, -deviceHeight / 2 + 80)
    levelUI.buildBtn = buildBtn
    buildBtn.onClick = _buildBtn_onClick
    levelUI.inWarp = false
    local omega = ui.new(MOAIProp2D.new())
    levelUI.omega = omega
    local omegaBG = omega:add(ui.Image.new("hudOmega13.atlas.png#omega13Frame.png"))
    omegaBG:setLoc(0, 34)
    local omegaTxt = omega:add(ui.TextBox.new(_("Activate Emergency Respawn Protocol?"), FONT_MEDIUM, "ffffff", "center", 280, 110))
    omegaTxt:setLoc(0, 180)
    local omegaPriceTxt = omega:add(ui.TextBox.new("", FONT_MEDIUM_BOLD, "ffffff", "center", 370, 110))
    omegaPriceTxt:setLoc(0, 120)
    levelUI.omegaPriceTxt = omegaPriceTxt
    local omegaIngot = omega:add(ui.Image.new("menuTemplateShared.atlas.png#iconCreds.png"))
    omegaIngot.yLoc = 156
    levelUI.omegaIngot = omegaIngot
    local omegaTimeTxtL = omega:add(ui.TextBox.new("", FONT_XLARGE, "ffffff", "center", 370, 110))
    omegaTimeTxtL:setLoc(-160, -40)
    omegaTimeTxtL:setColor(unpack(UI_FILL_RED_COLOR))
    levelUI.omegaTimeTxtL = omegaTimeTxtL
    local omegaTimeTxtR = omega:add(ui.TextBox.new("", FONT_XLARGE, "ffffff", "center", 370, 110))
    omegaTimeTxtR:setLoc(160, -40)
    omegaTimeTxtR:setColor(unpack(UI_FILL_RED_COLOR))
    levelUI.omegaTimeTxtR = omegaTimeTxtR
    local omegaBtn = omega:add(ui.Button.new("hudOmega13.atlas.png#omega13Button.png", "hudOmega13.atlas.png#omega13ButtonPress.png"))
    levelUI.omegaBtn = omegaBtn
    local omegaGlow = omega:add(ui.Image.new("hudOmega13.atlas.png#omega13ButtonGlow.png"))
    levelUI.omegaGlow = omegaGlow
    levelUI.omegaGlow:setColor(0.25, 0.25, 0.25, 0)
    local omegaLightL = omega:add(ui.Image.new("hudOmega13.atlas.png#omega13Light.png"))
    omegaLightL:setLoc(-216, 206)
    omegaLightL:setScl(0.5, 0.5)
    levelUI.omegaLightL = omegaLightL
    local omegaLightR = omega:add(ui.Image.new("hudOmega13.atlas.png#omega13Light.png"))
    omegaLightR:setLoc(216, 206)
    omegaLightR:setScl(0.5, 0.5)
    levelUI.omegaLightR = omegaLightR
    local blossomBG
    blossomBG = ui.Image.new("white.png")
    blossomBG:setScl(deviceWidth, deviceHeight)
    blossomBG:setPriority(100)
    blossomBG:setColor(0, 0, 0, 0)
    levelUI.blossomBG = blossomBG
    local blossomGroup = ui.new(MOAIProp2D.new())
    levelUI.blossomGroup = blossomGroup
    local blossomBtn = blossomGroup:add(ui.Button.new("hud.atlas.png#iconDeathBlossom.png"))
    blossomBtn._up:setPriority(30)
    blossomBtn._down:setPriority(30)
    function blossomBtn.onClick()
      if not levelUI.blossomActive then
        levelUI.blossomBtn:remove()
        levelUI.blossomGroup:add(levelUI.activeBlossom)
        local cost = BLOSSOM_COST * (BLOSSOM_CHARGES - blossomCharges + 1)
        levelUI.blossomCost:setString("" .. cost)
        ui.capture(levelUI.activeBlossom, self)
        soundmanager.onSFX("onDeathBlossomAnticipation")
      end
    end
    levelUI.blossomBtn = blossomBtn
    local activeBlossom = ui.new(MOAIProp2D.new())
    local activeBG = activeBlossom:add(ui.Image.new("hud.atlas.png#iconDeathBlossomActive.png"))
    activeBG:setPriority(30)
    w, h = activeBG:getSize()
    activeBlossom:setLoc(-deviceWidth / 2 + w / 2 + 18, -deviceHeight / 2 + h / 2 + 18)
    activeBlossom.handleTouch = activeBlossom_onTouch
    activeBlossom.halfwidth = w / 2
    activeBlossom.halfheight = h / 2
    levelUI.activeBlossom = activeBlossom
    local activateTxt = activeBlossom:add(ui.TextBox.new(_("Activate?"), FONT_SMALL_BOLD, "ffffff", "center", 280, 110, true))
    activateTxt:setLoc(40, -30)
    local activateIcon = activeBlossom:add(ui.Image.new("menuTemplateShared.atlas.png#iconCredsMed.png"))
    activateIcon:setLoc(16, -12)
    local activateCost = activeBlossom:add(ui.TextBox.new("15", FONT_MEDIUM_BOLD, "ffffff", "center", 280, 110, true))
    activateCost:setLoc(50, -50)
    levelUI.blossomCost = activateCost
    activateTxt:setPriority(30)
    activateIcon:setPriority(30)
    activateCost:setPriority(30)
    local messageDrop = ui.TextBox.new("", FONT_XLARGE, "ffffff", "center", 800, 130)
    messageDrop:setColor(unpack(UI_DROP_SHADOW_COLOR))
    messageDrop.endX = 2
    messageDrop.endY = deviceHeight / 4 - 2
    messageDrop.startX = deviceWidth * 2
    messageDrop:setLoc(messageDrop.startX, messageDrop.endY)
    levelUI.titleMessageDrop = messageDrop
    local message = ui.TextBox.new("", FONT_XLARGE, "ffffff", "center", 800, 130)
    message.endX = 0
    message.endY = deviceHeight / 4 - 0
    message.startX = -deviceWidth * 2
    message:setLoc(message.startX, messageDrop.endY)
    levelUI.titleMessage = message
    bucket.pop()
  end
  levelUI.levelDisplayed = false
  levelUI.finalWave = false
  levelUI.finalWaveAlert = false
  levelUI.alert = {}
  if DEBUG_HIDE_HUD then
    levelUI:setColor(0, 0, 0, 0)
    levelUI.blossomBtn._up:setColor(0, 0, 0, 0)
    levelUI.blossomBtn._down:setColor(0, 0, 0, 0)
    levelUI.buildBtn._up:setColor(0, 0, 0, 0)
    levelUI.resourceAreaBox:remove()
    levelUI.progressFill:remove()
    levelUI.ffbtn._up:setColor(0, 0, 0, 0)
    levelUI.ffbtn._down:setColor(0, 0, 0, 0)
    levelUI.pausebtn._up:setColor(0, 0, 0, 0)
    levelUI.pausebtn._down:setColor(0, 0, 0, 0)
  end
  local levelGalaxyIndex, levelSystemIndex, levelGalaxySystemIdx = level_get_galaxy_system()
  if gameMode ~= "survival" then
    if levelGalaxySystemIdx < TUT_MIN_WARP_SYSTEM then
      ui_toggle_warp_button(false)
    else
      popups.show("on_warp_active")
    end
    if levelGalaxySystemIdx <= TUT_MIN_BLOSSOM_SYSTEM then
      ui_toggle_blossom_button(false)
      levelUI.blossomInactive = true
    end
  end
end
function deinitialize_level_ui()
  if levelUI ~= nil then
    levelUI:remove()
    levelUI.omega:remove()
    levelUI.omega = nil
    levelUI = nil
  end
  bucket.release("LEVEL_UI")
end
function start_levelstart_ui()
  if levelUI.levelDisplayed then
    return
  end
  local levelString = environment_getlevelstring()
  start_level_message_ui(levelString)
end
function start_level_message_ui(text, waitTime)
  local ltDrop = levelUI.titleMessageDrop
  local lt = levelUI.titleMessage
  local pauseTime = waitTime or 1
  ltDrop:setString(_(text))
  lt:setString(_(text))
  levelUI.levelDisplayed = true
  levelUI:add(ltDrop)
  levelUI:add(lt)
  levelAS:wrap(ltDrop:seekLoc(ltDrop.endX, ltDrop.endY, 0.5, MOAIEaseType.SHARP_EASE_IN))
  levelAS:wrap(lt:seekLoc(lt.endX, lt.endY, 0.5, MOAIEaseType.SHARP_EASE_IN), function()
    levelAS:delaycall(pauseTime, function()
      levelAS:wrap(ltDrop:seekLoc(-device.width * 2, ltDrop.endY, 0.5, MOAIEaseType.SHARP_EASE_OUT), function()
        ltDrop:remove()
        ltDrop:setLoc(ltDrop.startX, ltDrop.endY)
      end)
      levelAS:wrap(lt:seekLoc(device.width * 2, lt.endY, 0.5, MOAIEaseType.SHARP_EASE_OUT), function()
        lt:remove()
        lt:setLoc(lt.startX, lt.endY)
      end)
      levelAS:delaycall(0.5, function()
        local levelGalaxyIndex, levelSystemIndex = level_get_galaxy_system()
        popups.show("on_g" .. levelGalaxyIndex .. "_s" .. levelSystemIndex .. "_start")
      end)
    end)
  end)
end
function start_finalwave_ui()
  if levelUI.finalWaveAlert then
    return
  end
  levelUI.finalWaveAlert = true
  soundmanager.onSFX("onFinalWave")
  local finalWaveText = uiLayer:add(ui.TextBox.new(_("Final Wave!"), FONT_XLARGE, "ff0000", "center", device.width, 120, true))
  levelAS:wrap(finalWaveText:seekColor(1, 1, 1, 0, 4), function()
    finalWaveText:remove()
    finalWaveText = nil
  end)
end
function start_defeated_ui()
  local throttle = 0.25
  uiAS:delaycall(OMEGA_DELAY, function()
    start_omega_ui()
  end)
  levelUI.resetting = true
  levelUI.ffbtn:onClick()
  levelAS:throttle(throttle)
  levelui_hide_hud_buttons()
end
function start_game_over_ui()
  local levelGalaxyIndex, levelSystemIndex = level_get_galaxy_system()
  popups.show("on_g" .. levelGalaxyIndex .. "_s" .. levelSystemIndex .. "_defeat")
  uiAS:delaycall(0.1, function()
    local defeatedString = _("You Are Defeated")
    resetting = uiLayer:add(ui.TextBox.new(defeatedString, FONT_XLARGE, "#ffffff", "center", device.width, 120, true))
    resetting:setColor(1, 1, 1, 1)
    levelUI:add(levelUI.pauseScreen)
    soundmanager.onSFX("onDefeat")
    uiAS:delaycall(2.5, function()
      popups.show("on_g" .. levelGalaxyIndex .. "_s" .. levelSystemIndex .. "_end")
      uiAS:delaycall(0.1, function()
        levelAS:throttle(1)
        popups.clear_queue()
        end_game()
        level_clear()
        menu_show("defeat")
      end)
    end)
  end)
end
local function omega_menu_callback()
  levelAS:pause()
  environmentAS:pause()
  levelUI.inStoreMenu = false
  local cost = levelUI.omegaCost
  local affordable = false
  local profile = get_profile()
  if not (cost <= (profile[OMEGA_RESOURCE_TYPE] or 0)) then
  elseif cost <= (scores[OMEGA_RESOURCE_TYPE] or 0) then
    affordable = true
  end
  if affordable then
    function levelUI.omegaBtn.onClick()
      _onOmegaEnd(true)
    end
  else
    levelUI.omegaBtn.onClick = omega_need_alloy_func
  end
end
local function omega_popup_callback(result)
  if result then
    menu_show("starbank?filter=" .. OMEGA_RESOURCE_TYPE, omega_menu_callback)
  else
    levelUI.inStoreMenu = false
  end
end
function omega_need_alloy_func()
  _popup_currency_show(OMEGA_RESOURCE_TYPE, nil, nil, omega_popup_callback, "omega13")
  levelUI.inStoreMenu = true
end
function start_omega_ui()
  local profile = get_profile()
  levelAS:pause()
  environmentAS:pause()
  local cost = math.min((omegaUsed + 1) * OMEGA_COST, OMEGA_MAX_COST)
  levelUI.omegaCost = cost
  local affordable = false
  if not (cost <= (profile[OMEGA_RESOURCE_TYPE] or 0)) then
  elseif cost <= (scores[OMEGA_RESOURCE_TYPE] or 0) then
    affordable = true
  end
  if affordable then
    function levelUI.omegaBtn.onClick()
      _onOmegaEnd(true)
    end
  else
    levelUI.omegaBtn.onClick = omega_need_alloy_func
  end
  local priceTxt = levelUI.omegaPriceTxt
  local costStr = string.format("(     %d)", levelUI.omegaCost)
  local len = string.len(costStr)
  priceTxt:setString(costStr)
  levelUI:add(levelUI.pauseScreen)
  levelUI:add(levelUI.omega)
  local xMin, yMin, xMax, yMax = priceTxt:getStringBounds(1, 1)
  local ingot = levelUI.omegaIngot
  local w, h = ingot:getSize()
  ingot:setLoc(xMax + w / 2, ingot.yLoc)
  levelUI.omegaTime = OMEGA_TIME
  levelUI.omegaBtn:showPage("down")
  levelUI.omegaBtn:showPage("up")
  levelUI.omegaAction = uiAS:run(_omega_tick)
end
local function _blossom_add_enemy_target(enemy)
  local l = -stageWidth / 2
  local r = stageWidth / 2
  local b = -stageHeight / 2
  local t = stageHeight / 2
  local cx, cy = camera:getLoc()
  local x, y = enemy:getLoc()
  local ox, oy = x, y
  x = x - cx
  y = y - cy
  if not (l > x) and not (r < x) and not (b > y) then
    if t < y then
    else
      do
        local dt = levelUI.blossomDt
        local target = ui.new(MOAIProp2D.new())
        enemy._deathTarget = target
        target:setLoc(ox, oy)
        target:setScl(2, 2)
        target:setColor(0, 0, 0, 0)
        uiAS:delaycall(dt, function()
          mainLayer:add(target)
          uiAS:wrap(target:seekScl(0.5, 0.5, 0.1, MOAIEaseType.LINEAR))
          uiAS:wrap(target:seekColor(1, 1, 1, 1, 0.1, MOAIEaseType.LINEAR))
        end)
        levelUI.iter = (levelUI.iter or 0) + 1
        if levelUI.iter % 5 == 0 then
          levelUI.blossomDt = dt + 0.2
        end
      end
    end
  end
  enemy.tickfn = behavior.enemy_thrust
end
local _blossom_destroy_enemy = function(enemy)
  if enemy._deathTarget then
    do
      local dt = levelUI.blossomDt
      enemy._deathTarget:remove()
      levelAS:delaycall(dt, function()
        enemy:destroy(true)
      end)
      levelUI.blossomDt = dt + 0.1
    end
  else
    enemy:destroy(true)
  end
end
local function _blossom_destroy_enemies()
  levelUI.blossomDt = 0.1
  level_foreach_object_of_type(ALL_ENEMY_TARGET_TYPES, _blossom_destroy_enemy)
  uiAS:wrap(levelUI.blossomBG:seekColor(0, 0, 0, 0, 0.75, MOAIEaseType.LINEAR), function()
    levelUI.blossomBG:remove()
  end)
  uiAS:delaycall(0.1, function()
    levelUI.blossomActive = false
    levelAS:resume()
    levelAS:throttle(1)
  end)
end
local _blossom_menu_callback = function()
  levelUI.inStoreMenu = false
  levelAS:resume()
end
local function _blossom_popup_callback(result)
  if result then
    menu_show("starbank?filter=" .. BLOSSOM_RESOURCE_TYPE, _blossom_menu_callback)
  else
    levelUI.inStoreMenu = false
    levelAS:resume()
  end
end
local function _blossom_need_alloy_func()
  levelUI.activeBlossom:remove()
  levelUI.blossomGroup:add(levelUI.blossomBtn)
  update_cannon_icons()
  levelUI.inStoreMenu = true
  levelUI.ffbtn:onClick()
  _popup_currency_show(BLOSSOM_RESOURCE_TYPE, nil, nil, _blossom_popup_callback, "deathblossom")
  levelAS:pause()
end
function start_death_blossom_ui()
  local profile = get_profile()
  local originalCost = BLOSSOM_COST * (BLOSSOM_CHARGES - blossomCharges + 1)
  local cost = BLOSSOM_COST * (BLOSSOM_CHARGES - blossomCharges + 1)
  local affordable = false
  if not (cost <= (profile[BLOSSOM_RESOURCE_TYPE] or 0)) then
  elseif cost <= (scores[BLOSSOM_RESOURCE_TYPE] or 0) then
    affordable = true
  end
  if affordable then
    cost = math.max(cost - (scores[BLOSSOM_RESOURCE_TYPE] or 0), 0)
    if scores[BLOSSOM_RESOURCE_TYPE] then
      scores[BLOSSOM_RESOURCE_TYPE] = math.max(scores[BLOSSOM_RESOURCE_TYPE] - originalCost, 0)
    end
    if cost > 0 then
      blossomUsed = (blossomUsed or 0) + 1
      profile_currency_txn(BLOSSOM_RESOURCE_TYPE, -cost, string.format("Used: deathblossom.%d", blossomUsed), true)
      set_if_nil(gameSessionAnalytics, "currency", {})
      set_if_nil(gameSessionAnalytics.currency, BLOSSOM_RESOURCE_TYPE, {})
      gameSessionAnalytics.currency[BLOSSOM_RESOURCE_TYPE].spent = (gameSessionAnalytics.currency[BLOSSOM_RESOURCE_TYPE].spent or 0) + cost
    end
    popups.show("on_cred_purchase")
    start_death_blossom()
    achievements.checklist_fail("turkey_plain")
    set_if_nil(gameSessionAnalytics, "specialAbilities", {})
    gameSessionAnalytics.specialAbilities.deathblossom = (gameSessionAnalytics.specialAbilities.deathblossom or 0) + 1
  else
    _blossom_need_alloy_func()
  end
end
function start_death_blossom(noCharge)
  local throttle = 0.25
  levelUI.blossomActive = true
  levelUI.ffbtn:onClick()
  levelAS:throttle(throttle)
  levelUI:add(levelUI.blossomBG)
  local system
  system = mainLayer:add(Particle.new("deathBlossomCharge.pex", uiAS))
  system:setLoc(DEATH_BLOSSOM_X, DEATH_BLOSSOM_Y)
  system:setPriority(100)
  system:updateSystem()
  system:begin(true)
  soundmanager.onSFX("onDeathBlossomChargeup")
  local cx, cy = camera:getLoc()
  uiAS:wrap(levelUI.cannonGroup:seekLoc(0, -128, 0.5, MOAIEaseType.EASE_IN), function()
    if not noCharge then
      blossomCharges = blossomCharges - 1
    end
    levelUI.activeBlossom:remove()
    levelUI.blossomGroup:add(levelUI.blossomBtn)
    update_cannon_icons()
    levelUI.blossomDt = 0.1
    level_foreach_object_of_type(ALL_ENEMY_TARGET_TYPES, _blossom_add_enemy_target)
  end)
  uiAS:delaycall(3, function()
    uiAS:wrap(levelUI.cannonGroup:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN))
    soundmanager.onSFX("onDeathBlossom")
    system:stopSystem()
    system:remove()
    system = mainLayer:add(Particle.new("deathBlossomRing.pex", uiAS))
    system:setLoc(DEATH_BLOSSOM_X, DEATH_BLOSSOM_Y)
    system:setPriority(100)
    system:updateSystem()
    system:begin(true)
    uiAS:wrap(levelUI.blossomBG:seekColor(1, 1, 1, 1, 0.75, MOAIEaseType.LINEAR), function()
      levelAS:pause()
      _blossom_destroy_enemies()
      if not MOAIPexPlugin then
        system:stopSystem()
        system:remove()
        system = nil
      end
    end)
  end)
end
function clear_level_ui_buttons()
  if levelUI.ffing then
    levelUI.ffing = false
  end
  if levelUI.pausing then
    levelUI.pausing = false
  end
end
function slide_hud_bottom(slideOut)
  if slideOut then
    levelUI.cannonGroup:seekLoc(0, -128, 0.5, MOAIEaseType.EASE_IN)
  else
    levelUI.cannonGroup:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
  end
end
function ui_toggle_warp_button(isOn)
  if isOn then
    levelUI.cannonGroup:add(levelUI.buildBtn)
  else
    levelUI.buildBtn:remove()
  end
end
function ui_toggle_blossom_button(isOn)
  if isOn then
    do
      local uiScl = device.ui_scale
      local deviceWidth = device.width * uiScl
      local deviceHeight = device.height * uiScl
      local x = -deviceWidth / 2
      levelUI.cannonGroup:add(levelUI.blossomGroup)
      levelUI.blossomBtn:showPage("down")
      levelUI.blossomBtn:showPage("up")
      local w, h = levelUI.blossomBtn._up:getSize()
      levelUI.blossomBtn:setLoc(x + w / 2 + 18, -deviceHeight / 2 + h / 2 + 18)
      x = x + w
    end
  else
    levelUI.blossomGroup:remove()
  end
end
function ui_update_warp_button()
  local count = level_count_objects_of_type("warp_module")
  levelUI.buildTxt:setString("" .. count)
  if count < 1 then
    function levelUI.buildBtn.onClick()
    end
    levelUI.buildBtn._up:setColor(unpack(UI_FADE_COLOR))
    levelUI.buildTxt:setColor(0, 0, 0, 0.4)
  else
    levelUI.buildBtn.onClick = _buildBtn_onClick
    levelUI.buildBtn._up:setColor(1, 1, 1, 1)
    levelUI.buildTxt:setColor(0, 0, 0, 0.8)
  end
end
function levelui_hide_hud_buttons()
  levelUI.ffbtn:remove()
  levelUI.pausebtn:remove()
  levelUI.cannonGroup:remove()
  if gameMode == "survival" then
    if levelUI.bottomBar ~= nil then
      levelUI.bottomBar:remove()
      levelUI.bottomBar = nil
    end
    local bottomBar = levelUI:add(ui.NinePatch.new("hudBottomBar9p.lua", device.ui_width + 2, 116))
    bottomBar:setLoc(0, -device.ui_height / 2 + 58)
    levelUI.bottomBar = bottomBar
  end
  if device.os == device.OS_ANDROID then
    local callback = function()
      return true
    end
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
end
function levelui_unhide_hud_buttons()
  levelUI:add(levelUI.ffbtn)
  if levelUI.ffbtn.currentPageName == "up" then
    levelUI.ffbtn:showPage("down")
    levelUI.ffbtn:showPage("up")
  elseif levelUI.ffbtn.currentPageName == "down" then
    levelUI.ffbtn:showPage("up")
    levelUI.ffbtn:showPage("down")
  end
  levelUI:add(levelUI.pausebtn)
  if levelUI.pausebtn.currentPageName == "up" then
    levelUI.pausebtn:showPage("down")
    levelUI.pausebtn:showPage("up")
  elseif levelUI.pausebtn.currentPageName == "down" then
    levelUI.pausebtn:showPage("up")
    levelUI.pausebtn:showPage("down")
  end
  levelUI:add(levelUI.cannonGroup)
  levelUI.blossomBtn:showPage("down")
  levelUI.blossomBtn:showPage("up")
  levelUI.buildBtn:showPage("down")
  levelUI.buildBtn:showPage("up")
  for i = 1, 3 do
    local btn = levelUI["perk" .. i .. "Btn"]
    if btn ~= nil then
      btn:showPage("down")
      btn:showPage("up")
    end
  end
  if gameMode == "survival" then
    if levelUI.bottomBar ~= nil then
      levelUI.bottomBar:remove()
      levelUI.bottomBar = nil
    end
    local bottomBar = levelUI:add(ui.NinePatch.new("hudBottomBarSurvival9p.lua", device.ui_width + 2, 116))
    bottomBar:setLoc(0, -device.ui_height / 2 + 58)
    levelUI.bottomBar = bottomBar
  end
  if device.os == device.OS_ANDROID then
    local function callback()
      _pauseBtn_onClick()
      return true
    end
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, callback)
  end
end
function levelui_show_resource_gain(rt)
  if levelUI.resGain == nil then
    do
      local resGain = levelUI:add(ui.Group.new())
      resGain:setLoc(0, -device.ui_height / 2 + 50)
      levelUI.resGain = resGain
      local box = resGain:add(ui.NinePatch.new("messageBox9p.lua"))
      resGain.box = box
      local group, text, icon
      if rt == "alloy" then
        group = box:add(ui.Group.new())
        text = group:add(ui.TextBox.new(util.commasInNumbers((scores.alloy or 0) + profile.alloy), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
        icon = text:add(ui.Image.new("menuTemplateShared.atlas.png#iconAlloyMed.png"))
        resGain.alloyGroup = group
        resGain.alloyText = text
        resGain.alloyIcon = icon
      elseif rt == "creds" then
        group = box:add(ui.Group.new())
        text = group:add(ui.TextBox.new(util.commasInNumbers((scores.creds or 0) + profile.creds), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
        icon = text:add(ui.Image.new("menuTemplateShared.atlas.png#iconCredsMed.png"))
        resGain.credsGroup = group
        resGain.credsText = text
        resGain.credsIcon = icon
      end
      text:setLoc(16, -2)
      icon:setLoc(-text._width / 2 - 20, 2)
      local width = text._width + 32 + 40
      box:setSize(width, 54)
      box.width = width
      resGain.time = 0
      local action
      action = uiAS:run(function(dt)
        if resGain.time < 2 then
          resGain.time = resGain.time + dt
        else
          resGain.action:stop()
          resGain:remove()
          if levelUI ~= nil then
            levelUI.resGain = nil
          end
        end
      end)
      resGain.action = action
    end
  else
    local resGain = levelUI.resGain
    resGain.time = 0
    local box = resGain.box
    if rt == "alloy" then
      if resGain.alloyText ~= nil then
        do
          local group = resGain.alloyGroup
          local text = resGain.alloyText
          local icon = resGain.alloyIcon
          text:setString(util.commasInNumbers((scores.alloy or 0) + profile.alloy), true)
          icon:setLoc(-text._width / 2 - 20, 2)
          local width = text._width + 32 + 40
          if resGain.credsGroup ~= nil then
            width = width + resGain.credsText._width + 32 + 40
          end
          if width ~= box.width then
            box:setSize(width, 54)
            box.width = width
            if resGain.credsGroup ~= nil then
              group:setLoc(-(text._width + 32 + 40) / 2, 0)
              resGain.credsGroup:setLoc((resGain.credsText._width + 32 + 40) / 2, 0)
            end
          end
        end
      else
        local group = box:add(ui.Group.new())
        local text = group:add(ui.TextBox.new(util.commasInNumbers((scores.alloy or 0) + profile.alloy), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
        local icon = text:add(ui.Image.new("menuTemplateShared.atlas.png#iconAlloyMed.png"))
        resGain.alloyGroup = group
        resGain.alloyText = text
        resGain.alloyIcon = icon
        text:setLoc(16, -2)
        icon:setLoc(-text._width / 2 - 20, 2)
        local width = text._width + 32 + 40
        if resGain.credsGroup ~= nil then
          width = width + resGain.credsText._width + 32 + 40
        end
        if width ~= box.width then
          box:setSize(width, 54)
          box.width = width
        end
        if resGain.credsGroup ~= nil then
          group:setLoc(-(text._width + 32 + 20) / 2, 0)
          resGain.credsGroup:setLoc((resGain.credsText._width + 32 + 20) / 2, 0)
        end
      end
    elseif rt == "creds" then
      if resGain.credsText ~= nil then
        do
          local group = resGain.credsGroup
          local text = resGain.credsText
          local icon = resGain.credsIcon
          text:setString(util.commasInNumbers((scores.creds or 0) + profile.creds), true)
          icon:setLoc(-text._width / 2 - 20, 2)
          local width = text._width + 32 + 40
          if resGain.alloyGroup ~= nil then
            width = width + resGain.alloyText._width + 32 + 40
          end
          if width ~= box.width then
            box:setSize(width, 54)
            box.width = width
            if resGain.alloyGroup ~= nil then
              group:setLoc((text._width + 32 + 40) / 2, 0)
              resGain.alloyGroup:setLoc(-(resGain.alloyText._width + 32 + 40) / 2, 0)
            end
          end
        end
      else
        local group = box:add(ui.Group.new())
        local text = group:add(ui.TextBox.new(util.commasInNumbers((scores.creds or 0) + profile.creds), FONT_MEDIUM, "ffffff", "center", nil, nil, true))
        local icon = text:add(ui.Image.new("menuTemplateShared.atlas.png#iconCredsMed.png"))
        resGain.credsGroup = group
        resGain.credsText = text
        resGain.credsIcon = icon
        text:setLoc(16, 0)
        icon:setLoc(-text._width / 2 - 20, 2)
        local width = text._width + 32 + 40
        if resGain.alloyGroup ~= nil then
          width = width + resGain.alloyText._width + 32 + 40
        end
        if width ~= box.width then
          box:setSize(width, 54)
          box.width = width
        end
        if resGain.alloyGroup ~= nil then
          group:setLoc((text._width + 32 + 40) / 2, 0)
          resGain.alloyGroup:setLoc(-(resGain.alloyText._width + 32 + 40) / 2, 0)
        end
      end
    end
  end
end
function levelui_update_survival_perk(num)
  for i, perk in pairs(active_perks) do
    if perk.order == num then
      do
        local btn = levelUI["perk" .. perk.order .. "Btn"]
        btn._up:setImage(string.gsub(perk.icon, ".png$", "Hud.png"))
        btn._down:setImage(string.gsub(perk.icon, ".png$", "Hud.png"))
        btn._up:setColor(1, 1, 1, 1)
        btn._down:setColor(0.5, 0.5, 0.5, 1)
        btn.handleTouch = Button_handleTouch
        function btn.onClick()
          levelAS:pause()
          uiAS:pause()
          environmentAS:pause()
          popup_survival_perks_show(nil, perk)
        end
        if btn._up.mask ~= nil and btn._down.mask ~= nil then
          btn._up.mask:remove()
          btn._up.mask = nil
          btn._down.mask:remove()
          btn._down.mask = nil
        end
        if btn.flashAS ~= nil then
          btn.flashAS:stop()
          btn.flashAS = nil
        end
        if btn.AS ~= nil then
          btn.AS:stop()
          btn.AS = nil
        end
        local maskUp = btn._up:add(ui.RadialImage.new("perksIconMask.png"))
        local maskDown = btn._down:add(ui.RadialImage.new("perksIconMask.png"))
        btn._up.mask = maskUp
        btn._down.mask = maskDown
        maskUp:setArc(HALF_PI, HALF_PI)
        maskDown:setArc(HALF_PI, HALF_PI)
        if perk.startTime == nil then
          perk.startTime = levelAS:getTime()
        end
        btn.AS = levelAS:wrap(function(dt, t)
          local perc = (levelAS:getTime() - perk.startTime) / (perk.duration * 60)
          if perc > 0.95 and perc < 1 then
            if btn.flashAS == nil then
              btn.flashAS = levelAS:repeatcall(0.6, function()
                if btn.flash ~= nil then
                  btn._up:seekColor(1, 1, 1, 1, 0.4, MOAIEaseType.EASE_IN)
                  btn.flash = nil
                else
                  btn._up:seekColor(UI_COLOR_RED[1], UI_COLOR_RED[2], UI_COLOR_RED[3], 1, 0.5, MOAIEaseType.EASE_IN)
                  btn.flash = true
                end
              end)
            end
          elseif perc >= 1 then
            btn._up:setColor(UI_COLOR_RED[1], UI_COLOR_RED[2], UI_COLOR_RED[3], 1)
            btn._down:setColor(UI_COLOR_RED_DARKEN[1], UI_COLOR_RED_DARKEN[2], UI_COLOR_RED_DARKEN[3], 1)
            if btn.flashAS ~= nil then
              btn.flashAS:stop()
              btn.flashAS = nil
            end
            btn.AS:stop()
            btn.AS = nil
            if i == "plusFighters" then
              level_foreach_object_of_type("fighter", function(self)
                if self.def.fighterType == "fighter" then
                  if self.nitro then
                    self.nitro:destroy()
                    self.nitro = nil
                  end
                  if self.def.maxspeed then
                    local speed = self.def.maxspeed
                    self.maxspeed = speed
                    self._maxspeed = speed
                  end
                  if self.def.accel then
                    local speed = self.def.accel
                    self.accel = speed
                    self._accel = speed
                  end
                end
              end)
            elseif i == "plusInterceptors" then
              level_foreach_object_of_type("fighter", function(self)
                if self.def.fighterType == "interceptor" then
                  if self.nitro then
                    self.nitro:destroy()
                    self.nitro = nil
                  end
                  if self.def.maxspeed then
                    local speed = self.def.maxspeed
                    self.maxspeed = speed
                    self._maxspeed = speed
                  end
                  if self.def.accel then
                    local speed = self.def.accel
                    self.accel = speed
                    self._accel = speed
                  end
                end
              end)
            elseif i == "plusBombers" then
              level_foreach_object_of_type("fighter", function(self)
                if self.def.fighterType == "bomber" then
                  if self.nitro then
                    self.nitro:destroy()
                    self.nitro = nil
                  end
                  if self.def.maxspeed then
                    local speed = self.def.maxspeed
                    self.maxspeed = speed
                    self._maxspeed = speed
                  end
                  if self.def.accel then
                    local speed = self.def.accel
                    self.accel = speed
                    self._accel = speed
                  end
                end
              end)
            elseif i == "plusMining" then
              level_foreach_object_of_type("harvester", function(self)
                if self.nitro then
                  self.nitro:destroy()
                  self.nitro = nil
                end
                if self.def.maxspeed then
                  local speed = self.def.maxspeed
                  self.maxspeed = speed
                  self._maxspeed = speed
                end
                if self.def.accel then
                  local speed = self.def.accel
                  self.accel = speed
                  self._accel = speed
                end
              end)
            end
            active_perks[i] = nil
          end
          maskUp:setArc(HALF_PI, HALF_PI - perc * TWO_PI)
          maskDown:setArc(HALF_PI, HALF_PI - perc * TWO_PI)
        end)
        if i == "plusFighters" then
          level_foreach_object_of_type("fighter", function(self)
            if self.def.fighterType == "fighter" and self.nitro == nil then
              if self.def.nitroTexture then
                self.nitro = self.sprite:add(Particle.new(self.def.nitroTexture, levelAS))
                if self.nitro then
                  self.nitro:setPriority(self.priority - 1)
                  levelAS:delaycall(0.1, function()
                    self.nitro:updateSystem()
                    self.nitro:begin()
                  end)
                end
              end
              if self.def.maxspeed then
                local speed = self.def.maxspeed
                speed = speed + speed * active_perks.plusFighters.modifier.speed
                self.maxspeed = speed
                self._maxspeed = speed
              end
              if self.def.accel then
                local speed = self.def.accel
                speed = speed + speed * active_perks.plusFighters.modifier.speed
                self.accel = speed
                self._accel = speed
              end
            end
          end)
        elseif i == "plusInterceptors" then
          level_foreach_object_of_type("fighter", function(self)
            if self.def.fighterType == "interceptor" and self.nitro == nil then
              if self.def.nitroTexture then
                self.nitro = self.sprite:add(Particle.new(self.def.nitroTexture, levelAS))
                if self.nitro then
                  self.nitro:setPriority(self.priority - 1)
                  levelAS:delaycall(0.1, function()
                    self.nitro:updateSystem()
                    self.nitro:begin()
                  end)
                end
              end
              if self.def.maxspeed then
                local speed = self.def.maxspeed
                speed = speed + speed * active_perks.plusInterceptors.modifier.speed
                self.maxspeed = speed
                self._maxspeed = speed
              end
              if self.def.accel then
                local speed = self.def.accel
                speed = speed + speed * active_perks.plusInterceptors.modifier.speed
                self.accel = speed
                self._accel = speed
              end
            end
          end)
        elseif i == "plusBombers" then
          level_foreach_object_of_type("fighter", function(self)
            if self.def.fighterType == "bomber" and self.nitro == nil then
              if self.def.nitroTexture then
                self.nitro = self.sprite:add(Particle.new(self.def.nitroTexture, levelAS))
                if self.nitro then
                  self.nitro:setPriority(self.priority - 1)
                  levelAS:delaycall(0.1, function()
                    self.nitro:updateSystem()
                    self.nitro:begin()
                  end)
                end
              end
              if self.def.maxspeed then
                local speed = self.def.maxspeed
                speed = speed + speed * active_perks.plusBombers.modifier.speed
                self.maxspeed = speed
                self._maxspeed = speed
              end
              if self.def.accel then
                local speed = self.def.accel
                speed = speed + speed * active_perks.plusBombers.modifier.speed
                self.accel = speed
                self._accel = speed
              end
            end
          end)
        elseif i == "plusMining" then
          level_foreach_object_of_type("harvester", function(self)
            if self.nitro == nil then
              if self.def.nitroTexture then
                self.nitro = self.sprite:add(Particle.new(self.def.nitroTexture, levelAS))
                if self.nitro then
                  self.nitro:setPriority(self.priority - 1)
                  levelAS:delaycall(0.1, function()
                    self.nitro:updateSystem()
                    self.nitro:begin()
                  end)
                end
              end
              if self.def.maxspeed then
                local speed = self.def.maxspeed
                speed = speed + speed * active_perks.plusMining.modifier.speed
                self.maxspeed = speed
                self._maxspeed = speed
              end
              if self.def.accel then
                local speed = self.def.accel
                speed = speed + speed * active_perks.plusMining.modifier.speed
                self.accel = speed
                self._accel = speed
              end
            end
          end)
        end
        return
      end
    end
  end
  local btn = levelUI["perk" .. num .. "Btn"]
  btn._up:setImage("menuIconsPerks.atlas.png#perksIconEmpty.png")
  btn._down:setImage("menuIconsPerks.atlas.png#perksIconEmpty.png")
  btn._up:setColor(UI_COLOR_RED[1], UI_COLOR_RED[2], UI_COLOR_RED[3], 1)
  btn._down:setColor(UI_COLOR_RED_DARKEN[1], UI_COLOR_RED_DARKEN[2], UI_COLOR_RED_DARKEN[3], 1)
  btn.handleTouch = Button_handleTouch
  function btn.onClick()
    levelAS:pause()
    uiAS:pause()
    environmentAS:pause()
    popup_survival_perks_show()
  end
  if btn._up.mask ~= nil and btn._down.mask ~= nil then
    btn._up.mask:remove()
    btn._up.mask = nil
    btn._down.mask:remove()
    btn._down.mask = nil
  end
  if btn.flashAS ~= nil then
    btn.flashAS:stop()
    btn.flashAS = nil
  end
  if btn.AS ~= nil then
    btn.AS:stop()
    btn.AS = nil
  end
  if not active_perks.plusFighters then
    level_foreach_object_of_type("fighter", function(self)
      if self.def.fighterType == "fighter" then
        if self.nitro then
          self.nitro:destroy()
          self.nitro = nil
        end
        if self.def.maxspeed then
          local speed = self.def.maxspeed
          self.maxspeed = speed
          self._maxspeed = speed
        end
        if self.def.accel then
          local speed = self.def.accel
          self.accel = speed
          self._accel = speed
        end
      end
    end)
  end
  if not active_perks.plusInterceptors then
    level_foreach_object_of_type("fighter", function(self)
      if self.def.fighterType == "interceptor" then
        if self.nitro then
          self.nitro:destroy()
          self.nitro = nil
        end
        if self.def.maxspeed then
          local speed = self.def.maxspeed
          self.maxspeed = speed
          self._maxspeed = speed
        end
        if self.def.accel then
          local speed = self.def.accel
          self.accel = speed
          self._accel = speed
        end
      end
    end)
  end
  if not active_perks.plusBombers then
    level_foreach_object_of_type("fighter", function(self)
      if self.def.fighterType == "bomber" then
        if self.nitro then
          self.nitro:destroy()
          self.nitro = nil
        end
        if self.def.maxspeed then
          local speed = self.def.maxspeed
          self.maxspeed = speed
          self._maxspeed = speed
        end
        if self.def.accel then
          local speed = self.def.accel
          self.accel = speed
          self._accel = speed
        end
      end
    end)
  end
  if not active_perks.plusMining then
    level_foreach_object_of_type("harvester", function(self)
      if self.nitro then
        self.nitro:destroy()
        self.nitro = nil
      end
      if self.def.maxspeed then
        local speed = self.def.maxspeed
        self.maxspeed = speed
        self._maxspeed = speed
      end
      if self.def.accel then
        local speed = self.def.accel
        self.accel = speed
        self._accel = speed
      end
    end)
  end
end
