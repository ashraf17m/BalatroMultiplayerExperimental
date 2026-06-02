local content_runtime = MP.CONTENT.RUNTIME

SMODS.Atlas({
	key = "speedrun",
	path = "j_speedrun.png",
	px = 71,
	py = 95,
})

SMODS.Joker(content_runtime.with_phantom_sync_hooks({
	key = "speedrun",
	atlas = "speedrun",
	rarity = 2,
	cost = 6,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = true,
	loc_vars = function(self, info_queue, card)
		MP.UTILS.add_nemesis_info(info_queue)
		return { vars = {} }
	end,
	mp_include = content_runtime.include_multiplayer_jokers,
	calculate = function(self, card, context)
		if
			context.mp_speedrun
			and (not card.edition or card.edition.type ~= "mp_phantom")
			and #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit
		then
			G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 1
			G.E_MANAGER:add_event(Event({
				trigger = "before",
				delay = 0.0,
				func = function()
					local created_card = create_card("Spectral", G.consumeables, nil, nil, nil, nil, nil, "mp_speedrun")
					created_card:add_to_deck()
					G.consumeables:emplace(created_card)
					G.GAME.consumeable_buffer = 0
					return true
				end,
			}))
			return {
				message = localize("k_plus_spectral"),
				colour = G.C.SECONDARY_SET.Spectral,
				card = card,
			}
		end
	end,
	mp_credits = {
		idea = { "Virtualized" },
		art = { "Aura!" },
		code = { "Virtualized" },
	},
}, "j_mp_speedrun"))
