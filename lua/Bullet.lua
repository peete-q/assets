
local math2d = require "math2d"
local resource = require "resource"
local Sprite = require "Sprite"

local distance = math2d.distance
local distanceSq = math2d.distanceSq

local _defaultProps = {
	moveSpeed = 0.01,
	damage = 1,
	bombRange = 10,
	force = nil,
	bombRun = nil,
	bombCmd = nil,
	
	bodyGfx = "bg.png?scl=0.1",
	propellerGfx = nil,
	bombGfx = nil,
	bombSfx = nil,
}

local _LOCK_DIST = 5

local Bullet = {}

Bullet.__index = function(self, key)
	if self._props[key] ~= nil then
		return self._props[key]
	end
	if _defaultProps[key] ~= nil then
		return _defaultProps[key]
	end
	return Bullet[key]
end

Bullet.bombEvent = {
	chain = function(scene, x, y, power, enemy, target, props, range, count)
		local exclusion = {[target] = target}
		local u = scene:getRandomUnit(enemy, x, y, range, exclusion)
		if u then
			local b = Bullet.fireLocked(props, scene, power, enemy, x, y, u)
			if count > 0 then
				b.bombCmd = {props, range, count - 1}
				b.bombRun = Bullet.bombEvent.chain
			end
		end
	end,
	
	spread = function(scene, x, y, power, enemy, target, props, range, count)
		local exclusion = {[target] = target}
		local units = scene:getUnitsInRound(enemy, x, y, range, execlusion)
		for i = #units, 1, -1 do
			if math.random(i) <= count then
				Bullet.fireLocked(props, scene, power, enemy, x, y, units[i])
				count = count - 1
				if count <= 0 then
					break
				end
			end
		end
	end,
}

function Bullet.impact(self, target)
	target:applyDamage(self.damage * self._power)
end

function Bullet.bomb(self, target)
	if target then
		self:impact(target)
	end
	
	local x, y = self:getWorldLoc()
	if self.bombRange > 0 then
		local force = self.enemy or self._enemy
		local units = self._scene:getUnitsInRound(force, x, y, self.bombRange)
		for k, v in pairs(units) do
			if v ~= target then
				self:impact(v)
			end
		end
	end
	
	if self.bombRun then
		self.bombRun(self._scene, x, y, self._power, self._enemy, target, unpack(self.bombCmd))
	end
	
	if self.bombGfx then
		local bomb = Sprite.new(self.bombGfx)
		bomb.update = Bullet.noop
		bomb.onDestroy = function()
			self:destroy()
			bomb._scene:remove(bomb)
		end
		bomb:setLoc(x, y)
		bomb:setPriority(self._body:getPriority())
		self._scene:addFX(bomb)
	else
		self:destroy()
	end
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
	if not self._target or self._target:isDead() then
		self:destroy()
		return
	end
	local x, y = self:getWorldLoc()
	local tx, ty = self._target:getWorldLoc()
	local dist = distance(x, y, tx, ty)
	if dist < self._target.bodySize then
		self:bomb(self._target)
		return
	end
	if self._tx and self._ty and distance(self._tx, self._ty, tx, ty) < _LOCK_DIST then
		return
	end
	self._tx = tx
	self._ty = ty
	if self._easeDriver then
		self._easeDriver:stop()
	end
	self._easeDriver = self._body:seekLoc(tx, ty, self.moveSpeed * dist, MOAIEaseType.LINEAR)
end

function Bullet.noop(self)
end

function Bullet.destroy(self)
	self._scene:remove(self)
	
	if self._body then
		self._body:destroy()
		self._body = nil
	end
	if self._moving then
		self._moving:stop()
		self._moving = nil
	end
end

function Bullet.setLayer(self, layer)
	self._body:setLayer(layer)
end

function Bullet:setPriority(value)
	self._body:setPriority(value)
end

function Bullet.new(props)
	local self = {
		_props = props,
	}
	setmetatable(self, Bullet)
	
	self._body = Sprite.new(self.bodyGfx)
	if props.propellerGfx then
		local o = Sprite.new(self.propellerGfx)
		self._body:add(o)
	end
	return self
end

function Bullet.fireLocked(props, scene, power, enemy, x, y, target)
	local self = Bullet.new(props)
	scene:addFX(self)
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
	scene:addFX(self)
	self:setWorldLoc(x, y)
	self._power = power
	self._enemy = enemy
	self._moving = MOAIThread.new()
	self._moving:run(function()
		local dist = distance(x, y, tx, ty)
		MOAIThread.blockOnAction(self._body:seekLoc(tx, ty, props.moveSpeed * dist, MOAIEaseType.LINEAR))
		self:bomb()
	end)
	return self
end

function Bullet.bombAt(props, scene, power, enemy, x, y, target)
	local self = Bullet.new(props)
	self.update = Bullet.noop
	scene:addFX(self)
	self:setWorldLoc(x, y)
	self._power = power
	self._enemy = enemy
	self:bomb(target)
	return self
end

return Bullet