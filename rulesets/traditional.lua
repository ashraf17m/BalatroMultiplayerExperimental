MP.inject_custom_standard_ruleset("traditional", 2, "k_traditional_description", {
	banned_jokers = {
		"j_mp_speedrun",
		"j_mp_conjoined_joker",
	},
	force_lobby_options = function(self)
		MP.LOBBY.config.timer = false
		return false
	end,
})
