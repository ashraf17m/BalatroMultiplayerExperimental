-- Starfruit - Extra Credit Joker ported to Sandbox
-- First played hand each round has a chance to gain 1 level (5 uses, then self-destructs)

MP.EC.register_sandbox_joker({
	key = "starfruit_sandbox",
	blueprint_compat = true,
	eternal_compat = false,
	rarity = 1,
	cost = 6,
	pos = { x = 2, y = 0 },
	config = { extra = { uses = 5, odds = 2 } },

	loc_vars = function(self, info_queue, card)
		local num, denom = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "j_mp_starfruit_sandbox")
		return { vars = { card.ability.extra.uses, num, denom } }
	end,

	calculate = function(self, card, context)
		if context.cardarea == G.jokers and G.GAME.current_round.hands_played == 0 and context.before then
			if SMODS.pseudorandom_probability(card, "j_mp_starfruit_sandbox", 1, card.ability.extra.odds) then
				local text = context.scoring_name
				card_eval_status_text(
					context.blueprint_card or card,
					"extra",
					nil,
					nil,
					nil,
					{ message = localize("k_level_up_ex") }
				)
				update_hand_text({ sound = "button", volume = 0.7, pitch = 0.8, delay = 0.3 }, {
					handname = localize(text, "poker_hands"),
					chips = G.GAME.hands[text].chips,
					mult = G.GAME.hands[text].mult,
					level = G.GAME.hands[text].level,
				})
				level_up_hand(context.blueprint_card or card, text, nil, 1)
			end

			if not context.blueprint then
				card.ability.extra.uses = card.ability.extra.uses - 1
				if card.ability.extra.uses <= 0 then
					MP.EC.destroy_joker(card)
					return {
						message = localize("k_eaten_ex"),
						colour = G.C.MONEY,
					}
				end
			end
		end
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "dottykitty" } },
})
