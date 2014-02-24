require("moai.compat")
local resource = require("resource")
local util = require("util")
local device = require("device")
local memory = require("memory")
local color = require("color")
local url = require("url")
local MOAIScissorRect = MOAIScissorRect
local MOAIEaseType = MOAIEaseType
local MOAITextBox = MOAITextBox
local MOAIFont = MOAIFont
local MOAIProp2D = MOAIProp2D
local MOAIAnim = MOAIAnim
local MOAITimer = MOAITimer
local MOAISimpleShader = MOAISimpleShader
local MOAIGfxQuad2D = MOAIGfxQuad2D
local MOAILayer2D = MOAILayer2D
local MOAIViewport = MOAIViewport
local MOAIPartition = MOAIPartition
local MOAIInputMgr = MOAIInputMgr
local MOAITouchSensor = MOAITouchSensor
local MOAIGfxDevice = MOAIGfxDevice
local MOAIColor = MOAIColor
local MOAISim = MOAISim
local MOAIMesh = MOAIMesh
local MOAIVertexBuffer = MOAIVertexBuffer
local MOAIVertexFormat = MOAIVertexFormat
local MOAIParticleEmitter = MOAIParticleEmitter
local MOAIParticleState = MOAIParticleState
local MOAIParticleSystem = MOAIParticleSystem
local MOAIParticlePlugin = MOAIParticlePlugin
local MOAIParticleTimedEmitter = MOAIParticleTimedEmitter
local MOAIPexPlugin = MOAIPexPlugin
local MOAI_VERSION = MOAI_VERSION
local MOAI_VERSION_1_0 = MOAI_VERSION_1_0
local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat
local clock = os.clock
local ipairs = ipairs
local pairs = pairs
local error = error
local type = type
local assert = assert
local setmetatable = setmetatable
local getmetatable = getmetatable
local tonumber = tonumber
local tostring = tostring
local print = print
local string = string
local printf = printf
local getfenv = getfenv
local resource = resource
local device = device
local nilify = util.nilify
local breakstr = util.breakstr
local file = file
local util = util
local dofile = dofile
local math = math
local math_floor = math.floor
local memory = memory
local pcall = pcall
local debug_ui = os.getenv("DEBUG_UI") or false
module(...)
local layers = {}
local captureElement, focusElement, touchFilterCallback, defaultTouchCallback, defaultKeyCallback
local ui_TOUCH_DOWN = MOAITouchSensor.TOUCH_DOWN
local ui_TOUCH_MOVE = MOAITouchSensor.TOUCH_MOVE
local ui_TOUCH_UP = MOAITouchSensor.TOUCH_UP
local ui_TOUCH_CANCEL = MOAITouchSensor.TOUCH_CANCEL
local ui_TOUCH_ONE = 0

local ui_getLayoutSize = function(self)
	local uiparent = self
	while uiparent ~= nil do
		if uiparent._uilayoutsize ~= nil then
			return uiparent._uilayoutsize
		end
		uiparent = uiparent._uiparent
	end
end

local ui_fireEvent = function(self, eventName, ...)
	local fn = self[eventName]
	if fn ~= nil then
		fn(self, ...)
	end
end

local function ui_setLayer(self, layer)
	if self._uilayer == layer then
		return
	end
	if layer ~= nil then
		layer:insertProp(self)
		if self._uilayer ~= self then
			self._uilayer = layer
		end
		if self.elements ~= nil then
			for k, v in pairs(self.elements) do
				ui_setLayer(v, layer)
			end
		end
		ui_fireEvent(self, "onLayerChanged", layer)
	elseif self._uilayer ~= nil then
		self._uilayer:removeProp(self)
		if captureElement == self then
			captureElement = nil
		end
		if self._uilayer ~= self then
			self._uilayer = nil
		end
		if self.elements ~= nil then
			for k, v in pairs(self.elements) do
				ui_setLayer(v, nil)
			end
		end
		ui_fireEvent(self, "onLayerChanged", nil)
	end
end

local function ui_unparentChild(child)
	ui_setLayer(child, nil)
	child._uiparent = nil
	child:setParent(nil)
end

local function ui_add(self, child)
	assert(child ~= nil, "Child must not be null")
	assert(child._uilayer == nil or child._uilayer ~= child, "Nested viewports not supported")
	if child._uiparent ~= nil then
		if child._uiparent == self then
			return
		end
		child._uiparent:remove(child)
	end
	if self.elements == nil then
		self.elements = {}
	end
	table_insert(self.elements, child)
	child:setParent(self)
	child._uiparent = self
	ui_setLayer(child, self._uilayer)
	if child._uilayoutsize ~= nil then
		local uilayoutsize = ui_getLayoutSize(self)
		if uilayoutsize ~= nil then
			child:setLayoutSize(uilayoutsize.width, uilayoutsize.height)
		else
			error("No parent layout size")
		end
	end
	return child
end

local function ui_removeAll(self, fullClear)
	if self.elements ~= nil then
		for k, v in pairs(self.elements) do
			ui_unparentChild(v)
			if fullClear then
				ui_removeAll(v)
			end
			self.elements[k] = nil
		end
		self.elements = nil
	end
	if self._pagemap ~= nil then
		for k, v in pairs(self._pagemap) do
			ui_unparentChild(v)
			if fullClear then
				ui_removeAll(v)
			end
			self._pagemap[k] = nil
		end
		self._pagemap = nil
	end
end

local function ui_remove(self, child, fullClear)
	if child == nil then
		if self._uiparent ~= nil then
			return ui_remove(self._uiparent, self)
		end
		return nil
	end
	if child._uiparent ~= self then
		return nil
	end
	if self.elements ~= nil then
		for k, v in pairs(self.elements) do
			if v == child then
				ui_unparentChild(child)
				if fullClear then
					ui_removeAll(child)
				end
				table_remove(self.elements, k)
				if #self.elements == 0 then
					self.elements = nil
				end
				return k
			end
		end
	end
	return nil
end

local function ui_setAnchor(self, dir, x, y)
	self._uianchor = dir
	local uilayoutsize = self._uilayer:getLayoutSize()
	local diffX = math_floor(uilayoutsize.width / 2)
	local diffY = math_floor(uilayoutsize.height / 2)
	if dir:find("T") then
		y = y + diffY
	elseif dir:find("B") then
		y = y - diffY
	end
	if dir:find("L") then
		x = x - diffX
	elseif dir:find("R") then
		x = x + diffX
	end
	self:setLoc(x, y)
end

local function ui_setLayoutSize(self, w, h)
	assert(not w or not nil, "Bad layout size")
	local uilayoutsize = self._uilayoutsize or {width = 0, height = 0}
	if self.elements and (uilayoutsize.width ~= w or uilayoutsize.height ~= h) then
		local diffX = math_floor((w - uilayoutsize.width) / 2)
		local diffY = math_floor((h - uilayoutsize.height) / 2)
		for i, e in pairs(self.elements) do
			local uianchor = e._uianchor
			if uianchor ~= nil then
				local x, y = e:getLoc()
				if uianchor:find("T") then
					y = y + diffY
				elseif uianchor:find("B") then
					y = y - diffY
				end
				if uianchor:find("L") then
					x = x - diffX
				elseif uianchor:find("R") then
					x = x + diffX
				end
				e:setLoc(x, y)
			end
		end
	end
	self._uilayoutsize = {width = w, height = h}
end

local function ui_new(o)
	assert(type(o) == "userdata" and getmetatable(o) ~= nil, "Improper use of ui_new")
	o.add = ui_add
	o.setLayer = ui_setLayer
	o.remove = ui_remove
	o.removeAll = ui_removeAll
	o.setAnchor = ui_setAnchor
	return o
end

local function ui_parseShader(colorstr)
	if colorstr ~= nil and type(colorstr) == "string" then
		return resource.shader(colorstr)
	elseif colorstr ~= nil and type(colorstr) == "userdata" then
		return colorstr
	end
	return nil
end

local function ui_tostring(o)
	local t = {}
	table_insert(t, tostring(o))
	if o ~= nil then
		if type(o) == "function" then
			table_insert(t, tostring(o))
		else
			table_insert(t, " \"")
			table_insert(t, tostring(o._uiname))
			table_insert(t, "\" [")
			if o._uilayer then
				if o._uilayer._uiname then
					table_insert(t, o._uilayer._uiname .. " ")
				end
				table_insert(t, tostring(o._uilayer))
				local p = o._uilayer:getPartition()
				if p then
					table_insert(t, " [" .. tostring(p) .. "]")
				end
			end
			table_insert(t, "]")
		end
	end
	return table_concat(t, "")
end

local touchEventName = {
	[ui_TOUCH_DOWN] = "TOUCH_DOWN",
	[ui_TOUCH_MOVE] = "TOUCH_MOVE",
	[ui_TOUCH_UP] = "TOUCH_UP",
	[ui_TOUCH_CANCEL] = "TOUCH_CANCEL"
}
local TOUCH_HANDLER_MAPPING = {
	[ui_TOUCH_DOWN] = "onTouchDown",
	[ui_TOUCH_MOVE] = "onTouchMove",
	[ui_TOUCH_UP] = "onTouchUp"
}
local function processTouch(fn, elem, eventType, touchIdx, x, y, tapCount)
	local fntype = type(fn)
	if fntype == "boolean" or fntype == "nil" then
		return fn
	elseif fntype == "table" then
		fn = fn[TOUCH_HANDLER_MAPPING[eventType]]
		if fn ~= nil then
			return fn(elem, touchIdx, x, y, tapCount)
		end
		return nil
	elseif fntype == "function" then
		return fn(elem, eventType, touchIdx, x, y, tapCount)
	else
		error("invalid touch handler: " .. tostring(fn))
	end
end

local filterFence = false
local touchLastX, touchLastY
local function onTouch(eventType, touchIdx, x, y, tapCount)
	local wx, wy
	if debug_ui then
		printf("%s[%s]: %s,%s", tostring(touchEventName[eventType] or tostring(eventType)), tostring(touchIdx), tostring(x), tostring(y))
	end
	local handled = false
	if touchFilterCallback ~= nil then
		if filterFence then
			if debug_ui then
				printf("\tskipping recursive filter")
			end
		else
			filterFence = true
			if debug_ui then
				printf("\tcalling filter: " .. tostring(touchFilterCallback))
			end
			local success, result = pcall(touchFilterCallback, eventType, touchIdx, x, y, tapCount)
			filterFence = false
			if success then
				if result then
					if debug_ui then
						printf("\thandled: " .. tostring(result))
					end
					return
				end
			else
				print("ERROR: error in touch filter: " .. tostring(result))
			end
		end
	end
	if eventType == ui_TOUCH_CANCEL then
	else
		if eventType == ui_TOUCH_MOVE then
			if touchLastX == x and touchLastY == y then
				return handled
			end
			touchLastX = x
			touchLastY = y
		elseif eventType == ui_TOUCH_UP then
			touchLastX = nil
			touchLastY = nil
		end
		local elem = captureElement
		if elem ~= nil then
			if type(elem) == "function" then
				if debug_ui then
					print("\tcapture fn: " .. tostring(elem))
				end
				handled = elem(eventType, touchIdx, x, y, tapCount)
				if not handled and defaultTouchCallback ~= nil then
					local success, result = pcall(defaultTouchCallback, eventType, touchIdx, x, y, tapCount)
					if success and result then
						handled = true
					end
				end
				if debug_ui then
					print("\t\thandled: " .. tostring(handled))
				end
				return handled
			end
			if elem._uilayer ~= nil then
				if debug_ui then
					print("\tcapture elem: " .. ui_tostring(elem))
				end
				while elem ~= nil do
					local fn = elem.handleTouch
					if fn ~= nil then
						local mx, my = x, y
						if x ~= nil and y ~= nil then
							local wx, wy = elem._uilayer:wndToWorld(x, y)
							mx, my = elem:worldToModel(wx, wy)
						end
						local success, result = pcall(processTouch, fn, elem, eventType, touchIdx, mx, my, tapCount)
						if success then
							if result then
								if debug_ui then
									print("\t\thandled = true")
								end
								handled = true
								break
							end
						else
							print("ERROR: " .. tostring(result))
							return nil, result
						end
					end
					
					elem = elem._uiparent
					if debug_ui then
						print("\t\tparent: " .. ui_tostring(elem))
					end
						-- print("warning: Clearing captured element because it is offscreen: " .. ui_tostring(elem))
						-- captureElement = nil
				end
			end
		else
			for i = #layers, 1, -1 do
				local layer = layers[i]
				if x ~= nil and y ~= nil then
					wx, wy = layer:wndToWorld(x, y)
				end
				if debug_ui then
					print("\tlayer " .. ui_tostring(layer))
				end
				local partition = layer:getPartition()
				if partition then
					local elemList = partition:propListForPoint(wx, wy)
					if elemList ~= nil then
						if debug_ui then
							print("\telemlist[" .. tostring(partition) .. "] = " .. util.tostr(elemList))
						end
						while not handled and #elemList > 0 do
							local lastPriority, fn, fnElemIdx, fnElem
							for i = #elemList, 1, -1 do
								local elem = elemList[i]
								local priority = elem:getPriority()
								if lastPriority == nil or lastPriority <= priority then
									if debug_ui then
										print("\t\telem " .. ui_tostring(elem))
									end
									while elem ~= nil do
										local touch = elem.handleTouch
										if touch ~= nil then
											lastPriority = priority
											fn = touch
											fnElemIdx = i
											fnElem = elem
											break
										end
										elem = elem._uiparent
										if debug_ui then
											print("\t\t\tparent " .. ui_tostring(elem))
										end
									end
								end
							end
							if fn == nil then
								break
							end
							local mx, my = fnElem:worldToModel(wx, wy)
							local success, result = pcall(processTouch, fn, fnElem, eventType, touchIdx, mx, my, tapCount)
							if success then
								if result then
									handled = true
									if debug_ui then
										print("\t\t\thandled: " .. tostring(handled))
									end
								else
									table_remove(elemList, fnElemIdx)
								end
							else
								print("ERROR: " .. tostring(result))
								return nil, result
							end
						end
					end
				end
				if handled or layer.handled then
					break
				end
			end
		end
		if not handled and defaultTouchCallback ~= nil then
			handled = defaultTouchCallback(eventType, touchIdx, x, y, tapCount)
		end
	end
	return handled
end

local mouseX = 0
local mouseY = 0
local mouseIsDown = false
local mouseTapCount = 0
local mouseDownTime
local function onMouseUpdate(x, y)
	mouseX = x
	mouseY = y
	if mouseIsDown then
		onTouch(ui_TOUCH_MOVE, ui_TOUCH_ONE, mouseX, mouseY, 1)
	end
end

local function onMouseLeft(down)
	mouseIsDown = down
	if down then
		do
			local t = clock()
			local dt = t - (mouseDownTime or t)
			if mouseDownTime == nil or dt > 0.285 then
				mouseTapCount = 1
			else
				mouseTapCount = mouseTapCount + 1
			end
			mouseDownTime = t
			onTouch(ui_TOUCH_DOWN, ui_TOUCH_ONE, mouseX, mouseY, mouseTapCount)
		end
	else
		onTouch(ui_TOUCH_UP, ui_TOUCH_ONE, mouseX, mouseY, mouseTapCount)
	end
end

KEY_BACKSPACE = 8
KEY_RETURN = 13
local function onKeyboard(key, down)
	local handled = false
	if focusElement ~= nil then
		local fn = focusElement.handleKey
		if fn ~= nil then
			handled = fn(key, down)
		end
	end
	if not handled and defaultKeyCallback ~= nil then
		handled = defaultKeyCallback(key, down)
	end
	return handled
end

function init(defaultInputHandler, defaultKeyHandler)
	defaultTouchCallback = defaultInputHandler
	defaultKeyCallback = defaultKeyHandler
	if MOAIInputMgr.device.pointer ~= nil then
		MOAIInputMgr.device.pointer:setCallback(onMouseUpdate)
	end
	if MOAIInputMgr.device.mouseLeft ~= nil then
		MOAIInputMgr.device.mouseLeft:setCallback(onMouseLeft)
	end
	if MOAIInputMgr.device.touch ~= nil then
		MOAIInputMgr.device.touch:setCallback(onTouch)
	end
	if MOAIInputMgr.device.keyboard ~= nil then
		MOAIInputMgr.device.keyboard:setCallback(onKeyboard)
	end
	layers = {}
	captureElement = nil
end

function inputShutdown()
	defaultTouchCallback = nil
	defaultKeyCallback = nil
	if MOAIInputMgr.device.pointer ~= nil then
		MOAIInputMgr.device.pointer:setCallback(nil)
	end
	if MOAIInputMgr.device.mouseLeft ~= nil then
		MOAIInputMgr.device.mouseLeft:setCallback(nil)
	end
	if MOAIInputMgr.device.touch ~= nil then
		MOAIInputMgr.device.touch:setCallback(nil)
	end
	if MOAIInputMgr.device.keyboard ~= nil then
		MOAIInputMgr.device.keyboard:setCallback(nil)
	end
end

function shutdown()
	inputShutdown()
	for i = 1, #layers do
		layers[i]:clear()
	end
	layers = {}
end

function injectTouch(eventType, touchIdx, x, y, tapCount)
	return onTouch(eventType, touchIdx, x, y, tapCount)
end

function setTouchFilter(touchFilter)
	touchFilterCallback = touchFilter
end

function setDefaultTouchCallback(defaultInputHandler)
	defaultTouchCallback = defaultInputHandler
end

function setDefaultKeyCallback(defaultKeyHandler)
	defaultKeyCallback = defaultKeyHandler
end

function hierarchystring(elem)
	local t = {}
	local e = elem
	while e do
		table_insert(t, ui_tostring(e))
		e = e._uiparent
	end
	return table_concat(t, [[

	]])
end

function dispatchTouch(e, eventType, touchIdx, x, y, tapCount)
	local handler = e[TOUCH_HANDLER_MAPPING[eventType]]
	if handler ~= nil then
		return handler(e, touchIdx, x, y, tapCount)
	end
end

function capture(e, ifEqualToE)
	if captureElement == ifEqualToE or ifEqualToE == nil then
		captureElement = e
	end
end

function getCaptureElement()
	return captureElement
end

function focus(e)
	focusElement = e
end

function treeCheck(x, y, elem)
	local layer = elem._uilayer
	if layer == nil then
		return false
	end
	local wx, wy = elem:modelToWorld(x, y)
	local elemList = layer:getPartition():propListForPoint(wx, wy)
	if elemList then
		for i, e in ipairs(elemList) do
			local temp = e
			while temp ~= nil do
				if temp == elem then
					return true
				end
				temp = temp._uiparent
			end
		end
	end
	return false
end

new = ui_new
TOUCH_DOWN = ui_TOUCH_DOWN
TOUCH_MOVE = ui_TOUCH_MOVE
TOUCH_UP = ui_TOUCH_UP
TOUCH_CANCEL = ui_TOUCH_CANCEL
TOUCH_ONE = ui_TOUCH_ONE
DRAG_THRESHOLD = 8
local function ui_get_moai_mt(o)
	return getmetatable(getmetatable(o))
end

Layer = {}
local function ui_Layer_clear(self)
	ui_removeAll(self, true)
	local mt = ui_get_moai_mt(self)
	mt.clear(self)
end

local function ui_Layer_setViewport(self, vp)
	self._uidata.viewport = vp
	local mt = ui_get_moai_mt(self)
	mt.setViewport(self, vp)
end

local ui_Layer_getViewport = function(self)
	return self._uidata.viewport
end

function Layer.new(viewport, scale)
	if viewport == nil or type(viewport) == "table" then
		do
			local left = 0
			local top = 0
			local right = device.width
			local bottom = device.height
			if viewport ~= nil then
				if viewport.left ~= nil then
					left = viewport.left
				end
				if viewport.top ~= nil then
					top = viewport.top
				end
				if viewport.right ~= nil then
					right = viewport.right
				end
				if viewport.bottom ~= nil then
					bottom = viewport.bottom
				end
			end
			viewport = MOAIViewport.new()
			viewport:setSize(left, top, right, bottom)
			if scale then
				viewport:setScale(right - left, bottom - top)
			else
				viewport:setScale(0, 0)
			end
		end
	elseif type(viewport) ~= "userdata" then
		error("Invalid viewport: " .. tostring(viewport))
	end
	local o = ui_new(MOAILayer2D.new())
	o._uidata = {}
	setmetatable(o._uidata, {__mode = "k"})
	o._uidata.viewport = viewport
	o:setViewport(viewport)
	o._uilayer = o
	o.clear = ui_Layer_clear
	o.setViewport = ui_Layer_setViewport
	o.getViewport = ui_Layer_getViewport
	o.getLayoutSize = ui_getLayoutSize
	o.setLayoutSize = ui_setLayoutSize
	o:setLayoutSize(device.width, device.height)
	table_insert(layers, o)
	MOAISim.pushRenderPass(o)
	return o
end

Group = {}
function Group.new()
	local o = ui_new(MOAIProp2D.new())
	o.getLayoutSize = ui_getLayoutSize
	o.setLayoutSize = ui_setLayoutSize
	return o
end

TextBox = {}
TextBox.LEFT = "left"
TextBox.CENTER = "center"
TextBox.RIGHT = "right"
local function TextBox_setColorVerPreMOAI1(self, color)
	if color ~= nil then
		self._textbox:setShader(ui_parseShader(color))
	end
end

local TextBox_seekColor = function(self, r, g, b, a, t, easetype)
	local action, shadowAction
	action = self._textbox:seekColor(r, g, b, a, t, easetype)
	if self._shadow ~= nil then
		shadowAction = self._shadow:seekColor(0, 0, 0, 0.5 * (a or 1), t, easetype)
		action:addChild(shadowAction)
	end
	return action
end

local TextBox_setColor = function(self, r, g, b, a)
	if self._shadow ~= nil then
		self._shadow:setColor(0, 0, 0, 0.5 * (a or 1))
	end
	self._textbox:setColor(r, g, b, a)
end

local TextBox_getSize = function(self)
	if not self or not self._width or not self._height then
		return nil
	end
	return self._width, self._height
end

local TextBox_setShadowOffset = function(self, xOffset, yOffset)
	self._shadow:setLoc(xOffset, yOffset)
end

local function TextBox_setString(self, str, recalcBounds)
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

local TextBox_getStringBounds = function(self, index, size)
	return self._textbox:getStringBounds(index, size)
end

function TextBox.new(str, font, color, justify, width, height, shadow)
	local o = ui_new(MOAIProp2D.new())
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
	justify = string.lower(justify or "center")
	local textbox = ui_new(MOAITextBox.new())
	textbox:setFont(font)
	if justify == "left" then
		textbox:setAlignment(MOAITextBox.LEFT_JUSTIFY)
	elseif justify == "right" then
		textbox:setAlignment(MOAITextBox.RIGHT_JUSTIFY)
	else
		textbox:setAlignment(MOAITextBox.CENTER_JUSTIFY)
	end
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
	o.getSize = TextBox_getSize
	textbox:setScl(1, -1)
	if color ~= nil then
		textbox:setShader(ui_parseShader(color))
	end
	if shadow then
		local shadow = ui_new(MOAITextBox.new())
		shadow:setFont(font)
		if justify == "left" then
			shadow:setAlignment(MOAITextBox.LEFT_JUSTIFY)
		elseif justify == "right" then
			shadow:setAlignment(MOAITextBox.RIGHT_JUSTIFY)
		else
			shadow:setAlignment(MOAITextBox.CENTER_JUSTIFY)
		end
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
		o.setColor = TextBox_setColorVerPreMOAI1
	else
		o.setColor = TextBox_setColor
	end
	o.seekColor = TextBox_seekColor
	o.getStringBounds = TextBox_getStringBounds
	o.setString = TextBox_setString
	o.setShadowOffset = TextBox_setShadowOffset
	return o
end

Image = {}
local Image_getSize = function(self)
	if not self or not self._deck or not self._deck.getSize then
		return nil
	end
	local w, h = self._deck:getSize(self.deckLayer)
	local x, y = self:getScl()
	return w * x, h * y
end

local function Image_setImage(self, imageName)
	if not imageName then
		self:setDeck(nil)
		self._deck = nil
		return
	end
	local imageName, queryStr = breakstr(imageName, "?")
	local deckName, layerName = breakstr(imageName, "#")
	local deck = resource.deck(deckName)
	self:setDeck(deck)
	if layerName ~= nil then
		self:setIndex(deck:indexOf(layerName))
		self.deckLayer = layerName
	end
	self.deckIndex = deck:indexOf(layerName)
	self:setScl(1, 1)
	self:setRot(0)
	self:setLoc(0, 0)
	self:setColor(1, 1, 1, 1)
	if queryStr ~= nil then
		local q = url.parse_query(queryStr)
		if q.scl ~= nil then
			local x, y = breakstr(q.scl, ",")
			self:setScl(tonumber(x), tonumber(y))
		end
		if q.rot ~= nil then
			local rot = tonumber(q.rot)
			self:setRot(rot)
		end
		if q.pri ~= nil then
			local pri = tonumber(q.pri)
			self:setPriority(pri)
		end
		if q.loc ~= nil then
			local x, y = breakstr(q.loc, ",")
			self:setLoc(tonumber(x), tonumber(y))
		end
		if q.alpha ~= nil then
			self:setColor(1, 1, 1, tonumber(q.alpha))
		end
	end
	self._deck = deck
end

function Image.new(imageName)
	local o = ui_new(MOAIProp2D.new())
	local deck
	if type(imageName) == "userdata" then
		deck = MOAIGfxQuad2D.new()
		do
			local tex = imageName
			deck:setTexture(tex)
			local w, h = tex:getSize()
			deck:setRect(-w / 2, -h / 2, w / 2, h / 2)
			o:setDeck(deck)
		end
	else
		local queryStr
		imageName, queryStr = breakstr(imageName, "?")
		local deckName, layerName = breakstr(imageName, "#")
		deck = resource.deck(deckName)
		o:setDeck(deck)
		if layerName ~= nil then
			o:setIndex(deck:indexOf(layerName))
			o.deckLayer = layerName
		end
		o.deckIndex = deck:indexOf(layerName)
		o:setScl(1, 1)
		o:setRot(0)
		o:setLoc(0, 0)
		o:setColor(1, 1, 1, 1)
		if queryStr ~= nil then
			local q = url.parse_query(queryStr)
			if q.scl ~= nil then
				local x, y = breakstr(q.scl, ",")
				o:setScl(tonumber(x), tonumber(y))
			end
			if q.rot ~= nil then
				local rot = tonumber(q.rot)
				o:setRot(rot)
			end
			if q.pri ~= nil then
				local pri = tonumber(q.pri)
				o:setPriority(pri)
			end
			if q.loc ~= nil then
				local x, y = breakstr(q.loc, ",")
				o:setLoc(tonumber(x), tonumber(y))
			end
			if q.alpha ~= nil then
				o:setColor(1, 1, 1, tonumber(q.alpha))
			end
		end
	end
	o._deck = deck
	o.getSize = Image_getSize
	o.setImage = Image_setImage
	return o
end

Anim = {}
local Anim_defaultCallback = function(self)
	if self._uiparent then
		self._uiparent:remove(self)
		if self._anim ~= nil then
			self._anim:stop()
			self._anim = nil
		end
		if self._animProp ~= nil then
			self.remove(self._animProp)
			self._animProp = nil
		end
	end
end

local function Anim_play(self, animName, callback, looping)
	if self._anim ~= nil then
		self._anim:stop()
		self._anim:clear()
		self._anim = nil
	end
	if self._animProp ~= nil then
		self.remove(self._animProp)
		self._animProp = nil
	end
	if not looping and callback == nil then
		callback = Anim_defaultCallback
	end
	if not animName or not self._deck or not self._deck._animCurves then
		return nil
	end
	local curve = self._deck._animCurves[animName]
	if not curve then
		return nil
	end
	local anim = MOAIAnim.new()
	if self._deck.type == "tweendeck" then
		do
			local consts = self._deck._animConsts[animName]
			local curLink = 1
			self._animProp = ui_new(MOAIProp2D.new())
			self._animProp:setDeck(self._deck)
			self:add(self._animProp)
			anim:reserveLinks(self._deck._numCurves[animName])
			for animType, entry in pairs(curve) do
				anim:setLink(curLink, entry, self._animProp, animType)
				if animType == MOAIColor.ATTR_A_COL then
					anim:setLink(curLink + 1, entry, self._animProp, MOAIColor.ATTR_R_COL)
					anim:setLink(curLink + 2, entry, self._animProp, MOAIColor.ATTR_G_COL)
					anim:setLink(curLink + 3, entry, self._animProp, MOAIColor.ATTR_B_COL)
					curLink = curLink + 3
				end
				curLink = curLink + 1
			end
			for animType, entry in pairs(consts) do
				if animType == "id" then
					self._animProp:setIndex(entry)
				elseif animType == "x" then
					do
						local x, y = self:getLoc()
						self._animProp:setLoc(entry, y)
					end
				elseif animType == "y" then
					do
						local x = self:getLoc()
						self._animProp:setLoc(x, entry)
					end
				elseif animType == "r" then
					self._animProp:setRot(entry)
				elseif animType == "xs" then
					do
						local x, y = self:getScl()
						self._animProp:setScl(entry, y)
					end
				elseif animType == "ys" then
					do
						local x = self:getScl()
						self._animProp:setScl(x, entry)
					end
				elseif animType == "a" then
					self._animProp:setColor(entry, entry, entry, entry)
				end
			end
		end
	else
		anim:reserveLinks(1)
		anim:setLink(1, curve, self, MOAIProp2D.ATTR_INDEX)
	end
	if looping then
		anim:setMode(MOAITimer.LOOP)
	else
		anim:setListener(MOAITimer.EVENT_TIMER_LOOP, function()
			callback(self)
		end)
	end
	self._anim = anim
	return anim:start()
end

local function Anim_loop(self, animName)
	return Anim_play(self, animName, nil, true)
end

local Anim_stop = function(self)
	if self._anim ~= nil then
		self._anim:stop()
		self._anim = nil
	end
	if self._animProp ~= nil then
		self.remove(self._animProp)
		self._animProp = nil
	end
end

function Anim.new(imageName)
	local o = Image.new(imageName)
	o.play = Anim_play
	o.loop = Anim_loop
	o.stop = Anim_stop
	return o
end

PageView = {}
local function PageView_showPage(self, page)
	if self.currentPageName == page then
		return
	end
	if self._pagemap[self.currentPageName] then
		ui_unparentChild(self._pagemap[self.currentPageName])
	end
	self.currentPageName = page
	if page ~= nil and self._pagemap then
		local elem = self._pagemap[page]
		if elem ~= nil then
			self:add(elem)
		end
	end
end

local function PageView_setPage(self, page, child)
	assert(page ~= nil, "PageView:setPage(page, child, page), page must not be nil")
	if self.currentPageName == page then
		self:showPage(nil)
	end
	self._pagemap[page] = child
	if self.currentPageName == nil then
		self:showPage(page)
	end
end

function PageView.new(pages)
	local o = ui_new(MOAIProp2D.new())
	assert(pages == nil or type(pages) == "table", "pages must be a table or nil")
	o._pagemap = {}
	o.currentPageName = nil
	o.showPage = PageView_showPage
	o.setPage = PageView_setPage
	if pages ~= nil then
		for k, v in pairs(pages) do
			o:setPage(k, v)
		end
	end
	return o
end

Button = {}
local function Button_handleTouch(self, eventType, touchIdx, x, y, tapCount)
	if eventType == ui_TOUCH_UP then
		capture(nil)
		self:showPage("up")
		self._isdown = nil
		self:onClick()
	elseif eventType == ui_TOUCH_DOWN then
		if not self._isDown then
			self:showPage("down")
			self._isdown = true
			capture(self)
			if self.onPress then
				self:onPress()
			end
		end
	elseif eventType == ui_TOUCH_MOVE and touchIdx == ui_TOUCH_ONE then
		if self._isdown and treeCheck(x, y, self) then
			self:showPage("down")
		else
			self:showPage("up")
			self._isdown = nil
		end
	end
	return true
end

local function defaultClickCallback(self)
	printf("CLICK!")
end

local function _MakePage(imageOrPage)
	if type(imageOrPage) == "string" then
		return Image.new(imageOrPage)
	elseif type(imageOrPage) == "userdata" then
		return imageOrPage
	else
		error("Invalid page type: " .. type(imageOrPage))
	end
end

function Button.new(up, down)
	local o = PageView.new()
	o._up = _MakePage(up)
	o._down = _MakePage(down or up)
	o:setPage("up", o._up)
	o:setPage("down", o._down)
	o.handleTouch = Button_handleTouch
	o.onClick = defaultClickCallback
	o.setPriority = Button.setPriority
	return o
end

function Button:setPriority(priority)
	self._up:setPriority(priority)
	self._down:setPriority(priority)
end

Switch = {}
function Switch_handleClick(self)
	self.isOn = not self.isOn
	if self.isOn then
		self._up:setImage(self._onUp)
		self._down:setImage(self._onDown)
		if self.onSwitchOn then
			self:onSwitchOn()
		end
	else
		self._up:setImage(self._offUp)
		self._down:setImage(self._offDown)
		if self.onSwitchOff then
			self:onSwitchOff()
		end
	end
	if self.onSwitch then
		self:onSwitch()
	end
end

function Switch.new(onUp, onDown, offUp, offDown)
	local o = Button.new(onUp, onDown)
	o.onClick = Switch_handleClick
	o.isOn = true
	o._onUp = onUp
	o._onDown = onDown
	o._offUp = offUp
	o._offDown = offDown
	return o
end

ProgressBar = {}
function ProgressBar.new(imageName)
	local o = Image.new(imageName)
	o._scissor = MOAIScissorRect.new()
	local w, h = o:getSize()
	o._scissor:setRect(-w / 2, -h / 2, w / 2, h / 2)
	o._scissor:setParent(o)
	o._scissor:setLoc(-w - 1, 0)
	o:setScissorRect(o._scissor)
	o.setProgress = ProgressBar.setProgress
	o.seekProgress = ProgressBar.seekProgress
	return o
end

function ProgressBar:setProgress(value, length)
	self._value = value
	local x = value * self._width
	self._scissor:setLoc(x, 0)
end

function ProgressBar:seekProgress(value, length, mode)
	self._value = value
	return self._scissor:seekLoc(0, 0, length, mode or MOAIEaseType.LINEAR)
end

DropList = {}
DropList.VERTICAL = "vertical"
DropList.HORIZONTAL = "horizontal"

function DropList.handleTouchV(self, eventType, touchIdx, x, y, tapCount)
	local root = self._uiparent._uiparent
	if eventType == ui_TOUCH_UP then
		capture(nil)
		if not root._scrolling then
			if self.onClick then
				self:onClick()
			end
		else
			if root._velocityY then
				root._velocityY = root._velocityY + root._diffY
			else
				root._velocityY = root._diffY
			end
			if not root._scrollAction then
				root._scrollAction = AS:run(function(dt)
					local x, y = root._items:getLoc()
					local newY = y - root._velocityY
					root._items:setLoc(0, root:clampItemY(newY))
					root._velocityY = root._velocityY + -root._velocityY * dt * 0.03 * 132
					if math.abs(root._velocityY) < 1 then
						root._scrollAction:stop()
						root._scrollAction = nil
					end
				end)
			end
		end
		root._scrolling = nil
	elseif eventType == ui_TOUCH_DOWN then
		capture(self)
		root._lastY = y
		root._diffY = 0
	elseif eventType == ui_TOUCH_MOVE and touchIdx == ui_TOUCH_ONE then
		root._scrolling = true
		root._diffY = root._lastY - y
		root._lastY = y
		if not root._scrollAction then
			local x, y = root:worldToModel(x, y)
			root._items:setLoc(0, root:clampItemY(y))
		end
	end
	return true
end

function DropList.new(w, h, direction)
	local self = ui.new(MOAIProp2D.new())
	self._scissor = MOAIScissorRect.new()
	self._scissor:setRect(-w / 2, -h / 2, w / 2, h / 2)
	self._scissor:setParent(self)
	self._items = self:add(ui.new(MOAIProp2D.new()))
	if direction == DropList.VERTICAL then
		self.handleItemTouch = DropList.handleTouchV
		self.addItem = DropList.addItemV
		self.removeItem = DropList.removeItemV
	else
		self.handleItemTouch = DropList.handleTouchH
		self.addItem = DropList.addItemH
		self.removeItem = DropList.removeItemH
	end
	self.addItem = DropList.addItem
	self.removeItem = DropList.removeItem
	self.getItemCount = DropList.getItemCount
	return self
end

function DropList:addItemV(o, offsetX, offsetY)
	offsetX = offsetX or 0
	offsetY = offsetY or 0
	local w, h = o:getSize()
	offsetY = offsetY - h / 2
	self._offsetY = offsetY
	if self:getItemCount() > 0 then
		local prev = self.elements[self:getItemCount() - 1]
		local w, h = prev:getSize()
		local x, y = prev:getLoc()
		y = y - h / 2
		offsetY = offsetY - y
	end
	self._items:add(o)
	o:setLoc(offsetX, offsetY)
	o:setScissorRect(self._scissor)
	o.handleTouch = self.handleItemTouch
	return o
end

function DropList:removeItemV(o, span, mode)
	local index = self._items:remove(o)
	if index then
		o:setScissorRect(nil)
		for i = index, self:getItemCount() do
			v:moveLoc(0, self._offsetY, span, mode)
		end
		return index
	end
end

function DropList:getItemCount()
	if not self._items.elements then
		return 0
	end
	return #self._items.elements
end

function DropList:clampItemY(y)
	if y < 0 or self:getItemCount() == 0 then
		return 0
	end
	local last = self._items.elements[self:getItemCount()]
	local lx, ly = last:getLoc()
	return math.min(y, math.abs(ly))
end

PickBox = {}
local function PickBox_setColor(self, color)
	if color ~= nil then
		self:setShader(ui_parseShader(color))
	end
end

local function PickBox_handleTouch(self, eventType, touchIdx, x, y, tapCount)
	if eventType == ui_TOUCH_UP then
		capture(nil)
		if self._isdown and self._inside then
			self:onClick(tapCount)
		end
		self._isdown = nil
		self._inside = nil
	elseif eventType == ui_TOUCH_DOWN then
		self._inside = true
		self._isdown = true
		capture(self)
	elseif eventType == ui_TOUCH_MOVE and touchIdx == ui_TOUCH_ONE and self._isdown then
		self._inside = treeCheck(x, y, self)
	end
	return true
end

function PickBox.new(width, height, colorstr)
	local o = ui_new(MOAIProp2D.new())
	if colorstr == nil then
		do
			local d = MOAIGfxQuad2D.new()
			d:setRect(-width / 2, -height / 2, width / 2, height / 2)
			o:setDeck(d)
		end
	else
		local fmt = MOAIVertexFormat.new()
		if MOAI_VERSION >= MOAI_VERSION_1_0 then
			fmt:declareCoord(1, MOAIVertexFormat.GL_FLOAT, 2)
		else
			fmt:declareCoord(MOAIVertexFormat.GL_FLOAT, 2)
		end
		local vbo = MOAIVertexBuffer.new()
		vbo:setPenWidth(1)
		vbo:setFormat(fmt)
		vbo:reserveVerts(5)
		vbo:setPrimType(MOAIVertexBuffer.GL_TRIANGLE_FAN)
		local w2 = width / 2
		local h2 = height / 2
		vbo:writeFloat(-w2, -h2)
		vbo:writeFloat(-w2, h2)
		vbo:writeFloat(w2, h2)
		vbo:writeFloat(w2, -h2)
		vbo:writeFloat(-w2, -h2)
		vbo:bless()
		local mesh = MOAIMesh.new()
		mesh:setVertexBuffer(vbo)
		o:setDeck(mesh)
		o:setShader(ui_parseShader(colorstr))
		o.setColor = PickBox_setColor
	end
	o.handleTouch = PickBox_handleTouch
	o.onClick = defaultClickCallback
	return o
end

ParticleSystem = {}
function ParticleSystem.new(particleName)
	local o
	if string.find(particleName, ".pex") ~= nil then
		do
			local texture, emitter
			if MOAIPexPlugin then
				do
					local plugin = resource.pexparticle(particleName)
					local maxParticles = plugin:getMaxParticles()
					local blendsrc, blenddst = plugin:getBlendMode()
					local minLifespan, maxLifespan = plugin:getLifespan()
					local duration = plugin:getDuration()
					local xMin, yMin, xMax, yMax = plugin:getRect()
					o = ui_new(MOAIParticleSystem.new())
					o._duration = duration
					o._lifespan = maxLifespan
					o:reserveParticles(maxParticles, plugin:getSize())
					o:reserveSprites(maxParticles)
					o:reserveStates(1)
					o:setBlendMode(blendsrc, blenddst)
					local state = MOAIParticleState.new()
					state:setTerm(minLifespan, maxLifespan)
					state:setPexPlugin(plugin)
					o:setState(1, state)
					texture = plugin:getTextureName()
					emitter = MOAIParticleTimedEmitter.new()
					emitter:setLoc(0, 0)
					emitter:setSystem(o)
					emitter:setEmission(plugin:getEmission())
					emitter:setFrequency(plugin:getFrequency())
					emitter:setRect(xMin, yMin, xMax, yMax)
				end
			else
				o, emitter, texture = MOAIParticlePlugin.loadExternal(particleName)
				o = ui_new(o)
			end
			local tex = resource.deck(texture)
			tex:setRect(-0.5, -0.5, 0.5, 0.5)
			o:setDeck(tex)
			emitter = ui_new(emitter)
			o:add(emitter)
			local emitters = {}
			emitters[1] = emitter
			o.emitters = emitters
		end
	else
		o = dofile(resource.path.resolvepath(particleName))
	end
	o:setIgnoreLocalTransform(true)
	o.startSystem = ParticleSystem.startSystem
	o.stopEmitters = ParticleSystem.stopEmitters
	o.stopSystem = ParticleSystem.stopSystem
	o.surgeSystem = ParticleSystem.surgeSystem
	o.updateSystem = ParticleSystem.updateSystem
	o.handleTouch = false
	return o
end

function ParticleSystem:startSystem(noEmitters)
	self:start()
	if not noEmitters then
		for k, v in pairs(self.emitters) do
			v:start()
		end
	end
end

function ParticleSystem:stopEmitters()
	for k, v in pairs(self.emitters) do
		v:stop()
	end
end

function ParticleSystem:stopSystem()
	self:stop()
	self:stopEmitters()
end

function ParticleSystem:surgeSystem(val)
	for k, v in pairs(self.emitters) do
		v:surge(val)
	end
end

function ParticleSystem:updateSystem()
	self:forceUpdate()
	for k, v in pairs(self.emitters) do
		v:forceUpdate()
	end
end

RadialImage = {}
function RadialImage.new(imageName)
	local self = ui_new(MOAIProp2D.new())
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
	vbo:setPrimType(MOAIVertexBuffer.GL_TRIANGLE_FAN)
	self.vbo = vbo
	local tex = resource.texture(imageName)
	local w, h = tex:getSize()
	self._xRadius = w / 2
	self._yRadius = h / 2
	local mesh = MOAIMesh.new()
	mesh:setTexture(tex)
	mesh:setVertexBuffer(vbo)
	self:setDeck(mesh)
	if MOAIGfxDevice.isProgrammable() then
		self:setShader(resource.shader("xyuv"))
	end
	self.angleIncrement = math.pi / 8
	self.setArc = RadialImage.setArc
	self:setArc(0, math.pi * 2)
	return self
end

local cos = math.cos
local sin = math.sin
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
	local uRad = 0.5
	local vRad = -0.5
	local a = startAngle
	for i = 1, n do
		dx = cos(a)
		dy = sin(a)
		vbo:writeFloat(dx * xRad, dy * yRad)
		vbo:writeFloat(0.5 + dx * uRad, 0.5 + dy * vRad)
		a = a + inc
	end
	dx = cos(endAngle)
	dy = sin(endAngle)
	vbo:writeFloat(dx * xRad, dy * yRad)
	vbo:writeFloat(0.5 + dx * uRad, 0.5 + dy * vRad)
	vbo:bless()
	self:forceUpdate()
end

FillBar = {}
local function FillBar_setColor(self, color)
	if color ~= nil then
		self:setShader(ui_parseShader(color))
	end
end

function FillBar.new(image, colorstr)
	local self = ui_new(MOAIProp2D.new())
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
	mesh:setVertexBuffer(vbo)
	self:setDeck(mesh)
	if colorstr then
		self:setShader(ui_parseShader(colorstr))
	elseif MOAIGfxDevice.isProgrammable() then
		self:setShader(resource.shader("xyuv"))
	end
	self.setFill = FillBar.setFill
	self.setColor = FillBar_setColor
	self:setFill(0, 1)
	return self
end

local cos = math.cos
local sin = math.sin
function FillBar:setFill(startVal, endVal)
	startVal = startVal or 0
	endVal = endVal or 1
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
	vbo:writeFloat(width * startWidth, halfHeight)
	vbo:writeFloat(startVal, 0)
	vbo:writeFloat(width * endWidth, -halfHeight)
	vbo:writeFloat(endVal, 1)
	vbo:writeFloat(width * endWidth, halfHeight)
	vbo:writeFloat(endVal, 0)
	vbo:bless()
	self:forceUpdate()
end

NinePatch = {}
local NinePatch_setSize = function(self, w, h)
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
	local self = ui_new(MOAIProp2D.new())
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

