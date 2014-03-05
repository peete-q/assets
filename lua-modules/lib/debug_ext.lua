
function debug.tracefull(level)
	local ret = ""
	level = level or 2
	ret = ret .. "stack traceback:\n"
	while true do	
		--get stack info	
		local info = debug.getinfo(level, "Sln")
		if not info then
			break
		end
		
		if info.what == "C" then	-- C function	
			ret = ret .. tostring(level) .. "\tC function\n"
		else						-- Lua function	
			ret = ret .. string.format("\t[%s]:%d in function '%s'\n", info.short_src, info.currentline, info.name or "?")
		end
		--get local vars	
		local i = 1
		while true do	
			local name, value = debug.getlocal(level, i)
			if not name then
				break
			end
			ret = ret .. "\t\t" .. name .. "=" .. string.topretty(value) .. "\n"
			i = i + 1
		end
		level = level + 1
	end
	return ret
end

function debug.getfuncinfo(f)
	local t = debug.getinfo(f)
	return string.format("%s:%s%s:%d", t.what, t.namewhat or "", t.source, t.linedefined)
end