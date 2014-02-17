
local resource = require "resource"
local ui = require "ui.base"
local profile = require "UserProfile"

local blockOn = MOAIThread.blockOnAction

local HomeStage = {}

local FONT_SMALL = "arial@20"

local menus = {
	{
		icon = "menu-settings.png",
		cb = function()
			HomeStage:switchSettings()
		end,
	},
	{
		icon = "menu-friends.png",
		cb = function()
			HomeStage:switchFriends()
		end,
	},
	{
		icon = "menu-alliances.png",
		cb = function()
			HomeStage:switchAlliances()
		end,
	},
	{
		icon = "menu-items.png",
		cb = function()
			HomeStage:switchItems()
		end,
	},
}


function HomeStage:init(spaceStage, gameStage)
end

function HomeStage:genPlanetOrbit(planet, x, y, t, s1, s2, s3, p)
	planet:setScl(s2, s2)
	local thread = MOAIThread.new()
	thread:run(function(planet, x, y, t)
		while true do
			planet:setLoc(-x, -y)
			planet:setPriority(p + self._base)
			local e = planet:seekScl(s1, s1, t / 2, MOAIEaseType.LINEAR)
			e:setListener(MOAIAction.EVENT_STOP, function()
				planet:seekScl(s2, s2, t / 2, MOAIEaseType.LINEAR)
			end)
			blockOn(planet:seekLoc(x, y, t, MOAIEaseType.SOFT_SMOOTH))
			
			planet:setLoc(x, y)
			planet:setPriority(p)
			local e = planet:seekScl(s3, s3, t / 2, MOAIEaseType.LINEAR)
			e:setListener(MOAIAction.EVENT_STOP, function()
				planet:seekScl(s2, s2, t / 2, MOAIEaseType.LINEAR)
			end)
			blockOn(planet:seekLoc(-x, -y, t, MOAIEaseType.SOFT_SMOOTH))
		end
	end, planet, x, y, t)
	
	if not self._orbits then
		self._orbits = {}
	end
	table.insert(self._orbits, thread)
end

function HomeStage:load(onOkay)
	if self._root then
		uiLayer:add(self._root)
		return
	end
	-- local bg = MOAIProp2D.new()
	-- local deck = MOAITileDeck2D.new()
	-- local tex = resource.texture("starfield.jpg")
	-- deck:setTexture(tex)
	-- local w, h = tex:getSize()
	-- deck:setSize(1, 1)
	-- deck:setRect (-0.5, 0.5, 0.5, -0.5)
	-- local grid = MOAIGrid.new ()
	-- grid:setSize(1, 1, w, h)
	-- grid:setRepeat ( true )
	-- grid:setRow(1, 1)
	-- bg:setDeck(deck)
	-- bg:setGrid(grid)
	-- sceneLayer:insertProp(bg)
	
	-- self._bgAnimating = MOAIThread.new()
	-- self._bgAnimating:run(function()
		-- while true do
			-- blockOn(bg:moveLoc(-w, 0, w / 3, MOAIEaseType.LINEAR))
		-- end
	-- end)
	
	self._base = 1000
	local mainPlanet = MOAIProp2D.new()
	local deck = resource.deck("earthMap6.png")
	mainPlanet:setDeck(deck)
	mainPlanet:setPriority(self._base)
	mainPlanet:setScl(0.5, 0.5)
	sceneLayer:insertProp(mainPlanet)
	
	local planet = MOAIProp2D.new()
	local deck = resource.deck("planet01.png")
	planet:setDeck(deck)
	sceneLayer:insertProp(planet)
	self:genPlanetOrbit(planet, 300, 100, 60, 0.8, 0.5, 0.2, 1)
	
	local planet = MOAIProp2D.new()
	local deck = resource.deck("planet03.png")
	planet:setDeck(deck)
	sceneLayer:insertProp(planet)
	self:genPlanetOrbit(planet, 400, -100, 30, 0.75, 0.45, 0.15, 1)
	
	sceneLayer:setSortMode(MOAILayer2D.SORT_PRIORITY_ASCENDING)
	
	self._root = uiLayer:add(ui.Group.new())
	self._userPanel = self._root:add(ui.Image.new ("user-panel.png"))
	local w, h = self._userPanel:getSize()
	self._userPanel:setAnchor("TL", w / 2, -h / 2)
	self._coinsNb = self._userPanel:add(ui.TextBox.new("0", FONT_SMALL, nil, "left", 60, 60))
    self._coinsNb:setLoc(0, 0)
	self._diamondsNb = self._userPanel:add(ui.TextBox.new("0", FONT_SMALL, nil, "left", 60, 60))
    self._diamondsNb:setLoc(0, 0)
	self._expBar = self._userPanel:add(ui.FillBar.new("exp-bar.png"))
	self._expBar:setLoc(0, 0)
	
	self._menuRoot = self._root:add(ui.Group.new())
	self._menuRoot:setAnchor("BR", 0, 0)
	self._menuPanel = self._menuRoot:add(ui.Image.new("menu-panel.png"))
	local w, h = self._menuPanel:getSize()
	self._menuPanel:setLoc(-w / 2, h / 2)
	self._menuPanel:setPriority(1)
	self._menuSwitch = self._menuRoot:add(ui.Switch.new("menu-icon.png", "menu-icon.png?scl=1.1,1.1", "menu-icon.png?scl=-1,1", "menu-icon.png?scl=-1.1,1.1"))
	self._menuSwitch:setPriority(2)
	self._menuSwitch:setLoc(-w / 2, h / 2)
	self._menuSwitch.onPress = function()
		if self._menuSwitch.isOn then
			self._menuPanel:moveRot(-720, 1)
		else
			self._menuPanel:moveRot(720, 1)
		end
	end
	self._menuSwitch.onSwitchOn = function()
		self:showMenu()
	end
	self._menuSwitch.onSwitchOff = function()
		self:hideMenu()
	end
	self._menuSwitch.isOn = false
	
	self._scan = self._menuRoot:add(ui.Button.new("scan-btn.png"))
	self._scan:setLoc(-w / 2, h / 2 + h)
	local scanCenter = self._scan:add(ui.new(MOAIProp2D.new()))
	local enemy = self._scan:add(ui.Image.new("scan-btn-03.png"))
	local scan = scanCenter:add(ui.Image.new("scan-btn-02.png"))
	self._scan:setPriority(0)
	enemy:setPriority(1)
	scan:setPriority(2)
	scan:setLoc(5, 20)
	self._scanning = MOAIThread.new()
	-- self._scanning:run(function()
		-- while true do
			-- local x = 30 - math.random(60)
			-- local y = 30 - math.random(60)
			-- enemy:setLoc(x, y)
			-- enemy:setScl(0.3)
			-- enemy:setColor(0, 0, 0, 0)
			-- enemy:seekScl(1, 1, 1.5)
			-- enemy:seekColor(1, 1, 1, 1, 1.5)
			-- blockOn(scanCenter:moveRot(-180, 2, MOAIEaseType.LINEAR))
		-- end
	-- end)
	
	local x = -50
	local y = 11
	local space = -25
	self._menus = {}
	for k, v in ipairs(menus) do
		local m = ui.Image.new("menu-bg.png")
		m:setLoc(x, y)
		x = x + space
		m._icon = m:add(ui.Button.new(v.icon))
		m._isActive = profile.menus[k]
		m:setColor(0, 0, 0, 0)
		table.insert(self._menus, m)
	end
		
	if onOkay then
		onOkay(HomeStage)
	end
end

function HomeStage:showMenu()
	if self._menuHiding or self._menuShowing then
		return
	end
	
	self._menuShowing = MOAIThread.new()
	self._menuShowing:run(function()
		for k, v in ipairs(self._menus) do
			local m = self._menuRoot:add(v)
			local a = 0.5
			if m._isActive then
				a = 1
			end
			m:seekColor(a, a, a, a, 0.3)
			local t = MOAITimer.new()
			t:setSpan(0.1)
			blockOn(t:start())
		end
		self._menuShowing = nil
	end)
end

function HomeStage:hideMenu()
	if self._menuShowing or self._menuHiding then
		return
	end
	
	self._menuHiding = MOAIThread.new()
	self._menuHiding:run(function()
		for i = #self._menus, 1, -1 do
			local m = self._menus[i]
			m:seekColor(0, 0, 0, 0, 0.3)
			local t = MOAITimer.new()
			t:setSpan(0.1)
			blockOn(t:start())
		end
		for k, v in ipairs(self._menus) do
			self._menuRoot:remove(v)
		end
		self._menuHiding = nil
	end)
end

function HomeStage:updateProfile()
end

function HomeStage:open()
end

function HomeStage:close()
	uiLayer:remove(self._root)
end

return HomeStage