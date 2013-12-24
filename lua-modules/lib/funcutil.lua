local _M = {}
function _M.debugstr(f)
  local t = debug.getinfo(f)
  return string.format("%s:%s%s:%d", t.what, t.namewhat or "", t.source, t.linedefined)
end
return _M
