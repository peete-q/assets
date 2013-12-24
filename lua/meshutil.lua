local TWO_PI = 2 * math.pi
local cos = math.cos
local sin = math.sin
local MOAIVertexFormat = MOAIVertexFormat
local MOAIVertexBuffer = MOAIVertexBuffer
local MOAIMesh = MOAIMesh
module(...)
function circle(radius, segments, originX, originY)
  segments = segments or 32
  originX = originX or 0
  originY = originY or 0
  local fmt = MOAIVertexFormat.new()
  fmt:declareCoord(MOAIVertexFormat.GL_FLOAT, 2)
  local vbo = MOAIVertexBuffer.new()
  vbo:setPenWidth(1)
  vbo:setFormat(fmt)
  vbo:reserveVerts(segments + 1)
  vbo:setPrimType(MOAIVertexBuffer.GL_LINE_STRIP)
  for i = 0, segments do
    local a = i / segments * TWO_PI
    vbo:writeFloat(cos(a) * radius + originX, sin(a) * radius + originY)
  end
  vbo:writeFloat(cos(0) * radius + originX, sin(0) * radius + originY)
  vbo:bless()
  local mesh = MOAIMesh.new()
  mesh:setVertexBuffer(vbo)
  return mesh, vbo
end
function linestrip(points, shader)
  local fmt = MOAIVertexFormat.new()
  fmt:declareCoord(MOAIVertexFormat.GL_FLOAT, 2)
  local vbo = MOAIVertexBuffer.new()
  vbo:setPenWidth(1)
  vbo:setFormat(fmt)
  vbo:reserveVerts(#points)
  vbo:setPrimType(MOAIVertexBuffer.GL_LINE_STRIP)
  local elem = points[1]
  if type(elem) == "table" then
    if elem.x ~= nil then
      for i = 1, #points do
        local p = points[i]
        vbo:writeFloat(p.x, p.y)
      end
    elseif elem[1] ~= nil then
      for i = 1, #points do
        local p = points[i]
        vbo:writeFloat(p[1], p[2])
      end
    end
  elseif type(elem) == "number" then
    for i = 1, #points, 2 do
      vbo:writeFloat(points[i], points[i + 1])
    end
  end
  vbo:bless()
  local mesh = MOAIMesh.new()
  mesh:setVertexBuffer(vbo)
  return mesh, vbo
end
