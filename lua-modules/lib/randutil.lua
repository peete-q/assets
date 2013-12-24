local _M = {}
function _M:new(seed)
end
function _M.randomseed(seed, n)
  math.randomseed(seed or _M.seed_timelo())
  n = n or 3
  for i = 1, n do
    math.random()
  end
end
function _M.seed_timelo()
  return tonumber(tostring(os.time()):reverse():sub(1, 6))
end
return _M
