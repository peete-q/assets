function MOAIEnvironment.getDevModel()
	return MOAIEnvironment.devModel
end

function MOAIEnvironment.getAppVersion()
	return MOAIEnvironment.appVersion
end
	
function MOAIEnvironment.getUDID()
	return MOAIEnvironment.udid
end

function MOAIEnvironment.getOSBrand()
	return MOAIEnvironment.osBrand
end
	
function MOAISim.getDeviceSize()
	return 1280, 720
end

function MOAIEnvironment.getAppID()
	return MOAIEnvironment.appID or "appIP"
end

function MOAIEnvironment.getDocumentDirectory()
	return "myApp"
end

local _mt = MOAIPartition.getInterfaceTable()
local _propListForPoint = _mt.propListForPoint
function _mt.propListForPoint(...)
	return {_propListForPoint(...)}
end

local _new = MOAIVertexBuffer.new
function MOAIVertexBuffer.new()
	local vb = _new()
	local mt = getmetatable(vb)
	local index = mt.__index
	mt.__index = function(self, key)
		if key == 'setPenWidth' or key == 'setPrimType' then
			return function(self, key) end
		end
		return index[key]
	end
	return vb
end

local _new = MOAIFont.new
function MOAIFont.new()
	local vb = _new()
	local mt = getmetatable(vb)
	local index = mt.__index
	mt.__index = function(self, key)
		if key == 'setTexture'  then
			return function(self, key) end
		end
		return index[key]
	end
	return vb
end

function xprint(tb, name)
	name = name or ""
	print ("--------------"..name.."--------------")
	if type(tb) ~= "table" then
		print(tb)
		return
	end
	for k, v in pairs(tb) do
		print(k, v)
	end
end

function print(...)
	local arg = {...}
	local s = tostring(arg[1])
	for i = 2, #arg do
		s = s.." "..tostring(arg[i])
	end
	MOAILogMgr.log(s)
end

