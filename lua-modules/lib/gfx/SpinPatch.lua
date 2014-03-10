
local Patch = require "gfx.Patch"
local actionset = require "actionset"
local interpolate = require "interpolate"

local SpinPatch = {}

function SpinPatch.new(image, color)
	local self = Patch.new(image, color)
	self.setSpin = SpinPatch.setSpin
	self.seekSpin = SpinPatch.seekSpin
	self.setColor = SpinPatch.setColor
	self:setSpin(0)
	self._AS = actionset.new()
	return self
end

function SpinPatch:setColor(...)
	self._color = {...}
	self:setSpin(self._spinVal)
end

function SpinPatch:setSpin(val)
	self._spinVal = val
	local w = self._width
	local h = self._height
	local vbo = self.vbo
	vbo:reserveVerts(4)
	vbo:reset()
	local cosv = math.cos(val)
	local sinv = math.sin(val)
	local x = -w / 2
	local y = -h / 2
	vbo:writeFloat(x * cosv - y * sinv, y * cosv + x * sinv)
	vbo:writeFloat(0, 1)
	vbo:writeColor32(unpack(self._color))
	local x = -w / 2
	local y = h / 2
	vbo:writeFloat(x * cosv - y * sinv, y * cosv + x * sinv)
	vbo:writeFloat(0, 0)
	vbo:writeColor32(unpack(self._color))
	local x = w / 2
	local y = -h / 2
	vbo:writeFloat(x * cosv - y * sinv, y * cosv + x * sinv)
	vbo:writeFloat(1, 1)
	vbo:writeColor32(unpack(self._color))
	local x = w / 2
	local y = h / 2
	vbo:writeFloat(x * cosv - y * sinv, y * cosv + x * sinv)
	vbo:writeFloat(1, 0)
	vbo:writeColor32(unpack(self._color))
	vbo:bless()
	self:forceUpdate()
end

function SpinPatch:seekSpin(startVal, endVal, length)
	local runtime = 0
	local val, action
	action = self._AS:run(function(dt)
		if runtime < length then
			runtime = runtime + dt
			if runtime > length then
				runtime = length
			end
			val = interpolate.lerp(startVal, endVal, runtime / length)
			self:setSpin(val)
		else
			action:stop()
		end
	end)
	return action
end

return SpinPatch