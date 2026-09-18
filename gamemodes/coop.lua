MP.Gamemode(MP.UTILS.with_empty_content_lists({
	key = "coop",
	selection_group_key = "k_cooperative",
	selection_group_order = 3,
	selection_order = 1,
	get_blinds_by_ante = function(self, ante)
		return nil, nil, nil
	end,
	banned_jokers = {
		"j_aij_eulenspiegel",
		"j_akyrs_you_tried",
		"j_cry_redeo",
		"j_mr_bones",
		"j_cry_carved_pumpkin",
		"j_cry_pumpkin",
		"j_hpot_lockin",
		"j_mp_conjoined_joker",
		"j_mp_defensive_joker",
		"j_mp_lets_go_gambling",
		"j_mp_pacifist",
		"j_mp_penny_pincher",
		"j_mp_pizza",
		"j_mp_skip_off",
		"j_mp_speedrun",
		"j_mp_taxes",
		"j_paperback_determination",
		"j_paperback_punch_card",
		"j_paperback_torii",
		"j_paperback_unholy_alliance",
		"j_poke_celebi",
		"j_poke_mimikyu",
		"j_poke_shedinja",
	},
	banned_consumables = {
		"c_cry_analog",
		"c_mp_asteroid",
		"c_paperback_apostle_of_swords",
	},
	banned_vouchers = {
		"v_hieroglyph",
		"v_petroglyph",
		"v_cry_asteroglyph",
	},
	banned_tags = {
		"tag_aij_anarchy",
	},
	banned_blinds = {
		"bl_akyrs_forgotten_prospects_of_the_future",
		"bl_akyrs_forgotten_uncertainties_of_life",
	},
	create_info_menu = function()
		return MP.build_gamemode_info_menu({
			description_key = "k_coop_description",
			blind_rows = {
				{
					label = { type = "variable", key = "k_ante_min", vars = { "1" } },
					chips = { "small", "big", "random" },
				},
			},
			show_values_note = true,
			spacer_size = 0.4,
		})
	end,
})):inject()
