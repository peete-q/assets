
local random = {}

function random.new(seed)
	local self = {
		seed = seed
	}
	setmetatable(self, seed)
	return self
end

function random:gen(...)
	self.seed = self.seed + 1
	math.randomseed(self.seed)
	return math.random(...)
end

function random:select(tb, count, cb)
	local res = {}
	for i = #tb, 1, -1 do
		if self:gen(i) <= count then
			if cb then
				cb(tb[i])
			end
			table.insert(res, tb[i])
			count = count - 1
			if count <= 0 then
				break
			end
		end
	end
	return res
end