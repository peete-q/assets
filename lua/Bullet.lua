
local math2d = require "math2d"
local resource = require "resource"
local node = require "node"
local Sprite = require "gfx.Sprite"

local distance = math2d.distance
local distanceSq = math2d.distanceSq
local normalize = math2d.normalize

local _defaultProps = {
	moveSpeed = 0.01,
	damage = 1,
	bombRange = 10,
	force = undefined,
	bombRun = undefined,
	bombCmd = undefined,
	
	bodyGfx = "alienAntiCapital01WeaponBasic.atlas.png?play=projectile&rot=90",
	propellerGfx = undefined,
	bombGfx = "alienBomberWeaponBasic.atlas.png?playOnce=impact&scl=5",
	bombSfx = undefined,
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
		local exclusion = {[target] = true}
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
		local exclusion = {[target] = true}
		local units = scene:getUnitsInRound(enemy, x, y, range, exclusion)
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
	
	local x, y = self:getLoc()
	if self.bombRange > 0 then
		local force = self.enemy or self._enemy
		local units = self._battlefield:getUnitsInRound(force, x, y, self.bombRange)
		for k, v in pairs(units) do
			if v ~= target then
				self:impact(v)
			end
		end
	end
	
	if self.bombRun then
		self.bombRun(self._battlefield, x, y, self._power, self._enemy, target, unpack(self.bombCmd))
	end
	
	if self.bombGfx then
		local bomb = Sprite.new(self.bombGfx)
		bomb.update = Bullet.noop
		bomb.onDestroy = function()
			self:destroy()
			bomb._battlefield:remove(bomb)
		end
		bomb:setLoc(x, y)
		bomb:setPriority(self._root:getPriority())
		self._battlefield:addFX(bomb)
	else
		self:destroy()
	end
end

function Bullet.getLoc(self)
	return self._root:getLoc()
end

function Bullet.setLoc(self, x, y)
	return self._root:setLoc(x, y)
end

function Bullet.setDir(self, rot)
	self._root:setRot(rot)
end

function Bullet.getDir(self)
	return self._root:getRot()
end

function Bullet.update(self)
	if self._bombed then
		return
	end
	if not self._target or self._target:isDead() then
		self:destroy()
		return
	end
	local x, y = self:getLoc()
	local tx, ty = self._target:getLoc()
	local dist = distance(x, y, tx, ty)
	if dist < self._target.bodySize then
		self:bomb(self._target)
		self._bombed = true
		return
	end
	if self._tx and self._ty and distance(self._tx, self._ty, tx, ty) < _LOCK_DIST then
		return
	end
	local x, y = self:getLoc()
	self:setDir(math2d.dir(x - tx, y - ty))
	self._tx = tx
	self._ty = ty
	if self._easeDriver then
		self._easeDriver:stop()
	end
	self._easeDriver = self._root:seekLoc(tx, ty, self.moveSpeed * dist, MOAIEaseType.LINEAR)
end

function Bullet.noop(self)
end

function Bullet.destroy(self)
	self._battlefield:remove(self)
	
	if self._root then
		self._root:destroy()
		self._root = nil
	end
	if self._moving then
		self._moving:stop()
		self._moving = nil
	end
end

function Bullet.setLayer(self, layer)
	self._root:setLayer(layer)
end

function Bullet:setPriority(value)
	self._root:setPriority(value)
end

function Bullet.new(props)
	local self = {
		_props = props,
	}
	setmetatable(self, Bullet)
	
	self._root = node.new(MOAIProp2D.new())
	local body = self._root:add(Sprite.new(self.bodyGfx))
	if self.propellerGfx then
		local o = Sprite.new(self.propellerGfx)
		o:setLoc(0,0)
		self._root:add(o)
	end
	return self
end

function Bullet.fireLocked(props, scene, power, enemy, x, y, target)
	local self = Bullet.new(props)
	scene:addFX(self)
	self:setLoc(x, y)
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
	self:setLoc(x, y)
	self._power = power
	self._enemy = enemy
	self._moving = MOAIThread.new()
	self._moving:run(function()
		local dist = distance(x, y, tx, ty)
		MOAIThread.blockOnAction(self._root:seekLoc(tx, ty, props.moveSpeed * dist, MOAIEaseType.LINEAR))
		self:bomb()
	end)
	return self
end

function Bullet.bombAt(props, scene, power, enemy, x, y, target)
	local self = Bullet.new(props)
	self.update = Bullet.noop
	scene:addFX(self)
	self:setLoc(x, y)
	self._power = power
	self._enemy = enemy
	self:bomb(target)
	return self
end

return Bullet