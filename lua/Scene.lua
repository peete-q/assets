
local Scene = {
	SPACE = 1,
	SKY = 2,
}

local GRID_SIZE = 10

Scene.__index = Scene

function Scene.new(w, h, spaceLayer, skyLayer, seed)
	local self = {
		WIDTH = w,
		HEIGHT = h,
		
		_units = {},
		_projectiles = {},
		_playerX = w / 2,
		_playerY = -h / 2,
		_enemyX = w / 2,
		_enemyY = h / 2,
		_spaceLayer = spaceLayer,
		_skyLayer = skyLayer,
	}
	
	setmetatable(self, Scene)
	return self
end

function Scene:destroy()
end

function Scene:addUnit(e)
	e._scene = self
	e:setLayer(self._spaceLayer)
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

function Scene:spawnUnit(e)
	self:addUnit(e)
	local n = (self.WIDTH / 2) / GRID_SIZE
	local x = math.random(-n, n) * GRID_SIZE
	e:setWorldLoc(x, self._playerY - e.bodySize)
end

function Scene:loadPlayer()
end

function Scene:loadAI()
end

function Scene:loadPlayerAI()
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

function Scene:update(ticks)
	local tb = {}
	for k, v in pairs(self._units) do
		tb[v] = v
	end
	for k, v in pairs(self._projectiles) do
		tb[v] = v
	end
	for k, v in pairs(tb) do
		v:update(ticks)
	end
end

function Scene:getUnitsInRound(force, x, y, r)
	local units = {}
	for k, v in pairs(self._units) do
		if v:isAlive() and v:isForce(force) and v:isPtInRange(x, y, r) then
			table.insert(units, v)
		end
	end
	return units
end

return Scene