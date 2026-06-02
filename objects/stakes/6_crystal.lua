MP.STAKES.register_alt_stake({
	name = "Crystal Stake",
	key = "crystal",
	applied_stakes = { "jade" },
	above_stake = "jade",
	pos = { x = 1, y = 1 },
	modifiers = function()
		G.GAME.modifiers.mp_enable_unreliable_jokers = true
	end,
	colour = HEX("BCF9FF"),
	shiny = true,
})
