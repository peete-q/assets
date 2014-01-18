
local Factor = {}

Factor.__index = Factor

function Factor.new()
	local self = {
		_values = {}
	}
	setmetatable(self, Factor)
	return self
end

function Factor:add(value, duration)
	self._updated = true
	table.insert(self._values, {value, duration})
end

function Factor:calc()
	local n = 0
	for k, v in pairs(self._values) do
		n = n + v[1]
	end
	return n
end

function Factor:update(ticks)
	local temp = {}
	for k, v in pairs(self._values) do
		temp[k] = v
	end
	local updated = self._updated
	for k, v in pairs(temp) do
		if v[2] < ticks then
			self._values[k] = nil
			updated = true
		end
	end
	return updated
end

return Factor