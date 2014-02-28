
local ship = {
	icon = "attacker-icon.png",
	model = "attacker-model.png",
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
}

local Profile = {
	menus = {
		[1] = true,
		[4] = true,
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
	taxCount = 5,
	taxMax = 5,
	collectCD = 10,
	coins = 100,
}

return Profile