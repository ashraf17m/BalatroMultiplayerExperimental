MP.EC.register_sandbox_joker({
	key = "jokalisa_sandbox",
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = false,

	rarity = 3,
	cost = 8,
	pos = { x = 3, y = 3 },

	config = {
		extra = {
			Xmult = 1,
			Xmult_mod = 0.1,
		},
	},

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.Xmult, card.ability.extra.Xmult_mod } }
	end,

	calculate = function(self, card, context)
		if context.before and not context.blueprint then
			local enhanced_count = 0
			local enhanced_keys = {}
			for i = 1, #context.scoring_hand do
				for k, v in pairs(SMODS.get_enhancements(context.scoring_hand[i])) do
					if v and not enhanced_keys[k] then
						enhanced_keys[k] = true
						enhanced_count = enhanced_count + 1
					end
				end
			end
			if enhanced_count > 0 then
				card.ability.extra.Xmult = card.ability.extra.Xmult + (card.ability.extra.Xmult_mod * enhanced_count)
				return {
					message = localize({ type = "variable", key = "a_xmult", vars = { card.ability.extra.Xmult } }),
					card = card,
					colour = G.C.RED,
				}
			end
		elseif context.cardarea == G.jokers and context.joker_main and card.ability.extra.Xmult > 1 then
			return {
				message = localize({ type = "variable", key = "a_xmult", vars = { card.ability.extra.Xmult } }),
				Xmult_mod = card.ability.extra.Xmult,
			}
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "R3venantR3mnant" },
	},
})
