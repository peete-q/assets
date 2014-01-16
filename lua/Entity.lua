
local math2d = require "math2d"
local resource = require "resource"
local Scene = require "Scene"
local Sprite = require "Sprite"
local Bullet = require "Bullet"

local distance = math2d.distance
local distanceSq = math2d.distanceSq

local Entity = {
	FORCE_PLAYER = 1,
	FORCE_ENEMY = 2,
	FORCE_ALL = 3,
}

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
	specialPower = nil,
	
	bodyGfx = nil,
	propellerGfx = nil,
	muzzleGfx = nil,
	fireSfx = nil,
	explodeGfx = nil,
	explodeSfx = nil,
	bullet = Bullet._defaultProps,
}

local _lockDistance = 10
local _recoverTicks = 10

Entity._defaultProps = _defaultProps

Entity.__index = function(self, key)
	if self._props[key] ~= nil then
		return self._props[key]
	end
	if _defaultProps[key] ~= nil then
		return _defaultProps[key]
	end
	return Entity[key]
end

Entity.__newindex = function(self, key, value)
	if self._props[key] ~= nil or _defaultProps[key] ~= nil then
		self._props[key] = value
		return
	end
	rawset(self, key, value)
end

function Entity.new(props, force)
	local self = {
		_force = force,
		_props = props or {},
		_lastAttackTicks = 0,
		_attackPriorities = {},
		_fireRange = 0,
		_lastTargets = {},
		_scene = nil,
		_motionDriver = nil,
		_target = nil,
		_rigid = nil,
		_attackSpeedFactor = 1,
		_moveSpeedFactor = 1,
		_recoverHpFactor = 1,
		_lastRecoverTicks = 0,
	}
	
	self._body = Sprite.new(props.bodyGfx)
	if props.propellerGfx then
		self._propeller = Sprite.new(props.propellerGfx)
		self._body:add(self._propeller)
	end
	if props.muzzleGfx then
		self._muzzle = Sprite.new(props.muzzleGfx)
	end
	setmetatable(self, Entity)
	return self
end

function Entity:destroy()
	self._scene:remove(self)
	
	if self._body then
		self._body:destroy()
		self._body = nil
	end
	
	if self._motionDriver then
		self._motionDriver:destroy()
		self._motionDriver = nil
	end
	
	if self._rigid then
		self._rigid:destroy()
		self._rigid = nil
	end
end

function Entity:setAttackSpeedFactor(value)
	self._attackSpeedFactor = value
end

function Entity:setMoveSpeedFactor(value)
	self._moveSpeedFactor = value
end

function Entity:getAttackSpeed()
	return self.attackSpeed * (self._attackSpeedFactor + (self._force.attackSpeedFactor or 0))
end

function Entity:getMoveSpeed()
	return self.moveSpeed * (self._moveSpeedFactor + (self._force.moveSpeedFactor or 0))
end

function Entity:getRecoverHp()
	return self.recoverHp * (self._recoverHpFactor + (self._force.recoverHpFactor or 0))
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

function Entity:moveTo(x, y)
	if not self.movable then
		return
	end
	self:_eraseRigid()
	self:stop()
	local sx, sy = self:getWorldLoc()
	local dist = distance(sx, sy, x, y)
	self._motionDriver = self._body:seekLoc(x, y, self:getMoveSpeed() * dist, MOAIEaseType.LINEAR)
	print("Entity:moveTo", x, y)
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

function Entity:_checkAttack()
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

function Entity:isInvincible()
	return self._invincible
end

function Entity:update(ticks)
	if self._lastRecoverTicks + _recoverTicks < ticks then
		self._lastRecoverTicks = ticks
		if self.hp < self.maxHp then
			self.hp = math.min(self.hp + self:getRecoverHp(), self.maxHp)
		end
	end
	if self._state then
		self._state(self, ticks)
	end
end

function Entity:_checkTarget()
	if self._target and (self._target:isDead() or not self:isInRange(self._target, self.guardRange)) then
		self._target = nil
	end
	
	return self._target
end

function Entity:stateMove(ticks)
	if not self._target then
		self._target = self:searchTarget()
		if self._target then
			if self:isInRange(self._target, self.attackRange) then
				self:attack(self._target)
			else
				self:chase(self._target)
			end
		end
	end
end

function Entity:stateChase(ticks)
	if not self:_checkTarget() then
		self:move()
		return
	end
	
	if self:_checkAttack() then
		self:attack(self._target)
		return
	end
	
	local x, y = self._target:getWorldLoc()
	if distance(self._tx, self._ty, x, y) > _lockDistance then
		self:chase(self._target)
	end
end

function Entity:stateAttack(ticks)
	if not self:_checkTarget() then
		self:move()
		return
	end
	
	if self._lastAttackTicks + self:getAttackSpeed() < ticks then
		if self:isInRange(self._target) then
			self:fire(self._target)
			self._lastAttackTicks = ticks
		elseif self:isInRange(self,_target, self.guardRange) then
			self:chase(self._target)
		else
			self._target = nil
			self:move()
		end
	end
end

function Entity:move()
	print("Entity:move")
	local x, y = self:getWorldLoc()
	if self._force.id == Entity.FORCE_PLAYER then
		y = self._scene:getPlayerLoc()
	else
		y = self._scene:getEnemyLoc()
	end
	self:moveTo(x, y)
	self._state = self.stateMove
end

function Entity:chase(target)
	print("Entity:chase", self, target)
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
	self._state = self.stateChase
end

function Entity:attack(target)
	print("Entity:attack")
	if target then
		self._target = target
	end
	self._state = self.stateAttack
end

function Entity:fire(target)
	local targets = self:getAttackTargets()
	local x, y = self:getWorldLoc()
	local n = 0
	for k, v in pairs(targets) do
		if self.lockTarget then
			-- Bullet.fireLocked(self.bullet, x, y, v, self:getEnemy())
		else
			local tx, ty = v:getWorldLoc()
			Bullet.fireToward(self.bullet, self._scene, x, y, tx, ty, self:getEnemy())
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
		targets[e] = e
	end
	self._lastTargets = targets
	return targets
end

function Entity:attackPriority(target)
	return self._attackPriorities[target.kind] or 0
end

function Entity:searchTarget(range, exclusion)
	range = range or self.guardRange
	local units = self._scene:getUnits()
	local enemy = self:getEnemy()
	local dist = range ^ 2
	local priority = 0
	local target = nil
	for k, v in pairs(units) do
		if v ~= self and v:isAlive() and v:isForce(enemy) and (not exclusion or not exclusion[v]) then
			local d = self:distanceSq(v)
			local p = self:attackPriority(v)
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
	range = range or self.guardRange
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
	range = range or self.attackRange
	local x, y = target:getWorldLoc()
	return self:isPtInRange(x, y, range)
end

function Entity:isPtInRange(x, y, range)
	range = range or self.attackRange
	local sx, sy = self:getWorldLoc()
	return distanceSq(x, y, sx, sy) < (range ^ 2)
end

function Entity:distance(other)
	local x, y = other:getWorldLoc()
	local sx, sy = self:getWorldLoc()
	return distance(x, y, sx, sy)
end

function Entity:distanceSq(other)
	local x, y = other:getWorldLoc()
	local sx, sy = self:getWorldLoc()
	return distanceSq(x, y, sx, sy)
end

function Entity:applyDamage(amount, source)
	print("Entity:applyDamage")
end

return Entity