
local Unit = require "Unit"
local Factor = require "Factor"
local device = require "device"

local Battlefield = {}

local LANE_WIDTH = 20
local LANE_COUNT = math.floor(device.height * 0.5 / LANE_WIDTH)

Battlefield.__index = Battlefield

function Battlefield.new(root, seed)
	local self = {
		_units = {},
		_FXs = {},
		_root = root,
		_player = {},
		_playerOffset = 0,
		_enemyOffset = 0,
		_forces = Unit.newForceList(),
		
		ticks = 0,
	}
	setmetatable(self, Battlefield)
	
	return self
end

function Battlefield:destroy()
end

function Battlefield:getForce(id)
	return self._forces[id]
end

function Battlefield:addUnit(props, force, x, y)
	local o = Unit.new(props, self._forces[force])
	o._battlefield = self
	o._ticks = self.ticks
	self._root:add(o)
	o:setLoc(x, y)
	self._units[o] = o
	return o
end

function Battlefield:addPlayerUnit(props, x, y)
	return self:addUnit(props, Unit.FORCE_PLAYER, x, y)
end

function Battlefield:addEnemyUnit(props, x, y)
	return self:addUnit(props, Unit.FORCE_ENEMY, x, y)
end

function Battlefield:addPlayerMontherShip(props, x, y)
	local o = self:addUnit(props, Unit.FORCE_PLAYER, x, y)
	self._playerMotherShip = o
	return o
end

function Battlefield:addEnemyMotherShip(props, x, y)
	local o = self:addUnit(props, Unit.FORCE_ENEMY, x, y)
	self._enemyMotherShip = o
	return o
end

function Battlefield:addFX(o)
	o._battlefield = self
	self._root:add(o)
	self._FXs[o] = o
	return o
end

function Battlefield:remove(o)
	o:setLayer(nil)
	self._units[o] = nil
	self._FXs[o] = nil
end

function Battlefield:spawnPlayerUnit(props)
	local y = math.random(-LANE_COUNT, LANE_COUNT) * LANE_WIDTH
	local x = self:getPlayerLoc()
	local o = self:addUnit(props, Unit.FORCE_PLAYER, self._playerOffset + x, y)
	o:move()
	return o
end

function Battlefield:spawnEnemyUnit(props)
	local y = math.random(-LANE_COUNT, LANE_COUNT) * LANE_WIDTH
	local x = self:getEnemyLoc()
	local o = self:addUnit(props, Unit.FORCE_ENEMY, self._enemyOffset + x, y)
	o:move()
	return o
end

local playerInfo = {
	[1] = {run = nil, cmd = nil, spend = 1, cd = 10, nb = 3}
}

function Battlefield:loadPlayer(playerInfo)
	self._player = playerInfo
	for k, v in pairs(self._player) do
		v._nb = v.nb
		v._ticks = 0
	end
end

local aiInfo = {
	loopBegin = 30,
	[1] = {props, 1, 3},
	[30] = {props, 2, 3},
	[60] = {props, 3, 5},
}

function Battlefield:loadAI(aiInfo)
	self._AI = aiInfo
end

local playerAI = {
	{
		time = 30,
		crystal = 30,
		units = {},
	},
}

function Battlefield:loadPlayerAI()
end

function Battlefield:simulateAI(ticks)
	local index = ticks
	if index > self._AI.loopBegin then
		index = math.fmod(index, self._AI.loopBegin) + self._AI.loopBegin
	end
	local ai = self._AI[index]
	if ai then
		for i = 1, math.random(ai[2], ai[3]) do
			self:spawnUnit(ai[1], Unit.FORCE_ENEMY, self._enemyY)
		end
	end
end

function Battlefield:getPlayerLoc()
	return self._playerMotherShip:getLoc()
end

function Battlefield:getEnemyLoc()
	return self._enemyMotherShip:getLoc()
end

function Battlefield:getUnits()
	return self._units
end

function Battlefield:runCommand(slot, x, y)
	local tb = self._player[slot]
	if tb._nb > 0 then
		tb._nb = tb._nb - 1
		tb.run(tb.cmd)
	end
end

function Battlefield:emitAttackSpeedAura(x, y, r, force, value, duration)
	for k, v in pairs(self._units) do
		if v:isAlive() and v:isForce(force) and v:isPtInRange(x, y, r) then
			v:addAttackSpeedFactor(value, duration)
		end
	end
end

function Battlefield:emitMoveSpeedAura(x, y, r, force, value, duration)
	for k, v in pairs(self._units) do
		if v:isAlive() and v:isForce(force) and v:isPtInRange(x, y, r) then
			v:addMoveSpeedFactor(value, duration)
		end
	end
end

function Battlefield:emitRecoverHpAura(x, y, r, force, value, duration)
	for k, v in pairs(self._units) do
		if v:isAlive() and v:isForce(force) and v:isPtInRange(x, y, r) then
			v:addRecoverHpFactor(value, duration)
		end
	end
end

function Battlefield:emitAttackPowerAura(x, y, r, force, value, duration)
	for k, v in pairs(self._units) do
		if v:isAlive() and v:isForce(force) and v:isPtInRange(x, y, r) then
			v:addAttackPowerFactor(value, duration)
		end
	end
end

function Battlefield:update()
	self.ticks = self.ticks + 1
	
	self._forces:update(self.ticks)
	
	if self._AI then
		self:simulateAI(self.ticks)
	elseif self._playerAI then
		self:simulatePlayerAI(self.ticks)
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
	for k, v in pairs(self._FXs) do
		tb[v] = v
	end
	for k, v in pairs(tb) do
		v:update()
	end
end

function Battlefield:getUnitsInRound(force, x, y, r, exclusion)
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

function Battlefield:getNearestUnit(force, x, y, r, exclusion)
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

function Battlefield:getRandomUnit(force, x, y, r, exclusion)
	local units = self:getUnitsInRound(force, x, y, r, exclusion)
	if #units > 0 then
		return units[math.random(#units)]
	end
end

function Battlefield:getBestTarget(force, r)
	local n = 0
	local o
	for k, v in pairs(self._units) do
		local i = 0
		for k, v2 in pairs(self._units) do
			if v:distance(v2) < r then
				i = i + 1
			end
		end
		if i > n then
			n = i
			o = v
		end
	end
	return o
end

return Battlefield