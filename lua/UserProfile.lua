
local plane = {
	cost = 0,
	prepareTime = 1,
	icon = "attacker-icon.png",
	bodyGfx="attacker.png",
}

local Profile = {
	menus = {
		[1] = true,
		[4] = true,
	},
	slots = {
		{props = plane},
		{props = plane},
		{props = plane},
		{props = plane},
	},
	prepareMax = 5,
	energyRecover = 5,
	energyMax = 500,
	energyInitial = 100,
}

return Profile