
local node = require "node"

local Patch = {}

function Patch.new(image)
	local self = node.new(MOAIProp2D.new())
	local fmt = MOAIVertexFormat.new()
	fmt:declareCoord(1, MOAIVertexFormat.GL_FLOAT, 2)
	fmt:declareUV(2, MOAIVertexFormat.GL_FLOAT, 2)
	fmt:declareColor(3, MOAIVertexFormat.GL_UNSIGNED_BYTE)
		
	local vbo = MOAIVertexBuffer.new()
	vbo:setFormat(fmt)
	self.vbo = vbo
	local tex
	if type(image) == "string" then
		tex = resource.texture(image)
		do
			local w, h = tex:getSize()
			self._width = w
			self._height = h
		end
	elseif type(image) == "table" then
		self._width = image[1]
		self._height = image[2]
	end
	local mesh = MOAIMesh.new()
	if tex then
		mesh:setTexture(tex)
	end
	mesh:setPrimType(MOAIMesh.GL_TRIANGLE_STRIP)
	mesh:setVertexBuffer(vbo)
	self:setDeck(mesh)
	self._color = {1, 1, 1, 1}
	return self
end

return Patch