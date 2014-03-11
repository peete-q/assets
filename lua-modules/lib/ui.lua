require("moai.compat")
require("base_ext")

local resource = require("resource")
local util = require("util")
local device = require("device")
local memory = require("memory")
local color = require("color")
local url = require("url")
local actionset = require("actionset")
local interpolate = require("interpolate")
local node = require("node")
local gfxutil = require("gfxutil")

local clock = os.clock

local ui = {
	debug_ui = os.getenv("DEBUG_UI"),
	
	TOUCH_DOWN = MOAITouchSensor.TOUCH_DOWN,
	TOUCH_MOVE = MOAITouchSensor.TOUCH_MOVE,
	TOUCH_UP = MOAITouchSensor.TOUCH_UP,
	TOUCH_CANCEL = MOAITouchSensor.TOUCH_CANCEL,
	TOUCH_ONE = 0,
	DRAG_THRESHOLD = 3,
	KEY_BACKSPACE = 8,
	KEY_RETURN = 13,
}

local layers = {}
local captureElement, focusElement, touchFilterCallback, defaultTouchCallback, defaultKeyCallback

local ui_AS = actionset.new()
local ui_new = node.new

local function ui_log(...)
	if ui.debug_ui then
		print("UI:", ...)
	end
end

local function ui_logf(...)
	if ui.debug_ui then
		print("UI:", string.format(...))
	end
end

local function ui_tostring(o)
	local t = {}
	table.insert(t, tostring(o))
	if o ~= nil then
		if type(o) == "function" then
			table.insert(t, tostring(o))
		else
			table.insert(t, " \"")
			table.insert(t, tostring(o._uiname))
			table.insert(t, "\" [")
			if o._layer then
				if o._layer._uiname then
					table.insert(t, o._layer._uiname .. " ")
				end
				table.insert(t, tostring(o._layer))
				local p = o._layer:getPartition()
				if p then
					table.insert(t, " [" .. tostring(p) .. "]")
				end
			end
			table.insert(t, "]")
		end
	end
	return table.concat(t, "")
end

local TOUCH_NAME_MAPPING = {
	[ui.TOUCH_DOWN] = "TOUCH_DOWN",
	[ui.TOUCH_MOVE] = "TOUCH_MOVE",
	[ui.TOUCH_UP] = "TOUCH_UP",
	[ui.TOUCH_CANCEL] = "TOUCH_CANCEL"
}
local TOUCH_EVENT_MAPPING = {
	[ui.TOUCH_DOWN] = "onTouchDown",
	[ui.TOUCH_MOVE] = "onTouchMove",
	[ui.TOUCH_UP] = "onTouchUp"
}

local function doTouch(fn, elem, eventType, touchIdx, x, y, tapCount)
	local fntype = type(fn)
	if fntype == "boolean" or fntype == "nil" then
		return fn
	elseif fntype == "table" then
		fn = fn[TOUCH_EVENT_MAPPING[eventType]]
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

local touchLastX, touchLastY
local function onTouch(eventType, touchIdx, x, y, tapCount)
	local handled = false
	if touchFilterCallback ~= nil then
		local success, result = pcall(touchFilterCallback, eventType, touchIdx, x, y, tapCount)
		if success then
			if result then
				return
			end
		else
			print("ERROR: error in touch filter: " .. tostring(result))
		end
	end
	if eventType == ui.TOUCH_CANCEL then
	else
		if eventType == ui.TOUCH_MOVE then
			if touchLastX == x and touchLastY == y then
				return handled
			end
			touchLastX = x
			touchLastY = y
		elseif eventType == ui.TOUCH_UP then
			touchLastX = nil
			touchLastY = nil
		end
		local elem = captureElement
		if elem ~= nil then
			if type(elem) == "function" then
				handled = elem(eventType, touchIdx, x, y, tapCount)
			elseif elem._layer ~= nil then
				while elem ~= nil do
					local fn = elem.handleTouch
					if fn ~= nil then
						local wx, wy = elem._layer:wndToWorld(x, y)
						local success, result = pcall(doTouch, fn, elem, eventType, touchIdx, wx, wy, tapCount)
						if success then
							if result then
								handled = true
								break
							end
						else
							print("ERROR: " .. tostring(result))
							return nil, result
						end
					end
					
					elem = elem._parent
				end
			end
		else
			for i = #layers, 1, -1 do
				ui_logf("pick layer %q", tostring(layers[i]._uiname))
				local layer = layers[i]
				local wx, wy = layer:wndToWorld(x, y)
				local partition = layer:getPartition()
				if partition then
					local elemList = {partition:propListForPoint(wx, wy)}
					if elemList ~= nil then
						while not handled and #elemList > 0 do
							local lastPriority, fn, fnElemIdx, fnElem
							for i = #elemList, 1, -1 do
								local elem = elemList[i]
								local priority = elem:getPriority()
								if lastPriority == nil or lastPriority <= priority then
									while elem ~= nil do
										local touch = elem.handleTouch
										if touch ~= nil then
											lastPriority = priority
											fn = touch
											fnElemIdx = i
											fnElem = elem
											break
										end
										elem = elem._parent
									end
								end
							end
							if fn == nil then
								break
							end
							local success, result = pcall(doTouch, fn, fnElem, eventType, touchIdx, wx, wy, tapCount)
							if success then
								if result then
									handled = true
								else
									table.remove(elemList, fnElemIdx)
								end
							else
								print("ERROR: " .. tostring(result))
								return nil, result
							end
						end
					end
				end
				if handled or layer.popuped then
					return true
				end
			end
		end
		if not handled and defaultTouchCallback ~= nil then
			if type(defaultTouchCallback) == "table" then
				fn = defaultTouchCallback[TOUCH_EVENT_MAPPING[eventType]]
				if fn then
					handled = fn(touchIdx, x, y, tapCount)
				end
			else
				handled = defaultTouchCallback(eventType, touchIdx, x, y, tapCount)
			end
		end
	end
	return handled
end

local function dragHappen(x1, y1, x2, y2)
	return math.abs(x1 - x2) > ui.DRAG_THRESHOLD or math.abs(y1 - y2) > ui.DRAG_THRESHOLD
end

function ui.handleTouch(self, eventType, touchIdx, x, y, tapCount)
	if eventType == ui.TOUCH_UP then
		ui.capture(nil)
		if self._isdragging then
			if self.onDragEnd then
				self:onDragEnd(touchIdx, x, y, tapCount)
			end
			self._isdragging = nil
		elseif self._isdown then
			if self.onTouchUp then
				self:onTouchUp()
			end
			self._isdown = nil
			if self.onClick then
				self:onClick(touchIdx, x, y, tapCount)
			end
		end
	elseif eventType == ui.TOUCH_DOWN then
		if not self._isDown then
			if self.onTouchDown then
				self:onTouchDown()
			end
			self._isdown = true
			self._downX = x
			self._downY = y
			ui.capture(self)
		end
	elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE then
		if dragHappen(self._downX, self._downY, x, y) then
			if self.onDragBegin then
				self._isdragging = self:onDragBegin(touchIdx, x, y, tapCount)
			end
		end
		if self._isdragging then
			if self.onDragMove then
				self:onDragMove(touchIdx, x, y, tapCount)
			end
		elseif self._isdown then
			if not ui.treeCheck(x, y, self) then
				if self.onTouchUp then
					self:onTouchUp()
				end
				self._isdown = nil
			end
		end
	end
	return true
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
		onTouch(ui.TOUCH_MOVE, ui.TOUCH_ONE, mouseX, mouseY, 1)
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
			onTouch(ui.TOUCH_DOWN, ui.TOUCH_ONE, mouseX, mouseY, mouseTapCount)
		end
	else
		onTouch(ui.TOUCH_UP, ui.TOUCH_ONE, mouseX, mouseY, mouseTapCount)
	end
end

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

function ui.init(defaultInputHandler, defaultKeyHandler)
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

function ui.shutdown()
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
	
	for i = 1, #layers do
		layers[i]:clear()
	end
	layers = {}
end

function ui.injectTouch(eventType, touchIdx, x, y, tapCount)
	return onTouch(eventType, touchIdx, x, y, tapCount)
end

function ui.setTouchFilter(touchFilter)
	touchFilterCallback = touchFilter
end

function ui.setDefaultTouchCallback(defaultInputHandler)
	defaultTouchCallback = defaultInputHandler
end

function ui.setDefaultKeyCallback(defaultKeyHandler)
	defaultKeyCallback = defaultKeyHandler
end

function ui.hierarchystring(elem)
	local t = {}
	local e = elem
	while e do
		table.insert(t, ui_tostring(e))
		e = e._parent
	end
	return table.concat(t, "\n")
end

function ui.capture(e, ifEqual)
	if captureElement == ifEqual or ifEqual == nil then
		captureElement = e
	end
end

function ui.getCaptureElement()
	return captureElement
end

function ui.focus(e)
	focusElement = e
end

function ui.treeCheck(x, y, elem)
	local layer = elem._layer
	if layer == nil then
		return false
	end
	local elemList = {layer:getPartition():propListForPoint(x, y)}
	if elemList then
		for i, e in ipairs(elemList) do
			local temp = e
			while temp ~= nil do
				if temp == elem then
					return true
				end
				temp = temp._parent
			end
		end
	end
	return false
end

function ui.removeLayer(o)
	local i = table.find(layers, o)
	if i then
		table.remove(layers, i)
	end
end

function ui.insertLayer(o, pos)
	ui.removeLayer(o)
	pos = pos or #layers + 1
	table.insert(layers, pos, o)
end

local Group = {}
function Group.new()
	local o = ui_new(MOAIProp2D.new())
	return o
end

local PageView = {}
local function PageView_showPage(self, page)
	if self.currPage == page then
		return
	end
	if self._pagemap[self.currPage] then
		self:remove(self._pagemap[self.currPage])
	end
	if self.currPage then
		local onShowPage = self.onShowPage[self.currPage]
		if onShowPage then
			onShowPage(self, false)
		end
	end
	self.currPage = page
	if page ~= nil and self._pagemap then
		local elem = self._pagemap[page]
		if elem ~= nil then
			self:add(elem)
		end
		local onShowPage = self.onShowPage[page]
		if onShowPage then
			onShowPage(self, true)
		end
	end
end

local function PageView_setPage(self, page, child)
	assert(page ~= nil, "page must not be nil")
	if self.currPage == page then
		self:showPage(nil)
	end
	self._pagemap[page] = child
	if self.currPage == nil then
		self:showPage(page)
	end
end

function PageView.new(pages)
	assert(pages == nil or type(pages) == "table", "pages must be a table or nil")
	local o = ui_new(MOAIProp2D.new())
	o._pagemap = {}
	o.currPage = nil
	o.showPage = PageView_showPage
	o.setPage = PageView_setPage
	if pages ~= nil then
		for k, v in pairs(pages) do
			o:setPage(k, v)
		end
	end
	o.onShowPage = {}
	return o
end

local Button = {}
local function Button_handleTouch(self, eventType, touchIdx, x, y, tapCount)
	if self._isDisable then
		return true
	end
	
	return ui.handleTouch(self, eventType, touchIdx, x, y, tapCount)
end

local function _MakePage(o)
	return gfxutil.parse(o)
end

local function Button_showPageUp(self)
	if self._downScl then
		self:setScl(1, 1)
	else
		self:showPage("up")
	end
end

local function Button_showPageDown(self)
	if self._downScl then
		self:setScl(self._downScl, self._downScl)
	else
		self:showPage("down")
	end
end

function Button.new(up, down, disable)
	local o = PageView.new()
	o._up = _MakePage(up)
	o:setPage("up", o._up)
	
	if type(down) == "number" then
		o._downScl = down
		down = up
	end
	o._down = _MakePage(down or up)
	o:setPage("down", o._down)
	
	if type(disable) == "number" then
		o._disableAlpha = disable
		disable = up
	end
	o._disable = _MakePage(disable or up)
	o:setPage("disable", o._disable)
	
	o.handleTouch = Button_handleTouch
	o.onTouchDown = Button_showPageDown
	o.onTouchUp = Button_showPageUp
	o.setPriority = Button.setPriority
	o.disable = Button.disable
	return o
end

function Button:disable(on)
	if on then
		if self._disableAlpha then
			self:setColor(1, 1, 1, self._disableAlpha)
		else
			self:showPage("disable")
		end
	else
		ui.capture(nil, self)
		if self._disableAlpha then
			self:setColor(1, 1, 1, 1)
		else
			self:showPage("up")
		end
		self._isdown = nil
	end
	self._isDisable = on
end

function Button:setPriority(priority)
	self._up:setPriority(priority)
	self._down:setPriority(priority)
	self._disable:setPriority(priority)
end

local Switch = {}
local function Switch_handleClick(self)
	self._status = self._status + 1
	if self._status > self._num then
		self._status = 1
	end
	self:turn(self._status)
	if self.onTurn then
		self:onTurn(self._status)
	end
end

local function Switch_handleTouchDown(self)
	self:showPage(self._status * 2)
end

local function Switch_handleTouchUp(self)
	self:showPage(self._status * 2 - 1)
end

function Switch.new(num, ...)
	local args = {...}
	local o = PageView.new()
	for k, v in pairs(args) do
		if type(v) == "number" then
			o.onShowPage = function(self, on)
				if on then
					self:setScl(v, v)
				else
					self:setScl(1, 1)
				end
			end
		else
			o:setPage(k, _MakePage(v))
		end
	end
	o._num = num
	o.handleTouch = ui.handleTouch
	o.onTouchDown = Switch_handleTouchDown
	o.onTouchUp = Switch_handleTouchUp
	o.onClick = Switch_handleClick
	o.turn = Switch.turn
	o:turn(1)
	return o
end

function Switch:turn(status)
	self._status = status
	self:showPage(status * 2 - 1)
end

local DropList = {}
DropList.VERTICAL = "vertical"
DropList.HORIZONTAL = "horizontal"
function DropList.handleTouchV(self, eventType, touchIdx, x, y, tapCount)
	local this = self._parent._parent
	if eventType == ui.TOUCH_UP then
		ui.capture(nil)
		if not this._scrolling then
			if self.onClick then
				self:onClick(touchIdx, x, y, tapCount)
			end
		else
			if this._velocityV then
				this._velocityV = this._velocityV + this._diffV
			else
				this._velocityV = this._diffV
			end
			if not this._scrollAction then
				this._scrollAction = ui_AS:wrap(function(dt)
					local x, y = this._root:getLoc()
					y = y + this._velocityV
					if 0 <= y and y <= (this:getItemCount() - 1) * this._space then
						this._root:setLoc(0, y)
						this._velocityV = this._velocityV + -this._velocityV * dt * 0.03 * device.dpi
					else
						this._velocityV = 0
					end
					if math.abs(this._velocityV) < 1 then
						this._scrollAction:stop()
						this._scrollAction = nil
					end
				end)
			end
		end
		this._scrolling = nil
	elseif eventType == ui.TOUCH_DOWN then
		ui.capture(self)
		this._lastV = y
		this._diffV = 0
	elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE then
		this._scrolling = true
		this._diffV = y - this._lastV
		this._lastV = y
		if not this._scrollAction then
			local x, y = this._root:getLoc()
			y = y + this._diffV
			if 0 <= y and y <= (this:getItemCount() - 1) * this._space then
				this._root:moveLoc(0, this._diffV)
			end
		end
	end
	return true
end

function DropList.handleTouchH(self, eventType, touchIdx, x, y, tapCount)
	local this = self._parent._parent
	if eventType == ui.TOUCH_UP then
		ui.capture(nil)
		if not this._scrolling then
			if self.onClick then
				self:onClick(touchIdx, x, y, tapCount)
			end
		else
			if this._velocityV then
				this._velocityV = this._velocityV + this._diffV
			else
				this._velocityV = this._diffV
			end
			if not this._scrollAction then
				this._scrollAction = ui_AS:wrap(function(dt)
					local x, y = this._root:getLoc()
					x = x + this._velocityV
					if 0 <= x and x <= (this:getItemCount() - 1) * this._space then
						this._root:setLoc(x, 0)
						this._velocityV = this._velocityV + -this._velocityV * dt * 0.03 * device.dpi
					else
						this._velocityV = 0
					end
					if math.abs(this._velocityV) < 1 then
						this._scrollAction:stop()
						this._scrollAction = nil
					end
				end)
			end
		end
		this._scrolling = nil
	elseif eventType == ui.TOUCH_DOWN then
		ui.capture(self)
		this._lastV = x
		this._diffV = 0
	elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE then
		this._scrolling = true
		this._diffV = x - this._lastV
		this._lastV = x
		if not this._scrollAction then
			local x, y = this._root:getLoc()
			x = x + this._diffV
			if 0 <= x and x <= (this:getItemCount() - 1) * this._space then
				this._root:moveLoc(this._diffV, 0)
			end
		end
	end
	return true
end

function DropList.new(w, h, space, direction)
	local self = ui_new(MOAIProp2D.new())
	self._scissor = MOAIScissorRect.new()
	self._scissor:setParent(self)
	self._root = self:add(ui_new(MOAIProp2D.new()))
	if direction == DropList.VERTICAL then
		self.handleItemTouch = DropList.handleTouchV
		self.addItem = DropList.addItemV
		self.removeItem = DropList.removeItemV
	else
		self.handleItemTouch = DropList.handleTouchH
		self.addItem = DropList.addItemH
		self.removeItem = DropList.removeItemH
	end
	self._space = space
	self.getSize = DropList.getSize
	self.setSize = DropList.setSize
	self.getItemCount = DropList.getItemCount
	self.clearItems = DropList.clearItems
	self:setSize(w, h)
	return self
end

function DropList:getSize()
	return unpack(self._size)
end

function DropList:setSize(w, h)
	self._size = {w, h}
	self._scissor:setRect(-w / 2, -h / 2, w / 2, h / 2)
end

function DropList:clearItems()
	self._root:removeAll()
end

function DropList:addItemV(o)
	local y = self._size[2] / 2 - self._space / 2 + self:getItemCount() * -self._space
	self._root:add(o)
	o:setLoc(0, y)
	o:setScissorRect(self._scissor)
	o.handleTouch = self.handleItemTouch
	return o
end

function DropList:removeItemV(o, span, mode)
	local index = self._root:remove(o)
	if index then
		o:setScissorRect(nil)
		for i = index, self:getItemCount() do
			v:moveLoc(0, self._space, span, mode)
		end
		self:getItemCount()
		return index
	end
end

function DropList:addItemH(o)
	local x = -self._size[1] / 2 + self._space / 2 + self:getItemCount() * self._space
	self._root:add(o)
	o:setLoc(x, 0)
	o:setScissorRect(self._scissor)
	o.handleTouch = self.handleItemTouch
	return o
end

function DropList:removeItemH(o, span, mode)
	local index = self._root:remove(o)
	if index then
		o:setScissorRect(nil)
		for i = index, self:getItemCount() do
			v:moveLoc(-self._space, 0, span, mode)
		end
		self:getItemCount()
		return index
	end
end

function DropList:getItemCount()
	return #self._root:getChildrenCount()
end

local PickBox = {}
function PickBox.handleTouch(self, eventType, touchIdx, x, y, tapCount)
	if eventType == ui.TOUCH_UP then
		ui.capture(nil)
		if self._isdown and self._inside then
			self:onClick(touchIdx, x, y, tapCount)
		end
		self._isdown = nil
		self._inside = nil
	elseif eventType == ui.TOUCH_DOWN then
		self._inside = true
		self._isdown = true
		ui.capture(self)
	elseif eventType == ui.TOUCH_MOVE and touchIdx == ui.TOUCH_ONE and self._isdown then
		self._inside = ui.treeCheck(x, y, self)
	end
	return true
end

function PickBox.new(width, height)
	local o = ui_new(MOAIProp2D.new())
	local d = MOAIGfxQuad2D.new()
	d:setRect(-width / 2, -height / 2, width / 2, height / 2)
	o:setDeck(d)
	o.handleTouch = PickBox.handleTouch
	return o
end

ui.Group = Group
ui.PageView = PageView
ui.Button = Button
ui.Switch = Switch
ui.DropList = DropList

return ui