MP.inject_custom_standard_ruleset("testing", 3, "k_testing_description", {
	forced_gamemode_text = "k_attrition",
	forced_gamemode = "gamemode_mp_attrition",
	forced_lobby_options = false,
	is_disabled = function(self)
		return MP.UTILS.check_lovely_version()
	end,
	force_lobby_options = function(self)
		MP.LOBBY.config.pvp_start_round = 1
		return false
	end,
})
