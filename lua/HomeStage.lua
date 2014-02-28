
local timer = require "timer"
local resource = require "resource"
local ui = require "ui.base"
local profile = require "UserProfile"

local blockOn = MOAIThread.blockOnAction

local HomeStage = {}

local FONT_SMALL = "arial@12"

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

function HomeStage:genPlanetOrbit(planet, x, y, t, s1, s2, s3, p, children)
	children = children or {}
	planet:setScl(s2, s2)
	local thread = MOAIThread.new()
	thread:run(function(planet, x, y, t)
		while true do
			planet:setLoc(-x, -y)
			planet:setPriority(p + self._base)
			for i, v in ipairs(children) do
				v:setPriority(p + self._base)
			end
			local e = planet:seekScl(s1, s1, t / 2, MOAIEaseType.LINEAR)
			e:setListener(MOAIAction.EVENT_STOP, function()
				planet:seekScl(s2, s2, t / 2, MOAIEaseType.LINEAR)
			end)
			blockOn(planet:seekLoc(x, y, t, MOAIEaseType.SOFT_SMOOTH))
			
			planet:setLoc(x, y)
			planet:setPriority(p)
			for i, v in ipairs(children) do
				v:setPriority(p)
			end
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
	
-- MOAIDebugLines.setStyle ( MOAIDebugLines.PARTITION_CELLS, 2, 1, 0, 0 )
-- MOAIDebugLines.setStyle ( MOAIDebugLines.PARTITION_PADDED_CELLS, 1, 0, 1, 0 )
-- MOAIDebugLines.setStyle ( MOAIDebugLines.PROP_MODEL_BOUNDS, 2, 0, 0, 1 )
-- MOAIDebugLines.setStyle ( MOAIDebugLines.PROP_WORLD_BOUNDS, 1, 1, 1, 0 )
-- MOAIDebugLines.setStyle ( MOAIDebugLines.TEXT_BOX, 1, 1, 0, 1 )
-- MOAIDebugLines.setStyle ( MOAIDebugLines.TEXT_BOX_BASELINES, 1, 0, 1, 1 )
-- MOAIDebugLines.setStyle ( MOAIDebugLines.TEXT_BOX_LAYOUT, 1, 1, 1, 1 )

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
	local motherPlanet = MOAIProp2D.new()
	local deck = resource.deck("earthMap6.png")
	motherPlanet:setDeck(deck)
	motherPlanet:setPriority(self._base)
	motherPlanet:setScl(0.5, 0.5)
	sceneLayer:insertProp(motherPlanet)
	
	local taxWindow = ui.Image.new("window.png")
	local closeButton = taxWindow:add(ui.Button.new("close.png"))
	local taxRoot = taxWindow:add(ui.new(MOAIProp2D.new()))
	taxRoot:setLoc(0, 50)
	closeButton:setLoc(50, 0)
	closeButton.onClick = function()
		local ease = taxWindow:seekScl(1, 0, 0.5, MOAIEaseType.EASE_OUT)
		ease:setListener(MOAIAction.EVENT_STOP, function()
			popupLayer:remove(taxWindow)
			popupLayer.popuped = false
		end)
	end
	
	local taxboxlist = {}
	local x, y, w = 0, 0, 25
	for i = 1, profile.taxMax do
		local taxbox = taxRoot:add(ui.Image.new("tex-box.png"))
		taxbox:setLoc(x, y)
		taxboxlist[i] = taxbox
		x = x + w
	end
	local taxlist = {}
	local filltax = function()
		for i = 1, profile.taxCount do
			local tax = taxboxlist[i]:add(ui.Image.new("tax.png"))
			taxlist[i] = tax
		end
	end
	filltax()
	local collectCD = taxWindow:add(ui.TimeBox.new(0, FONT_SMALL, nil, "left", 100, 60))
	collectCD.setCD = function(secs)
		local cd = timer.new()
		cd:runn(1, secs, function()
			secs = secs - 1
			collectCD:setTime(secs)
			if secs == 0 then
				profile.taxCount = profile.taxMax
				filltax()
			end
		end)
	end
	local collectTax = taxWindow:add(ui.Button.new("button-normal.png", "button-highlight.png"))
	collectTax:setLoc(0, 100)
	collectTax.onClick = function()
		local n = #taxlist
		if n > 0 then
			local tax = taxlist[n]
			local e = tax:seekScl(1.5, 1.5, 1)
			tax:seekColor(0, 0, 0, 0, 1)
			e:setListener(MOAIAction.EVENT_STOP, function()
				tax:remove()
			end)
			taxlist[n] = nil
			profile.taxCount = profile.taxCount - 1
			
			if profile.taxCount == 0 then
				collectCD.setCD(profile.collectCD)
			end
		end
	end
	
	motherPlanet.onClick = function(self)
		popupLayer.popuped = true
		popupLayer:add(taxWindow)
		taxWindow:setScl(0.5, 0.5)
		taxWindow:seekScl(1, 1, 0.5)
		taxWindow:setColor(0.5, 0.5, 0.5, 0.5)
		taxWindow:seekColor(1, 1, 1, 1, 0.5)
	end
	
	local fleetWindow = ui.Image.new("window.png")
	local shipList = fleetWindow:add(ui.DropList.new(150, 150, 30, "vertical"))
	local shipModel = fleetWindow:add(ui.Image.new(""))
	local upgrade = fleetWindow:add(ui.Button.new("upgrade.png"))
	local currInfo = fleetWindow:add(ui.TextBox.new("", FONT_SMALL, nil, "left", 100, 60))
	local nextInfo = fleetWindow:add(ui.TextBox.new("", FONT_SMALL, nil, "left", 100, 60))
	currInfo:setLoc(80, 0)
	currInfo:setLineSpacing(20)
	nextInfo:setLoc(180, 0)
	nextInfo:setLineSpacing(20)
	upgrade:setLoc(50, -50)
	shipModel:setLoc(50, 0)
	fleetWindow.updateFleet = function()
		shipList:clearItems()
		for i, v in ipairs(profile.fleet) do
			local item = shipList:addItem(ui.Image.new(v.icon))
			item.onClick = function()
				shipModel:setImage(v.model)
				currInfo:setString(table.concat(v.upgradeCurve[v.level].info, "\n"))
				local lvl = v.level + 1
				if lvl <= #v.upgradeCurve then
					nextInfo:setString(table.concat(v.upgradeCurve[lvl].info, "\n"))
					local ok = profile.coins >= v.upgradeCost
					upgrade:disable(not ok)
					if ok then
						upgrade.onClick = function()
							v.level = v.level + 1
						end
					end
				end
				
			end
		end
	end
	
	local millPlanet = MOAIProp2D.new()
	local deck = resource.deck("planet01.png")
	millPlanet:setDeck(deck)
	sceneLayer:insertProp(millPlanet)
	millPlanet:setLoc(0, -100)
	millPlanet.onClick = function()
		popupLayer.popuped = true
		popupLayer:add(fleetWindow)
		fleetWindow:updateFleet()
		fleetWindow:setScl(0.5, 0.5)
		fleetWindow:seekScl(1, 1, 0.5)
		fleetWindow:setColor(0.5, 0.5, 0.5, 0.5)
		fleetWindow:seekColor(1, 1, 1, 1, 0.5)
	end
	
	-- self:genPlanetOrbit(millPlanet, 300, 100, 60, 0.6, 0.4, 0.2, 3)
	
	local techPlanet = MOAIProp2D.new()
	local deck = resource.deck("planet03.png")
	techPlanet:setDeck(deck)
	sceneLayer:insertProp(techPlanet)
	-- self:genPlanetOrbit(techPlanet, 350, -100, 55, 0.5, 0.3, 0.1, 2)
	
	-- local portal = MOAIProp2D.new()
	-- local deck = resource.deck("star-portal.png")
	-- portal:setDeck(deck)
	-- local children = {}
	-- local portal02 = MOAIProp2D.new()
	-- portal02:setParent(portal)
	-- sceneLayer:insertProp(portal02)
	-- local deck = resource.deck("star-portal-02.png")
	-- portal02:setDeck(deck)
	-- table.insert(children, portal02)
	-- for i = 1, 7 do
		-- local o = MOAIProp2D.new()
		-- o:setParent(portal02)
		-- o:setDeck(deck)
		-- o:setRot(45 * i)
		-- sceneLayer:insertProp(o)
		-- table.insert(children, o)
	-- end
	-- sceneLayer:insertProp(portal)
	-- self:genPlanetOrbit(portal, 150, -200, 10, 0.5, 0.3, 0.1, 1, children)
	-- self._portalRotating = MOAIThread.new()
	-- self._portalRotating:run(function()
		-- while true do
			-- blockOn(portal02:moveRot(360, 10, MOAIEaseType.LINEAR))
		-- end
	-- end)
	
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
	-- self._scanning = MOAIThread.new()
	-- self._scanning:run(function()
		-- while true do
			-- blockOn(scanCenter:moveRot(-180, 2, MOAIEaseType.LINEAR))
		-- end
	-- end)
	-- self._enemy = MOAIThread.new()
	-- self._enemy:run(function()
		-- while true do
			-- local x = 30 - math.random(60)
			-- local y = 30 - math.random(60)
			-- enemy:setLoc(x, y)
			-- enemy:setScl(0.3)
			-- enemy:setColor(0, 0, 0, 0)
			-- enemy:seekScl(1, 1, 1)
			-- blockOn(enemy:seekColor(1, 1, 1, 1, 1))
			-- enemy:seekScl(0.3, 0.3, 1)
			-- blockOn(enemy:seekColor(0, 0, 0, 0, 1))
		-- end
	-- end)
	
	local x = -158
	local y = 50
	local space = -110
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
	
	ui.setDefaultTouchCallback(function(eventType, touchIdx, x, y, tapCount)
		if eventType == ui.TOUCH_UP then
			local wx, wy = sceneLayer:wndToWorld(x, y)
			local partition = sceneLayer:getPartition()
			local prop = partition:propForPoint(wx, wy)
			if prop and prop.onClick then
				prop:onClick()
			end
		end
	end)
	
	if onOkay then
		onOkay(HomeStage)
	end
end

function HomeStage:update()
end

function HomeStage:showMenu()
	if self._menuHiding or self._menuShowing then
		return
	end
	
	self._menuShowing = MOAIThread.new()
	self._menuShowing:run(function()
		for k, v in ipairs(self._menus) do
			local m = self._menuRoot:add(v)
			local a = 0.3
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
	
	self._bgAnimating:stop()
	self._portalRotating:stop()
	if self._menuShowing then
		self._menuShowing:stop()
	end
	if self._menuHiding then
		self._menuHiding:stop()
	end
end

return HomeStage