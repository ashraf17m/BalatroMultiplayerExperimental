MP.Ruleset({
	key = "experimental_legacy",
	layers = { "classic" },
	selection_group_key = "k_custom",
	selection_group_order = 2,
	selection_order = 8,
	selection_localize_key = "k_experimental_legacy",
	forced_gamemode = "gamemode_mp_attrition",
	forced_gamemode_text = "k_attrition",
	multiplayer_content = true,
	banned_silent = {
		"j_mp_pizza",
		"j_mp_penny_pincher",
		"j_mp_conjoined_joker",
		"j_mp_pacifist",
		"j_mp_defensive_joker",
		"j_mp_speedrun",
		"j_mp_skip_off",
		"j_mp_taxes",
		"j_hanging_chad",
	},
	banned_consumables = {
		"c_justice",
		"c_mp_asteroid",
	},
	reworked_jokers = {
		"j_mp_hanging_chad",
		"j_mp_lets_go_gambling",
	},
	create_info_menu = function()
		return MP.UI.CreateRulesetInfoMenu({
			multiplayer_content = true,
			forced_gamemode_text = "k_attrition",
			description_key = "k_experimental_legacy_description",
		})
	end,
	force_lobby_options = function(self)
		MP.LOBBY.config.the_order = true
		return false
	end,
}):inject()
