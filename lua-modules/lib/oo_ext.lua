
local __classes = {}

function class(name)
	local _C = {}
	local base = {}
	
	function inherit(name)
		assert(__classes[name], "inherit undefined class: "..name)
		base = __classes[name]
		table.merge(_C, base._C0)
	end
	
	function define(this)
		table.merge(_C, this)
		
		_C.__base = base._C
		_C.__index = _C
		
		local _ENV = {
			__base = base._C
		}
		local _F = getfenv(2)
		setmetatable(_ENV, {__index = _F, __newindex = _F})
		for k, v in pairs(this) do
			if type(v) == "function" then
				setfenv(v, _ENV)
			end
		end
		
		local _C0 = _C
		local _M = {
			__call = function(self, ...)
				local o = {}
				for k, v in pairs(_C) do
					if getfield(v, "__clone") then
						o[k] = v:__clone()
					elseif type(v) == "table" then
						o[k] = table.clone(v)
					end
				end
				o.__class = _C
				o.__tostring = string.format("object{class %s}: (%s)", name, tostring(o))
				o = strict(o, "+", _C0)
				return o
			end
		}
		_C = strict(_C, "rw+", _M)
		rawset(_C, "__tostring", "class "..name)
		__classes[name] = {_C = _C, _C0 = _C0}
		
		local _ENV = {
			[name] = _C,
		}
		setmetatable(_ENV, {__index = _F, __newindex = _F})
		setfenv(2, _ENV)
	end
	
	return _C
end

function import(name)
	return __classes[name]._C
end

function base(name)
	local t = require(name)
	return table.clone(t)
end