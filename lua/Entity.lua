
local math2d = require "math2d"
local resource = require "resource"
local Scene = require "Scene"
local Sprite = require "Sprite"

local distance = math2d.distance
local distanceSq = math2d.distanceSq

local none = false

local Entity = {
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
	bulletSpeed = 10,
	impactRange = 1,
	kind = "normal",
	movable = true,
	specialPower = none,
	
	bodyGfx = none,
	propellerGfx = none,
	muzzleGfx = none,
	fireSfx = none,
	impactGfx = none,
	impactSfx = none,
	explodeGfx = none,
	explodeSfx = none,
	bulletGfx = none,
	bulletPropellerGfx = none,
}

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
	error(string.format("[error] write undefined entity property '%s'", key))
end

function Entity.new(props, layer)
	local self = {
		_force = force,
		_children = {},
		_props = props or {},
		_lastAttackTicks = 0,
		_attackPriorities = {},
		_motionDriver = none,
		_target = none,
		_rigid = none,
		_scene = none,
		_stopRange = 0,
	}
	
	self._body = Sprite.new(props.bodyGfx, layer)
	if props.propellerGfx then
		self._propeller = Sprite.new(props.propellerGfx, layer)
	end
	if props.muzzleGfx then
		self._muzzle = Sprite.new(props.muzzleGfx, layer)
	end
	setmetatable(self, Entity)
	return self
end

function Entity:destroy()
	for k, v in pairs(self._children) do
		v:destroy()
	end
	
	if self._motionDriver then
		self._motionDriver:destroy()
	end
	
	if self._rigid then
		self._rigid:destroy()
		self._rigid = none
	end
end

function Entity:setLayer(layer)
	self._body:setLayer(layer)
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
		self._motionDriver = none
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
		self._rigid = none
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
	
	if self._target and self._target:isDead() then
		self._target = none
	end
	
	if not self._target then
		self._target = self:_searchAttackTarget()
		if self._target then
			self:chase(self._target)
		end
	end
	
	if self._target and self._lastAttackTicks + self.attackSpeed < ticks then
		if self:isInRange(self._target) then
			self:attack(self._target)
		end
	end
end

function Entity:chase(target)
	local x, y = target:getWorldLoc()
	local sx, sy = self:getWorldLoc()
	local mx = sx * self.attackRange * 2 / self._scene.WIDTH
	x = math.random(mx - self.bodySize, mx + self.bodySize)
	self:moveTo(x, y)
	self._stopRange = math.random(self.bodySize * 2)
end

function Entity:attack(target)
	target = target or self._target
	target:applyDamage(self.attackPower)
end

function Entity:attackPriority(target)
	return self._attackPriorities[target.kind] or 0
end

function Entity:_searchAttackTarget()
	local force = self:getHostileForce()
	local dist = self.guardRange ^ 2
	local priority = 0
	local target = none
	for k, v in pairs(force) do
		local d = self:distanceSq(v)
		local p = self:attackPriority(v)
		if p > priority or (p == priority and d < dist) then
			priority = p
			dist = d
			target = v
		end
	end
	return target
end

function Entity:getMyForce()
	return self._scene:getForce(self._force)
end

function Entity:getHostileForce()
	if self._force == Scene.FORCE_SELF then
		return self._scene:getForce(Scene.FORCE_ENEMY)
	end
	return self._scene:getForce(Scene.FORCE_SELF)
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
end

return Entity