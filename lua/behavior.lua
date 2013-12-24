local device = require("device")
local ui = require("ui")
local entitydef = require("entitydef")
local math2d = require("math2d")
local gfxutil = require("gfxutil")
local WTable = require("WeightTable")
local perkdef = require("PerkDef")
local Projectile = require("Projectile")
local interpolate = require("interpolate")
local Particle = require("Particle")
local soundmanager = require("soundmanager")
local math = math
local random = math.random
local deg = math.deg
local sqrt = math.sqrt
local atan2 = math.atan2
local normalize = math2d.normalize
local distance = math2d.distance
local dot = math2d.dot
local cos = math.cos
local sin = math.sin
local floor = math.floor
local abs = math.abs
local max = math.max
local min = math.min
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local HALF_PI = math.pi / 2
local PI = math.pi
local TWO_PI = math.pi * 2
local lerp = interpolate.lerp
local _debug, _warn, _error = require("qlog").loggers("behavior")
local _targetweights = WTable.new()
local function vary(x, variance)
  return x + random() * variance * 2 - variance
end
local timecheck = function(obj, field, t, period)
  if t >= (obj[field] or 0) then
    if period ~= nil then
      obj[field] = t + period
    else
      obj[field] = nil
    end
    return true
  end
  return false
end
local _M = {}
local Ship_Forward = function(self, dt)
  local dx, dy = self:getWorldDir()
  local dist = dt * self:accelerate(dt)
  self:addLoc(dist * dx, dist * dy)
end
local function Ship_Thrust(self, dt, dx, dy, dist, angleAdj)
  local turnSpeed = self.turnSpeed
  local goalRot = deg(atan2(dy, dx)) + (angleAdj or 0)
  if turnSpeed then
    do
      local wdx, wdy = self:getWorldDir()
      local newRot = deg(atan2(wdy, wdx))
      local diffRot = goalRot - newRot
      local maxAngle = turnSpeed * dt
      if diffRot < -180 then
        diffRot = diffRot + 360
      elseif diffRot > 180 then
        diffRot = diffRot - 360
      end
      local extraAngle = abs(diffRot) - abs(maxAngle)
      if extraAngle > 0 then
        if diffRot < 0 then
          self:addRot(-maxAngle)
        else
          self:addRot(maxAngle)
        end
        do
          local alpha = extraAngle / 270
          dist = dist * (1 - alpha)
        end
      else
        self:addRot(diffRot)
      end
      dx, dy = self:getWorldDir()
      self:addLoc(dx * dist, dy * dist)
    end
  else
    self:addLoc(dx * dist, dy * dist)
    self:setRot(goalRot)
  end
end
local function Ship_AdvanceOnPath(self, dt, path, forwardIfNoPath, offset)
  if path == nil or path:len() <= 1 then
    if forwardIfNoPath then
      Ship_Forward(self, dt)
    else
      self.speed = 0
    end
    return false
  end
  local dist = dt * self:accelerate(dt)
  local x, y, dx, dy = path:advance(dist)
  if x ~= nil and y ~= nil then
    local goalX, goalY
    if offset ~= nil and dx ~= nil and dy ~= nil then
      goalX = x - dy * offset
      goalY = y + dx * offset
    else
      goalX = x
      goalY = y
    end
    x, y = self:getWorldLoc()
    local gdx, gdy, goalDist = normalize(goalX - x, goalY - y)
    local trackDist = 9000 / (self.turnSpeed or 180)
    Ship_Thrust(self, dt, gdx, gdy, dist)
  end
  return true
end
local Ship_Drift = function(self, dt, dx, dy)
  local x, y = self:getLoc()
  local dist = DRIFT_SPEED * dt
  dx, dy = dx or 0, dy or -1
  self:addLoc(dist * dx, dist * dy)
end
local function Ship_TrackToPoint(self, dt, goalX, goalY, goalRadius, goalFOV, stopOnGoal, wigFreq)
  local x, y = self:getLoc()
  local wdx, wdy = self:getWorldDir()
  local wiggleFreq = wigFreq or self.def.wiggleFrequency
  local wiggleAngleAdj
  if wiggleFreq ~= nil then
    local sz = (self.def.wiggleAmplitude or 1) * 22.5
    local wt = (levelAS:getTime() - self.spawnTime) * wiggleFreq
    wiggleAngleAdj = cos(wt) * sz
  end
  if goalX == nil or goalY == nil then
    return false, nil, nil, nil
  end
  local dx, dy, goalDist = normalize(goalX - x, goalY - y)
  local dist = dt * self:accelerate(dt)
  local radius2 = goalRadius * 2
  if wiggleFreq ~= nil then
    wiggleAngleAdj = wiggleAngleAdj * min(abs(radius2 - goalDist), 1)
  end
  local inview = not goalFOV or goalFOV <= dot(wdx, wdy, dx, dy)
  if goalDist <= dist or goalRadius > goalDist then
    if inview and stopOnGoal then
      local a = (self.accel or self.def.accel or 10) * 1.5
      self.speed = max(0, self.speed - dt * a)
      dist = self.speed * dt
      self:addLoc(wdx * dist, wdy * dist)
      return true, goalDist, wdx, wdy
    end
    if not inview then
      dist = dist * 0.8
      self.speed = self.speed - self.speed * 0.95 * dt
    end
    Ship_Thrust(self, dt, wdx, wdy, dist, wiggleAngleAdj)
    return inview, goalDist, wdx, wdy
  end
  Ship_Thrust(self, dt, dx, dy, dist, wiggleAngleAdj)
  return false, goalDist, dx, dy
end
local function Ship_TrackToPointOnPath(self, dt, path, dp, offset)
  if self.pathGoalReached then
  end
  if path == nil or path:len() <= 1 then
    self.speed = self.speed * 0.3
    return false
  end
  local x, y, dx, dy = path:pointAt((dp or 0.99) * path:distance())
  if x ~= nil and y ~= nil then
    local goalX, goalY
    if offset ~= nil then
      goalX = x + dy * offset
      goalY = y - dx * offset
    else
      goalX = x
      goalY = y
    end
    x, y = self:getWorldLoc()
    local result, distance = Ship_TrackToPoint(self, dt, goalX, goalY, 40, nil, true)
    if result and distance <= 40 then
      self.pathGoalReached = true
      return true
    else
      return false
    end
  end
end
local function Ship_TrackPath(self, dt, path, offset)
  if path == nil or path:len() <= 1 then
    self.speed = self.speed * 0.3
    return false
  end
  local pathD = path:distance()
  local dist = dt * self:accelerate(dt)
  local newD = (self.pathTrackDist or 0) + dist
  local x, y, dx, dy = path:pointAt(newD)
  if x ~= nil and y ~= nil then
    local goalX, goalY
    if offset ~= nil then
      if offset > 30 then
        offset = 30
      end
      goalX = x + dy * offset
      goalY = y - dx * offset
    else
      goalX = x
      goalY = y
    end
    x, y = self:getWorldLoc()
    local gdx, gdy, goalDist = normalize(goalX - x, goalY - y)
    if offset ~= nil then
      local dv = dot(gdx, gdy, dx, dy)
      if offset > goalDist and dv < 0 then
        newD = newD - dv * offset
        dist = dist + dv * dist * 0.999
        gdx = dx
        gdy = dy
      end
    end
    local trackDist = 9000 / (self.turnSpeed or 180)
    Ship_Thrust(self, dt, gdx, gdy, dist)
    if goalDist < trackDist then
      self.pathTrackDist = newD
    end
  end
  return true
end
local function Ship_TrackToNextPathPoint(self, dt, path, offset)
  if self.currentPathPoint == nil then
    self.currentPathPoint = 1
  end
  if path == nil or 1 >= path:len() then
    self.speed = self.speed * 0.3
    return false
  end
  local gx, gy = path:get(self.currentPathPoint)
  local arrived, dist, gdx, gdy = Ship_TrackToPoint(self, dt, gx, gy, 20)
  if arrived then
    self.currentPathPoint = self.currentPathPoint + 1
  end
  return arrived, dist, gdx, gdy
end
local function _append_module(m, mods)
  table_insert(mods, m)
end
local function _get_module_targets(_type)
  _type = _type or "capitalship"
  local mods = {}
  level_foreach_object_of_type(_type, _append_module, mods)
  if #mods == 0 then
    return nil
  end
  return mods
end
local function _random_module_target(_type)
  _type = _type or "capitalship"
  local mods = {}
  level_foreach_object_of_type(_type, _append_module, mods)
  if #mods == 0 then
    return nil
  end
  local m = mods[math.random(1, #mods)]
  return m
end
local function _get_module_commandship()
  local mods = {}
  level_foreach_object_of_entityid("commandship", _append_module, mods)
  if #mods == 0 then
    return nil
  end
  local m = mods[math.random(1, #mods)]
  return m
end
local function _turret_fov_check(obj, turret)
  local _x, _y = obj:getWorldLoc()
  local x, y = turret:getWorldLoc()
  local tx, ty, tlen = normalize(_x - x, _y - y)
  local dx, dy = turret:getWorldDir()
  local dotval = dot(dx, dy, tx, ty)
  if dotval >= 0.9 then
    return true
  end
end
local function _ship_fire_at(self, target, time, texture)
  if not target or target.hp == nil or target.hp <= 0 then
    return false
  end
  local time = time or self.def.weaponTravelTime or 0.65
  local p = Projectile.new(texture or self.def.weaponTexture or "pellet.png", levelAS)
  mainLayer:add(p)
  local x, y
  if not self.def.weaponLoc then
    x, y = self:getLoc()
  else
    x, y = self:modelToWorld(unpack(self.def.weaponLoc))
  end
  p:setLoc(x, y)
  local wdx, wdy = self:getWorldDir()
  p:addLoc(wdx, 0)
  local spread = self.def.weaponSpread or 5
  if target.def.type == "capitalship" or target.def.type == "enemyc" then
    spread = self.def.weaponSpread or 25
  end
  local damage = self.def.weaponDamage
  local tx, ty = target:getLoc()
  local tdx, tdy = target:getWorldDir()
  local fx = tx + tdx * time * (target.speed or 0)
  local fy = ty + tdy * time * (target.speed or 0)
  fx, fy = math2d.randomPointInCircle(fx, fy, spread)
  local fireRot = deg(atan2(fy - y, fx - x)) + (self.weaponRot or 0)
  if self.turret ~= nil then
    self.turret:setRot(fireRot + (self.def.turretRot or 0) - 90)
  end
  p:setRot(fireRot + (self.def.weaponRot or 0) - 90)
  local shield = target.shield
  if shield ~= nil then
    local rot = math.rad(target:getRot())
    local sdx, sdy = cos(rot + target.shieldAngle), sin(rot + target.shieldAngle)
    local _tdx, _tdy = normalize(x - tx, y - ty)
    local angle = math.acos(dot(sdx, sdy, _tdx, _tdy))
    if angle <= target.shieldHalfAngle then
      damage = damage * target.def.shieldDamping
    end
  end
  if self.def.type == "fighter" then
    if self.def.fighterType == "fighter" and active_perks.plusFighters then
      damage = damage + damage * active_perks.plusFighters.modifier.damage
    elseif self.def.fighterType == "interceptor" and active_perks.plusInterceptors then
      damage = damage + damage * active_perks.plusInterceptors.modifier.damage
    elseif self.def.fighterType == "bomber" and active_perks.plusBombers then
      damage = damage + damage * active_perks.plusBombers.modifier.damage
    end
  end
  local muzzleFlash = self.muzzleFlash
  if muzzleFlash then
    self:add(self.muzzleFlash)
    self.muzzleFlash:playAssets()
  end
  if self.def.type == "fighter" and not self.def._id:find("Bomb") then
    soundmanager.onGunfire()
  else
    local muzzleFlashSfx = self.muzzleFlashSfx
    if muzzleFlashSfx then
      muzzleFlashSfx:play()
    end
  end
  local driver = levelAS:wrap(p:seekLoc(fx, fy, time, MOAIEaseType.SOFT_EASE_OUT))
  driver:setListener(MOAITimer.EVENT_STOP, function()
    local x, y = p:getLoc()
    target.lastAttacker = self
    if target.target == nil then
      target.nextTargetSeekTime = nil
    end
    local damMod = 1
    if self.def.targetTypes then
      damMod = self.def.targetTypes[target.def.type] or 1
      if not self.targetIneffective and damMod < WEAPON_INEFFECTIVE_MOD then
        level_fx_floatie(x, y, _(INEFFECTIVE_MESSAGE), "ffffff", nil, FONT_SMALL)
        self.targetIneffective = true
      end
    end
    local impactTexture
    if device.cpu == device.CPU_LO and device.ui_assetrez == device.ASSET_MODE_LO then
      impactTexture = self.def.weaponImpactTextureLo
    else
      impactTexture = self.def.weaponImpactTexture
    end
    if impactTexture then
      do
        local impactType = type(impactTexture)
        if impactType == "string" then
          level_fx_explosion(x, y, 8, self.sprite._uilayer, impactTexture)
        elseif impactType == "table" then
          if damMod < 0.5 and impactTexture.low then
            level_fx_explosion(x, y, 8, self.sprite._uilayer, impactTexture.low)
          elseif damMod >= 0.5 and impactTexture.high then
            level_fx_explosion(x, y, 8, self.sprite._uilayer, impactTexture.high)
            if impactTexture.bonus and self.nitro then
              level_fx_explosion(x, y, 8, self.sprite._uilayer, impactTexture.bonus)
            end
          end
        end
      end
    else
      level_fx_explosion(x, y, 8, mainLayer)
    end
    if target.def.type == "capitalship" then
      level_fx_camera_shake(math.max(2, damage / 10))
    end
    p:destroy()
    p = nil
    target:applyDamage(damage * damMod, self)
  end)
  return true
end
local function _ship_fire(self, time, texture)
  return _ship_fire_at(self, self.target, time, texture)
end
local function _directfire_fov_check(obj, ship, maxFovDot, maxDist, weaponTex)
  local _x, _y = obj:getWorldLoc()
  local x, y = ship:getWorldLoc()
  local tx, ty, tlen = normalize(_x - x, _y - y)
  if maxDist >= tlen then
    local dx, dy = ship:getWorldDir()
    local dotval = dot(dx, dy, tx, ty)
    if maxFovDot <= dotval then
      _ship_fire_at(ship, obj, 0.7, weaponTex)
      return true, obj
    end
  end
end
local _first_object = function(enemy, self, range)
  return true, enemy
end
local function _weight_targets(enemy, self, weight)
  if enemy ~= self then
    _targetweights:mul(enemy, weight)
  end
end
local function _weight_object_in_range(enemy, self, range, fov)
  if self:isInRange(enemy, range, fov) then
    local targets = self.def.targetTypes
    if targets then
      _weight_targets(enemy, self, targets[enemy.def.type])
    else
      return true, enemy
    end
  end
end
local _object_in_range = function(enemy, self, range, fov)
  if self:isInRange(enemy, range, fov) then
    return true, enemy
  end
end
local function _weapons_fire_check(self, t, checkRange)
  if (checkRange == nil or checkRange) and not self:isInRange(self.target) then
    return false
  end
  if timecheck(self, "nextWeaponsFireTime", t) and t > 0.01 then
    local def = self.def
    local pulses = def.weaponPulses
    local pulseTime = def.weaponPulseDelay
    self.nextWeaponsFireTime = t + pulses * pulseTime + def.weaponCooldown
    levelAS:repeatcalln(pulseTime, pulses, _ship_fire, self)
    return true
  end
  return false
end
_M.DISCIPLINE_VALUES = {
  low = 0,
  med = 1,
  high = 2
}
local function _target_update_check(self, t, primaryIsHostile)
  local oldTarget = self.target
  local newTarget = self.target
  if newTarget ~= nil and not newTarget:isAlive() then
    newTarget = nil
  end
  if self.target ~= nil and not self.target:isAlive() then
    self.target = nil
  end
  if timecheck(self, "nextTargetSeekTime", t, 1) then
    local hostilePrimary
    if primaryIsHostile then
      if self.primaryTarget == nil or not self.primaryTarget:isAlive() then
        self.primaryTarget = _random_module_target()
      end
      hostilePrimary = self.primaryTarget
    end
    local discipline = self.discipline or 1
    local defendYourself, opportunityWeight, opportunityScanMult
    if discipline == 2 then
      newTarget = hostilePrimary
      if newTarget ~= nil then
        defendYourself = false
        opportunityWeight = 0
        opportunityScanMult = 2
      else
        defendYourself = true
        opportunityWeight = 0.25
        opportunityScanMult = 3
      end
    elseif discipline == 1 then
      newTarget = hostilePrimary
      defendYourself = true
      if newTarget ~= nil then
        opportunityWeight = 1.5
        opportunityScanMult = 3
      else
        opportunityWeight = 0
        opportunityScanMult = 0
      end
    else
      newTarget = hostilePrimary
      opportunityWeight = 2
      opportunityScanMult = 5
      defendYourself = true
    end
    _targetweights:reset()
    if self:isInRange(oldTarget, nil, false) then
      _targetweights:mul(oldTarget, 2)
    else
      _targetweights:set(oldTarget, 1)
    end
    if defendYourself then
      local lastAttacker = self.lastAttacker
      if self:isInRange(lastAttacker, nil, false) then
        _targetweights:mul(lastAttacker, 2)
      end
    end
    if newTarget ~= nil and self:distance(newTarget) > self.def.weaponRange * 2 then
      _targetweights:mul(newTarget, 0.5)
    end
    if hostilePrimary ~= nil then
      _targetweights:mul(hostilePrimary, 1)
    end
    if opportunityWeight > 0 then
      local def = self.def
      local targets = def.targetTypes or ENEMY_TARGET_TYPES
      local x, y = self:getWorldLoc()
      local found, enemy = level_foreach_object_of_type_in_circle(targets, x, y, def.weaponRange * opportunityScanMult, _object_in_range, self)
      if found then
        _targetweights:mul(enemy, 1.5)
      end
    end
    newTarget = _targetweights:highest()
    self.target = newTarget
  end
  return self.target ~= oldTarget
end
local function crate_handleTouch(self, eventType, touchIdx, x, y, tapCount)
  if eventType == ui.TOUCH_UP then
    self.towShip:deployCrate(self)
  end
end
local function _object_collect(obj, harvester)
  local rt = obj.def.resourceType
  if rt ~= nil then
    do
      local hrt = harvester.def.harvestResourceType
      if obj.def.type == "survivor" then
        do
          local tow = obj.chainParent
          if not tow then
            harvester:appendTowObject(obj)
          else
            tow:appendTowObject(harvester)
          end
        end
      elseif hrt == "*" or rt == hrt then
        local chainTex = obj.def.towedObjectTexture
        local chainMax = harvester.def.towedObjectMax
        if chainTex and chainMax ~= nil then
          harvester:appendTowObject(obj)
        else
          harvester:floatie("+" .. obj.def.resourceValue, obj.def.resourceTexture)
          scores[rt] = (scores[rt] or 0) + (obj.def.resourceValue or 1)
          levelui_show_resource_gain(rt)
          obj:destroy()
        end
      end
    end
  else
    local etype = obj.def.type
    if etype == "powerup" then
      do
        local eid = obj.def._id
        if eid == "PU_restorehealth" then
          if harvester.hp ~= nil and harvester.hp < harvester.def.hp then
            harvester:applyDamage(harvester.hp - harvester.def.hp)
            harvester:floatie("Healed!")
            obj:destroy()
          end
        elseif eid == "PU_repair" then
          if harvester.repairUntilTime == nil then
            harvester.repairUntilTime = levelAS:getTime() + 20
            harvester:floatie("Repair! (20s)")
            obj:destroy()
          end
        else
          _warn("Unimplemented powerup: " .. eid)
        end
      end
    elseif etype == "crate" then
      local c = harvester:appendTowObject(obj)
      if c ~= nil then
        c.handleTouch = crate_handleTouch
      end
    end
  end
end
local function _object_collect_check(self)
  local x, y = self:getLoc()
  local r = self.collisionRadius * (self.def.collectScl or 1.1)
  local types = self.def.collectTypes or FIGHTER_COLLECT_TYPES
  level_foreach_object_of_type_in_circle(types, x, y, r, _object_collect, self)
end
local _object_deposit_check = function(self)
  local x, y = self:getLoc()
  local chain = self.towedObjects
  if chain ~= nil then
    local m = self:getObjectUnderShip("silo")
    if m ~= nil then
      self:bankTowedResources()
    end
  end
end
local _module_hover_clear = function(self)
  if self.hoverModule ~= nil then
    if self.hoverModuleIndicator ~= nil then
      self.hoverModuleIndicator:remove()
      self.hoverModuleIndicator = nil
    end
    self.hoverModuleActivateTime = nil
    self.hoverModuleActivated = false
    local m = self.hoverModule
    self.hoverModule = nil
    if m.handleShipHoverStop then
      m:handleShipHoverStop(self)
    end
  end
end
local function _module_hover_check(self, dt, t)
  local hoverActivateTime = self.hoverModuleActivateTime
  local m = self:getObjectUnderShip()
  if hoverActivateTime == nil then
    if m ~= nil and m.handleShipHover ~= nil then
      if m.handleShipHoverStart then
        local ok, reason = m:handleShipHoverStart(self, dt, t)
        if not ok then
          if reason ~= nil then
            local mx, my = m:getLoc()
            self:floatie(reason)
          end
          self.hoverModule = m
          self.hoverModuleActivateTime = false
          return
        end
      end
      self.hoverModuleActivateTime = t + HOVER_ACTIVATION_TIME
      self.hoverModule = m
      self.hoverModuleIndicator = uiLayer:add(ui.TextBox.new(string.format("%4.1f", HOVER_ACTIVATION_TIME), FONT_XLARGE, "ffffff", "center", 60, 60))
      self.hoverModuleIndicator:setScl(1.5, -1.5)
    end
  elseif m ~= self.hoverModule then
    if m == nil or m.handleShipHover == nil then
      _module_hover_clear(self)
    else
      self.hoverModuleActivateTime = t + HOVER_ACTIVATION_TIME
      self.hoverModuleIndicator:setString(string.format("%4.1f", HOVER_ACTIVATION_TIME))
      self.hoverModule = m
    end
    if m.handleShipHoverStart and not m:handleShipHoverStart(self) then
    end
  elseif hoverActivateTime == false then
  else
    local ht = hoverActivateTime - t
    if ht <= 0 then
      if not self.hoverModuleActivated then
        m:handleShipHover(self, dt, -ht)
        self.hoverModuleActivated = true
        self.hoverModuleIndicator:remove()
      end
    else
      local x, y = self:getWorldLoc()
      local mx, my = m:getWorldLoc()
      x = x + (mx - x) / 30
      y = y + (my - y) / 30
      self:setLoc(x, y)
      self.hoverModuleIndicator:setString(string.format("%4.1f", ht))
    end
  end
end
local _repair_module = function(m, dt, ship)
  if m.moduleType ~= nil and m.hp < m.hpMax then
    m:applyDamage(-50 * dt)
  end
end
local function _repair_surrounding_modules_check(self, dt, t)
  local repairTime = self.repairUntilTime
  if repairTime == nil then
    return
  end
  local effect = self.repairEffect
  if t >= repairTime then
    effect:remove()
    self.repairEffect = nil
    self.repairRadius = nil
    self.repairUntilTime = nil
    return
  end
  if effect == nil then
    effect = self:add(ui.Image.new("objects.atlas.png#damage_immunity_shield.png"))
    effect:setPriority(1)
    effect.handleTouch = false
    self.repairEffect = effect
    self.repairRadius = 350
  end
  effect:addRot(dt * 0.1)
  local s = math.sin((t - self.spawnTime) * 20) * 0.08 + 1 * (self.repairRadius / 110)
  effect:setScl(s, s)
  level_foreach_object_of_type_in_circle(nil, x, y, r, ship.repairRadius, _repair_module, dt, self)
end
local _missile_collision = function(other, self)
  if self._consumed then
    return
  end
  local ex, ey = other:getLoc()
  local x, y = self:getLoc()
  other:applyDamage(self.damage or self.def.damage)
  self:destroy()
  self._consumed = true
  return true
end
local function _asteroid_collision(obj, self)
  local miner = obj.def.type == "miner"
  local damageToAsteroid = 10
  if not miner then
    damageToAsteroid = 150
    if obj:applyDamage(self.def.collisionDamage) then
      local x, y = self:getLoc()
      local _x, _y = obj:getLoc()
      local nx, ny, len = normalize(_x - x, _y - y)
      local speed = 5
      obj:addLoc(nx * speed * 2, ny * speed * 2)
      self:addLoc(-nx * speed, -ny * speed)
      obj:destroyPath()
    end
  end
  if not self:applyDamage(damageToAsteroid) then
    return true
  end
  if miner then
    local x, y = self:getLoc()
    local _x, _y = obj:getLoc()
    local nx, ny, len = normalize(_x - x, _y - y)
    local speed = 5
    obj:addLoc(nx * speed * 2, ny * speed * 2)
    self:addLoc(-nx * speed, -ny * speed)
  end
end

function _M:enemy_asteroid_eater(dt, t)
end