MP.EC.register_sandbox_joker({
	key = "ambrosia_sandbox",
	blueprint_compat = false,
	eternal_compat = false,

	rarity = 2,
	cost = 5,
	pos = { x = 5, y = 2 },

	config = {
		extra = {},
	},

	loc_vars = function(self, info_queue, card)
		return { vars = {} }
	end,

	calculate = function(self, card, context)
		if context.skip_blind then
			for i = 1, G.consumeables.config.card_limit do
				if #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit then
					G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 1
					G.E_MANAGER:add_event(Event({
						trigger = "before",
						delay = 0.0,
						func = function()
							local created_card = create_card("Spectral", G.consumeables, nil, nil, nil, nil, nil, "ambro")
							created_card:add_to_deck()
							G.consumeables:emplace(created_card)
							G.GAME.consumeable_buffer = 0
							created_card:juice_up(0.5, 0.5)
							return true
						end,
					}))
					card_eval_status_text(
						context.blueprint_card or card,
						"extra",
						nil,
						nil,
						nil,
						{ message = localize("k_plus_spectral"), colour = G.C.SECONDARY_SET.Spectral }
					)
				end
			end
		elseif context.selling_card then
			if context.card.ability.set == "Spectral" then
				MP.EC.destroy_joker(card)
				card_eval_status_text(
					context.blueprint_card or card,
					"extra",
					nil,
					nil,
					nil,
					{ message = localize("k_drank_ex"), colour = G.C.SECONDARY_SET.Spectral }
				)
			end
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "dottykitty" },
	},
})
