-- Espresso - Extra Credit Joker ported to Sandbox
-- Gain $30 and destroy this card when Blind is skipped, reduces by $5/round

MP.EC.register_sandbox_joker({
	key = "espresso_sandbox",
	blueprint_compat = false,
	eternal_compat = false,
	rarity = 1,
	cost = 2,
	pos = { x = 6, y = 1 },
	config = { extra = { money = 30, m_loss = 5 } },

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.money, card.ability.extra.m_loss } }
	end,

	calculate = function(self, card, context)
		if context.skip_blind and not context.blueprint then
			G.E_MANAGER:add_event(Event({
				func = function()
					card_eval_status_text(card, "extra", nil, nil, nil, {
						message = localize("k_drank_ex"),
						colour = G.C.MONEY,
						card = card,
					})
					return true
				end,
			}))
			ease_dollars(card.ability.extra.money)
			card:juice_up(0.5, 0.5)
			delay(0.5)
			MP.EC.destroy_joker(card)
		elseif context.end_of_round and not context.individual and not context.repetition and not context.blueprint then
			card.ability.extra.money = card.ability.extra.money - card.ability.extra.m_loss
			if card.ability.extra.money <= 0 then
				MP.EC.destroy_joker(card)
				return {
					message = "Too cold!",
					colour = G.C.FILTER,
				}
			else
				return {
					message = "Cooled!",
					colour = G.C.FILTER,
				}
			end
		end
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "dottykitty" } },
})
