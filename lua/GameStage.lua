
local ui = require "ui"
local Unit = require "Unit"
local Scene = require "Scene"
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
		self._scene:spawnPlayerUnit(props)
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
	self._scene:update()
	self._ticks = self._ticks + 1
	if self._ticks >= 10 then
		self._ticks = self._ticks - 10
		self._energy = math.min(profile.energyMax, self._energy + profile.energyRecover)
	end
end

function GameStage:open(stage, level)
	self._width = level.width
	self._height = level.height
	self._scene = Scene.new(sceneLayer)
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
	
	ui.default = self
end

function GameStage:close()
	self._scene:destroy()
	self._scene = nil
	
	farLayer:remove(self._farRoot)
	nearLayer:remove(self._nearRoot)
	sceneLayer:remove(self._sceneRoot)
	uiLayer:remove(self._uiRoot)
	
	ui.default = nil
end

return GameStage