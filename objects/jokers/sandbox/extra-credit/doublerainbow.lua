-- Double Rainbow - Extra Credit Joker ported to Sandbox
-- Retrigger all Lucky Cards

MP.EC.register_sandbox_joker({
	key = "doublerainbow_sandbox",
	blueprint_compat = true,
	eternal_compat = true,
	enhancement_gate = "m_lucky",
	rarity = 2,
	cost = 5,
	pos = { x = 1, y = 0 },
	config = { extra = 1 },

	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = G.P_CENTERS.m_lucky
		return {}
	end,

	calculate = function(self, card, context)
		if
			context.repetition
			and context.cardarea == G.play
			and SMODS.get_enhancements(context.other_card)["m_lucky"] == true
		then
			return {
				message = localize("k_again_ex"),
				repetitions = 1,
				card = card,
			}
		elseif
			context.repetition
			and context.cardarea == G.hand
			and SMODS.get_enhancements(context.other_card)["m_lucky"] == true
		then
			if next(context.card_effects[1]) or #context.card_effects > 1 then
				return {
					message = localize("k_again_ex"),
					repetitions = card.ability.extra,
					card = card,
				}
			end
		end
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "dottykitty" } },
})
