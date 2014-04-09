
local actionset = require "actionset"

local function _calc_camera_shake(t)
	local strength = 0
	for driver, v in pairs(self._shakeFXs) do
		local n = driver(t)
		if n == nil then
			self._shakeFXs[driver] = nil
		else
			strength = strength + n
		end
	end
	return strength
end

local function _do_shake(dt, length)
	local strength = _calc_camera_shake(length)
	camera:addLoc(-self._shakeX, -self._shakeY)
	self._shakeX = (math.random() - 0.5) * strength
	self._shakeY = (math.random() - 0.5) * strength
	camera:addLoc(self._shakeX, self._shakeY)
end

function camera.new()
	local self = MOAICamera2D.new ()
	self._shakeFXs = {}
	self._shakeX = 0
	self._shakeY = 0
	self._AS = actionset.new()
	self._AS:run(_do_shake)
	self.shake = camera.shake
	return self
end

function camera:shake(strength, duration)
	if strength == nil then
		strength = 50
	end
	if duration == nil then
		duration = 1
	end
	
	local function fn(t)
		local a = t / duration
		if a > 1 then
			return nil
		end
		return strength - strength *(-math.pow(2, -10 * a) + 1)
	end
	self._shakeFXs[fn] = true
end
