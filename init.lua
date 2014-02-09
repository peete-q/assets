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
	return 960, 640
end

function MOAIEnvironment.getAppID()
	return "myGame"
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

function print(...)
	local s = ""
	for k, v in ipairs{...} do
		s = s..tostring(v).." "
	end
	MOAILogMgr.log(s.."\n")
end

function printx(o)
	if type(o) ~= "table" then
		print(o)
		return
	end
	for k, v in pairs(o) do
		print(k, v)
	end
end

function printf(...)
	print(string.format ( ... ))
end

undefined = false
