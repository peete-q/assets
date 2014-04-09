
local actionset = require "actionset"

local shake = {}

function shake.new(source)
	local self = actionset.new()
	self._shakeDrivers = {}
	self._shakeX = 0
	self._shakeY = 0
	self._source = source
	self.add = shake.add
	self.setSource = shake.setSource
	self:run(function(dt)
		if self._source and not table.empty(self._shakeDrivers) then
			local t = self:getTime()
			local x, y = 0, 0
			for driver, v in pairs(self._shakeDrivers) do
				local dx, dy = driver(t)
				if not dx then
					self._shakeDrivers[driver] = nil
				else
					x = x + dx
					y = y + dy
				end
			end
			self._source:addLoc(-self._shakeX, -self._shakeY)
			self._shakeX = (math.random() - 0.5) * x
			self._shakeY = (math.random() - 0.5) * y
			self._source:addLoc(self._shakeX, self._shakeY)
		end
	end)
	return self
end

function shake:setSource(o)
	self._source = o
end

function shake:clear()
	self._shakeDrivers = {}
end

function shake:add(strengthX, strengthY, duration)
	if strengthX == nil then
		strengthX = 50
	end
	if strengthY == nil then
		strengthY = 50
	end
	if duration == nil then
		duration = 1
	end
	
	local startTime = self:getTime()
	local function fn(t)
		local a = (t - startTime) / duration
		if a > 1 then
			return nil
		end
		local n = -math.pow(2, -10 * a) + 1
		return strengthX - strengthX * n, strengthY - strengthY * n
	end
	self._shakeDrivers[fn] = true
end

return shake