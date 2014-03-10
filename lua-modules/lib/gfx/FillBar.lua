
local Patch = require "gfx.Patch"
local actionset = require "actionset"
local interpolate = require "interpolate"

local FillBar = {}

function FillBar.new(image)
	local self = Patch.new(image)
	self.setFill = FillBar.setFill
	self.seekFill = FillBar.seekFill
	self.setSpin = FillBar.setSpin
	self.seekSpin = FillBar.seekSpin
	self.setColor = FillBar.setColor
	self:setFill(0, 1)
	self._AS = actionset.new()
	return self
end

function FillBar:setColor(...)
	self._color = {...}
	self:setFill(self._startVal, self._endVal)
end

function FillBar:setFill(startVal, endVal)
	startVal = startVal or 0
	endVal = endVal or 1
	self._startVal = startVal
	self._endVal = endVal
	local width = self._width
	local height = self._height
	local halfHeight = height / 2
	if startVal > endVal then
		startVal, endVal = endVal, startVal
	end
	local vbo = self.vbo
	vbo:reserveVerts(4)
	vbo:reset()
	local startWidth = startVal - 0.5
	local endWidth = endVal - 0.5
	vbo:writeFloat(width * startWidth, -halfHeight)
	vbo:writeFloat(startVal, 1)
	vbo:writeColor32(unpack(self._color))
	vbo:writeFloat(width * startWidth, halfHeight)
	vbo:writeFloat(startVal, 0)
	vbo:writeColor32(unpack(self._color))
	vbo:writeFloat(width * endWidth, -halfHeight)
	vbo:writeFloat(endVal, 1)
	vbo:writeColor32(unpack(self._color))
	vbo:writeFloat(width * endWidth, halfHeight)
	vbo:writeFloat(endVal, 0)
	vbo:writeColor32(unpack(self._color))
	vbo:bless()
	self:forceUpdate()
end

function FillBar:seekFill(startValLeft, startValRight, endValLeft, endValRight, length)
	local runtime = 0
	local leftNum, prevLeftNum, rightNum, prevRightNum, action
	action = self._AS:run(function(dt)
		if runtime < length then
			runtime = runtime + dt
			if runtime > length then
				runtime = length
			end
			leftNum = interpolate.lerp(startValLeft, endValLeft, runtime / length)
			rightNum = interpolate.lerp(startValRight, endValRight, runtime / length)
			self:setFill(leftNum, rightNum)
			prevLeftNum = leftNum
			prevRightNum = rightNum
		else
			action:stop()
		end
	end)
	return action
end

return FillBar