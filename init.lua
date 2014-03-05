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

function print(...)
	local s = ""
	for k, v in ipairs{...} do
		s = s..tostring(v).." "
	end
	MOAILogMgr.log(s.."\n")
end

function printf(...)
	print(string.format ( ... ))
end

undefined = false
