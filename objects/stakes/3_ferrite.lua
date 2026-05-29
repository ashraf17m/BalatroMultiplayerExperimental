MP.STAKES.register_alt_stake({
	name = "Ferrite Stake",
	key = "ferrite",
	applied_stakes = { "pebble" },
	above_stake = "pebble",
	pos = { x = 3, y = 0 },
	modifiers = function()
		G.GAME.modifiers.mp_enable_persistent_jokers = true
	end,
	colour = HEX("B2B2B2"),
})
