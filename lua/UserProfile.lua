
local ship = {
	icon = "ship000.png?rot=-90&scl=0.4",
	model = "ship000.png",
	bodyGfx="ship000.png?rot=-90",
	level = 1,
	upgradeCurve = {
		[1] = {
			info = {
				"attack: 1",
				"hp: 1",
				"cost: 1",
				"readyTime: 1",
			},
			data = {
				cost = 1,
				readyTime = 1,
				upgradeCost = 10,
			},
		},
		[2] = {
			info = {
				"attack: 2",
				"hp: 2",
				"cost: 2",
				"readyTime: 2",
			},
			data = {
				cost = 2,
				readyTime = 2,
			},
		},
	},
	
	cost = 0,
	upgradeCost = 0,
	readyTime = 3,
}

local Profile = {
	menus = {
		[1] = true,
		[4] = true,
		[5] = true,
	},
	fleet = {
		ship,
		ship,
		ship,
		ship,
		ship,
	},
	spells = {
	},
	colonies = {
	},
	motherShip = ship,
	readyMax = 5,
	energyRecover = 5,
	energyMax = 500,
	energyInitial = 100,
	taxMax = 10,
	taxCount = 8,
	taxNum = 12,
	collectCD = 10,
	currCCD = 3,
	coins = 198,
	diamonds = 100,
	currExp = 10,
	level = 1,
	expList = {100, 200, 300},
}

return Profile