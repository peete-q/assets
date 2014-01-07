
local Scene = {
	UINT_ME = 1,
	UNIT_ENEMY = 2,
	UNIT_BULLET = 3,
	
	_layers = {},
}

local SPACE_SIZE = 10

Scene.__index = Scene

function Scene.new(w, h, layer, seed)
	local self = {
		WIDTH = w,
		HEIGHT = h,
		
		_units = {
			[Scene.UINT_ME] = {},
			[Scene.UNIT_ENEMY] = {},
			[Scene.UNIT_BULLET] = {},
		},
		_myY = -h / 2,
		_enemyY = h / 2,
		_layer = layer,
	}
	self._partition = MOAIPartition.new()
	self._layer:setPartition(self._partition)
	setmetatable(self, Scene)
	return self
end

function Scene:destroy()
end

function Scene:addUnit(force, e)
	e._scene = self
	e:setLayer(self._layer)
	self._units[force][e] = e
	return e
end

function Scene:spawnUnit(force, e)
	self:addUnit(force, e)
	local n = (self.WIDTH / 2) / SPACE_SIZE
	local x = math.random(-n, n) * SPACE_SIZE
	e:setWorldLoc(x, self._myY - e.bodySize)
end

function Scene:getForce(nb)
	return self._units[nb]
end

function Scene:update(ticks)
	for _, force in ipairs(self._units) do
		for _, entity in pairs(force) do
			entity:update(ticks)
		end
	end
end

function Scene:getForceInRound(nbForce, x, y, r)
	local units = {}
	local force = self:getForce(nbForce)
	for k, v in pairs(force) do
		if v:isAlive() and v:isPtInRange(x, y, r) then
			table.insert(units, v)
		end
	end
	return units
end

return Scene