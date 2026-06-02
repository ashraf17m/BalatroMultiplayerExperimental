MP.Gamemode(MP.UTILS.with_empty_content_lists({
	key = "attrition",
	selection_group_key = "k_battle",
	selection_group_order = 1,
	selection_order = 1,
	get_blinds_by_ante = function(self, ante)
		if ante >= MP.LOBBY.config.pvp_start_round then
			if not MP.LOBBY.config.normal_bosses then
				return nil, nil, "bl_mp_nemesis"
			else
				G.GAME.round_resets.pvp_blind_choices.Boss = true
			end
		end
		return nil, nil, nil
	end,
	banned_jokers = {
		"j_mr_bones",
		"j_luchador",
		"j_matador",
		"j_chicot",
	},
	banned_consumables = {},
	banned_vouchers = {
		"v_hieroglyph",
		"v_petroglyph",
		"v_directors_cut",
		"v_retcon",
	},
	banned_tags = {
		"tag_boss",
	},
	banned_blinds = {
		"bl_wall",
		"bl_final_vessel",
	},
	create_info_menu = function()
		return MP.build_gamemode_info_menu({
			description_key = "k_attrition_description",
			blind_rows = {
				{
					label = { type = "variable", key = "k_ante_number", vars = { "1" } },
					chips = { "small", "big", "random" },
				},
				{
					label = { type = "variable", key = "k_ante_min", vars = { "2" } },
					chips = { "small", "big", "pvp" },
				},
			},
			lives = "4",
			show_values_note = true,
		})
	end,
})):inject()
