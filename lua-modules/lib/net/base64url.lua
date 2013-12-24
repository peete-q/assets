local _M = {}
function _M.encode(text)
  return MOAIDataBuffer.base64Encode(text):gsub("[+]", "-"):gsub("/", "_"):gsub("=", "%%3D")
end
function _M.decode(text)
  return MOAIDataBuffer.base64Decode(text:gsub("%%3D", "="):gsub("_", "/"):gsub("-", "+"))
end
return _M
