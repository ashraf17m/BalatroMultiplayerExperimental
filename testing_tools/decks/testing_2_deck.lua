local starting_jokers = {
	{ key = "j_mp_lets_go_gambling", seed = "testing_2_lets_go_gambling" },
	{ key = "j_mp_skip_off", seed = "testing_2_skip_off" },
	{ key = "j_mp_taxes", seed = "testing_2_taxes" },
	{ key = "j_oops", seed = "testing_2_oops_1" },
	{ key = "j_oops", seed = "testing_2_oops_2" },
}

local function add_starting_joker(joker_def)
	local card = create_card("Joker", G.jokers, nil, nil, nil, nil, joker_def.key, joker_def.seed)
	card:add_to_deck()
	G.jokers:emplace(card)
end

local deck = SMODS.Back({
	name = "testing_2_deck",
	key = "testing_2",
	pos = { x = 0, y = 0 },
	config = {},

	apply = function()
		G.E_MANAGER:add_event(Event({
			func = function()
				for _, joker_def in ipairs(starting_jokers) do
					add_starting_joker(joker_def)
				end

				return true
			end,
		}))
	end,
})

return deck
