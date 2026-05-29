local deck = SMODS.Back({
	name = "testing_deck",
	key = "testing",
	pos = { x = 0, y = 0 },
	config = {},

	apply = function()
		G.E_MANAGER:add_event(Event({
			func = function()
				for i = 1, 3 do
					local card = create_card("Joker", G.jokers, nil, nil, nil, nil, nil, "testing_joker")
					card:add_to_deck()
					G.jokers:emplace(card)
				end

				local seals = { "Gold", "Red", "Blue", "Purple" }
				for i = 1, 3 do
					local front = pseudorandom_element(G.P_CARDS, pseudoseed("testing_front"))
					local card = create_card("Base", G.deck, nil, nil, nil, nil, nil, "testing_base")
					card:set_base(front)
					card:set_seal(pseudorandom_element(seals, pseudoseed("testing_seal")), true)
					card:add_to_deck()
					G.deck:emplace(card)
					table.insert(G.playing_cards, card)
				end

				return true
			end,
		}))
	end,
})

return deck
