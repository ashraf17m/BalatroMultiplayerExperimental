local content_runtime = MP.CONTENT.RUNTIME

SMODS.Joker({
	key = "todo_list",
	no_collection = MP.should_hide_collection_item(),
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	rarity = 1,
	cost = 4,
	pos = { x = 4, y = 11 },
	config = { extra = { dollars = 5, poker_hand = "High Card" }, mp_sticker_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.dollars, localize(card.ability.extra.poker_hand, "poker_hands") } }
	end,
	calculate = function(self, card, context)
		if context.before and context.scoring_name == card.ability.extra.poker_hand then
			return content_runtime.create_buffered_dollars_reward(card.ability.extra.dollars)
		end
		if context.end_of_round and context.game_over == false and context.main_eval and not context.blueprint then
			local poker_hands = {}
			for handname, _ in pairs(G.GAME.hands) do
				if handname ~= card.ability.extra.poker_hand then poker_hands[#poker_hands + 1] = handname end
			end
			card.ability.extra.poker_hand = pseudorandom_element(poker_hands, "todo_list")
			return {
				message = localize("k_reset"),
			}
		end
	end,
	set_ability = function(self, card, initial, delay_sprites)
		local poker_hands = {}
		for handname, _ in pairs(G.GAME.hands) do
			if handname ~= card.ability.extra.poker_hand then poker_hands[#poker_hands + 1] = handname end
		end
		card.ability.extra.poker_hand = pseudorandom_element(poker_hands, "todo_list")
	end,
	mp_include = function()
		return MP.is_layer_active("experimental")
	end,
})
