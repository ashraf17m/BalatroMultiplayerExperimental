MP.inject_matchmaking_standard_ruleset("standard_ranked", 1, "k_standard_ranked_description", {
	forced_gamemode_text = "k_attrition",
	forced_gamemode = "gamemode_mp_attrition",
	forced_lobby_options = true,
	is_disabled = function(self)
		return MP.UTILS.check_lovely_version()
	end,
	force_lobby_options = function(self)
		MP.LOBBY.config.the_order = true
		return true
	end,
})
