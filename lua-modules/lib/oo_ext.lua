
local __classes = {}

function class(name)
	local c = {}
	
	local parent
	function inherit(name)
		assert(__classes[name], "inherit undefined class: "..name)
		parent = __classes[name]
		table.merge(c, parent, true)
	end
	
	function define(content)
		table.merge(c, content)
		strict(c, "rw", name)
		local _ENV = {
			__base = parent
		}
		setmetatable(_ENV, {__index = _G, __newindex = _G})
		for k, v in pairs(c) do
			if type(v) == "function" then
				setfenv(v, _ENV)
			end
		end
		
		c.__call = function(self, ...)
			local o = clone(c)
			return o
		end
		setmetatable(c, c)
		__classes[name] = c
		
		local _ENV = {
			[name] = c
		}
		local _F = getfenv(2)
		setmetatable(_ENV, {__index = _F, __newindex = _F})
		setfenv(2, _ENV)
	end
end

function import(name)
	return __classes[name]
end