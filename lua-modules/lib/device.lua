require("moai.compat")
local file = require("file")
local device_profile = require("device.profile")
local device = {}
device.hasPVR = false
device.hasOGG = false
device.IDIOM_HANDSET = "handset"
device.IDIOM_TABLET = "tablet"
device.ASSET_MODE_LO = "lo"
device.ASSET_MODE_HI = "hi"
device.ASSET_MODE_X_HI = "xhi"
device.FILL_RATE_LO = "lo"
device.FILL_RATE_HI = "hi"
device.CPU_LO = "lo"
device.CPU_HI = "hi"
device.OS_IOS = "ios"
device.OS_ANDROID = "android"
device.PLATFORM_IOS = "ios"
device.PLATFORM_IOS_TESTFLIGHT = "ios_testflight"
device.PLATFORM_ANDROID_GOOGLE = "android_google"
device.PLATFORM_ANDROID_AMAZON = "android_amazon"
device.PLATFORM_OSX_APPSTORE = "osx_store"
device.PLATFORM_OSX = "osx"
device.PLATFORM_OSX_STEAM = "osx_steam"
device.PLATFORM_WINDOWS = "windows"
device.PLATFORM_WINDOWS_STEAM = "windows_steam"
device.PLATFORM_LINUX = "linux"
device.PLATFORM_UNKNOWN = "unknown"
device.asset_rez = device.ASSET_MODE_LO
local profile
local profileName = os.getenv("MOAI_DEVICE_PROFILE")
if profileName ~= nil then
  profile = require("device.profile").get(profileName:lower())
  print("Using device profile: " .. profileName)
elseif os.getenv("SIMULATE_SCREEN_SIZE") then
  profileName = "manual"
  profile = {
    width = tonumber(os.getenv("SIMULATE_SCREEN_W")),
    height = tonumber(os.getenv("SIMULATE_SCREEN_H"))
  }
  print("Using screen size: " .. profile.width .. "x" .. profile.height)
elseif os.getenv("DEVICE_WIDTH") then
  profileName = "manual"
  profile = {
    width = tonumber(os.getenv("DEVICE_WIDTH")),
    height = tonumber(os.getenv("DEVICE_HEIGHT"))
  }
  print("Using device size: " .. profile.width .. "x" .. profile.height)
end
local platform
if os.getenv("DEVICE_PLATFORM") then
  platform = os.getenv("DEVICE_PLATFORM")
else
  platform = MOAIEnvironment.getDevModel()
end
if profile == nil then
  profile = {}
  profile.width, profile.height = MOAISim.getDeviceSize()
  print("Found device size: ", profile.width, profile.height)
elseif os.getenv("MOAI_DEVICE_PORTRAIT") and profile.width > profile.height then
  profile.width, profile.height = profile.height, profile.width
end
device.width, device.height = profile.width, profile.height
if device.width <= 0 then
  device.width = 1024
end
if device.height <= 0 then
  print("Could not find default height")
  device.height = 768
end
local shortestSide = device.width
if device.height < device.width then
  shortestSide = device.height
end
if shortestSide >= 768 and platform:find("iPad") or shortestSide == 768 then
  device.ui_scale = 768 / shortestSide
  device.ui_idiom = device.IDIOM_TABLET
  if shortestSide >= 1536 then
    device.ui_assetrez = device.ASSET_MODE_X_HI
  else
    device.ui_assetrez = device.ASSET_MODE_HI
    if os.getenv("DEVICE_RETINA") then
      device.ui_assetrez = device.ASSET_MODE_X_HI
    end
  end
else
  device.ui_scale = 640 / shortestSide
  device.ui_idiom = device.IDIOM_HANDSET
  if shortestSide <= 320 then
    device.ui_assetrez = device.ASSET_MODE_LO
    if os.getenv("DEVICE_RETINA") then
      device.ui_assetrez = device.ASSET_MODE_HI
    end
  else
    device.ui_assetrez = device.ASSET_MODE_HI
  end
end
device.ui_width = device.width * device.ui_scale
device.ui_height = device.height * device.ui_scale
device.fill = device.FILL_RATE_HI
device.cpu = device.CPU_HI
local version = MOAIEnvironment.getAppVersion()
local osbrand = MOAIEnvironment.getOSBrand()
if osbrand == MOAIEnvironment.OS_BRAND_IOS then
  do
    local iosProfile = device_profile.getIOSProfile(MOAIEnvironment.getDevModel():lower())
    device.hasPVR = true
    device.hasCAF = true
    profile.dpi = iosProfile.dpi
    device.fill = iosProfile.fill
    device.cpu = iosProfile.cpu
    device.perf = iosProfile.perf
    device.displayName = iosProfile.name
    device.os = device.OS_IOS
    device.platform = device.PLATFORM_IOS
  end
elseif osbrand == MOAIEnvironment.OS_BRAND_ANDROID then
  profile.dpi = MOAISim.getDeviceDpi()
  device.os = device.OS_ANDROID
  device.displayName = "Android"
  if device.ui_assetrez == device.ASSET_MODE_HI then
    if MOAIEnvironment.getNumProcessors() > 1 then
      device.cpu = device.CPU_HI
      device.fill = device.FILL_RATE_HI
    else
      device.cpu = device.CPU_LO
      device.fill = device.FILL_RATE_LO
    end
  else
    device.cpu = device.CPU_LO
    device.perf = device.CPU_LO
    device.fill = device.FILL_RATE_LO
  end
  if MOAIEnvironment.getDevBrand():lower():find("amazon") then
    device.platform = device.PLATFORM_ANDROID_AMAZON
  else
    device.platform = device.PLATFORM_ANDROID_GOOGLE
  end
else
  device.platform = device.PLATFORM_UNKNOWN
end
if os.getenv("MOAI_UDID") then
  device.udid = os.getenv("MOAI_UDID")
else
  device.udid = MOAIEnvironment.getUDID()
end
local appId = MOAIEnvironment.getAppID()
if device.platform == device.PLATFORM_IOS then
  device.storeURL = "itms-apps://itunes.com/apps/" .. appId
elseif device.platform == device.PLATFORM_ANDROID_GOOGLE then
  device.storeURL = "market://details?id=" .. appId
elseif device.platform == device.PLATFORM_ANDROID_AMAZON then
  device.storeURL = "amzn://apps/android?p=" .. appId
else
  device.storeURL = "http://www.harebrained-schemes.com?appId=" .. appId .. "&store=1&os=" .. osbrand
end
device.dpi = profile.dpi or 132
function device:size()
  return self.width, self.height
end
local dataDir, cacheDir, docsDir
if MOAIApp ~= nil and MOAIApp.getDirectoryInDomain then
  dataDir = MOAIApp.getDirectoryInDomain(MOAIApp.DOMAIN_APP_SUPPORT)
  cacheDir = MOAIApp.getDirectoryInDomain(MOAIApp.DOMAIN_CACHES)
  docsDir = MOAIApp.getDirectoryInDomain(MOAIApp.DOMAIN_DOCUMENTS)
else
  local docDir = MOAIEnvironment.getDocumentDirectory()
  dataDir = "data/support"
  cacheDir = "data/cache"
  docsDir = "data/docs"
  if docDir ~= "UNKNOWN" then
    dataDir = docDir .. "/" .. dataDir
    cacheDir = docDir .. "/" .. cacheDir
    docsDir = docDir .. "/" .. docsDir
  end
end
local function _makePath(basePath, path, createIfNeeded)
  local p
  if path == nil then
    p = basePath
  else
    p = string.format("%s/%s", basePath, path)
  end
  createIfNeeded = createIfNeeded or true
  if createIfNeeded then
    file.mkdir(p)
  end
  return p
end
function device.getDataPath(path, createIfNeeded)
  return _makePath(dataDir, path, createIfNeeded)
end
function device.getDocumentsPath(path, createIfNeeded)
  return _makePath(docsDir, path, createIfNeeded)
end
function device.getCachePath(path, createIfNeeded)
  return _makePath(cacheDir, path, createIfNeeded)
end
return device
