if MP.PLATFORM.SMODS.is_mod_loadable("jen") then
	sendDebugMessage("Jen's compatibility detected", "MULTIPLAYER")
	MP.DECK.ban_cards({
		"j_jen_hydrangea",
		"j_jen_gamingchair",
		"j_jen_kosmos",
		"c_jen_entropy",
	})
end
