
local ui = require "ui.base"
local profile = {}

local HomeStage = {}

local FONT_SMALL = "arial@20"

function HomeStage:init(spaceStage, gameStage)
end

function HomeStage:load(onOkay)
	if self._root then
		uiLayer:add(self._root)
		return
	end
	
	self._root = uiLayer:add(ui.Group.new())
	self._userPanel = self._root:add(ui.Image.new ("user-panel.png"))
	local w, h = self._userPanel:getSize()
	self._userPanel:setAnchor("TL", w / 2, -h / 2)
	self._coinsNb = self._userPanel:add(ui.TextBox.new("0", FONT_SMALL, nil, "left", 60, 60))
    self._coinsNb:setLoc(0, 0)
	self._diamondsNb = self._userPanel:add(ui.TextBox.new("0", FONT_SMALL, nil, "left", 60, 60))
    self._diamondsNb:setLoc(, 0)
	self._expBar = self._userPanel:add(ui.FillBar.new("exp-bar.png"))
	self._expBar:setLoc(0, 0)
	
	self._menuRoot = self._root:add(ui.Group.new())
	self._menuRoot:setAnchor("BR", 0, 0)
	self._menuPanel = self._menuRoot:add(ui.Image.new("menu-panel.png"))
	local w, h = self._menuPanel:getSize()
	self._menuPanel:setLoc(-w / 2, h / 2)
	-- self._menuSwitch = self._menuRoot:add(ui.Switch.new("menu-hide-up.png", "menu-hide-down.png"))
	if onOkay then
		onOkay(HomeStage)
	end
end

function HomeStage:updateProfile()
end

function HomeStage:open()
end

function HomeStage:close()
	uiLayer:remove(self._root)
end

return HomeStage