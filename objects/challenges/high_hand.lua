SMODS.Challenge({
	key = "high_hand",
	rules = {
		modifiers = {
			{ id = "hands", value = 1 },
			{ id = "hand_size", value = 26 },
			{ id = "discards", value = 0 },
		},
	},
	restrictions = {
		banned_cards = {
			{ id = "j_burglar" },
		},
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})
