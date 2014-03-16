
local math2d = require "math2d"
local resource = require "resource"
local node = require "node"
local Sprite = require "gfx.Sprite"
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

local Unit = {
	FORCE_PLAYER = 1,
	FORCE_ENEMY = 2,
	FORCE_ALL = 3,
}

local _LOCK_DIST = 10
local _RECOVER_TICKS = 10
local _ACCELERATION_MAX = 5

local _defaultProps = {
	hp = 100,
	maxHp = 100,
	recoverHp = 1,
	bodySize = 10,
	moveSpeed = 0.01,
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

local ForceList = {}
ForceList.__index = ForceList

function ForceList:addForce(id)
	local o = {
		id = id,
		attackSpeedFactor = Factor.new(),
		moveSpeedFactor = Factor.new(),
		recoverHpFactor = Factor.new(),
		attackPowerFactor = Factor.new(),
	}
	self[id] = o
	return o
end

function ForceList:update(ticks)
	for k, v in pairs(self._forces) do
		v.attackSpeedFactor:update(ticks)
		v.moveSpeedFactor:update(ticks)
		v.recoverHpFactor:update(ticks)
		v.attackPowerFactor:update(ticks)
	end
end

function Unit.newForceList()
	local o = {}
	setmetatable(o, ForceList)
	o:addForce(Unit.FORCE_PLAYER)
	o:addForce(Unit.FORCE_ENEMY)
	o:addForce(Unit.FORCE_ALL)
	return o
end

Unit.__index = function(self, key)
	if self._db[key] ~= nil then
		return self._db[key]
	end
	if self._props[key] ~= nil then
		return self._props[key]
	end
	if _defaultProps[key] ~= nil then
		return _defaultProps[key]
	end
	return Unit[key]
end

Unit.__newindex = function(self, key, value)
	if _defaultProps[key] ~= nil then
		self._db[key] = value
	else
		rawset(self, key, value)
	end
end

function Unit.new(props, force)
	local self = node.new {
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
		_writelog = nil,
		_battlefield = nil,
		_motionDriver = nil,
		_target = nil,
		_rigid = nil,
	}
	setmetatable(self, Unit)
	
	self._setLayer = Unit._setLayer
	self._runState = self.stateIdle
	self._fireRange = self.attackRange
	self._force.enemy = self:getEnemy()
	
	self._root = self:add(node.new())
	local body = self._root:add(Sprite.new(self.bodyGfx))
	if props.propellerGfx then
		self._propeller = Sprite.new(props.propellerGfx)
		self._root:add(self._propeller)
	end
	if props.muzzleGfx then
		self._muzzle = Sprite.new(props.muzzleGfx)
	end
	self._drifting = MOAIThread.new()
	self._drifting:run(function()
		while true do
			local n = math.random(95, 98) / 100
			MOAIThread.blockOnAction(self._root:seekScl(n, n, n * 2, MOAIEaseType.SOFT_SMOOTH))
			MOAIThread.blockOnAction(self._root:seekScl(1, 1, n * 2, MOAIEaseType.SOFT_SMOOTH))
		end
	end)
	return self
end

function Unit:destroy()
	self._battlefield:remove(self)
	
	if self._root then
		self._root:destroy()
		self._root = nil
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

function Unit:log(...)
	if self._writelog then
		print(concat("[", self, "]"), ...)
	end
end

function Unit:logIf(cond, ...)
	if self._writelog and cond then
		print(concat("[", self, "]"), ...)
	end
end

function Unit:loadDB(db)
	self._db = db
end

function Unit:setPriority(value)
	self._root:setPriority(value)
end

function Unit:getPriority()
	if self._root then
		self._root:getPriority()
	end
end

function Unit:addAttackSpeedFactor(value, duration)
	self._attackSpeedFactor:add(value, self._battlefield.ticks + duration)
end

function Unit:addMoveSpeedFactor(value, duration)
	self._moveSpeedFactor:add(value, self._battlefield.ticks + duration)
end

function Unit:addRecoverHpFactor(value, duration)
	self._recoverHpFactor:add(value, self._battlefield.ticks + duration)
end

function Unit:addAttackPowerFactor(value, duration)
	self._attackPowerFactor:add(value, self._battlefield.ticks + duration)
end

function Unit:getAttackSpeed()
	local speed = self.attackSpeed / (1 + self._attackSpeedFactor:calc() + self._force.attackSpeedFactor:calc())
	return math.floor(speed)
end

function Unit:getMoveSpeed()
	local acc = self:getAcceleration()
	local speed = self.moveSpeed / (1 + self._moveSpeedFactor:calc() + self._force.moveSpeedFactor:calc())
	return speed / acc
end

function Unit:getRecoverHp()
	return self.recoverHp * (1 + self._recoverHpFactor:calc() + self._force.recoverHpFactor:calc())
end

function Unit:getAttackPower()
	return self.attackPower + self._attackPowerFactor:calc() + self._force.attackPowerFactor:calc()
end

function Unit:_setLayer(layer)
	if layer then
		layer:insertProp(self._root)
	else
		self._layer:removeProp(self._root)
	end
	self._layer = layer
end

function Unit:setParent(parent)
	self._root:setParent(parent)
end

function Unit:setScissorRect(rect)
	self._root:setScissorRect(rect)
end

function Unit:add(fx)
	self._root:add(fx)
end

function Unit:remove(fx)
	self._root:remove(fx)
end

function Unit:setLoc(x, y)
	self._root:setLoc(x, y)
end

function Unit:getLoc()
	return self._root:getLoc()
end

function Unit.setDir(self, rot)
	self._root:setRot(rot)
end

function Unit.getDir(self)
	return self._root:getRot()
end

function Unit:moveTo(x, y, speed)
	self:stop()
	local sx, sy = self:getLoc()
	local dist = distance(sx, sy, x, y)
	local dir = math2d.dir(sx - x, sy - y)
	self:setDir(dir)
	self._moveSpeed = speed or self:getMoveSpeed()
	self._motionDriver = self._root:seekLoc(x, y, self._moveSpeed * dist, MOAIEaseType.LINEAR)
	self._dx = x
	self._dy = y
	self:_eraseRigid()
	self:log("Unit:moveTo", sx, sy, x, y, self._moveSpeed, dist)
end

function Unit:whenArrive(cb)
	self._motionDriver:setListener(MOAIAction.EVENT_STOP, cb)
end

function Unit:correctMoveSpeed()
	if not self:isMoving() then
		return
	end
	
	local speed = self:getMoveSpeed()
	if math.abs(speed - self._moveSpeed) > 0.01 then
		self:moveTo(self._dx, self._dy, speed)
	end
end

function Unit:isMoving()
	return self._motionDriver and self._motionDriver:isBusy()
end

function Unit:stop()
	if self:isMoving() then
		self._motionDriver:stop()
		self._motionDriver = nil
	end
	-- self:_insertRigid()
end

function Unit:_insertRigid()
	self:_eraseRigid()
	self._rigid = world:addBody(MOAIBox2DBody.DYNAMIC)
	local x, y = self:getLoc()
	self._rigid:addCircle(x, y, self.bodySize)
	self._root:setParent(self._rigid)
end

function Unit:_eraseRigid()
	if self._rigid then
		self._rigid:destroy()
		self._rigid = nil
	end
end

function Unit:_checkAttackable()
	if self._target and self:isMoving() then
		if self:isInRange(self._target, self._fireRange) then
			self:stop()
			return true
		end
	end
end

function Unit:isAlive()
	return self.hp > 0
end

function Unit:isDead()
	return self.hp <= 0
end

function Unit:getAcceleration()
	return self._accel or 1
end

function Unit:update()
	if self:isDead() then
		return
	end
	
	self._accel = math.min(self._battlefield.ticks - self._ticks, _ACCELERATION_MAX)
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

function Unit:_checkTarget(range)
	if self._target then
		if self._target:isDead() then
			self:log("Unit:_checkTarget target", self._target, "is dead")
			self._target = nil
		elseif not self:isInRange(self._target, range) then
			self:log("Unit:_checkTarget target", self._target, "out of range")
			self._target = nil
		end
	end
	
	if not self._target then
		self._target = self:searchTarget(range)
		self:logIf(self._target, "Unit:_checkTarget found target", self._target)
	end
	return self._target
end

function Unit:keepAlert()
	if self:_checkTarget(self.guardRange) then
		if self:isInRange(self._target, self.attackRange) then
			self:attack(self._target)
		else
			self:chase(self._target)
		end
	end
end

function Unit:stateIdle(ticks)
	self:keepAlert()
end

function Unit:stateMove(ticks)
	self:keepAlert()
end

function Unit:stateChase(ticks)
	if not self:_checkTarget(self.guardRange) then
		self:idle()
		return
	end
	
	if self:_checkAttackable() then
		self:attack(self._target)
		return
	end
	
	local x, y = self._target:getLoc()
	if distance(self._tx, self._ty, x, y) > _LOCK_DIST then
		self:chase(self._target)
	end
end

function Unit:stateAttack(ticks)
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

function Unit:idle()
	self:log("Unit:idle", self)
	if self.movable then
		self:move()
	else
		self._runState = self.stateIdle
	end
end

function Unit:move()
	self:log("Unit:move", self)
	if not self.movable then
		return
	end

	local x, y = self:getLoc()
	if self._force.id == Unit.FORCE_PLAYER then
		local _x, _y = self._battlefield:getEnemyLoc()
		y = _y
	else
		local _x, _y = self._battlefield:getPlayerLoc()
		y = _y
	end
	self:moveTo(x, y)
	self._runState = self.stateMove
end

function Unit:chase(target)
	self:log("Unit:chase", self)
	if not self.movable then
		self:attack(target)
		return
	end
	
	if self:isInRange(target, self._fireRange) then
		return
	end
	
	local sx, sy = self:getLoc()
	local x, y = target:getLoc()
	local mx = sx * self.attackRange * 2 / device.width
	self._tx = x
	self._ty = y
	x = math.random(mx - self.bodySize, mx + self.bodySize)
	self:moveTo(x, y)
	self._fireRange = self.attackRange - math.random(self.bodySize * 2)
	self._runState = self.stateChase
end

function Unit:attack(target)
	self:log("Unit:attack", self)
	if target then
		self._target = target
	end
	self._attackTicks = self._ticks
	self._runState = self.stateAttack
end

function Unit:fire(target)
	self:log("Unit:fire", self, target)
	target._attacker = self
	self:stop()
	local targets = self:getAttackTargets()
	local x, y = self:getLoc()
	local tx, ty = v:getLoc()
	local dir = math2d.dir(x - tx, y - ty)
	self:setDir(dir)
	local n = 0
	for k, v in pairs(targets) do
		if self.lockTarget then
			Bullet.fireLocked(self.bullet, self._battlefield, self:getAttackPower(), self:getEnemy(), x, y, v)
		else
			Bullet.fireToward(self.bullet, self._battlefield, self:getAttackPower(), self:getEnemy(), x, y, tx, ty)
		end
		n = n + 1
		if n >= self.shots then
			break
		end
	end
end

function Unit:getAttackTargets()
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

function Unit:getAttackPriority(target)
	return self.attackPriorities[target.kind] or 0
end

function Unit:searchTarget(range, exclusion)
	local units = self._battlefield:getUnits()
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

function Unit:searchNearestTarget(range, exclusion)
	local units = self._battlefield:getUnits()
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

function Unit:getEnemy()
	if self._force.id == Unit.FORCE_PLAYER then
		return Unit.FORCE_ENEMY
	end
	return Unit.FORCE_PLAYER
end

function Unit:isForce(id)
	return id == Unit.FORCE_ALL or id == self._force.id
end

function Unit:isInRange(target, range)
	if not target then
		return false
	end
	if target:isDead() then
		return false
	end
	local x, y = target:getLoc()
	return self:isPtInRange(x, y, range)
end

function Unit:isPtInRange(x, y, range)
	local sx, sy = self:getLoc()
	return distanceSq(x, y, sx, sy) < (range ^ 2)
end

function Unit:distance(other)
	local x, y = self:getLoc()
	local tx, ty = other:getLoc()
	return distance(x, y, tx, ty)
end

function Unit:distanceSq(other)
	local x, y = self:getLoc()
	local tx, ty = other:getLoc()
	return distanceSq(x, y, tx, ty)
end

function Unit:distanceTo(tx, ty)
	local x, y = self:getLoc()
	return distance(x, y, tx, ty)
end

function Unit:distanceSqTo(tx, ty)
	local x, y = self:getLoc()
	return distanceSq(x, y, tx, ty)
end

function Unit:applyDamage(value, source)
	if self.hp > 0 then
		self.hp = self.hp - value
		if self.onDamage then
			self.onDamage(value, self.hp)
		end
		if self.hp <= 0 then
			self:onExplode()
		end
	end
end

function Unit:onExplode()
	if self.explodeGfx then
		local explode = Sprite.new(self.explodeGfx)
		self._root:add(explode)
		self._root.onDestroy = function()
			self:destroy()
		end
	else
		self:destroy()
	end
end

return Unit