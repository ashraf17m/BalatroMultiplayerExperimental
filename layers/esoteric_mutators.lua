MP.Layer("flipped_cards", {
	game_modifiers = { flipped_cards = true },
})

MP.Layer("debuff_played_cards", {
	game_modifiers = { debuff_played_cards = true },
})

MP.Layer("all_eternal", {
	game_modifiers = { all_eternal = true },
})

MP.Layer("sticker_shop", {
	game_modifiers = {
		enable_eternals_in_shop = true,
		enable_perishables_in_shop = true,
		enable_rentals_in_shop = true,
	},
})

MP.Layer("chip_cap", {
	game_modifiers = { chips_dollar_cap = true },
})

MP.Layer("shrinking_hand", {
	game_modifiers = { minus_hand_size_per_X_dollar = 10 },
})
