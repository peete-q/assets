
local ui = require "ui.base"
local profile = {}
local blockOn = MOAIThread.blockOnAction

local HomeStage = {}

function HomeStage:init(spaceStage, gameStage)
end

function HomeStage:load(onOkay)
	if self._root then
		uiLayer:add(self._root)
		return
	end
	
	self._root = uiLayer:add(ui.Group.new())
	self._userPanel = self._root:add(ui.Image.new ("user-panel.png"))
	self._userPanel:setAnchor("TL", 0, 0)
	self._coinsNb = self._userPanel:add(ui.TextBox.new("0", FONT_SMALL, "ffffff", "left", 60, 60))
    self._coinsNb:setLoc(0, 0)
	self._diamondsNb = self._userPanel:add(ui.TextBox.new("0", FONT_SMALL, "ffffff", "left", 60, 60))
    self._diamondsNb:setLoc(0, 0)
	self._expBar = self._userPanel:add(ui.FillBar.new("exp-bar.png"))
	self._expBar:setLoc(0, 0)
	
	self._menuRoot = self._root:add(ui.Group.new())
	self._menuRoot:setAnchor("BR", 0, 0)
	self._menuPanel = self._menuRoot:add(ui.Image.new("menu-panel.png"))
	self._menuPanel:setLoc(0, 0)
	self._menuSwitch = self._menuRoot:add(ui.Switch.new("menu-hide.png", nil, "menu-show.png", nil))
	self._menuSwitch.onSwitchOn = function() self:showMenu() end
	self._menuSwitch.onSwitchOff = function() self:hideMenu() end
	if onOkay then
		onOkay(HomeStage)
	end
end

local _menuIcons = {}
function HomeStage:showMenu()
	if self._showing then
		return
	end
	local x = 0
	local y = 0
	local space = 50
	local menus = {}
	self._showing = mainAS:run(function()
		for k, v in ipairs(profile.menus) do
			local bg = self._menuRoot:add(ui.Image.new("menu-bg.png"))
			bg:setLoc(x, y)
			local icon = bg:add(ui.Button.new(_menuIcons[v.type]))
			icon:setColor(0, 0, 0, 0)
			blockOn(icon:seekColor(1, 1, 1, 1, 0.5))
		end
		self._showing = nil
	end)
end

function HomeStage:hideMenu()
end

function HomeStage:updateProfile()
end

function HomeStage:open()
end

function HomeStage:close()
	uiLayer:remove(self._root)
end
