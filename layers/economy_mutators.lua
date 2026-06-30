MP.Layer("inflation", {
	game_modifiers = { inflation = true },
})

MP.Layer("no_interest", {
	game_modifiers = { no_interest = true },
})

MP.Layer("discard_tax", {
	game_modifiers = { discard_cost = 1 },
})

MP.Layer("frugal", {
	game_modifiers = { money_per_discard = 1 },
})

MP.Layer("spartan", {
	game_modifiers = { no_blind_reward = { Small = true, Big = true } },
})

MP.Layer("pricey_packs", {
	game_modifiers = { booster_ante_scaling = true },
})
