MP.Ruleset({
	key = "experimental",
	layers = { "experimental" },
	default_modifiers = { "pvp_timer", "pressure_timer" },
	selection_group_key = "k_custom",
	selection_group_order = 2,
	selection_order = 7,
	selection_localize_key = "k_experimental_standard",
	forced_gamemode = "gamemode_mp_attrition",
	forced_gamemode_text = "k_attrition",
	create_info_menu = function()
		return MP.UI.CreateRulesetInfoMenu({
			multiplayer_content = true,
			forced_gamemode_text = "k_attrition",
			description_key = "k_experimental_description",
		})
	end,
	force_lobby_options = function(self)
		MP.LOBBY.config.the_order = true
		return false
	end,
}):inject()
