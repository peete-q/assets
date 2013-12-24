local device = require("device")
local resource = require("resource")
local compat = require("moai.compat")
local metatable = require("metatable")
local ui = require("ui")
local angle = require("angle")
local math2d = require("math2d")
local DynLineStrip = require("DynLineStrip")
local HealthBar = require("HealthBar")
local Ribbon = require("Ribbon")
local gfxutil = require("gfxutil")
local behavior = require("behavior")
local url = require("url")
local color = require("color")
local entitydef = require("entitydef")
local soundmanager = require("soundmanager")
local SoundInstance = require("SoundInstance")
local perkdef = require("PerkDef")
local util = require("util")
local popups = require("popups")
local Particle = require("Particle")
local achievements = require("achievements")
local table_remove = table.remove
local table_insert = table.insert
local table_concat = table.concat
local breakstr = util.breakstr
local set_if_nil = util.set_if_nil
local _debug, _warn, _error = require("qlog").loggers("Entity")
local Entity = {}
Entity.__index = Entity
local deg = math.deg
local atan2 = math.atan2
local normalize = math2d.normalize
local dot = math2d.dot
local distance = math2d.distance
local distanceSq = math2d.distanceSq
local cos = math.cos
local sin = math.sin
local random = math.random
local min = math.min
local max = math.max
local ceil = math.ceil
local floor = math.floor
local TWO_PI = math.pi * 2
local HALF_PI = math.pi / 2
local P = function(x, y)
  return "(" .. tostring(x) .. "," .. tostring(y) .. ")"
end
local EntitySprite = {}
EntitySprite.__index = EntitySprite
function EntitySprite:onLayerChanged(layer)
  if self.hpBar then
    if layer then
      layer:add(self.hpBarContainer)
    else
      self.hpBarContainer:remove()
    end
  end
  if layer then
    layer:forceUpdate()
    self:forceUpdate()
  end
end
local function detonate_damage_with_crit(ship, dmg, self, critRangeSq, critMult)
  if ship.shield then
    local x, y = self:getLoc()
    local tx, ty = ship:getLoc()
    local rot = math.rad(ship:getRot())
    local tdx, tdy = cos(rot + ship.shieldAngle), sin(rot + ship.shieldAngle)
    local _tdx, _tdy = normalize(x - tx, y - ty)
    local angle = math.acos(dot(tdx, tdy, _tdx, _tdy))
    if angle <= ship.shieldHalfAngle then
      return
    end
  end
  if critRangeSq >= ship:distanceSq(self) then
    dmg = dmg * critMult
    self.criticalCount = (self.criticalCount or 0) + 1
  end
  local x, y = ship:getLoc()
  level_fx_explosion(x, y, 8, ship.sprite._uilayer, ARTILLERY_HIT_FX)
  local result = ship:applyDamage(dmg, self)
  if result == false then
    enemies_destroyed.via_artillery = (enemies_destroyed.via_artillery or 0) + 1
  end
  if self.cannon and self.cannon.def.type == "cannon" then
    level_cannon_hit_enemy()
  end
end
local function salvage_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  if eventType == ui.TOUCH_DOWN then
    if self.lastTouchIdx then
      return false
    end
    self.lastTouchIdx = touchIdx
    ui.capture(self)
    return true
  elseif eventType == ui.TOUCH_MOVE then
  elseif eventType == ui.TOUCH_UP then
    if self.lastTouchIdx ~= touchIdx then
      return false
    end
    ui.capture()
    do
      local entity = self.entity
      self.lastTouchIdx = nil
      local rt = entity.def.resourceType
      local resValue = entity.def.resourceValue
      if rt == "alloy" and active_perks.plusAlloy then
        resValue = resValue + resValue * active_perks.plusAlloy.modifier
      end
      entity:floatie("+" .. resValue, entity.def.resourceTexture)
      scores[rt] = (scores[rt] or 0) + (resValue or 1)
      if lootPickupTimer[rt] == nil then
        lootPickupTimer[rt] = levelAS:delaycall(2, function()
          profile_currency_txn(rt, lootPickupTimer[rt].resValue, "Salvage", true)
          lootPickupTimer[rt] = nil
        end)
        lootPickupTimer[rt].resValue = resValue or 1
      else
        local timerValue = lootPickupTimer[rt].resValue
        lootPickupTimer[rt]:stop()
        lootPickupTimer[rt] = nil
        lootPickupTimer[rt] = levelAS:delaycall(2, function()
          profile_currency_txn(rt, lootPickupTimer[rt].resValue, "Salvage", true)
          lootPickupTimer[rt] = nil
        end)
        lootPickupTimer[rt].resValue = timerValue + (resValue or 1)
      end
      soundmanager.onSFX("onAwardpickup")
      entity:destroy()
      set_if_nil(gameSessionAnalytics, "currency", {})
      set_if_nil(gameSessionAnalytics.currency, rt, {})
      gameSessionAnalytics.currency[rt].earned = (gameSessionAnalytics.currency[rt].earned or 0) + (resValue or 1)
      return true
    end
  end
end
local function tesla_onTouch(self, eventType, touchIdx, x, y, tapCount)
  local entity = self.sprite.entity
  if entity.firing or entity.recharging or entity.resetting then
    return false
  end
  local turret = entity.turret
  local path = entity:affirmPath()
  if eventType == ui.TOUCH_DOWN then
    if self.lastTouchIdx then
      return true
    end
    self.lastTouchIdx = touchIdx
    self.lastTouchX = x
    self.lastTouchY = y
    self.startTouchX = x
    self.startTouchY = y
    self.sprite.lastScl = self.sprite:getScl()
    self.sprite:setScl(self.sprite.lastScl * 1.5, self.sprite.lastScl * 1.5)
    turret.lastScl = turret:getScl()
    turret:setScl(turret.lastScl * 0.66, turret.lastScl * 0.66)
    ui.capture(self)
    return true
  elseif eventType == ui.TOUCH_MOVE then
    if self.lastTouchIdx ~= touchIdx then
      return true
    end
    if self.outOfBounds then
      return true
    end
    if not entity.capturingPath then
    elseif distance(x, y, self.startTouchX or 0, self.startTouchY or 0) >= entity.def.collisionRadius then
      local _x, _y = self:modelToWorld(x, y)
      local tx, ty = turret:getWorldLoc()
      if not entity.capturingPath then
        entity:pathCaptureBegin(true)
        path:append(_x, _y, true)
      else
        path.points[#path.points - 1] = _x
        path.points[#path.points] = _y
        path:update()
      end
      local dir = deg(atan2(_y - ty, _x - tx))
      turret:setRot(dir - 90)
    end
    self.lastTouchX = x
    self.lastTouchY = y
    return true
  elseif eventType == ui.TOUCH_UP then
    if self.lastTouchIdx ~= touchIdx then
      return true
    end
    if self.sprite.lastScl then
      self.sprite:setScl(self.sprite.lastScl, self.sprite.lastScl)
      turret:setScl(turret.lastScl, turret.lastScl)
    end
    self.lastTouchIdx = nil
    if self.outOfBounds then
      self.outOfBounds = false
      ui.capture(nil, self)
    elseif not entity.capturingPath then
      ui.capture(nil, self)
      return false
    else
      entity:pathCaptureEnd()
      path.penWidth = PATH_ACTIVE_WIDTH
      path:update()
      entity.firing = true
      entity.fireTime = 0
      local points = path.points
      local _x, _y = self:modelToWorld(x, y)
      entity.targetX = points[#points - 1]
      entity.targetY = points[#points]
      local entityX, entityY = entity:getWorldLoc()
      entity.targetDist = math2d.distance(entityX, entityY, entity.targetX, entity.targetY)
      local rot = turret:getRot()
      entity.targetDX = cos(math.rad(rot + 90))
      entity.targetDY = sin(math.rad(rot + 90))
    end
    return true
  end
end
local function pathing_onTouch(self, eventType, touchIdx, x, y, tapCount)
  local entity = self.sprite.entity
  local path = entity:affirmPath()
  if eventType == ui.TOUCH_DOWN then
    if self.lastTouchIdx then
      return true
    end
    self.lastTouchIdx = touchIdx
    self.lastTouchX = x
    self.lastTouchY = y
    self.startTouchX = x
    self.startTouchY = y
    self.sprite.lastScl = self.sprite:getScl()
    self.sprite:setScl(self.sprite.lastScl * 1.5, self.sprite.lastScl * 1.5)
    if path ~= nil then
      path.penWidth = PATH_ACTIVE_WIDTH
      path:update()
    end
    do
      local overlay = self.sprite.moduleOverlay
      if overlay then
        self.sprite:add(overlay)
      end
      ui.capture(self)
      return true
    end
  elseif eventType == ui.TOUCH_MOVE then
    if self.lastTouchIdx ~= touchIdx then
      return true
    end
    if self.outOfBounds then
      return true
    end
    if entity.capturingPath and path:len() >= PATH_MAX_USER_POINTS then
      return true
    end
    if not entity.capturingPath then
    elseif distance(x, y, self.startTouchX or 0, self.startTouchY or 0) >= PATH_DRAG_THRESHOLD then
      if not entity.capturingPath then
        entity:pathCaptureBegin(true)
      end
      local _x, _y = self:modelToWorld(x, y)
      path.penWidth = PATH_ACTIVE_WIDTH
      path:append(_x, _y, true)
    end
    self.lastTouchX = x
    self.lastTouchY = y
    return true
  elseif eventType == ui.TOUCH_UP then
    if self.lastTouchIdx ~= touchIdx then
      return true
    end
    local overlay = self.sprite.moduleOverlay
    if overlay then
      overlay:remove()
    end
    if self.sprite.lastScl then
      self.sprite:setScl(self.sprite.lastScl, self.sprite.lastScl)
    end
    self.lastTouchIdx = nil
    if self.outOfBounds then
      self.outOfBounds = false
      ui.capture(nil, self)
    elseif not entity.capturingPath then
      if path ~= nil then
        path.penWidth = PATH_INACTIVE_WIDTH
        path:update()
      end
      ui.capture(nil, self)
      return false
    else
      local endIcon = entity.pathEndIcon
      if endIcon and #path.points > 3 then
        mothershipLayer:add(endIcon)
        local lastX, lastY = path.points[#path.points - 1], path.points[#path.points]
        local prevX, prevY = path.points[#path.points - 3], path.points[#path.points - 2]
        local dir = atan2(lastY - prevY, lastX - prevX) - HALF_PI
        local w, h = endIcon:getSize()
        w = w / 2 - 1
        h = h / 2 - 1
        endIcon:setLoc(lastX + h * -sin(dir), lastY + w * cos(dir))
        endIcon:setRot(deg(dir))
      end
      soundmanager.onSetPatrol()
      self.lastTouchX = nil
      self.lastTouchY = nil
      if entity.def.ai == "harvester_module" then
        entity.target = nil
        entity.targetScanTime = 1
        entity.endIconActive = true
      end
      entity:pathCaptureEnd()
      set_if_nil(gameSessionAnalytics, "pathsDrawn", {})
      gameSessionAnalytics.pathsDrawn[entity.def.hangarInventoryType] = (gameSessionAnalytics.pathsDrawn[entity.def.hangarInventoryType] or 0) + 1
    end
    return true
  end
end
local _launch = function(self)
  if self.progressBar then
    self.progressBar:remove()
    self.progressBar = nil
  end
  local o = level_spawn_object(self.def.launchType)
  local x, y = self:getWorldLoc()
  o:setLoc(x, y)
  o:setRot(90)
  o.launchBay = self
  self:addActiveChildCount(1)
  return o
end
function launchbay_can_activate(self)
  if self.launchMaxConcurrent ~= nil then
    local current = self.activeChildCount
    if current >= self.launchMaxConcurrent then
      return false, "Max: " .. self.launchMaxConcurrent
    end
  end
  local def = entitydef[self.def.launchType]
  local cost = self.launchResourceCost or def.buildCost
  if cost ~= nil then
    local costStr = {}
    for rt, amount in pairs(cost) do
      local v = scores[rt] or 0
      if amount > v then
        return false, string.format("Need: %d", amount - v)
      end
    end
  end
  if self.progressBar then
    return false, "Busy"
  end
  return true
end
function launchbay_launch(self, dragX, dragY)
  local ok, errmsg = launchbay_can_activate(self)
  if not ok then
    print("Not launching: ", errmsg)
    return
  end
  local def = entitydef[self.def.launchType]
  local cost = self.launchResourceCost or def.buildCost
  if cost ~= nil then
    local costStr = {}
    for rt, amount in pairs(cost) do
      scores[rt] = (scores[rt] or 0) - amount
      table_insert(costStr, tostring(-amount))
    end
    local wx, wy = self:getWorldLoc()
    level_fx_floatie(wx, wy + MODULE_WORLD_SIZE * 0.25, table_concat(costStr, ", "))
  end
  if def.buildTime then
    print("building ", def._id, " in ", def.buildTime, "on", self)
    do
      local pbar = mainLayer:add(ui.PickBox.new(1, 16, "yellow"))
      pbar.handleTouch = nil
      pbar:setColor(0.5, 0.5, 0.5, 0.5)
      self:forceUpdate()
      local _x, _y = self:getWorldLoc()
      pbar:setLoc(_x - 30, _y)
      self.progressBar = pbar
      levelAS:wrap(pbar:seekScl(60, 1, def.buildTime, MOAIEaseType.LINEAR))
      levelAS:wrap(pbar:seekLoc(_x, _y, def.buildTime, MOAIEaseType.LINEAR))
      levelAS:delaycall(def.buildTime, function()
        self.progressBar:remove()
        self.progressBar = nil
        print("launching ", def._id)
        _launch(self)
      end)
    end
  else
    local o = _launch(self)
    if o.def.type == "fighter" or o.def.type == "missile" then
      o:pathCaptureBegin(dragX ~= nil and dragY ~= nil)
    end
  end
end
local launchbay_handleTouch = {
  onTouchDown = function(self, touchIdx, x, y, tapCount)
    self.touchX = x
    self.touchY = y
    self.launched = false
    ui.capture(self)
    return true
  end,
  onTouchMove = function(self, touchIdx, x, y, tapCount)
    if distance(x, y, self.touchX or x, self.touchY or y) >= ui.DRAG_THRESHOLD then
      ui.capture(nil)
      if not self.launched then
        self.launched = true
        launchbay_launch(self, x, y)
      end
    end
    return true
  end,
  onTouchUp = function(self, touchIdx, x, y, tapCount)
    ui.capture(nil)
    if not self.launched then
      self.launched = true
      launchbay_launch(self)
    end
    return true
  end
}
function hangarbay_can_activate(self)
  local def = entitydef[self.def.hangarInventoryType]
  local cost = def.buildCost
  if cost ~= nil then
    local costStr = {}
    for rt, amount in pairs(cost) do
      local v = scores[rt] or 0
      if amount > v then
        return false, string.format("Need: %d", amount - v)
      end
    end
  end
  if self.hangarCapacity ~= nil then
    if (self.unitCount or 0) >= self.hangarCapacity then
      return false, "Full"
    end
  end
  return true
end
function hangarbay_activate(self)
  local ok, errmsg = hangarbay_can_activate(self)
  if not ok then
    local wx, wy = self:getWorldLoc()
    level_fx_floatie(wx, wy + MODULE_WORLD_SIZE * 0.25, errmsg)
    return false
  end
  local def = entitydef[self.def.hangarInventoryType]
  local cost = def.buildCost
  if cost ~= nil then
    local costStr = {}
    for rt, amount in pairs(cost) do
      scores[rt] = (scores[rt] or 0) - amount
      table_insert(costStr, tostring(-amount))
    end
    local wx, wy = self:getWorldLoc()
    level_fx_floatie(wx, wy + MODULE_WORLD_SIZE * 0.25, table_concat(costStr, ", "))
  end
  self:addInventoryCount(1)
end
local hangarbay_handleTouch = {
  onTouchDown = function(self, touchIdx, x, y, tapCount)
    self.touchX = x
    self.touchY = y
    ui.capture(self)
    return true
  end,
  onTouchMove = function(self, touchIdx, x, y, tapCount)
    if distance(x, y, self.touchX or x, self.touchY or y) >= ui.DRAG_THRESHOLD then
      ui.capture(nil)
      if not self.launched then
        self.launched = true
        launchbay_launch(self, x, y)
      end
    end
    return true
  end,
  onTouchUp = function(self, touchIdx, x, y, tapCount)
    ui.capture(nil)
    if not self.launched then
      self.launched = true
      launchbay_launch(self)
    end
    return true
  end
}
local _turnSpeedFromRadius = function(r)
  local MAX_R = 150
  local MIN_R = 20
  if r < MIN_R then
    r = MIN_R
  elseif MAX_R < r then
    r = MAX_R
  end
  local a = 1 - (r - MIN_R) / (MAX_R - MIN_R)
  return 10 + a * 170
end
local entitycompat_getWorldLoc = function(self)
  return self.sprite:getWorldLoc()
end
local entitycompat_getWorldDir = function(self)
  return self.sprite:getWorldDir()
end
local R2D = 180 / math.pi
local D2R = math.pi / 180
local function entitycompat_getRot(self)
  return self:getAngle() * R2D
end
local function entitycompat_setRot(self, r)
  return self:setAngle(r * D2R)
end
local function entitycompat_addRot(self, r)
  return self:setAngle(self:getAngle() + r * D2R)
end
local entitycompat_addLoc = function(self, dx, dy)
  local x, y = self:getPos()
  x = x + dx
  y = y + dy
  self:setPos(x, y)
end
local entitycompat_add = function(self, elem)
  return self.sprite:add(elem)
end
local entitycompat_remove = function(self, ...)
  return self.sprite:remove(...)
end
function Entity.new(mgr, def, opts, parentEntity)
  local self, tickfn
  if def.ai ~= nil then
    tickfn = behavior[def.ai]
    assert(tickfn ~= nil, "invalid AI type: " .. tostring(def.ai))
  end
  self = MOAICpBody.new()
  local scl = def.scl or 1
  if RELEASE_MODE then
    _warn("Entity [" .. def._id .. "] is using scale factor: " .. scl)
  end
  if def.collisionRadius ~= nil then
    self.collisionRadius = def.collisionRadius * scl
    do
      local shape = self:addCircle(def.collisionRadius * scl)
      shape:setIsSensor(true)
      levelSpace:insertPrim(shape)
    end
  else
    self.collisionRadius = 0
  end
  self.def = def
  self.tickfn = tickfn
  self._uiname = tostring(mgr:_nextEntityId()) .. "_[" .. def._id .. "]"
  metatable.copyinto(self, Entity)
  self.add = entitycompat_add
  self.setLoc = self.setPos
  self.addLoc = entitycompat_addLoc
  self.getLoc = self.getPos
  self.getRot = entitycompat_getRot
  self.addRot = entitycompat_addRot
  self.setRot = entitycompat_setRot
  self.getWorldLoc = entitycompat_getWorldLoc
  self.getWorldDir = entitycompat_getWorldDir
  self.modelToWorld = self.localToWorld
  self.worldToModel = self.worldToLocal
  self.remove = entitycompat_remove
  local sprite = ui.new(MOAIProp2D.new())
  sprite:setScl(scl, scl)
  self.sprite = sprite
  metatable.copyinto(sprite, EntitySprite)
  sprite.entity = self
  sprite:setParent(self)
  if def.type == "module" or def.type:find("cannon") then
    self.priority = 3
  elseif def.type ~= "capitalship" and def.type ~= "enemyc" and def.type ~= "asteroid" then
    self.priority = 6
  else
    self.priority = 1
  end
  sprite:setPriority(self.priority)
  if def.ribbon then
    local ribbon = levelAS:wrap(sprite:add(Ribbon.new(def.ribbon)))
    levelAS:wrap(ribbon.system)
    ribbon._uiname = self._uiname .. " ribbon"
    ribbon:setPriority(-1)
    ribbon.system:setPriority(-1)
    self.ribbon = ribbon
  end
  if def.texture then
    gfxutil.addAssets(sprite, def.texture, self._uiname .. " texture")
  end
  if def.anim then
    local animTexture, queryStr = breakstr(def.anim, "?")
    self.anim = ui.Anim.new(def.anim)
    local showAnim = false
    if queryStr ~= nil then
      local q = url.parse_query(queryStr)
      if q.anim then
        self.animName = q.anim
      end
      if q.showAnim then
        showAnim = true
      end
    end
    if showAnim then
      self:showAnim()
    end
  end
  if def.damageTextures then
    local damageTextures = def.damageTextures
    self.damageStates = {}
    local damageStates = self.damageStates
    self.curDamageState = 0
    for k, v in ipairs(damageTextures) do
      local damagename = " damageTexture" .. k
      damageStates[k] = ui.new(MOAIProp2D.new())
      damageStates[k]:setPriority(self.priority)
      gfxutil.addAssets(damageStates[k], damageTextures[k], self._uiname .. damagename)
    end
  end
  gfxutil.addImages(sprite, def.icon, self._uiname .. " icon")
  self._mgr = mgr
  self._next = nil
  self._prev = nil
  mgr:_addEntityToIndex(self)
  self.hp = def.hp
  self.maxHp = def.hp
  if self.hp ~= nil and not def.hpHidden then
    sprite.hpBar = HealthBar.new(def.hpBarLarge, self.hp, def.hpBarFlash, def.type)
    sprite.hpBar:setLoc(0, self.collisionRadius + 20)
    local g = ui.Group.new()
    g:add(sprite.hpBar)
    sprite.hpBar:setPriority(10)
    sprite.hpBarContainer = g
  end
  local pathR, pathG, pathB
  if def.pathColor then
    pathR, pathG, pathB = color.parse(def.pathColor)
  end
  local galIdx, sysIdx, galSysIdx = level_get_galaxy_system()
  if def.hangarInventoryType ~= nil then
    local htype = entitydef[def.hangarInventoryType]
    self.unitCountLabel = sprite:add(ui.TextBox.new("0", FONT_MEDIUM_BOLD, "ff0000", "center", nil, nil, true))
    self.unitCountLabel:setString("0")
    self.unitCountLabel:setLoc(-1, -5)
    self.unitCountLabel:setPriority(self.priority + 2)
    self.unitCountLabel:setScl(1 / scl, 1 / scl)
    if def.pathColor then
      sprite:setColor(pathR, pathG, pathB, 1)
    end
    local cost = htype.buildCost.blue
    --do break end
    if cost then
      local squadPriceTag = sprite:add(ui.Image.new("hud.atlas.png#squadPriceTag.png"))
      squadPriceTag:setPriority(self.priority + 2)
      squadPriceTag:setLoc(0, -68)
      squadPriceTag:setScl(1 / scl, 1 / scl)
      local icon = squadPriceTag:add(ui.Image.new("menuTemplateShared.atlas.png#iconCrystalSmall.png"))
      icon:setLoc(-16, 0)
      icon:setPriority(self.priority + 2)
      local costTxt = squadPriceTag:add(ui.TextBox.new("" .. cost, FONT_SMALL_BOLD, "#000000", "center"))
      costTxt:setLoc(9, -3)
      costTxt:setPriority(self.priority + 2)
      costTxt:setColor(0, 0, 0, 1)
    end
    self.hangarCapacity = def.hangarCapacity
    if self.hangarCapacity then
      self:addInventoryCount(self.hangarCapacity)
    end
  end
  if def.weaponFireTexture ~= nil then
    self.muzzleFlash = ui.new(MOAIProp2D.new())
    self.muzzleFlash:setPriority(self.priority)
    gfxutil.addAssets(self.muzzleFlash, def.weaponFireTexture, self._uiname .. "flash")
    if def.weaponLoc then
      self.muzzleFlash:setLoc(unpack(def.weaponLoc))
    end
    self.muzzleFlash.stopAssets = gfxutil.stopAssets
    self.muzzleFlash.playAssets = gfxutil.playAssets
  end
  if def.deathSfx ~= nil then
    self.deathSfx = SoundInstance.new(def.deathSfx, nil, nil, true)
  end
  if def.weaponFireSfx ~= nil then
    self.muzzleFlashSfx = SoundInstance.new(def.weaponFireSfx)
  end
  if def.weaponImpactSfx ~= nil then
    self.impactSfx = SoundInstance.new(def.weaponImpactSfx)
  end
  if def.depositSfx ~= nil then
    self.depositSfx = SoundInstance.new(def.depositSfx)
  end
  if def.weaponTexture ~= nil then
    local id, queryStr = breakstr(def.weaponTexture, "?")
    if queryStr ~= nil then
      local q = url.parse_query(queryStr)
      if q.scl ~= nil then
        local scl = tonumber(q.scl)
        self.weaponScl = scl
      end
      if q.rot ~= nil then
        local rot = tonumber(q.rot)
        self.weaponRot = rot
      end
      if q.alpha ~= nil then
        self.weaponAlpha = tonumber(q.alpha)
      end
    end
  end
  if def.turretTexture ~= nil then
    self.turret = sprite:add(ui.Image.new(def.turretTexture))
    self.turret:setPriority(self.priority + 1)
    if def.teslaMode then
      self.turretBeam = ui.Image.new(def.weaponTexture)
      self.turretBeam.length = self.turretBeam:getSize()
      self.turretBeam:setColor(1, 1, 1, 0)
      self.turret:setPriority(self.priority + 3)
      self.turretBeam:setPriority(self.priority + 1)
      self.turretMuzzleFlash = Particle.new(def.teslaMuzzleFlash, levelAS)
      self.turretMuzzleFlash:setPriority(self.priority + 2)
      self.turretMuzzleLoc = def.tesslaMuzzleFlashPos
      self.turretFireEnd = Particle.new(def.teslaFireEnd, levelAS)
      self.turretFireEnd:setPriority(self.priority + 2)
      self.teslaFireTime = def.teslaFireTime or TESLA_FIRE_TIME or 1
      self.turretOverlay = sprite:add(ui.Image.new(def.turretOverlay))
      self.reloadingOverlay = ui.RadialImage.new(def.moduleOverlay)
      self.turretOverlay:setPriority(self.priority + 4)
      if def.pathColor then
        self.turretOverlay:setColor(pathR, pathG, pathB, 1)
      end
    end
  end
  if def.shieldDamping ~= nil then
    local shieldSize = 64
    local shieldTex = def.shieldTexture or "shieldPrototype.png"
    if self.collisionRadius < 54 then
      shieldTex = "shieldPrototypeSmall.png"
      shieldSize = 32
    end
    self.shield = sprite:add(ui.RadialImage.new(shieldTex))
    local a = math.rad(def.shieldArc / 2)
    local sa = math.rad(def.shieldAngle or 0)
    self.shieldHalfAngle = a
    self.shieldAngle = sa
    self.shield:setArc(sa - a, sa + a)
    local sc = self.collisionRadius / shieldSize * 1.2
    self.shield:setScl(sc, sc)
  end
  if def.turnSpeed == true then
    self.turnSpeed = _turnSpeedFromRadius(self.collisionRadius)
  elseif type(def.turnSpeed) == "number" then
    self.turnSpeed = def.turnSpeed
  end
  if def.nitroTexture then
    if def.type == "fighter" then
      if def.fighterType == "fighter" and active_perks.plusFighters or def.fighterType == "interceptor" and active_perks.plusInterceptors or def.fighterType == "bomber" and active_perks.plusBombers then
        self.nitro = self.sprite:add(Particle.new(def.nitroTexture, levelAS))
      end
    elseif def.type == "harvester" and active_perks.plusMining then
      self.nitro = self.sprite:add(Particle.new(def.nitroTexture, levelAS))
    end
    if self.nitro then
      self.nitro:setPriority(self.priority - 1)
    end
  end
  if def.maxspeed then
    local speed = def.maxspeed
    if def.type == "fighter" then
      if def.fighterType == "fighter" and active_perks.plusFighters then
        speed = speed + speed * active_perks.plusFighters.modifier.speed
      elseif def.fighterType == "interceptor" and active_perks.plusInterceptors then
        speed = speed + speed * active_perks.plusInterceptors.modifier.speed
      elseif def.fighterType == "bomber" and active_perks.plusBombers then
        speed = speed + speed * active_perks.plusBombers.modifier.speed
      end
    elseif def.type == "harvester" and active_perks.plusMining then
      speed = speed + speed * active_perks.plusMining.modifier.speed
    end
    self.maxspeed = speed
    self._maxspeed = speed
  end
  if def.accel then
    local speed = def.accel
    if def.type == "fighter" then
      if def.fighterType == "fighter" and active_perks.plusFighters then
        speed = speed + speed * active_perks.plusFighters.modifier.speed
      elseif def.fighterType == "interceptor" and active_perks.plusInterceptors then
        speed = speed + speed * active_perks.plusInterceptors.modifier.speed
      elseif def.fighterType == "bomber" and active_perks.plusBombers then
        speed = speed + speed * active_perks.plusBombers.modifier.speed
      end
    elseif def.type == "harvester" and active_perks.plusMining then
      speed = speed + speed * active_perks.plusMining.modifier.speed
    end
    self.accel = speed
    self._accel = speed
  end
  if def.harvestRate then
    local rate = def.harvestRate
    if active_perks.plusCrystals then
      rate = rate - rate * active_perks.plusCrystals.modifier
    end
    self.harvestRate = rate
  end
  if def.moduleOverlay ~= nil then
    self.moduleOverlay = ui.Image.new(def.moduleOverlay)
    if def.pathColor then
      self.moduleOverlay:setColor(pathR, pathG, pathB, 1)
    end
    self.moduleOverlay:setPriority(self.priority + 1)
  end
  local dpiOffset
  if def.pathingMode or def.teslaMode then
    self.pathEndIcon = ui.Image.new(def.pathEndIcon or "hud.atlas.png#pathEnd.png")
    if def.pathColor then
      local pathA = def.pathAlpha or 1
      self.pathEndIcon:setColor(pathR * pathA, pathG * pathA, pathB * pathA, pathA)
    end
    do
      local tex
      local moduleOverlay = self.moduleOverlay
      if def.pathingMode then
        tex = ui.Image.new(self.def.texture)
      else
        tex = ui.Image.new(def.moduleOverlay)
      end
      local w, h = tex:getSize()
      local pathbox = self:add(ui.PickBox.new(w, w))
      pathbox:setPriority(100)
      pathbox:setRot(45)
      pathbox.sprite = sprite
      if def.pathingMode then
        pathbox.handleTouch = pathing_onTouch
        self.buildBar = ui.FillBar.new({
          UI_UNIT_BUILD_BAR_LENGTH * device.ui_scale,
          UI_UNIT_BUILD_BAR_HEIGHT * device.ui_scale
        }, def.pathColor)
        self.buildBar:setLoc(0, -29)
      else
        pathbox.handleTouch = tesla_onTouch
      end
      sprite.pathbox = pathbox
      if USE_MODULE_DPI then
        local touchScl = device.dpi * device.ui_scale * SQUAD_SELECTOR_WIDTH_INCHES
        local newScl = math.max(scl, touchScl / SQUAD_SELECTOR_SIZE_PIXELS)
        sprite.scl = newScl
        sprite:setScl(sprite.scl)
        dpiOffset = newScl / scl
      end
    end
  elseif def.launchType ~= nil then
    assert(entitydef[def.launchType] ~= nil, "EntityDef not found: " .. def.launchType)
    sprite.handleTouch = launchbay_handleTouch
  elseif def.salvageTouch ~= nil then
    sprite.handleTouch = salvage_handleTouch
  else
    sprite.handleTouch = nil
  end
  if def.hangarInventoryType ~= nil and def.hangarManualBuild then
    self.onActivate = hangarbay_activate
  end
  self.spawnTime = mgr:getTime()
  if def.spawnLifetime ~= nil then
    self.spawnExpirationTime = self.spawnTime + def.spawnLifetime
  end
  if def.subentities ~= nil then
    self.subentities = {}
    for i = 1, #def.subentities do
      local id, queryStr = breakstr(def.subentities[i], "?")
      local o
      if queryStr ~= nil then
        o = url.parse_query(queryStr)
      end
      local d = entitydef[id]
      assert(d ~= nil, "Invalid submodule idref: " .. tostring(id))
      if not d.commandModule or gameMode == "survival" or galSysIdx >= TUT_MIN_HARVESTER_SYSTEM then
        local e = Entity.new(mgr, d, o, self)
        sprite:add(e.sprite)
        table_insert(self.subentities, e)
      end
    end
  end
  if opts ~= nil then
    if opts.loc ~= nil then
      local x, y = breakstr(opts.loc, ",")
      x, y = tonumber(x), tonumber(y)
      if dpiOffset then
        x = x * dpiOffset
        y = y * dpiOffset
      end
      self.sprite:setLoc(x, y)
    end
    if opts.rot ~= nil then
      self:setRot(tonumber(opts.rot))
    end
  end
  local baseID = def._id:gsub("_%d$", "")
  popups.show("on_ship_spawn_" .. baseID)
  return self
end
function Entity:addToSquad(squad)
  if squad[self] == nil then
    local score = self.def.scoreValue
    squad.curpoints = squad.curpoints + score
    squad.totalpoints = squad.totalpoints + score
    squad[self] = score
  end
end
function Entity:removeFromSquad(squad)
  if squad == nil then
    squad = self.squad
    if squad == nil then
      return
    end
  end
  local score = squad[self]
  if score == nil then
    return
  end
  local old = squad.curpoints
  squad.curpoints = math.max(0, squad.curpoints - score)
  squad[self] = nil
  local fleefn = behavior.flee_offscreen
  local pct = squad.curpoints / squad.totalpoints
  for s, v in pairs(squad) do
    local b = s.bravery or 1
    if b < 1 and pct >= b then
      s.tickfn = fleefn
    end
  end
end
function Entity:addAssets(assets)
  assert(type(assets) == "string" or type(assets) == "table", "ERROR: Trying to add an invalid asset type to Entity's Texture")
  gfxutil.addAssets(self.sprite, assets, self._uiname .. " texture")
end
function Entity:addDamageStates(damageTextures)
  if not self.damageStates and type(damageTextures) == "table" then
    self.damageStates = {}
    local damageStates = self.damageStates
    self.curDamageState = 0
    local d = 0
    for k, v in ipairs(damageTextures) do
      local damagename = " damageTexture" .. k
      damageStates[k] = ui.new(MOAIProp2D.new())
      damageStates[k]:setPriority(self.priority)
      gfxutil.addAssets(damageStates[k], damageTextures[k], self._uiname .. damagename)
    end
  end
end
function Entity:destroy(withEffects, source)
  if self.subentities ~= nil then
    local subentities = self.subentities
    self.subentities = nil
    for i = 1, #subentities do
      subentities[i]:destroy(withEffects)
    end
  end
  local layer = self.sprite._uilayer
  if withEffects then
    local x, y = self:getWorldLoc()
    local defType = self.def.type
    if self.def.scoreValue ~= nil and not self.noXP then
      local score = self.def.scoreValue
      local baseScore = scores.score or 0
      if SURVIVAL_MODE_FF_SCORE_MULTIPLIER and levelUI.ffing then
        scores.score = math.floor(baseScore + score * SURVIVAL_MODE_FF_SCORE_MULTIPLIER)
      else
        scores.score = baseScore + score
      end
      local xp = math.floor((baseScore + score) / SCORE_XP_THRESHOLD) - math.floor(baseScore / SCORE_XP_THRESHOLD)
      if xp > 0 then
        if gameMode == "survival" then
          if levelSurvivorWave >= SURVIVAL_MODE_XP_MOD_THRESHOLD then
            xp = math.floor(xp * (SURVIVAL_MODE_XP_MODIFIER or 1))
          end
          if active_perks.plusXP then
            xp = xp + math.floor(xp * active_perks.plusXP.modifier)
          end
        end
        level_fx_floatie(x, y, "+" .. xp .. " XP", nil, nil, FONT_SMALL, 1)
        scores.xp = (scores.xp or 0) + xp
      end
      if gameMode == "survival" then
        local calculate_bonus_alloy = function(score)
          local n = 1
          local bonusScore = (n - 1) * n * SURVIVAL_MODE_BONUS_ALLOY_MODIFIER + SURVIVAL_MODE_BONUS_ALLOY_MODIFIER
          while score > bonusScore do
            n = n + 1
            bonusScore = (n - 1) * n * SURVIVAL_MODE_BONUS_ALLOY_MODIFIER + SURVIVAL_MODE_BONUS_ALLOY_MODIFIER
          end
          return bonusScore, n
        end
        if SURVIVAL_MODE_BONUS_ALLOY_MODIFIER ~= nil and 0 < SURVIVAL_MODE_BONUS_ALLOY_MODIFIER then
          local bonusScore, n = calculate_bonus_alloy(baseScore)
          if baseScore < bonusScore and bonusScore <= scores.score then
            local rt = "bonusAlloy"
            local resValue = math.floor(n * SURVIVAL_MODE_BONUS_ALLOY_MULTIPLIER)
            scores[rt] = (scores[rt] or 0) + (resValue or 1)
          end
        end
      end
      enemies_destroyed[self.def.type] = (enemies_destroyed[self.def.type] or 0) + 1
    end
    if self.deathSfx then
      if defType == "capitalship" or defType == "enemyc" then
        self.deathSfx:play()
      else
        soundmanager.onImpact()
      end
    end
    local _size = self.collisionRadius
    local deathfx = self.def.deathfx
    if deathfx then
      for k, v in pairs(deathfx) do
        local _ex, _ey = math2d.randomPointInCircle(x, y, _size / 3)
        level_fx_explosion(_ex, _ey, _size / 2, self.sprite._uilayer, v)
      end
    end
    local dropMod
    if source then
      dropMod = source.def.resourceDropMod
    end
    level_spawn_loot_at(self.def.lootDrop, dropMod, x, y, _size * 1.5)
    if self ~= commandShip and defType == "capitalship" then
      local o = level_spawn_object("spawning_module", mothershipLayer)
      o.hangarInventoryType = self.def._id
      local x, y = self:getWorldLoc()
      o:setLoc(x, y)
      level_update_max_dc()
    end
    local chainParent = self.chainParent
    if chainParent then
      if self.def.type == "survivor" then
        chainParent:clearTowedObjects()
      else
        chainParent:removeTowObject(self)
      end
    end
    self:spawnWreckage()
    local baseID = self.def._id:gsub("_%d$", "")
    popups.show("on_ship_killed_" .. baseID)
    if gameMode == "survival" and self.def._id == ACHIEVEMENTS_SURVIVAL_KILL_1_ID then
      achievements.checklist_check("survival_kill_1")
    end
  end
  self:clearTowedObjects()
  if self.hp ~= nil then
    self.hp = 0
  end
  self:destroyPath()
  self:clearNavPoint()
  self:clearOffscreenIndicator()
  self._mgr:_removeEntityFromIndex(self, withEffects)
  if self.anim ~= nil then
    self.anim:stop()
  end
  if self.launchBay ~= nil then
    self.launchBay:addActiveChildCount(-1)
  end
  if self.parentModule ~= nil then
    assert(self.parentModule.occupier == self, "hm, parentModule got out of sync somehow!")
    self.parentModule.occupier = nil
  end
  if self.ribbon then
    self.ribbon:destroy()
    self.ribbon = nil
  end
  if self.nitro then
    self.nitro:destroy()
    self.nitro = nil
  end
  if self.turretBeam then
    self.turretBeam:remove()
  end
  if self.turretBeamParticle then
    self.turretBeamParticle:destroy()
    self.turretBeamParticle = nil
  end
  if self.turretMuzzleFlash then
    self.turretMuzzleFlash:destroy()
    self.turretMuzzleFlash = nil
  end
  if self.turretFireEnd then
    self.turretFireEnd:destroy()
    self.turretFireEnd = nil
  end
  if self.afterBurner then
    self.afterBurner:destroy()
    self.afterBurner = nil
  end
  if self.pathEndIcon then
    self.pathEndIcon:remove()
  end
  if self.sprite.healthBar then
    self.sprite.hpBarContainer:remove()
    self.sprite.healthBar:destroy()
    self.sprite.healthBar = nil
    self.sprite.hpBarContainer = nil
  end
  if self.muzzleFlash then
    gfxutil.removeAssets(self.muzzleFlash)
    self.muzzleFlash = nil
  end
  if self.turret then
    self.turret = nil
  end
  self:removeFromSquad()
  gfxutil.removeAssets(self.sprite)
  if self.damageStates then
    for _, v in pairs(self.damageStates) do
      gfxutil.removeAssets(v)
      v:remove()
    end
    self.damageStates = nil
  end
  self:remove()
  self.mgr = nil
  self.lastAttacker = nil
  self.target = nil
  self.fleeTarget = nil
  self.defendTarget = nil
  self.primaryTarget = nil
  self.buildTarget = nil
  self.launchBay = nil
  self.maker = nil
  self.cannon = nil
  self._prev = nil
  self._next = nil
end
function Entity:_updateUnitCount()
  self.unitCount = (self.inventoryCount or 0) + (self.activeChildCount or 0)
  if self.unitCountLabel ~= nil then
    self.unitCountLabel:setString(string.format("%d", self.unitCount))
  end
end
function Entity:addActiveChildCount(value)
  self.activeChildCount = (self.activeChildCount or 0) + value
  self:_updateUnitCount()
end
function Entity:addInventoryCount(value)
  self.inventoryCount = (self.inventoryCount or 0) + value
  self:_updateUnitCount()
end
function Entity:updateSurvivorTowSpeed()
  local chain = self.towedObjects
  if chain ~= nil then
    local pod = chain[#chain]
    if pod and pod.def and pod.def.type == "survivor" then
      local weight = pod.def.towedObjectWeight
      local str = (self.harvesterChain or 0) + 1
      local maxspeed = self._maxspeed or self.def.maxspeed
      local step = maxspeed / weight
      local speed = math.floor(str * step)
      local rem = str - weight
      local bonus = math.max(0, math.floor(rem * maxspeed * 0.1))
      self.maxspeed = math.min(speed, maxspeed) + bonus
      for i = 1, #chain - 1 do
        local obj = chain[i]
        obj.maxspeed = self.maxspeed
      end
    end
  end
end
function Entity:updateTowedObjects(dt, t)
  local chain = self.towedObjects
  local linkLen = 32
  if chain ~= nil and #chain > 0 then
    local obj = chain[#chain]
    if obj.def == nil or obj.def.type ~= "survivor" then
      do
        local cp = chain[1]
        local x, y = self:getLoc()
        local dx, dy = self:getWorldDir()
        local firstLinkLen = self.collisionRadius + cp.towRadius
        cp:setLoc(x - dx * firstLinkLen, y - dy * firstLinkLen)
        local rotMod = 90
        if cp.def and cp.def.type == "harvester" then
          rotMod = 0
        end
        cp:setRot(self:getRot() + rotMod)
        for i = 2, #chain do
          local c = chain[i]
          local _x, _y = cp:getLoc()
          local x, y = c:getLoc()
          local dx, dy, len = normalize(_x - x, _y - y)
          local dlen = len - (c.towRadius + cp.towRadius)
          c:addLoc(dx * dlen, dy * dlen)
          c:setRot(deg(atan2(dy, dx)) + rotMod)
          cp = c
        end
      end
    elseif dt ~= nil and t ~= nil then
      local cp = obj
      local _x, _y = self:getLoc()
      local x, y = cp:getLoc()
      local dx, dy, len = normalize(_x - x, _y - y)
      local dlen = len - (self.collisionRadius + cp.towRadius)
      cp:addLoc(dx * dlen, dy * dlen)
      local rotMod = 90
      if cp.def and cp.def.type == "harvester" then
        rotMod = 0
      end
      cp:setRot(deg(atan2(dy, dx)) + rotMod)
      for i = 1, #chain - 1 do
        local c = chain[i]
        if c.def ~= nil then
          if c.defendTarget == nil then
            c.defendTarget = obj
          end
          if c.targetHead == nil then
            c.targetHead = self
          end
          if c.defendOffsetAngle == nil then
            c.defendOffsetAngle = random() * math.pi - HALF_PI
            local rep = true
            local tries = 10
            while rep do
              rep = false
              for i = 1, #chain - 1 do
                local v = chain[i]
                if v ~= c and v.defendOffsetAngle ~= nil and math.abs(v.defendOffsetAngle - c.defendOffsetAngle) < math.pi / 12 then
                  rep = true
                  c.defendOffsetAngle = random() * math.pi - HALF_PI
                  break
                end
              end
              tries = tries - 1
              if tries <= 0 then
                break
              end
            end
          end
          behavior.pushing_miner(c, dt, t)
          c:updateTowedObjects(dt, t)
        else
          local _x, _y = self:getLoc()
          local x, y = c:getLoc()
          local dx, dy, len = normalize(_x - x, _y - y)
          local dlen = len - (c.towRadius + self.collisionRadius)
          c:addLoc(dx * dlen, dy * dlen)
          c:setRot(deg(atan2(dy, dx)) + rotMod)
        end
      end
    end
  end
end
function Entity:clearTowedObjects()
  if self.towedObjects == nil then
    return
  end
  for i, c in ipairs(self.towedObjects) do
    if c.def then
      c.tickfn = c._unchainedfn
      c.chainParent = nil
      c.maxspeed = c._maxspeed
      c.defendTarget = nil
      c.targetHead = nil
      c.defendOffsetAngle = nil
    else
      c.towShip = nil
      c:remove()
    end
  end
  self.maxspeed = self._maxspeed
  self.towedObjects = nil
  self.towedObjectWeight = nil
  self.towingSurvivor = nil
  self.harvesterChain = nil
end
function Entity:isTowFull()
  if self.towedObjects == nil then
    return false
  end
  local chainMax = self.def.towedObjectMax
  return chainMax ~= nil and (chainMax <= #self.towedObjects or chainMax <= self.towedObjectWeight) or self.towingSurvivor
end
function Entity:appendTowObject(obj)
  local sourceDef = obj.def
  local chainTex = sourceDef.towedObjectTexture
  local chainMax = self.def.towedObjectMax
  local chain = self.towedObjects
  local objType = obj.def.type
  if objType == "survivor" or objType == "harvester" then
    do
      local weight = 0
      if chain == nil then
        chain = {}
        self.towedObjects = chain
        self.towedObjectWeight = 0
      end
      if objType == "survivor" then
        self.towingSurvivor = true
        table_insert(chain, obj)
      else
        self.harvesterChain = (self.harvesterChain or 0) + 1
        table_insert(chain, #chain, obj)
      end
      obj._unchainedfn = obj.tickfn
      obj.tickfn = nil
      obj.chainParent = self
      obj.towRadius = obj.def.collisionRadius
      self:updateSurvivorTowSpeed()
      self:updateTowedObjects()
    end
  elseif chainMax ~= nil and chainTex ~= nil and (chain == nil or chainMax > #chain) then
    local weight = 0
    if chain == nil then
      chain = {}
      self.towedObjects = chain
      self.towedObjectWeight = weight + (sourceDef.towedObjectWeight or 0)
    elseif sourceDef.towedObjectMax ~= nil or chainMax ~= nil then
      local count = 0
      for i = 1, #chain do
        local tdef = chain[i].towSourceDef
        if tdef == sourceDef then
          count = count + 1
        end
        weight = weight + (tdef.towedObjectWeight or 0)
      end
      if sourceDef.towedObjectMax ~= nil and count >= sourceDef.towedObjectMax then
        return nil
      end
    end
    obj:destroy()
    local c = self.sprite._uilayer:add(ui.Image.new(chainTex))
    c.towShip = self
    c.towRadius = sourceDef.towedObjectRadius or 32
    c.towSourceDef = sourceDef
    self.towedObjectWeight = weight + (sourceDef.towedObjectWeight or 0)
    if chainMax ~= nil and chainMax < self.towedObjectWeight then
      self.maxspeed = (self._maxspeed or self.def.maxspeed) / 2
    else
      self.maxspeed = self._maxspeed
    end
    table_insert(chain, c)
    self:updateTowedObjects()
    return c
  end
  return nil
end
function Entity:removeTowObject(obj)
  local chain = self.towedObjects
  if chain ~= nil then
    for i = 1, #chain do
      local c = chain[i]
      if c == obj then
        if c.def then
          c.chainParent = nil
          c.tickfn = c._unchainedfn
          if c.def.type == "survivor" then
            self.towingSurvivor = false
          else
            self.harvesterChain = (self.harvesterChain or 1) - 1
          end
          self:updateSurvivorTowSpeed()
        else
          c.towShip = nil
          c:remove()
        end
        table_remove(chain, i)
        if #chain == 0 then
          self.towedObjects = {}
        end
        return obj
      end
    end
  end
  return nil
end
function Entity:bankTowedResources()
  local count = 0
  local chain = self.towedObjects
  if chain ~= nil then
    local i = 1
    local blueVal = 0
    local blueValExcess = 0
    while i <= #chain do
      do
        local c = chain[i]
        if c.def then
          if c.def.type == "survivor" then
            local rt = c.def.resourceType
            if rt ~= nil then
              if rt == "health" and commandShip and commandShip:isAlive() then
                do
                  local hpLeftOver = commandShip.hp + (c.def.resourceValue or 0.15) * (commandShip.maxHp or commandShip.def.hp) - (commandShip.maxHp or commandShip.def.hp)
                  if hpLeftOver > 0 then
                    local extraCrystals = floor(hpLeftOver * 0.5)
                    if maxDC then
                      local extraCrystalsExcess = (scores.blue or 0) + extraCrystals - min((scores.blue or 0) + extraCrystals, maxDC)
                      extraCrystals = extraCrystals - extraCrystalsExcess
                      blueValExcess = blueValExcess + extraCrystalsExcess
                    end
                    scores.blue = (scores.blue or 0) + extraCrystals
                    blueVal = blueVal + extraCrystals
                    if maxDC then
                      scores.blue = min(scores.blue, maxDC)
                    end
                  end
                  if commandShip.curDamageState == #commandShip.damageStates then
                    achievements.checklist_check("deaths_door")
                  end
                  level_foreach_object_of_type("capitalship", function(obj, value, tex)
                    local val = (value or 0.15) * obj.def.hp
                    local _x, _y = obj:getLoc()
                    obj:applyDamage(-val)
                    obj:floatie("+" .. val .. " " .. _("HP"), tex, FONT_SMALL)
                    local explosionFx
                    if obj == commandShip then
                      explosionFx = "spcHeal01.pex"
                    else
                      explosionFx = "capShipHeal01.pex"
                    end
                    level_fx_explosion(_x, _y, 10, obj.sprite._uilayer, explosionFx)
                  end, c.def.resourceValue, c.def.resourceTexture)
                end
              else
                scores[rt] = (scores[rt] or 0) + (c.def.resourceValue or 1)
                self:floatie("+" .. c.def.resourceValue, c.def.resourceTexture)
              end
            end
            self.towingSurvivor = false
            if self.launchBay.endIconActive then
              self.launchBay.endIconActive = false
              self.launchBay.pathEndIcon:remove()
            end
            c.unkillable = true
            c.hp = 0
            c.chainParent:clearTowedObjects()
            levelAS:wrap(c.sprite:seekColor(0, 0, 0, 0, 0.5), function()
              c:destroy()
            end)
            set_if_nil(gameSessionAnalytics, "rescues", {})
            gameSessionAnalytics.rescues.success = (gameSessionAnalytics.rescues.success or 0) + 1
            popups.show("on_survivor_saved")
          end
          i = i + 1
          count = count + 1
        else
          local rt = c.towSourceDef.resourceType
          if rt ~= nil then
            do
              local resVal = c.towSourceDef.resourceValue or 1
              if rt == "blue" and maxDC then
                local resValExcess = (scores.blue or 0) + resVal - min((scores.blue or 0) + resVal, maxDC)
                resVal = resVal - resValExcess
                blueValExcess = blueValExcess + resValExcess
              end
              scores[rt] = (scores[rt] or 0) + resVal
              if rt == "blue" and maxDC then
                blueVal = blueVal + resVal
                scores[rt] = math.min(scores[rt], maxDC)
              end
              c.towShip = nil
              c:remove()
              table_remove(chain, i)
              count = count + 1
              popups.show("on_resource_banked")
            end
          else
            i = i + 1
          end
        end
      end
    end
    if blueVal > 0 then
      self:floatie("+" .. blueVal, "menuTemplateShared.atlas.png#iconCrystalMed.png")
      set_if_nil(gameSessionAnalytics, "currency", {})
      set_if_nil(gameSessionAnalytics.currency, "crystals", {})
      gameSessionAnalytics.currency.crystals.earned = (gameSessionAnalytics.currency.crystals.earned or 0) + blueVal
      if blueValExcess > 0 then
        gameSessionAnalytics.currency.crystals.excess = (gameSessionAnalytics.currency.crystals.excess or 0) + blueValExcess
      end
    end
    if #chain == 0 then
      self:clearTowedObjects()
    end
  end
  if count > 0 then
    local depositSfx = self.depositSfx
    if depositSfx then
      depositSfx:play()
    end
    return true
  end
  return false
end
local MODULE_RADIUS = MODULE_WORLD_SIZE / 2
local _deploy_to_module = function(deployType, m)
  print("deploying ", deployType, "to", m)
  local newobj = level_spawn_object(deployType, mothershipLayer)
  local _x, _y = m:getWorldLoc()
  newobj:setLoc(_x, _y)
  newobj.parentModule = m
  m.occupier = newobj
  return newobj
end
function Entity:deployCrate(crate)
  local tt
  if crate ~= nil then
    tt = crate.towSourceDef.deployTargetType or "blank"
  end
  local m = self:getObjectUnderShip(tt)
  if m == nil then
    print("no module under ship")
    return false
  end
  if m.occupier ~= nil then
    return false
  end
  if crate == nil then
    local chain = self.towedObjects
    if chain ~= nil then
      for i = 1, #chain do
        local c = chain[i]
        if c.towSourceDef.deployTargetType == m.moduleType then
          crate = c
          break
        end
      end
    end
    if crate == nil then
      print("no deployable crates for ", m.moduleType)
      return false
    end
  end
  local sourceDef = crate.towSourceDef
  local deployType = sourceDef.deployType
  crate.towEntity:removeTowObject(crate)
  if sourceDef.deployTime ~= nil and sourceDef.deployTime > 0 then
    do
      local placeholder = m:add(ui.Image.new(sourceDef.deployTexture))
      placeholder.deployType = deployType
      placeholder.parentModule = m
      m.occupier = placeholder
      local time = sourceDef.deployTime
      print("deploying ", deployType, " in ", time, "on", m)
      local pbar = mainLayer:add(ui.PickBox.new(1, 16, "yellow"))
      pbar.handleTouch = nil
      pbar:setColor(0.5, 0.5, 0.5, 0.5)
      placeholder:forceUpdate()
      local _x, _y = placeholder:getWorldLoc()
      pbar:setLoc(_x - 30, _y)
      placeholder.progressBar = pbar
      levelAS:wrap(pbar:seekScl(60, 1, time, MOAIEaseType.LINEAR))
      levelAS:wrap(pbar:seekLoc(_x, _y, time, MOAIEaseType.LINEAR))
      levelAS:delaycall(time, function()
        placeholder.progressBar:remove()
        placeholder.progressBar = nil
        _deploy_to_module(deployType, m)
      end)
    end
  else
    _deploy_to_module(deployType, m)
  end
  return true
end
function Entity:activate()
  local onActivate = self.onActivate or self.def.onActivate
  if type(onActivate) == "function" then
    return onActivate(self)
  elseif onActivate ~= nil then
    local activateFn = self[onActivate]
    if activateFn then
      return activateFn(self)
    end
  end
  return nil
end
local _first_module = function(obj)
  if obj.moduleType ~= nil then
    return true, obj
  end
end
function Entity:getObjectUnderShip(_type)
  local x, y = self:getWorldLoc()
  local r = MODULE_RADIUS
  local found, m = level_foreach_object_of_type_in_circle(_type, x, y, r, _first_module)
  if found then
    return m
  end
  return nil
end
function Entity:affirmPath()
  if self.path == nil then
    local col
    local a = self.def.pathAlpha
    if a then
      do
        local r, g, b = color.parse(self.def.pathColor)
        if r ~= nil then
          col = color.toHex(r * a, g * a, b * a, a)
        end
      end
    else
      col = self.def.pathColor
    end
    self.path = DynLineStrip.new(nil, col)
    self.path:setPriority(5)
    self.path.maxPoints = MAX_PATH_POINTS
    self.path.handleTouch = false
    self.path.penWidth = 1
    self.path.handleTouch = false
    self.path._uiname = self._uiname .. " path"
    if self.sprite and self.sprite._uilayer then
      self.sprite._uilayer:add(self.path)
    elseif self._uilayer then
      self._uilayer:add(self.path)
    end
  end
  return self.path
end
function Entity:pathCaptureBegin(isDragging, startX, startY)
  local path = self:affirmPath()
  if self.pathEndIcon then
    self.pathEndIcon:remove()
  end
  path.penWidth = PATH_ACTIVE_WIDTH
  self:resetPath()
  if isDragging then
    do
      local x, y = startX, startY
      if x == nil or y == nil then
        x, y = self:getWorldLoc()
      end
      path:append(x, y, true)
      ui.capture(self.sprite.pathbox)
      self.capturingPath = true
      activePathCapturer = self
    end
  else
    self:pathCaptureEnd()
  end
end
function Entity:pathCaptureInject(dx, dy)
  if self.capturingPath then
    local path = self.path
    local n = path:len()
    if n < PATH_MAX_USER_POINTS then
      local x, y = path:get(n)
      path:set(n, x + dx, y + dy)
      path:update()
    end
  end
end
function Entity:pathCaptureEnd()
  local wasCapturing = self.capturingPath
  self.capturingPath = nil
  activePathCapturer = nil
  if self.path ~= nil then
    self.path.penWidth = PATH_INACTIVE_WIDTH
    self.path:update()
  end
  ui.capture(nil, self.sprite.pathbox)
  if wasCapturing then
    do
      local n = self.path:len()
      local x0, y0 = self.path:get(1)
      local x1, y1 = self.path:get(n)
      if distance(x0, y0, x1, y1) <= PATH_LOOP_THRESHOLD then
        self.path.closed = true
      else
        self.path.closed = false
      end
      self.path:smooth()
      self.path:update()
      local halfPathLen = self:affirmPath():distance() / 2
      level_foreach_object(function(obj)
        if obj.launchBay == self and obj.pathTrackDist ~= nil and obj.pathTrackDist > halfPathLen then
          local d = halfPathLen + math.random() * halfPathLen
          obj.pathTrackDist = d
        end
      end)
    end
  end
end
function Entity:resetPath()
  if self.path ~= nil then
    self.path:clear()
    self.path:update()
  end
  if self.capturingPath then
    ui.capture(nil, self)
    self.capturingPath = nil
    activePathCapturer = nil
  end
  self.actionOnPathComplete = nil
end
function Entity:destroyPath()
  if self.path ~= nil then
    self.path:remove()
    self:resetPath()
    self.path = nil
  end
end
function Entity:setNavPoint(x, y)
  if self.navIndicator == nil then
    self.navIndicator = hudLayer:add(ui.Image.new(self.def.navPointTexture or "nav_marker.png"))
    self.navIndicator:setPriority(-1)
  end
  self.navIndicator:setLoc(x, y)
  self.travelLock = nil
end
function Entity:setNavPointWithAction(x, y)
  self:resetPath()
  self:setNavPoint(x, y)
  self.actionOnPathComplete = true
end
function Entity:clearNavPoint()
  if self.navIndicator ~= nil then
    self.navIndicator:remove()
    self.navIndicator = nil
  end
  self.travelLock = nil
end
function Entity:floatie(text, icon, font)
  local x, y = self:getWorldLoc()
  level_fx_floatie(x, y + self.collisionRadius, text, nil, icon, font)
end
function Entity:detonate(x, y)
  if x == nil then
    x, y = self:getWorldLoc()
  end
  local impactTexture = self.def.weaponImpactTexture
  if not active_perks.plusCannon or self.def.type == "alien_missile" then
    if impactTexture then
      do
        local impactType = type(impactTexture)
        if impactType == "string" then
          level_fx_explosion(x, y, 8, self.sprite._uilayer, impactTexture)
        elseif impactType == "table" then
          for _, v in pairs(impactTexture) do
            level_fx_explosion(x, y, 8, self.sprite._uilayer, v)
          end
        end
      end
    else
      level_fx_explosion(x, y, self.def.weaponRange, mainLayer, self.def.weaponTexture)
    end
  end
  soundmanager.onImpact()
  self:destroy()
  local critRangeSq = 225
  self.criticalCount = nil
  local damage = self.def.weaponDamage
  if active_perks.plusCannon and self.def.type ~= "alien_missile" then
    damage = damage + damage * active_perks.plusCannon.modifier.damage
    level_fx_explosion(x, y, self.def.weaponRange, mainLayer, "artilleryImpactCenterNitro.pex")
    level_fx_explosion(x, y, self.def.weaponRange, mainLayer, "artilleryImpactRingNitro.pex")
  end
  level_foreach_object_of_type_in_circle(self.def.targetTypes or ARTILLERY_TARGET_TYPES, x, y, self.def.weaponRange, detonate_damage_with_crit, damage, self, critRangeSq, 4)
  if self.criticalCount ~= nil then
    level_fx_floatie(x, y, _("Direct Hit!"), "fff")
    do
      local marksman = achievements.checklist_get("marksman") or 0
      achievements.checklist_set("marksman", marksman + 1)
    end
  else
    local marksman = achievements.checklist_get("marksman") or 0
    if marksman < 5 then
      achievements.checklist_set("marksman", 0)
    end
  end
end
function Entity:affirmOffscreenIndicator()
  local ind = self.offscreenIndicator
  if ind == nil then
    ind = uiLayer:add(ui.Image.new(self.def.offscreenIndicatorTexture))
    local w, h = ind:getSize()
    w = w / 2
    h = h / 2
    if self.def.offscreenIndicatorNoRot then
      ind.w, ind.h = w, h
    else
      ind.w, ind.h = w, w
    end
    ind:setPriority(25)
    self.offscreenIndicator = ind
    ind.ship = self
  end
  return ind
end
function Entity:clearOffscreenIndicator()
  if self.offscreenIndicator ~= nil then
    self.offscreenIndicator:remove()
    self.offscreenIndicator.ship = nil
    self.offscreenIndicator = nil
    self.offscreenIndicatorColor = nil
  end
end
function Entity:accelerate(dt)
  local s = self.speed or 0
  local a = self.accel or self.def.accel or 10
  s = s + a * dt
  local maxspeed = self.maxspeed or self.def.maxspeed
  if s > maxspeed then
    s = maxspeed
  end
  self.speed = s
  return s
end
function Entity:isAlive()
  return self.sprite._uilayer ~= nil
end
function Entity:isInRange(target, range, fov)
  if target == nil then
    return false
  end
  if target.hp ~= nil and target.hp <= 0 then
    return false
  end
  if range == nil then
    range = self.def.weaponRange
  end
  if fov == nil then
    fov = self.def.weaponFOV
  end
  local x, y = self:getWorldLoc()
  local _x, _y = target:getWorldLoc()
  local Tx, Ty, T = normalize(_x - x, _y - y)
  local _r = target.collisionRadius + range
  if T <= _r then
    if not fov then
      return true, T
    end
    local wdx, wdy = self:getWorldDir()
    if fov <= dot(wdx, wdy, Tx, Ty) then
      return true, T
    end
  end
  return false
end
function Entity:distance(other)
  local x, y = self:getWorldLoc()
  local _x, _y = other:getWorldLoc()
  return distance(x, y, _x, _y)
end
function Entity:distanceSq(other)
  local x, y = self:getWorldLoc()
  local _x, _y = other:getWorldLoc()
  return distanceSq(x, y, _x, _y)
end
function Entity:update(dt)
  local update = self._update
  if update then
    update(self, dt)
  end
end
function Entity:hasMorePath()
  local path = self.path
  if path == nil or path:len() == 1 then
    return false
  end
  return true
end
function Entity:applyDamage(amount, source)
  if self.sprite._uilayer == nil then
    return false
  end
  if self.hp == nil then
    return true
  end
  if amount == nil then
    print(debug.traceback())
  end
  if self.unkillable and self.hp - amount <= 0 then
    return true
  end
  self.hp = math.min(self.hp - amount, self.maxHp or self.def.hp)
  if self.hp <= 0 then
    self.hp = 0
    self:destroy(true, source)
    return false
  end
  local curDamageState
  if self.curDamageState then
    curDamageState = self:updateDamageState()
  end
  local emitOnDamage = self.def.emitPerHealth
  if emitOnDamage ~= nil then
    self.emitHp = (self.emitHp or 0) + amount
    local emitDef = entitydef[self.def.emitType]
    local radius = 100
    local x, y = self:getLoc()
    while emitOnDamage < self.emitHp do
      self.emitHp = self.emitHp - emitOnDamage
      local a = random() * TWO_PI
      local _x = radius * cos(a)
      local _y = radius * sin(a)
      local o = level_spawn_object(emitDef)
      o:setLoc(x + _x, y + _y)
    end
  end
  if self.sprite.hpBar then
    local warning
    if self == commandShip and curDamageState and curDamageState == #self.damageStates then
      warning = true
    end
    self.sprite.hpBar:update(self.hp, nil, warning)
  end
  if self.def.type == "capitalship" and amount > 0 then
    achievements.checklist_fail("nodamage")
  end
  return true
end
function Entity:updateDamageState()
  local perHp = self.hp / (self.maxHp or self.def.hp)
  local curState
  local fn = self.damageStateFunc
  if fn then
    curState = fn(self, perHp)
  else
    curState = #self.damageStates - ceil(perHp * (#self.damageStates + 1) - 1)
  end
  if curState ~= self.curDamageState then
    if self.curDamageState > 0 then
      self.damageStates[self.curDamageState]:remove()
      gfxutil.stopAssets(self.damageStates[self.curDamageState])
    end
    if curState > 0 then
      self:add(self.damageStates[curState])
      gfxutil.playAssets(self.damageStates[curState])
      if self.def.sfxOnChangeState then
        soundmanager.onSFX("onConstruction")
      end
    end
    self.curDamageState = curState
  end
  return curState
end
function Entity:showAnim()
  if not self.anim then
    return
  end
  self:add(self.anim)
end
function Entity:loopAnim()
  if not self.anim then
    return
  end
  self:add(self.anim)
  levelAS:wrap(self.anim:loop(self.animName))
end
function Entity:stopAnim()
  if not self.anim then
    return
  end
  self.anim:remove()
  self.anim:stop()
end
function Entity:spawnWreckage()
  local deathObjs = self.def.deathObjs
  if deathObjs then
    if self == commandShip then
      commandShipParts = {}
    end
    for k, v in pairs(deathObjs) do
      local id, queryStr = breakstr(v, "?")
      local q = {}
      if queryStr ~= nil then
        q = url.parse_query(queryStr)
      end
      local x, y = self:getWorldLoc()
      local o = level_spawn_object("wreckage", mothershipLayer, x, y)
      o:addAssets(v)
      o.direction = q.dir or 0
      local theta = math.rad(o.direction)
      o.driftX, o.driftY = cos(theta), sin(theta)
      o.driftRotDir = 1
      if random(50) > 25 then
        o.driftRotDir = -1
      end
      if q.lifetime ~= nil then
        o.spawnTime = o._mgr:getTime()
        o.spawnExpirationTime = o.spawnTime + q.lifetime
        o.spawnLifetime = q.lifetime
      end
      o.fxRateMin, o.fxRateMax = 1, 1
      if q.fxrate ~= nil then
        local fmin, fmax = breakstr(q.fxrate, ",")
        o.fxRateMin = tonumber(fmin) or 1
        o.fxRateMax = tonumber(fmax) or o.fxRateMin
      end
      o.explosionSpan = math.random() * (o.fxRateMax - o.fxRateMin) + o.fxRateMin
      local fx, fy = 0, 0
      if q.fxorigin ~= nil then
        fx, fy = breakstr(q.fxorigin, ",")
        fx, fy = tonumber(fx), tonumber(fy)
      end
      o.wreckageX = fx
      o.wreckageY = fy
      fx, fy = 0, 0
      if q.fxbounds ~= nil then
        fx, fy = breakstr(q.fxbounds, ",")
        fx, fy = tonumber(fx), tonumber(fy)
      end
      o.wreckageW = fx
      o.wreckageH = fy
      o.wreckageSpeed = WRECKAGE_SPEED
      if self == commandShip then
        o.wreckageSpeed = WRECKAGE_SPEED_SPC
        commandShipParts[#commandShipParts + 1] = o
      end
    end
  end
end
function _warpOutCallback(self)
  self.rocketTrail:remove()
  self.rocketTrail:destroy()
  self.rocketTrail = nil
end
function Entity:warpOut(camShake)
  local delayTime = 0
  if camShake then
    delayTime = 2
    level_fx_camera_shake(100, 4)
  end
  levelAS:delaycall(delayTime, function()
    local x, y = self:getLoc()
    if self.subentities ~= nil then
      local subentities = self.subentities
      self.subentities = nil
      for i = 1, #subentities do
        subentities[i]:destroy()
      end
    end
    local _x, _y = 0, 0
    if self.afterBurner then
      _x, _y = self.afterBurner:getLoc()
      self.afterBurner:destroy()
      self.afterBurner = nil
    end
    self.rocketTrail = levelAS:wrap(self.sprite:add(Ribbon.new("longRocketRibbon")))
    self.rocketTrail:setLoc(_x, _y)
    levelAS:wrap(self.rocketTrail.system)
    self.rocketTrail._uiname = self._uiname .. " ribbon"
    self.rocketTrail:setPriority(-1)
    self.rocketTrail.system:setPriority(-1)
    level_fx_warp(x, math.max(stageHeight, levelHeight * 1.8), mothershipLayer, nil, self, _warpOutCallback)
  end)
end
function Entity:startAfterBurner()
  if not self.def.warpEffect then
    return
  end
  local part = Particle.new(self.def.warpEffect, levelAS)
  local texture, queryStr = breakstr(self.def.warpEffect, "?")
  local nPri, x, y
  if queryStr ~= nil then
    q = url.parse_query(queryStr)
    if q.pri then
      nPri = tonumber(q.pri)
    end
    if q.loc ~= nil then
      x, y = breakstr(q.loc, ",")
      x = tonumber(x)
      y = tonumber(y)
    end
  end
  mothershipLayer:add(part)
  if nPri then
    part:setPriority(nPri)
  end
  if x then
    part:setLoc(x, y)
  end
  part:setParent(self.sprite)
  part:updateSystem()
  part:begin()
  gfxutil.stopAssets(self.sprite, true)
  self.afterBurner = part
end
return Entity
