local _M = {}
function _M.split(ver)
  local major, minor, patch = ver:match("%d+")
  if major == nil then
    major = 0
  end
  if minor == nil then
    minor = 0
  end
  if patch == nil then
    patch = 0
  end
  return major, minor, patch
end
function _M.numeric(ver)
  local major, minor, patch = _M.split(ver)
  return major * 1000000 + minor * 1000 + patch
end
return _M
