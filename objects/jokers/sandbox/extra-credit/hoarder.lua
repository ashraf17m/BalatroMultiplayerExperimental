MP.EC.register_sandbox_joker({
	key = "hoarder_sandbox",
	blueprint_compat = false,
	eternal_compat = true,

	rarity = 2,
	cost = 5,
	pos = { x = 9, y = 3 },

	config = {
		extra = 1,
	},

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra } }
	end,

	mp_credits = {
		code = { "CampfireCollective", "steph" },
		art = { "neatoqueen" },
	},
})
