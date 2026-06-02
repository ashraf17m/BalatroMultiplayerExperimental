MP.Gamemode(MP.UTILS.with_empty_content_lists({
	key = "survival",
	selection_group_key = "k_challenge",
	selection_group_order = 2,
	selection_order = 1,
	get_blinds_by_ante = function(self, ante)
		return nil, nil, nil
	end,
	banned_jokers = {
		"j_mp_conjoined_joker",
		"j_mp_defensive_joker",
		"j_mp_lets_go_gambling",
		"j_mp_magnet_sandbox",
		"j_mp_pacifist",
		"j_mp_penny_pincher",
		"j_mp_pizza",
		"j_mp_skip_off",
		"j_mp_speedrun",
		"j_mp_taxes",
	},
	banned_consumables = {
		"c_mp_asteroid",
	},
	create_info_menu = function()
		return MP.build_gamemode_info_menu({
			description_key = "k_survival_description",
			blind_rows = {
				{
					label = { type = "variable", key = "k_ante_min", vars = { "1" } },
					chips = { "small", "big", "random" },
				},
			},
			lives = "1",
			spacer_size = 0.4,
		})
	end,
})):inject()
