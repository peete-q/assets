
local math2d = require "math2d"
local resource = require "resource"
local Sprite = require "Sprite"
local Bullet = require "Bullet"
local Factor = require "Factor"

local distance = math2d.distance
local distanceSq = math2d.distanceSq

local function concat(...)
	local s = ""
	for k, v in ipairs{...} do
		s = s..tostring(v)
	end
	return s
end

local Entity = {
	FORCE_PLAYER = 1,
	FORCE_ENEMY = 2,
	FORCE_ALL = 3,
}

undefined = false

local _LOCK_DIST = 10
local _RECOVER_TICKS = 10
local _ACCELERATION_MAX = 5

local _defaultProps = {
	hp = 100,
	maxHp = 100,
	recoverHp = 1,
	bodySize = 10,
	moveSpeed = 0.1,
	attackPower = 1,
	attackSpeed = 10,
	attackRange = 100,
	guardRange = 150,
	shots = 1,
	kind = "normal",
	movable = true,
	lockTarget = true,
	
	specialPower = undefined,
	bodyGfx = undefined,
	propellerGfx = undefined,
	muzzleGfx = undefined,
	fireSfx = undefined,
	explodeGfx = undefined,
	explodeSfx = undefined,
	
	bullet = {},
	attackPriorities = {},
	
	_ticks = undefined,
}

Entity.__index = function(self, key)
	if self._db[key] ~= nil then
		return self._db[key]
	end
	if self._props[key] ~= nil then
		return self._props[key]
	end
	if _defaultProps[key] ~= nil then
		return _defaultProps[key]
	end
	return Entity[key]
end

Entity.__newindex = function(self, key, value)
	if _defaultProps[key] ~= nil then
		self._db[key] = value
	else
		rawset(self, key, value)
	end
end

function Entity.new(props, force)
	local self = {
		_force = force,
		_props = props or {},
		_db = {},
		_lastTargets = {},
		_attackSpeedFactor = Factor.new(),
		_moveSpeedFactor = Factor.new(),
		_recoverHpFactor = Factor.new(),
		_attackPowerFactor = Factor.new(),
		_lastRecoverTicks = 0,
		_moveSpeed = 0,
		_logging = false,
		_scene = nil,
		_motionDriver = nil,
		_target = nil,
		_rigid = nil,
	}
	setmetatable(self, Entity)
	
	self._runState = self.stateIdle
	self._fireRange = self.attackRange
	self._force.enemy = self:getEnemy()
	self._body = Sprite.new(props.bodyGfx)
	if props.propellerGfx then
		self._propeller = Sprite.new(props.propellerGfx)
		self._body:add(self._propeller)
	end
	if props.muzzleGfx then
		self._muzzle = Sprite.new(props.muzzleGfx)
	end
	self._drifting = MOAIThread.new()
	self._drifting:run(function()
		while true do
			local n = math.random(90, 100) / 100
			MOAIThread.blockOnAction(self._body:seekScl(n, n, n, MOAIEaseType.SOFT_SMOOTH))
			MOAIThread.blockOnAction(self._body:seekScl(1, 1, n, MOAIEaseType.SOFT_SMOOTH))
		end
	end)
	return self
end

function Entity:destroy()
	self._scene:remove(self)
	
	if self._body then
		self._body:destroy()
		self._body = nil
	end
	
	if self._motionDriver then
		self._motionDriver:stop()
		self._motionDriver = nil
	end
	
	if self._drifting then
		self._drifting:stop()
		self._drifting = nil
	end
	
	if self._rigid then
		self._rigid:destroy()
		self._rigid = nil
	end
end

function Entity:log(...)
	if self._logging then
		print(concat("[", self, "]"), ...)
	end
end

function Entity:logIf(cond, ...)
	if self._logging and cond then
		print(concat("[", self, "]"), ...)
	end
end

function Entity:loadDB(db)
	self._db = db
end

function Entity:setPriority(value)
	self._body:setPriority(value)
end

function Entity:addAttackSpeedFactor(value, duration)
	self._attackSpeedFactor:add(value, self._scene.ticks + duration)
end

function Entity:addMoveSpeedFactor(value, duration)
	self._moveSpeedFactor:add(value, self._scene.ticks + duration)
end

function Entity:addRecoverHpFactor(value, duration)
	self._recoverHpFactor:add(value, self._scene.ticks + duration)
end

function Entity:addAttackPowerFactor(value, duration)
	self._attackPowerFactor:add(value, self._scene.ticks + duration)
end

function Entity:getAttackSpeed()
	local speed = self.attackSpeed / (1 + self._attackSpeedFactor:calc() + self._force.attackSpeedFactor:calc())
	return math.floor(speed)
end

function Entity:getMoveSpeed()
	local acc = self:getAcceleration()
	local speed = self.moveSpeed / (1 + self._moveSpeedFactor:calc() + self._force.moveSpeedFactor:calc())
	return speed / acc
end

function Entity:getRecoverHp()
	return self.recoverHp * (1 + self._recoverHpFactor:calc() + self._force.recoverHpFactor:calc())
end

function Entity:getAttackPower()
	return self.attackPower + self._attackPowerFactor:calc() + self._force.attackPowerFactor:calc()
end

function Entity:setLayer(layer)
	self._body:setLayer(layer)
end

function Entity:add(fx)
	self._body:add(fx)
end

function Entity:remove(fx)
	self._body:remove(fx)
end

function Entity:setWorldLoc(x, y)
	self._body:setLoc(x, y)
end

function Entity:getWorldLoc()
	return self._body:getLoc()
end

function Entity:moveTo(x, y, speed)
	self:stop()
	local sx, sy = self:getWorldLoc()
	local dist = distance(sx, sy, x, y)
	self._moveSpeed = speed or self:getMoveSpeed()
	self._motionDriver = self._body:seekLoc(x, y, self._moveSpeed * dist, MOAIEaseType.LINEAR)
	self._dx = x
	self._dy = y
	self:_eraseRigid()
end

function Entity:correctMoveSpeed()
	if not self:isMoving() then
		return
	end
	
	local speed = self:getMoveSpeed()
	if math.abs(speed - self._moveSpeed) > 0.01 then
		self:moveTo(self._dx, self._dy, speed)
	end
end

function Entity:isMoving()
	return self._motionDriver and self._motionDriver:isBusy()
end

function Entity:stop()
	if self:isMoving() then
		self._motionDriver:stop()
		self._motionDriver = nil
	end
	-- self:_insertRigid()
end

function Entity:_insertRigid()
	self:_eraseRigid()
	self._rigid = world:addBody(MOAIBox2DBody.DYNAMIC)
	local x, y = self:getWorldLoc()
	self._rigid:addCircle(x, y, self.bodySize)
	self._body:setParent(self._rigid)
end

function Entity:_eraseRigid()
	if self._rigid then
		self._rigid:destroy()
		self._rigid = nil
	end
end

function Entity:_checkAttackable()
	if self._target and self:isMoving() then
		if self:isInRange(self._target, self._fireRange) then
			self:stop()
			return true
		end
	end
end

function Entity:isAlive()
	return self.hp > 0
end

function Entity:isDead()
	return self.hp <= 0
end

function Entity:getAcceleration()
	return self._accel
end

function Entity:update()
	if self:isDead() then
		return
	end
	
	self._accel = math.min(self._scene.ticks - self._ticks, _ACCELERATION_MAX)
	self._ticks = self._ticks + self._accel
	
	self._attackSpeedFactor:update(self._ticks)
	self._moveSpeedFactor:update(self._ticks)
	self._recoverHpFactor:update(self._ticks)
	
	self:correctMoveSpeed()
	if self._lastRecoverTicks + _RECOVER_TICKS < self._ticks then
		self._lastRecoverTicks = self._ticks
		if self.hp < self.maxHp then
			self.hp = math.min(self.hp + self:getRecoverHp(), self.maxHp)
		end
	end
	
	if self._runState then
		self._runState(self, self._ticks)
	end
end

function Entity:_checkTarget(range)
	if self._target then
		if self._target:isDead() then
			self:log("Entity:_checkTarget target", self._target, "is dead")
			self._target = nil
		elseif not self:isInRange(self._target, range) then
			self:log("Entity:_checkTarget target", self._target, "out of range")
			self._target = nil
		end
	end
	
	if not self._target then
		self._target = self:searchTarget(range)
		self:logIf(self._target, "Entity:_checkTarget found target", self._target)
	end
	return self._target
end

function Entity:keepAlert()
	if self:_checkTarget(self.guardRange) then
		if self:isInRange(self._target, self.attackRange) then
			self:attack(self._target)
		else
			self:chase(self._target)
		end
	end
end

function Entity:stateIdle(ticks)
	self:keepAlert()
end

function Entity:stateMove(ticks)
	self:keepAlert()
end

function Entity:stateChase(ticks)
	if not self:_checkTarget(self.guardRange) then
		self:idle()
		return
	end
	
	if self:_checkAttackable() then
		self:attack(self._target)
		return
	end
	
	local x, y = self._target:getWorldLoc()
	if distance(self._tx, self._ty, x, y) > _LOCK_DIST then
		self:chase(self._target)
	end
end

function Entity:stateAttack(ticks)
	if not self:_checkTarget(self.attackRange) then
		self:idle()
		return
	end
	
	if ticks >= self._attackTicks then
		if self:isInRange(self._target, self.attackRange) then
			self:fire(self._target)
			self._attackTicks = self._attackTicks + self:getAttackSpeed()
		elseif self:isInRange(self,_target, self.guardRange) then
			self:chase(self._target)
		else
			self._target = nil
			self:idle()
		end
	end
end

function Entity:idle()
	self:log("Entity:idle", self)
	if self.movable then
		self:move()
	else
		self._runState = self.stateIdle
	end
end

function Entity:move()
	self:log("Entity:move", self)
	if not self.movable then
		return
	end

	local x, y = self:getWorldLoc()
	if self._force.id == Entity.FORCE_PLAYER then
		y = self._scene:getEnemyLoc()
	else
		y = self._scene:getPlayerLoc()
	end
	self:moveTo(x, y)
	self._runState = self.stateMove
end

function Entity:chase(target)
	self:log("Entity:chase", self)
	if not self.movable then
		self:attack(target)
		return
	end
	
	if self:isInRange(target, self._fireRange) then
		return
	end
	
	local sx, sy = self:getWorldLoc()
	local x, y = target:getWorldLoc()
	local mx = sx * self.attackRange * 2 / self._scene.WIDTH
	self._tx = x
	self._ty = y
	x = math.random(mx - self.bodySize, mx + self.bodySize)
	self:moveTo(x, y)
	self._fireRange = self.attackRange - math.random(self.bodySize * 2)
	self._runState = self.stateChase
end

function Entity:attack(target)
	self:log("Entity:attack", self)
	if target then
		self._target = target
	end
	self._attackTicks = self._ticks
	self._runState = self.stateAttack
end

function Entity:fire(target)
	self:stop()
	local targets = self:getAttackTargets()
	local x, y = self:getWorldLoc()
	local n = 0
	for k, v in pairs(targets) do
		if self.lockTarget then
			Bullet.fireLocked(self.bullet, self._scene, self:getAttackPower(), self:getEnemy(), x, y, v)
		else
			local tx, ty = v:getWorldLoc()
			Bullet.fireToward(self.bullet, self._scene, self:getAttackPower(), self:getEnemy(), x, y, tx, ty)
		end
		n = n + 1
		if n >= self.shots then
			break
		end
	end
end

function Entity:getAttackTargets()
	self._lastTargets[self._target] = self._target
	local n = 0
	local targets = {}
	for k, v in pairs(self._lastTargets) do
		if v:isAlive() then
			targets[v] = v
			n = n + 1
		end
	end
	for i = 1, self.shots - n do
		local e = self:searchNearestTarget(self.attackRange, targets)
		if not e then
			break
		end
		targets[e] = e
	end
	self._lastTargets = targets
	return targets
end

function Entity:getAttackPriority(target)
	return self.attackPriorities[target.kind] or 0
end

function Entity:searchTarget(range, exclusion)
	local units = self._scene:getUnits()
	local enemy = self:getEnemy()
	local dist = range ^ 2
	local priority = 0
	local target = nil
	for k, v in pairs(units) do
		if v ~= self and v:isAlive() and v:isForce(enemy) and (not exclusion or not exclusion[v]) then
			local d = self:distanceSq(v)
			local p = self:getAttackPriority(v)
			if p > priority or (p == priority and d < dist) then
				priority = p
				dist = d
				target = v
			end
		end
	end
	return target
end

function Entity:searchNearestTarget(range, exclusion)
	local units = self._scene:getUnits()
	local enemy = self:getEnemy()
	local dist = range ^ 2
	local target = nil
	for k, v in pairs(units) do
		if v ~= self and v:isAlive() and v:isForce(enemy) and (not exclusion or not exclusion[v]) then
			local d = self:distanceSq(v)
			if d < dist then
				dist = d
				target = v
			end
		end
	end
	return target
end

function Entity:getEnemy()
	if self._force.id == Entity.FORCE_PLAYER then
		return Entity.FORCE_ENEMY
	end
	return Entity.FORCE_PLAYER
end

function Entity:isForce(id)
	return id == Entity.FORCE_ALL or id == self._force.id
end

function Entity:isInRange(target, range)
	if not target then
		return false
	end
	if target:isDead() then
		return false
	end
	local x, y = target:getWorldLoc()
	return self:isPtInRange(x, y, range)
end

function Entity:isPtInRange(x, y, range)
	local sx, sy = self:getWorldLoc()
	return distanceSq(x, y, sx, sy) < (range ^ 2)
end

function Entity:distance(other)
	local x, y = self:getWorldLoc()
	local tx, ty = other:getWorldLoc()
	return distance(x, y, tx, ty)
end

function Entity:distanceSq(other)
	local x, y = self:getWorldLoc()
	local tx, ty = other:getWorldLoc()
	return distanceSq(x, y, tx, ty)
end

function Entity:distanceTo(tx, ty)
	local x, y = self:getWorldLoc()
	return distance(x, y, tx, ty)
end

function Entity:distanceSqTo(tx, ty)
	local x, y = self:getWorldLoc()
	return distanceSq(x, y, tx, ty)
end

function Entity:applyDamage(value, source)
	if self.hp > 0 then
		self.hp = self.hp - value
		if self.hp <= 0 then
			self:onExplode()
		end
	end
end

function Entity:onExplode()
	if self.explodeGfx then
		local explode = Sprite.new(self.explodeGfx)
		self._body:add(explode)
		self._body.onDestroy = function()
			self:destroy()
		end
	else
		self:destroy()
	end
end

return Entity