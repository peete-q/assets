undefined = falsefunction printf(...)	print(string.format(...))endfunction toprettystring(o)	if type(o) == "string" then		return string.format("%q", o)	elseif type(o) == "table" then		return table.tostring(o, "\n", "\t")	else		return tostring(o)	endendfunction getfield(o, k)	if type(o) == "table" then		return o[k]	elseif type(o) == "userdata" and getmetatable(o) then		return o[k]	endendfunction strict(o, rw, name)	assert(type(o) == "table" and not getmetatable(o), "expect a table without metatable")		rw = rw or "rw"	name = name or "?"	local mt = {}	if string.find(rw, "w") then		mt.__newindex = function(self, key, value)			error("attempt to write undefined memmber '"..key.."' of '"..name.."'")		end	end	if string.find(rw, "r") then		mt.__index = function(self, key)			error("attempt to read undefined memmber '"..key.."' of '"..name.."'")		end	end	setmetatable(o, mt)	return oend--- Make a shallow copy of a table, including any metatable (for a-- deep copy, use tree.clone).-- @param v any value-- @param nometa if non-nil don't copy metatable-- @return copy of tablefunction clone (v, _ref)	_ref = _ref or {}	_ref[v] = v	local o = v	if getfield(v, "__clone") then		o = v:__clone()	elseif type(v) == "table" then		o = {}		for k, v in pairs(v) do			if _ref[v] then				o[k] = _ref[v]			elseif getfield(v, "__clone") then				local c = v:__clone()				o[k] = c				_ref[v] = c			elseif type(v) == "table" then				local c = clone(v, _ref)				o[k] = c				_ref[v] = c			else				o[k] = v			end		end		setmetatable(o, getmetatable(v))	end	return oend--- An iterator like ipairs, but in reverse.-- @param t table to iterate over-- @return iterator function-- @return the table, as above-- @return #t + 1function rpairs (t)	return function (t, n)					 n = n - 1					 if n > 0 then						 return n, t[n]					 end				 end,	t, #t + 1endfunction spairs(t, f)	local a = {}	for n in pairs(t) do		table.insert(a, n)	end	table.sort(a, f)	local i = 0	local function iter()		i = i + 1		if a[i] == nil then			return nil		else			return a[i], t[a[i]]		end	end	return iterend--- Extend to allow formatted arguments.-- @param v value to assert-- @param f format-- @param ... arguments to format-- @return valuefunction assert(v, f, ...)	if not v then		error(string.format(f, ...))	end	return vendfunction warnning(v, ...)	if not v then		print("WARNNING:", string.format(...))	end	return vendlocal _NIL = {}function pack(...)	local n = select("#", ...)	local t = {		...	}	for i = 1, n do		if t[i] == nil then			t[i] = _NIL		end	end	return tendfunction unpack(t, i, j)	i = i or 1	j = j or #t	if i > j then		return	end	local v = t[i]	if v == _NIL then		v = nil	end	return v, unpack(t, i + 1, j)endfunction pcall(f, ...)	local args = pack(...)	return xpcall(function() f(unpack(args)) end, debug.traceback)endrequire "oo_ext"require "string_ext"require "table_ext"require "debug_ext"require "math_ext"