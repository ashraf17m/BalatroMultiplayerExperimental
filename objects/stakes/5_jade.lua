MP.STAKES.register_alt_stake({
	name = "Jade Stake",
	key = "jade",
	applied_stakes = { "pyrite" },
	above_stake = "pyrite",
	pos = { x = 0, y = 1 },
	modifiers = function()
		G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
	end,
	colour = HEX("3EA93C"),
})
