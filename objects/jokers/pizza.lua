local content_runtime = MP.CONTENT.RUNTIME

SMODS.Atlas({
	key = "pizza",
	path = "j_pizza.png",
	px = 71,
	py = 95,
})

SMODS.Joker(content_runtime.with_phantom_sync_hooks({
	key = "pizza",
	atlas = "pizza",
	rarity = 1,
	cost = 4,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = false,
	perishable_compat = true,
	config = { extra = { discards = 2, discards_nemesis = 1 } },
	loc_vars = function(self, info_queue, card)
		MP.UTILS.add_nemesis_info(info_queue)
		return { vars = { card.ability.extra.discards, card.ability.extra.discards_nemesis } }
	end,
	mp_include = content_runtime.include_multiplayer_jokers,
	calculate = function(self, card, context)
		if context.mp_end_of_pvp and not content_runtime.is_phantom_card(card) then
			content_runtime.increment_pizza_discards(card.ability.extra.discards)
			G.GAME.round_resets.discards = G.GAME.round_resets.discards + card.ability.extra.discards
			ease_discard(card.ability.extra.discards)
			content_runtime.send_eat_pizza(card.ability.extra.discards_nemesis)
			local _card = context.blueprint_card or card
			_card:remove_from_deck()
			_card:start_dissolve({ G.C.RED }, nil, 1.6)
			return {
				message = localize("k_eaten_ex"),
				colour = G.C.RED,
			}
		end
	end,
	mp_credits = {
		idea = { "Virtualized" },
		art = { "TheTrueRaven" },
		code = { "Virtualized" },
	},
}, "j_mp_pizza"))
