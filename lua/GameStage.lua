
local ui = require "ui"
local Unit = require "Unit"
local Battlefield = require "Battlefield"
local profile = require "UserProfile"
local node = require "node"
local device = require "device"
local timer = require "timer"
local Image = require "gfx.Image"
local FillBar = require "gfx.FillBar"
local TextBox = require "gfx.TextBox"

local blockOn = MOAIThread.blockOnAction

local FONT_SMALL = "normal@18"
local FONT_MIDDLE = "normal@24"
local BUTTON_IMAGE = {"button-normal.png", 1.1, 0.5}
local FONT_COLOR_LIGHT = {120/255, 255/255, 220/255}
local FONT_COLOR_GOLD = {255/255, 191/255, 7/255}

local GameStage = {}
local readySpace = 22
local spells = {
	light = function()
	end,
}

function GameStage:init()
end

function GameStage:initFleetSlots()
	local x = 50
	local y = 50
	local space = 80
	self._slots = {}
	for i = 1, 6 do
		local slot = self._uiRoot:add(ui.Button.new("slot.png"))
		slot:setAnchor("LB", x, y)
		self._slots[i] = slot
		x = x + space
	end
end

function GameStage:setupFleet()
	for i = 1, 6 do
		local slot = self._slots[i]
		local ship = profile.fleet[i]
		if ship then
			local o = slot:add(Image.new(ship.icon))
			o.handleTouch = ui.handleTouch
			o.onClick = function()
				GameStage:addReadyQ(ship, slot:getLoc())
			end
		end
	end
end

function GameStage:setupSpells()
end

function GameStage:updateProfile()
end

function GameStage:addReadyQ(props, x, y)
	if props.cost > self._energy then
		return
	end
	local tx, ty = self:getFreeLoc()
	if not tx then
		return
	end
	
	self._energy = self._energy - props.cost
	local box = self._uiRoot:add(Image.new("ready_box.png"))
	local bar = box:add(FillBar.new("ready_bar.png"))
	bar:setLoc(0, -30)
	local e = bar:seekFill(0, 0, 0, 1, props.readyTime)
	self._readyQ.index = self._readyQ.index + 1
	self._readyQ.n = self._readyQ.n + 1
	local index = self._readyQ.index
	e:setListener(MOAITimer.EVENT_STOP, function()
		self._readyQ.n = self._readyQ.n - 1
		self:removeReadyQ(index)
		local o = self._battlefield:spawnPlayerUnit(props)
		o:setTreePriority(3)
	end)
	local icon = box:add(Image.new(props.icon))
	box:setLoc(x, y)
	box:seekLoc(tx, ty, 1)
	self._readyQ[index] = box
end

function GameStage:removeReadyQ(index)
	local o = self._readyQ[index]
	o:remove()
	for i = index + 1, self._readyQ.index do
		local o = self._readyQ[i]
		if o then
			o:moveLoc(-readySpace, 0, 0.5)
		end
	end
	self._readyQ[index] = nil
end

function GameStage:getFreeLoc()
	if self._readyQ.n >= profile.readyMax then
		return
	end
	
	if self._readyQ.n > 0 then
		return readySpace * self._readyQ.n, 0
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

function GameStage:onClick(touchIdx, x, y, tapCount)
	local x, y = sceneLayer:wndToWorld(x, y)
	local o = self._battlefield:addUnit(profile.fleet[1], Unit.FORCE_PLAYER, x, y)
	o:move()
end

function GameStage:load()
	self._uiRoot = node.new()
	self._uiRoot:setLayoutSize(device.width, device.height)
	
	self._sceneRoot = node.new()
	self._farRoot = node.new()
	self._nearRoot = node.new()
	
	self:initStageBG()
	self:initFleetSlots()
	self:initUserPanel()
end

function GameStage:initStageBG()
	local bg = self._farRoot:add(node.new())
	local deck = MOAITileDeck2D.new()
	local tex = resource.texture("starfield.jpg")
	deck:setTexture(tex)
	local w, h = tex:getSize()
	deck:setSize(1, 1)
	deck:setRect (-0.5, 0.5, 0.5, -0.5)
	local grid = MOAIGrid.new ()
	grid:setSize(1, 1, w, h)
	grid:setRepeat ( true )
	grid:setRow(1, 1)
	bg:setDeck(deck)
	bg:setGrid(grid)
end

function GameStage:initUserPanel()
	self._userPanel = self._uiRoot:add(Image.new("user_panel_02.png"))
	local w, h = self._userPanel:getSize()
	self._userPanel:setAnchor("LT", w / 2, -h / 2)
	self._coinsNum = self._userPanel:add(TextBox.new("0", FONT_SMALL, nil, "MM", 60, 60))
	self._diamondsNum = self._userPanel:add(TextBox.new("0", FONT_SMALL, nil, "MM", 60, 60))
	self._expBar = self._userPanel:add(FillBar.new("exp-bar.png"))
	self._avatar = self._userPanel:add(Image.new("avatar.png"))
	
	self._expBar:setFill(0, 0)
	self._expBar:setLoc(5,-16)
	self._coinsNum:setLoc(150, 28)
	self._diamondsNum:setLoc(0, 28)
	self._avatar:setLoc(-200, 0)
end

local testLevel = {
	width = 960,
	height = 640,
	playerMotherShip = {
		loc = {-480, 0},
		dir = 180,
	},
	enemyMotherShip = {
		props = {bodyGfx = "mothership000.png?rot=-90"},
		loc = {480, 0},
		dir = 180,
	},
	cameraLoc = {0, 0},
}

function GameStage:loadLevel(levelData)
	self._xMin = -levelData.width / 2
	self._xMax = levelData.width / 2
	self._yMin = -levelData.height / 2
	self._yMax = levelData.height / 2
	self._battlefield = Battlefield.new(self._sceneRoot)
	local playerMS = self._battlefield:addPlayerMontherShip(profile.motherShip, unpack(levelData.playerMotherShip.loc))
	playerMS:setDir(levelData.playerMotherShip.dir)
	local enemyMS = self._battlefield:addEnemyMotherShip(levelData.enemyMotherShip.props, unpack(levelData.enemyMotherShip.loc))
	playerMS:setDir(levelData.enemyMotherShip.dir)
	camera:setLoc(unpack(levelData.cameraLoc))
end

function GameStage:open(stage, level)
	self._readyQ = {
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
	
	self:setupFleet()
	self:setupSpells()
	self:loadLevel(testLevel)
	
	self._timer = timer.new(0.1, function()
		self:update()
	end)
end

function GameStage:close()
	self._timer:close()
	self._timer = nil
	
	self._battlefield:destroy()
	self._battlefield = nil
	
	farLayer:remove(self._farRoot)
	nearLayer:remove(self._nearRoot)
	sceneLayer:remove(self._sceneRoot)
	uiLayer:remove(self._uiRoot)
	
	ui.defaultTouchHandler = nil
end

return GameStage