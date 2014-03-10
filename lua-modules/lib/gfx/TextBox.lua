
local node = require "node"
local actionset = require "actionset"
local device = require "device"
local interpolate = require "interpolate"

local TextBox = {}

function TextBox.setColorVerPreMOAI1(self, color)
	if color ~= nil then
		self._textbox:setShader(ui_parseShader(color))
	end
end

function TextBox.seekColor(self, r, g, b, a, t, easetype)
	local action, shadowAction
	action = self._textbox:seekColor(r, g, b, a, t, easetype)
	if self._shadow ~= nil then
		shadowAction = self._shadow:seekColor(0, 0, 0, 0.5 * (a or 1), t, easetype)
		action:addChild(shadowAction)
	end
	return action
end

function TextBox.setColor(self, r, g, b, a)
	if self._shadow ~= nil then
		self._shadow:setColor(0, 0, 0, 0.5 * (a or 1))
	end
	self._textbox:setColor(r, g, b, a)
end

function TextBox.getSize(self)
	if not self or not self._width or not self._height then
		return nil
	end
	return self._width, self._height
end

function TextBox.setShadowOffset(self, xOffset, yOffset)
	self._shadow:setLoc(xOffset, yOffset)
end

function TextBox.setString(self, str, recalcBounds)
	self._textbox:setString(str)
	if self._shadow ~= nil then
		self._shadow:setString(str)
	end
	if recalcBounds then
		local dw = self._fixedWidth or device.ui_width
		local dh = self._fixedHeight or device.ui_height
		self._textbox:setRect(-dw / 2, -dh / 2, dw / 2, dh / 2)
		local xmin, ymin, xmax, ymax = self._textbox:getStringBounds(1, str:len())
		local width = self._fixedWidth or xmax - xmin + 5
		local height = self._fixedHeight or ymax - ymin + 5
		self._textbox:setRect(-width / 2, -height / 2, width / 2, height / 2)
		if self._shadow ~= nil then
			self._shadow:setRect(-width / 2, -height / 2, width / 2, height / 2)
		end
		self._width = width
		self._height = height
	end
end

function TextBox.getStringBounds(self, index, size)
	return self._textbox:getStringBounds(index, size)
end

function TextBox.setLineSpacing(self, height)
	self._textbox:setLineSpacing(height)
end

function TextBox.rollNumber(self, start, goal, length, prefix, suffix, cb)
	prefix = prefix or ""
	suffix = suffix or ""
	local runtime = 0
	local num, prevNum, action
	action = self._AS:run(function(dt)
		if runtime < length then
			runtime = runtime + dt
			if runtime > length then
				runtime = length
			end
			num = interpolate.lerp(start, goal, runtime / length)
			self:setString(prefix .. util.commasInNumbers(math.floor(num)) .. suffix)
			if prevNum ~= nil and math.floor(prevNum) ~= math.floor(num) then
				action.rollingNumber = num
				if cb then
					cb()
				end
			end
			prevNum = num
		else
			action:stop()
		end
	end)
	return action
end

function TextBox.setTime(self, secs)
	local s = math.fmod(secs, 60)
	local m = math.fmod(math.floor(secs / 60), 60)
	local h = math.floor(math.floor(secs / 60) / 60)
	local str = string.format("%02d:%02d:%02d", h, m, s)
	self:setString(str)
end

function TextBox.setSize(self, width, height)
	self._textbox:setRect(-width / 2, -height / 2, width / 2, height / 2)
	if self._shadow then
		self._shadow:setRect(-width / 2, -height / 2, width / 2, height / 2)
	end
end

function TextBox.new(str, font, color, justify, width, height, shadow)
	local o = node.new(MOAIProp2D.new())
	local face, size
	if type(font) == "table" then
		if font.face ~= nil then
			face = font.face
			size = tonumber(font.size)
		else
			face = font[1]
			size = tonumber(font[2])
		end
	elseif type(font) == "string" then
		face, size = font:match("([^@]+)@(%d+)$")
		if face == nil then
			face = "Arial"
		end
		if size == nil then
			size = 12
		else
			size = tonumber(size)
		end
	else
		face = "Arial"
		size = 12
	end
	font = resource.font(face, size)
	justify = justify or "MM"
	local textbox = node.new(MOAITextBox.new())
	textbox:setFont(font)
	local h, v
	if justify[1] == "L" then
		h = MOAITextBox.LEFT_JUSTIFY
	elseif justify[1] == "R" then
		h = MOAITextBox.RIGHT_JUSTIFY
	elseif justify[1] == "M" then
		h = MOAITextBox.CENTER_JUSTIFY
	end
	if justify[2] == "T" then
		v = MOAITextBox.LEFT_JUSTIFY
	elseif justify[2] == "B" then
		v = MOAITextBox.RIGHT_JUSTIFY
	elseif justify[2] == "M" then
		v = MOAITextBox.CENTER_JUSTIFY
	end
	textbox:setAlignment(h, v)
	if device.ui_assetrez == device.ASSET_MODE_HI then
		textbox:setTextSize(size)
	elseif device.ui_assetrez == device.ASSET_MODE_LO then
		textbox:setTextSize(size * 2)
	elseif device.ui_assetrez == device.ASSET_MODE_X_HI then
		textbox:setTextSize(size * 0.5)
	end
	textbox:setString(str)
	if width ~= nil then
		o._fixedWidth = width
	end
	if height ~= nil then
		o._fixedHeight = height
	end
	if width == nil or height == nil then
		local dw = width or device.ui_width
		local dh = height or device.ui_height
		textbox:setRect(-dw / 2, -dh / 2, dw / 2, dh / 2)
		local xmin, ymin, xmax, ymax = textbox:getStringBounds(1, str:len())
		if width == nil then
			width = xmax - xmin + 5
		end
		if height == nil then
			if ymax == nil or ymin == nil then
				height = 5
			else
				height = ymax - ymin + 5
			end
		end
	end
	textbox:setRect(-width / 2, -height / 2, width / 2, height / 2)
	o._width = width
	o._height = height
	o.getSize = TextBox.getSize
	textbox:setScl(1, -1)
	if color ~= nil then
		textbox:setShader(ui_parseShader(color))
	end
	if shadow then
		local shadow = node.new(MOAITextBox.new())
		shadow:setFont(font)
		shadow:setAlignment(h, v)
		if device.ui_assetrez == device.ASSET_MODE_HI then
			shadow:setTextSize(size)
		elseif device.ui_assetrez == device.ASSET_MODE_LO then
			shadow:setTextSize(size * 2)
		elseif device.ui_assetrez == device.ASSET_MODE_X_HI then
			shadow:setTextSize(size * 0.5)
		end
		shadow:setString(str)
		shadow:setRect(-width / 2, -height / 2, width / 2, height / 2)
		shadow:setScl(1, -1)
		shadow:setColor(0, 0, 0, 0.5)
		shadow:setLoc(2, -2)
		o:add(shadow)
		o._shadow = shadow
	end
	o:add(textbox)
	o._textbox = textbox
	if MOAI_VERSION < MOAI_VERSION_1_0 then
		o.setColor = TextBox.setColorVerPreMOAI1
	else
		o.setColor = TextBox.setColor
	end
	o.seekColor = TextBox.seekColor
	o.getStringBounds = TextBox.getStringBounds
	o.setString = TextBox.setString
	o.setShadowOffset = TextBox.setShadowOffset
	o.setLineSpacing = TextBox.setLineSpacing
	o.rollNumber = TextBox.rollNumber
	o.setTime = TextBox.setTime
	o.setSize = TextBox.setSize
	o._AS = actionset.new()
	return o
end

return TextBox