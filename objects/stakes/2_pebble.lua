MP.STAKES.register_alt_stake({
	name = "Pebble Stake",
	key = "pebble",
	applied_stakes = { "plastic" },
	above_stake = "plastic",
	pos = { x = 2, y = 0 },
	modifiers = function()
		G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
	end,
	colour = HEX("949494"),
})
