local MOAIEnvironment = {}
MOAIEnvironment.OS_BRAND_IOS = "iOS"
MOAIEnvironment.OS_BRAND_ANDROID = "Android"
function MOAIEnvironment.getOSBrand()
  return "unknown"
end
function MOAIEnvironment.getUDID()
  return "00000000"
end
return MOAIEnvironment
