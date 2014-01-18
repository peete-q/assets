
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
	force = nil,
	
	bodyGfx = "bg.png?scl=0.5",
	propellerGfx = nil,
	bombGfx = nil,
	bombSfx = nil,
	impactGfx = nil,
}

local _lockDistance = 5

local Bullet = {}

Bullet._defaultProps = _defaultProps
Bullet.__index = Bullet

function Bullet.impact(self, target)
	target:applyDamage(self._props.damage * self._power)
end

function Bullet.bomb(self, target)
	if target then
		self:impact(target)
	end
	
	if self._props.bombRange > 0 then
		local x, y = self:getWorldLoc()
		if self._props.bombGfx then
			local bomb = Sprite.new(self._props.bombGfx)
			bomb.update = Bullet.noop
			bomb.onDestroy = function(self)
				self._scene:remove(self)
			end
			self._scene:addProjectile(bomb)
		end
		local force = self._props.enemy or self._enemy
		local units = self._scene:getUnitsInRound(force, x, y, self._props.bombRange)
		for k, v in pairs(units) do
			if v ~= target then
				self:impact(v)
			end
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
	if self._tx and self._ty and distance(self._tx, self._ty, tx, ty) < _lockDistance then
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
	self._scene:remove(self)
	
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
	}
	self._body = Sprite.new(props.bodyGfx)
	if props.propellerGfx then
		local o = Sprite.new(props.propellerGfx)
		self._body:add(o)
	end
	setmetatable(self, Bullet)
	return self
end

function Bullet.fireLocked(props, scene, power, enemy, x, y, target)
	local self = Bullet.new(props)
	scene:addProjectile(self)
	self:setWorldLoc(x, y)
	self._power = power
	self._enemy = enemy
	self._target = target
	self:update()
	return self
end

function Bullet.fireToward(props, scene, power, enemy, x, y, tx, ty)
	local self = Bullet.new(props)
	self.update = Bullet.noop
	scene:addProjectile(self)
	self:setWorldLoc(x, y)
	self._power = power
	self._enemy = enemy
	self._thread = MOAIThread.new()
	self._thread:run(function()
		local dist = distance(x, y, tx, ty)
		MOAIThread.blockOnAction(self._body:seekLoc(tx, ty, props.moveSpeed * dist, MOAIEaseType.LINEAR))
		self:bomb()
	end)
	return self
end

function Bullet.bombAt(props, scene, power, enemy, x, y, target)
	local self = Bullet.new(props)
	self.update = Bullet.noop
	scene:addProjectile(self)
	self:setWorldLoc(x, y)
	self._power = power
	self._enemy = enemy
	self:bomb(target)
	return self
end

return Bullet