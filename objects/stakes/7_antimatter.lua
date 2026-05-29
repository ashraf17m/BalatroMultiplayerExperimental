MP.STAKES.register_alt_stake({
	name = "Antimatter Stake",
	key = "antimatter",
	applied_stakes = { "crystal" },
	above_stake = "crystal",
	pos = { x = 2, y = 1 },
	modifiers = function()
		G.GAME.modifiers.mp_enable_draining_jokers = true
	end,
	colour = HEX("4F6367"),
	shiny = true,
})
