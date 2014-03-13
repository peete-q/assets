
local ui = require "ui"
local Unit = require "Unit"
local Battlefield = require "Battlefield"
local profile = require "UserProfile"
local node = require "node"
local Image = require "gfx.Image"
local FillBar = require "gfx.FillBar"

local blockOn = MOAIThread.blockOnAction

local GameStage = {}
local preparingSpace = 22
local skills = {
	light = function()
	end,
}

function GameStage:init()
end

function GameStage:load()
	self._uiRoot = node.new()
	self._sceneRoot = node.new()
	self._farRoot = node.new()
	self._nearRoot = node.new()
end

function GameStage:setupFleet()
	local x = 0
	local y = 11
	local space = 50
	for k, v in ipairs(profile.fleet) do
		local slot = self._uiRoot:add(ui.Button.new("slot.png"))
		slot:setAnchor("BL", x, y)
		slot.onClick = function()
			GameStage:addPreparing(v, slot:getLoc())
		end
		x = x + 50
	end
end

function GameStage:setupSpells()
end

function GameStage:updateProfile()
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
	local unit = self._uiRoot:add(Image.new("prepare-bg.png"))
	local prog = unit:add(FillBar.new("prepare-progress.png"))
	prog:setLoc(0, -30)
	local e = prog:seekFill(0, 0, 0, 1, props.prepareTime)
	self._preparings.index = self._preparings.index + 1
	self._preparings.n = self._preparings.n + 1
	local index = self._preparings.index
	e:setListener(MOAITimer.EVENT_STOP, function()
		self._preparings.n = self._preparings.n - 1
		self:removePreparing(index)
		self._battlefield:spawnPlayerUnit(props)
	end)
	local icon = self._uiRoot:add(Image.new(props.icon))
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
			o:moveLoc(-preparingSpace, 0, 0.5)
		end
	end
	self._preparings[index] = nil
end

function GameStage:getFreeLoc()
	if self._preparings.n >= profile.prepareMax then
		return
	end
	
	if self._preparings.n > 0 then
		return preparingSpace * self._preparings.n, 0
	end
	return 0, 0
end

function GameStage:update()
	self._battlefield:update()
	self._ticks = self._ticks + 1
	if self._ticks >= 10 then
		self._ticks = self._ticks - 10
		self._energy = math.min(profile.energyMax, self._energy + profile.energyRecover)
	end
end

local lastX, lastY
function GameStage:onDragBegin(touchIdx, x, y, tapCount)
	lastX = x
	lastY = y
	return true
end

function GameStage:onDragMove(touchIdx, x, y, tapCount)
	local diffX = x - lastX
	local diffY = y - lastY
	lastX = x
	lastY = y
	local x, y = camera:getLoc()
	x = math.clamp(x - diffX, self._xMin, self._xMax)
	y = math.clamp(y + diffY, self._yMin, self._yMax)
	camera:setLoc(x, y)
end

function GameStage:loadLevel(data)
	self._xMin = -data.width / 2
	self._xMax = data.width / 2
	self._yMin = -data.height / 2
	self._yMax = data.height / 2
	self._battlefield = Battlefield.new(sceneLayer)
	self._battlefield:addPlayerMontherShip(profile.motherShip, unpack(data.playerLoc))
	self._battlefield:addEnemyMotherShip(data.enemyMotherShip, unpack(data.enemyLoc))
end

function GameStage:open(stage, level)
	self._preparings = {
		n = 0,
		index = 0,
	}
	self._energy = profile.energyInitial
	self._ticks = 0
	
	if not self._loaded then
		self:load()
		self._loaded = true
	end
	
	farLayer:add(self._farRoot)
	nearLayer:add(self._nearRoot)
	sceneLayer:add(self._sceneRoot)
	uiLayer:add(self._uiRoot)
	
	ui.defaultTouchHandler = self
end

function GameStage:close()
	self._battlefield:destroy()
	self._battlefield = nil
	
	farLayer:remove(self._farRoot)
	nearLayer:remove(self._nearRoot)
	sceneLayer:remove(self._sceneRoot)
	uiLayer:remove(self._uiRoot)
	
	ui.defaultTouchHandler = nil
end

return GameStage