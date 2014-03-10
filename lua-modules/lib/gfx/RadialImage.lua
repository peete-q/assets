
local node = require "node"
local actionset = require "actionset"
local interpolate = require "interpolate"

local RadialImage = {}

function RadialImage.new(imageName)
	local self = node.new(MOAIProp2D.new())
	local fmt = MOAIVertexFormat.new()
	fmt:declareCoord(1, MOAIVertexFormat.GL_FLOAT, 2)
	fmt:declareUV(2, MOAIVertexFormat.GL_FLOAT, 2)
	fmt:declareColor(3, MOAIVertexFormat.GL_UNSIGNED_BYTE)
	
	local vbo = MOAIVertexBuffer.new()
	vbo:setFormat(fmt)
	self.vbo = vbo
	local tex = resource.texture(imageName)
	local w, h = tex:getSize()
	self._xRadius = w / 2
	self._yRadius = h / 2
	local mesh = MOAIMesh.new()
	mesh:setTexture(tex)
	mesh:setPrimType(MOAIMesh.GL_TRIANGLE_FAN)
	mesh:setVertexBuffer(vbo)
	self:setDeck(mesh)
	if MOAIGfxDevice.isProgrammable() then
		self:setShader(resource.shader("xyuv"))
	end
	self.angleIncrement = math.pi / 8
	self.setArc = RadialImage.setArc
	self.seekArc = RadialImage.seekArc
	self:setArc(0, math.pi * 2)
	self._AS = actionset.new()
	return self
end

function RadialImage:seekArc(startValLeft, startValRight, endValLeft, endValRight, length)
	local runtime = 0
	local leftNum, rightNum, action
	action = self._AS:run(function(dt)
		if runtime < length then
			runtime = runtime + dt
			if runtime > length then
				runtime = length
			end
			leftNum = interpolate.lerp(startValLeft, endValLeft, runtime / length)
			rightNum = interpolate.lerp(startValRight, endValRight, runtime / length)
			self:setArc(leftNum, rightNum)
		else
			action:stop()
		end
	end)
	return action
end

function RadialImage:setArc(startAngle, endAngle)
	local xRad = self._xRadius
	local yRad = self._yRadius
	if endAngle < startAngle then
		startAngle, endAngle = endAngle, startAngle
	end
	local span = endAngle - startAngle
	local inc = self.angleIncrement
	local dx, dy
	local n = math.floor(span / inc) + 1
	local vbo = self.vbo
	vbo:reserveVerts(n + 2)
	vbo:reset()
	vbo:writeFloat(0, 0)
	vbo:writeFloat(0.5, 0.5)
	vbo:writeColor32(1, 1, 1)
	local uRad = 0.5
	local vRad = -0.5
	local a = startAngle
	for i = 1, n do
		dx = math.cos(a)
		dy = sin(a)
		vbo:writeFloat(dx * xRad, dy * yRad)
		vbo:writeFloat(0.5 + dx * uRad, 0.5 + dy * vRad)
		vbo:writeColor32(1, 1, 1)
		a = a + inc
	end
	dx = math.cos(endAngle)
	dy = math.sin(endAngle)
	vbo:writeFloat(dx * xRad, dy * yRad)
	vbo:writeFloat(0.5 + dx * uRad, 0.5 + dy * vRad)
	vbo:writeColor32(1, 1, 1)
	vbo:bless()
	self:forceUpdate()
end

return RadialImage