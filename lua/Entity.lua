
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
	bodySize = 10,
	moveSpeed = 10,
	attackPower = 1,
	attackSpeed = 10,
	attackRange = 100,
	guardRange = 160,
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
		_stopRange = 0,
		_lastTargets = {},
		_scene = nil,
		_motionDriver = nil,
		_target = nil,
		_rigid = nil,
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
	self:_cancelRigid()
	self:stop()
	self._motionDriver = self._body:seekLoc(x, y, self.moveSpeed, MOAIEaseType.LINEAR)
end

function Entity:isMoving()
	return self._motionDriver and self._motionDriver:isBusy()
end

function Entity:stop()
	if self:isMoving() then
		self._motionDriver:stop()
		self._motionDriver = nil
	end
end

function Entity:_doRigid()
	assert(not self._rigid)
	self._rigid = world:addBody(MOAIBox2DBody.DYNAMIC)
	local x, y = self:getWorldLoc()
	self._rigid:addCircle(x, y, self.bodySize)
	self._body:setParent(self._rigid)
end

function Entity:_cancelRigid()
	if self._rigid then
		self._rigid:destroy()
		self._rigid = nil
	end
end

function Entity:_checkStop()
	if self._target and self:isMoving() then
		if self:isInRange(self._target, self.attackRange - self._stopRange) then
			self:stop()
		end
	end
	
	if not self._rigid and not self:isMoving() then
		-- self:_doRigid()
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
	self:_checkStop()
	
	if self._target and (self._target:isDead() or not self:isInRange(self._target, self.guardRange)) then
		self._target = nil
	end
	
	if not self._target then
		self._target = self:searchTarget()
		if self._target then
			self:chase(self._target)
		end
	end
	
	if self._target and self._lastAttackTicks + self.attackSpeed < ticks then
		if self:isInRange(self._target) then
			self:attack(self._target)
			self._lastAttackTicks = ticks
		end
	end
end

function Entity:chase(target)
	print("Entity:chase", self, target)
	if self:isInRange(target, self.attackRange - self._stopRange) then
		return
	end
	local x, y = target:getWorldLoc()
	local sx, sy = self:getWorldLoc()
	local mx = sx * self.attackRange * 2 / self._scene.WIDTH
	x = math.random(mx - self.bodySize, mx + self.bodySize)
	self:moveTo(x, y)
	self._stopRange = math.random(self.bodySize * 2)
end

function Entity:moveOn()
	local x, y
	if self._force == Entity.FORCE_PLAYER then
		x, y = self._scene:getPlayerLoc()
	else
		x, y = self._scene:getEnemyLoc()
	end
end

function Entity:attack(target)
	local targets = self:getAttackTargets()
	local x, y = self:getWorldLoc()
	local n = 0
	for k, v in pairs(targets) do
		if self.lockTarget then
			Bullet.fire(self.bullet, x, y, v, self:getEnemy())
		else
			local tx, ty = v:getWorldLoc()
			Bullet.fireTo(self.bullet, self._scene, x, y, tx, ty, self:getEnemy())
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
	if self._force == Entity.FORCE_PLAYER then
		return Entity.FORCE_ENEMY
	end
	return Entity.FORCE_PLAYER
end

function Entity:isForce(nb)
	return nb == Entity.FORCE_ALL or nb == self._force
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