local broken_center = {
	order = 1,
	unlocked = true,
	start_alerted = true,
	discovered = true,
	blueprint_compat = true,
	perishable_compat = true,
	eternal_compat = true,
	rarity = 4,
	cost = 10000,
	name = "BROKEN",
	pos = { x = 9, y = 9 },
	set = "Joker",
	effect = "",
	cost_mult = 1.0,
	config = {},
	key = "j_broken",
}

MP.HOOKS.register_method_hook(Card, "Card", "init", "mp.compatibility.broken_center", {
	before = function(ctx)
		if ctx.args[6] == nil then
			ctx.args[6] = broken_center
		end
	end,
})
