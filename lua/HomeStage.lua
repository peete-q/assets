
local timer = require "timer"
local resource = require "resource"
local ui = require "ui"
local node = require "node"
local profile = require "UserProfile"

local blockOn = MOAIThread.blockOnAction

local HomeStage = {}

local FONT_SMALL = "normal@18"
local FONT_MIDDLE = "normal@24"
local BUTTON_IMAGE = {"button-normal.png", 1.1, 0.5}
local FONT_COLOR_LIGHT = {120/255, 255/255, 220/255}
local FONT_COLOR_GOLD = {255/255, 191/255, 7/255}

local menus = {
	{
		icon = "menu-settings.png",
		onClick = function()
			HomeStage:switchSettings()
		end,
	},
	{
		icon = "menu-friends.png",
		onClick = function()
			HomeStage:switchFriends()
		end,
	},
	{
		icon = "menu-alliances.png",
		onClick = function()
			HomeStage:switchAlliances()
		end,
	},
	{
		icon = "menu-rank.png",
		onClick = function()
			HomeStage:switchRank()
		end,
	},
	{
		icon = "menu-items.png",
		onClick = function()
			HomeStage:switchItems()
		end,
	},
}

function HomeStage:init(spaceStage, gameStage)
	self._spaceStage = spaceStage
	self._gameStage = gameStage
end

function HomeStage:makePlanetOrbit(planet, x, y, t, s1, s2, s3, p, children)
	children = children or {}
	planet:setScl(s2, s2)
	local thread = MOAIThread.new()
	thread:run(function(planet, x, y, t)
		while true do
			planet:setLoc(-x, -y)
			planet:setPriority(p + self._basePriority)
			for i, v in ipairs(children) do
				v:setPriority(p + self._basePriority)
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

function HomeStage:initStageBG()
	self._sceneRoot = node.new()
	
	local bg = self._sceneRoot:add(node.new())
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
	
	self._bgAnimating = MOAIThread.new()
	self._bgAnimating:run(function()
		while true do
			blockOn(bg:moveLoc(-w, 0, w / 3, MOAIEaseType.LINEAR))
		end
	end)
end

function HomeStage:initMotherPlanet()
	self._basePriority = 1000
	local motherPlanet = MOAIProp2D.new()
	local deck = resource.deck("earth.png")
	motherPlanet:setDeck(deck)
	motherPlanet:setPriority(self._basePriority)
	motherPlanet:setScl(0.9, 0.9)
	sceneLayer:insertProp(motherPlanet)
	
	local taxWindow = ui.Image.new("window.png")
	taxWindow:setPriority(1)
	local closeButton = taxWindow:add(ui.Button.new("back.png", "back.png?scl=1.2"))
	closeButton:setLoc(435, 228)
	closeButton.onClick = function()
		local ease = taxWindow:seekScl(1, 0, 0.5, MOAIEaseType.EASE_OUT)
		ease:setListener(MOAIAction.EVENT_STOP, function()
			-- popupLayer:remove(taxWindow)
			popupLayer.popuped = false
		end)
	end
	planet = taxWindow:add(ui.Image.new("earth.png"))
	planet:setScl(0.6)
	planet:setLoc(200, 0)
	planet:setColor(1, 1, 1, 0.8)
	
	timerIcon = taxWindow:add(ui.Image.new("timer-icon.png"))
	timerIcon:setLoc(-300, 20)
	
	taxRoot = taxWindow:add(ui.new(MOAIProp2D.new()))
	taxRoot:setLoc(-350, 80)
	local taxboxlist = {}
	local x, y, w = 0, 0, 25
	for i = 1, profile.taxMax do
		local taxbox = taxRoot:add(ui.Image.new("tax-box.png"))
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
	collectCD = taxWindow:add(ui.TextBox.new("00:00:00", FONT_SMALL, nil, "LM", 100, 50))
	collectCD.cooldown = function(secs)
		profile.currCCD = secs
		local cd = timer.new()
		cd:runn(1, profile.currCCD, function()
			profile.currCCD = profile.currCCD - 1
			collectCD:setTime(profile.currCCD)
			if profile.currCCD == 0 then
				profile.taxCount = profile.taxMax
				filltax()
			end
		end)
	end
	collectCD:setLoc(-210, 20)
	collectCD:setColor(unpack(FONT_COLOR_LIGHT))
	if profile.currCCD > 0 then
		collectCD.cooldown(profile.currCCD)
	end
	
	collectCountLabel = taxWindow:add(ui.TextBox.new("collect count", FONT_MIDDLE, nil, "MM", 200, 50))
	collectCountLabel:setColor(unpack(FONT_COLOR_LIGHT))
	collectCountLabel:setLoc(-300, 140)
	
	collectCount = taxWindow:add(ui.TextBox.new("", FONT_SMALL, nil, "LM", 100, 50))
	collectCount.setCount = function(self, numerator, denominator)
		local str = string.format("%d/%d", numerator, denominator)
		self:setString(str)
	end
	collectCount:setCount(profile.taxCount, profile.taxMax)
	collectCount:setColor(unpack(FONT_COLOR_GOLD))
	collectCount:setLoc(-140, 137)
	
	coinText = taxWindow:add(ui.TextBox.new("coins", FONT_MIDDLE, nil, "MM", 100, 50))
	coinText:setColor(unpack(FONT_COLOR_LIGHT))
	coinText:setLoc(-320, -100)
	
	coinIcon = taxWindow:add(ui.Image.new("coin.png"))
	coinIcon:setLoc(-180, -100)
	
	coinNum = taxWindow:add(ui.TextBox.new("", FONT_SMALL, nil, "LM", 100, 50))
	coinNum.setNum = function(self, num)
		local str = string.format("%d", num)
		self:setString(str)
	end
	coinNum:setNum(profile.coins)
	coinNum:setColor(unpack(FONT_COLOR_GOLD))
	coinNum:setLoc(-100, -100)
	
	collectTax = taxWindow:add(ui.Button.new(unpack(BUTTON_IMAGE)))
	collectTax:setLoc(-250, -180)
	local action
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
			collectCount:setCount(profile.taxCount, profile.taxMax)
			
			if profile.taxCount == 0 then
				collectCD.cooldown(profile.collectCD)
			end
			local num = profile.coins
			if action then
				num = action.rollingNumber
				action:stop()
			end
			coinNum:rollNumber(num, profile.coins + profile.taxNum, 0.75)
			profile.coins = profile.coins + profile.taxNum
		end
	end
	
	collectText = collectTax:add(ui.TextBox.new("collect", FONT_MIDDLE, nil, "MM", 100, 50))
	collectText:setColor(unpack(FONT_COLOR_LIGHT))
	
	motherPlanet.onClick = function(self)
		popupLayer.popuped = true
		popupLayer:add(taxWindow)
		taxWindow:setScl(0.5, 0.5)
		taxWindow:seekScl(1, 1, 0.5)
		taxWindow:setColor(0.5, 0.5, 0.5, 0.5)
		taxWindow:seekColor(1, 1, 1, 1, 0.5)
	end
end

function HomeStage:initMillPlanet()
	local fleetWindow = ui.Image.new("window.png")
	fleetWindow:setPriority(1)
	local closeButton = fleetWindow:add(ui.Button.new("back.png", "back.png?scl=1.2"))
	closeButton:setLoc(435, 228)
	closeButton.onClick = function()
		local ease = fleetWindow:seekScl(1, 0, 0.5, MOAIEaseType.EASE_OUT)
		ease:setListener(MOAIAction.EVENT_STOP, function()
			-- popupLayer:remove(fleetWindow)
			popupLayer.popuped = false
		end)
	end
	local upgrade = fleetWindow:add(ui.Button.new(unpack(BUTTON_IMAGE)))
	upgrade:setLoc(50, -50)
	local currInfo = fleetWindow:add(ui.TextBox.new("", FONT_SMALL, nil, "MM", 100, 50))
	currInfo:setLoc(80, 0)
	currInfo:setLineSpacing(20)
	local nextInfo = fleetWindow:add(ui.TextBox.new("", FONT_SMALL, nil, "MM", 100, 50))
	nextInfo:setLoc(180, 0)
	nextInfo:setLineSpacing(20)
	-- local shipModel = fleetWindow:add(ui.Image.new(""))
	-- shipModel:setLoc(50, 0)
	local shipList = fleetWindow:add(ui.DropList.new(150, 500, 150, "vertical"))
	fleetWindow.updateFleet = function()
		shipList:clearItems()
		for i, v in ipairs(profile.fleet) do
			local frame = shipList:addItem(ui.Image.new("frame_icon.png"))
			local item = frame:add(ui.Image.new(v.icon))
			-- item.onClick = function()
				-- shipModel:setImage(v.model)
				-- currInfo:setString(table.concat(v.upgradeCurve[v.level].info, "\n"))
				-- local lvl = v.level + 1
				-- if lvl <= #v.upgradeCurve then
					-- nextInfo:setString(table.concat(v.upgradeCurve[lvl].info, "\n"))
					-- local ok = profile.coins >= v.upgradeCost
					-- upgrade:disable(not ok)
					-- if ok then
						-- upgrade.onClick = function()
							-- v.level = v.level + 1
						-- end
					-- end
				-- end
			-- end
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
	
	self:makePlanetOrbit(millPlanet, 300, 100, 60, 0.6, 0.4, 0.2, 3)
end

function HomeStage:initTechPlanet()
	local techPlanet = MOAIProp2D.new()
	local deck = resource.deck("planet03.png")
	techPlanet:setDeck(deck)
	sceneLayer:insertProp(techPlanet)
	self:makePlanetOrbit(techPlanet, 350, -100, 55, 0.5, 0.3, 0.1, 2)
end

function HomeStage:initPortal()
	local portal = MOAIProp2D.new()
	local deck = resource.deck("star-portal.png")
	portal:setDeck(deck)
	local children = {}
	local portal02 = MOAIProp2D.new()
	portal02:setParent(portal)
	sceneLayer:insertProp(portal02)
	local deck = resource.deck("star-portal-02.png")
	portal02:setDeck(deck)
	table.insert(children, portal02)
	for i = 1, 7 do
		local o = MOAIProp2D.new()
		o:setParent(portal02)
		o:setDeck(deck)
		o:setRot(45 * i)
		sceneLayer:insertProp(o)
		table.insert(children, o)
	end
	sceneLayer:insertProp(portal)
	self:makePlanetOrbit(portal, 150, -200, 10, 0.5, 0.3, 0.1, 1, children)
	self._portalRotating = MOAIThread.new()
	self._portalRotating:run(function()
		while true do
			blockOn(portal02:moveRot(360, 10, MOAIEaseType.LINEAR))
		end
	end)
end

function HomeStage:initUserPanel()
	self._userPanel = self._uiRoot:add(ui.Image.new ("user-panel.png"))
	local w, h = self._userPanel:getSize()
	self._userPanel:setAnchor("TL", w / 2, -h / 2)
	self._coinsNum = self._userPanel:add(ui.TextBox.new("0", FONT_SMALL, nil, "MM", 60, 60))
    self._coinsNum:setLoc(0, 0)
	self._diamondsNum = self._userPanel:add(ui.TextBox.new("0", FONT_SMALL, nil, "MM", 60, 60))
    self._diamondsNum:setLoc(0, 0)
	self._expBar = self._userPanel:add(ui.FillBar.new("exp-bar.png"))
	self._expBar:setLoc(0, 0)
end

function HomeStage:updateUserPanel()
	local num = profile.currExp / profile.expList[profile.level]
	self._expBar:setFill(num)
	self._coinsNum:setString(tostring(profile.coins))
	self._diamondsNum:setString(tostring(profile.diamonds))
end

function HomeStage:initMenu()
	self._menuRoot = self._uiRoot:add(ui.Group.new())
	self._menuRoot:setAnchor("BR", 0, 0)
	menuPanel = self._menuRoot:add(ui.Image.new("menu-panel.png"))
	local w, h = menuPanel:getSize()
	menuPanel:setLoc(-w / 2, h / 2)
	menuPanel:setPriority(1)
	menuSwitch = self._menuRoot:add(ui.Switch.new("menu-icon.png?scl=-1,1", "menu-icon.png?scl=-1.1,1.1", "menu-icon.png", "menu-icon.png?scl=1.1,1.1"))
	menuSwitch:setPriority(2)
	menuSwitch:setLoc(-w / 2, h / 2)
	menuSwitch.onPress = function()
		if menuSwitch.isOn then
			menuPanel:moveRot(-720, 1)
		else
			menuPanel:moveRot(720, 1)
		end
	end
	menuSwitch.onTurnOn = function()
		self:showMenu()
	end
	menuSwitch.onTurnOff = function()
		self:hideMenu()
	end
	menuSwitch:turnOn(false)
	
	scanButton = self._menuRoot:add(ui.Button.new("scan-btn.png"))
	scanButton:setLoc(-w / 2, h / 2 + h)
	local scanCenter = scanButton:add(ui.new(MOAIProp2D.new()))
	local enemy = scanButton:add(ui.Image.new("scan-btn-03.png"))
	local scan = scanCenter:add(ui.Image.new("scan-btn-02.png"))
	scanButton:setPriority(0)
	enemy:setPriority(1)
	scan:setPriority(2)
	scan:setLoc(5, 20)
	local scanThread = MOAIThread.new()
	scanThread:run(function()
		while true do
			blockOn(scanCenter:moveRot(-180, 2, MOAIEaseType.LINEAR))
		end
	end)
	local enemyThread = MOAIThread.new()
	enemyThread:run(function()
		while true do
			local x = 30 - math.random(60)
			local y = 30 - math.random(60)
			enemy:setLoc(x, y)
			enemy:setScl(0.3)
			enemy:setColor(0, 0, 0, 0)
			enemy:seekScl(1, 1, 1)
			blockOn(enemy:seekColor(1, 1, 1, 1, 1))
			enemy:seekScl(0.3, 0.3, 1)
			blockOn(enemy:seekColor(0, 0, 0, 0, 1))
		end
	end)
	
	local x = -155
	local y = 50
	local space = -100
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
end

function HomeStage:load(onOkay)
-- MOAIDebugLines.setStyle ( MOAIDebugLines.PARTITION_CELLS, 2, 1, 0, 0 )
-- MOAIDebugLines.setStyle ( MOAIDebugLines.PARTITION_PADDED_CELLS, 1, 0, 1, 0 )
-- MOAIDebugLines.setStyle ( MOAIDebugLines.PROP_MODEL_BOUNDS, 2, 0, 0, 1 )
-- MOAIDebugLines.setStyle ( MOAIDebugLines.PROP_WORLD_BOUNDS, 1, 1, 1, 0 )
-- MOAIDebugLines.setStyle ( MOAIDebugLines.TEXT_BOX, 1, 1, 0, 1 )
-- MOAIDebugLines.setStyle ( MOAIDebugLines.TEXT_BOX_BASELINES, 1, 0, 1, 1 )
-- MOAIDebugLines.setStyle ( MOAIDebugLines.TEXT_BOX_LAYOUT, 1, 1, 1, 1 )

	self._uiRoot = uiLayer:add(ui.Group.new())
	self:initUserPanel()
	self:initMenu()
	self:initStageBG()
	self:initMotherPlanet()
	self:initMillPlanet()
	self:initTechPlanet()
	self:initPortal()
	
	sceneLayer:setSortMode(MOAILayer2D.SORT_PRIORITY_ASCENDING)
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

function HomeStage:switchToSpace()
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
	if not self._loaded then
		self:load()
		self._loaded = true
	end
	uiLayer:add(self._uiRoot)
	sceneLayer:add(self._sceneRoot)
	
	self:updateUserPanel()
end

function HomeStage:close()
	uiLayer:remove(self._uiRoot)
	sceneLayer:remove(self._sceneRoot)
	
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