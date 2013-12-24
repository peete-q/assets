

local gm = {}
local s, c, k, h
local eof = "<eof>\n"
local env = {
	echo = function(...)
		local arg = {...}
		local s = ""
		for i, v in ipairs(arg) do
			s = s..tostring(v).."\n"
		end
		h:settimeout(10)
		local ok, e = h:send(s.."\n")
		if not ok then
			print("[GM] echo failed, "..e)
		end
		h:settimeout(0)
	end,
}

function gm.listen(host, port)
	s = socket.bind(host, port)
	if not s then
		print("[GM] server cannot bind on "..host..":"..port)
		return
	end
	local i, p = s:getsockname()
	print("[GM] server waiting on "..tostring(i)..":"..tostring(p))
	s:settimeout(0)
	setmetatable(env, {__index = _G, __newindex = function(self, key, value)
		if _G[key] then
			_G[key] = value
		else
			rawset(self, key, value)
		end
	end})
end

function gm.step()
	if not s then
		return
	end
	
	local v = s:accept()
	if v then
		local i, p = v:getpeername()
		print("[GM] client connected from "..tostring(i)..":"..tostring(p))
		v:settimeout(0)
		c = c or {}
		c[v] = v
	end
	
	if c then
		for k, v in pairs(c) do
			local cmd, e = v:receive()
			if cmd then
				print("[GM] "..cmd)
				h = v
				local ok, e = loadstring(cmd), "input error"
				if ok then
					setfenv(ok, env)
					ok, e = xpcall(ok, debug.traceback)
					if not ok then
						print(e)
					end
				end
				v:settimeout(10)
				local ack = eof
				if not ok then
					ack = e.."\n"..ack
				end
				ok, e = v:send(ack)
				if not ok then
					print("[GM] send ack failed, "..e)
				end
				v:settimeout(0)
			elseif e ~= "timeout" then
				local i, p = v:getpeername()
				print("[GM] client "..tostring(i)..":"..tostring(p).." "..e)
				c[v] = nil
				v:close()
			end
		end
	end
end

function gm.connect(host, port)
	local c = assert(socket.connect(host, port))
	while true do
		io.write("GM: ")
		local l = io.read("*line")
		if l == "q" then
			c:shutdown("both")
			return
		end
		c:send(l.."\n")
		c:settimeout(10)
		while true do
			local ack, e = c:receive()
			if not ack then
				print("receive ack failed, "..e)
				break
			end
			if ack == "<eof>" then
				break
			end
			print(ack)
		end
	end
end

return gm