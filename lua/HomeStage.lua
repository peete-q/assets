
local timer = require "timer"
local resource = require "resource"
local device = require "device"
local ui = require "ui"
local node = require "node"
local profile = require "UserProfile"
local Image = require "gfx.Image"
local TextBox = require "gfx.TextBox"
local FillBar = require "gfx.FillBar"
local SpinPatch = require "gfx.SpinPatch"
local interpolate = require "interpolate"

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

function HomeStage:makePlanetOrbit(planet, x, y, a, b, s1, s2, t, p, theta0, phi)
	local thread = MOAIThread.new()
	local timer = timer.new()
	timer:setSpan(1.0E37)
	timer:start()
	local s1, s2 = 1, 2
	local length = t / 2
	local sinphi = math.sin(phi)
	local cosphi = math.cos(phi)
	local runtime, t0 = 0, 0
	local theta1, theta2 = -math.pi, 0
	local p2 = p + self._centerPriority
	local b2 = b * 2
	local x1, y1, theta
	planet:setTreePriority(p2)
	thread:run(function()
		while true do
			runtime = timer:getTime() - t0
			if runtime >= length then
				t0 = t0 + length
				runtime = runtime - length
				theta1 = theta1 + math.pi
				theta2 = theta2 + math.pi
				if p2 == p then
					p2 = p + self._centerPriority
				else
					p2 = p
				end
				planet:setTreePriority(p2)
			end
			theta = theta0 + interpolate.lerp(theta1, theta2, runtime / length)
			x1 = a * math.cos(theta) * cosphi - b * math.sin(theta) * sinphi
			y1 = a * math.cos(theta) * sinphi + b * math.sin(theta) * cosphi
			planet:setLoc(x1, y1)
			planet:setScl(s1 + (1 - math.sin(theta)) * (s2 - s1) / 2)
			coroutine.yield()
		end
	end)
end

function HomeStage:initStageBG()
	local bg = self._sceneRoot:add(node.new())
	bg:setPriority(1)
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
	
	self._bgMoving = MOAIThread.new()
	self._bgMoving:run(function()
		while true do
			blockOn(bg:moveLoc(-w, 0, w / 3, MOAIEaseType.LINEAR))
		end
	end)
end

function HomeStage:initMotherPlanet()
	self._centerPriority = 1000
	local motherPlanet = self._sceneRoot:add(node.new())
	local deck = resource.deck("earth.png")
	motherPlanet:setDeck(deck)
	motherPlanet:setPriority(self._centerPriority)
	motherPlanet:setScl(0.9, 0.9)
	
	local taxWindow = Image.new("window.png")
	taxWindow:setPriority(1)
	local closeButton = taxWindow:add(ui.Button.new("back.png", "back.png?scl=1.2"))
	closeButton:setLoc(435, 228)
	closeButton.onClick = function()
		local ease = taxWindow:seekScl(1, 0, 0.5, MOAIEaseType.EASE_OUT)
		ease:setListener(MOAIAction.EVENT_STOP, function()
			popupLayer:remove(taxWindow)
			popupLayer.popuped = false
		end)
	end
	
	beam = taxWindow:add(Image.new("beam.png"))
	beam:setScl(2.8, 2.8)
	beam:setLoc(200, 0)
	beam:setColor(0.5, 0.5, 0.5, 0.5)
	beam:setPriority(2)
	
	spin = taxWindow:add(SpinPatch.new("spin.png"))
	spin:setScl(2, 1)
	spin:setLoc(200, -150)
	spin:setColor(0.8, 0.8, 0.8, 0.8)
	spin:setPriority(2)
	local spinning = MOAIThread.new()
	spinning:run(function()
		while true do
			blockOn(spin:seekSpin(0, math.pi * 2, 4))
		end
	end)
	
	planet = taxWindow:add(Image.new("earth.png"))
	planet:setScl(0.6)
	planet:setLoc(200, 0)
	planet:setColor(1, 1, 1, 0.9)
	planet:setPriority(3)
	
	timerIcon = taxWindow:add(Image.new("timer-icon.png"))
	timerIcon:setLoc(-300, 20)
	
	taxRoot = taxWindow:add(node.new())
	taxRoot:setLoc(-350, 80)
	local taxboxlist = {}
	local x, y, w = 0, 0, 25
	for i = 1, profile.taxMax do
		local taxbox = taxRoot:add(Image.new("tax-box.png"))
		taxbox:setLoc(x, y)
		taxboxlist[i] = taxbox
		x = x + w
	end
	local taxlist = {}
	local filltax = function()
		for i = 1, profile.taxCount do
			if not taxlist[i] then
				local tax = taxboxlist[i]:add(Image.new("tax.png"))
				taxlist[i] = tax
			end
		end
	end
	filltax()
	collectCD = taxWindow:add(TextBox.new("00:00:00", FONT_SMALL, nil, "LM", 100, 50))
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
	
	collectCountLabel = taxWindow:add(TextBox.new("collect count", FONT_MIDDLE, nil, "MM", 200, 50))
	collectCountLabel:setColor(unpack(FONT_COLOR_LIGHT))
	collectCountLabel:setLoc(-300, 140)
	
	collectCount = taxWindow:add(TextBox.new("", FONT_SMALL, nil, "LM", 100, 50))
	collectCount.setCount = function(self, numerator, denominator)
		local str = string.format("%d/%d", numerator, denominator)
		self:setString(str)
	end
	collectCount:setCount(profile.taxCount, profile.taxMax)
	collectCount:setColor(unpack(FONT_COLOR_GOLD))
	collectCount:setLoc(-140, 137)
	
	coinText = taxWindow:add(TextBox.new("coins", FONT_MIDDLE, nil, "MM", 100, 50))
	coinText:setColor(unpack(FONT_COLOR_LIGHT))
	coinText:setLoc(-320, -100)
	
	coinIcon = taxWindow:add(Image.new("coin.png"))
	coinIcon:setLoc(-180, -100)
	
	coinNum = taxWindow:add(TextBox.new("", FONT_SMALL, nil, "MM", 100, 50))
	coinNum.setNum = function(self, num)
		local str = string.format("%d", num)
		self:setString(str)
	end
	coinNum:setNum(profile.coins)
	coinNum:setColor(unpack(FONT_COLOR_GOLD))
	coinNum:setLoc(-130, -100)
	
	collectTax = taxWindow:add(ui.Button.new(unpack(BUTTON_IMAGE)))
	collectTax:setLoc(-250, -180)
	local blinking
	local rolling
	collectTax.onClick = function()
		local n = #taxlist
		if n > 0 then
			local tax = taxlist[n]
			local e = tax:seekScl(1.5, 1.5, 0.75)
			tax:seekColor(0, 0, 0, 0, 0.75)
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
			if rolling then
				num = rolling.rollingNumber
				rolling:stop()
				blinking:stop()
			end
			rolling = coinNum:rollNumber(num, profile.coins + profile.taxNum, 0.6)
			coinNum:setScl(1.5, 1.5)
			blinking = coinNum:seekScl(1, 1, 0.5, MOAIEaseType.EASE_IN)
			profile.coins = profile.coins + profile.taxNum
		end
	end
	
	collectText = collectTax:add(TextBox.new("collect", FONT_MIDDLE, nil, "MM", 100, 50))
	collectText:setColor(unpack(FONT_COLOR_LIGHT))
	
	motherPlanet.handleTouch = ui.handleTouch
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
	local fleetWindow = Image.new("window.png")
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
	local currInfo = fleetWindow:add(TextBox.new("", FONT_SMALL, nil, "MM", 100, 50))
	currInfo:setLoc(80, 0)
	currInfo:setLineSpacing(20)
	local nextInfo = fleetWindow:add(TextBox.new("", FONT_SMALL, nil, "MM", 100, 50))
	nextInfo:setLoc(180, 0)
	nextInfo:setLineSpacing(20)
	-- local shipModel = fleetWindow:add(Image.new(""))
	-- shipModel:setLoc(50, 0)
	local shipList = fleetWindow:add(ui.DropList.new(150, 500, 150, "vertical"))
	fleetWindow.updateFleet = function()
		shipList:clearItems()
		for i, v in ipairs(profile.fleet) do
			local frame = shipList:addItem(Image.new("frame_icon.png"))
			local item = frame:add(Image.new(v.icon))
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
	
	local millPlanet = node.new()
	local deck = resource.deck("planet01.png")
	millPlanet:setDeck(deck)
	self._sceneRoot:add(millPlanet)
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
	
	self:makePlanetOrbit(millPlanet, 0, 0, 300, 100, 0.2, 0.6, 20, 4, math.pi/2, 0)
end

function HomeStage:initTechPlanet()
	local techPlanet = node.new()
	local deck = resource.deck("planet03.png")
	techPlanet:setDeck(deck)
	self._sceneRoot:add(techPlanet)
	self:makePlanetOrbit(techPlanet, 0, 0, 300, 100, 0.1, 0.5, 20, 3, math.pi, 0)
end

function HomeStage:initPortal()
	local portal = node.new()
	local deck = resource.deck("star-portal.png")
	portal:setDeck(deck)
	local portal02 = portal:add(node.new())
	local deck = resource.deck("star-portal-02.png")
	portal02:setDeck(deck)
	for i = 1, 7 do
		local o = portal02:add(node.new())
		o:setDeck(deck)
		o:setRot(45 * i)
	end
	self._sceneRoot:add(portal)
	self:makePlanetOrbit(portal, 0, 0, 200, 50, 0.1, 0.5, 20, 2, 0, math.pi/4)
	self._portalRotating = MOAIThread.new()
	self._portalRotating:run(function()
		while true do
			blockOn(portal02:moveRot(360, 10, MOAIEaseType.LINEAR))
		end
	end)
end

function HomeStage:initUserPanel()
	self._userPanel = self._uiRoot:add(Image.new ("user-panel.png"))
	local w, h = self._userPanel:getSize()
	self._userPanel:setAnchor("LT", w / 2, -h / 2)
	self._coinsNum = self._userPanel:add(TextBox.new("0", FONT_SMALL, nil, "MM", 60, 60))
    self._coinsNum:setLoc(0, 0)
	self._diamondsNum = self._userPanel:add(TextBox.new("0", FONT_SMALL, nil, "MM", 60, 60))
    self._diamondsNum:setLoc(0, 0)
	self._expBar = self._userPanel:add(FillBar.new("exp-bar.png"))
	self._expBar:setLoc(0, 0)
end

function HomeStage:updateUserPanel()
	local num = profile.currExp / profile.expList[profile.level]
	self._expBar:setFill(num)
	self._coinsNum:setString(tostring(profile.coins))
	self._diamondsNum:setString(tostring(profile.diamonds))
end

function HomeStage:initMenu()
	self._menuRoot = self._uiRoot:add(node.new())
	self._menuRoot:setAnchor("RB", 0, 0)
	menuPanel = self._menuRoot:add(Image.new("menu-panel.png"))
	local w, h = menuPanel:getSize()
	menuPanel:setLoc(-w / 2, h / 2)
	menuPanel:setPriority(1)
	menuSwitch = self._menuRoot:add(ui.Switch.new(2, "menu-icon.png?scl=-1,1", "menu-icon.png?scl=-1.1,1.1", "menu-icon.png", "menu-icon.png?scl=1.1,1.1"))
	menuSwitch:setPriority(2)
	menuSwitch:setLoc(-w / 2, h / 2)
	menuSwitch.onTurn = function(o, status)
		if status == 1 then
			menuPanel:moveRot(-720, 1)
			self:showMenu()
		else
			menuPanel:moveRot(720, 1)
			self:hideMenu()
		end
	end
	menuSwitch:turn(2)
	
	scanButton = self._menuRoot:add(ui.Button.new("scan-btn.png"))
	scanButton:setLoc(-w / 2, h / 2 + h)
	scanButton.onClick = function()
		self:enterSpace()
	end
	local scanRoot = scanButton:add(node.new())
	local enemy = scanButton:add(Image.new("scan-btn-03.png"))
	local scan = scanRoot:add(Image.new("scan-btn-02.png"))
	scanButton:setPriority(0)
	enemy:setPriority(1)
	scan:setPriority(2)
	scan:setLoc(5, 20)
	local scanThread = MOAIThread.new()
	scanThread:run(function()
		while true do
			blockOn(scanRoot:moveRot(-180, 2, MOAIEaseType.LINEAR))
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
		local m = Image.new("menu-bg.png")
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

	self._uiRoot = uiLayer:add(node.new())
	self._uiRoot:setLayoutSize(device.width, device.height)
	
	self._sceneRoot = node.new()
	
	self:initUserPanel()
	self:initMenu()
	self:initStageBG()
	self:initMotherPlanet()
	self:initMillPlanet()
	self:initTechPlanet()
	self:initPortal()
	
	local theta0 = math.pi * 2 / #profile.colonies
	for k, v in ipairs(profile.colonies) do
		local colony = self._sceneRoot:add(Image.new(v.icon))
		self:makePlanetOrbit(colony, 0, 0, 600, 200, 0.1, 0.5, 20, 2, theta0)
	end
	
	if onOkay then
		onOkay(HomeStage)
	end
end

function HomeStage:update()
end

function HomeStage:enterSpace()
	self:close()
	self._spaceStage:open()
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
	ui.insertLayer(sceneLayer, 1)
	
	-- self:updateUserPanel()
end

function HomeStage:close()
	uiLayer:remove(self._uiRoot)
	sceneLayer:remove(self._sceneRoot)
	ui.removeLayer(sceneLayer)
	
	self._bgMoving:stop()
	self._portalRotating:stop()
	if self._menuShowing then
		self._menuShowing:stop()
	end
	if self._menuHiding then
		self._menuHiding:stop()
	end
end

return HomeStage