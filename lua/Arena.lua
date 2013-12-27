
local Arena = {
	FORCE_SELF = 1,
	FORCE_ENEMY = 2,
	
	_layers = {},
}

local SPACE_SIZE = 10

Arena.__index = Arena

function Arena.new(w, h, seed)
	local self = {
		WIDTH = w,
		HEIGHT = h,
		
		_forces = {
			[Arena.FORCE_SELF] = {},
			[Arena.FORCE_ENEMY] = {},
		},
		_myY = -h / 2,
		_enemyY = h / 2,
	}
	setmetatable(self, Arena)
	return self
end

function Arena:destroy()
end

function Arena:addUnit(force, spawn)
	local e = spawn()
	e._arena = self
	self._forces[force][e] = e
	return e
end

function Arena:spawnUnit(force, spawn)
	local e = self:addUnit(force, spawn)
	local n = (self.WIDTH / 2) / SPACE_SIZE
	local x = math.random(-n, n) * SPACE_SIZE
	e:setWorldLoc(x, self._myY - e.bodySize)
end

function Arena:getForce(nb)
	return self._forces[nb]
end

function Arena:update(ticks)
	for _, force in ipairs(self._forces) do
		for _, entity in pairs(force) do
			entity:update(ticks)
		end
	end
end

return Arena