
_pex_cache = {}
ParticleSystem = {}
ParticleSystem.__index = ParticleSystem
function ParticleSystem.preload(path)
	for i, f in ipairs(path) do
		_pex_cache[f] = MOAIParticlePexPlugin.load(f)
	end
end
function ParticleSystem.new(particleName)
	local plugin = _pex_cache[particleName] or MOAIParticlePexPlugin.load(particleName)
	local maxParticles = plugin:getMaxParticles()
	local blendsrc, blenddst = plugin:getBlendMode()
	local minLifespan, maxLifespan = plugin:getLifespan()
	local duration = plugin:getDuration()
	local xMin, yMin, xMax, yMax = plugin:getRect()
	local _, _, texture = string.find(plugin:getTextureName(), "/([^/]+)$")

	local system = MOAIParticleSystem.new()
	system._duration = duration
	system._lifespan = maxLifespan
	system:reserveParticles(maxParticles , plugin:getSize())
	system:reserveSprites(maxParticles)
	system:reserveStates(1)
	system:setBlendMode(blendsrc, blenddst)

	local state = MOAIParticleState.new()
	state:setTerm(minLifespan, maxLifespan)
	state:setPlugin(plugin)
	system:setState(1, state)

	emitter = MOAIParticleTimedEmitter.new()
    emitter:setLoc(0, 0)
	emitter:setSystem(system)
	emitter:setEmission(plugin:getEmission())
	emitter:setFrequency(plugin:getFrequency())
	emitter:setRect(xMin, yMin, xMax, yMax)
	
	local deck = resource.deck(texture)
	deck:setRect(-0.5, -0.5, 0.5, 0.5)
	system:setDeck(deck)

	system.state = state
	system.emitters = {emitter}
	system.startSystem = ParticleSystem.startSystem
	system.stopEmitters = ParticleSystem.stopEmitters
	system.stopSystem = ParticleSystem.stopSystem
	system.surgeSystem = ParticleSystem.surgeSystem
	system.updateSystem = ParticleSystem.updateSystem
	system.handleTouch = false
	return system
end
function ParticleSystem:startSystem(noEmitters)
  self:start()
  if not noEmitters then
    for k, v in pairs(self.emitters) do
      v:start()
    end
  end
end
function ParticleSystem:stopEmitters()
  for k, v in pairs(self.emitters) do
    v:stop()
  end
end
function ParticleSystem:stopSystem()
  self:stop()
  self:stopEmitters()
end
function ParticleSystem:surgeSystem(val)
  for k, v in pairs(self.emitters) do
    v:surge(val)
  end
end
function ParticleSystem:updateSystem()
  self:forceUpdate()
  for k, v in pairs(self.emitters) do
    v:forceUpdate()
  end
end
ParticleSystem.preload{
	"particles/alienArtillery01.pex",
	"particles/alienArtillery02.pex",
	"particles/alienArtillery03.pex",
	"particles/alienArtillery04.pex",
	"particles/alienArtillery05.pex",
	"particles/alienArtillery06.pex",
	"particles/alienBomberImpactLarge.pex",
	"particles/alienConstructionSparks.pex",
	"particles/alienExplosionLarge.pex",
	"particles/alienExplosionMed.pex",
	"particles/alienExplosionSparksLarge.pex",
	"particles/alienHeavyImpact.pex",
	"particles/alienImpactLarge.pex",
	"particles/alienShield.pex",
	"particles/alienShieldGenerator01.pex",
	"particles/alienSpitterImpact.pex",
	"particles/alienSpitterProjectile.pex",
	"particles/alienSpitterProjectileTrail.pex",
	"particles/alienWarp.pex",
	"particles/antiBomberExplosionSmall.pex",
	"particles/antiBomberImpactHigh.pex",
	"particles/antiBomberExplosionSparksSmall.pex",
	"particles/antiBomberIneffectiveImpact.pex",
	"particles/antiBomberNitro.pex",
	"particles/artilleryImpactCenter01.pex",
	"particles/artilleryImpactCenterNitro.pex",
	"particles/artilleryImpactRing01.pex",
	"particles/artilleryImpactRingNitro.pex",
	"particles/bomberExplosion01.pex",
	"particles/bomberImpact01.pex",
	"particles/bomberImpactHigh.pex",
	"particles/bomberNitro.pex",
	"particles/buoyBeacon.pex",
	"particles/capShipHeal01.pex",
	"particles/capShipSparks.pex",
	"particles/capShipTrail.pex",
	"particles/capShipWarpIn.pex",
	"particles/capShipWarpTrail01.pex",
	"particles/deathBlossom01.pex",
	"particles/deathBlossomCharge.pex",
	"particles/deathBlossomExplosion.pex",
	"particles/deathBlossomFlash.pex",
	"particles/deathBlossomRing.pex",
	"particles/spitterImpact01.pex",
}

-- compact
local _require = require
function require(module)
	if module == "entitydef" then
		module = "SourceEntityDef"
	end
	return _require(module)
end
--

package.path = "?.lua"
package.preload.socket()
local gm = require "gm"
gm.listen("192.168.1.103",9999)
local timer = require "timer"

require "constants"
local device = require "device"
-- device.ui_assetrez = device.ASSET_MODE_HI
local resource = require "resource"
local actionset = require "actionset"
local path = require "path"
local sound = require "sound"
Particle = require "particles"
local math2d = require "math2d"
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
local timer = require "timer"
local tick = MOAITimer.new()

SCREEN_WIDTH, SCREEN_HEIGHT = device.ui_width, device.ui_height
MOAISim.openWindow("drawtest", device.width, device.height)
viewport = MOAIViewport.new()
viewport:setScale(device.ui_width, device.ui_height)
viewport:setSize(0, 0, device.width, device.height)
viewport:setRotation(-90)

layer = MOAILayer2D.new()
layer:setViewport(viewport)
camera = MOAICamera2D.new()
layer:setCamera(camera)
partition = MOAIPartition.new()
layer:setPartition(partition)
MOAISim.pushRenderPass(layer)

uilayer = MOAILayer2D.new()
uilayer:setViewport(viewport)
MOAISim.pushRenderPass(uilayer)

toplayer = MOAILayer2D.new()
toplayer:setViewport(viewport)
MOAISim.pushRenderPass(toplayer)

function angle(x1, y1, x2, y2)
	return math.atan2(y2 - y1, x2 - x1) *(180 / math.pi)
end

function distance(x1, y1, x2, y2)
	return math.sqrt(((x2 - x1) ^ 2) +((y2 - y1) ^ 2))
end

function sprite(res)
	prop = MOAIProp2D.new()
	deck = resource.deck(res)
	prop:setDeck(deck)
	prop.setIndexByName = function(self, name)
		self:setIndex(deck:indexOf(name))
	end
	prop.addLayer = function(self, layer)
		self:removeLayer()
		layer:insertProp(self)
		self.layer = layer
	end
	prop.removeLayer = function(self)
		if self.layer then
			self.layer:removeProp(self)
			self.layer = nil
		end
	end
	prop._deck = deck
	prop.def = {}
	prop.speed = speed or 100
	prop.maxspeed = maxspeed or 120
	prop.accel = accel or 100
	prop.accelerate = function(self, dt)
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
	return prop
end

local mouseX = 0
local mouseY = 0
local lastX = 0
local lastY = 0

mainAS = actionset.new()
mainAS:start()

function motherShip()
	ship = sprite("StarPatrolOne.atlas.png")
	ship:setIndexByName("ship01.png")
	ship:setScl(1.5)
	ship.isMotherShip = true
	layer:insertProp(ship)
	local engine = Particle.new("particles/capShipWarpTrail01.pex", mainAS, layer)
	engine:setParent(ship)
	engine:setLoc(0,-180)
	engine:setScl(2,2)
	engine:begin()
	ship.engine = engine
	
	damage1 = sprite("StarPatrolOne.atlas.png")
	damage1:setIndex(5)
	damage2 = sprite("StarPatrolOne.atlas.png")
	damage2:setIndex(6)
	
	ship.damageHp = function()
		ship.hp = ship.hp - 1
		if ship.hp == 15 then
			damage1:addLayer(layer)
		end
		if ship.hp == 5 then
			damage2:addLayer(layer)
		end
	end
	
	ship:setLoc(0,-350)
	ship.hp = 30
	sound.new("game_shipwarping_01"):play()
	ship:seekLoc(0,-50, 3, MOAIEaseType.EASE_IN)
	return ship
end
function motherShip_dead()
	if ship.isDead then
		return
	end
	ship.isDead = true
	ship:setLoc(0,-2500)
	
	if damage1 then damage1:removeLayer() end
	if damage2 then damage2:removeLayer() end
	
	sound.new("game_deathblossom_explosion"):play()
	local impact = Particle.new("particles/deathBlossomRing.pex", mainAS, layer)
	impact:setLoc(0,0)
	impact:setScl(1,1)
	impact:begin()
	
	local timer = MOAITimer.new()
	timer:setSpan(3)
	timer:setListener(MOAITimer.EVENT_TIMER_END_SPAN, function()
		ship:setLoc(0,-350)
		sound.new("game_shipwarping_01"):play()
		ship:seekLoc(0,-50, 3, MOAIEaseType.EASE_IN)
	end)
	timer:start()
	
	local timer = MOAITimer.new()
	timer:setSpan(6)
	timer:setListener(MOAITimer.EVENT_TIMER_END_SPAN, function()
		ship.hp = 30
		ship.isDead = nil
	end)
	timer:start()
end

function motherShip_fireNow(muzzle, x0, y0, range, bulletSpeed)
	if #fighters == 0 or ship.hp <= 0 then
		muzzle:removeLayer()
		return
	end
	local dis = range
	local aim
	for k, v in ipairs(fighters) do
		local x, y = v:getLoc()
		if distance(x0, y0, x, y) < dis then
			aim = v
			dis = distance(x0, y0, x, y)
		end
	end
	if aim then
		local x, y = aim:getLoc()
		muzzle:setRot(angle(x0, y0, x, y) - 90)
		muzzle:addLayer(layer)
		local bullet = sprite("bomberWeaponBasic.atlas.png")
		bullet:setScl(2, 2)
		Anim_loop(bullet, "projectile")
		bullet:setLoc(x0, y0)
		bullet:setRot(angle(x0, y0, x, y) - 90)
		bullet:addLayer(layer)
		bullet.weaponFireSfx = sound.new("alienBomber?volum=0.1")
		bullet.bombRange = 0
		Anim_fireAt(bullet, x, y, bulletSpeed)
	else
		muzzle:removeLayer()
	end
end

function motherShip_fire(x0, y0, range)
	local timer = MOAITimer.new()
	timer:setSpan(1)
	timer:setMode(MOAITimer.LOOP)
	local muzzle = sprite("bomberWeaponBasic.atlas.png")
	muzzle:setScl(2, 2)
	Anim_loop(muzzle, "muzzleFlash")
	muzzle:setLoc(x0, y0)
	local bulletSpeed = 0.0025
	timer:setListener(MOAITimer.EVENT_TIMER_END_SPAN, function()
		motherShip_fireNow(muzzle, x0, y0, range, bulletSpeed)
	end)
	timer:start()
	return muzzle
end

local camShakes = {}
local camShakeX = 0
local camShakeY = 0

local function _calc_camera_shake(t)
  local strength = 0
  for driver, v in pairs(camShakes) do
    local str = driver(t)
    if str == nil then
      camShakes[driver] = nil
    else
      strength = strength + str
    end
  end
  return strength
end
function level_fx_camera_shake(strength, duration)
  if strength == nil then
    strength = 50
  end
  if duration == nil then
    duration = 1
  end
  local startTime = mainAS:getTime()
  local pow = math.pow
  local function fn(t)
    local a =(t - startTime) / duration
    if a > 1 then
      return nil
    end
    return strength - strength *(-pow(2, -10 * a) + 1)
  end
  camShakes[fn] = true
end

function Ship_Forward(self, dt)
  local dx, dy = self:getWorldDir()
  local dist = dt * self:accelerate(dt)
  self:addLoc(dist * dx, dist * dy)
end
function Ship_Thrust(self, dt, dx, dy, dist, angleAdj)
  local turnSpeed = self.turnSpeed
  local goalRot = deg(atan2(dy, dx)) +(angleAdj or 0)
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
          dist = dist *(1 - alpha)
        end
      else
        self:addRot(diffRot)
      end
      dx, dy = self:getWorldDir()
      self:addLoc(dx * dist, dy * dist)
    end
  else
    self:addLoc(dx * dist, dy * dist)
    self:setRot(goalRot - 90)
  end
end
function Ship_AdvanceOnPath(self, dt, path, forwardIfNoPath, offset)
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
    local trackDist = 9000 /(self.turnSpeed or 180)
    Ship_Thrust(self, dt, gdx, gdy, dist)
  end
  return true
end
function Ship_Drift(self, dt, dx, dy)
  local x, y = self:getLoc()
  local dist = DRIFT_SPEED * dt
  dx, dy = dx or 0, dy or -1
  self:addLoc(dist * dx, dist * dy)
end
function Ship_TrackToPoint(self, dt, goalX, goalY, goalRadius, goalFOV, stopOnGoal, wigFreq)
  local x, y = self:getLoc()
  local wdx, wdy = self:getWorldDir()
  local wiggleFreq = wigFreq or self.def.wiggleFrequency
  local wiggleAngleAdj
  if wiggleFreq ~= nil then
    local sz =(self.def.wiggleAmplitude or 1) * 22.5
    local wt =(levelAS:getTime() - self.spawnTime) * wiggleFreq
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
      local a =(self.accel or self.def.accel or 10) * 1.5
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
function Ship_TrackToPointOnPath(self, dt, path, dp, offset)
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
function Ship_TrackPath(self, dt, path, offset)
  if path == nil or path:len() <= 1 then
    self.speed = self.speed * 0.3
    return false
  end
  local pathD = path:distance()
  local dist = dt * self:accelerate(dt)
  local newD =(self.pathTrackDist or 0) + dist
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
    local trackDist = 9000 /(self.turnSpeed or 180)
    Ship_Thrust(self, dt, gdx, gdy, dist)
    if goalDist < trackDist then
      self.pathTrackDist = newD
    end
  end
  return true
end
function Ship_TrackToNextPathPoint(self, dt, path, offset)
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

function Anim_play(self, animName, callback, looping)
  if self._anim ~= nil then
    self._anim:stop()
    self._anim:clear()
    self._anim = nil
  end
  if not looping and callback == nil then
    callback = Anim_defaultCallback
  end
  if not animName or not self._deck or not self._deck._animCurves then
    return nil
  end
  local curve = self._deck._animCurves[animName]
  if not curve then
    return nil
  end
  local anim = MOAIAnim.new()
  if self._deck.type == "tweendeck" then
    do
      local consts = self._deck._animConsts[animName]
      local curLink = 1
      self._animProp = MOAIProp2D.new()
      self._animProp:setDeck(self._deck)
      anim:reserveLinks(self._deck._numCurves[animName])
      for animType, entry in pairs(curve) do
        anim:setLink(curLink, entry, self._animProp, animType)
        if animType == MOAIColor.ATTR_A_COL then
          anim:setLink(curLink + 1, entry, self._animProp, MOAIColor.ATTR_R_COL)
          anim:setLink(curLink + 2, entry, self._animProp, MOAIColor.ATTR_G_COL)
          anim:setLink(curLink + 3, entry, self._animProp, MOAIColor.ATTR_B_COL)
          curLink = curLink + 3
        end
        curLink = curLink + 1
      end
      for animType, entry in pairs(consts) do
        if animType == "id" then
          self._animProp:setIndex(entry)
        elseif animType == "x" then
          do
            local x, y = self:getLoc()
            self._animProp:setLoc(entry, y)
          end
        elseif animType == "y" then
          do
            local x = self:getLoc()
            self._animProp:setLoc(x, entry)
          end
        elseif animType == "r" then
          self._animProp:setRot(entry)
        elseif animType == "xs" then
          do
            local x, y = self:getScl()
            self._animProp:setScl(entry, y)
          end
        elseif animType == "ys" then
          do
            local x = self:getScl()
            self._animProp:setScl(x, entry)
          end
        elseif animType == "a" then
          self._animProp:setColor(entry, entry, entry, entry)
        end
      end
    end
  else
    anim:reserveLinks(1)
    anim:setLink(1, curve, self, MOAIProp2D.ATTR_INDEX)
  end
  if looping then
    anim:setMode(MOAITimer.LOOP)
  else
    anim:setListener(MOAITimer.EVENT_TIMER_END_SPAN, callback)
  end
  self._anim = anim
  return anim:start()
end
function Anim_loop(self, animName)
  return Anim_play(self, animName, nil, true)
end
function Anim_stop(self)
  if self._anim ~= nil then
    self._anim:stop()
    self._anim = nil
  end
  if self._animProp ~= nil then
    self._animProp = nil
  end
end
function Anim_fireAt(self, x, y, speed, shake)
	local thread = MOAIThread.new()
	thread:run(function()
		local x0, y0 = self:getLoc()
		if self.weaponFireSfx then
			self.weaponFireSfx:play()
		end
		local dis = distance(x0, y0, x, y)
		MOAIThread.blockOnAction(self:seekLoc(
			x, y,
			dis * speed,
			MOAIEaseType.LINEAR))
			
		if self.weaponImpactSfx then
			self.weaponImpactSfx:play()
		end
		if shake then
			level_fx_camera_shake(shake, 1)
		end
		Anim_play(self, "impact", function()
			if self.bombRange then
				local x0, y0 = x - self.bombRange, y - self.bombRange
				local x1, y1 = x + self.bombRange, y + self.bombRange
				local props = {partition:propListForRect(x0, y0, x1, y1)}
				for k, v in pairs(props) do
					if v.isFighter then
						v.hp = v.hp - 1
						if v.hp <= 0 then
							for i, f in ipairs(fighters) do
								if v == f then
									local ps = Particle.new("particles/antiBomberExplosionSmall.pex", mainAS, layer)
									ps:setLoc(f:getLoc())
									ps:begin()
									f:dead()
									table.remove(fighters, i)
								end
							end
						else
							local ps = Particle.new("particles/antiBomberImpactHigh.pex", mainAS, layer)
							ps:setParent(v)
							ps:begin()
						end
						break
					end
				end
			end
			self:removeLayer()
		end)
	end)
end

fighters = {}
Fighter = {}
function Fighter.new(layer, def)
	local self = sprite("fighterBasic.atlas.png")
	self:setLoc(-100,150)
	self:setScl(1.5, 1.5)
	self:setRot(-90)
	self.fireRange = 200
	self.hp = 10
	self.isFighter = true
	self.fireAt = Fighter.fireAt
	self.dead = Fighter.dead
	self:addLayer(layer)
	
	local muzzle = sprite("alienFighterWeaponBasic.atlas.png")
	muzzle._animProp = muzzle
	muzzle:setLoc(0, 8)
	muzzle:setRot(0)
	muzzle:setParent(self)
	Anim_loop(muzzle, "muzzleFlash")
	self.muzzle = muzzle
	self.fireSpan = 0.35
	self.bulletSpeed = 0.0015
	
	if def.weaponFireSfx ~= nil then
		self.weaponFireSfx = sound.new(def.weaponFireSfx)
	end
	if def.weaponImpactSfx ~= nil then
		self.weaponImpactSfx = sound.new(def.weaponImpactSfx)
	end
	self.fireTimer = MOAITimer.new()
	self.fireTimer:setSpan(self.fireSpan)
	self.fireTimer:setListener(MOAITimer.EVENT_TIMER_END_SPAN, function()
		if not self.firing or ship.hp <= 0 then
			return
		end
		local bullet = sprite("alienFighterWeaponBasic.atlas.png")
		Anim_loop(bullet, "alienFighter_projectile")
		local x, y = self:getLoc()
		bullet:setLoc(x, y)
		bullet:setRot(angle(x, y, self.firing.x, self.firing.y) - 90)
		bullet:addLayer(layer)
		bullet.weaponFireSfx = self.weaponFireSfx
		Anim_fireAt(bullet, self.firing.x, self.firing.y, self.bulletSpeed, 3)
	end)
	self.fireTimer:setMode(MOAITimer.LOOP)
	self.fireTimer:start()
	return self
end
function Fighter.fireAt(self, x, y, range)
	local x0, y0 = self:getLoc()
	local dis = distance(x0, y0, x, y)
	local firing = self.firing
	if dis < self.fireRange and ship.hp > 0 then
		self.firing = {
			x = x + range - math.random(2 * range),
			y = y + range - math.random(2 * range),
		}
		self:setRot(angle(x0, y0, x, y) - 90)
	elseif self.firing then
		self.firing = nil
	end
	if not firing and self.firing then
		self.muzzle:addLayer(self.layer)
	end
	if firing and not self.firing then
		self.muzzle:removeLayer()
	end
end
function Fighter.dead(self)
	self:removeLayer()
	self.muzzle:removeLayer()
	self.fireTimer:stop()
end

Projectile = {}
function Projectile.new(layer, def)
	local self = sprite("alienAntiCapital02WeaponBasic.atlas.png")
	self:setLoc(0, SCRREEN_HEIGHT)
	self:setRot(-90)
	self:setScl(2, 2)
	
	self.speed = 0.002
	self.fireAt = Projectile.fireAt
	self:addLayer(layer)
	
	if def.weaponFireSfx ~= nil then
		self.weaponFireSfx = sound.new(def.weaponFireSfx)
	end
	if def.weaponImpactSfx ~= nil then
		self.weaponImpactSfx = sound.new(def.weaponImpactSfx)
	end
	
	self.impact = Particle.new("particles/alienExplosionLarge.pex", mainAS, layer)
	return self
end
function Projectile.fireAt(self, x0, y0, r0, x1, y1, r1)
	x0 = x0 + r0 - math.random(2 * r0)
	y0 = y0 + r0 - math.random(2 * r0)
	self:setLoc(x0, y0)
	Anim_loop(self, "projectile")
	
	x1 = x1 + r1 - math.random(2 * r1)
	y1 = y1 + r1 - math.random(2 * r1)
	if self.weaponFireSfx then
		self.weaponFireSfx:play()
	end
	
	self:setRot(angle(x0, y0, x1, y1) - 90)
	local thread = MOAIThread.new()
	thread:run(function()
		local dis = distance(x0, y0, x1, y1)
		MOAIThread.blockOnAction(self:seekLoc(
			x1, y1,
			dis * self.speed,
			MOAIEaseType.LINEAR))
			
		if self.weaponImpactSfx then
			self.weaponImpactSfx:play()
		end
		
		level_fx_camera_shake(10, 2)
		self:removeLayer()
		if self.impact then
			ship.damageHp()
			if ship.hp <= 0 then
				motherShip_dead()
			end
			self.impact:setLoc(x1, y1)
			self.impact:begin(function()
			end)
		end
	end)
end

vertexFormat = MOAIVertexFormat.new ()
vertexFormat:declareCoord ( 1, MOAIVertexFormat.GL_FLOAT, 2 )
vertexFormat:declareUV ( 2, MOAIVertexFormat.GL_FLOAT, 2 )
vertexFormat:declareColor ( 3, MOAIVertexFormat.GL_UNSIGNED_BYTE )

lightingVbo = MOAIVertexBuffer.new ()
lightingVbo:setFormat ( vertexFormat )

lightingIbo = MOAIIndexBuffer.new ()

lightingMesh = MOAIMesh.new ()
lightingMesh:setTexture ( resource.texture("light.png") )
lightingMesh:setVertexBuffer ( lightingVbo )
lightingMesh:setIndexBuffer ( lightingIbo )
lightingMesh:setPrimType ( MOAIMesh.GL_TRIANGLES )

lightingProp = MOAIProp2D.new ()
lightingProp:setDeck ( lightingMesh )
lightingProp:setPriority(3)
lightingProp:setBlendMode(MOAIProp.BLEND_ADD)

laser = {
	trac = {},
	n = 0,
	length = 0.2,
	speed = 2000,
	width = 10,
	life = 10,
	now = 0,
	span = 3,
	damage = 5,
	damageSpan = 0.05,
	sfx = "laser",
}
laserVbo = MOAIVertexBuffer.new ()
laserVbo:setFormat (vertexFormat)
laserIbo = MOAIIndexBuffer.new ()

laserMesh = MOAIMesh.new ()
laserMesh:setTexture (resource.texture("laser.png"))
laserMesh:setVertexBuffer (laserVbo)
laserMesh:setIndexBuffer (laserIbo)
laserMesh:setPrimType (MOAIMesh.GL_TRIANGLES)

laserProp = MOAIProp2D.new ()
laserProp:setDeck (laserMesh)
laserProp:setPriority(3)
laserProp:setBlendMode(MOAIProp.BLEND_ADD)

space = MOAICpSpace.new ()
space:setIterations ( 5 )
space:start ()

wall = space:getStaticBody ()
function addSegment ( x0, y0, x1, y1 )
	local shape = wall:addSegment ( x0, y0, x1, y1 )
	shape:setElasticity ( 1 )
	shape:setType ( 2 )
	shape.name = "wall"
	space:insertPrim ( shape )
end

local radius = 50
addSegment ( -SCREEN_HEIGHT/2 - radius, -SCREEN_WIDTH/2 - radius, SCREEN_HEIGHT/2 + radius, -SCREEN_WIDTH/2 - radius )
addSegment ( -SCREEN_HEIGHT/2 - radius, SCREEN_WIDTH/2 + radius, SCREEN_HEIGHT/2 + radius, SCREEN_WIDTH/2 + radius )
addSegment ( -SCREEN_HEIGHT/2 - radius, -SCREEN_WIDTH/2 - radius, -SCREEN_HEIGHT/2 - radius, SCREEN_WIDTH/2 + radius )
addSegment ( SCREEN_HEIGHT/2 + radius, -SCREEN_WIDTH/2 - radius, SCREEN_HEIGHT/2 + radius, SCREEN_WIDTH/2 + radius )

ball = MOAICpBody.new ( 1, moment )
space:insertPrim ( ball )

local shape = ball:addCircle ( radius, 0, 0 )
shape:setElasticity ( 1 )
shape:setType ( 1 )
shape.name = "ball"
space:insertPrim ( shape )

function handleCollisions ( event, a, b, arb )
	if laser.age < laser.life then
		laser.age = laser.age + 1
		sound.new(laser.sfx):play()
		print ("collision", a.name, b.name, laser.age)
	end

	return true
end

space:setCollisionHandler ( 1, 2, MOAICpSpace.BEGIN, handleCollisions )

function attack(x0, y0, x1, y1, damage, span)
	local props = {partition:propListForRect(x0, y0, x1, y1)}
	for k, v in pairs(props) do
		if v.isFighter then
			for i, f in ipairs(fighters) do
				repeat
					if v == f then
						local last = v._lastDamageTime or 0
						if os.clock() - last < span then
							break
						end
						v._lastDamageTime = os.clock()
						v.hp = v.hp - damage
						if v.hp <= 0 then
							for i, f in ipairs(fighters) do
								if v == f then
									local ps = Particle.new("particles/antiBomberExplosionSmall.pex", mainAS, layer)
									ps:setLoc(f:getLoc())
									ps:begin()
									f:dead()
									table.remove(fighters, i)
								end
							end
						else
							local ps = Particle.new("particles/antiBomberImpactHigh.pex", mainAS, layer)
							ps:setParent(v)
							ps:begin()
						end
					end
				until true
			end
		elseif v.isMotherShip then
			local last = v._lastDamageTime or 0
			if os.clock() - last < span then
				return
			end
			v._lastDamageTime = os.clock()
			sound.new(projImpactSfx[math.random(#projImpactSfx)]):play()
			local ps = Particle.new("particles/antiBomberExplosionSmall.pex", mainAS, layer)
			ps:setLoc((x0 + x1) / 2, (y0 + y1) / 2)
			ps:begin()
			level_fx_camera_shake(10, 2)
		end
	end
end
flySpan = 0.05
fighterOffset = 25
local delta = 0
local trac = {n = 0}
local now = os.clock()
function onTick(dt)
	if gm then
		gm.step()
	end
	
	if dt > 0 then
		if not gaming then
			return
		end
		local ttime = mainAS:getTime()
		local camShakeStrength = _calc_camera_shake(ttime)
		camera:addLoc(-camShakeX, -camShakeY)
		camShakeX =(math.random() - 0.5) * camShakeStrength
		camShakeY =(math.random() - 0.5) * camShakeStrength
		camera:addLoc(camShakeX, camShakeY)

		delta = delta + dt
		if fighters and delta > flySpan then
			for k, v in ipairs(fighters) do
				Ship_TrackPath(v, delta, v.flyway, fighterOffset)
				v:fireAt(0, 0, 20)
			end
			delta = 0
		end
	end
	
	if os.clock() - now > 0.01 then
		local span = os.clock() - now
		now = os.clock()
		
		if laser.n > 1 then
			if laser.age < laser.life then
				local x, y = ball:getPos()
				laser.n = laser.n + 1
				laser.trac[laser.n] = {
					x = x,
					y = y,
					birth = now,
				}
				local prev = laser.trac[laser.n - 1]
				attack(prev.x, prev.y, x, y, laser.damage, laser.damageSpan)
			end
			
			if now - laser.trac[1].birth > laser.length then
				table.remove(laser.trac, 1)
				laser.n = laser.n - 1
				
				if laser.n < 2 then
					laser.n = 0
					layer:removeProp (laserProp)
					ball:setVel(0, 0)
				end
			end
		end
		
		if laser.n > 1 then
			laserVbo:reserveVerts ((laser.n - 1) * 4)
			laserIbo:reserve ((laser.n - 1) * 6)
			local idx, tri = 0, 0
			local prev = laser.trac[1]
			for i = 2, laser.n do
				local pt = laser.trac[i]
				local angle = math.atan2(pt.y - prev.y, pt.x - prev.x)
				local angle = angle + math.pi / 2
				local px1 = prev.x + laser.width * math.cos(angle)
				local py1 = prev.y + laser.width * math.sin(angle)
				local px2 = prev.x + laser.width * math.cos(angle + math.pi)
				local py2 = prev.y + laser.width * math.sin(angle + math.pi)
				local x1 = pt.x + laser.width * math.cos(angle)
				local y1 = pt.y + laser.width * math.sin(angle)
				local x2 = pt.x + laser.width * math.cos(angle + math.pi)
				local y2 = pt.y + laser.width * math.sin(angle + math.pi)
				local u1, v1 = 0, 0
				local u2, v2 = 1, 1
				
				laserVbo:writeFloat(px1, py1)
				laserVbo:writeFloat(u1, v2)
				laserVbo:writeColor32 ( 1, 1, 1 )
				laserVbo:writeFloat(px2, py2)
				laserVbo:writeFloat(u2, v2)
				laserVbo:writeColor32 ( 1, 1, 1 )
				laserVbo:writeFloat(x1, y1)
				laserVbo:writeFloat(u1, v1)
				laserVbo:writeColor32 ( 1, 1, 1 )
				laserVbo:writeFloat(x2, y2)
				laserVbo:writeFloat(u2, v1)
				laserVbo:writeColor32 ( 1, 1, 1 )
				laserIbo:setIndex(idx + 1, tri + 1)
				laserIbo:setIndex(idx + 2, tri + 3)
				laserIbo:setIndex(idx + 3, tri + 4)
				laserIbo:setIndex(idx + 4, tri + 1)
				laserIbo:setIndex(idx + 5, tri + 4)
				laserIbo:setIndex(idx + 6, tri + 2)
				idx = idx + 6
				tri = tri + 4
				
				prev = pt
			end
			laserVbo:bless ()
			layer:insertProp (laserProp)
		end
	
		if trac.n > 2 then
			for i = 1, trac.n do
				if trac[i] and now - trac[i].birth > 0.3 then
					table.remove(trac, i)
					trac.n = trac.n - 1
				end
			end
			if trac.n > 2 then
				local vbs = (trac.n - 1) * 4
				local ibs = (trac.n - 1) * 6
				lightingVbo:reserveVerts ( vbs )
				lightingIbo:reserve ( ibs )
				local size = 30
				local prev = trac[1]
				local pt = trac[2]
				local span = now - prev.birth
				local angle = math.atan2(pt.y - prev.y, pt.x - prev.x) + math.pi / 2
				local len = (1 - ((now - pt.birth) / span)^2) * size
				local px1 = prev.x + len * math.cos(angle)
				local py1 = prev.y + len * math.sin(angle)
				local px2 = prev.x + len * math.cos(angle + math.pi)
				local py2 = prev.y + len * math.sin(angle + math.pi)
				local idx = 0
				local tri = 0
				for i = 2, trac.n do
					local pt = trac[i]
					local angle = math.atan2(pt.y - prev.y, pt.x - prev.x) + math.pi / 2
					local len = (1 - ((now - pt.birth) / span)^2) * size
					local x1 = pt.x + len * math.cos(angle)
					local y1 = pt.y + len * math.sin(angle)
					local x2 = pt.x + len * math.cos(angle + math.pi)
					local y2 = pt.y + len * math.sin(angle + math.pi)
					local u1, v1 = 70/212, 73/963
					local u2, v2 = 160/212, 169/963
					
					lightingVbo:writeFloat(px1, py1)
					lightingVbo:writeFloat(u1, v2)
					lightingVbo:writeColor32 ( 1, 1, 1 )
					lightingVbo:writeFloat(px2, py2)
					lightingVbo:writeFloat(u2, v2)
					lightingVbo:writeColor32 ( 1, 1, 1 )
					lightingVbo:writeFloat(x1, y1)
					lightingVbo:writeFloat(u1, v1)
					lightingVbo:writeColor32 ( 1, 1, 1 )
					lightingVbo:writeFloat(x2, y2)
					lightingVbo:writeFloat(u2, v1)
					lightingVbo:writeColor32 ( 1, 1, 1 )
					lightingIbo:setIndex(idx + 1, tri + 1)
					lightingIbo:setIndex(idx + 2, tri + 3)
					lightingIbo:setIndex(idx + 3, tri + 4)
					lightingIbo:setIndex(idx + 4, tri + 1)
					lightingIbo:setIndex(idx + 5, tri + 4)
					lightingIbo:setIndex(idx + 6, tri + 2)
					idx = idx + 6
					tri = tri + 4
					
					px1, py1, px2, py2 = x1, y1, x2, y2
					prev = pt
				end
				lightingVbo:bless ()
				layer:insertProp ( lightingProp )
				lightingProp:forceUpdate()
			else
				trac = {n = 0}
				layer:removeProp ( lightingProp )
			end
		end
	end
end

uipartition = MOAIPartition.new()
uilayer:setPartition(uipartition)

uiClickSfx = "btn"
function button(res, index, x, y, xScl, yScl, cb)
	local prop = MOAIProp2D.new()
	local deck = resource.deck(res)
	prop.click = cb
	prop.scale = true
	prop:setDeck(deck)
	prop.setIndexByName = function(self, name)
		self:setIndex(deck:indexOf(name))
	end
	prop:setPriority(2)
	prop:setLoc(x, y)
	prop:setScl(xScl, yScl)
	prop:setIndex(index)
	uilayer:insertProp(prop)
	return prop
end
function widget(res, x, y, xScl, yScl, cb, rot, scale, priority)
	local prop = _G[res] or MOAIProp2D.new()
	local deck = resource.deck(res)
	_G[res] = prop
	prop.click = cb
	prop.scale = scale
	prop.clickSfx = uiClickSfx
	prop:setDeck(deck)
	prop:setPriority(priority or 2)
	if rot then
		prop:setRot(rot)
	end
	prop:setLoc(x, y)
	prop:setScl(xScl, yScl)
	uilayer:insertProp(prop)
	return prop
end
function widget_new(res, x, y, xScl, yScl, cb, rot, scale, priority)
	local prop = MOAIProp2D.new()
	local deck = resource.deck(res)
	prop.click = cb
	prop.scale = scale
	prop:setDeck(deck)
	prop:setPriority(2)
	if rot then
		prop:setRot(rot)
	end
	prop:setLoc(x, y)
	prop:setScl(xScl, yScl)
	uilayer:insertProp(prop)
	return prop
end
function image(res, x, y, xScl, yScl, rot, priority, where)
	where = where or layer
	local prop = _G[res] or MOAIProp2D.new()
	local deck = resource.deck(res)
	_G[res] = prop
	prop:setDeck(deck)
	prop:setPriority(priority or 2)
	if rot then
		prop:setRot(rot)
	end
	prop:setLoc(x, y)
	prop:setScl(xScl, yScl)
	where:insertProp(prop)
	return prop
end
function image_new(res, x, y, xScl, yScl, rot, priority, where)
	where = where or layer
	local prop = MOAIProp2D.new()
	local deck = resource.deck(res)
	prop:setDeck(deck)
	prop:setPriority(priority or 2)
	if rot then
		prop:setRot(rot)
	end
	prop:setLoc(x, y)
	prop:setScl(xScl, yScl)
	where:insertProp(prop)
	return prop
end

bombFlySfx = "Fx12302_blasts"
bombImpactSfx = {
	"f8100_explosions-5",
	"f8101_explosions-6",
	"f8102_explosions-7",
}
bombSpan = 0.35
bombCount = 6
projImpactSfx = {
	"game_explosion_01",
	"game_explosion_02",
}
projFlySfx = "game_blossomanticipation_01"
local proj = function()
	local fire = {
		"ui_swipe_forward_01",
	}
	sound.new(projFlySfx):play()
	local timer = MOAITimer.new()
	timer:setSpan(0.1)
	timer:setMode(MOAITimer.LOOP)
	local i = 1
	timer:setListener(MOAITimer.EVENT_TIMER_END_SPAN, function()
		local proj = Projectile.new(layer, {
			weaponFireSfx = fire[math.random(#fire)],
			weaponImpactSfx = projImpactSfx[math.random(#projImpactSfx)],
		})
		proj:fireAt(0, SCREEN_HEIGHT + SCREEN_WIDTH / 8, SCREEN_WIDTH / 8, 0, 0, 60)
		i = i + 1
		if i > 5 then
			timer:stop()
		end
	end)
	timer:start()
end
local bomb = function()
	sound.new(bombFlySfx):play()
	if b1 then b1:removeLayer() end
	if b2 then b2:removeLayer() end
	if b3 then b3:removeLayer() end
	local scale = 1
	b1 = sprite("alienAntiCapital01.atlas.png")
	b1:setIndex(2)
	b1:setScl(scale, scale)
	b1:addLayer(layer)
	b1:setLoc(0, -400)
	b1:seekLoc(0, 800, 1, MOAIEaseType.LINEAR)
	b2 = sprite("alienAntiCapital01.atlas.png")
	b2:setIndex(2)
	b2:setScl(scale, scale)
	b2:addLayer(layer)
	b2:setLoc(-100, -600)
	b2:seekLoc(-100, 700, 1, MOAIEaseType.LINEAR)
	b3 = sprite("alienAntiCapital01.atlas.png")
	b3:setIndex(2)
	b3:setScl(scale, scale)
	b3:addLayer(layer)
	b3:setLoc(100, -600)
	b3:seekLoc(100, 700, 1, MOAIEaseType.LINEAR)

	local timer = MOAITimer.new()
	timer:setSpan(0.5)
	timer:setListener(MOAITimer.EVENT_TIMER_END_SPAN, function()
		local timer = MOAITimer.new()
		timer:setSpan(bombSpan)
		timer:setMode(MOAITimer.LOOP)
		timer:start()
		local i = 1
		timer:setListener(MOAITimer.EVENT_TIMER_END_SPAN, function()
			ship.damageHp()
			if ship.hp <= 0 then
				motherShip_dead()
			end
			local p = Particle.new("particles/alienExplosionLarge.pex", mainAS, layer)
			p:setScl(1.5, 1.5)
			p:setLoc(math.random(-200, 200), math.random(-200, 200))
			p:begin(function()
			end)
			local bomb = sound.new(bombImpactSfx[math.random(#bombImpactSfx)])
			bomb:play()
			level_fx_camera_shake(20, 3)
			i = i + 1
			if i > bombCount then
				timer:stop()
			end
		end)
	end)
	timer:start()
end

local lightingSfxNow = 0
local lightingNow = 0
local lighted = 0
lightingSpan = 2
lightingSfx = "Fx12805"
lightingSfxSpan = 0.5
lightingDamage = 2
lightingDamageSpan = 0.1
lightingDist = 20
laserDist = 20
function pointerCallback(x, y)
    mouseX, mouseY = layer:wndToWorld(x, y)
	if drawing and gaming then
		if fightersGo then
			flyway:append(mouseX, mouseY)
			flyway:update()
		end
	end
	
	if drawing then 
		if os.clock() - lightingNow < lightingSpan then
			if os.clock() - lightingSfxNow > lightingSfxSpan then
				lightingSfxNow = os.clock()
				sound.new(lightingSfx):play()
			end
			local pt = trac[1]
			if pt and (pt.x - mouseX)^2 + (pt.y - mouseY)^2 < lightingDist^2 then
				return
			end
			if trac.n > 1 then
				local x0, y0 = trac[trac.n - 1].x, trac[trac.n - 1].y
				local x1, y1 = trac[trac.n].x, trac[trac.n].y
				attack(x0, y0, x1, y1, lightingDamage, lightingDamageSpan)
			end
			trac.n = trac.n + 1
			trac[trac.n] = {x = mouseX, y = mouseY, birth = os.clock()}
		end
		if os.clock() - laser.now < laser.span and laser.n < 2 then
			local pt = laser.trac[1]
			if pt and (pt.x - mouseX)^2 + (pt.y - mouseY)^2 < laserDist^2 then
				return
			end
			laser.n = laser.n + 1
			laser.trac[laser.n] = {x = mouseX, y = mouseY, birth = os.clock()}
			if laser.n == 2 then
				local prev = laser.trac[1]
				local pt = laser.trac[2]
				local angle = math.atan2(pt.y - prev.y, pt.x - prev.x)
				ball:setPos(pt.x, pt.y)
				ball:setVel(laser.speed * math.cos(angle), laser.speed * math.sin(angle))
				laser.age = 0
				sound.new(laser.sfx):play()
				print("cast laser!!!")
			end
		end
	end
	lastX, lastY = mouseX, mouseY
end
function clickCallback(down)
	if down then
		pick = uipartition:propForPoint(mouseX, mouseY)
		if pick then
			print("click", pick)
			if pick.clickSfx then
				sound.new(pick.clickSfx):play()
			end
			if pick.click then
				pick.click()
			end
			if pick.scale then
				local thread = MOAIThread.new()
				thread:run(function()
					local pick = pick
					pick:setPriority(3)
					MOAIThread.blockOnAction(pick:moveScl(0.25, 0.25, 0.125, MOAIEaseType.EASE_IN))
					MOAIThread.blockOnAction(pick:moveScl(-0.25, -0.25, 0.125, MOAIEaseType.EASE_IN))
					pick:setPriority(2)
				end)
			end
			return
		end
		
		if click_scene then
			click_scene()
			return
		end
		
		if not gaming then
			return
		end
	else
		if pick then
			return
		end
		
		if not gaming then
			return
		end
		
		if flyway then
			flyway:smooth(smooth_iter or 10, smooth_weight or 10)
		end
		
		if fightersGo then
			fightersGo = nil
			local def = {
				weaponFireSfx = "alienFighterLaser?volum=0.5",
				-- weaponImpactSfx = "alienBomber?volum=0.2",
			}
			oldway = flyway
			flyway = nil
			
			local spawn = function()
				local fighter = Fighter.new(layer, def)
				fighter.flyway = oldway
				fighter:setLoc(0, SCREEN_HEIGHT)
				table.insert(fighters, fighter)
			end
			spawn()
			for i = 1, 4 do
				local timer = MOAITimer.new()
				timer:setSpan(i * 0.7)
				timer:setMode(MOAITimer.LOOP)
				timer:setListener(MOAITimer.EVENT_TIMER_END_SPAN, function()
					spawn()
					timer:stop()
				end)
				timer:start()
			end
		end
	end
	
	drawing = down
end

function init()
	sound.new("first_time_play"):play()
	local deck = resource.deck("LoadingScreen.jpg")
	local w, h = deck:getSize()
	xScl, yScl = SCREEN_WIDTH / w, SCREEN_HEIGHT / h
	bg = image("LoadingScreen.jpg", 0, 0, xScl, yScl, -90)
	
	gate1 = image_new("gate.jpg", -SCREEN_WIDTH/2, 0, xScl, yScl, -90, 1, toplayer)
	gate2 = image_new("gate.jpg", SCREEN_WIDTH/2, 0, xScl, yScl, 90, 1, toplayer)
	
	click_scene = play_main
end

function play_main()
	print("play_main")
	
	click_scene = nil
	local deck = resource.deck("bg.jpg")
	bg:setDeck(deck)
	bg:setLoc(-20, -160)
	
	girl = image("girl.png", -200, 800, xScl, yScl)
	girl:setRot(-90)
	girl:seekLoc(-200, 400, 0.5, MOAIEaseType.EASE_IN)
	
	quest = widget("quest.png", 200, -900, xScl, yScl, function()
		gate1:seekLoc(-SCREEN_WIDTH/8 - 18, 0, 0.5, MOAIEaseType.EASE_IN)
		gate2:seekLoc(SCREEN_WIDTH/8 + 18, 0, 0.5, MOAIEaseType.EASE_IN)
		local h
		h = timer.new(0.7, function()
			play_quest()
			sound.new("doorclose"):play()
			gate1:seekLoc(-SCREEN_WIDTH/2, 0, 0.5, MOAIEaseType.EASE_IN)
			gate2:seekLoc(SCREEN_WIDTH/2, 0, 0.5, MOAIEaseType.EASE_IN)
			h:stop()
		end)
	end)
	quest:setRot(-90)
	quest:seekLoc(200, -400, 0.5, MOAIEaseType.EASE_IN)
	sound.new("ui_swipe_forward_01"):play()
	
	battle = widget("battle.png", 100, -900, xScl, yScl)
	battle:setRot(-90)
	local h
	h = timer.new(0.2, function()
		sound.new("ui_swipe_forward_01"):play()
		battle:seekLoc(100, -400, 0.4, MOAIEaseType.EASE_IN)
		h:stop() 
	end)
	
	fleet = widget("fleet.png", 0, -900, xScl, yScl, play_fleet)
	fleet:setRot(-90)
	local h
	h = timer.new(0.4, function()
		sound.new("ui_swipe_forward_01"):play()
		fleet:seekLoc(0, -400, 0.4, MOAIEaseType.EASE_IN)
		h:stop() 
	end)
	
	friend = widget("friend.png", -100, -900, xScl, yScl)
	friend:setRot(-90)
	local h
	h = timer.new(0.6, function()
		friend:seekLoc(-100, -400, 0.4, MOAIEaseType.EASE_IN)
		h:stop() 
	end)
end

function close_main()
	girl:seekLoc(-200, 800, 0.3, MOAIEaseType.EASE_IN)
	quest:seekLoc(200, -900, 0.3, MOAIEaseType.EASE_IN)
	sound.new("ui_swipe_forward_01"):play()
	
	local h
	h = timer.new(0.1, function()
		sound.new("ui_swipe_forward_01"):play()
		battle:seekLoc(100, -900, 0.3, MOAIEaseType.EASE_IN)
		h:stop() 
	end)
	
	local h
	h = timer.new(0.2, function()
		fleet:seekLoc(0, -900, 0.3, MOAIEaseType.EASE_IN)
		h:stop() 
	end)
	
	local h
	h = timer.new(0.3, function()
		friend:seekLoc(-100, -900, 0.3, MOAIEaseType.EASE_IN)
		h:stop() 
	end)
end

function pop_role(which)
	close_role()
	black = image("black.png", 0, 0, xScl, yScl, -90, 10, uilayer)
	role = image(which, 0, 0, 0.5, 0.5, -90, 10, uilayer)
	ok = widget("ok.png", -150, -100, 0.5, 0.5, function()
		sound.new("doorclose"):play()
		gate1:seekLoc(-SCREEN_WIDTH/8 - 18, 0, 0.5, MOAIEaseType.EASE_IN)
		gate2:seekLoc(SCREEN_WIDTH/8 + 18, 0, 0.5, MOAIEaseType.EASE_IN)
		local h
		h = timer.new(0.7, function()
			close_role()
			play_game()
			gate1:seekLoc(-SCREEN_WIDTH/2, 0, 0.5, MOAIEaseType.EASE_IN)
			gate2:seekLoc(SCREEN_WIDTH/2, 0, 0.5, MOAIEaseType.EASE_IN)
			h:stop()
		end)
	end, -90, true, 11)
	cancel = widget("cancel.png", -150, -250, 0.5, 0.5, close_role, -90, true, 11)
	
	role:seekScl(xScl, yScl, 0.5, MOAIEaseType.EASE_IN)
	ok:seekScl(1.5, 1.5, 0.5, MOAIEaseType.EASE_IN)
	cancel:seekScl(1.5, 1.5, 0.5, MOAIEaseType.EASE_IN)
end

function close_role()
	if role then
		uilayer:removeProp(black)
		uilayer:removeProp(role)
		uilayer:removeProp(ok)
		uilayer:removeProp(cancel)
		role = nil
	end
end

function play_quest()
	print("play_quest")
	girl:setLoc(-200, 800)
	quest:setLoc(200, -900)
	battle:setLoc(100, -900)
	fleet:setLoc(0, -900)
	friend:setLoc(-100, -900)
		
	click_scene = nil
	local deck = resource.deck("bg_quest.png")
	bg:setDeck(deck)
	bg:setLoc(0, 0)
	island1 = widget("machinegun_market.png", 0, 0, 1, 1, function() pop_role("pop.png") end, -90, true)
	island2 = widget("commandcenter_market.png", 100, 400, 1, 1, function() pop_role("pop2.png") end, -90, true)
	island3 = widget("tallweeds_last.png", -150, 300, 0.6, 0.6, function() pop_role("pop3.png") end, -90, true)
end

function close_quest()
	uilayer:removeProp(island1)
	uilayer:removeProp(island2)
	uilayer:removeProp(island3)
end

function play_fleet()
	print("play_fleet")
	
	close_main()
	local h
	h = timer.new(0.5, function()
		bg:seekLoc(-20, 160, 0.5, MOAIEaseType.EASE_IN)
		h:stop() 
	end)
	
	local h
	h = timer.new(1, function()
		sound.new("ui_swipe_forward_01"):play()
		equip = image("equip.png", SCREEN_WIDTH / 2 + 50, 0, xScl, yScl)
		equip:setRot(-90)
		equip:seekLoc(0, 0, 0.5, MOAIEaseType.EASE_IN)
		
		man = image("man.png", -200, -800, xScl, yScl)
		man:seekLoc(-200, -400, 0.5, MOAIEaseType.EASE_IN)
		man:setRot(-90)
		
		click_scene = function()
			sound.new("ui_swipe_forward_01"):play()
			equip:seekLoc(SCREEN_WIDTH / 2 + 50, 0, 0.3, MOAIEaseType.EASE_IN)
			man:seekLoc(-200, -800, 0.3, MOAIEaseType.EASE_IN)
			local h
			h = timer.new(0.3, function()
				local deck = resource.deck("bg.jpg")
				bg:setDeck(deck)
				bg:seekLoc(-20, -160, 0.5, MOAIEaseType.EASE_IN)
				h:stop()
			end)
			local h
			h = timer.new(0.7, function()
				play_main()
				h:stop()
			end)
		end
		h:stop()
	end)
end

function play_game()
	print("play_game")
	close_quest()
	
	layer:removeProp(bg)
	click_scene = nil
	
	gaming = true
	space = sprite("galaxy01MapBG.png")
	space:setScl(2, 2)
	layer:insertProp(space)
	
	hud = sprite("hud.png")
	hud:setScl(0.6, 0.6)
	hud:setRot(-90)
	hud:setLoc(260, 350)
	uilayer:insertProp(hud)
	
	uiClickSfx = "ui_upgrade_select_01"
	btn1 = widget("icon1.png", -250, 500, 1.5, 1.5, function()
		local h
		h = timer.new(0.1, function()
			fightersGo = true
			h:stop() 
		end)
		if oldway then
			layer:removeProp(oldway)
			oldway = nil
		end
		flyway = path.new(nil, "#00ff0044")
		flyway:setBlendMode(MOAIProp.BLEND_ADD)
		flyway.penWidth = 2
		flyway.currentPathPoint = 1
		layer:insertProp(flyway)
	end, -90, true)
	btn2 = widget("icon2.png", -250, 400, 1.5, 1.5, proj, -90, true)
	btn3 = widget("icon3.png", -250, 300, 1.5, 1.5, bomb, -90, true)
	btn4 = widget("icon4.png", -250, 200, 1.5, 1.5, function()
		lightingNow = os.clock()
	end, -90, true)
	btn5 = widget("icon5.png", -250, 100, 1.5, 1.5, function()
		laser.now = os.clock()
	end, -90, true)
	btn6 = widget_new("icon.png", -250, 0, 1.5, 1.5, nil, -90, true)
	
	motherShip()
	motherShip_fire(-30, 0, 300)
	motherShip_fire(30, 0, 300)
end

if MOAIInputMgr.device.pointer then
	-- mouse input
	MOAIInputMgr.device.pointer:setCallback(pointerCallback)
	MOAIInputMgr.device.mouseLeft:setCallback(clickCallback)
else
	-- touch input
	MOAIInputMgr.device.touch:setCallback (function(eventType, idx, x, y, tapCount)
		if idx ~= 0 then
			return
		end
		pointerCallback(x, y)
		if eventType == MOAITouchSensor.TOUCH_DOWN then
			clickCallback(true)
		elseif eventType == MOAITouchSensor.TOUCH_UP then
			clickCallback(false)
		end
	end)
end

init()
mainAS:run(onTick)
