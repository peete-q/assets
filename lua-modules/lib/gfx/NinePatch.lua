
local node = require "node"

local NinePatch = {}

local function NinePatch_setSize(self, w, h)
	local halfW = w / 2
	local halfH = h / 2
	local x0 = -halfW
	local x3 = halfW
	local x1 = x0 + self._borderL
	local x2 = x3 - self._borderR
	local y0 = halfH
	local y3 = -halfH
	local y1 = y0 - self._borderT
	local y2 = y3 + self._borderB
	local u0 = self._u0
	local u1 = self._u1
	local u2 = self._u2
	local u3 = self._u3
	local v0 = self._v0
	local v1 = self._v1
	local v2 = self._v2
	local v3 = self._v3
	local vbo = self.vbo
	vbo:reserveVerts(24)
	vbo:reset()
	vbo:writeFloat(x0, y0, u0, v0)
	vbo:writeFloat(x1, y0, u1, v0)
	vbo:writeFloat(x0, y1, u0, v1)
	vbo:writeFloat(x1, y1, u1, v1)
	vbo:writeFloat(x0, y2, u0, v2)
	vbo:writeFloat(x1, y2, u1, v2)
	vbo:writeFloat(x0, y3, u0, v3)
	vbo:writeFloat(x1, y3, u1, v3)
	vbo:writeFloat(x1, y3, u1, v3)
	vbo:writeFloat(x2, y3, u2, v3)
	vbo:writeFloat(x1, y2, u1, v2)
	vbo:writeFloat(x2, y2, u2, v2)
	vbo:writeFloat(x1, y1, u1, v1)
	vbo:writeFloat(x2, y1, u2, v1)
	vbo:writeFloat(x1, y0, u1, v0)
	vbo:writeFloat(x2, y0, u2, v0)
	vbo:writeFloat(x2, y0, u2, v0)
	vbo:writeFloat(x3, y0, u3, v0)
	vbo:writeFloat(x2, y1, u2, v1)
	vbo:writeFloat(x3, y1, u3, v1)
	vbo:writeFloat(x2, y2, u2, v2)
	vbo:writeFloat(x3, y2, u3, v2)
	vbo:writeFloat(x2, y3, u2, v3)
	vbo:writeFloat(x3, y3, u3, v3)
	vbo:bless()
	self:forceUpdate()
end

function NinePatch.new(opts, w, h)
	if type(opts) == "string" then
		local f = resource.path.resolvepath(opts)
		opts = dofile(f)
	end
	if type(opts) ~= "table" then
		error("invalid options for ninepatch: " .. tostring(opts))
	end
	local self = node.new(MOAIProp2D.new())
	local fmt = MOAIVertexFormat.new()
	if MOAI_VERSION >= MOAI_VERSION_1_0 then
		fmt:declareCoord(1, MOAIVertexFormat.GL_FLOAT, 2)
		fmt:declareUV(2, MOAIVertexFormat.GL_FLOAT, 2)
	else
		fmt:declareCoord(MOAIVertexFormat.GL_FLOAT, 2)
		fmt:declareUV(MOAIVertexFormat.GL_FLOAT, 2)
	end
	local vbo = MOAIVertexBuffer.new()
	vbo:setFormat(fmt)
	vbo:setPrimType(MOAIVertexBuffer.GL_TRIANGLE_STRIP)
	self.vbo = vbo
	local tex = resource.texture(opts.texture)
	local tw, th = tex:getSize()
	self._texWidth = tw
	self._texHeight = th
	self._borderL = opts.borderL
	self._borderR = opts.borderR
	self._borderT = opts.borderT
	self._borderB = opts.borderB
	self._u0 = 0
	self._u1 = self._borderL / tw
	self._u2 = (tw - self._borderR) / tw
	self._u3 = 1
	self._v0 = 0
	self._v1 = self._borderT / th
	self._v2 = (th - self._borderB) / th
	self._v3 = 1
	local mesh = MOAIMesh.new()
	mesh:setTexture(tex)
	mesh:setVertexBuffer(vbo)
	self:setDeck(mesh)
	if MOAIGfxDevice.isProgrammable() then
		self:setShader(resource.shader("xyuv"))
	end
	self.setSize = NinePatch_setSize
	if w ~= nil and h ~= nil then
		self:setSize(w, h)
	else
		self:setSize(tw, th)
	end
	return self
end

return NinePatch