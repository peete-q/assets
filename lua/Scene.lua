
local Entity = require "Entity"
local Factor = require "Factor"

local Scene = {
	SPACE = 1,
	SKY = 2,
}

local LANE_SIZE = 20

Scene.__index = Scene

function Scene.new(w, h, spaceLayer, skyLayer, seed)
	local self = {
		WIDTH = w,
		HEIGHT = h,
		
		_units = {},
		_projectiles = {},
		_playerX = w / 2,
		_playerY = h / 2,
		_enemyX = w / 2,
		_enemyY = -h / 2,
		_spaceLayer = spaceLayer,
		_skyLayer = skyLayer,
		_forces = {},
		_player = {},
		
		ticks = 0,
	}
	
	setmetatable(self, Scene)
	return self
end

function Scene:destroy()
end

function Scene:newForce(id)
	local force = {
		id = id,
		attackSpeedFactor = Factor.new(),
		moveSpeedFactor = Factor.new(),
		recoverHpFactor = Factor.new(),
		attackPowerFactor = Factor.new(),
	}
	self._forces[id] = force
	return force
end

function Scene:getForce(id)
	return self._forces[id]
end

function Scene:newUnit(props, force, x, y)
	local e = Entity.new(props, self._forces[force])
	e._scene = self
	e:setLayer(self._spaceLayer)
	e:setWorldLoc(x, y)
	self._units[e] = e
	return e
end

function Scene:addProjectile(e)
	e._scene = self
	e:setLayer(self._spaceLayer)
	self._projectiles[e] = e
	return e
end

function Scene:remove(e)
	e:setLayer(nil)
	self._units[e] = nil
	self._projectiles[e] = nil
end

function Scene:spawnUnit(props, force, y)
	local n = (self.WIDTH / 2) / LANE_SIZE
	local x = math.random(-n, n) * LANE_SIZE
	local u = self:newUnit(props, force, x, y)
	u:move()
end

local playerInfo = {
	[1] = {run = nil, cmd = nil, spend = 1, cd = 10, nb = 3}
}

function Scene:loadPlayer(playerInfo)
	self._player = playerInfo
	for k, v in pairs(self._player) do
		v._nb = v.nb
		v._ticks = 0
	end
end

local aiInfo = {
	loopBegin = 30,
	[1] = {props = aiProps, nb = 2},
	[30] = {props = aiProps, nb = 3},
	[60] = {props = aiProps, nb = 5},
}

function Scene:loadAI(aiInfo)
	self._ai = aiInfo
end

function Scene:loadPlayerAI()
end

function Scene:updateAI(ticks)
	local index = ticks
	if index > self._ai.loopBegin then
		index = math.fmod(index, self._ai.loopBegin) + self._ai.loopBegin
	end
	local ai = self._ai[index]
	if ai then
		for i = 1, ai.nb do
			self:spawnUnit(ai.props, Entity.FORCE_ENEMY, self._enemyY)
		end
	end
end

function Scene:getPlayerLoc()
	return self._playerX, self._playerY
end

function Scene:getEnemyLoc()
	return self._enemyX, self_enemyY
end

function Scene:getUnits()
	return self._units
end

function Scene:runCommand(slot, x, y)
	local tb = self._player[slot]
	if tb._nb > 0 then
		tb._nb = tb._nb - 1
		tb.run(tb.cmd)
	end
end

function Scene:emitAttackSpeedAura(x, y, r, force, value, duration)
	for k, v in pairs(self._units) do
		if v:isAlive() and v:isForce(force) and v:isPtInRange(x, y, r) then
			v:addAttackSpeedFactor(value, duration)
		end
	end
end

function Scene:emitMoveSpeedAura(x, y, r, force, value, duration)
	for k, v in pairs(self._units) do
		if v:isAlive() and v:isForce(force) and v:isPtInRange(x, y, r) then
			v:addMoveSpeedFactor(value, duration)
		end
	end
end

function Scene:emitRecoverHpAura(x, y, r, force, value, duration)
	for k, v in pairs(self._units) do
		if v:isAlive() and v:isForce(force) and v:isPtInRange(x, y, r) then
			v:addRecoverHpFactor(value, duration)
		end
	end
end

function Scene:emitAttackPowerAura(x, y, r, force, value, duration)
	for k, v in pairs(self._units) do
		if v:isAlive() and v:isForce(force) and v:isPtInRange(x, y, r) then
			v:addAttackPowerFactor(value, duration)
		end
	end
end

function Scene:update()
	self.ticks = self.ticks + 1
	for k, v in pairs(self._forces) do
		v.attackSpeedFactor:update(self.ticks)
		v.moveSpeedFactor:update(self.ticks)
		v.recoverHpFactor:update(self.ticks)
		v.attackPowerFactor:update(self.ticks)
	end
	
	if self._ai then
		self:updateAI(self.ticks)
	elseif self._playerAI then
		self:updatePlayerAI(self.ticks)
	end
	
	for k, v in pairs(self._player) do
		if v._ticks < self.ticks and v._nb < v.nb then
			v._ticks = self.ticks + v.cd
			v._nb = v._nb + 1
		end
	end
	
	local tb = {}
	for k, v in pairs(self._units) do
		tb[v] = v
	end
	for k, v in pairs(self._projectiles) do
		tb[v] = v
	end
	for k, v in pairs(tb) do
		v:update(self.ticks)
	end
end

function Scene:getUnitsInRound(force, x, y, r, exclusion)
	local units = {}
	for k, v in pairs(self._units) do
		if v:isAlive() and v:isForce(force) and (not exclusion or not exclusion[v]) then
			if v:isPtInRange(x, y, r) then
				table.insert(units, v)
			end
		end
	end
	return units
end

function Scene:getNearestUnit(force, x, y, r, exclusion)
	local unit = nil
	local dist = r ^ 2
	for k, v in pairs(self._units) do
		if v:isAlive() and v:isForce(force) and (not exclusion or not exclusion[v]) then
			local d = v:distanceSqTo(x, y)
			if d < dist then
				dist = d
				unit = v
			end
		end
	end
	return unit
end

function Scene:getRandomUnit(force, x, y, r, exclusion)
	local units = self:getUnitsInRound(force, x, y, r, exclusion)
	if #units > 0 then
		return units[math.random(#units)]
	end
end

return Scene