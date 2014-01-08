
local math2d = require "math2d"
local resource = require "resource"
local Scene = require "Scene"
local Sprite = require "Sprite"

local distance = math2d.distance
local distanceSq = math2d.distanceSq

local _defaultProps = {
	moveSpeed = 0.01,
	damage = 1,
	bombRange = 10,
	
	bodyGfx = "bg.png?scl=0.5",
	propellerGfx = nil,
	bombGfx = nil,
	bombSfx = nil,
	impactGfx = nil,
}

local _bulletLockDistance = 3

local Bullet = {}

Bullet._defaultProps = _defaultProps
Bullet.__index = Bullet

function Bullet.impact(self, target)
	target:applyDamage(self._props.damage)
end

function Bullet.bomb(self, target)
	if target then
		self:impact(target)
	end
	if self._props.bombRange <= 0 then
		return
	end
	local x, y = self:getWorldLoc()
	if self._props.bombGfx then
		local bomb = Sprite.new(self._props.bombGfx)
		bomb.update = Bullet.noop
		self._scene:addUnit(Scene.UNIT_BOMB, bomb)
	end
	local force = self._scene:getForceInRound(self._enemyForce, x, y, self._props.bombRange)
	for k, v in pairs(force) do
		if v ~= target then
			self:impact(v)
		end
	end
	self:destroy()
end

function Bullet.getWorldLoc(self)
	return self._body:getLoc()
end

function Bullet.setWorldLoc(self, x, y)
	return self._body:setLoc(x, y)
end

function Bullet.update(self)
	if self._bombed then
		return
	end
	local x, y = self:getWorldLoc()
	local tx, ty = self._target:getWorldLoc()
	local dist = distance(x, y, tx, ty)
	if dist < self._target.bodySize then
		self:bomb(self._target)
		return
	end
	if self._tx and self._ty and distance(self._tx, self._ty, tx, ty) < _bulletLockDistance then
		return
	end
	self._tx = tx
	self._ty = ty
	if self._easeDriver then
		self._easeDriver:stop()
	end
	self._easeDriver = self._body:seekLoc(tx, ty, self._props.moveSpeed * dist, MOAIEaseType.LINEAR)
end

function Bullet.noop(self)
end

function Bullet.destroy(self)
	self._scene:removeUnit(self)
	
	if self._body then
		self._body:destroy()
		self._body = nil
	end
	if self._thread then
		self._thread:stop()
		self._thread = nil
	end
end

function Bullet.setLayer(self, layer)
	self._body:setLayer(layer)
end

function Bullet.new(props)
	local self = {
		_props = props,
		_force = force,
	}
	self._body = Sprite.new(props.bodyGfx)
	if props.propellerGfx then
		local o = Sprite.new(props.propellerGfx)
		self._body:add(o)
	end
	setmetatable(self, Bullet)
	return self
end

function Bullet.fire(props, x, y, target, enemyForce)
	local self = Bullet.new(props)
	target._scene:addUnit(Scene.UNIT_BULLET, self)
	self:setWorldLoc(x, y)
	self._target = target
	self._enemyForce = enemyForce
	self:update()
	return self
end

function Bullet.fireTo(props, scene, x, y, tx, ty, enemyForce)
	local self = Bullet.new(props)
	self.update = Bullet.noop
	scene:addUnit(Scene.UNIT_BULLET, self)
	self:setWorldLoc(x, y)
	self._enemyForce = enemyForce
	self._thread = MOAIThread.new()
	self._thread:run(function()
		local dist = distance(x, y, tx, ty)
		MOAIThread.blockOnAction(self._body:seekLoc(tx, ty, props.moveSpeed * dist, MOAIEaseType.LINEAR))
		self:bomb()
	end)
	return self
end

return Bullet