local pairs = pairs
local tinsert = table.insert
local _M = {}
local PROFILES = {
	["iphone"] = {
		width = 480,
		height = 320,
		dpi = 163,
		cpu = "lo",
		fill = "hi",
		perf = "lo",
		name = "iPhone"
	},
	["iphone4"] = {
		width = 960,
		height = 640,
		dpi = 326,
		cpu = "hi",
		fill = "lo",
		perf = "lo",
		name = "iPhone 4"
	},
	["iphone4s"] = {
		width = 960,
		height = 640,
		dpi = 326,
		cpu = "hi",
		fill = "hi",
		name = "iPhone 4S"
	},
	["ipad"] = {
		width = 1024,
		height = 768,
		dpi = 132,
		cpu = "lo",
		fill = "lo",
		name = "iPad"
	},
	["ipad2"] = {
		width = 1024,
		height = 768,
		dpi = 132,
		cpu = "hi",
		fill = "hi",
		name = "iPad 2"
	},
	["ipad3"] = {
		width = 2048,
		height = 1536,
		dpi = 264,
		cpu = "hi",
		fill = "hi",
		name = "iPad 3"
	},
	["hvga"] = {width = 480, height = 320},
	["wvga"] = {width = 800, height = 480},
	["fwvga"] = {width = 854, height = 480},
	["1024x600"] = {width = 1024, height = 600},
	["1280x768"] = {width = 1280, height = 768}
}
PROFILES.droid = PROFILES.fwvga
PROFILES.kindlefire = PROFILES["1024x600"]
PROFILES.galaxytab = PROFILES["1024x600"]
PROFILES.gslate = PROFILES["1280x768"]
function _M.list()
	local t = {}
	for k, v in pairs(PROFILES) do
		tinsert(t, k)
	end
	return t
end

function _M.get(profile)
	return PROFILES[profile]
end

local label_iphone = "iphone"
local iphone_len = label_iphone:len() + 1
local label_ipod = "ipod"
local ipod_len = label_ipod:len() + 1
local label_ipad = "ipad"
local ipad_len = label_ipad:len() + 1
function _M.getIOSProfile(platform)
	local version
	if platform:find(label_iphone) then
		version = tonumber(platform:sub(iphone_len, iphone_len))
		if version and version >= 4 then
			return PROFILES.iphone4s
		elseif version and version == 3 then
			return PROFILES.iphone4
		end
		return PROFILES.iphone
	elseif platform:find(label_ipod) then
		version = tonumber(platform:sub(ipod_len, ipod_len))
		if version and version >= 4 then
			return PROFILES.iphone4
		end
		return PROFILES.iphone
	else
		version = tonumber(platform:sub(ipad_len, ipad_len))
		if version and version >= 3 then
			return PROFILES.ipad3
		elseif version and version == 2 then
			return PROFILES.ipad2
		end
		return PROFILES.ipad
	end
end

return _M
