
local ui = require "ui.base"
local Unit = require "Unit"
local Scene = require "Scene"
local profile = require "UserProfile"

local blockOn = MOAIThread.blockOnAction

local GameStage = {
	width = 400,
	height = 400,
}
local _prepareQVSpace = 0
local _prepareQHSpace = 22

function GameStage:init(spaceStage)
end

function GameStage:load(onOkay)
	if self._root then
		uiLayer:add(self._root)
		return
	end
	self._root = uiLayer:add(ui.Group.new())
	self:setupSlots()
	self:open()
	if onOkay then
		onOkay(GameStage)
	end
end

function GameStage:setupSlots()
	local x = 0
	local y = 11
	local space = 50
	for k, v in ipairs(profile.slots) do
		local slot = self._root:add(ui.Button.new("slot-btn.png"))
		slot:setAnchor("BL", x, y)
		slot._args = {v.props, slot:getLoc()}
		slot.onClick = function()
			GameStage:addPreparing(unpack(slot._args))
		end
		x = x + 50
	end
end

function GameStage:setupSkills()
end

function GameStage:updateProfile()
end

function GameStage:open()
	self._scene = Scene.new(self.width, self.height, uiLayer)
	self._preparings = {
		n = 0,
		index = 0,
	}
	self._energy = profile.energyInitial
	self._ticks = 0
end

function GameStage:addPreparing(props, x, y)
	if props.cost > self._energy then
		return
	end
	local tx, ty = self:getFreeLoc()
	if not tx then
		return
	end
	
	self._energy = self._energy - props.cost
	local unit = self._root:add(ui.Image.new("prepare-bg.png"))
	local prog = unit:add(ui.ProgressBar.new("prepare-progress.png"))
	prog:setLoc(0, -30)
	local e = prog:seekProgress(1, props.prepareTime)
	self._preparings.index = self._preparings.index + 1
	self._preparings.n = self._preparings.n + 1
	local index = self._preparings.index
	e:setListener(MOAITimer.EVENT_STOP, function()
		self._preparings.n = self._preparings.n - 1
		self:removePreparing(index)
		self._scene:spawnPlayerUnit(props)
	end)
	local icon = self._root:add(ui.Image.new(props.icon))
	unit:setLoc(x, y)
	unit:seekLoc(tx, ty, 1)
	self._preparings[index] = unit
end

function GameStage:removePreparing(index)
	local unit = self._preparings[index]
	unit:remove()
	for i = index + 1, self._preparings.index do
		local o = self._preparings[i]
		if o then
			o:moveLoc(-_prepareQHSpace, 0, 0.5)
		end
	end
	self._preparings[index] = nil
end

function GameStage:getFreeLoc()
	if self._preparings.n >= profile.prepareMax then
		return
	end
	
	if self._preparings.n > 0 then
		return _prepareQHSpace * self._preparings.n, 0
	end
	return 0, 0
end

function GameStage:update()
	self._scene:update()
	self._ticks = self._ticks + 1
	if self._ticks >= 10 then
		self._ticks = _ticks - 10
		self._energy = math.min(profile.energyMax, self._energy + profile.energyRecover)
	end
end

function GameStage:close()
	uiLayer:remove(self._root)
end

return GameStage