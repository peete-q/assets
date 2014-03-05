
local util = {}

function util.get_moai_mt(o)
	return getmetatable(getmetatable(o)).__index
end

return util