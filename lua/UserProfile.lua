
local plane = {
	cost = 0,
	prepareTime = 3,
	icon = "plane-icon.png",
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
}

return Profile