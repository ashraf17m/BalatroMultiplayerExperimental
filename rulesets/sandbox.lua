MP.Ruleset({
	key = "sandbox",
	layers = { "sandbox" },
	selection_group_key = "k_matchmaking",
	selection_group_order = 1,
	selection_order = 4,
	create_info_menu = function()
		return MP.UI.CreateRulesetInfoMenu({
			multiplayer_content = true,
			forced_lobby_options = true,
			description_key = "k_sandbox_description",
		})
	end,
	forced_lobby_options = true,
	force_lobby_options = function(self)
		MP.LOBBY.config.preview_disabled = true
		MP.LOBBY.config.the_order = true
		MP.LOBBY.config.starting_lives = 4
		return false
	end,
}):inject()
