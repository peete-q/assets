
local ship = {
	icon = "ship001-icon.png?rot=-90&scl=0.9",
	model = "ship001.png",
	bodyGfx="attacker.png",
	level = 1,
	upgradeCurve = {
		[1] = {
			info = {
				"cost: 1",
				"prepareTime: 1",
			},
			data = {
				cost = 1,
				prepareTime = 1,
				upgradeCost = 10,
			},
		},
		[2] = {
			info = {
				"cost: 2",
				"prepareTime: 2",
			},
			data = {
				cost = 2,
				prepareTime = 2,
			},
		},
	},
	
	cost = 0,
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
	prepareMax = 5,
	energyRecover = 5,
	energyMax = 500,
	energyInitial = 100,
	taxMax = 10,
	taxCount = 8,
	collectCD = 10,
	coins = 100,
}

return Profile