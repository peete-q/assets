local compat = require("moai.compat")
local resource = require("resource")
local math2d = require("math2d")
local interpolate = require("interpolate")
local metatable = require("metatable")
local _M = {}
_M.__index = M
local floor = math.floor
local table_insert = table.insert
local table_remove = table.remove
local length = math2d.length
local distance = math2d.distance
local normalize = math2d.normalize
local atan2 = math.atan2
local unpack = unpack
local shader
local function nth_point(points, n)
  local k = (n - 1) * 2 + 1
  return unpack(points, k, k + 1)
end
function _M.new(points, color)
  if points ~= nil then
    if type(points) ~= "table" then
      error("invalid points table")
    end
    for i = 1, #points do
      if type(points[i]) ~= "number" then
        error("table must be numbers only ({x1,y1,x2,y2,...})")
      end
    end
  end
  local self = metatable.copyinto(MOAIProp2D.new(), _M)
  self.minSegmentLength = 20
  self.penWidth = 1
  self.closed = false
  if points == nil then
    self.points = {}
  else
    self.points = points
  end
  local fmt = MOAIVertexFormat.new()
  if MOAI_VERSION >= MOAI_VERSION_1_0 then
    fmt:declareCoord(1, MOAIVertexFormat.GL_FLOAT, 2)
  else
    fmt:declareCoord(MOAIVertexFormat.GL_FLOAT, 2)
  end
  local vbo = MOAIVertexBuffer.new()
  vbo:setFormat(fmt)
  self.vbo = vbo
  local mesh = MOAIMesh.new()
  mesh:setPrimType(MOAIMesh.GL_LINE_STRIP)
  mesh:setVertexBuffer(vbo)
  self.mesh = mesh
  self:setDeck(mesh)
  if MOAIGfxDevice.isProgrammable() then
    if color then
      self:setShader(resource.shader(color))
    else
      self:setShader(resource.shader("white"))
    end
  end
  self:update()
  return self
end
function _M:clear(update)
  self.points = {}
  if update then
    self:update()
  end
  self.distances = nil
  self.closed = false
  return self
end
function _M:append(x, y, update)
  local self_points = self.points
  local minLength = self.minSegmentLength
  local k = #self_points
  if minLength == nil or k < 4 then
    table_insert(self_points, x)
    table_insert(self_points, y)
  else
    local len = distance(unpack(self_points, k - 3, k))
    local maxPoints = self.maxPoints
    if maxPoints == nil or maxPoints > self:len() then
      if minLength > len then
        self_points[k - 1] = x
        self_points[k] = y
      else
        table_insert(self_points, x)
        table_insert(self_points, y)
      end
    end
  end
  if update then
    self:update()
  end
  self.distances = nil
  return self
end
function _M:get(n)
  return nth_point(self.points, n)
end
function _M:set(n, x, y, update)
  local k = (n - 1) * 2 + 1
  local self_points = self.points
  if k + 1 > #self_points then
    assert("appending via set() is not implemented")
  end
  self_points[k] = x
  self_points[k + 1] = y
  if update then
    self:update()
  end
  self.distances = nil
end
function _M:remove(n, update)
  if n == nil then
    n = self:len()
  end
  if n <= 0 then
    return
  end
  local k = (n - 1) * 2 + 1
  local self_points = self.points
  table_remove(self_points, k)
  table_remove(self_points, k)
  if update then
    self:update()
  end
  self.distances = nil
  return self
end
function _M:len()
  return floor(#self.points / 2)
end
function _M:distance()
  local self_points = self.points
  if #self_points <= 2 then
    return 0
  end
  local distances = self.distances
  if distances ~= nil then
    return distances[1]
  end
  distances = {}
  table_insert(distances, 0)
  self.distances = distances
  local total = 0
  local x0 = self_points[1]
  local y0 = self_points[2]
  for k = 3, #self_points, 2 do
    local x = self_points[k]
    local y = self_points[k + 1]
    local d = distance(x0, y0, x, y)
    table_insert(distances, d)
    total = total + d
    x0 = x
    y0 = y
  end
  if self.closed then
    local d = distance(x0, y0, self_points[1], self_points[2])
    table_insert(distances, d)
    total = total + d
  end
  distances[1] = total
  return total
end
function _M:update()
  local points = self.points
  self.distances = nil
  local vbo = self.vbo
  self.mesh:setPenWidth(self.penWidth or 1)
  local n = floor(#points / 2)
  if self.closed then
    n = n + 1
  end
  vbo:reserveVerts(n)
  vbo:reset()
  vbo:writeFloat(unpack(points))
  if self.closed then
    vbo:writeFloat(points[1], points[2])
  end
  vbo:bless()
  self:forceUpdate()
end
function _M:smooth(iter, weight)
  iter = iter or 3
  weight = weight or 3
  local w1 = 1 / (weight + 1)
  local w2 = weight / (weight + 1)
  local points
  local oldpoints = self.points
  if #oldpoints <= 4 then
    return
  end
  for it = 1, iter do
    points = {}
    local npx = oldpoints[1]
    local npy = oldpoints[2]
    table_insert(points, npx)
    table_insert(points, npy)
    for i = 3, #oldpoints, 2 do
      local px = npx
      local py = npy
      npx = oldpoints[i]
      npy = oldpoints[i + 1]
      table_insert(points, w2 * px + w1 * npx)
      table_insert(points, w2 * py + w1 * npy)
      table_insert(points, w1 * px + w2 * npx)
      table_insert(points, w1 * py + w2 * npy)
    end
    table_insert(points, oldpoints[#oldpoints - 1])
    table_insert(points, oldpoints[#oldpoints])
    oldpoints = points
  end
  self.points = points
  self.distances = nil
end
function _M:pointAt(dist)
  local self_points = self.points
  if #self_points == 2 then
    local x0 = self_points[1]
    local y0 = self_points[2]
    return x0, y0, nil, nil
  end
  local distances = self.distances
  if distances == nil then
    self:distance()
    distances = self.distances
  end
  local sign
  if self.closed then
    dist, sign = interpolate.loop(dist, distances[1])
  else
    dist, sign = interpolate.pingpong(dist, distances[1])
  end
  local i = 1
  local d = 0
  repeat
    i = i + 1
    dist = dist - d
    d = distances[i]
  until dist <= d
  local x0, y0 = nth_point(self_points, i - 1)
  local x1, y1
  if i * 2 > #self_points then
    x1, y1 = nth_point(self_points, 1)
  else
    x1, y1 = nth_point(self_points, i)
  end
  local dx = (x1 - x0) / d
  local dy = (y1 - y0) / d
  x0 = x0 + dx * dist
  y0 = y0 + dy * dist
  return x0, y0, dx * sign, dy * sign
end
function _M:advance(dist)
  local self_points = self.points
  if #self_points == 2 then
    local x0 = self_points[1]
    local y0 = self_points[2]
    return x0, y0, nil, nil
  end
  local x0 = self_points[1]
  local y0 = self_points[2]
  local dx, dy, d
  while dist > 0 and #self_points > 2 do
    local x = self_points[3]
    local y = self_points[4]
    dx, dy, d = normalize(x - x0, y - y0)
    if dist <= d then
      x0 = x0 + dx * dist
      y0 = y0 + dy * dist
      self_points[1] = x0
      self_points[2] = y0
      break
    end
    dist = dist - d
    table_remove(self_points, 1)
    table_remove(self_points, 1)
    x0 = x
    y0 = y
  end
  self:update()
  self.distances = nil
  return x0, y0, dx, dy
end
return _M
