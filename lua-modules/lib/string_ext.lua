-- String

-- @func __index: Give strings a subscription operator
--	 @param s: string
--	 @param n: index
-- @returns
--	 @param s_: string.sub (s, n, n)
local _prev_index = getmetatable ("").__index
getmetatable ("").__index = function (s, n)
	if type (n) == "number" then
		return string.sub (s, n, n)
	-- Fall back to old metamethods
	elseif type (_prev_index) == "function" then
		return _prev_index (s, n)
	else
		return _prev_index[n]
	end
end

-- @func caps: Capitalise each word in a string
--	 @param s: string
-- @returns
--	 @param s_: capitalised string
function string.caps (s)
	return (string.gsub (s, "(%w)([%w]*)",
								function (l, ls)
									return upper (l) .. ls
								end))
end


-- @func format: Extend to work better with one argument
-- If only one argument is passed, no formatting is attempted
--	 @param f: format
--	 @param ...: arguments to format
-- @returns
--	 @param s: formatted string
local _format = string.format
function string.format (f, arg1, ...)
	if arg1 == nil then
		return f
	else
		return _format (f, arg1, ...)
	end
end

-- @func pad: Justify a string
-- When the string is longer than w, it is truncated (left or right
-- according to the sign of w)
--	 @param s: string to justify
--	 @param w: width to justify to (-ve means right-justify; +ve means
--		 left-justify)
--	 @param [p]: string to pad with [" "]
-- @returns
--	 s_: justified string
function string.pad (s, w, p)
	p = string.rep (p or " ", abs (w))
	if w < 0 then
		return string.sub (p .. s, -w)
	end
	return sub (s .. p, 1, w)
end

-- @func split: Split a string at a given separator
--	 @param s: string to split
--	 @param sep: separator regex
-- @returns
--	 @param ...: list of strings
function string.split (s, sep)
	local list = {}
	local pos = 1
	while true do
		do
			local first, last = string.find(s, sep, pos)
			if first then
				table.insert(list, string.sub(s, pos, first - 1))
				pos = last + 1
			else
				table.insert(list, string.sub(s, pos))
				break
			end
		end
	end
	return unpack(list)
end


local function tokey(v)
	if type(v) == "number" then
		return string.format("[%d]", v)
	elseif type(v) == "string" then
		return string.format("[%q]", v)
	end
	return string.format("[%s]", tostring(v))
end

function string.topretty(v, sep, tab, pre, map, key)
	map = map or {}
	pre = pre or ""
	sep = sep or ""
	tab = tab or ""
	key = key or "*"
	map[v] = key
	local ret = ""
	if type(v) == "table" then
		local s = ""
		local comma = ""
		for k, v in pairs(v) do
			s = s..comma
			comma = ","
			s = s..sep..tab..pre..tokey(k).."="
			if not map[v] then
				local key = key..tokey(k)
				s = s..string.topretty(v, sep, tab, pre..tab, map, key)
				map[v] = key
			else
				s = s..tab..map[v]
			end
		end
		if s == "" then
			ret = ret.."{}"
		else
			ret = ret.."{"..s..sep..pre.."}"
		end
	elseif type(v) == "string" then
		ret = ret..string.format("%q", v)
	else
		ret = ret..tostring(v)
	end
	return ret
end
