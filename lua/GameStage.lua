
local ui = require "ui.base"
local Unit = require "Unit"
local Scene = require "Scene"

local profile = {}
local blockOn = MOAIThread.blockOnAction

local GameStage = {
	width = 900,
	height = 600,
}
local _prepareQVSpace = 0
local _prepareQHSpace = 0

function GameStage:init(spaceStage)
end

function GameStage:load(onOkay)
	if self._root then
		uiLayer:add(self._root)
		return
	end
	
	if onOkay then
		onOkay(GameStage)
	end
end

function GameStage:setupSlots()
	for k, v in ipairs(profile.slots) do
	end
end

function GameStage:setupSkills()
end

function GameStage:updateProfile()
end

function GameStage:open()
	self._scene = Scene.new(self.width, self.height, gameLayer)
	self._prepareQ = {}
	self._energy = 0
end

function GameStage:pushQ(props, x, y)
	if props.cost > self._energy then
		return
	end
	local tx, ty = self:getFreeQLoc()
	if not tx then
		return
	end
	
	self._energy = self._energy - props.cost
	local unit = self._root:add(ui.Image.new("prepare-q.png"))
	table.insert(self._prepareQ, unit)
	local prog = unit:add(ui.Image.new("prepare-progress.png"))
	local e = prog:seekScl(10, 1, props.prepareTime)
	e:setListener(MOAITimer.EVENT_STOP, function()
		self:popQ(#self._prepareQ)
		self._scene:spwanPlayerUnit(props)
	end
	local icon = self._root:add(ui.Image.new(props.icon))
	unit:setLoc(x, y)
	unit:seekLoc(tx, ty, 1)
end

function GameStage:popQ(index)
	local unit = self._prepareQ[index]
	unit:remove()
	table.remove(self._prepareQ, index)
	for i = index, #self._prepareQ do
		local o = self._prepareQ[i]
		o:moveLoc(-_prepareQHSpace, 0, 0.5)
	end
end

function GameStage:getFreeQLoc()
	local nb = #self._prepareQ
	if nb >= profile.prepareQMax then
		return
	end
	
	if nb > 0 then
		local x, y = self._prepareQ[nb]:getLoc()
		return x + _prepareQHSpace, y
	end
	return 0, 0
end

function GameStage:update()
	self._scene:update()
	local ticks = self._scene.ticks
end

function GameStage:close()
	uiLayer:remove(self._root)
end
