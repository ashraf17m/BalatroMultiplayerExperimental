MP.EC.register_sandbox_joker({
	key = "pyromancer_sandbox",
	blueprint_compat = true,
	eternal_compat = true,

	rarity = 1,
	cost = 5,
	pos = { x = 1, y = 3 },

	config = {
		extra = {
			mult = 20,
		},
	},

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.mult } }
	end,

	calculate = function(self, card, context)
		if
			context.cardarea == G.jokers
			and context.joker_main
			and G.GAME.current_round.hands_left <= G.GAME.current_round.discards_left
		then
			return {
				message = localize({ type = "variable", key = "a_mult", vars = { card.ability.extra.mult } }),
				mult_mod = card.ability.extra.mult,
			}
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "Wingcap" },
	},
})
