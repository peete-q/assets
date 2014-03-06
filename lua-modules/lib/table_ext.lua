
--- Return whether table is empty.
-- @param t table
-- @return <code>true</code> if empty or <code>false</code> otherwise
function table.empty (t)
	return not next (t)
end

--- Find the number of elements in a table.
-- @param t table
-- @return number of elements in t
function table.size (t)
	local n = 0
	for k, v in pairs (t) do
		n = n + 1
	end
	return n
end

--- Make the list of keys of a table.
-- @param t table
-- @return list of keys
function table.keys (t)
	local list = {}
	for k, v in pairs (t) do
		table.insert (list, k)
	end
	return list
end

--- Make the list of values of a table.
-- @param t table
-- @return list of values
function table.values (t)
	local list = {}
	for k, v in pairs (t) do
		table.insert (list, v)
	end
	return list
end

--- Make a shallow copy of a table, including any metatable (for a
-- deep copy, use tree.clone).
-- @param t table
-- @param nometa if non-nil don't copy metatable
-- @return copy of table
function table.clone (t, nometa, _ref)
	_ref = _ref or {}
	_ref[t] = t
	local o = {}
	for k, v in pairs(t) do
		if _ref[v] then
			o[k] = _ref[v]
		elseif type(v) == "table" then
			local c = table.clone(v, nometa, _ref)
			o[k] = c
			_ref[v] = c
		else
			o[k] = v
		end
	end
	if not nometa then
		setmetatable(o, getmetatable(t))
	end
	return o
end

--- Merge two tables.
-- If there are duplicate fields, o's will be used. The metatable of
-- the returned table is that of t.
-- @param t first table
-- @param o second table
-- @return merged table
function table.merge (t, o, nocover)
	for k, v in pairs (o) do
		if t[k] == nil or not nocover then
			t[k] = v
		end
	end
	return t
end

function table.copy (t)
	local o = {}
	for k, v in pairs (t) do
		o[k] = v
	end
	return o
end

local function _keystr(v)
	if type(v) == "number" then
		return string.format("[%d]", v)
	elseif type(v) == "string" then
		return string.format("[%q]", v)
	end
	return string.format("[%s]", tostring(v))
end

function table.tostring(v, sep, tab, _pre, _loc, _ref)
	sep = sep or ""
	tab = tab or ""
	_pre = _pre or ""
	_loc = _loc or "*"
	_ref = _ref or {}
	_ref[v] = _loc
	local ret = ""
	local str = ""
	local comma = ""
	for k, v in pairs(v) do
		str = str..comma
		comma = ","
		str = str..sep..tab.._pre.._keystr(k).."="
		if not _ref[v] then
			local _loc = _loc.._keystr(k)
			str = str..table.tostring(v, sep, tab, _pre..tab, _loc, _ref)
			_ref[v] = _loc
		else
			str = str..tab.._ref[v]
		end
	end
	if str == "" then
		ret = ret.."{}"
	else
		ret = ret.."{"..str..sep.._pre.."}"
	end
	return ret
end