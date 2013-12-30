
local Scene = {
	FORCE_SELF = 1,
	FORCE_ENEMY = 2,
	
	_layers = {},
}

local SPACE_SIZE = 10

Scene.__index = Scene

function Scene.new(w, h, layer, seed)
	local self = {
		WIDTH = w,
		HEIGHT = h,
		
		_forces = {
			[Scene.FORCE_SELF] = {},
			[Scene.FORCE_ENEMY] = {},
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

function Scene:addUnit(force, spawn)
	local e = spawn()
	e._scene = self
	e:setLayer(self._layer)
	self._forces[force][e] = e
	return e
end

function Scene:spawnUnit(force, spawn)
	local e = self:addUnit(force, spawn)
	local n = (self.WIDTH / 2) / SPACE_SIZE
	local x = math.random(-n, n) * SPACE_SIZE
	e:setWorldLoc(x, self._myY - e.bodySize)
end

function Scene:getForce(nb)
	return self._forces[nb]
end

function Scene:update(ticks)
	for _, force in ipairs(self._forces) do
		for _, entity in pairs(force) do
			entity:update(ticks)
		end
	end
end

return Scene