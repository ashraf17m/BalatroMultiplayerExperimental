SMODS.Challenge({
	key = "in_the_red",
	rules = {
		custom = {
			{ id = "no_reward_specific", value = "Small" },
			{ id = "no_reward_specific", value = "Big" },
		},
	},
	jokers = {
		{ id = "j_credit_card", eternal = true, edition = "negative", rental = true },
	},
	restrictions = {
		banned_tags = {
			{ id = "tag_investment" },
		},
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})
