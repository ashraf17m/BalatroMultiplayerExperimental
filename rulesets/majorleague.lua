MP.inject_tournament_empty_ruleset("majorleague", 1, "k_majorleague_description", {
	forced_gamemode_text = "k_attrition",
	forced_gamemode = "gamemode_mp_attrition",
	forced_lobby_options = true,
	is_disabled = function(self)
		return false
	end,
	force_lobby_options = function(self)
		MP.LOBBY.config.timer_base_seconds = 180
		MP.LOBBY.config.timer_forgiveness = 1
		MP.LOBBY.config.the_order = false
		MP.LOBBY.config.preview_disabled = true
		return true
	end,
})
