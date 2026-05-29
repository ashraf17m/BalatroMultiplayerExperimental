MP.inject_matchmaking_empty_ruleset("legacy_ranked", 2, "k_legacy_ranked_description", {
	banned_silent = {},
	reworked_enhancements = {
		"m_mp_display_glass",
	},
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
