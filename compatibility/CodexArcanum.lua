if MP.PLATFORM.SMODS.is_mod_loadable("CodexArcanum") then
	sendDebugMessage("Codex Arcanum compatibility detected", "MULTIPLAYER")
	MP.DECK.ban_cards({
		"j_breaking_bozo",
		"c_alchemy_terra",
	})
end
