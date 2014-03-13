
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

function table.find(t, o)
	for k, v in pairs(t) do
		if v == o then
			return k
		end
	end
end

function table.copy (t)
	local o = {}
	for k, v in pairs (t) do
		o[k] = v
	end
	return o
end
