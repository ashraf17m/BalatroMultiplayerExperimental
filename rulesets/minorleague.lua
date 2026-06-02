MP.inject_tournament_empty_ruleset("minorleague", 2, "k_minorleague_description", {
	forced_gamemode_text = "k_attrition",
	forced_gamemode = "gamemode_mp_attrition",
	forced_lobby_options = true,
	force_lobby_options = function(self)
		MP.LOBBY.config.timer_base_seconds = 210
		MP.LOBBY.config.timer_forgiveness = 1
		MP.LOBBY.config.the_order = true
		return true
	end,
})
